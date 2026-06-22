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

"""Extract metadata from PDF files in test/data/.

Walks the test/data/ directory tree, extracts metadata from every .pdf file
using pypdf, and writes the result to a .meta.json file alongside each PDF
(same directory, same base name, .meta.json extension). Progress is printed to
stdout.

The output JSON contains two top-level keys:
  "info"  — standard PDF Info dictionary fields (str values, null if absent)
  "xmp"   — selected XMP fields (str / list / null)

Usage:
  python3 extract_meta.py [path ...]

  With no arguments, scans all .pdf files under test/data/.
  With one or more path arguments, processes those paths (files or directories).

Examples:
  python3 extract_meta.py
  python3 extract_meta.py test/data/arxiv/2605.16085v1.pdf
  python3 extract_meta.py test/data/arxiv/

Output:
  test/data/arxiv/2605.16085v1.pdf  ->  test/data/arxiv/2605.16085v1.meta.json

Requires: pypdf (pip install pypdf)
"""

import json
import os
import sys


DATA_DIR = os.path.join(os.path.dirname(__file__), "test", "data")

# Info-dictionary keys we care about, mapped to output field names.
_INFO_FIELDS = {
    "/Title": "title",
    "/Author": "author",
    "/Subject": "subject",
    "/Keywords": "keywords",
    "/Creator": "creator",
    "/Producer": "producer",
    "/CreationDate": "creation_date",
    "/ModDate": "mod_date",
    "/Trapped": "trapped",
    # Non-standard but common in arXiv PDFs.
    "/DOI": "doi",
    "/License": "license",
    "/arXivID": "arxiv_id",
}


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


def _xmp_str(value):
    """Normalise an XMP value to a plain string or None."""
    if value is None:
        return None
    if isinstance(value, dict):
        # Language-keyed dict — prefer 'x-default', else first value.
        return value.get("x-default") or next(iter(value.values()), None)
    if isinstance(value, list):
        return [str(v) for v in value] if value else None
    return str(value)


def extract(pdf_path):
    """Return a metadata dict for *pdf_path*, or a dict with an 'error' key."""
    from pypdf import PdfReader
    from pypdf.errors import PdfReadError

    try:
        reader = PdfReader(pdf_path)

        if reader.is_encrypted:
            for pwd in ("", "test", "owner"):
                result = reader.decrypt(pwd)
                if result.value > 0:
                    break
            else:
                return {"error": "encrypted: could not decrypt"}

        # --- Info dictionary ---
        raw_info = reader.metadata or {}
        info = {field: str(raw_info[key]) if key in raw_info else None
                for key, field in _INFO_FIELDS.items()}
        info["page_count"] = len(reader.pages)

        # --- XMP ---
        xmp_data = reader.xmp_metadata
        if xmp_data is not None:
            xmp = {
                "title": _xmp_str(xmp_data.dc_title),
                "creators": _xmp_str(xmp_data.dc_creator),
                "description": _xmp_str(xmp_data.dc_description),
                "subjects": _xmp_str(xmp_data.dc_subject),
                "language": _xmp_str(xmp_data.dc_language),
                "rights": _xmp_str(xmp_data.dc_rights),
                "identifier": _xmp_str(xmp_data.dc_identifier),
                "create_date": str(xmp_data.xmp_create_date) if xmp_data.xmp_create_date else None,
                "modify_date": str(xmp_data.xmp_modify_date) if xmp_data.xmp_modify_date else None,
                "creator_tool": _xmp_str(xmp_data.xmp_creator_tool),
                "keywords": _xmp_str(xmp_data.pdf_keywords),
                "pdf_version": _xmp_str(xmp_data.pdf_pdfversion),
                "producer": _xmp_str(xmp_data.pdf_producer),
                "document_id": _xmp_str(xmp_data.xmpmm_document_id),
                "instance_id": _xmp_str(xmp_data.xmpmm_instance_id),
            }
        else:
            xmp = None

        return {"info": info, "xmp": xmp}

    except PdfReadError as exc:
        return {"error": f"PdfReadError: {exc}"}
    except Exception as exc:  # noqa: BLE001
        return {"error": f"{type(exc).__name__}: {exc}"}


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
        json_path = os.path.splitext(pdf_path)[0] + ".meta.json"
        json_rel = os.path.relpath(json_path)
        meta = extract(pdf_path)
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2, ensure_ascii=False)
            f.write("\n")
        status = "ERROR" if "error" in meta else "ok"
        print(f"[{status}] {rel}  ->  {json_rel}")

    print(f"\nDone. {len(files)} file(s) processed.")


if __name__ == "__main__":
    main()
