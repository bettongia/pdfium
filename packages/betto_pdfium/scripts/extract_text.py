#!/usr/bin/env python3
# Copyright 2026 The Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Extract plain text from PDF files in test/data/.

Walks the test/data/ directory tree, extracts text from every .pdf file
using pypdf, and writes the result to a .json file alongside each PDF
(same directory, same base name, .json extension). The JSON format matches
the text output of the pdfinfo.dart --json flag: an array of page objects,
each with pageIndex, hasTextLayer, hasUnicodeErrors, and text fields.

Usage:
  python3 extract_text.py [path ...]

  With no arguments, scans all .pdf files under test/data/.
  With one or more path arguments, processes those paths (files or directories).

Examples:
  python3 extract_text.py
  python3 extract_text.py test/data/arxiv/2605.16085v1.pdf
  python3 extract_text.py test/data/arxiv/

Output:
  test/data/arxiv/2605.16085v1.pdf  ->  test/data/arxiv/2605.16085v1.json

  JSON structure:
  [
    {
      "pageIndex": 0,
      "hasTextLayer": true,
      "hasUnicodeErrors": false,
      "text": "..."
    },
    ...
  ]

Requires: pypdf (pip install pypdf)
"""

import json
import os
import sys


DATA_DIR = os.path.join(os.path.dirname(__file__), "test", "data")


def _pdf_files(paths):
    """Yield absolute paths to every .pdf file reachable from *paths*."""
    for path in paths:
        path = os.path.abspath(path)
        if os.path.isfile(path):
            if path.lower().endswith(".pdf"):
                yield path
        elif os.path.isdir(path):
            for root, _dirs, files in os.walk(path):
                for name in sorted(files):
                    if name.lower().endswith(".pdf"):
                        yield os.path.join(root, name)
        else:
            print(f"WARNING: {path!r} does not exist, skipping.", file=sys.stderr)


def extract(pdf_path):
    """Return a list of page dicts for *pdf_path*, or raise on fatal error.

    Each dict matches the pdfinfo.dart --json text page structure:
      pageIndex (int), hasTextLayer (bool), hasUnicodeErrors (bool), text (str).

    hasTextLayer mirrors the Dart heuristic: True when extracted text is
    non-empty.  hasUnicodeErrors is True when the extracted text contains
    the Unicode replacement character (U+FFFD).
    """
    from pypdf import PdfReader
    from pypdf.errors import PdfReadError

    try:
        reader = PdfReader(pdf_path)
        if reader.is_encrypted:
            # Attempt decryption with no password, then common test passwords.
            for pwd in ("", "test", "owner"):
                result = reader.decrypt(pwd)
                if result.value > 0:
                    break
            else:
                return [{"pageIndex": 0, "hasTextLayer": False, "hasUnicodeErrors": False, "text": "<encrypted: could not decrypt>"}]

        pages = []
        for i, page in enumerate(reader.pages):
            text = page.extract_text() or ""
            pages.append({
                "pageIndex": i,
                "hasTextLayer": bool(text),
                "hasUnicodeErrors": "�" in text,
                "text": text,
            })
        return pages
    except PdfReadError as exc:
        return [{"pageIndex": 0, "hasTextLayer": False, "hasUnicodeErrors": False, "text": f"<PdfReadError: {exc}>"}]
    except Exception as exc:  # noqa: BLE001
        return [{"pageIndex": 0, "hasTextLayer": False, "hasUnicodeErrors": False, "text": f"<error: {type(exc).__name__}: {exc}>"}]


def main():
    try:
        from pypdf import PdfReader  # noqa: F401
    except ImportError:
        sys.exit("ERROR: pypdf is not installed. Run: pip install pypdf")

    roots = sys.argv[1:] or [DATA_DIR]
    files = list(_pdf_files(roots))

    if not files:
        print("No PDF files found.", file=sys.stderr)
        sys.exit(1)

    for pdf_path in files:
        rel = os.path.relpath(pdf_path)
        json_path = os.path.splitext(pdf_path)[0] + ".json"
        json_rel = os.path.relpath(json_path)
        pages = extract(pdf_path)
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(pages, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"{rel}  ->  {json_rel}")

    print(f"\nDone. {len(files)} file(s) processed.")


if __name__ == "__main__":
    main()
