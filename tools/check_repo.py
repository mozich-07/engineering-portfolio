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
for folder in ("projects", "collections"):
    assert all(p.resolve() in pages for p in (root / folder).glob("*/README.md"))

for page in [root / "README.md", *pages, *sorted((root / "docs").glob("*.md"))]:
    content = page.read_text(encoding="utf-8")
    links = re.findall(r'\]\(([^()]+)\)|<img\b[^>]*\bsrc="([^"]+)"', content)
    for markdown, image in links:
        link = urlsplit(markdown or image)
        if link.scheme or not link.path:
            continue
        dest = (page.parent / link.path).resolve()
        assert dest.is_relative_to(root) and dest.exists(), (page.name, link.path)
    assert not re.search(r'\b[A-Z]:[/\\]|\b1[3-9]\d{9}\b|\d{5,}@qq\.com', content, re.I), page

sample = json.loads((root / "projects/quiz-bank-workshop/work/banks.json").read_text(encoding="utf-8"))
assert len(sample) == 1 and len(sample[0]["questions"]) == 2
assert "人工样例" in sample[0]["name"]
assert not any(question["media"] for question in sample[0]["questions"])
print(f"{len(entries)} records mapped to {len(pages)} pages. Links and demo bank OK.")
