output "s3_bucket_name" {
  description = "Name of the S3 bucket for PDF storage"
  value       = aws_s3_bucket.textract_bucket.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.textract_processor.function_name
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.textract_dlq.url
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret for LLM API"
  value       = aws_secretsmanager_secret.llm_api_key.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
