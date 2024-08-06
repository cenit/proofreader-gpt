
import fitz
import pytesseract
from PIL import Image
from openai import OpenAI
import os
import io
import sys

client = OpenAI()

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

def save_and_ocr_images(images, output_dir):
    image_paths = []
    ocr_texts = []
    for img_data, page_number, img_index in images:
        image = Image.open(io.BytesIO(img_data))
        image_path = os.path.join(output_dir, f'image_{page_number}_{img_index}.png')
        image.save(image_path)
        image_paths.append(image_path)

        ocr_text = pytesseract.image_to_string(image)
        ocr_texts.append(ocr_text)

    return image_paths, ocr_texts


def convert_text_to_markdown(text):
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
              {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": f"Convert the following text to Markdown format:\n\n{text}"}
        ],
        max_tokens=2048
    )
    markdown_text = response.choices[0].message.content
    return markdown_text

def generate_markdown_file(markdown_text, image_paths, output_md_path):
    with open(output_md_path, 'w') as md_file:
        md_file.write(markdown_text)
        md_file.write("\n\n")
        for idx, image_path in enumerate(image_paths):
            md_file.write(f"![Image {idx}](./{os.path.basename(image_path)})\n")

def pdf_to_markdown(pdf_path, output_md_path, images_dir):
    text, images = extract_text_and_images(pdf_path)
    image_paths, ocr_texts = save_and_ocr_images(images, images_dir)

    combined_text = text + "\n\n" + "\n\n".join(ocr_texts)

    markdown_text = convert_text_to_markdown(combined_text)
    generate_markdown_file(markdown_text, image_paths, output_md_path)


pdf_path = sys.argv[1]
output_md_path = 'output_document.md'
images_dir = 'images'
os.makedirs(images_dir, exist_ok=True)
pdf_to_markdown(pdf_path, output_md_path, images_dir)
print(f"Markdown document created at: {output_md_path}")
