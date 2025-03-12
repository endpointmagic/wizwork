# Create an IAM role for the control plane
resource "aws_iam_role" "cluster" {
    name = "${var.name}-cluster-role"
    assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

# Allow EKS to assume the IAM role
data "aws_iam_policy_document" "cluster_assume_role" {
    statement {
        effect = "Allow"
        actions = ["sts:AssumeRole"]
        principals {
            type = "Service"
            identifiers = ["eks.amazonaws.com"]
        }
    }
}

# Attach the permissions the IAM role needs
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.cluster.name
}

# Add vpc and subnet data sources
data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_eks_cluster" "cluster" {
    name = var.name
    role_arn = aws_iam_role.cluster.arn
    version = "1.32"

    vpc_config {
        subnet_ids = data.aws_subnets.default.ids
    }


# This will ensure IAM Role permissions are created before and deleted after
# the EKS Cluster. Otherwise, EKS would not be able to properly delete
# EKS managed EC2 infrastructure such as Security Groups.
depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
]
}


# Create an IAM role for the node group (managed)
resource "aws_iam_role" "node_group" {
    name = "${var.name}-node-group"
    assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

# Allow EC2 instances to assume the IAM role
data "aws_iam_policy_document" "node_assume_role" {
    statement {
        effect = "Allow"
        actions = ["sts:AssumeRole"]
        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

# Attach the permissions the node group needs
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = aws_iam_role.node_group.name
}

resource "aws_eks_node_group" "nodes" {
    cluster_name = aws_eks_cluster.cluster.name
    node_group_name = var.name
    node_role_arn = aws_iam_role.node_group.arn
    subnet_ids = data.aws_subnets.default.ids
    instance_types = var.instance_types

    scaling_config {
        min_size = var.min_size
        max_size = var.max_size
        desired_size = var.desired_size
    }

    # Ensure that IAM Role permissions are created before and deleted after
    # the EKS Node Group. Otherwise, EKS would not be able to properly
    # delete EC2 Instances and Elastic Network Interfaces.
    depends_on = [
        aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
        aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
        aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    ]
}

### Wiz requirement alert:
### this is the service account that addresses the "provide the container
### with cluster admin privileges" component:
resource "kubernetes_service_account" "taskySA" {
  metadata {
    name = "tasky-service-account"
  }
}


### Wiz requirement alert:
### this takes the service account (that addresses the "provide the container
### with cluster admin privileges" component) and binds it to the cluster-admin role
### this effectively gives the container full privileges at the cluster level
resource "kubernetes_cluster_role_binding" "tasky" {
  metadata {
    name = "tasky-svcacct-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tasky-service-account"
    namespace = "default"
  }
}