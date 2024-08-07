from PIL import Image, UnidentifiedImageError
import fitz
from PIL import Image
import os
import io
from base64 import b64encode
from termcolor import colored
import argparse

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
        try:
            if image.mode == 'CMYK':
                image = image.convert('RGB')
            image.save(image_path)
            image_paths.append(image_path)
        except (OSError, UnidentifiedImageError) as e:
            print(f"Error saving image {page_number}_{img_index}: {e}")
            image_paths.append("broken_image")
            continue
    return image_paths


def tokenize_text(text):
    return text.split()


def split_text(text, max_tokens=MAX_TOKENS):
    words = tokenize_text(text)
    text_chunks = []
    current_chunk = ""
    current_tokens = 0

    for word in words:
        word_tokens = len(word.split())  # Approximate token count
        if current_tokens + word_tokens > max_tokens:
            text_chunks.append(current_chunk.strip())
            current_chunk = word + " "
            current_tokens = word_tokens
        else:
            current_chunk += word + " "
            current_tokens += word_tokens

    if current_chunk:
        text_chunks.append(current_chunk.strip())

    return text_chunks


def convert_text_to_markdown(text, strings_to_remove=None):
    messages = [
        {"role": "system",
            "content": f"You are a helpful assistant that corrects typos, errors, and formatting in documents. You convert from PDF to markdown. You are now given a text bulk-extracted from a document; it might have lost formatting and might also have missing chars, unreadable ones, typographical errors or even syntax and grammatical ones that must be removed. You should write your output using Markdown syntax, with nice formatting. If you find any boilerplate or anything similar to the following list of strings, maybe also written in other languages even different from the rest of the document, you should just remove them from your output. Also any printing date, version, or similar information should be removed: {strings_to_remove}. Similarly, any personal name, email address or telephone number should be removed and any section that can be described as an address book should just be skipped."},
        {"role": "user", "content": f"Convert the following text to Markdown format:\n\n{text}"}
    ]

    response = client.chat.completions.create(
        model=openai_model,
        messages=messages,
        max_tokens=MAX_TOKENS
    )
    return response.choices[0].message.content


def convert_image_to_markdown(image_data):
    image_b64 = b64encode(image_data).decode('utf-8')

    messages = [
        {
            "role": "system",
            "content": "You are a helpful assistant that corrects typos, errors, and formatting in documents. You are converting a PDF to markdown, inspecting also images for text. You are now given an image, if it is a text image, you should convert it to markdown, otherwise, you should ignore it."
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{image_b64}",
                        "detail": "high"
                    }
                }
            ]
        }
    ]

    response = client.chat.completions.create(
        model=openai_model,
        messages=messages,
        max_tokens=MAX_TOKENS
    )
    return response.choices[0].message.content


def generate_markdown_file(markdown_text, output_md_path):
    with open(output_md_path, 'w', encoding='utf-8') as md_file:
        md_file.write(markdown_text)


def pdf_to_markdown(pdf_path, output_md_path, images_dir, strings_to_remove=None, skip_images=False):
    text, images = extract_text_and_images(pdf_path)
    image_paths = save_images(images, images_dir)

    text_chunks = split_text(text)
    markdown_texts = []
    for i in range(len(text_chunks)):
        markdown_text = convert_text_to_markdown(text_chunks[i], strings_to_remove)
        markdown_texts.append(markdown_text)

    if len(images) != len(image_paths):
        raise ValueError("Number of images extracted does not match number of image paths saved")
    markdown_texts.append(f"\n\n## Images\n\n")
    for idx, image_path in enumerate(image_paths):
        if skip_images:
            markdown_text = ""
        else:
            markdown_text = convert_image_to_markdown(images[idx][0])
        markdown_texts.append(f"![Image {idx}](./images/{os.path.basename(image_path)})\n" + markdown_text)

    combined_markdown_text = "\n\n".join(markdown_texts)
    generate_markdown_file(combined_markdown_text, output_md_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert a PDF document into Markdown using OpenAI')
    parser.add_argument('--debug', dest='debug', default=False, action='store_true', help='Enable verbose output', required=False)
    parser.add_argument('--skip-images', dest='skip_images', default=False, action='store_true', help='Skip image processing for text extraction', required=False)
    parser.add_argument('--json', dest='jsonFile', help='Define the json config file', required=False, default='strings_to_skip.json')
    parser.add_argument('--pdf', dest='pdfFile', help='Define the input PDF file', required=True)
    parser.add_argument('--md', dest='mdFile', help='Define the output MD file', required=True)
    parser.add_argument('--images', dest='imgFolder', help='Define the output images folder', required=True)
    args = parser.parse_args()

    if os.path.exists(args.jsonFile):
        import json
        with open(args.jsonFile, "r") as f:
            strings_to_skip = json.load(f)
            strings_to_skip = strings_to_skip["strings_to_skip"]
    else:
        strings_to_skip = None

    os.makedirs(args.imgFolder, exist_ok=True)
    pdf_to_markdown(args.pdfFile, args.mdFile, args.imgFolder, strings_to_skip, args.skip_images)
    print(colored(f"Markdown document created at: {args.mdFile}", "green"))
