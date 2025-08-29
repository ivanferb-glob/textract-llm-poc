# Route 53 Domain Registration and DNS Configuration
# This creates a new domain for the PoC if you don't have an existing one

# Register a new domain (optional - only if you don't have a domain)
resource "aws_route53domains_registered_domain" "textract_domain" {
  count       = var.register_new_domain ? 1 : 0
  domain_name = var.new_domain_name

  # Domain registration contact information
  admin_contact {
    address_line_1    = var.domain_contact_address
    city              = var.domain_contact_city
    country_code      = var.domain_contact_country
    email             = var.domain_contact_email
    first_name        = var.domain_contact_first_name
    last_name         = var.domain_contact_last_name
    phone_number      = var.domain_contact_phone
    state             = var.domain_contact_state
    zip_code          = var.domain_contact_zip
    organization_name = var.domain_contact_organization
  }

  registrant_contact {
    address_line_1    = var.domain_contact_address
    city              = var.domain_contact_city
    country_code      = var.domain_contact_country
    email             = var.domain_contact_email
    first_name        = var.domain_contact_first_name
    last_name         = var.domain_contact_last_name
    phone_number      = var.domain_contact_phone
    state             = var.domain_contact_state
    zip_code          = var.domain_contact_zip
    organization_name = var.domain_contact_organization
  }

  tech_contact {
    address_line_1    = var.domain_contact_address
    city              = var.domain_contact_city
    country_code      = var.domain_contact_country
    email             = var.domain_contact_email
    first_name        = var.domain_contact_first_name
    last_name         = var.domain_contact_last_name
    phone_number      = var.domain_contact_phone
    state             = var.domain_contact_state
    zip_code          = var.domain_contact_zip
    organization_name = var.domain_contact_organization
  }

  auto_renew = false  # Set to false for PoC to avoid automatic charges
  
  tags = {
    Name        = "${var.project_name}-domain"
    Environment = "poc"
  }
}

# Create Route 53 Hosted Zone (only when registering a new domain)
resource "aws_route53_zone" "textract_zone" {
  count = var.enable_ses && var.register_new_domain ? 1 : 0
  name  = aws_route53domains_registered_domain.textract_domain[0].domain_name

  tags = {
    Name        = "${var.project_name}-zone"
    Environment = "poc"
  }
}

# SES Domain Verification Record (only when registering a new domain)
resource "aws_route53_record" "ses_verification" {
  count   = var.enable_ses && var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.textract_zone[0].zone_id
  name    = "_amazonses.${aws_route53_zone.textract_zone[0].name}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.textract_domain[0].verification_token]
}

# DKIM Records for SES (only when registering a new domain)
resource "aws_route53_record" "ses_dkim" {
  count   = var.enable_ses && var.register_new_domain ? 3 : 0  # SES always generates 3 DKIM tokens
  zone_id = aws_route53_zone.textract_zone[0].zone_id
  name    = "${aws_ses_domain_dkim.textract_domain_dkim[0].dkim_tokens[count.index]}._domainkey.${aws_route53_zone.textract_zone[0].name}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.textract_domain_dkim[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# MX Record for SES Email Receiving (only when registering a new domain)
resource "aws_route53_record" "ses_mx" {
  count   = var.enable_ses && var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.textract_zone[0].zone_id
  name    = aws_route53_zone.textract_zone[0].name
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.${var.aws_region}.amazonaws.com"]
}

# SPF Record for email authentication (only when registering a new domain)
resource "aws_route53_record" "ses_spf" {
  count   = var.enable_ses && var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.textract_zone[0].zone_id
  name    = aws_route53_zone.textract_zone[0].name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# DMARC Record for email security (only when registering a new domain)
resource "aws_route53_record" "ses_dmarc" {
  count   = var.enable_ses && var.register_new_domain ? 1 : 0
  zone_id = aws_route53_zone.textract_zone[0].zone_id
  name    = "_dmarc.${aws_route53_zone.textract_zone[0].name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@${aws_route53_zone.textract_zone[0].name}"]
}

# Output the name servers for domain configuration
output "route53_name_servers" {
  description = "Name servers for the Route 53 hosted zone"
  value       = var.enable_ses && var.register_new_domain ? aws_route53_zone.textract_zone[0].name_servers : null
}

output "registered_domain_name" {
  description = "The registered domain name (if created)"
  value       = var.register_new_domain ? aws_route53domains_registered_domain.textract_domain[0].domain_name : null
}

output "domain_registration_status" {
  description = "Status of domain registration"
  value       = var.register_new_domain ? "Domain registered via Route 53" : "Using email identity verification"
}

output "email_address_ready" {
  description = "Email address ready for use"
  value       = var.enable_ses ? var.ses_email_address : null
}
