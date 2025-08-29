# SES Email Configuration for receiving emails with PDF attachments

# SES Domain Identity (required for email receiving)
resource "aws_ses_domain_identity" "textract_domain" {
  count  = var.enable_ses ? 1 : 0
  domain = var.ses_domain
}

# SES Domain DKIM (required for email authentication)
resource "aws_ses_domain_dkim" "textract_domain_dkim" {
  count  = var.enable_ses ? 1 : 0
  domain = aws_ses_domain_identity.textract_domain[0].domain
}

# Route53 Zone (if managing DNS with AWS and not using registered domain)
resource "aws_route53_zone" "ses_zone" {
  count = var.enable_ses && var.manage_dns && !var.register_new_domain ? 1 : 0
  name  = var.ses_domain
}

# Domain verification TXT record (for existing domains)
resource "aws_route53_record" "ses_domain_verification" {
  count   = var.enable_ses && var.manage_dns && !var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.ses_zone[0].zone_id
  name    = "_amazonses.${var.ses_domain}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.textract_domain[0].verification_token]
}

# DKIM CNAME records (for existing domains)
resource "aws_route53_record" "ses_domain_dkim" {
  count   = var.enable_ses && var.manage_dns && !var.register_new_domain ? 3 : 0
  zone_id = aws_route53_zone.ses_zone[0].zone_id
  name    = "${aws_ses_domain_dkim.textract_domain_dkim[0].dkim_tokens[count.index]}._domainkey.${var.ses_domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.textract_domain_dkim[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# MX record for email receiving (for existing domains)
resource "aws_route53_record" "ses_domain_mx" {
  count   = var.enable_ses && var.manage_dns && !var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.ses_zone[0].zone_id
  name    = var.ses_domain
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
}

# Data source for current region
data "aws_region" "current" {}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "textract_rule_set" {
  count         = var.enable_ses ? 1 : 0
  rule_set_name = "${var.project_name}-email-rules"
}

# Activate the receipt rule set
resource "aws_ses_active_receipt_rule_set" "textract_active_rule_set" {
  count         = var.enable_ses ? 1 : 0
  rule_set_name = aws_ses_receipt_rule_set.textract_rule_set[0].rule_set_name
}

# SES Receipt Rule
resource "aws_ses_receipt_rule" "textract_rule" {
  count         = var.enable_ses ? 1 : 0
  name          = "${var.project_name}-pdf-processor"
  rule_set_name = aws_ses_receipt_rule_set.textract_rule_set[0].rule_set_name
  recipients    = [var.ses_email_address]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.textract_bucket.bucket
    object_key_prefix = "emails/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.ses_policy]
}

# S3 Bucket Policy for SES
resource "aws_s3_bucket_policy" "ses_policy" {
  count  = var.enable_ses ? 1 : 0
  bucket = aws_s3_bucket.textract_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPuts"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.textract_bucket.arn}/emails/*"
        Condition = {
          StringEquals = {
            "aws:Referer" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Lambda function for email processing
resource "aws_lambda_function" "email_processor" {
  count            = var.enable_ses ? 1 : 0
  filename         = "email_processor.zip"
  function_name    = "${var.project_name}-email-processor"
  role            = aws_iam_role.email_lambda_role[0].arn
  handler         = "email_processor.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.textract_bucket.bucket
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.email_lambda_logs[0],
    data.archive_file.email_lambda_zip[0],
  ]
}

# IAM Role for Email Lambda
resource "aws_iam_role" "email_lambda_role" {
  count = var.enable_ses ? 1 : 0
  name  = "${var.project_name}-email-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Email Lambda
resource "aws_iam_role_policy" "email_lambda_policy" {
  count = var.enable_ses ? 1 : 0
  name  = "${var.project_name}-email-lambda-policy"
  role  = aws_iam_role.email_lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.textract_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "email_lambda_logs" {
  count      = var.enable_ses ? 1 : 0
  role       = aws_iam_role.email_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 trigger for email processing
resource "aws_s3_bucket_notification" "email_notification" {
  count  = var.enable_ses ? 1 : 0
  bucket = aws_s3_bucket.textract_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.email_processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "emails/"
  }

  depends_on = [aws_lambda_permission.allow_email_bucket[0]]
}

resource "aws_lambda_permission" "allow_email_bucket" {
  count         = var.enable_ses ? 1 : 0
  statement_id  = "AllowExecutionFromS3EmailBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_processor[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.textract_bucket.arn
}

# Email processor Lambda deployment package
data "archive_file" "email_lambda_zip" {
  count       = var.enable_ses ? 1 : 0
  type        = "zip"
  output_path = "email_processor.zip"
  source_file = "${path.module}/../src/lambda/email_processor.py"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Outputs for SES configuration
output "ses_domain_verification_token" {
  description = "Domain verification token for SES"
  value       = var.enable_ses ? aws_ses_domain_identity.textract_domain[0].verification_token : null
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for email authentication"
  value       = var.enable_ses ? aws_ses_domain_dkim.textract_domain_dkim[0].dkim_tokens : null
}

output "ses_email_address" {
  description = "Email address for receiving PDFs"
  value       = var.enable_ses ? var.ses_email_address : null
}

output "ses_mx_record" {
  description = "MX record for email receiving"
  value       = var.enable_ses ? "10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com" : null
}

output "dns_configuration_instructions" {
  description = "DNS configuration instructions"
  value = var.enable_ses && !var.manage_dns ? {
    domain_verification = "Add TXT record: _amazonses.${var.ses_domain} = ${aws_ses_domain_identity.textract_domain[0].verification_token}"
    dkim_records = "Add CNAME records for DKIM tokens (see ses_dkim_tokens output)"
    mx_record = "Add MX record: ${var.ses_domain} = 10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"
  } : null
}
