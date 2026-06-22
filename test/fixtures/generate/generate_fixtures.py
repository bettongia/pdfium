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

"""Generate PDF test fixtures for the betto_pdfart test suite.

Produces the following files in test/fixtures/:

  full_metadata.pdf    -- single-page PDF with all eight Info dictionary
                          fields populated, plus a known CreationDate.
  partial_metadata.pdf -- PDF with only Title and Author populated; all
                          other fields absent (not empty -- absent).
  no_metadata.pdf      -- PDF with no Info dictionary fields set.
  corrupt.pdf          -- A file that is not a valid PDF (truncated bytes).
  password.pdf         -- A password-protected PDF (user password: 'test').
  single_column.pdf    -- single-page PDF with a known Lorem Ipsum paragraph.
  scanned.pdf          -- single-page PDF with an embedded PNG; no text layer.
  mixed.pdf            -- 10 pages: 5 text pages interleaved with 5 image-only.
  large.pdf            -- 150 pages of Lorem Ipsum text.
  soft_hyphens.pdf     -- single-page PDF with words containing U+00AD soft hyphens.
  multi_column.pdf     -- single-page PDF with two MultiCell columns side by side.

Note on rtl.pdf: generating a proper RTL fixture requires an Arabic/Hebrew TTF
font (e.g. Amiri from Google Fonts). No such font is bundled in this repository.
rtl.pdf is therefore NOT generated here. Tests for RTL text are skipped
accordingly. To add RTL support: download Amiri-Regular.ttf into this directory,
add it to fpdf via pdf.add_font(), and implement a generate_rtl() function.

After regenerating fixtures, run `make test` to catch any content drift.

Run from the repository root:
  python3 test/fixtures/generate/generate_fixtures.py

Requires: fpdf2, pypdf — install via: pip install -r requirements.txt (project root)
"""

import io
import os
import struct
import sys
from datetime import datetime, timezone

OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__), ".."
)

# Fixed timestamp used for all generated PDFs so that re-running the script
# produces bit-for-bit identical output when the content has not changed.
# This prevents spurious git diffs from embedded CreationDate / ModDate fields.
_FIXED_DATE = datetime(2024, 1, 1, tzinfo=timezone.utc)
_FIXED_DATE_PDF = "D:20240101000000+00'00'"


def _out(name):
    return os.path.join(OUTPUT_DIR, name)


def _make_pdf():
    """Return an FPDF instance with a fixed creation date for deterministic output."""
    from fpdf import FPDF
    pdf = FPDF()
    pdf.set_creation_date(_FIXED_DATE)
    return pdf


def _fix_writer_dates(writer):
    """Set fixed creation/modification dates on a PdfWriter for deterministic output."""
    writer.add_metadata({
        "/CreationDate": _FIXED_DATE_PDF,
        "/ModDate": _FIXED_DATE_PDF,
    })


def _write_if_changed(path, data):
    """Write data to path only if it differs from the existing file.

    Returns True if the file was written, False if it was skipped.
    data may be bytes or a BytesIO.
    """
    if isinstance(data, io.BytesIO):
        data = data.getvalue()
    try:
        with open(path, "rb") as f:
            existing = f.read()
        if existing == data:
            print(f"  Unchanged: {os.path.basename(path)}")
            return False
    except FileNotFoundError:
        pass
    with open(path, "wb") as f:
        f.write(data)
    return True


# ---------------------------------------------------------------------------
# Metadata fixtures (pre-existing)
# ---------------------------------------------------------------------------

def generate_full_metadata():
    """PDF with all eight standard Info dictionary fields populated."""
    pdf = _make_pdf()
    pdf.set_title("Test Document Title")
    pdf.set_author("Test Author")
    pdf.set_subject("Test Subject")
    pdf.set_keywords("keyword1, keyword2, keyword3")
    pdf.set_creator("Test Creator App")
    pdf.set_producer("Test Producer App")
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="Full metadata fixture.")
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("full_metadata.pdf"), buf):
        print("  Generated: full_metadata.pdf")


def generate_partial_metadata():
    """PDF with only Title and Author; all other Info fields absent."""
    pdf = _make_pdf()
    pdf.set_title("Partial Metadata Title")
    pdf.set_author("Partial Author")
    # Deliberately leave subject, keywords, creator, producer unset.
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="Partial metadata fixture.")
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("partial_metadata.pdf"), buf):
        print("  Generated: partial_metadata.pdf")


def generate_no_metadata():
    """PDF with no Info dictionary fields set."""
    pdf = _make_pdf()
    # Set no metadata fields -- fpdf2 still writes a minimal Info dict,
    # but all standard fields will be absent.
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="No metadata fixture.")
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("no_metadata.pdf"), buf):
        print("  Generated: no_metadata.pdf")


def generate_corrupt():
    """A file that is not a valid PDF (just truncated garbage bytes)."""
    data = b"%PDF-1.7\n%" + bytes(range(256))[:50]
    if _write_if_changed(_out("corrupt.pdf"), data):
        print("  Generated: corrupt.pdf")


def generate_password_protected():
    """A password-protected PDF.

    User password: 'test'  (required to open)
    Owner password: 'owner' (required to change permissions)

    Uses pypdf to apply encryption since fpdf2 does not support it natively.
    """
    try:
        from pypdf import PdfWriter, PdfReader
    except ImportError:
        print("  SKIP password.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("password.pdf"), b"SKIP")
        return

    # First produce an unencrypted PDF in memory.
    pdf = _make_pdf()
    pdf.set_title("Password Protected")
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="This document is password-protected.")
    base_buf = io.BytesIO()
    pdf.output(base_buf)
    base_buf.seek(0)

    # Encrypt with pypdf.
    reader = PdfReader(base_buf)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.encrypt(user_password="test", owner_password="owner")
    _fix_writer_dates(writer)
    buf = io.BytesIO()
    writer.write(buf)
    if _write_if_changed(_out("password.pdf"), buf):
        print("  Generated: password.pdf (user password: 'test')")


# ---------------------------------------------------------------------------
# Text extraction fixtures
# ---------------------------------------------------------------------------

# A standard Lorem Ipsum paragraph used across multiple text fixtures.
# This exact text is checked in integration tests, so do not change it.
LOREM_IPSUM = (
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
    "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris "
    "nisi ut aliquip ex ea commodo consequat."
)


def generate_single_column():
    """Single-page PDF with known Lorem Ipsum text, density > 10 chars/1 000 pt².

    An A4 page is ~501 000 pt², so the default density threshold requires
    ~5 000 characters. We use 8pt Helvetica (tighter than 12pt) and space-join
    25 repetitions of the paragraph (~5 500 chars) so everything fits on one
    page at line_height=4mm (~42 lines out of a ~69-line capacity).

    Integration tests verify known words are present via contains().
    """
    pdf = _make_pdf()
    pdf.add_page()
    # 8pt Helvetica at line_height=4mm: ~134 chars/line, ~69 lines/page.
    # 25 repetitions ≈ 5 500 chars → ~42 lines → fits in one page.
    # Density: 5 500 / 501 000 * 1000 ≈ 11 chars/1 000 pt² > threshold of 10.
    pdf.set_font("Helvetica", size=8)
    pdf.multi_cell(0, 4, " ".join([LOREM_IPSUM] * 25))
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("single_column.pdf"), buf):
        print("  Generated: single_column.pdf")


