#!/bin/bash
# Get the IAM role credentials from the instance metadata service
IAM_ROLE_NAME="mongo-backups-s3-upload"
CREDENTIALS="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/mongo-backups-s3-upload)"

# Extract the credentials
ACCESS_KEY_ID="$(echo "$CREDENTIALS" | jq -r .AccessKeyId)"
SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r .SecretAccessKey)
SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r .Token)
EXPIRATION=$(echo "$CREDENTIALS" | jq -r .Expiration)

# Set environment variables for the AWS CLI
export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r .Token)
export AWS_SECURITY_TOKEN=$(echo "$CREDENTIALS" | jq -r .Token) # For compatibility with older versions of the CLI
export AWS_REGION="us-east-2"

# Back up mongodb locally
sudo mongodump --gzip --out /home/ubuntu/mongodump/$(date +"%Y-%m-%d") mongodb://taskyAdmin:pwned@localhost:27017

# Upload the local mongodb backup to S3
FOLDER_NAME=$(date +"%Y-%m-%d")
aws s3 cp /home/ubuntu/mongodump/$FOLDER_NAME s3://endpointmagic-mongo-backup/$FOLDER_NAME --recursive