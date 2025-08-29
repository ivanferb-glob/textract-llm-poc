#!/usr/bin/env python3
"""
Create a test PDF file for Textract processing
"""
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

def create_test_pdf():
    filename = "test_document.pdf"
    
    # Create PDF
    c = canvas.Canvas(filename, pagesize=letter)
    width, height = letter
    
    # Add content
    c.setFont("Helvetica-Bold", 16)
    c.drawString(100, height - 100, "Test Document for AWS Textract")
    
    c.setFont("Helvetica", 12)
    c.drawString(100, height - 140, "Invoice #: INV-2024-001")
    c.drawString(100, height - 160, "Date: January 15, 2024")
    c.drawString(100, height - 180, "Customer: Acme Corporation")
    
    c.drawString(100, height - 220, "Items:")
    c.drawString(120, height - 240, "• Software License - $500.00")
    c.drawString(120, height - 260, "• Support Services - $200.00")
    c.drawString(120, height - 280, "• Training - $300.00")
    
    c.drawString(100, height - 320, "Total Amount: $1,000.00")
    c.drawString(100, height - 340, "Payment Terms: Net 30 days")
    
    c.drawString(100, height - 380, "This is a test document containing structured")
    c.drawString(100, height - 400, "information that AWS Textract can extract.")
    
    c.save()
    print(f"Created {filename}")

if __name__ == "__main__":
    create_test_pdf()