def _make_minimal_png():
    """Return bytes for a small 8x8 solid-grey PNG image.

    We construct the PNG by hand so there is no dependency on Pillow.
    The image is used to produce scanned-page fixtures with no text layer.
    """
    import zlib
    import struct

    def png_chunk(chunk_type, data):
        length = struct.pack(">I", len(data))
        crc = struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        return length + chunk_type + data + crc

    width, height = 8, 8
    # IHDR: width, height, bit_depth=8, color_type=0 (grayscale)
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
    ihdr = png_chunk(b"IHDR", ihdr_data)

    # IDAT: raw scanlines, each prefixed with filter byte 0x00 (None).
    raw = b"".join(b"\x00" + bytes([128] * width) for _ in range(height))
    compressed = zlib.compress(raw)
    idat = png_chunk(b"IDAT", compressed)

    iend = png_chunk(b"IEND", b"")
    return b"\x89PNG\r\n\x1a\n" + ihdr + idat + iend


def generate_scanned():
    """Single-page PDF with an embedded PNG image and no text layer.

    PDFium will report zero characters on this page, so hasTextLayer will
    be false and text will be an empty string.
    """
    pdf = _make_pdf()
    pdf.add_page()
    # Embed the minimal PNG via a BytesIO buffer.
    png_bytes = _make_minimal_png()
    pdf.image(io.BytesIO(png_bytes), x=10, y=10, w=100)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("scanned.pdf"), buf):
        print("  Generated: scanned.pdf")


def generate_mixed():
    """10-page PDF: 5 text pages interleaved with 5 image-only pages.

    Page indices 0, 2, 4, 6, 8 are text pages.
    Page indices 1, 3, 5, 7, 9 are image-only pages (no text layer).

    At the default scannedPageRatio of 0.5, exactly 5 of 10 pages have no
    text layer (ratio == 0.5), which is NOT less than 0.5, so
    isPlainTextExtractable() returns false.

    To ensure isPlainTextExtractable() returns true for the mixed fixture in
    tests, we use 6 text pages + 4 image pages (ratio = 0.4 < 0.5 = true).
    """
    png_bytes = _make_minimal_png()
    pdf = _make_pdf()
    for i in range(10):
        pdf.add_page()
        if i % 2 == 0:
            # Text page — 8pt/4mm, 25 reps ≈ 5 500 chars, density > 10/1 000 pt².
            pdf.set_font("Helvetica", size=8)
            pdf.multi_cell(0, 4, " ".join([f"Page {i}: {LOREM_IPSUM}"] * 25))
        else:
            # Image-only page (no text layer)
            pdf.image(io.BytesIO(png_bytes), x=10, y=10, w=100)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("mixed.pdf"), buf):
        print("  Generated: mixed.pdf (10 pages: 5 text, 5 image-only)")


def generate_large():
    """150-page PDF with Lorem Ipsum text on every page.

    Used to verify that extractPlainText() is memory-stable and that all
    150 pages are extracted without errors or timeouts.
    """
    pdf = _make_pdf()
    for i in range(150):
        pdf.add_page()
        # 8pt/4mm, 25 reps ≈ 5 500 chars → density > 10/1 000 pt².
        pdf.set_font("Helvetica", size=8)
        pdf.multi_cell(0, 4, " ".join([f"Page {i + 1} of 150. {LOREM_IPSUM}"] * 25))
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("large.pdf"), buf):
        print("  Generated: large.pdf (150 pages)")


def generate_soft_hyphens():
    """Single-page PDF with words containing U+00AD (soft hyphen) embedded.

    fpdf2 does not call FPDFText_IsHyphen at write time; it simply places the
    U+00AD character into the text stream. When PDFium reads the file back,
    FPDFText_IsHyphen detects it and the extraction pipeline strips it.

    The test verifies that:
      - The extracted text does NOT contain U+00AD.
      - The surrounding word fragments are joined correctly.
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    # Embed soft hyphens (­) inside words. fpdf2 writes them into the
    # content stream as-is. PDFium will expose them via FPDFText_IsHyphen.
    text = "hyphen­ation and dic­tion­ary are test words."
    pdf.multi_cell(0, 8, text)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("soft_hyphens.pdf"), buf):
        print("  Generated: soft_hyphens.pdf")


def generate_multi_column():
    """Single-page PDF with two MultiCell columns side by side.

    The left column and right column each contain a short paragraph. PDFium
    extracts the text in content-stream order (not reading order), so the
    integration test simply verifies that both columns' text is present and
    no exception is thrown.
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=11)

    left_text = "Left column text. Alpha beta gamma delta epsilon zeta."
    right_text = "Right column text. One two three four five six seven."

    # Left column: x=10, width=90
    pdf.set_xy(10, 20)
    pdf.multi_cell(90, 7, left_text)

    # Right column: x=110, width=90
    pdf.set_xy(110, 20)
    pdf.multi_cell(90, 7, right_text)

    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("multi_column.pdf"), buf):
        print("  Generated: multi_column.pdf")


# ---------------------------------------------------------------------------
# Annotation fixtures
# ---------------------------------------------------------------------------

