#!/usr/bin/env python3
"""D63 lane L40 (2026-11-10): CHECK the per-layer calibrations of RunShapeShield.lean, and the non-weight half of every
block's `BlockPublic.Valid`, against the media app's own verifier export.

The export: results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier (apps/proven-media's
`VERIFIER_EXPORT`; its profile.json must hash to the app's `PROFILE_SHA`). Every layer manifest must hash to the value
profile.json pins, and every non-weight array file to the value its manifest pins. The weights (wq, wk, wv, wo, wg_t,
wu_t, wd_t) are pinned by hash in the manifests but their bytes are not in the repository (D62): their int8 class stays
a premise.

What is checked, layer by layer:
  1. the calibration `(sh_ao, sh_s, sh_h, sh_z, gate, cn_a, cn_m, nG)` equals RunShapeShield.lean's `shieldExport`
     entry (the Lean file is parsed), where the gate shift is `group_folds_for`'s (accuracy_groups.rs:48-50):
     `max(17, max over the used groups of sh_g + 10 + e_in - base_e_in)`, and nG is the number of ACT groups;
  2. its `(sh_ao, sh_s, sh_h, sh_z, gate)` equals L17's `shieldLayers` entry (ShapeR13.lean, parsed);
  3. the profile constants the Lean shape fixes: f_e 9, f_p 12, norm_ceps 2439, norm_tn 9 (so tn - 8 = 1), sh_qkv 8,
     sh_o 9, sh_g 8, sh_u 0, T 128;
  4. the public data's classes, `BlockPublic.Valid`'s non-weight fields (CircuitBlock.lean:191-213):
     gamma_a, gamma_m |g| <= 127; m_q, m_k, m_v, m_o, m_u, m_d in [0, 2^14]; the FOLDED gate multipliers
     (`m_g << (gate - its group's shift)`, accuracy_groups.rs:60) in [0, 2^14]; rope |cos|, |sin| <= 2^7; exp in
     [0, 2^f_e]; the SCALED act words (`raw * 2^(24 - sh_h + e_out - base_out)`, accuracy_aligned.rs:37-46) |a| <= 2^31;
     every channel's group id below nG; silu_groups equal to the manifest's group members.
A negative control repeats every check with one value changed (one per check kind) and requires each to fail.

usage: python3 -I l40_shield_export.py <repo root>
"""
import hashlib
import json
import re
import struct
import sys

root = sys.argv[1]
EXP = f"{root}/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier"
APP = f"{root}/apps/proven-media/proven_media/shieldstral_runtime.py"
LEAN = f"{root}/formal/ZK60Formal/RunShapeShield.lean"
L17 = f"{root}/formal/ZK60Formal/ShapeR13.lean"
DT = {"int8": ("b", 1), "int16": ("h", 2), "int64": ("q", 8)}


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def load(layer_dir, man, name):
    a = man["arrays"][name]
    code, size = DT[a["dtype"]]
    raw = open(f"{layer_dir}/{a['file']}", "rb").read()
    n = len(raw) // size
    return list(struct.unpack("<" + code * n, raw)), a


def lean_list(path, name):
    txt = open(path).read()
    m = re.search(r"def " + name + r"[^:]*:[^=]*:=\s*\[(.*?)\]\s*\n\s*\n", txt, re.S)
    if not m:
        raise SystemExit(f"cannot find {name} in {path}")
    body = m.group(1)
    tuples = re.findall(r"[⟨(]([^⟩)]*)[⟩)]", body)
    return [tuple(int(x) for x in t.split(",")) for t in tuples]


checks = 0
failed = 0
MODE = ""


def check(label, ok, detail=""):
    global checks, failed
    checks += 1
    if not ok:
        failed += 1
        print(f"{MODE}FAIL {label} {detail}")


