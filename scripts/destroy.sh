#!/bin/bash
set -e

# Configuration
STACK_NAME="basic-cloud-app"
TEMPLATE_BUCKET="${STACK_NAME}-templates-$(aws sts get-caller-identity --query Account --output text)"
REGION=$(aws configure get region)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting cleanup process for ${STACK_NAME}...${NC}"

# Ask for confirmation before proceeding
read -p "Are you sure you want to destroy the ${STACK_NAME} stack and all associated resources? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${RED}Operation cancelled${NC}"
    exit 1
fi

# First disable termination protection on the RDS instance and S3 bucket
echo -e "${YELLOW}Disabling termination protection on resources...${NC}"

# Get RDS instance identifier
DB_INSTANCE_ID=$(aws cloudformation describe-stack-resources \
    --stack-name ${STACK_NAME}-DatabaseStack \
    --query "StackResources[?ResourceType=='AWS::RDS::DBInstance'].PhysicalResourceId" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$DB_INSTANCE_ID" ]; then
    echo -e "${YELLOW}Disabling deletion protection on RDS instance: ${DB_INSTANCE_ID}${NC}"
    aws rds modify-db-instance --db-instance-identifier ${DB_INSTANCE_ID} --no-deletion-protection
    echo -e "${GREEN}Waiting for RDS modification to complete...${NC}"
    aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
fi

# Delete the CloudFormation stack
echo -e "${YELLOW}Deleting CloudFormation stack: ${STACK_NAME}${NC}"
aws cloudformation delete-stack --stack-name ${STACK_NAME}
echo -e "${YELLOW}Waiting for stack deletion to complete...${NC}"
aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}

# Delete the S3 bucket with templates
echo -e "${YELLOW}Cleaning up template bucket: ${TEMPLATE_BUCKET}${NC}"
# First empty the bucket
aws s3 rm s3://${TEMPLATE_BUCKET} --recursive
# Then delete the bucket
aws s3 rb s3://${TEMPLATE_BUCKET} --force

echo -e "${GREEN}Cleanup completed successfully${NC}"
