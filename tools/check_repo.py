import json
import re
from pathlib import Path
from urllib.parse import urlsplit

root = Path(__file__).resolve().parents[1]
entries = json.loads((root / "catalog.json").read_text(encoding="utf-8"))
ids = [entry["id"] for entry in entries]
assert len(ids) == len(set(ids))
pages = set()
for entry in entries:
    assert re.fullmatch(r"P\d{2}", entry["id"])
    page = (root / entry["page"]).resolve()
    assert page.is_relative_to(root) and page.is_file(), page
    pages.add(page)
for project in (root / "projects").glob("*/README.md"):
    assert project.resolve() in pages, project

collection_pages = {p.resolve() for p in (root / "collections").glob("*/README.md")}
public_pages = {
    root / "README.md", *pages, *collection_pages,
    *(root / "collections").glob("*/details/*.md"),
    *(root / "projects").glob("*/examples/*.md"),
    *(root / "docs").glob("*.md"),
}
outgoing = {}

for page in sorted(public_pages):
    outgoing[page] = set()
    content = page.read_text(encoding="utf-8")
    links = re.findall(r'\]\(([^()]+)\)|<img\b[^>]*\bsrc="([^"]+)"', content)
    for markdown, image in links:
        link = urlsplit(markdown or image)
        if link.scheme or not link.path:
            continue
        dest = (page.parent / link.path).resolve()
        assert dest.is_relative_to(root) and dest.exists(), (page, link.path)
        if dest.is_dir():
            readme = dest / "README.md"
            if readme.exists():
                dest = readme
        outgoing[page].add(dest)
    assert not re.search(r'\b[A-Z]:[/\\]|\b1[3-9]\d{9}\b|\d{5,}@qq\.com', content, re.I), page

# Check the navigation a visitor actually follows from the landing page.
seen = set()
pending = [root / "README.md"]
while pending:
    here = pending.pop()
    if here not in seen:
        seen.add(here)
        pending.extend(outgoing.get(here, ()))
assert not (pages | collection_pages) - seen, (pages | collection_pages) - seen

by_id = {entry["id"]: root / entry["page"] for entry in entries}
for collection, ids in {
    "ml": "02 10 13 14 41 42 43 44 45",
    "imaging": "01 09 10 11 12 14 15 16 34 40 41 46",
}.items():
    index = root / "collections" / collection / "README.md"
    for number in ids.split():
        assert by_id["P" + number] in outgoing[index], (index, number)

sample = json.loads((root / "projects/quiz-bank-workshop/work/banks.json").read_text(encoding="utf-8"))
assert len(sample) == 1 and len(sample[0]["questions"]) == 2
assert "人工样例" in sample[0]["name"]
assert not any(question["media"] for question in sample[0]["questions"])
print(f"{len(entries)} records mapped to {len(pages)} pages. Links and demo bank OK.")
