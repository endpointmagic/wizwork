/* provider "aws" {
    region = "us-east-2"
} */

# create an EC2 instance to install MongoDB on
resource "aws_instance" "ec2-mongodb" {
    # I am using Ubuntu 16.04 LTS AMI in us-east-2 region per Wiz requirement to use an old OS
    ami = "ami-0c686a31f8d8f5978"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.ec2-mongodb-sg.id]
    
    ### reminder to self: this key is on my macbook ;)
    key_name = "ubuntu-mongo_key"
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

    ### directly copy the mongodb backups upload to S3 script to avoid issues with variables, etc.
    provisioner "file" {
        source      = "mongo-backup.sh"
        destination = "/home/ubuntu/mongo-backup.sh"
        
        connection {
        type        = "ssh"
        user        = "ubuntu"
        private_key = "${file("/Users/jamessandwick/.ssh/id_rsa")}"
        host        = "${self.public_ip}"
        }
    }

    ### EC2 first-run stuff... prob oughta do most of this cloud-init stuff in packer but this is fun, too
    user_data = <<-EOF
        #!/bin/bash
        ### need curl for a couple things
        sudo apt-get install gnupg curl
        ### install mongodb 4.4
        curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
        sudo apt-get update
        sudo apt-get install -y mongodb-org=4.4.29 mongodb-org-server=4.4.29 mongodb-org-shell=4.4.29 mongodb-org-mongos=4.4.29 mongodb-org-tools=4.4.29
        sudo systemctl start mongod
        ### creating mongo user does not seem to work unless I wait for a while...
        sleep 45
        ### create the mongo user so authentication (authorization) can be done
        sudo mongo admin --eval "db.createUser({user: 'taskyAdmin', pwd:'pwned', roles: [{role: 'userAdminAnyDatabase', db: 'admin'},{ role : 'dbAdminAnyDatabase', db : 'admin'  },{ role : 'readWriteAnyDatabase', db : 'admin'  },{ role : 'clusterAdmin', db : 'admin'  }]});"
        ### set the mongo binding to allow traffic from everywhere
        sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf 
        ### enable authentication (authorization) for mongo
        sudo sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
        sudo systemctl restart mongod
        sudo systemctl enable mongod
        ### restrict traffic with host based firewall
        sudo ufw allow 27017
        sudo ufw allow 22
        sudo ufw --force enable
        ###  install aws cli and jq to support copying mongodb backups to S3
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        sudo apt install unzip
        unzip awscliv2.zip 
        sudo ./aws/install 
        sudo apt install jq -y
        ### create a cron job to back up mongo and upload backup files to s3 (the .sh file was copied elsewhere)
        (crontab -l ; echo "*/60 * * * * sudo sh /home/ubuntu/mongo-backup.sh") | crontab -
        ### congratulate myself
        echo "Well done!"
        EOF
    
    user_data_replace_on_change = true

    tags = {
        name = "ec2_mongodb"
    }
    ### need to have the key before creating the ec2 instance so I can ssh in
    depends_on = [
        aws_key_pair.ubuntu
    ]
}


resource "aws_security_group" "ec2-mongodb-sg" {
    name = "ec2_mongodb_sg"

    ingress {
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

### I created this key on my MacBook for connecting to the EC2 instance via SSH
resource "aws_key_pair" "ubuntu" {
  key_name   = "ubuntu-mongo_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcCSwZIrrKTaMSUAUcFGO0Ao2iEd2kScS13eLmNLSn1pK27+9/kTE8mFImzyCz8vH72q27lBfRcPW+h2jSzjPO8T3wqCwpbAjjBEBDZHCdyHKi9FXenPor2d+ZPC5VDg09sqDeHgAHKr97RSbdO20BD2A7CvUcPQ+GAXQHknx+aOrhfC79UCvVg/FZzoFWT34qe6t6OL6SwYJA5jcVTwN8sttMj5prF3cFKclXd6v/Uuay2cu8Lgh/H1Os1An/iiM+QqZ7FIQDQPHvucA379/GFY5SyOUxn29AOVZIP2LbMLBAstEh5vTpctmr5H4ZvwBfEJzglNWEdF8PxnBCtpVXBJdPmKT2fKHIMdSmkf3TWdWbh/KFd0GGfUDI7Edzu9aC3O5XVsM+9GtWJY11Vp2G0QKE/MrlxKG7FKNLBFeN+roiWoLqT5h68F6TlWNzxFVIBjWd9dGwazVsPUdzWZsU5k8JXf8cqSAfMUz0TZGQeHWNAqSRL2AxpwiaFO+caPJu/hAOe7OwramoyJM8BHlLd92tltbwjFzPs7rO8E+rNKp1XnmZu/UxyZVFJlFRWzg8XVF2mv1Q/6fiAqRMioWgGNoGxfr9Cm2jDqFPMAMfF2v6DGC4xJ6gz/clVFXfLjJG4z/ZMVxoSVOTxFGHeVCjUPgzKoE/mShQYY20zhdwFw== jamessandwick@yahoo.com"
}

### Create the IAM role (for EC2 to upload mongodb backups to S3), and let EC2 assume it
resource "aws_iam_role" "s3_role" {
  name = "mongo-backups-s3-upload"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

### attach the IAM policy (that allows S3 get/put/delete) to the s3 uploader role
### (actually, that IAM policy is now allowed all AWS permissions per the wiz requirements)
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.s3_role.name
  policy_arn = var.IAMPolicyARN
}

### create the ec2 mongod
resource "aws_iam_instance_profile" "ec2_profile" {
    name = "ec2-mongobackup-s3-profile"
    role = aws_iam_role.s3_role.name
}