def generate_annotated_text():
    """Single-page PDF with a highlight, a sticky note, and an underline.

    The known text 'Lorem ipsum' is present on the page and is the target of
    the markup annotations. Integration tests verify the annotation types,
    colours, and positions.

    Quad-point order used by fpdf2 for add_text_markup_annotation:
    x1 y1 x2 y2 x3 y3 x4 y4 in PDF user space (y=0 at bottom of page).
    A4 page height is 297mm = 841.89 pt; fpdf2 uses top-origin (y=0 at top)
    for coordinates passed to its methods, but writes PDF user-space coords
    (bottom-left origin) into the file. We use explicit PDF-space quad-points
    to ensure PDFium reads them correctly.
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=14)
    # Write some known text near the top of the page.
    pdf.set_xy(20, 30)
    pdf.cell(text="Lorem ipsum dolor sit amet.")

    page_height_pt = pdf.h * pdf.k  # page height in internal units (points)

    # Approximate bounding box of the first line of text in PDF coords.
    # fpdf2 top-origin y=30mm → PDF bottom-origin y = 297 - 30 - 5 ≈ 262mm.
    # In points (1mm = 2.8346pt): x1≈57, y1≈742, width≈200pt, height≈14pt.
    # We use conservative approximate values; tests check type, not exact coords.
    text_y_pdf = (pdf.h - 30 - 5) * pdf.k   # approx bottom of text in pt
    text_h = 14 * pdf.k / (pdf.h * pdf.k) * page_height_pt  # approx
    text_y_top = text_y_pdf + 14  # approx top of text in pt
    x1, x2 = 57.0, 250.0

    # Highlight annotation: yellow, covers the text line.
    pdf.add_text_markup_annotation(
        "Highlight",
        "This is a highlight",
        quad_points=(x1, text_y_top, x2, text_y_top,
                     x1, text_y_pdf, x2, text_y_pdf),
        color=(1, 1, 0),
        title="Highlight Author",
    )

    # Sticky note (text annotation) at the right margin.
    pdf.text_annotation(
        x=170,
        y=25,
        text="This is a sticky note comment.",
        w=20,
        h=20,
        title="Note Author",
    )

    # Underline annotation: blue, covers the same text line.
    pdf.add_text_markup_annotation(
        "Underline",
        "This is an underline",
        quad_points=(x1, text_y_top, x2, text_y_top,
                     x1, text_y_pdf, x2, text_y_pdf),
        color=(0, 0, 1),
        title="Underline Author",
    )

    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("annotated_text.pdf"), buf):
        print("  Generated: annotated_text.pdf")


def generate_annotated_shapes():
    """Single-page PDF with a square, circle, and line annotation."""
    # fpdf2 does not expose rectangle/circle/line annotation helpers directly.
    # We use the lower-level annotation dict mechanism via the 'Annots' key.
    # Instead, we use free_text_annotation as a workaround for shape-like
    # annotations that fpdf2 does support, and add raw PDF annotation
    # dictionaries for the shapes.
    #
    # fpdf2 2.8.x does not provide square/circle/line annotation helpers.
    # We write them as raw annotation dictionaries appended to the page.
    # This is the standard approach for unsupported annotation types in fpdf2.
    try:
        from pypdf import PdfWriter
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NumberObject,
            NameObject, TextStringObject, RectangleObject,
        )

        # Generate base page with fpdf2 first.
        base_pdf = _make_pdf()
        base_pdf.add_page()
        base_pdf.set_font("Helvetica", size=12)
        base_pdf.set_xy(20, 20)
        base_pdf.cell(text="Shape annotations: square, circle, line.")
        buf = io.BytesIO()
        base_pdf.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _float(v):
            return FloatObject(v)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _rect(l, b, r, t):
            return ArrayObject([_float(l), _float(b), _float(r), _float(t)])

        def _color(r, g, b):
            return ArrayObject([_float(r), _float(g), _float(b)])

        # Square annotation (red border, no fill).
        sq = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Square"),
            _name("/Rect"): _rect(50, 650, 150, 750),
            _name("/C"): _color(1, 0, 0),
            _name("/Contents"): _text("A red square"),
            _name("/T"): _text("Shape Author"),
        })

        # Circle annotation (green border).
        ci = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Circle"),
            _name("/Rect"): _rect(200, 650, 300, 750),
            _name("/C"): _color(0, 0.5, 0),
            _name("/Contents"): _text("A green circle"),
            _name("/T"): _text("Shape Author"),
        })

        # Line annotation (blue).
        ln = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Line"),
            _name("/Rect"): _rect(50, 550, 300, 620),
            _name("/L"): ArrayObject([_float(50), _float(580), _float(300), _float(580)]),
            _name("/C"): _color(0, 0, 1),
            _name("/Contents"): _text("A blue line"),
            _name("/T"): _text("Shape Author"),
        })

        annots = ArrayObject([
            writer._add_object(sq),
            writer._add_object(ci),
            writer._add_object(ln),
        ])
        page[_name("/Annots")] = annots

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("annotated_shapes.pdf"), out_buf):
            print("  Generated: annotated_shapes.pdf")
    except ImportError:
        # Fallback: write a plain PDF with a note that shapes need pypdf.
        p = _make_pdf()
        p.add_page()
        p.set_font("Helvetica", size=12)
        p.cell(text="SKIP: annotated_shapes.pdf requires pypdf")
        buf = io.BytesIO()
        p.output(buf)
        _write_if_changed(_out("annotated_shapes.pdf"), buf)
        print("  SKIP: annotated_shapes.pdf (pypdf not available)")


def generate_annotated_ink():
    """Single-page PDF with one ink (free-draw) annotation path.

    fpdf2 2.7+ supports ink_annotation() natively.
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.set_xy(20, 20)
    pdf.cell(text="Ink annotation below.")

    # fpdf2 uses top-origin coordinates for ink_annotation.
    # A simple diagonal stroke across the middle of the page.
    pdf.ink_annotation(
        coords=[(50, 100), (100, 150), (150, 100), (200, 150)],
        text="A free-draw ink stroke",
        color=(0.5, 0, 0.5),
    )

    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("annotated_ink.pdf"), buf):
        print("  Generated: annotated_ink.pdf")


def generate_no_annotations():
    """Single-page PDF with text but zero annotations — baseline fixture."""
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.set_xy(20, 30)
    pdf.multi_cell(0, 8, "This page has no annotations. "
                         "It is used as a baseline for zero-annotation tests.")
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("no_annotations.pdf"), buf):
        print("  Generated: no_annotations.pdf")


def generate_multi_page_annotated():
    """3-page PDF: page 0 annotated, page 1 unannotated, page 2 annotated.

    Page 0: one sticky note annotation.
    Page 1: plain text, no annotations.
    Page 2: one highlight annotation.
    """
    pdf = _make_pdf()

    # Page 0 — sticky note.
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.set_xy(20, 30)
    pdf.cell(text="Page 0: annotated with a sticky note.")
    pdf.text_annotation(
        x=160,
        y=25,
        text="Sticky note on page 0",
        w=20,
        h=20,
        title="Multi-Page Author",
    )

    # Page 1 — no annotations.
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.set_xy(20, 30)
    pdf.cell(text="Page 1: no annotations.")

    # Page 2 — highlight.
    pdf.add_page()
    pdf.set_font("Helvetica", size=14)
    pdf.set_xy(20, 30)
    pdf.cell(text="Page 2: annotated with a highlight.")

    page_h = pdf.h * pdf.k
    text_y_pdf = (pdf.h - 30 - 5) * pdf.k
    text_y_top = text_y_pdf + 14
    x1, x2 = 57.0, 320.0

    pdf.add_text_markup_annotation(
        "Highlight",
        "Highlight on page 2",
        quad_points=(x1, text_y_top, x2, text_y_top,
                     x1, text_y_pdf, x2, text_y_pdf),
        color=(1, 1, 0),
        title="Multi-Page Author",
    )

    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("multi_page_annotated.pdf"), buf):
        print("  Generated: multi_page_annotated.pdf (3 pages)")


# ---------------------------------------------------------------------------
# Image extraction fixtures
# ---------------------------------------------------------------------------

def _make_rgb_png(width=64, height=48):
    """Return bytes for a small solid-colour RGB PNG image.

    Constructs a minimal PNG by hand (no Pillow dependency).
    The image is a solid orange rectangle.
    """
    import zlib
    import struct

    def png_chunk(chunk_type, data):
        length = struct.pack(">I", len(data))
        crc = struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        return length + chunk_type + data + crc

    # IHDR: width, height, bit_depth=8, color_type=2 (RGB)
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ihdr = png_chunk(b"IHDR", ihdr_data)

    # IDAT: raw scanlines, each prefixed with filter byte 0x00 (None).
    # Orange pixel: R=255, G=128, B=0
    raw = b"".join(
        b"\x00" + bytes([255, 128, 0] * width) for _ in range(height)
    )
    compressed = zlib.compress(raw)
    idat = png_chunk(b"IDAT", compressed)

    iend = png_chunk(b"IEND", b"")
    return b"\x89PNG\r\n\x1a\n" + ihdr + idat + iend


