#!/usr/bin/env python3
"""Write a calibration variant as a full `zk60-trained-profile-export/1` export in the
native R8 per-layer-constant format (coordinator brief 2026-10-19 ~13:45 UTC):

* any of norm_cn_a, norm_cn_m, norm_ceps, sh_ao, sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z that
  differs between layers is `null` in profile.json `profile_constants` AND listed in
  `per_layer_constants_differ` (exactly the null keys; exp_e_s / silu_member as today);
  each layer manifest's `constants` carries that layer's integer;
* norm_tn, f_e, rope_theta, sh_rope, sh_u, f_p, f_ro, sh_r2 must be run-wide (asserted);
  every per-layer constant is checked against the declared classes;
* the exported sequences (the reference export's held-out token ids) are chained through the
  calibration lane's integer reference `tlcalib.i_block` at each layer's own constants and
  must be accepted at every layer; `fp_lib.rx_block` (all sites exact) is cross-checked equal;
* rotation, token_io (embedding table / 8B head) and licence files are hard-linked from the
  reference export when the residual scales are identical (asserted), else refused.

  [ZK60_MODEL=llama3-8b] python3 fp_export.py --variant VARIANT_DIR --ref REF_EXPORT --name NAME
        [--words-from RUN_TAG] [--fidelity-run RUN_TAG]
Output: exports/NAME. Calibration data, not a proof, not a privacy claim.
"""
import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
from fp_lib import tc, GEO  # noqa: E402
from fp_selfcheck import layerint  # noqa: E402

PER_LAYER_OK = ("norm_cn_a", "norm_cn_m", "norm_ceps", "sh_ao", "sh_qkv", "sh_s", "sh_o", "sh_g", "sh_h", "sh_z",
                "exp_e_s", "silu_member")
RUN_WIDE = ("norm_tn", "f_e", "rope_theta", "sh_rope", "sh_u", "f_p", "f_ro", "sh_r2")
CLASSES = {"norm_tn": (1, 16), "norm_cn_a": (1, 1 << 20), "norm_cn_m": (1, 1 << 20), "norm_ceps": (1, 1 << 40),
           "sh_ao": (0, 8), "sh_qkv": (1, 8), "sh_s": (1, 8), "sh_g": (1, 8), "sh_z": (1, 8), "sh_o": (9, 16), "sh_h": (9, 16),
           "exp_e_s": (-8, 8)}
WORDS = ("wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t")


def sha(p: Path) -> str:
    return fl.sha_file(p)


def write_bin(dirp: Path, name: str, arr: np.ndarray, dtype: str) -> dict:
    a = np.ascontiguousarray(arr).astype(dtype)
    p = dirp / f"{name}.bin"
    p.write_bytes(a.tobytes())
    return {"file": p.name, "dtype": {"<i1": "int8", "<i2": "int16", "<i8": "int64"}[dtype], "shape": list(a.shape), "sha256": sha(p)}


