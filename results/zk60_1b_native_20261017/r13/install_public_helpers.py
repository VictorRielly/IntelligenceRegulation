from pathlib import Path
import shutil
import hashlib
import json

p=Path(__file__).resolve().parent
src=p/"working-tree/hashline/src/private_block"
assert (p/"witness-assign.done").read_text().strip()=="0"
assert (p/"witness-legacy-proof.done").read_text().strip()=="0"
manifest={}
for folder,name in [("fold-next","accuracy_fold"),("act-next","accuracy_act")]:
    target=src/(name+".rs");assert not target.exists()
    shutil.copy2(p/folder/(name+".rs"),target)
    manifest[target.name]=hashlib.sha256(target.read_bytes()).hexdigest()
(p/"public-helpers-installed.json").write_text(json.dumps(manifest,indent=2)+"\n")
