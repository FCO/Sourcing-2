#!/usr/bin/env python3
"""Extract mermaid diagrams from SPEC.md"""

import re
import sys

def extract_mermaid_blocks(md_file):
    """Extract all mermaid diagram blocks from markdown file."""
    with open(md_file, 'r') as f:
        content = f.read()
    
    # Pattern to match mermaid code blocks with optional title
    pattern = r'```mermaid(?:\s*\w+)?\n(.*?)```'
    matches = re.findall(pattern, content, re.DOTALL)
    
    return matches

def main():
    md_file = 'SPEC.md'
    blocks = extract_mermaid_blocks(md_file)
    
    print(f"Found {len(blocks)} mermaid diagrams:")
    for i, block in enumerate(blocks):
        # Get first line as identifier
        first_line = block.strip().split('\n')[0]
        print(f"\n{i+1}. {first_line}")
        print("-" * 40)
        print(block.strip()[:200] + "...")

if __name__ == '__main__':
    main()
