terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for PDF storage and JSON output
resource "aws_s3_bucket" "textract_bucket" {
  bucket = "${var.project_name}-textract-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "textract_bucket_versioning" {
  bucket = aws_s3_bucket.textract_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "textract_bucket_encryption" {
  bucket = aws_s3_bucket.textract_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "textract_bucket_lifecycle" {
  bucket = aws_s3_bucket.textract_bucket.id

  rule {
    id     = "delete_old_files"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

# SQS Dead Letter Queue for error handling
resource "aws_sqs_queue" "textract_dlq" {
  name                      = "${var.project_name}-textract-dlq"
  message_retention_seconds = 1209600 # 14 days
}

# Lambda function for processing
resource "aws_lambda_function" "textract_processor" {
  filename         = "lambda_function.zip"
  function_name    = "${var.project_name}-textract-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  dead_letter_config {
    target_arn = aws_sqs_queue.textract_dlq.arn
  }

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.textract_bucket.bucket
      API_SECRET_NAME = aws_secretsmanager_secret.llm_api_key.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs,
    data.archive_file.lambda_zip,
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-textract-processor"
  retention_in_days = 14
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

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

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.textract_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.llm_api_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.textract_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Bucket Notification to trigger Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.textract_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.textract_bucket.arn
}

# Secrets Manager for LLM API Key
resource "aws_secretsmanager_secret" "llm_api_key" {
  name        = "${var.project_name}-llm-api-key"
  description = "API key for LLM service"
}

resource "aws_secretsmanager_secret_version" "llm_api_key_version" {
  secret_id     = aws_secretsmanager_secret.llm_api_key.id
  secret_string = jsonencode({
    api_key = var.llm_api_key
    api_url = var.llm_api_url
  })
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source_file = "${path.module}/../src/lambda/lambda_function.py"
}
