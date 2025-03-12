/* provider "aws" {
    region = "us-east-2"
} */

### create the s3 bucket that will store mongo backups
resource "aws_s3_bucket" "mongo_backup" {
  bucket = "endpointmagic-mongo-backup"
  force_destroy = true

  tags = {
    Name        = "MongoDB Backups Bucket"
  }
}

/* ### disable versioning because mongo backup folders are named by date/time
resource "aws_s3_bucket_versioning" "mongodb-backup_versioning" {
  bucket = aws_s3_bucket.mongo_backup.id
  versioning_configuration {
    status = "Enabled"
  }
} */

resource "aws_s3_bucket_ownership_controls" "mongo_backup" {
  bucket = aws_s3_bucket.mongo_backup.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

### this is to disable public access blocks so the s3 bucket
### can be reached externally as per wiz requirements
resource "aws_s3_bucket_public_access_block" "mongo_backup" {
  bucket = aws_s3_bucket.mongo_backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

### create an acl to allow public read access to the mongo backups s3 bucket
resource "aws_s3_bucket_acl" "mongo_backup" {
  depends_on = [
    aws_s3_bucket_ownership_controls.mongo_backup,
    aws_s3_bucket_public_access_block.mongo_backup,
  ]

  bucket = aws_s3_bucket.mongo_backup.id
  acl    = "public-read"
}

### can't remember why I created this but I don't think it's needed...
/* ### Create IAM User to upload backups to S3
resource "aws_iam_user" "backup_user" {
    name = "s3-upload-user" # username
}

### can't remember why I created this but I don't think it's needed...
resource "aws_iam_access_key" "my_access_key" {
    user = aws_iam_user.backup_user.name
} */


### create the IAM policy to upload mongodb backups from mongo ec2 instance to s3
### actually this is just going to be basically an admin policy...
resource "aws_iam_policy" "backup_user_policy" {
    name        = "s3-upload-user-policy"
    path = "/"
    description = "Policy for allowing uploading to the S3 bucket for mongo db backups"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
/*           {
            Effect    = "Allow"
            Action    = [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
            ]
            Resource = ["arn:aws:s3:::${aws_s3_bucket.mongo_backup.bucket}/*"] 
          }, */

        ### *** ALLOWING FULL ACCESS TO ALL AWS RESOURCES PER WIZ REQUIREMENTS *** ###
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
      ]
    })
}

### can't remember why I created this but I don't think it's needed...
/* 
resource "aws_iam_user_policy_attachment" "s3_upload_attachment" {
    user       = aws_iam_user.backup_user.name
    policy_arn = aws_iam_policy.backup_user_policy.arn
} */

