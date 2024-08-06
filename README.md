# PDF to Markdown Converter

This repository contains two Python scripts, `ai_converter.py` and `ai_fixer.py`, which work together to convert PDF documents or already converted markdown documents into properly formatted Markdown documents.

## Files

### ai_converter.py

This script handles the conversion of PDF documents to Markdown format, including extracting text and images from the PDF, splitting the text into manageable chunks, and converting the text and images to Markdown.

#### Key Functions

- `extract_text_and_images(pdf_path)`: Extracts text and images from the specified PDF file.
- `save_images(images, output_dir)`: Saves extracted images to the specified directory.
- `tokenize_text(text)`: Tokenizes the input text.
- `split_text_and_images(text, images, max_tokens)`: Splits the text and images into chunks based on the maximum token size.
- `convert_text_and_images_to_markdown(text, images)`: Converts text and images to Markdown format using the OpenAI API.
- `generate_markdown_file(markdown_text, image_paths, output_md_path)`: Generates a Markdown file from the converted text and images.
- `pdf_to_markdown(pdf_path, output_md_path, images_dir)`: Main function to convert a PDF to Markdown.

### ai_fixer.py

This script processes pre-generated but low-quality Markdown file to correct any typos, errors, and formatting issues.

#### Key Functions

- `split_text_into_chunks(text, max_chunk_size)`: Splits the input text into chunks of a specified maximum size.
- `process_chunk(chunk)`: Sends a text chunk to the OpenAI API and returns the corrected text.
- `process_document(input_path, output_path, max_chunk_size)`: Processes the entire document in chunks and saves the corrected text.

## Usage

### Prerequisites

- Python 3.x
- Required Python packages: `openai`, `fitz` (PyMuPDF), `PIL` (Pillow)

Install the required packages using pip:

```bash
pip install openai pymupdf pillow
```

## Converting a PDF to Markdown

1. Place your PDF file in the desired directory.
2. Run the `ai_converter.py` script with the appropriate arguments:

```bash
python ai_converter.py <path_to_pdf> 
```

## Fixing the Markdown File

1. Run the `ai_fixer.py` script with the appropriate arguments:

```bash
python ai_fixer.py <input_markdown_file>
```

## License

This project is licensed under the MIT License. See the LICENSE file for details.
