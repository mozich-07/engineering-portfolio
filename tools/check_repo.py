import json
from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'catalog.json').read_text(encoding='utf-8'))
assert len({entry['id'] for entry in catalog}) == len(catalog)
slugs = {entry['slug'] for entry in catalog}
assert len(slugs) == len(catalog)
assert slugs == {entry.name for entry in (root / 'projects').iterdir() if entry.is_dir()}
for entry in catalog:
    assert re.fullmatch(r'P\d{2}', entry['id'])
    slug = entry['slug']
    assert re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', slug)
    assert entry['tier'] in {'featured', 'project', 'lab'}
    page = (root / 'projects' / slug / 'README.md').read_text(encoding='utf-8')
    for label in ('功能与当前边界', '本人工作', '后续计划'):
        assert label in page, slug

for file in [root / 'README.md', *(root / 'projects').glob('*/README.md')]:
    page = file.read_text(encoding='utf-8')
    for link in re.findall(r'\]\(((?!https?://)[^()]+)\)', page):
        target = (file.parent / link).resolve()
        assert target.is_relative_to(root) and target.exists(), (file.name, link)
    assert not re.search(r'\b[A-Z]:[/\\]|\b1[3-9]\d{9}\b|\d{5,}@qq\.com', page, re.I), file

sample = json.loads((root / 'projects/quiz-bank-workshop/work/banks.json').read_text(encoding='utf-8'))
assert len(sample) == 1 and len(sample[0]['questions']) == 2
assert '人工样例' in sample[0]['name']
assert not any(question['media'] for question in sample[0]['questions'])
print(f'{len(catalog)} 项：目录、说明链接、人工题库检查通过。')
