#!/Users/allee/scratch/2024-10-25--clipboard-gpt/.venv/bin/python
import os
import sys

import openai
import pyperclip


def enhance_text():
    # Get API key from environment variable
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("Error: OPENAI_API_KEY environment variable not set")
        sys.exit(1)
    print("HI")
    sys.exit(0)

    # Configure OpenAI
    openai.api_key = api_key

    # Get text from clipboard
    text = pyperclip.paste()

    if not text:
        print("No text found in clipboard!")
        return

    try:
        # Make API call to OpenAI
        response = openai.chat.completions.create(
            model="gpt-4",  # You can adjust this if needed
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful assistant. Review and improve the following text, fixing any errors and enhancing clarity while maintaining the original meaning.",
                },
                {"role": "user", "content": text},
            ],
            temperature=0.7,
            max_tokens=1000,
        )

        # Extract the improved text
        improved_text = response.choices[0].message.content

        # Copy result back to clipboard
        print(improved_text.strip())

    except Exception as e:
        print(f"Error: {str(e)}")
        return


if __name__ == "__main__":
    enhance_text()
