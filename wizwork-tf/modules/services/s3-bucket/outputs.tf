output "s3-bucket_IAM-Policy-ARN" {
    value = aws_iam_policy.backup_user_policy.arn
    description = "ARN of the IAM Policy that provides upload access to the mongodb backups S3 bucket"
}