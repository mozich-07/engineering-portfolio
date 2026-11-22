"""Audit COCO annotations, group adjacent camera frames, export three-stage YOLO."""
import json, hashlib, re, random, collections, shutil
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageOps

W = Path(__file__).resolve().parent
R = W.parent.parent
D = R / "源码与数据/data"
E = R / "实验记录与来源"

def phash(im):
    a = cv2.resize(np.asarray(im.convert("L")), (32,32)).astype(np.float32)
    d = cv2.dct(a)[:8,:8].flatten()[1:]
    return sum(int(v>np.median(d)) << i for i,v in enumerate(d))

def main():
    sources = list((W/"raw").rglob("*.json"))
    records = []
    for source in sources:
        data = json.loads(source.read_text())
        if not isinstance(data,dict) or "annotations" not in data: continue
        categories = {c["id"]:c["name"] for c in data["categories"]}
        anns = collections.defaultdict(list)
        for a in data["annotations"]: anns[a["image_id"]].append(a)
        for item in data["images"]:
            found = list((W/"raw").rglob(Path(item["file_name"]).name))
            assert len(found)==1, (item["file_name"],found)
            f=found[0]
            with Image.open(f) as im:
                im=ImageOps.exif_transpose(im)
                im.load(); w,h=im.size
                assert (w,h)==(item["width"],item["height"])
                digest=hashlib.sha256(f.read_bytes()).hexdigest()
                percept=phash(im)
            labels=[]
            for a in anns[item["id"]]:
                cat=categories[a["category_id"]]
                cls=0 if cat.endswith("_green") else 1 if cat.endswith("_half_ripened") else 2
                x,y,bw,bh=a["bbox"]
                assert bw>0 and bh>0 and x>=0 and y>=0
                assert x+bw<=w+1 and y+bh<=h+1, (f,a)
                labels.append([cls,(x+bw/2)/w,(y+bh/2)/h,bw/w,bh/h])
            match=re.match(r"(.*?)(\d+)$",f.stem)
            # Consecutive filenames are a conservative proxy for a capture sequence.
            group=f"{match[1]}{int(match[2])//10:05d}" if match else f.stem
            records.append(dict(file=f.name,path=str(f),sha256=digest,phash=percept,
                group=group,original_split=source.stem,width=w,height=h,labels=labels))
    # Merge adjacent-image groups when perceptual hashes are very close.
    parents={r["group"]:r["group"] for r in records}
    def find(x):
        while parents[x]!=x: x=parents[x]
        return x
    near=[]
    duplicates=[]
    seen={}
    clean=[]
    for r in records:
        if r["sha256"] in seen:
            duplicates.append([r["file"],seen[r["sha256"]]]);continue
        seen[r["sha256"]]=r["file"]; clean.append(r)
    records=clean
    for i,a in enumerate(records):
        for b in records[i+1:]:
            distance=(a["phash"]^b["phash"]).bit_count()
            if distance<=6:
                parents[find(b["group"])]=find(a["group"])
                near.append([a["file"],b["file"],distance])
    for r in records:r["group"]=find(r["group"])
    groups=sorted(set(r["group"] for r in records))
    random.Random(20261021).shuffle(groups)
    n=len(groups)
    assignments={g:("train" if i<int(n*.7) else "val" if i<int(n*.85) else "test")
                 for i,g in enumerate(groups)}
    summary={}
    manifest=[]
    for split in ["train","val","test"]:
        (D/f"images/{split}").mkdir(parents=True,exist_ok=True)
        (D/f"labels/{split}").mkdir(parents=True,exist_ok=True)
        selected=[r for r in records if assignments[r["group"]]==split]
        counts=collections.Counter()
        for r in selected:
            with Image.open(r["path"]) as im:
                im=ImageOps.exif_transpose(im).convert("RGB");im.thumbnail((1280,1280))
                im.save(D/f"images/{split}"/r["file"],quality=92)
            txt="\n".join(" ".join([str(a[0])]+[f"{x:.7f}" for x in a[1:]]) for a in r["labels"])
            (D/f"labels/{split}"/Path(r["file"]).with_suffix(".txt")).write_text(txt,encoding="utf-8")
            counts.update(a[0] for a in r["labels"])
            manifest.append({k:v for k,v in r.items() if k not in ("path","labels","phash")}|{
                "split":split,"boxes":len(r["labels"]),"phash":hex(r["phash"]),
                "stage_counts":[sum(a[0]==c for a in r["labels"]) for c in range(3)]})
        summary[split]={"images":len(selected),"groups":len(set(r["group"] for r in selected)),
                        "boxes":sum(counts.values()),"class_counts":dict(sorted(counts.items()))}
        assert set(counts)=={0,1,2}
    (D/"dataset.yaml").write_text("train: images/train\nval: images/val\ntest: images/test\nnames:\n  0: green\n  1: half_ripened\n  2: fully_ripened\n",encoding="utf-8")
    (W/"data_absolute.yaml").write_text(f"path: {D.as_posix()}\n"+(D/"dataset.yaml").read_text(),encoding="utf-8")
    (E/"split_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    audit={"seed":20261021,"summary":summary,"duplicates_removed":duplicates,
           "near_pairs_merged":near,"group_rule":"camera filename prefix + floor(frame number / 10), union phash distance <= 6",
           "limitation":"相邻文件号与感知哈希仅为拍摄场景代理；缺少植株身份，不能证明跨植株或跨农场独立。",
           "resize":"先按EXIF旋转至标注方向，再等比例缩小长边至1280像素，JPEG质量92；框坐标归一化保持不变。"}
    (E/"data_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(audit,ensure_ascii=False,indent=2))
    shutil.copytree(W/"sources",E/"来源文件",dirs_exist_ok=True,ignore=shutil.ignore_patterns("*.pt"))
    # A representative label contact sheet for manual visual verification.
    canvas=Image.new("RGB",(1200,800),"white")
    for i,r in enumerate(records[::max(1,len(records)//6)][:6]):
        im=ImageOps.exif_transpose(Image.open(r["path"])).convert("RGB");im.thumbnail((390,360))
        dr=ImageDraw.Draw(im)
        for c,x,y,w,h in r["labels"]:
            a=[(x-w/2)*im.width,(y-h/2)*im.height,(x+w/2)*im.width,(y+h/2)*im.height]
            dr.rectangle(a,outline=["#36d573","#ffd03c","#ff504e"][c],width=2)
        x=i%3*400;y=i//3*400;canvas.paste(im,(x,y+25));ImageDraw.Draw(canvas).text((x+5,y+3),r["file"],fill="black")
    canvas.save(E/"label_audit.jpg")

if __name__=="__main__":main()
