import sys
import os

use_azure = True

if use_azure:
    from openai import AzureOpenAI
    openai_model = os.getenv("AZURE_OPENAI_DEPLOYMENT_MODEL")
    client = AzureOpenAI(
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        api_version="2024-02-01"
    )
else:
    from openai import OpenAI
    openai_model = "gpt-4o"
    client = OpenAI()

def split_text_into_chunks(text, max_chunk_size):
    """Splits the input text into chunks of a specified maximum size."""
    chunks = []
    while len(text) > max_chunk_size:
        # Find the last newline character within the maximum chunk size
        split_pos = text.rfind('\n', 0, max_chunk_size)
        if split_pos == -1:
            # If no newline character is found, split at max_chunk_size
            split_pos = max_chunk_size
        chunks.append(text[:split_pos])
        text = text[split_pos:].lstrip('\n')
    chunks.append(text)
    return chunks

def process_chunk(chunk):
    """Sends a text chunk to the OpenAI API and returns the corrected text."""
    response = client.chat.completions.create(
        model=openai_model,
        messages=[
            {"role": "system", "content": "You are a helpful assistant that corrects typos, errors, and formatting in markdown documents."},
            {"role": "user", "content": chunk}
        ]
    )
    return response.choices[0].message.content

def process_document(input_path, output_path, max_chunk_size=2048):
    """Processes the entire document in chunks and saves the corrected text."""
    with open(input_path, 'r') as file:
        text = file.read()

    chunks = split_text_into_chunks(text, max_chunk_size)
    corrected_chunks = [process_chunk(chunk) for chunk in chunks]
    corrected_text = '\n'.join(corrected_chunks)

    with open(output_path, 'w') as file:
        file.write(corrected_text)


input_path = sys.argv[1]
output_path = 'output_markdown.md'
process_document(input_path, output_path)
