#!/usr/bin/env python3
"""Lane B3: independent check of an export in `zk60-trained-profile-export/1`.

Reads ONLY the exported files (no checkpoint, no solver state):
  * every array's sha256 against its manifest, dtype / shape / byte length;
  * the public tables regenerated from their keys with the native generators
    (exp_member(e_s, 64, f_e), the frozen SiLU member, rope_tables_generate)
    and their spec digests;
  * the profile's per-layer constants equal the layer manifests' (for keys
    the profile declares uniform);
  * for every exported sequence: x_in_L00 -> the exact integer block (the
    native witness relations, tlcalib.i_block) of every layer -> bit-exact
    x_out_LNN, and x_in_L(N+1) == x_out_LNN; no range refusal on the way.
Prints a JSON report; exit 1 on any mismatch. Calibration data, not a proof.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402

DT = {"int8": "<i1", "int16": "<i2", "int64": "<i8"}


def load_arr(d: Path, spec: dict, errs: list, name: str) -> np.ndarray:
    p = d / spec["file"]
    raw = p.read_bytes()
    if hashlib.sha256(raw).hexdigest() != spec["sha256"]:
        errs.append(f"{d.name}/{name}: sha256 mismatch")
    a = np.frombuffer(raw, dtype=DT[spec["dtype"]])
    if a.size != int(np.prod(spec["shape"])):
        errs.append(f"{d.name}/{name}: length {a.size} != shape {spec['shape']}")
        return a
    return a.reshape(spec["shape"]).astype(np.int64)


def main(root: Path) -> int:
    errs: list[str] = []
    prof = json.loads((root / "profile.json").read_text())
    T = prof["T"]
    g = tc.GEO
    want_shape = {"wq": [g.d, g.d], "wk": [g.kvw, g.d], "wv": [g.kvw, g.d], "wo": [g.d, g.d], "gamma_a": [g.d],
                  "gamma_m": [g.d], "wg_t": [g.d, g.f], "wu_t": [g.d, g.f], "wd_t": [g.f, g.d], "exp": [256],
                  "act": [256], "rope_cos": [T, g.half], "rope_sin": [T, g.half]}
    # sequences first (small), then the layers one at a time (memory: one layer)
    seqs = {}
    for sname in prof["sequences"]:
        sd = root / sname
        sman = json.loads((sd / "manifest.json").read_text())
        xs = {}
        for l in range(len(prof["layers"])):
            xs[("in", l)] = load_arr(sd, sman["arrays"][f"x_in_L{l:02d}"], errs, f"x_in_L{l:02d}").reshape(1, T, g.d)
            xs[("out", l)] = load_arr(sd, sman["arrays"][f"x_out_L{l:02d}"], errs, f"x_out_L{l:02d}").reshape(1, T, g.d)
            if l and not np.array_equal(xs[("in", l)], xs[("out", l - 1)]):
                errs.append(f"{sname}: x_in_L{l:02d} != x_out_L{l - 1:02d}")
        seqs[sname] = {"x": xs, "ok_layers": 0, "tokens": len(sman["token_ids"])}
    n_layers = 0
    for l, ent in enumerate(prof["layers"]):
        d = root / ent["dir"]
        mb = (d / "manifest.json").read_bytes()
        if hashlib.sha256(mb).hexdigest() != ent["manifest_sha256"]:
            errs.append(f"{ent['dir']}: manifest sha256 differs from profile.json")
        man = json.loads(mb)
        c = man["constants"]
        for k, v in prof["profile_constants"].items():
            if v is not None and c[k] != v:
                errs.append(f"{ent['dir']}: constant {k} {c[k]} != profile {v}")
        A = {}
        for name, spec in man["arrays"].items():
            if spec["shape"] != want_shape[name]:
                errs.append(f"{ent['dir']}/{name}: shape {spec['shape']} != {want_shape[name]}")
            raw = (d / spec["file"]).read_bytes()
            if hashlib.sha256(raw).hexdigest() != spec["sha256"]:
                errs.append(f"{ent['dir']}/{name}: sha256 mismatch")
            A[name] = np.frombuffer(raw, dtype=DT[spec["dtype"]]).reshape(spec["shape"])
        e_t, e_d = b3.exp_member(c["exp_e_s"], g.dh, c["f_e"])
        if not np.array_equal(A["exp"], e_t) or e_d != man["tables"]["exp"]["spec_digest"]:
            errs.append(f"{ent['dir']}: exp table is not exp_member({c['exp_e_s']}, 64, {c['f_e']})")
        mem = b3.silu_member(*c["silu_member"])
        if mem is None or not np.array_equal(A["act"], mem[0]) or mem[1] != man["tables"]["act"]["spec_digest"]:
            errs.append(f"{ent['dir']}: act table is not the frozen SiLU member {c['silu_member']}")
        rc, rs = b3.rope_generate(T, g.dh, c["rope_theta"], c["f_ro"])
        if not (np.array_equal(A["rope_cos"], rc) and np.array_equal(A["rope_sin"], rs)):
            errs.append(f"{ent['dir']}: rope tables differ from rope_tables_generate")
        for n in ("wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t", "gamma_a", "gamma_m"):
            if int(A[n].min()) == -128:
                errs.append(f"{ent['dir']}/{n}: an int8 word is -128")
        P = tc.LayerInt(wq=A["wq"], wk=A["wk"], wv=A["wv"], wo=A["wo"], gamma_a=A["gamma_a"], gamma_m=A["gamma_m"],
                        wg_t=A["wg_t"], wu_t=A["wu_t"], wd_t=A["wd_t"], exp=A["exp"].astype(np.int64), act=A["act"],
                        cn_a=c["norm_cn_a"], cn_m=c["norm_cn_m"], tn=c["norm_tn"], ceps=c["norm_ceps"],
                        norm_wrho=tc.norm_window(g.d, c["norm_tn"]), sh_qkv=c["sh_qkv"], sh_rope=c["sh_rope"],
                        sh_s=c["sh_s"], sh_o=c["sh_o"], sh_ao=c["sh_ao"], sh_g=c["sh_g"], sh_u=c["sh_u"], sh_h=c["sh_h"],
                        sh_z=c["sh_z"], f_e=c["f_e"], f_p=c["f_p"], f_ro=c["f_ro"], sh_r2=c["sh_r2"])
        for sname, sq in seqs.items():
            rec = tc.Rec(1)
            y = tc.i_block(sq["x"][("in", l)], P, (rc, rs), rec)
            if rec.first[0] is not None:
                errs.append(f"{sname}: layer {l} refuses at {rec.first[0]}")
            if np.array_equal(y, sq["x"][("out", l)]):
                sq["ok_layers"] += 1
            else:
                errs.append(f"{sname}: layer {l} recomputed output differs from x_out ({int((y != sq['x'][('out', l)]).sum())} words)")
        del P, A
        n_layers += 1
    seq_rep = {k: {"layers_bit_exact": v["ok_layers"], "tokens": v["tokens"]} for k, v in seqs.items()}
    report = {"export": str(root), "layers": n_layers, "sequences": seq_rep, "errors": errs, "ok": not errs}
    print(json.dumps(report, indent=1))
    return 0 if not errs else 1


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1])))
