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

"""Extract annotations from PDF files using pypdf.

Walks the test/data/ directory tree (or the specified paths), extracts
annotations from every .pdf file using pypdf raw dictionary access, and
writes the result to a .annot.json file alongside each PDF.

JSON format per file:
  [
    {
      "pageIndex": 0,
      "annotations": [
        {
          "type": "Highlight",
          "rect": [left, bottom, right, top],
          "contents": "...",
          "author": "...",
          "color": [r, g, b],
          "modifiedDate": "...",
          "quadPoints": [x1, y1, ...],
          "inkList": null,
          "vertices": null,
          "linePoints": null,
          "interiorColor": null
        }
      ]
    }
  ]

pypdf fidelity gaps (fields always null in this reference output):
  - inkList:       pypdf does not parse /InkList path arrays
  - vertices:      pypdf does not parse /Vertices
  - linePoints:    pypdf does not parse /L (line endpoint array)
  - interiorColor: pypdf does not surface /IC (interior colour)
  - popupRect:     pypdf does not follow /Popup references
  - flags:         pypdf may not expose /F in all annotation types

Tests that rely on these fields MUST be Dart-only tests against fixture PDFs,
using PDFium as the sole source of truth -- do not cross-check against this
reference JSON for those fields.

quadPoints IS populated for markup annotation types (Highlight, Underline,
Squiggly, StrikeOut) because pypdf exposes the raw /QuadPoints array as
a list of floats in PDF user space.

Usage:
  python3 extract_annotations.py [path ...]

  With no arguments, scans all .pdf files under test/data/.
  With one or more path arguments, processes those paths (files or directories).

Examples:
  python3 extract_annotations.py
  python3 extract_annotations.py test/fixtures/annotated_text.pdf
  python3 extract_annotations.py test/fixtures/

Requires: pypdf (pip install pypdf)
"""

import json
import os
import sys


DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "test", "data")

# Annotation subtypes that carry quad-points (/QuadPoints).
_MARKUP_TYPES = {"Highlight", "Underline", "Squiggly", "StrikeOut"}

# Annotation subtypes that are out of scope for v0.02 (form fields).
_SKIP_TYPES = {"Widget", "XFAWidget"}


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


def _get_str(annot_dict, key):
    """Return a decoded string value from a pypdf annotation dict, or None."""
    try:
        val = annot_dict.get(key)
        if val is None:
            return None
        s = str(val)
        return s if s else None
    except Exception:  # noqa: BLE001
        return None


def _get_rect(annot_dict):
    """Return /Rect as [left, bottom, right, top] floats, or None."""
    try:
        rect = annot_dict.get("/Rect")
        if rect is None:
            return None
        return [float(v) for v in rect]
    except Exception:  # noqa: BLE001
        return None


def _get_color(annot_dict, key="/C"):
    """Return a colour array as 0.0-1.0 floats, or None."""
    try:
        c = annot_dict.get(key)
        if c is None or len(c) == 0:
            return None
        return [float(v) for v in c]
    except Exception:  # noqa: BLE001
        return None


def _get_quad_points(annot_dict):
    """Return /QuadPoints as a flat list of floats, or None."""
    try:
        qp = annot_dict.get("/QuadPoints")
        if qp is None:
            return None
        return [float(v) for v in qp]
    except Exception:  # noqa: BLE001
        return None


def _extract_annotation(annot_ref):
    """Convert a pypdf annotation reference to a JSON-serialisable dict.

    Fields that pypdf cannot reliably provide are set to null (see module
    docstring for the full gap table).
    """
    try:
        d = annot_ref.get_object() if hasattr(annot_ref, "get_object") else annot_ref

        subtype = _get_str(d, "/Subtype")
        if subtype:
            subtype = subtype.lstrip("/")

        # Skip form-field annotations (out of scope for v0.02).
        if subtype in _SKIP_TYPES:
            return None

        rect = _get_rect(d)
        contents = _get_str(d, "/Contents")
        author = _get_str(d, "/T")
        mod_date = _get_str(d, "/M")
        color = _get_color(d, "/C")

        quad_points = None
        if subtype in _MARKUP_TYPES:
            quad_points = _get_quad_points(d)

        return {
            "type": subtype,
            "rect": rect,
            "contents": contents,
            "author": author,
            "color": color,
            "modifiedDate": mod_date,
            "quadPoints": quad_points,
            # Fields pypdf cannot reliably extract (see module docstring).
            "inkList": None,
            "vertices": None,
            "linePoints": None,
            "interiorColor": None,
        }
    except Exception as exc:  # noqa: BLE001
        return {"type": "error", "error": f"{type(exc).__name__}: {exc}"}


def extract(pdf_path):
    """Return a list of per-page annotation dicts for *pdf_path*.

    Each dict has the shape: { "pageIndex": int, "annotations": [...] }.
    """
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
                return [{"pageIndex": 0, "annotations": [],
                         "error": "encrypted: could not decrypt"}]

        pages = []
        for i, page in enumerate(reader.pages):
            raw_annots = page.get("/Annots")
            if raw_annots is None:
                pages.append({"pageIndex": i, "annotations": []})
                continue

            try:
                annot_list = (
                    raw_annots.get_object()
                    if hasattr(raw_annots, "get_object")
                    else raw_annots
                )
            except Exception:  # noqa: BLE001
                pages.append({"pageIndex": i, "annotations": []})
                continue

            annotations = []
            for annot_ref in annot_list:
                result = _extract_annotation(annot_ref)
                if result is not None:
                    annotations.append(result)

            pages.append({"pageIndex": i, "annotations": annotations})

        return pages

    except PdfReadError as exc:
        return [{"pageIndex": 0, "annotations": [],
                 "error": f"PdfReadError: {exc}"}]
    except Exception as exc:  # noqa: BLE001
        return [{"pageIndex": 0, "annotations": [],
                 "error": f"{type(exc).__name__}: {exc}"}]


def main():
    """Entry point: process PDF files and write .annot.json references."""
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
        json_path = os.path.splitext(pdf_path)[0] + ".annot.json"
        json_rel = os.path.relpath(json_path)
        pages = extract(pdf_path)
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(pages, f, indent=2, ensure_ascii=False)
            f.write("\n")
        total_annots = sum(len(p.get("annotations", [])) for p in pages)
        print(f"{rel}  ->  {json_rel}  ({total_annots} annotations)")

    print(f"\nDone. {len(files)} file(s) processed.")


if __name__ == "__main__":
    main()
