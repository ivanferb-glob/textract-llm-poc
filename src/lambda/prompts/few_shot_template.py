EXAMPLE_1_INPUT = """
Test Document for AWS Textract
Invoice #: INV-2024-001
Date: January 15, 2024
Customer: Acme Corporation
Items:
• Software License - $500.00
• Support Services - $200.00
• Training - $300.00
Total Amount: $1,000.00
Payment Terms: Net 30 days
This is a test document containing structured
information that AWS Textract can extract.
"""

# Refine output based on example
EXAMPLE_1_OUTPUT = """
{
  "document_title": "Test Document for AWS Textract",
  "invoice_number": "INV-2024-001",
  "date": "January 15, 2024",
  "customer": "Acme Corporation",
  "items": [
    {
      "description": "Software License",
      "amount": 500.00
    },
    {
      "description": "Support Services",
      "amount": 200.00
    },
    {
      "description": "Training",
      "amount": 300.00
    }
  ],
  "total_amount": 1000.00,
  "payment_terms": "Net 30 days",
  "additional_info": "This is a test document containing structured information that AWS Textract can extract."
}
"""