def rebuild_token_io(td: Path, rtd: Path, s_in0: float, s_out: float, rmeta: dict):
    """TOKEN_IO_SPEC at new residual scales: the int16 embedding table (every vocabulary row,
    refuse outside int16) and the final norm's Ceps / Cn by the b8_token_io rule (tlcalib.norm_site
    with c = 1 on the reference's calibration xhat maxima, margin 0.5, tn = 9)."""
    R = fl.b3.Rotation(GEO.d, int(rmeta["rotation"]["seed"]))
    raw = fl.bf16_memmap("model.embed_tokens.weight")
    V = raw.shape[0]
    with open(td / "embedding_int16.bin", "wb") as fh:
        for v0 in range(0, V, 4096):
            xr = R.fwd((np.asarray(raw[v0:v0 + 4096]).astype(np.uint32) << 16).view(np.float32).astype(np.float64)).astype(np.float32)
            q = np.floor(xr.astype(np.float64) / s_in0 + 0.5)
            if np.abs(q).max() > 32767:
                raise ValueError(f"embedding rows {v0}.. leave int16 at s_in {s_in0}")
            fh.write(q.astype("<i2").tobytes())
    hm = json.loads((rtd / "head_manifest.json").read_text())
    ch = np.frombuffer((rtd / "calib_final_xhat_rot_absmax.bin").read_bytes(), dtype="<f8")
    assert ch.shape == (GEO.d,)
    nrep = {}
    fn0 = hm["final_norm"]
    g8, cn, tn_s, ceps, s_y, _ = tc.norm_site(np.ones(GEO.d), ch, [], "final_norm", tc.CalibOptions(margin=0.5, tn=int(fn0["tn"])), s_out, nrep, "final_norm")
    assert int(tn_s) == int(fn0["tn"]) and np.all(g8 == 127) and 1 <= cn <= (1 << 20)
    hm["final_norm"] = {**fn0, "ceps": int(ceps), "cn_calibrated": int(cn)}
    hm["rebuilt_by"] = "fidelity lane fp_export.py --rebuild-token-io (new residual scale; head words / multipliers unchanged)"
    (td / "head_manifest.json").write_text(json.dumps(hm, indent=1, sort_keys=True))
    return {"embedding_sha256": sha(td / "embedding_int16.bin"), "final_norm": hm["final_norm"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--words-from", default="", help="fp_eval run tag whose saved words (GPTQ) replace the variant's")
    ap.add_argument("--fidelity-run", default="", help="fp_eval run tag whose metrics go into fidelity_T")
    ap.add_argument("--class-change", default="", help="EVALUATION exports only: widen the declared class of these keys "
                    "'key:hi,...' (e.g. sh_qkv:16,sh_g:16,sh_z:16 for two-byte remainders); recorded in profile.json; the native "
                    "prover refuses such an export until the class change is built and reviewed")
    ap.add_argument("--rebuild-token-io", action="store_true",
                    help="residual scales differ from the reference: rebuild the int16 embedding table and the final-norm Ceps "
                         "(head words, multipliers and the calibration xhat maxima are scale-free and stay hard links)")
    a = ap.parse_args()
    t0 = time.time()
    cc = {k: int(v) for k, v in (t.split(":") for t in a.class_change.split(",") if t)}
    for k, hi in cc.items():
        CLASSES[k] = (CLASSES[k][0], hi)
    var, ref = Path(a.variant), Path(a.ref)
    out = fl.HERE / "exports" / a.name
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"{out} exists and is not empty")
    out.mkdir(parents=True, exist_ok=True)
    vprof = json.loads((var / "profile.json").read_text())
    rprof = json.loads((ref / "profile.json").read_text())
    T = int(vprof["T"])
    assert T == int(rprof["T"])
    L = len(vprof["layers"])
    vmeta, rmeta = vprof["metadata_out_of_proof"], rprof["metadata_out_of_proof"]
    s_in, s_out = [float(x) for x in vmeta["residual_scales_in"]], [float(x) for x in vmeta["residual_scales_out"]]
    same_scales = (s_in == [float(x) for x in rmeta["residual_scales_in"]]) and (s_out == [float(x) for x in rmeta["residual_scales_out"]])
    assert same_scales or a.rebuild_token_io, "residual scales differ from the reference: rerun with --rebuild-token-io"
    rebuild = not same_scales
    wsrc = (fl.HERE / "runs" / fl.MODEL / a.words_from) if a.words_from else None
    # ---------------- layers
    consts, layers, replaced = [], [], {}
    for l in range(L):
        src, dst = var / f"layer_{l:02d}", out / f"layer_{l:02d}"
        dst.mkdir()
        man = json.loads((src / "manifest.json").read_text())
        z = np.load(wsrc / f"words_L{l:02d}.npz") if wsrc is not None else None
        changed = []
        for name, arr in man["arrays"].items():
            fsrc = src / arr["file"]
            assert sha(fsrc) == arr["sha256"], f"layer {l} {name}: source sha256"
            if z is not None and name in z.files:
                old = np.frombuffer(fsrc.read_bytes(), dtype=fl.DT[arr["dtype"]]).reshape(arr["shape"])
                new = z[name]
                assert new.shape == old.shape and new.dtype == np.int8 and int(np.abs(new.astype(np.int64)).max()) <= 127
                if not np.array_equal(new, old):
                    man["arrays"][name] = write_bin(dst, name, new, "<i1")
                    changed.append(name)
                    continue
            os.link(fsrc, dst / arr["file"])
        if changed:
            man["variant"] = a.name
            man["metadata_out_of_proof"]["word_rounding"] = {"method": "GPTQ at fixed scales (fp_gptq.py)", "run": a.words_from,
                                                            "words_changed": changed}
        (dst / "manifest.json").write_text(json.dumps(man, indent=1, sort_keys=True))
        replaced[l] = changed
        c = man["constants"]
        for k, (lo, hi) in CLASSES.items():
            assert lo <= int(c[k]) <= hi, f"layer {l}: {k} = {c[k]} outside the declared class [{lo}, {hi}]"
        consts.append(c)
        layers.append({"dir": dst.name, "layer": l, "manifest_sha256": sha(dst / "manifest.json")})
    keys = list(consts[0])
    differ = sorted(k for k in keys if any(json.dumps(c[k]) != json.dumps(consts[0][k]) for c in consts))
    bad = [k for k in differ if k not in PER_LAYER_OK]
    assert not bad, f"run-wide constants differ between layers: {bad}"
    assert consts[0]["norm_tn"] == {"tinyllama": 10, "llama3-8b": 9}[fl.MODEL], "norm_tn must stay the run's value"
    pc = {k: (None if k in differ else consts[0][k]) for k in keys}
    # ---------------- rotation, token_io, licence files (hard links from the reference)
    for f in ("rotation.json", "rotation_sign.bin", "embedding_int16.bin", "token_io.json", "LICENSE", "USE_POLICY.md", "NOTICE"):
        if (ref / f).exists() and not (rebuild and f in ("embedding_int16.bin", "token_io.json")):
            os.link(ref / f, out / f)
    if (ref / "token_io").is_dir():
        # the data files are the reference's (hard links); token_io.json / SHA256SUMS are rewritten below for
        # THIS export's checks (x_out changed); the reference's README.md (its own checks) is not carried over
        (out / "token_io").mkdir()
        for f in sorted((ref / "token_io").iterdir()):
            if f.name in ("token_io.json", "README.md", "SHA256SUMS"):
                continue
            if rebuild and f.name in ("embedding_int16.bin", "head_manifest.json", "f2_fidelity.json"):
                continue
            os.link(f, out / "token_io" / f.name)
        if rebuild:
            rebuild_token_io(out / "token_io", ref / "token_io", s_in[0], s_out[-1], rmeta)
    assert hashlib.sha256((out / "rotation_sign.bin").read_bytes()).hexdigest() == rmeta["rotation"]["sign_sha256"]
    # ---------------- sequences through the integer reference
    tab_path = out / "embedding_int16.bin" if (out / "embedding_int16.bin").exists() else out / "token_io" / "embedding_int16.bin"
    tab = np.memmap(tab_path, dtype="<i2", mode="r").reshape(-1, GEO.d)
    seqs = []
    for sname in rprof["sequences"]:
        rman = json.loads((ref / sname / "manifest.json").read_text())
        toks = np.array(rman["token_ids"], dtype=np.int64)
        x = np.asarray(tab[toks], dtype=np.int64)[None]
        sd = out / sname
        sd.mkdir()
        files = {}
        for l in range(L):
            man = json.loads((out / f"layer_{l:02d}" / "manifest.json").read_text())
            words = {n: np.frombuffer((out / f"layer_{l:02d}" / ar["file"]).read_bytes(), dtype=fl.DT[ar["dtype"]]).reshape(ar["shape"])
                     for n, ar in man["arrays"].items()}
            c = dict(man["constants"])
            c["e_s"] = int(man["tables"]["exp"]["e_s"]); c["silu"] = tuple(man["tables"]["act"]["silu_member"])
            c["wrho"] = tc.norm_window(GEO.d, int(c["norm_tn"]))
            Lw = {"w": words, "c": c}
            P = layerint(Lw)
            rope = (words["rope_cos"].reshape(T, -1).astype(np.int64), words["rope_sin"].reshape(T, -1).astype(np.int64))
            rec = tc.Rec(1)
            y = tc.i_block(x, P, rope, rec)
            assert rec.summary()["sequences_refused"] == 0, f"{sname} refused at layer {l}: {rec.summary()['first_refusal_sites']}"
            yr = fl.rx_block(x.astype(np.float64), fl.LayerModel(Lw, T), frozenset(fl.SITES), None)
            assert np.array_equal(yr.astype(np.int64), y), f"{sname} layer {l}: rx_block != i_block"
            files[f"x_in_L{l:02d}"] = write_bin(sd, f"x_in_L{l:02d}", x[0], "<i2")
            files[f"x_out_L{l:02d}"] = write_bin(sd, f"x_out_L{l:02d}", y[0], "<i2")
            x = y
        sman = {k: rman[k] for k in ("schema", "kind", "id", "heldout_index", "source", "token_ids", "T", "basis") if k in rman}
        sman.update({"accepted_at_every_layer": True, "arrays": files,
                     "selection": rman.get("selection", "") + " (token ids of the reference export's sequence; chained at this export's words)",
                     "residual_scales_in_out": [[s_in[l], s_out[l]] for l in range(L)]})
        (sd / "manifest.json").write_text(json.dumps(sman, indent=1, sort_keys=True))
        seqs.append(sname)
        fl.log(f"{sname}: {L} layers chained through tlcalib.i_block, accepted, rx_block equal ({time.time() - t0:.0f}s)")
    # ---------------- token_io.json for this export (8B layout)
    if (ref / "token_io").is_dir():
        R = fl.b3.Rotation(GEO.d, int(rmeta["rotation"]["seed"]))
        checks = []
        for sname in seqs:
            sm = json.loads((out / sname / "manifest.json").read_text())
            toks = np.array(sm["token_ids"], dtype=np.int64)
            x_in = np.frombuffer((out / sname / "x_in_L00.bin").read_bytes(), dtype="<i2").reshape(T, GEO.d)
            rule = np.floor(R.fwd(fl.emb_rows(toks)).astype(np.float32).astype(np.float64) / s_in[0] + 0.5)
            assert np.array_equal(np.asarray(tab[toks]), x_in) and np.array_equal(rule.astype(np.int64), x_in.astype(np.int64)), sname
            checks.append(sname)
        rtio = json.loads((ref / "token_io" / "token_io.json").read_text())
        tio = dict(rtio)
        tio.update({"mode": "reuse (fidelity lane fp_export.py)", "export": a.name, "T": T,
                    "checked_against": {"exported_sequences": checks,
                                        "checks": ["table[token_ids] == x_in_L00 == the TOKEN_IO_SPEC rule recomputed from the checkpoint rows",
                                                   "x_out of every layer chained through tlcalib.i_block at this export's words (accepted at every layer)"]},
                    "reused_from": {"token_io": str(ref / "token_io"), "token_io_json_sha256": sha(ref / "token_io" / "token_io.json")},
                    "notes": ["embedding_int16.bin, head_int8_perrow.bin, head_mult12.bin, head_manifest.json and calib_final_xhat_rot_absmax.bin "
                              "are the reference export's files (hard links, unchanged: same residual scales, same final norm)",
                              "f2_fidelity.json (if present) was measured on the REFERENCE export's stack output, not on this export's"]})
        tio.pop("heldout_chain_sequences", None)
        if rebuild:
            tio["s_x_in_layer0"], tio["s_x_out_layer31"] = s_in[0], s_out[-1]
            tio["embedding_table"] = {**rtio["embedding_table"], "sha256": sha(out / "token_io" / "embedding_int16.bin")}
            tio["mode"] = "rebuilt at this export's residual scale (fidelity lane fp_export.py --rebuild-token-io)"
            tio["notes"] = ["embedding_int16.bin rebuilt by the TOKEN_IO_SPEC rule at s_in; head_manifest.json final_norm Ceps / Cn re-derived "
                            "by the b8_token_io rule at s_out; head_int8_perrow.bin, head_mult12.bin, calib_final_xhat_rot_absmax.bin are the "
                            "reference's files (scale-free, hard links); f2_fidelity.json not carried (it measured the reference stack)"]
        (out / "token_io" / "token_io.json").write_text(json.dumps(tio, indent=1, sort_keys=True))
        lines = [f"{sha(f)}  {f.name}" for f in sorted((out / "token_io").iterdir()) if f.name != "SHA256SUMS"]
        (out / "token_io" / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    # ---------------- profile.json
    tool = {"path": "results/zk60_fidelity_parity_20261019 (+ results/zk60_1b_calibration_20260929, results/zk60_8b_calibration_20261017 read-only)",
            "sha256": {**{p: sha(fl.HERE / p) for p in ("fp_variant.py", "fp_lib.py", "fp_export.py", "fp_gptq.py", "fp_selfcheck.py")},
                       **{p: sha(fl.CAL / p) for p in ("tlcalib.py", "b3calib.py", "b3_ladder.py", "corpus.py", "corpus4.py")}}}
    fid = None
    if a.fidelity_run:
        fs = json.loads((fl.HERE / "runs" / fl.MODEL / a.fidelity_run / "summary.json").read_text())
        fid = {"fidelity_lane_run": a.fidelity_run, "metrics": fs["metrics"], "refused": fs["refused"],
               "note": "fp_eval paired float-vs-integer metrics (D25 T4 integer head); export words identical to the evaluated run"}
    prof = {"schema": "zk60-trained-profile-export/1", "kind": "profile", "variant": a.name,
            "variant_options": vprof.get("variant_options"), "model": rprof["model"], "calibration_tool": tool, "T": T,
            "profile_constants": pc, "per_layer_constants_differ": differ, "layers": layers, "sequences": seqs,
            "metadata_out_of_proof": {
                "residual_scale_s_x": s_in[0] if len(set(s_in)) == 1 else None, "residual_scales_in": s_in, "residual_scales_out": s_out,
                "rotation": rmeta["rotation"],
                "per_layer": [{"layer": l, "scales": json.loads((out / f"layer_{l:02d}" / "manifest.json").read_text())["metadata_out_of_proof"]["scales"]}
                              for l in range(L)],
                "calibration": {**rmeta.get("calibration", {}), "fidelity_lane_variant": str(var), "variant_profile": {
                    k: vprof.get(k) for k in ("shift_windows", "profile_from", "sh_s_overrides", "vocab0", "only_layers")}},
                "word_rounding": {"run": a.words_from, "layers_changed": {str(k): v for k, v in replaced.items() if v}} if a.words_from else None,
                "geometry": rmeta.get("geometry"), "tokenizer": rmeta.get("tokenizer"), "rope_tables": rmeta.get("rope_tables")},
            "fidelity_T": fid, "reference_export": {"dir": str(ref), "profile_sha256": sha(ref / "profile.json")},
            "native_format": "R8 per-layer constants (keys null in profile_constants == per_layer_constants_differ)",
            "class_change": ({"keys": cc, "status": "OUTSIDE today's declared classes (evaluation export only; needs the native "
                              "two-byte-remainder change and review before any proof)"} if cc else None),
            "scope": "calibration data, not a proof, not a privacy claim"}
    (out / "profile.json").write_text(json.dumps(prof, indent=1, sort_keys=True))
    # ---------------- re-read through the reader (sha256 of every array)
    exr = fl.Export(out, verify=True)
    for l in range(L):
        exr.layer(l)
    fl.log(f"export written: {out} profile sha256 {sha(out / 'profile.json')}; per-layer keys {differ}; "
           f"words replaced in {sum(1 for v in replaced.values() if v)} layers ({time.time() - t0:.0f}s)")


if __name__ == "__main__":
    main()