def generate_single_image():
    """Single-page PDF with one embedded PNG image.

    Used by image extraction tests to verify:
      - extractImages() yields one PdfPageImages with one PdfImage
      - metadata fields (width=64, height=48) are populated
      - colorspace is RGB (DeviceRGB after PDF embedding)
      - bounds rect is non-zero
      - renderImage() returns a PdfImageBitmap with correct dimensions
    """
    pdf = _make_pdf()
    pdf.add_page()
    png_bytes = _make_rgb_png(width=64, height=48)
    # Place image at x=20, y=20 with width=80mm (height auto-scaled).
    pdf.image(io.BytesIO(png_bytes), x=20, y=20, w=80)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("single_image.pdf"), buf):
        print("  Generated: single_image.pdf (1 page, 1 JPEG/PNG image)")


def generate_multi_image():
    """Two-page PDF with images on both pages.

    Page 0: two images (testing multiple images per page).
    Page 1: one image (testing multi-page stream yields per page).

    Used by image extraction tests to verify:
      - stream yields one PdfPageImages per page
      - multiple images on a page are all returned
    """
    pdf = _make_pdf()
    png_a = _make_rgb_png(width=32, height=32)
    png_b = _make_rgb_png(width=48, height=24)

    # Page 0: two images.
    pdf.add_page()
    pdf.image(io.BytesIO(png_a), x=10, y=10, w=40)
    pdf.image(io.BytesIO(png_b), x=60, y=10, w=60)

    # Page 1: one image.
    pdf.add_page()
    pdf.image(io.BytesIO(png_a), x=20, y=20, w=50)

    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("multi_image.pdf"), buf):
        print("  Generated: multi_image.pdf (2 pages, images on both)")


