# AWS Textract PDF Processing PoC

This Terraform configuration deploys a complete serverless architecture for processing PDF files via email using AWS Textract and LLM integration.

## Architecture Overview

![Workflow Diagram](WORKFLOW_DIAGRAM.md)

The solution provides an end-to-end email-to-PDF processing pipeline:
1. **Email Reception**: Users send PDFs to `documents@textract-poc-082025.info`
2. **Automatic Processing**: SES → S3 → Lambda → Textract → LLM API
3. **Results Storage**: JSON outputs stored in S3 with structured organization

**Current Status**: ✅ **FULLY DEPLOYED AND OPERATIONAL**
- Domain: `textract-poc-082025.info` (registered via Route 53)
- Email endpoint: `documents@textract-poc-082025.info`
- Complete DNS configuration with MX, DKIM, and verification records
- All Lambda functions deployed and tested

## Project Structure

```
├── terraform/              # Terraform infrastructure code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── route53-domain.tf
│   ├── ses-email-setup.tf
│   ├── terraform.tfvars.example
│   └── .terraform/
├── src/                    # Source code
│   └── lambda/
│       ├── email_processor.py
│       └── lambda_function.py
├── docs/                   # Documentation
│   ├── assets/            # Images and diagrams
│   └── EMAIL_SETUP.md
├── scripts/               # Utility scripts
│   └── create_test_pdf.py
├── tests/                 # Test files and data
├── build/                 # Build artifacts (zip files)
└── .amazonq/             # Amazon Q configuration
```

## Components

- **S3 Bucket**: Stores incoming PDFs and processed JSON files
- **Lambda Function**: Orchestrates Textract processing and LLM API calls
- **Amazon Textract**: Extracts text from PDF documents
- **Secrets Manager**: Securely stores LLM API credentials
- **CloudWatch**: Logging and monitoring
- **SQS**: Dead letter queue for error handling

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. LLM API endpoint and key

## Deployment

### Prerequisites
- AWS CLI configured with profile `mcp-poc`
- Terraform >= 1.0 installed
- LLM API endpoint and key (OpenAI or compatible)

### Quick Start (Infrastructure Already Deployed)

**Current Infrastructure Status**: ✅ Deployed and Ready
- S3 Bucket: `textract-poc-textract-rab8wu80`
- Domain: `textract-poc-082025.info` (Route 53 registered)
- Lambda Functions: Email processor + Textract processor
- SES Configuration: Complete email receiving setup

### Update LLM API Credentials
```bash
export AWS_PROFILE=mcp-poc
aws secretsmanager update-secret --secret-id textract-poc-llm-api-key \
  --secret-string '{"api_key":"your-openai-api-key","api_url":"https://api.openai.com/v1/chat/completions"}'
```

### Fresh Deployment (if needed)
```bash
cd terraform/
export AWS_PROFILE=mcp-poc
terraform init
terraform plan -no-color
terraform apply -no-color
```

## Usage

### Email-Based Processing (Ready to Use)

**✅ System is fully operational and ready for testing!**

#### Send Test Email
```
To: documents@textract-poc-082025.info
Subject: Process Document
Attachment: test_document.pdf (or any PDF)
```

#### Automatic Processing Flow
1. **SES receives email** → stores in S3 `emails/` folder
2. **Email Processor Lambda** extracts PDF → saves to `incoming/` folder  
3. **Textract Processor Lambda** processes PDF → creates JSON → calls LLM API
4. **Results stored** in `processed/` folder

#### Monitor Processing
```bash
export AWS_PROFILE=mcp-poc
# Watch email processing
aws logs tail /aws/lambda/textract-poc-email-processor --follow
# Watch Textract processing
aws logs tail /aws/lambda/textract-poc-textract-processor --follow
```

#### Check Results
```bash
aws s3 ls s3://textract-poc-textract-rab8wu80/processed/
```

### Manual Testing (Alternative)

1. **Upload PDF directly** to S3 for testing:
   ```bash
   export AWS_PROFILE=mcp-poc
   aws s3 cp test_document.pdf s3://textract-poc-textract-rab8wu80/incoming/
   ```

2. **Monitor processing** and **check results**:
   ```bash
   aws logs tail /aws/lambda/textract-poc-textract-processor --follow
   aws s3 ls s3://textract-poc-textract-rab8wu80/processed/
   ```

## S3 Bucket Structure

```
emails/             # Raw emails from SES
├── email1.txt
└── email2.txt

metadata/           # Email metadata
├── email1_metadata.json
└── email2_metadata.json

incoming/           # Extracted PDFs ready for processing
├── abc12345_document1.pdf
└── def67890_document2.pdf

processed/          # JSON outputs from Textract
├── abc12345_document1.json
├── abc12345_document1_llm_response.json
├── def67890_document2.json
└── def67890_document2_llm_response.json
```

## Configuration

### Current Deployment Settings
- **AWS Region**: us-east-1
- **Project Name**: textract-poc
- **S3 Bucket**: textract-poc-textract-rab8wu80
- **Domain**: textract-poc-082025.info
- **Email**: documents@textract-poc-082025.info

### Environment Variables (Lambda)
- `BUCKET_NAME`: S3 bucket name
- `API_SECRET_NAME`: Secrets Manager secret name

### DNS Configuration (Route 53)
- **MX Record**: `10 inbound-smtp.us-east-1.amazonaws.com`
- **Domain Verification**: TXT record for SES
- **DKIM Authentication**: 3 CNAME records
- **SPF/DMARC**: Email security policies

## Security Features

- S3 server-side encryption (AES256)
- IAM roles with least-privilege permissions
- API credentials stored in AWS Secrets Manager
- VPC endpoints support (if needed)

## Monitoring

- CloudWatch logs for Lambda execution
- S3 access logging
- Dead letter queue for failed processing
- 7-day lifecycle policy for cost optimization

## Troubleshooting

1. **Check Lambda logs**:
   ```bash
   export AWS_PROFILE=mcp-poc
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/textract-poc"
   ```

2. **Verify S3 bucket access**:
   ```bash
   aws s3 ls s3://textract-poc-textract-rab8wu80/
   ```

3. **Test Textract directly**:
   ```bash
   aws textract detect-document-text --document '{"S3Object":{"Bucket":"textract-poc-textract-rab8wu80","Name":"incoming/test_document.pdf"}}'
   ```

4. **Common Issues**:
   - **401 LLM API Error**: Update API key in Secrets Manager
   - **Email not received**: Check domain DNS propagation
   - **PDF not processed**: Verify file is in `incoming/` folder

## Cost Optimization

- 7-day S3 lifecycle policy
- Lambda timeout set to 5 minutes
- CloudWatch log retention: 14 days
- Free tier eligible for small workloads

## Cleanup

```bash
cd terraform/
export AWS_PROFILE=mcp-poc
terraform destroy -no-color
```

**Note**: Domain registration cannot be automatically deleted and will continue to incur charges until manually cancelled in Route 53.

## Testing Files

- **test_document.pdf**: Sample invoice PDF for testing (created automatically)
- **WORKFLOW_DIAGRAM.md**: Complete architecture and workflow documentation

## Next Steps for Production

1. ✅ ~~Add SES email domain configuration~~ (Complete)
2. ✅ ~~Implement email parsing for attachments~~ (Complete)
3. Add API Gateway for webhook integration
4. Configure VPC for enhanced security
5. Add monitoring dashboards
6. Implement backup and disaster recovery
7. Add email notification for processing completion