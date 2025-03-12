variable "IAMPolicyARN" {
    description = "ARN of the IAM Policy that provides upload access to the mongodb backups S3 bucket (from output of S3 bucket module)"
    type        = string
}