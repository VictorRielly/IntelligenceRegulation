"""Copy only public R13 arrays from the authenticated Astra candidate.

This is an adapter, not a quantizer. Rust must regenerate/check every table
and every derived coefficient. Weight/proof import is a later gate.
"""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
ASTRA=HERE.parent.parent/"zk60_shieldstral_export_20261026"
ROOT=ASTRA/"s2_evaluation_t256"
OUT=HERE/"shieldstral-intake-arrays"

def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda:f.read(1<<20),b""):h.update(b)
    return h.hexdigest()

audit=json.loads((ASTRA/"native_candidate_audit.json").read_text())
assert sha(ROOT/"complete.json")==audit["evaluation_export_sha256"]
complete=json.loads((ROOT/"complete.json").read_text())
fixdir=ASTRA/"layer25_fix_candidate"
assert sha(fixdir/"complete.json")==audit["candidate"]["complete_sha256"]
fixmeta=json.loads((fixdir/"complete.json").read_text())
assert sha(fixdir/"candidate.npz")==fixmeta["candidate_sha256"]
assert complete["layers"]==len(audit["layers"])==26
OUT.mkdir(exist_ok=False)
manifest={"scope":"actual public-array native-loader intake only; no weight import or proof acceptance",
    "audit_sha256":sha(ASTRA/"native_candidate_audit.json"),"adapter_sha256":sha(Path(__file__)),
    "evaluation_export_sha256":sha(ROOT/"complete.json"),"candidate_sha256":fixmeta["candidate_sha256"],"layers":[]}
with np.load(fixdir/"candidate.npz",allow_pickle=False) as fix:
    for layer in audit["layers"]:
        i=layer["layer"]; source=ROOT/f"layer_{i:02d}"
        assert sha(source/"ready.json")==complete["layers_sha256"][i]
        ready=json.loads((source/"ready.json").read_text())
        # Hash only these exact input files, required by the native intake gate.
        for name,digest in ready["files"].items():assert sha(source/name)==digest,(i,name)
        target=OUT/f"layer_{i:02d}";target.mkdir()
        arrays={}
        with np.load(source/"arrays.npz",allow_pickle=False) as data:
            payload={"m_"+site:fix["mult_u"] if i==25 and site=="u" else data["extra__mult_"+site]
                for site in "qkvogud"}
            get=(lambda key:fix[key]) if i==25 else (lambda key:data["extra__"+key])
            payload.update(silu_group_ids=get("group_ids"),silu_groups=np.array(layer["group_members"]),act=get("group_tables"))
            for name,value in payload.items():
                dtype="<i2" if name=="act" else "<i8"
                a=np.asarray(value,dtype=dtype)
                path=target/(name+".bin");path.write_bytes(a.tobytes(order="C"))
                arrays[name]={"file":path.name,"dtype":"int16" if name=="act" else "int64","shape":list(a.shape),"sha256":sha(path)}
        row={"index":i,"directory":target.name,"source_archive_sha256":ready["files"]["arrays.npz"],
            "constants":layer["constants"],"arrays":arrays}
        for key in ("gate_common_shift","folded_gate_multiplier_max","aligned_product_shift","derived_table_max_abs"):
            row[key]=layer[key]
        manifest["layers"].append(row)
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print(json.dumps({"layers":len(manifest["layers"]),"manifest_sha256":sha(OUT/"manifest.json"),"scope":manifest["scope"]}))
