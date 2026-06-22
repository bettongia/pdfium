#!/usr/bin/env python3
# Copyright 2026 The Authors. See the AUTHORS file for details.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Create an easy to use entry for the citation table in test/data/arxiv/README.md"""

import io
import json
import sys
from pathlib import Path
import time

import arxiv

from extract_text import extract
from extract_meta import extract as extract_meta

arxiv_client = arxiv.Client(delay_seconds=5)


def get_arxiv_metadata(paper_id: str, cache_path: Path):
    # Drop the arxiv: prefix
    paper_id = paper_id.replace("arXiv:", "")

    cache_path.mkdir(exist_ok=True)

    cached_file = Path(cache_path, f"{paper_id}.json")

    if cached_file.exists():
        with open(cached_file, "r") as file:
            return json.load(file)

    try:
        # Fetch paper metadata
        search = arxiv.Search(id_list=[paper_id])
        paper = next(arxiv_client.results(search))
        with open(cached_file, "w") as file:
            paper_map = {
                "authors": [author.name for author in paper.authors],
                "title": paper.title,
                "year": paper.published.year,
                "url": paper.entry_id,
            }
            json.dump(paper_map, file)
    except StopIteration:
        print(f"Error: No paper found with ID '{paper_id}'", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error fetching data: {e}", file=sys.stderr)
        sys.exit(1)

    return paper_map


def get_citation(paper):
    # Format data
    authors = ", ".join([author for author in paper["authors"]])
    title = paper["title"]
    year = paper["year"]
    url = paper["url"]

    return f"{authors} ({year}). {title}. arXiv preprint {url}"


def main():
    # Setup CLI arguments

    directory = Path("test/data/arxiv")
    extension = "*.pdf"
    txt_extension = ".txt.json"
    meta_extension = ".meta.json"

    citation_file = Path(directory, "citations.md")

    buffer = io.StringIO()
    buffer.writelines(
        [
            "| ID | Citation | PDF File | Text File |\n",
            "| -- | -------- | -------- | --------- |\n",
        ]
    )

    flag = False
    for file_path in directory.glob(extension):
        print(f"Paper: {file_path}")
        paper_id = file_path.stem

        paper = get_arxiv_metadata(paper_id, Path(directory, ".cache"))

        citation = get_citation(paper)

        txt_file_path = Path(directory, f"{file_path.stem}{txt_extension}")
        meta_file_path = Path(directory, f"{file_path.stem}{meta_extension}")

        if not txt_file_path.exists():
            print(f"Extracting plain text for {file_path} to {txt_file_path}")
            text = extract(file_path)
            text_json = json.dumps(text, indent=2, ensure_ascii=False)
            txt_file_path.write_text(text_json)

        if not meta_file_path.exists():
            print(f"Extracting metadata for {file_path} to {meta_file_path}")
            meta = extract_meta(file_path)
            meta_json = json.dumps(meta, indent=2, ensure_ascii=False)
            meta_file_path.write_text(meta_json)

        buffer.write(
            f"| {paper["url"]} | {citation} | [{file_path.name}]({file_path.name}) | [{txt_file_path.name}]({txt_file_path.name}) |\n"
        )

    citation_file.write_text(buffer.getvalue())


if __name__ == "__main__":
    main()
