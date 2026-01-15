#!/bin/bash

# Compile README.md to README.pdf
# Requires: pandoc and a LaTeX distribution (texlive)

set -e

INPUT="README.md"
OUTPUT="README.pdf"

# Check if pandoc is installed
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc is not installed."
    echo "Install with: sudo apt install pandoc"
    exit 1
fi

# Check if pdflatex is available (part of texlive)
if ! command -v pdflatex &> /dev/null; then
    echo "Error: pdflatex is not installed."
    echo "Install with: sudo apt install texlive-latex-base texlive-fonts-recommended"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT" ]; then
    echo "Error: $INPUT not found."
    exit 1
fi

echo "Compiling $INPUT to $OUTPUT..."

pandoc "$INPUT" \
    -o "$OUTPUT" \
    --pdf-engine=pdflatex \
    -V geometry:margin=1in \
    -V fontsize=11pt \
    --highlight-style=tango \
    --toc \
    -V toc-title="Table of Contents"

echo "Done! Created $OUTPUT"
