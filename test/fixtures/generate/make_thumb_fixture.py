#!/usr/bin/env python3
# Copyright 2026 The Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Create a minimal test fixture PDF with two pages:
  - Page 0 has an embedded /Thumb entry (a 4x4 RGB thumbnail, solid cornflower blue).
  - Page 1 has no /Thumb entry.

The PDF is written as raw bytes without any external library so it can be
generated in a sandboxed environment without network access.
"""

import zlib


def make_thumbnail_pdf(path):
    # Create a minimal 4x4 RGB image for the thumbnail.
    # PDFium's FPDFPage_GetThumbnailAsBitmap will decode this to a bitmap.
    # Using RGB (no alpha) exercises the BGRx/BGR code path in the handler.
    width, height = 4, 4
    # Each pixel: R=100, G=149, B=237 (cornflower blue)
    row = bytes([100, 149, 237] * width)
    raw_image = row * height

    # Compress with zlib (FlateDecode filter).
    compressed = zlib.compress(raw_image, level=9)

    objects = []

    def add_obj(content: bytes) -> int:
        obj_num = len(objects) + 1
        objects.append(content)
        return obj_num

    # Reserve object slots upfront so we can reference forward
    catalog_num = add_obj(b"")   # obj 1
    thumb_num = add_obj(b"")     # obj 2
    page0_num = add_obj(b"")     # obj 3
    page1_num = add_obj(b"")     # obj 4
    pages_num = add_obj(b"")     # obj 5

    # Build actual content for each object
    # Catalog
    objects[catalog_num - 1] = (
        f"<< /Type /Catalog /Pages {pages_num} 0 R >>"
    ).encode()

    # Thumbnail image stream (RGB, no alpha channel)
    thumb_stream_header = (
        f"<< /Type /XObject /Subtype /Image "
        f"/Width {width} /Height {height} "
        f"/ColorSpace /DeviceRGB "
        f"/BitsPerComponent 8 "
        f"/Filter /FlateDecode "
        f"/Length {len(compressed)} >>\n"
        f"stream\n"
    ).encode()
    objects[thumb_num - 1] = (
        thumb_stream_header + compressed + b"\nendstream"
    )

    # Page 0 with /Thumb entry
    objects[page0_num - 1] = (
        f"<< /Type /Page /Parent {pages_num} 0 R "
        f"/MediaBox [0 0 200 200] "
        f"/Thumb {thumb_num} 0 R >>"
    ).encode()

    # Page 1 without /Thumb
    objects[page1_num - 1] = (
        f"<< /Type /Page /Parent {pages_num} 0 R "
        f"/MediaBox [0 0 200 200] >>"
    ).encode()

    # Pages dictionary
    objects[pages_num - 1] = (
        f"<< /Type /Pages "
        f"/Kids [{page0_num} 0 R {page1_num} 0 R] "
        f"/Count 2 >>"
    ).encode()

    # Serialise to PDF
    buf = bytearray()
    buf += b"%PDF-1.4\n"
    buf += b"%\xe2\xe3\xcf\xd3\n"  # binary comment marker

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

    with open(path, "wb") as f:
        f.write(buf)

    print(f"Written {len(buf)} bytes to {path}")
    print(f"  Page 0: has /Thumb (obj {thumb_num}), {width}x{height} RGB FlateDecode")
    print(f"  Page 1: no /Thumb")


make_thumbnail_pdf(
    "/Users/gonk/development/bettongia/pdfart/test/data/thumbnail_fixture.pdf"
)
