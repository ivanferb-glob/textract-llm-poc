#!/bin/bash

# AWS Textract PoC Cleanup Script
# This script helps destroy the infrastructure with proper AWS profile setup

set -e

# Check if AWS_PROFILE is set
if [ -z "$AWS_PROFILE" ]; then
    echo "Setting AWS_PROFILE=mcp-poc as required..."
    export AWS_PROFILE=mcp-poc
fi

echo "Using AWS Profile: $AWS_PROFILE"

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

echo "WARNING: This will destroy all infrastructure created by this project!"
echo "Are you sure you want to proceed? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Destroying Terraform infrastructure..."
    terraform destroy
    echo "Infrastructure destroyed successfully!"
else
    echo "Cleanup cancelled."
    exit 0
fi