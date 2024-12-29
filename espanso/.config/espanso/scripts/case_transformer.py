#!/usr/bin/python3

import sys

def to_title_case(text):
    return text.title()

def to_snake_case(text):
    return text.replace(" ", "_").lower()

def to_kebab_case(text):
    return text.replace(" ", "-").lower()

def to_camel_case(text):
    words = text.split()
    return words[0].lower() + ''.join(word.capitalize() for word in words[1:])

def transform_text(text, case_type):
    if case_type == "title":
        return to_title_case(text)
    elif case_type == "snake":
        return to_snake_case(text)
    elif case_type == "kebab":
        return to_kebab_case(text)
    elif case_type == "camel":
        return to_camel_case(text)
    else:
        return text

if __name__ == "__main__":
    clipboard_text = sys.argv[1]
    case_type = sys.argv[2]
    print(transform_text(clipboard_text, case_type)) 