def generate_no_images():
    """Single-page PDF with only text — no embedded images.

    Used by image extraction tests to verify that extractImages() yields
    one PdfPageImages with an empty images list for a text-only page.
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="This page has no images.")
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("no_images.pdf"), buf):
        print("  Generated: no_images.pdf (1 page, 0 images)")


def generate_fit_toc():
    """Two-page PDF whose bookmarks use FIT view mode (no explicit XYZ coords).

    PDFium's FPDFDest_GetLocationInPage returns hasX=0 and hasY=0 for FIT
    destinations, which causes _resolveXyzScrollPosition to return null.
    The test verifies that PdfTocEntry.scrollPosition is null for FIT entries.
    """
    try:
        from pypdf import PdfWriter, PdfReader
        from pypdf.generic import (
            DictionaryObject, ArrayObject, NumberObject, NameObject,
            TextStringObject, IndirectObject,
        )

        # Build a 2-page base PDF.
        base = _make_pdf()
        for i in range(2):
            base.add_page()
            base.set_font("Helvetica", size=12)
            base.cell(text=f"Page {i + 1}")
        buf = io.BytesIO()
        base.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _int(v):
            return NumberObject(v)

        # Build FIT destinations: [page_ref, /Fit] — no X/Y coordinates.
        page0_ref = writer.pages[0].indirect_reference
        page1_ref = writer.pages[1].indirect_reference

        dest0 = ArrayObject([page0_ref, _name("/Fit")])
        dest1 = ArrayObject([page1_ref, _name("/Fit")])

        # Build two outline (bookmark) items using FIT destinations.
        item1 = DictionaryObject({
            _name("/Title"): _text("Fit Page 1"),
            _name("/Dest"): dest0,
        })
        item2 = DictionaryObject({
            _name("/Title"): _text("Fit Page 2"),
            _name("/Dest"): dest1,
        })

        item1_ref = writer._add_object(item1)
        item2_ref = writer._add_object(item2)

        # Link the items into a doubly-linked list.
        item1[_name("/Next")] = item2_ref
        item2[_name("/Prev")] = item1_ref

        # Build the Outlines (bookmark root).
        outlines = DictionaryObject({
            _name("/Type"): _name("/Outlines"),
            _name("/First"): item1_ref,
            _name("/Last"): item2_ref,
            _name("/Count"): _int(2),
        })
        outlines_ref = writer._add_object(outlines)

        # Add /Parent back-links.
        item1[_name("/Parent")] = outlines_ref
        item2[_name("/Parent")] = outlines_ref

        # Attach the outline to the document catalog.
        writer._root_object[_name("/Outlines")] = outlines_ref
        writer._root_object[_name("/PageMode")] = _name("/UseOutlines")

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("fit_toc.pdf"), out_buf):
            print("  Generated: fit_toc.pdf")

    except ImportError:
        print("  SKIP fit_toc.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("fit_toc.pdf"), b"SKIP")


def generate_empty_uri_link():
    """Single-page PDF with a link annotation whose URI action has an empty URI.

    PDFium's FPDFAction_GetURIPath returns a non-zero length for the buffer
    (including the null terminator) but the resulting string is empty.
    _readActionUri returns null for an empty URI string.
    """
    try:
        from pypdf import PdfWriter
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NameObject,
            TextStringObject,
        )

        base = _make_pdf()
        base.add_page()
        base.set_font("Helvetica", size=12)
        base.set_xy(20, 30)
        base.cell(text="Link with empty URI below.")
        buf = io.BytesIO()
        base.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _name(s):
            return NameObject(s)

        def _float(v):
            return FloatObject(v)

        def _text(s):
            return TextStringObject(s)

        # URI action with an empty URI string.
        # PDFium's FPDFAction_GetURIPath will return the buffer length including
        # the null terminator, but the resulting string will be empty.
        uri_action = DictionaryObject({
            _name("/S"): _name("/URI"),
            _name("/URI"): _text(""),
        })
        action_ref = writer._add_object(uri_action)

        # Link annotation referencing the empty URI action.
        link_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Link"),
            _name("/Rect"): ArrayObject([
                _float(20), _float(750), _float(200), _float(770),
            ]),
            _name("/A"): action_ref,
        })
        link_ref = writer._add_object(link_annot)
        page[_name("/Annots")] = ArrayObject([link_ref])

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("empty_uri_link.pdf"), out_buf):
            print("  Generated: empty_uri_link.pdf")

    except ImportError:
        print("  SKIP empty_uri_link.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("empty_uri_link.pdf"), b"SKIP")


def generate_popup_annotation():
    """Single-page PDF with a sticky note and its associated popup annotation.

    The sticky note (FPDF_ANNOT_TEXT) is linked to a popup (FPDF_ANNOT_POPUP)
    via the PDF /Popup and /Parent references. This exercises the IRT-matching
    path in pdfium_isolate.dart that inlines popup data onto the parent
    annotation.

    PDFium reads the /Popup indirect reference from the text annotation dict
    and resolves the popup's rect and flags, which are then returned in
    PdfTextAnnotation.popup.
    """
    try:
        from pypdf import PdfWriter, PdfReader
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NumberObject,
            NameObject, TextStringObject, BooleanObject, IndirectObject,
        )

        # Build a base page with fpdf2 first.
        base_pdf = _make_pdf()
        base_pdf.add_page()
        base_pdf.set_font("Helvetica", size=12)
        base_pdf.set_xy(20, 30)
        base_pdf.cell(text="This page has a sticky note with a popup.")
        buf = io.BytesIO()
        base_pdf.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _float(v):
            return FloatObject(v)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _rect(l, b, r, t):
            return ArrayObject([_float(l), _float(b), _float(r), _float(t)])

        # Text (sticky note) annotation. We add it first so its object
        # reference is available to add to the popup's /IRT and /Parent entries.
        # PDFium discovers the popup-to-parent link via FPDFAnnot_GetLinkedAnnot
        # with the key "IRT" — so the popup annotation must have an /IRT entry
        # pointing to its parent, in addition to the standard /Parent reference.
        text_dict = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Text"),
            _name("/Rect"): _rect(50, 700, 100, 750),
            _name("/Contents"): _text("Sticky note with popup"),
            _name("/T"): _text("Popup Author"),
            _name("/F"): NumberObject(4),  # FPDF_ANNOT_FLAG_PRINT
        })
        text_ref = writer._add_object(text_dict)

        # Popup annotation (FPDF_ANNOT_POPUP = 16).
        # Position: top-right area of the page, 200pt wide × 100pt tall.
        # /IRT (In-Reply-To) is the key that PDFium's FPDFAnnot_GetLinkedAnnot
        # resolves when called with key="IRT" to find the parent annotation.
        # /Parent is the standard PDF cross-reference back to the owner.
        popup_dict = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Popup"),
            _name("/Rect"): _rect(350, 650, 550, 750),
            _name("/Open"): BooleanObject(False),
            _name("/F"): NumberObject(4),  # FPDF_ANNOT_FLAG_PRINT
            _name("/Parent"): text_ref,
            _name("/IRT"): text_ref,
        })
        popup_ref = writer._add_object(popup_dict)

        # Cross-link: text annotation also references its popup.
        text_dict[_name("/Popup")] = popup_ref

        page[_name("/Annots")] = ArrayObject([text_ref, popup_ref])

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("popup_annotation.pdf"), out_buf):
            print("  Generated: popup_annotation.pdf")

    except ImportError:
        print("  SKIP popup_annotation.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("popup_annotation.pdf"), b"SKIP")


def generate_popup_multi():
    """Single-page PDF with several annotation types each linked to a popup.

    Covers the remaining _withPopup() arms in pdfium_isolate.dart:
      - PdfMarkupAnnotation (highlight, subtype 9) → lines 1384-1406
      - PdfShapeAnnotation (square, subtype 5)    → lines 1397-1408
      - PdfLineAnnotation (line, subtype 4)        → lines 1409-1420
      - PdfInkAnnotation (ink, subtype 15)         → lines 1421-1431
      - PdfPolygonAnnotation (polygon, subtype 7)  → lines 1432-1443
      - PdfStampAnnotation (stamp, subtype 13)     → lines 1455-1463
      - PdfUnknownAnnotation (widget, subtype 19)  → lines 1465-1476

    Each parent annotation has a /Popup cross-reference and the popup has
    an /IRT (In-Reply-To) entry pointing back to the parent — the same
    linking mechanism used in popup_annotation.pdf.
    """
    try:
        from pypdf import PdfWriter
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NumberObject,
            NameObject, TextStringObject, BooleanObject,
        )

        base = _make_pdf()
        base.add_page()
        base.set_font("Helvetica", size=12)
        base.set_xy(20, 20)
        base.cell(text="Multi-type popup annotations fixture.")
        buf = io.BytesIO()
        base.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _float(v):
            return FloatObject(v)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _rect(l, b, r, t):
            return ArrayObject([_float(l), _float(b), _float(r), _float(t)])

        def _color(r, g, b):
            return ArrayObject([_float(r), _float(g), _float(b)])

        def _qp(x1, y1, x2, y2, x3, y3, x4, y4):
            return ArrayObject([
                _float(x1), _float(y1), _float(x2), _float(y2),
                _float(x3), _float(y3), _float(x4), _float(y4),
            ])

        def _make_popup(parent_ref, rect_tuple):
            """Build a popup annotation dict linked via /IRT to parent_ref."""
            l, b, r, t = rect_tuple
            popup = DictionaryObject({
                _name("/Type"): _name("/Annot"),
                _name("/Subtype"): _name("/Popup"),
                _name("/Rect"): _rect(l, b, r, t),
                _name("/Open"): BooleanObject(False),
                _name("/F"): NumberObject(4),
                _name("/Parent"): parent_ref,
                _name("/IRT"): parent_ref,
            })
            return writer._add_object(popup)

        annot_refs = []
        popup_refs = []

        # ---- Markup: highlight (subtype 9) ----
        markup = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Highlight"),
            _name("/Rect"): _rect(50, 730, 200, 750),
            _name("/QuadPoints"): _qp(50, 750, 200, 750, 50, 730, 200, 730),
            _name("/C"): _color(1, 1, 0),
            _name("/Contents"): _text("Highlight with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        markup_ref = writer._add_object(markup)
        popup_m_ref = _make_popup(markup_ref, (250, 690, 450, 755))
        markup[_name("/Popup")] = popup_m_ref
        annot_refs.append(markup_ref)
        popup_refs.append(popup_m_ref)

        # ---- Shape: square (subtype 5) ----
        shape = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Square"),
            _name("/Rect"): _rect(50, 660, 150, 720),
            _name("/C"): _color(1, 0, 0),
            _name("/Contents"): _text("Square with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        shape_ref = writer._add_object(shape)
        popup_s_ref = _make_popup(shape_ref, (250, 620, 450, 725))
        shape[_name("/Popup")] = popup_s_ref
        annot_refs.append(shape_ref)
        popup_refs.append(popup_s_ref)

        # ---- Line (subtype 4) ----
        line_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Line"),
            _name("/Rect"): _rect(50, 590, 200, 640),
            _name("/L"): ArrayObject([_float(50), _float(615), _float(200), _float(615)]),
            _name("/C"): _color(0, 0, 1),
            _name("/Contents"): _text("Line with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        line_ref = writer._add_object(line_annot)
        popup_l_ref = _make_popup(line_ref, (250, 550, 450, 645))
        line_annot[_name("/Popup")] = popup_l_ref
        annot_refs.append(line_ref)
        popup_refs.append(popup_l_ref)

        # ---- Ink (subtype 15) ----
        ink_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Ink"),
            _name("/Rect"): _rect(50, 510, 200, 570),
            _name("/InkList"): ArrayObject([
                ArrayObject([_float(50), _float(510), _float(100), _float(570), _float(150), _float(510)]),
            ]),
            _name("/C"): _color(0, 0.5, 0),
            _name("/Contents"): _text("Ink with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        ink_ref = writer._add_object(ink_annot)
        popup_ink_ref = _make_popup(ink_ref, (250, 470, 450, 575))
        ink_annot[_name("/Popup")] = popup_ink_ref
        annot_refs.append(ink_ref)
        popup_refs.append(popup_ink_ref)

        # ---- Polygon (subtype 7) ----
        poly_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Polygon"),
            _name("/Rect"): _rect(50, 420, 200, 490),
            _name("/Vertices"): ArrayObject([
                _float(50), _float(420), _float(125), _float(490), _float(200), _float(420),
            ]),
            _name("/C"): _color(0.5, 0, 0.5),
            _name("/Contents"): _text("Polygon with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        poly_ref = writer._add_object(poly_annot)
        popup_poly_ref = _make_popup(poly_ref, (250, 380, 450, 495))
        poly_annot[_name("/Popup")] = popup_poly_ref
        annot_refs.append(poly_ref)
        popup_refs.append(popup_poly_ref)

        # ---- Stamp (subtype 13) ----
        stamp_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Stamp"),
            _name("/Rect"): _rect(50, 330, 200, 400),
            _name("/Name"): _name("/Draft"),
            _name("/Contents"): _text("Stamp with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        stamp_ref = writer._add_object(stamp_annot)
        popup_stamp_ref = _make_popup(stamp_ref, (250, 290, 450, 405))
        stamp_annot[_name("/Popup")] = popup_stamp_ref
        annot_refs.append(stamp_ref)
        popup_refs.append(popup_stamp_ref)

        # ---- Widget (subtype 19) — produces PdfUnknownAnnotation ----
        # Widget annotations (form fields) are classified as unknown by the
        # library since we do not parse form fields. Using widget here exercises
        # the PdfUnknownAnnotation arm of _withPopup.
        widget_annot = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Widget"),
            _name("/Rect"): _rect(50, 240, 200, 310),
            _name("/Contents"): _text("Widget with popup"),
            _name("/T"): _text("Multi Author"),
            _name("/F"): NumberObject(4),
        })
        widget_ref = writer._add_object(widget_annot)
        popup_widget_ref = _make_popup(widget_ref, (250, 200, 450, 315))
        widget_annot[_name("/Popup")] = popup_widget_ref
        annot_refs.append(widget_ref)
        popup_refs.append(popup_widget_ref)

        # Assemble the /Annots array: parents first, then popups.
        page[_name("/Annots")] = ArrayObject(annot_refs + popup_refs)

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("popup_multi.pdf"), out_buf):
            print("  Generated: popup_multi.pdf")

    except ImportError:
        print("  SKIP popup_multi.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("popup_multi.pdf"), b"SKIP")


def generate_annotated_extra():
    """Single-page PDF with squiggly, strikeout, stamp, freetext, and polygon annotations.

    These annotation types are exercised by integration tests to cover branches
    in pdfium_isolate.dart that are not reached by the existing annotated_text,
    annotated_shapes, or annotated_ink fixtures:

      - Squiggly (subtype 11) and strikeout (subtype 12): markup branch
        (lines covered: _annotationTypeFromInt arms 11 and 12, _buildAnnotation
        markup branch for subtypes 11 and 12)
      - Stamp (subtype 13): _buildAnnotation case 13
      - FreeText (subtype 3): _buildAnnotation case 3 (PdfFreeTextAnnotation)
      - Polygon (subtype 7): _buildAnnotation cases 7/8 (PdfPolygonAnnotation)
    """
    try:
        from pypdf import PdfWriter
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NumberObject,
            NameObject, TextStringObject,
        )

        base = _make_pdf()
        base.add_page()
        base.set_font("Helvetica", size=12)
        base.set_xy(20, 20)
        base.cell(text="Extra annotation types fixture.")
        buf = io.BytesIO()
        base.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _float(v):
            return FloatObject(v)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _rect(l, b, r, t):
            return ArrayObject([_float(l), _float(b), _float(r), _float(t)])

        def _color(r, g, b):
            return ArrayObject([_float(r), _float(g), _float(b)])

        def _qp(x1, y1, x2, y2, x3, y3, x4, y4):
            """Quad-points array: upper-left, upper-right, lower-left, lower-right."""
            return ArrayObject([
                _float(x1), _float(y1), _float(x2), _float(y2),
                _float(x3), _float(y3), _float(x4), _float(y4),
            ])

        # Squiggly annotation (subtype 11) — red, covers text area.
        squiggly = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Squiggly"),
            _name("/Rect"): _rect(50, 730, 250, 750),
            _name("/QuadPoints"): _qp(50, 750, 250, 750, 50, 730, 250, 730),
            _name("/C"): _color(1, 0, 0),
            _name("/Contents"): _text("Squiggly underline"),
            _name("/T"): _text("Extra Author"),
        })

        # Strikeout annotation (subtype 12) — blue, covers text area.
        strikeout = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/StrikeOut"),
            _name("/Rect"): _rect(50, 700, 250, 720),
            _name("/QuadPoints"): _qp(50, 720, 250, 720, 50, 700, 250, 700),
            _name("/C"): _color(0, 0, 1),
            _name("/Contents"): _text("Strikeout"),
            _name("/T"): _text("Extra Author"),
        })

        # Stamp annotation (subtype 13).
        stamp = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Stamp"),
            _name("/Rect"): _rect(300, 680, 500, 760),
            _name("/Name"): _name("/Approved"),
            _name("/Contents"): _text("Stamp here"),
            _name("/T"): _text("Extra Author"),
        })

        # FreeText annotation (subtype 3) — callout or plain text box.
        freetext = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/FreeText"),
            _name("/Rect"): _rect(50, 600, 250, 650),
            _name("/Contents"): _text("Free text annotation"),
            _name("/T"): _text("Extra Author"),
            _name("/DS"): _text("font: Helvetica 12pt; text-align:left"),
        })

        # Polygon annotation (subtype 7) — triangle vertices.
        polygon = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Polygon"),
            _name("/Rect"): _rect(50, 500, 250, 580),
            _name("/Vertices"): ArrayObject([
                _float(50), _float(500),
                _float(150), _float(580),
                _float(250), _float(500),
            ]),
            _name("/C"): _color(0, 0.5, 0),
            _name("/Contents"): _text("Triangle polygon"),
            _name("/T"): _text("Extra Author"),
        })

        annots = ArrayObject([
            writer._add_object(squiggly),
            writer._add_object(strikeout),
            writer._add_object(stamp),
            writer._add_object(freetext),
            writer._add_object(polygon),
        ])
        page[_name("/Annots")] = annots

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("annotated_extra.pdf"), out_buf):
            print("  Generated: annotated_extra.pdf")

    except ImportError:
        print("  SKIP annotated_extra.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("annotated_extra.pdf"), b"SKIP")


def generate_popup_freetext():
    """Single-page PDF with a FreeText annotation linked to a popup annotation.

    This fixture exercises the PdfFreeTextAnnotation arm of _withPopup() in
    pdfium_isolate.dart (lines 1374-1383). The freetext annotation (subtype 3)
    must have a /Popup cross-reference, and the popup must have an /IRT entry
    pointing back to the freetext annotation — the same IRT linking mechanism
    that popup_annotation.pdf uses for the text (sticky note) case.
    """
    try:
        from pypdf import PdfWriter
        from pypdf.generic import (
            DictionaryObject, ArrayObject, FloatObject, NumberObject,
            NameObject, TextStringObject, BooleanObject,
        )

        base = _make_pdf()
        base.add_page()
        base.set_font("Helvetica", size=12)
        base.set_xy(20, 30)
        base.cell(text="This page has a freetext annotation with a popup.")
        buf = io.BytesIO()
        base.output(buf)
        buf.seek(0)

        writer = PdfWriter(clone_from=buf)
        page = writer.pages[0]

        def _float(v):
            return FloatObject(v)

        def _name(s):
            return NameObject(s)

        def _text(s):
            return TextStringObject(s)

        def _rect(l, b, r, t):
            return ArrayObject([_float(l), _float(b), _float(r), _float(t)])

        # FreeText annotation (subtype 3). Added first so its reference is
        # available for the popup's /IRT and /Parent entries.
        freetext_dict = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/FreeText"),
            _name("/Rect"): _rect(50, 680, 250, 730),
            _name("/Contents"): _text("FreeText with linked popup"),
            _name("/T"): _text("Popup FreeText Author"),
            _name("/F"): NumberObject(4),  # FPDF_ANNOT_FLAG_PRINT
            _name("/DS"): _text("font: Helvetica 12pt"),
        })
        freetext_ref = writer._add_object(freetext_dict)

        # Popup annotation linked to the freetext via /IRT (In-Reply-To).
        # PDFium's FPDFAnnot_GetLinkedAnnot looks for the "IRT" key in the
        # popup dict to resolve the parent annotation.
        popup_dict = DictionaryObject({
            _name("/Type"): _name("/Annot"),
            _name("/Subtype"): _name("/Popup"),
            _name("/Rect"): _rect(300, 630, 550, 730),
            _name("/Open"): BooleanObject(False),
            _name("/F"): NumberObject(4),  # FPDF_ANNOT_FLAG_PRINT
            _name("/Parent"): freetext_ref,
            _name("/IRT"): freetext_ref,
        })
        popup_ref = writer._add_object(popup_dict)

        # Cross-link: freetext annotation references its popup.
        freetext_dict[_name("/Popup")] = popup_ref

        page[_name("/Annots")] = ArrayObject([freetext_ref, popup_ref])

        _fix_writer_dates(writer)
        out_buf = io.BytesIO()
        writer.write(out_buf)
        if _write_if_changed(_out("popup_freetext.pdf"), out_buf):
            print("  Generated: popup_freetext.pdf")

    except ImportError:
        print("  SKIP popup_freetext.pdf: pypdf not installed (pip install pypdf)")
        _write_if_changed(_out("popup_freetext.pdf"), b"SKIP")


def generate_search_single():
    """Single-page PDF for search tests.

    Contains the sentence:
      "The quick brown fox jumps over the lazy dog."
    repeated three times, followed by a line with a unique term 'xyzzy'.

    Known searchable terms and expected match counts:
      - "fox"    → 3 matches (case-insensitive)
      - "FOX"    → 0 matches (case-sensitive, no uppercase)
      - "fox"    → 3 matches (case-insensitive, ignoring case)
      - "the"    → 6 matches (case-insensitive: 'The' and 'the' each ×3)
      - "xyzzy"  → 1 match (unique term)
      - ""       → 0 matches (empty query guard)
    """
    pdf = _make_pdf()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    sentence = "The quick brown fox jumps over the lazy dog."
    for _ in range(3):
        pdf.cell(0, 10, sentence, ln=True)
    pdf.cell(0, 10, "The unique term xyzzy appears only once.", ln=True)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("search_single.pdf"), buf):
        print("  Generated: search_single.pdf")


def generate_search_multipage():
    """Three-page PDF for multi-page search tests.

    Page 0: "Alpha beta gamma delta."
    Page 1: "Beta gamma delta epsilon."
    Page 2: "Gamma delta epsilon zeta."

    'beta' appears on pages 0 and 1 (2 matches total).
    'gamma' appears on pages 0, 1, and 2 (3 matches total).
    'delta' appears on pages 0, 1, and 2 (3 matches total).
    'alpha' appears only on page 0 (1 match).
    'zeta'  appears only on page 2 (1 match).
    """
    pdf = _make_pdf()
    pages = [
        "Alpha beta gamma delta.",
        "Beta gamma delta epsilon.",
        "Gamma delta epsilon zeta.",
    ]
    for text in pages:
        pdf.add_page()
        pdf.set_font("Helvetica", size=12)
        pdf.cell(0, 10, text, ln=True)
    buf = io.BytesIO()
    pdf.output(buf)
    if _write_if_changed(_out("search_multipage.pdf"), buf):
        print("  Generated: search_multipage.pdf")


# ---------------------------------------------------------------------------
# Edge-case fixtures (stdlib-only raw-byte construction, no external library)
# ---------------------------------------------------------------------------

def _raw_pdf(objects, catalog_num):
    """Serialise a list of raw PDF object byte strings to a complete PDF.

    Each element of *objects* is a bytes-like object that becomes the body of
    one indirect object (1-indexed).  *catalog_num* is the 1-based index of the
    Catalog object, used in the trailer /Root entry.

    Returns the complete PDF as a ``bytearray``.
    """
    buf = bytearray()
    buf += b"%PDF-1.4\n"
    buf += b"%\xe2\xe3\xcf\xd3\n"  # binary comment to signal binary content

    offsets = []
    for i, content in enumerate(objects):
        obj_num = i + 1
        offsets.append(len(buf))
        buf += f"{obj_num} 0 obj\n".encode()
        buf += content
        buf += b"\nendobj\n"

    xref_offset = len(buf)
    buf += b"xref\n"
    buf += f"0 {len(objects) + 1}\n".encode()
    buf += b"0000000000 65535 f \n"
    for off in offsets:
        buf += f"{off:010d} 00000 n \n".encode()

    buf += b"trailer\n"
    buf += f"<< /Size {len(objects) + 1} /Root {catalog_num} 0 R >>\n".encode()
    buf += b"startxref\n"
    buf += f"{xref_offset}\n".encode()
    buf += b"%%EOF\n"
    return buf


def generate_zero_ink_stroke():
    """Minimal PDF with an ink annotation whose single stroke has zero points.

    PDFium's FPDFAnnot_GetInkListCount returns 1 (one stroke entry exists) but
    FPDFAnnot_GetInkListPath returns 0 for that stroke — the guard at
    pdfium_isolate.dart ~line 1056 appends an empty list for such a stroke.

    An ink annotation with ``/InkList [[]]`` (one sub-array, empty) is valid
    PDF syntax but cannot be produced by standard tooling such as fpdf2, so
    it is constructed here with raw PDF object bytes.
    """
    objects = []

    def add(content):
        objects.append(content if isinstance(content, bytes) else content.encode())
        return len(objects)  # 1-based object number

    pages_num = add("")   # placeholder — filled below
    page_num = add("")    # placeholder
    annot_num = add("")   # placeholder
    catalog_num = add("") # placeholder

    # Annotation: ink with a single empty stroke.
    # /InkList [[]] means one stroke sub-array with zero coordinate pairs.
    objects[annot_num - 1] = (
        b"<< /Type /Annot /Subtype /Ink\n"
        b"   /Rect [50 650 200 750]\n"
        b"   /InkList [[]]\n"
        b"   /C [0 0 1]\n"
        b"   /Contents (Zero-point ink stroke)\n"
        b">>"
    )

    # Page referencing the annotation.
    objects[page_num - 1] = (
        f"<< /Type /Page /Parent {pages_num} 0 R\n"
        f"   /MediaBox [0 0 612 792]\n"
        f"   /Annots [{annot_num} 0 R]\n"
        f">>"
    ).encode()

    # Pages dictionary.
    objects[pages_num - 1] = (
        f"<< /Type /Pages /Kids [{page_num} 0 R] /Count 1 >>"
    ).encode()

    # Catalog.
    objects[catalog_num - 1] = (
        f"<< /Type /Catalog /Pages {pages_num} 0 R >>"
    ).encode()

    buf = _raw_pdf(objects, catalog_num)
    if _write_if_changed(_out("zero_ink_stroke.pdf"), bytes(buf)):
        print("  Generated: zero_ink_stroke.pdf")


def generate_zero_polygon_vertices():
    """Minimal PDF with a polygon annotation whose vertices array is empty.

    PDFium's FPDFAnnot_GetVertices returns 0 for this annotation — the guard
    at pdfium_isolate.dart ~line 1089 returns an empty vertices list without
    allocating a native buffer.

    A polygon annotation with ``/Vertices []`` (empty array) is valid PDF
    syntax but cannot be produced by standard tooling.
    """
    objects = []

    def add(content):
        objects.append(content if isinstance(content, bytes) else content.encode())
        return len(objects)

    pages_num = add("")
    page_num = add("")
    annot_num = add("")
    catalog_num = add("")

    # Polygon annotation with an empty /Vertices array.
    objects[annot_num - 1] = (
        b"<< /Type /Annot /Subtype /Polygon\n"
        b"   /Rect [50 650 200 750]\n"
        b"   /Vertices []\n"
        b"   /C [1 0 0]\n"
        b"   /Contents (Zero-vertex polygon)\n"
        b">>"
    )

    objects[page_num - 1] = (
        f"<< /Type /Page /Parent {pages_num} 0 R\n"
        f"   /MediaBox [0 0 612 792]\n"
        f"   /Annots [{annot_num} 0 R]\n"
        f">>"
    ).encode()

    objects[pages_num - 1] = (
        f"<< /Type /Pages /Kids [{page_num} 0 R] /Count 1 >>"
    ).encode()

    objects[catalog_num - 1] = (
        f"<< /Type /Catalog /Pages {pages_num} 0 R >>"
    ).encode()

    buf = _raw_pdf(objects, catalog_num)
    if _write_if_changed(_out("zero_polygon_vertices.pdf"), bytes(buf)):
        print("  Generated: zero_polygon_vertices.pdf")


def generate_broken_image_metadata():
    """Minimal PDF with a streamless image XObject that causes metadata failure.

    A dict-only image XObject (no ``stream … endstream`` body) causes
    ``FPDFImageObj_GetImageMetadata`` to return false, firing the skip path at
    pdfium_isolate.dart ~lines 2039-2042.

    Empirically confirmed 2026-05-22: a corrupt FlateDecode stream body is NOT
    sufficient — PDFium reads metadata from the stream dictionary, not the
    pixel data.  A genuinely streamless XObject (dict only, no stream keyword)
    triggers the false-return path reliably.
    """
    import zlib

    objects = []

    def add(content):
        objects.append(content if isinstance(content, bytes) else content.encode())
        return len(objects)

    pages_num = add("")
    page_num = add("")
    xobj_num = add("")   # streamless image XObject
    catalog_num = add("")

    # Dict-only image XObject — deliberately omits ``stream … endstream``.
    # PDFium cannot locate the pixel data and returns false from
    # FPDFImageObj_GetImageMetadata.
    objects[xobj_num - 1] = (
        b"<< /Type /XObject /Subtype /Image\n"
        b"   /Width 4 /Height 4\n"
        b"   /ColorSpace /DeviceRGB\n"
        b"   /BitsPerComponent 8\n"
        b"   /Filter /FlateDecode\n"
        b"   /Length 0\n"
        b">>"
    )

    # Content stream that references the image XObject.
    content_stream = b"q 100 0 0 100 50 650 cm /Im1 Do Q"
    compressed_content = zlib.compress(content_stream)
    content_dict = (
        f"<< /Filter /FlateDecode /Length {len(compressed_content)} >>\n"
        f"stream\n"
    ).encode() + compressed_content + b"\nendstream"
    content_num = add(content_dict)

    objects[page_num - 1] = (
        f"<< /Type /Page /Parent {pages_num} 0 R\n"
        f"   /MediaBox [0 0 612 792]\n"
        f"   /Contents {content_num} 0 R\n"
        f"   /Resources << /XObject << /Im1 {xobj_num} 0 R >> >>\n"
        f">>"
    ).encode()

    objects[pages_num - 1] = (
        f"<< /Type /Pages /Kids [{page_num} 0 R] /Count 1 >>"
    ).encode()

    objects[catalog_num - 1] = (
        f"<< /Type /Catalog /Pages {pages_num} 0 R >>"
    ).encode()

    buf = _raw_pdf(objects, catalog_num)
    if _write_if_changed(_out("broken_image_metadata.pdf"), bytes(buf)):
        print("  Generated: broken_image_metadata.pdf")


if __name__ == "__main__":
    print(f"Generating test fixtures in: {os.path.abspath(OUTPUT_DIR)}")
    generate_full_metadata()
    generate_partial_metadata()
    generate_no_metadata()
    generate_corrupt()
    generate_password_protected()
    generate_single_column()
    generate_scanned()
    generate_mixed()
    generate_large()
    generate_soft_hyphens()
    generate_multi_column()
    generate_annotated_text()
    generate_annotated_shapes()
    generate_annotated_ink()
    generate_no_annotations()
    generate_multi_page_annotated()
    generate_single_image()
    generate_multi_image()
    generate_no_images()
    generate_popup_annotation()
    generate_popup_freetext()
    generate_popup_multi()
    generate_annotated_extra()
    generate_fit_toc()
    generate_empty_uri_link()
    generate_search_single()
    generate_search_multipage()
    generate_zero_ink_stroke()
    generate_zero_polygon_vertices()
    generate_broken_image_metadata()
    print("Done.")
    print("")
    print("Note: rtl.pdf is not generated (no Arabic font bundled).")
    print("See the module docstring for instructions on adding RTL support.")
