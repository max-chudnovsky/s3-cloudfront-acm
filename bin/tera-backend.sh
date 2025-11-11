#!/bin/bash
# Script to create an S3 bucket for Terraform state storage with versioning and encryption enabled and dynamoDB for locking.

# SUFFIX=$(openssl rand -hex 4)
# For consistency, using a fixed suffix
SUFFIX="eb9509bc"
PROJECT="testproject" 
BUCKET_NAME="${PROJECT}-terraform-state-${SUFFIX}"
TABLE_NAME="${PROJECT}-terraform-lock-${SUFFIX}"

# Check if bucket already exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket: ${BUCKET_NAME}"
    aws s3 mb s3://${BUCKET_NAME}
else
    echo "S3 bucket ${BUCKET_NAME} already exists, skipping creation"
    exit 1
fi

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "S3 bucket created: ${BUCKET_NAME}"

# Check if DynamoDB table already exists
if aws dynamodb describe-table --table-name ${TABLE_NAME} --region us-east-1 2>&1 | grep -q 'ResourceNotFoundException'; then
    echo "Creating DynamoDB table: ${TABLE_NAME}"
    aws dynamodb create-table \
      --table-name ${TABLE_NAME} \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region us-east-1

    # Wait for table to be active
    aws dynamodb wait table-exists --table-name ${TABLE_NAME}
    echo "DynamoDB table created: ${TABLE_NAME}"
else
    echo "DynamoDB table ${TABLE_NAME} already exists, skipping creation"
fi