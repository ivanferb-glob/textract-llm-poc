# Email Receiving Setup Guide

## Required DNS Configuration for Email Receiving

To receive emails with PDF attachments, you must configure these DNS records:

### 1. Domain Verification (TXT Record)
```
Name: _amazonses.your-domain.com
Type: TXT
Value: [verification_token from terraform output]
```

### 2. DKIM Authentication (3 CNAME Records)
```
Name: [dkim_token_1]._domainkey.your-domain.com
Type: CNAME
Value: [dkim_token_1].dkim.amazonses.com

Name: [dkim_token_2]._domainkey.your-domain.com
Type: CNAME
Value: [dkim_token_2].dkim.amazonses.com

Name: [dkim_token_3]._domainkey.your-domain.com
Type: CNAME
Value: [dkim_token_3].dkim.amazonses.com
```

### 3. MX Record (Email Receiving)
```
Name: your-domain.com
Type: MX
Priority: 10
Value: inbound-smtp.[region].amazonaws.com
```

## Setup Steps

1. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```

2. **Get DNS Configuration Values**:
   ```bash
   terraform output ses_domain_verification_token
   terraform output ses_dkim_tokens
   terraform output ses_mx_record
   ```

3. **Add DNS Records** to your domain provider using the values from step 2

4. **Wait for Verification** (can take up to 72 hours)

5. **Test Email Receiving**:
   ```
   To: documents@your-domain.com
   Subject: Test PDF Processing
   Attachment: test.pdf
   ```

## Automatic DNS Management

Set `manage_dns = true` in terraform.tfvars to automatically create Route53 records (requires domain to be managed by Route53).