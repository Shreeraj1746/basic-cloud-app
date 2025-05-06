#!/bin/bash
set -e

# Configuration
STACK_NAME="basic-cloud-app"
TEMPLATE_BUCKET="${STACK_NAME}-templates-$(aws sts get-caller-identity --query Account --output text)"
REGION=$(aws configure get region)
TEMPLATE_DIR="infrastructure/templates"
PARAMS_FILE="infrastructure/parameters.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying ${STACK_NAME} to AWS...${NC}"

# Create S3 bucket for templates if it doesn't exist
if ! aws s3api head-bucket --bucket ${TEMPLATE_BUCKET} 2>/dev/null; then
    echo -e "${YELLOW}Creating S3 bucket for templates: ${TEMPLATE_BUCKET}${NC}"
    aws s3 mb s3://${TEMPLATE_BUCKET} --region ${REGION}
    aws s3api put-bucket-versioning --bucket ${TEMPLATE_BUCKET} --versioning-configuration Status=Enabled
    echo -e "${GREEN}Bucket created successfully${NC}"
else
    echo -e "${GREEN}Template bucket already exists: ${TEMPLATE_BUCKET}${NC}"
fi

# Upload CloudFormation templates to S3
echo -e "${YELLOW}Uploading CloudFormation templates to S3...${NC}"
find ${TEMPLATE_DIR} -name "*.yml" -type f | while read -r template; do
    template_name=$(basename "${template}")
    echo -e "Uploading ${template} to s3://${TEMPLATE_BUCKET}/templates/${template_name}"

    # Replace placeholder with actual bucket name
    if [ "${template_name}" == "main.yml" ]; then
        sed "s|BUCKET_NAME|${TEMPLATE_BUCKET}|g" "${template}" > "${template}.tmp"
        aws s3 cp "${template}.tmp" "s3://${TEMPLATE_BUCKET}/templates/${template_name}"
        rm "${template}.tmp"
    else
        aws s3 cp "${template}" "s3://${TEMPLATE_BUCKET}/templates/${template_name}"
    fi
done
echo -e "${GREEN}Templates uploaded successfully${NC}"

# Deploy the CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack ${STACK_NAME}...${NC}"
aws cloudformation deploy \
    --template-url "https://s3.amazonaws.com/${TEMPLATE_BUCKET}/templates/main.yml" \
    --stack-name "${STACK_NAME}" \
    --parameter-overrides file://${PARAMS_FILE} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack ${STACK_NAME} deployed successfully${NC}"

    # Get stack outputs
    echo -e "${YELLOW}Stack outputs:${NC}"
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query "Stacks[0].Outputs" \
        --output table
else
    echo -e "${RED}Stack deployment failed${NC}"
    exit 1
fi