def run(mutate=None):
    """All checks; `mutate(kind, value)` changes one value of the given kind (negative control)."""
    mut = mutate or (lambda kind, v: v)
    app = open(APP).read()
    want = re.search(r"PROFILE_SHA = '([0-9a-f]{64})'", app).group(1)
    check("profile.json is the app's (PROFILE_SHA)", mut("profile_sha", sha(f"{EXP}/profile.json")) == want)
    prof = json.load(open(f"{EXP}/profile.json"))
    check("T 128", mut("T", prof["T"]) == 128)
    lean = lean_list(LEAN, "shieldExport")
    l17 = lean_list(L17, "shieldLayers")
    check("26 layers", len(prof["layers"]) == 26 and len(lean) == 26 and len(l17) == 26)
    for L, ent in enumerate(prof["layers"]):
        d = f"{EXP}/{ent['dir']}"
        check(f"L{L} manifest pinned", sha(f"{d}/manifest.json") == ent["manifest_sha256"])
        man = json.load(open(f"{d}/manifest.json"))
        c = man["constants"]
        for k, v in [("f_e", 9), ("f_p", 12), ("norm_ceps", 2439), ("norm_tn", 9), ("sh_qkv", 8), ("sh_o", 9),
                     ("sh_g", 8), ("sh_u", 0)]:
            check(f"L{L} {k}", mut("const", c[k]) == v, f"{c[k]} != {v}")
        members = man["tables"]["act"]["group_members"]
        base_in, base_out = c["silu_member"]
        arr = {}
        for name in ["act", "exp", "gamma_a", "gamma_m", "m_d", "m_g", "m_k", "m_o", "m_q", "m_u", "m_v", "rope_cos",
                     "rope_sin", "silu_group_ids", "silu_groups"]:
            vals, a = load(d, man, name)
            check(f"L{L} {name} pinned", sha(f"{d}/{a['file']}") == a["sha256"])
            n = 1
            for s in a["shape"]:
                n *= s
            check(f"L{L} {name} size", len(vals) == n, f"{len(vals)} != {n}")
            arr[name] = vals
        nG = len(members)
        ids = arr["silu_group_ids"]
        check(f"L{L} group ids below nG", all(0 <= mut("gid", i) < nG for i in ids))
        check(f"L{L} every group used", set(ids) == set(range(nG)))
        sg = arr["silu_groups"]
        check(f"L{L} silu_groups = members", [[sg[2 * k], sg[2 * k + 1]] for k in range(nG)] == members)
        gshift = [c["sh_g"] + 10 + (members[g][0] - base_in) for g in range(nG)]
        gate = max(17, max(gshift))
        cal = (c["sh_ao"], c["sh_s"], c["sh_h"], c["sh_z"], gate, c["norm_cn_a"], c["norm_cn_m"], nG)
        check(f"L{L} calibration = shieldExport", tuple(mut("cal", x) for x in cal) == lean[L], f"{cal} vs {lean[L]}")
        check(f"L{L} = L17's shieldLayers", cal[:5] == l17[L], f"{cal[:5]} vs {l17[L]}")
        for g in ["gamma_a", "gamma_m"]:
            check(f"L{L} {g} |g| <= 127", all(abs(mut("gamma", v)) <= 127 for v in arr[g]))
        for m in ["m_q", "m_k", "m_v", "m_o", "m_u", "m_d"]:
            check(f"L{L} {m} in [0, 2^14]", all(0 <= mut("mult", v) <= 2 ** 14 for v in arr[m]))
        folded = [arr["m_g"][ch] << (gate - gshift[ids[ch]]) for ch in range(len(ids))]
        check(f"L{L} folded m_g in [0, 2^14]", all(0 <= mut("mg", v) <= 2 ** 14 for v in folded))
        for r in ["rope_cos", "rope_sin"]:
            check(f"L{L} {r} |.| <= 2^7", all(abs(mut("rope", v)) <= 2 ** 7 for v in arr[r]))
        check(f"L{L} exp in [0, 2^9]", all(0 <= mut("exp", v) <= 2 ** 9 for v in arr["exp"]))
        scaled_ok = True
        for g in range(nG):
            e = 24 - c["sh_h"] + (members[g][1] - base_out)
            for v in arr["act"][4096 * g:4096 * (g + 1)]:
                if abs(mut("act", v) * 2 ** e) > 2 ** 31:
                    scaled_ok = False
        check(f"L{L} scaled act |a| <= 2^31", scaled_ok)
    return lean


lean = run()
print(f"shieldExport (from the export): {len(lean)} layers")
print(f"L40 SHIELD EXPORT: {checks} checks, {failed} failed")
base_checks, base_failed = checks, failed

# Negative control: one single change per kind; each must make at least one check fail.
kinds = ["profile_sha", "T", "const", "gid", "cal", "gamma", "mult", "mg", "rope", "exp", "act"]
neg_bad = 0
for kind in kinds:
    hit = [False]

    def mutate(k, v, kind=kind, hit=hit):
        if k != kind or hit[0]:
            return v
        hit[0] = True
        if isinstance(v, str):
            return "0" * 64
        if kind == "act":
            return 2 ** 30
        if kind in ("gamma",):
            return -128
        if kind in ("mult", "mg"):
            return 2 ** 14 + 1
        if kind == "rope":
            return 129
        if kind == "exp":
            return 513
        if kind == "gid":
            return 99
        return v + 1

    checks, failed = 0, 0
    MODE = f"[negative control {kind}] "
    run(mutate)
    ok = failed >= 1
    print(f"negative control {kind}: {failed} failed of {checks} -> {'caught' if ok else 'NOT CAUGHT'}")
    if not ok:
        neg_bad += 1
print(f"L40 SHIELD EXPORT NEGATIVE CONTROL: {len(kinds)} single changes, {len(kinds) - neg_bad} caught")
sys.exit(0 if base_failed == 0 and neg_bad == 0 else 1)
