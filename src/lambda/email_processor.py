import json
import boto3
import email
import os
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase

# Initialize AWS clients
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to process emails received via SES:
    1. Parse email from S3
    2. Extract PDF attachments
    3. Save PDFs to incoming/ folder for Textract processing
    """
    
    try:
        # Parse S3 event
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            print(f"Processing email: {object_key} from bucket: {bucket_name}")
            
            # Skip if not in emails/ folder
            if not object_key.startswith('emails/'):
                print(f"Skipping non-email file: {object_key}")
                continue
            
            # Download email from S3
            response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
            email_content = response['Body'].read()
            
            # Parse email
            msg = email.message_from_bytes(email_content)
            
            # Extract PDF attachments
            pdf_count = 0
            for part in msg.walk():
                if part.get_content_disposition() == 'attachment':
                    filename = part.get_filename()
                    if filename and filename.lower().endswith('.pdf'):
                        # Extract PDF content
                        pdf_content = part.get_payload(decode=True)
                        
                        # Generate unique filename
                        timestamp = context.aws_request_id[:8]
                        pdf_key = f"incoming/{timestamp}_{filename}"
                        
                        # Save PDF to incoming/ folder
                        s3_client.put_object(
                            Bucket=bucket_name,
                            Key=pdf_key,
                            Body=pdf_content,
                            ContentType='application/pdf'
                        )
                        
                        print(f"Extracted PDF: {pdf_key}")
                        pdf_count += 1
            
            # Log email metadata
            email_metadata = {
                'from': msg.get('From'),
                'to': msg.get('To'),
                'subject': msg.get('Subject'),
                'date': msg.get('Date'),
                'pdf_attachments_extracted': pdf_count,
                'original_email_key': object_key
            }
            
            # Save metadata
            metadata_key = object_key.replace('emails/', 'metadata/').replace('.txt', '_metadata.json')
            s3_client.put_object(
                Bucket=bucket_name,
                Key=metadata_key,
                Body=json.dumps(email_metadata, indent=2),
                ContentType='application/json'
            )
            
            print(f"Email metadata saved: {metadata_key}")
            print(f"Extracted {pdf_count} PDF attachments")
            
        return {
            'statusCode': 200,
            'body': json.dumps(f'Email processing completed. Extracted {pdf_count} PDFs.')
        }
        
    except Exception as e:
        print(f"Error processing email: {str(e)}")
        raise e
