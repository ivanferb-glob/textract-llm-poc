#!/bin/bash

# AWS Textract PoC Deployment Script
# This script helps deploy the infrastructure with proper AWS profile setup

set -e

# Check if AWS_PROFILE is set
if [ -z "$AWS_PROFILE" ]; then
    echo "Setting AWS_PROFILE=mcp-poc as required..."
    export AWS_PROFILE=mcp-poc
fi

echo "Using AWS Profile: $AWS_PROFILE"

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "Please edit terraform.tfvars with your configuration before proceeding."
    exit 1
fi

# Run terraform commands
echo "Initializing Terraform..."
terraform init

echo "Planning deployment..."
terraform plan

echo "Ready to apply? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Applying Terraform configuration..."
    terraform apply
else
    echo "Deployment cancelled."
    exit 0
fi

echo "Deployment completed successfully!"
echo "Don't forget to update the LLM API credentials in AWS Secrets Manager:"
echo "aws secretsmanager update-secret --secret-id textract-poc-llm-api-key \\"
echo "  --secret-string '{\"api_key\":\"your-actual-api-key\",\"api_url\":\"https://your-api-endpoint.com/v1/chat\"}'"