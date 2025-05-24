#!/usr/bin/env bash
#
# batch-ocr.sh — add a searchable text layer to every PDF in a directory
#
#   New flag
#   ──────────────────────────────────────────────────────────────────
#   -t   After OCR, run `pdftotext -layout` and save  filename-searchable.txt
#
#   Other flags
#   ──────────────────────────────────────────────────────────────────
#   -r   Recurse into sub‑directories
#
#   The script now checks for `pdftotext` only if -t is supplied.
#
#   Usage examples
#   ──────────────────────────────────────────────────────────────────
#     ./batch-ocr.sh                # OCR only
#     ./batch-ocr.sh -t             # OCR + text extraction
#     ./batch-ocr.sh -r -t ~/docs   # OCR recursively + text
#
#   Dependencies (auto‑checked)
#     • ocrmypdf   • tesseract   • pdftotext (only with -t)
#
#   Author: ChatGPT (April 2025)

set -euo pipefail

##############################################################################
# 0. Helper — dependency checker
##############################################################################
need_cmd() { command -v "$1" >/dev/null 2>&1; }

require() {
  local bin=$1
  need_cmd "$bin" && return
  echo -e "\n✖  Missing required command: $bin\n" >&2
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "→ macOS install (Homebrew):  brew install $2" >&2
  elif [[ -f /etc/debian_version ]]; then
    echo "→ Debian/Ubuntu install:     sudo apt install $3" >&2
  else
    echo "→ See upstream docs for install instructions." >&2
  fi
  exit 1
}

##############################################################################
# 1. Parse flags
##############################################################################
RECURSE=false
EXTRACT_TEXT=false

while getopts ":rt" opt; do
  case $opt in
    r) RECURSE=true ;;
    t) EXTRACT_TEXT=true ;;
    *) echo "Usage: $0 [-r] [-t] [directory]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

DIR="${1:-.}"
[[ -d "$DIR" ]] || { echo "Directory not found: $DIR" >&2; exit 1; }

##############################################################################
# 2. Dependency checks
##############################################################################
require ocrmypdf ocrmypdf ocrmypdf
require tesseract tesseract tesseract-ocr
if $EXTRACT_TEXT; then
  require pdftotext poppler poppler-utils
fi

##############################################################################
# 3. Collect PDFs
##############################################################################
if $RECURSE; then
  mapfile -t PDFS < <(find "$DIR" -type f -iname '*.pdf' | sort)
else
  mapfile -t PDFS < <(find "$DIR" -maxdepth 1 -type f -iname '*.pdf' | sort)
fi

[[ ${#PDFS[@]} -eq 0 ]] && { echo "No PDFs found in $DIR"; exit 0; }
echo "Found ${#PDFS[@]} PDFs … starting OCR"

##############################################################################
# 4. OCR + optional text extraction
##############################################################################
for SRC in "${PDFS[@]}"; do
  OUT_PDF="${SRC%.pdf}-searchable.pdf"

  if [[ -s "$OUT_PDF" ]]; then
    echo "✔︎  Skipping (exists): $(basename "$OUT_PDF")"
  else
    echo "→  OCRing $(basename "$SRC") …"
    ocrmypdf \
        --deskew \
        --rotate-pages \
        --optimize 3 \
        --language eng \
        "$SRC" "$OUT_PDF"
  fi

  if $EXTRACT_TEXT; then
    OUT_TXT="${OUT_PDF%.pdf}.txt"
    if [[ -s "$OUT_TXT" ]]; then
      echo "✔︎  Skipping text (exists): $(basename "$OUT_TXT")"
    else
      echo "→  Extracting text to $(basename "$OUT_TXT")"
      pdftotext -layout "$OUT_PDF" "$OUT_TXT"
    fi
  fi
done

echo "🎉  All done!"
