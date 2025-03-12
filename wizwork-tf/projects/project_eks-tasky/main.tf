### I'm going to be using just the us-east-2 region just because
provider "aws" {
    region = "us-east-2"
}

### create the bucket (where mongo backups will go)
module "s3_bucket" {
    source = "../../modules/services/s3-bucket"
}

### create the ec2 instance, install mongo, set up the backups job
module "ec2_mongodb" {
    source = "../../modules/services/ec2-mongodb/"

    IAMPolicyARN = module.s3_bucket.s3-bucket_IAM-Policy-ARN

    # Only create the EC2 instance after the S3 bucket has been created
    depends_on = [
        module.s3_bucket,
    ]
}

### build the kubernetes cluster
module "eks_cluster" {
    source = "../../modules/services/eks-cluster/"

    name = "example-eks-cluster"
    min_size = 1
    max_size = 2
    desired_size = 1

    ### t3.small is the smallest instance type that can be 
    ### used for worker nodes so I can't do free tier here :(
    instance_types = ["t3.small"]
}

### load the kubernetes provider
provider "kubernetes" {
    host = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(
        module.eks_cluster.cluster_certificate_authority[0].data
    )
    token = data.aws_eks_cluster_auth.cluster.token
}

### get the kubernetes cluster name (used to connect to the kubernetes provider - above)
data "aws_eks_cluster_auth" "cluster" {
    name = module.eks_cluster.cluster_name
}

### create the mongodb connection string (this is using creds in cleartext -- very bad!)
### TODO: change ec2_privateIP variable name to "mongoConnectionString" or similar
locals {
    ec2_privateIP = join("",["mongodb://taskyAdmin:pwned@",module.ec2_mongodb.ec2-mongodb_privateIP,":27017"])
}

### set up the tasky deployment in the kubernetes/EKS cluster
module "tasky-app" {
    source = "../../modules/services/tasky-app"

    name = "tasky-app"
    image = "urkl/wizwork:3"
    replicas = 2
    container_port = 8080

    environment_variables = {
        MONGODB_URI = local.ec2_privateIP
        SECRET_KEY = "secret123"
    }

    # only deploy tasky after the cluster and mongodb server have already been deployed
    depends_on = [
        module.eks_cluster,
        module.ec2_mongodb,
    ]
}

### handy for connecting 
output "service_endpoint" {
    value = module.tasky-app.service_endpoint
    description = "The tasky-app endpoint"
}

### using this to expedite troubleshooting issue with tasky not seemingly connecting to the db
### also to have it handy for connecting to mongo via mongosh for testing
output "ec2_privateIP" {
    value = local.ec2_privateIP
}