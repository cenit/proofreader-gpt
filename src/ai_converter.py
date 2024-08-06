import fitz
from PIL import Image
import os
import io
import sys
from base64 import b64encode

use_azure = False

if use_azure:
    from openai import AzureOpenAI

    client = AzureOpenAI(
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        api_version="2024-02-01"
    )
else:
    from openai import OpenAI
    client = OpenAI()

MAX_TOKENS = 4096

def extract_text_and_images(pdf_path):
    pdf_document = fitz.open(pdf_path)
    text = ""
    images = []

    for page_number in range(len(pdf_document)):
        page = pdf_document.load_page(page_number)
        text += page.get_text()

        for img_index, img in enumerate(page.get_images(full=True)):
            xref = img[0]
            base_image = pdf_document.extract_image(xref)
            image_bytes = base_image["image"]
            images.append((image_bytes, page_number, img_index))

    return text, images


def save_images(images, output_dir):
    image_paths = []
    for img_data, page_number, img_index in images:
        image = Image.open(io.BytesIO(img_data))
        image_path = os.path.join(
            output_dir, f'image_{page_number}_{img_index}.png')
        image.save(image_path)
        image_paths.append(image_path)
    return image_paths


def tokenize_text(text):
    return text.split()


def split_text_and_images(text, images, max_tokens=MAX_TOKENS):
    words = tokenize_text(text)
    text_chunks = []
    images_chunks = []

    current_chunk = ""
    current_images = []
    current_tokens = 0

    for word in words:
        word_tokens = len(word.split())  # Approximate token count
        if current_tokens + word_tokens > max_tokens:
            text_chunks.append(current_chunk.strip())
            images_chunks.append(current_images)
            current_chunk = word + " "
            current_tokens = word_tokens
            current_images = []
        else:
            current_chunk += word + " "
            current_tokens += word_tokens

    if current_chunk:
        text_chunks.append(current_chunk.strip())
        images_chunks.append(current_images)

    images_per_chunk = len(images) // len(text_chunks) + 1
    for i in range(len(text_chunks)):
        images_chunks[i] = images[i*images_per_chunk: (i+1)*images_per_chunk]

    return text_chunks, images_chunks


def convert_text_and_images_to_markdown(text, images):
    image_data = [b64encode(img).decode('utf-8') for img, _, _ in images]

    messages = [
        {"role": "system", "content": "You are a helpful assistant that corrects typos, errors, and formatting in documents. You convert from PDF to markdown, inspecting also images for text"},
        {"role": "user", "content": [{"type": "text", "text": f"Convert the following text and images to Markdown format:\n\n{text}"}, {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}]}
    ]

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages,
        max_tokens=MAX_TOKENS
    )
    return response.choices[0].message.content


def generate_markdown_file(markdown_text, image_paths, output_md_path):
    with open(output_md_path, 'w') as md_file:
        md_file.write(markdown_text)
        md_file.write("\n\n")
        for idx, image_path in enumerate(image_paths):
            md_file.write(
                f"![Image {idx}](./{os.path.basename(image_path)})\n")


def pdf_to_markdown(pdf_path, output_md_path, images_dir):
    text, images = extract_text_and_images(pdf_path)
    image_paths = save_images(images, images_dir)

    text_chunks, images_chunks = split_text_and_images(text, images)

    markdown_texts = []
    for i in range(len(text_chunks)):
        markdown_text = convert_text_and_images_to_markdown(
            text_chunks[i], images_chunks[i])
        markdown_texts.append(markdown_text)

    combined_markdown_text = "\n\n".join(markdown_texts)
    generate_markdown_file(combined_markdown_text, image_paths, output_md_path)


if __name__ == "__main__":
    pdf_path = sys.argv[1]
    output_md_path = 'output_document.md'
    images_dir = 'images'
    os.makedirs(images_dir, exist_ok=True)
    pdf_to_markdown(pdf_path, output_md_path, images_dir)
    print(f"Markdown document created at: {output_md_path}")
