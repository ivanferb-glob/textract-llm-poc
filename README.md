# AWS Textract PDF Processing PoC

Serverless architecture for processing PDF files via email using AWS Textract and LLM integration.

**Status**: ✅ **FULLY DEPLOYED AND OPERATIONAL**
- Domain: `textract-poc-082025.info`
- Email: `documents@textract-poc-082025.info`
- S3 Bucket: `textract-poc-textract-rab8wu80`

## Architecture Workflow

```
Email Input → SES → S3 (emails/) → Email Processor λ → S3 (incoming/) 
                                                            ↓
                                                   Textract Processor λ
                                                            ↓
                                                       Textract
                                                            ↓
                                                    S3 (processed/)
                                                            ↓
                                                        LLM API
                                                            ↓
                                                  S3 (llm_response/)
```

### Processing Flow
1. **Email Input**: User sends PDF to `documents@textract-poc-082025.info`
2. **SES Processing**: Receives email, stores in S3 `emails/` folder
3. **Email Processor**: Lambda extracts PDF attachments to `incoming/` folder
4. **Textract Processor**: Lambda processes PDF with Textract and LLM API
5. **Results Storage**: Textract JSON saved in `processed/`, LLM responses in `llm_response/`

### S3 Bucket Structure
```
textract-poc-textract-rab8wu80/
├── emails/        # Raw emails from SES
├── metadata/      # Email metadata JSON
├── incoming/      # Extracted PDFs
├── processed/     # Textract JSON output
└── llm_response/  # LLM structured data responses
```

## Project Structure

```
├── terraform/              # Infrastructure code
│   ├── main.tf
│   ├── ses-email-setup.tf
│   ├── variables.tf
│   └── terraform.tfvars    # Configuration values
├── src/lambda/             # Lambda functions
│   ├── email_processor.py
│   └── lambda_function.py
├── test_document.pdf       # Sample test file
└── WORKFLOW_DIAGRAM.md     # Detailed architecture
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- SAIA LLM API key (configured in terraform.tfvars)

## Usage

### Send Test Email
```
To: documents@textract-poc-082025.info
Subject: Process Document
Attachment: test_document.pdf
```

### Monitor Processing
```bash
aws logs tail /aws/lambda/textract-poc-textract-processor --follow
```

### Check Results
```bash
# Check Textract JSON output
aws s3 ls s3://textract-poc-textract-rab8wu80/processed/

# Check LLM structured responses
aws s3 ls s3://textract-poc-textract-rab8wu80/llm_response/

# View LLM response content
aws s3 cp s3://textract-poc-textract-rab8wu80/llm_response/filename.json - | jq .
```

### Update LLM API Key
```bash
aws secretsmanager update-secret --secret-id textract-poc-llm-api-key \
  --secret-string '{"api_key":"your-saia-api-key","api_url":"https://api.qa.saia.ai/chat"}'
```

## Infrastructure Components

### Core Services
- **Amazon SES**: Email receiving with MX/DKIM records
- **Amazon S3**: Document storage with lifecycle policies
- **AWS Lambda**: Email processor + Textract processor
- **Amazon Textract**: OCR text extraction
- **Secrets Manager**: Secure API credential storage

### Supporting Services
- **Route 53**: DNS management for domain
- **CloudWatch**: Logging and monitoring
- **SQS**: Dead letter queue for errors
- **IAM**: Least-privilege security roles

## Deployment

Infrastructure is already deployed. For fresh deployment:

```bash
cd terraform/
terraform init
terraform plan -no-color
terraform apply -no-color
```

## Troubleshooting

**Common Issues**:
- **401 SAIA API Error**: Update API key in Secrets Manager
- **Email not received**: Check DNS propagation (15-30 min)
- **PDF not processed**: Verify file in `incoming/` folder
- **No LLM response**: Check `llm_response/` folder and Lambda logs

**Debug Commands**:
```bash
# Check logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/textract-poc"
# Test S3 access
aws s3 ls s3://textract-poc-textract-rab8wu80/
# Test Textract
aws textract detect-document-text --document '{"S3Object":{"Bucket":"textract-poc-textract-rab8wu80","Name":"incoming/test_document.pdf"}}'
```

## Security & Cost Features

- S3 server-side encryption (AES256)
- 7-day S3 lifecycle policy
- 14-day CloudWatch log retention
- IAM least-privilege roles
- Free tier eligible

## Cleanup

```bash
cd terraform/
terraform destroy -no-color
```

**Note**: Domain registration requires manual cancellation in Route 53.