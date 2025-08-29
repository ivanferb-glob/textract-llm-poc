variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "textract-poc"
}

variable "llm_api_key" {
  description = "API key for LLM service"
  type        = string
  sensitive   = true
  default     = "your-api-key-here"
}

variable "llm_api_url" {
  description = "URL endpoint for LLM API"
  type        = string
  default     = "https://api.example.com/v1/chat"
}

variable "enable_ses" {
  description = "Enable SES email processing"
  type        = bool
  default     = true
}

variable "ses_domain" {
  description = "Domain for SES email processing"
  type        = string
  default     = "example.com"
}

variable "ses_email_address" {
  description = "Email address for receiving PDFs"
  type        = string
  default     = "pdf-processor@example.com"
}

variable "manage_dns" {
  description = "Manage DNS records automatically with Route53"
  type        = bool
  default     = false
}

# Route 53 Domain Registration Variables
variable "register_new_domain" {
  description = "Whether to register a new domain via Route 53"
  type        = bool
  default     = false
}

variable "new_domain_name" {
  description = "New domain name to register (e.g., textract-poc-demo.com)"
  type        = string
  default     = "textract-poc-demo.com"
}

# Domain Contact Information (required for domain registration)
variable "domain_contact_first_name" {
  description = "First name for domain registration contact"
  type        = string
  default     = "John"
}

variable "domain_contact_last_name" {
  description = "Last name for domain registration contact"
  type        = string
  default     = "Doe"
}

variable "domain_contact_email" {
  description = "Email for domain registration contact"
  type        = string
  default     = "admin@example.com"
}

variable "domain_contact_phone" {
  description = "Phone number for domain registration contact (format: +1.1234567890)"
  type        = string
  default     = "+1.1234567890"
}

variable "domain_contact_address" {
  description = "Address for domain registration contact"
  type        = string
  default     = "123 Main St"
}

variable "domain_contact_city" {
  description = "City for domain registration contact"
  type        = string
  default     = "Anytown"
}

variable "domain_contact_state" {
  description = "State for domain registration contact"
  type        = string
  default     = "CA"
}

variable "domain_contact_zip" {
  description = "ZIP code for domain registration contact"
  type        = string
  default     = "12345"
}

variable "domain_contact_country" {
  description = "Country code for domain registration contact"
  type        = string
  default     = "US"
}

variable "domain_contact_organization" {
  description = "Organization name for domain registration contact"
  type        = string
  default     = "Textract PoC"
}
