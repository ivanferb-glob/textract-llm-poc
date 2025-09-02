import json
import boto3
import os
import urllib.request
import urllib.parse
from urllib.parse import unquote_plus

# Initialize AWS clients
s3_client = boto3.client('s3')
textract_client = boto3.client('textract')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event, context):
    """
    Lambda function to process PDF files uploaded to S3:
    1. Extract text using Amazon Textract
    2. Convert to JSON format
    3. Send to LLM API for processing
    4. Store results back to S3
    """
    
    try:
        # Parse S3 event
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            print(f"Processing file: {object_key} from bucket: {bucket_name}")
            
            # Skip if not a PDF file
            if not object_key.lower().endswith('.pdf'):
                print(f"Skipping non-PDF file: {object_key}")
                continue
            
            # Extract text from PDF using Textract
            textract_response = textract_client.detect_document_text(
                Document={
                    'S3Object': {
                        'Bucket': bucket_name,
                        'Name': object_key
                    }
                }
            )
            
            # Process Textract response into structured JSON
            extracted_text = extract_text_from_textract(textract_response)
            
            # Create JSON structure
            json_data = {
                'source_file': object_key,
                'extracted_text': extracted_text,
                'textract_blocks': textract_response['Blocks'],
                'processing_timestamp': context.aws_request_id
            }
            
            # Store JSON to S3
            json_key = object_key.replace('incoming/', 'processed/').replace('.pdf', '.json')
            s3_client.put_object(
                Bucket=bucket_name,
                Key=json_key,
                Body=json.dumps(json_data, indent=2),
                ContentType='application/json'
            )
            
            print(f"JSON stored at: {json_key}")
            
            # Send to LLM API
            llm_response = send_to_llm_api(json_data)
            
            # Store LLM response
            if llm_response:
                response_key = json_key.replace('.json', '_llm_response.json')
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=response_key,
                    Body=json.dumps(llm_response, indent=2),
                    ContentType='application/json'
                )
                print(f"LLM response stored at: {response_key}")
            
        return {
            'statusCode': 200,
            'body': json.dumps('Processing completed successfully')
        }
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise e

def extract_text_from_textract(textract_response):
    words = [
        {
            "text": block["Text"],
            "left": block["Geometry"]["BoundingBox"]["Left"],
            "top": block["Geometry"]["BoundingBox"]["Top"],
            "width": block["Geometry"]["BoundingBox"]["Width"],
        }
        for block in textract_response["Blocks"]
        if block["BlockType"] == "WORD"
    ]
    words.sort(key=lambda x: (x["top"], x["left"]))

    lines = []
    current_line = []
    current_line_top = None
    line_spacing_threshold = 0.005  # Adjust for line detection

    for word in words:
        if (
            current_line_top is None
            or abs(word["top"] - current_line_top) < line_spacing_threshold
        ):
            current_line.append(word)
            current_line_top = word["top"]
        else:
            current_line.sort(key=lambda x: x["left"])
            lines.append(current_line)
            current_line = [word]
            current_line_top = word["top"]
    if current_line:
        current_line.sort(key=lambda x: x["left"])
        lines.append(current_line)

    formatted_text = ""
    space_threshold = 0.0000000001  # Adjust this threshold for word spacing

    for line in lines:
        line_text = ""
        prev_word = None

        for word in line:
            if prev_word:
                space_gap = word["left"] - (prev_word["left"] + prev_word["width"])
                if space_gap > space_threshold:
                    line_text += " "
            line_text += word["text"]
            prev_word = word

        formatted_text += line_text + "\n"

    return formatted_text.strip()

def send_to_llm_api(json_data):
    """Send extracted JSON to LLM API for processing"""
    try:
        # Get API credentials from Secrets Manager
        secret_name = os.environ['API_SECRET_NAME']
        secret_response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_data = json.loads(secret_response['SecretString'])
        
        api_key = secret_data['api_key']
        api_url = secret_data['api_url']
        
        # Prepare API request
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'saia:agent:InvoiceIQ',  # Adjust based on your LLM service
            'messages': [
                {
                    'role': 'system',
                    'content': 'You are a document processing assistant. Analyze the extracted text and provide insights or take actions based on the content.'
                },
                {
                    'role': 'user',
                    'content': f'Please analyze this extracted document text: {json_data["extracted_text"]}'
                }
            ]
        }
        
        # Make API request using urllib
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(api_url, data=data, headers=headers)
        
        with urllib.request.urlopen(req, timeout=30) as response:
            response_data = response.read().decode('utf-8')
            return json.loads(response_data)
        
    except Exception as e:
        print(f"Error calling LLM API: {str(e)}")
        return None
