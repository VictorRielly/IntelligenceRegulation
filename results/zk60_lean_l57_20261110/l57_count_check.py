#!/usr/bin/env python3
"""D63 lane L57 (2026-11-10), finding L53-2: stage IN-C's LogUp squeeze count at the app's profile, CHECKED against the
code (read only; no receipt at the app's profile exists in the repository or under zk60-artifacts, and the Shieldstral
weights are not in the repository, D62, so no run of the classifier at that profile can be made here).

What the check reads (hashline, perf's sources in this worktree):
  * shape.rs: the media app's block profile R13_SHIELD_T128_H24 (`tokens:128, width:3072`), and the shape constructor's
    `(t_pad, d_pad) = (tokens.next_power_of_two(), width.next_power_of_two())`;
  * token_io/stage_in_c.rs `fn challenges`: the head draws `beta`, `gamma`, `alpha` (three `challenge_fp2()`), then
    `r_emb = challenge_fp2_vec(clog2(cp.d_pad))`;
  * token_io.rs: the stage tier R1_MVP's `stage_log_n` (the stage domain floor);
  * token_io/classify.rs: the registered Shieldstral policies' vocabulary `v: 131_072`;
  * formal/ZK60Formal/StageVerifyExecInC.lean: Lean's `incHeadDraws I = 3 + I.rBits`, `rBits = clog2 I.dPad`.
It computes the head's squeeze count m at the app's profile, the dev rung's for comparison (d = 384: lane L53's
MEASURED 12), and the count condition of `hD` for the stage's LogUp run (`n·e ≤ 3·eL`, `e ≤ eL`) at the escape count
of the polynomial-identity model (RunStgAlgCount.lean: e = 2·(2^tiLog + 2^vocLog), an ESTIMATE of the model's per-round
degree, PROVED there as arithmetic) and the run's LogUp bound eL = 2^26 (lane L36-1's bound, the run-level chain's).

Negative control: each single change to the sources (in memory) must be caught by at least one check.
usage: python3 l57_count_check.py <WT>
"""
import re
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
HL = WT + "/ops/zkp-mvp/gpu-metal/hashline/src/private_block/"
SRC = {
    "shape": HL + "shape.rs",
    "inc": HL + "token_io/stage_in_c.rs",
    "tio": HL + "token_io.rs",
    "cls": HL + "token_io/classify.rs",
    "lean": WT + "/formal/ZK60Formal/StageVerifyExecInC.lean",
}


def clog2(v):
    return (v - 1).bit_length() if v > 1 else 0


def npow2(v):
    return 1 << clog2(v)


def run(txt):
    checks = []

    def ck(name, ok, info=""):
        checks.append((name, bool(ok), info))

    # the app's block profile
    m = re.search(r"AccuracyProfile\{profile:R13_SHIELD_T128_H24,[^}]*tokens:(\d+),width:(\d+),", txt["shape"])
    ck("PROFILE R13_SHIELD_T128_H24 present", m is not None)
    tokens, width = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    ck("PROFILE tokens = 128", tokens == 128, tokens)
    ck("PROFILE width = 3072", width == 3072, width)
    ck("SHAPE d_pad = width.next_power_of_two()",
       "let (t_pad, d_pad) = (tokens.next_power_of_two(), width.next_power_of_two());" in txt["shape"])
    # the head's draws
    f = re.search(r"fn challenges\(tr: &mut Transcript, cp: &ClassifierProfile, tables: &ClassifierTables\)[^{]*\{(.*?)\n\}",
                  txt["inc"], re.S)
    ck("HEAD fn challenges present", f is not None)
    body = f.group(1) if f else ""
    lines = [ln.strip() for ln in body.splitlines() if "challenge" in ln]
    scal = [ln for ln in lines if re.search(r"tr\.challenge_fp2\(\)", ln)]
    vec = [ln for ln in lines if "challenge_fp2_vec" in ln]
    ck("HEAD three scalar challenges (beta, gamma, alpha)", len(scal) == 3,
       [s.split("=")[0].strip() for s in scal])
    ck("HEAD order beta, gamma, alpha",
       [s.split("=")[0].replace("let", "").strip() for s in scal] == ["beta", "gamma", "alpha"])
    ck("HEAD one vector challenge r_emb of clog2(cp.d_pad)",
       len(vec) == 1 and "let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));" in vec[0], vec)
    ck("HEAD the vector after the scalars", bool(lines) and "challenge_fp2_vec" in lines[-1])
    # the stage tier and the vocabulary
    t = re.search(r"const R1_MVP: Tier = Tier \{[^}]*stage_log_n: (\d+),", txt["tio"])
    ck("TIER R1_MVP stage_log_n present", t is not None)
    lt = int(t.group(1)) if t else 0
    ck("TIER stage_log_n = 12", lt == 12, lt)
    vs = [int(x.replace("_", "")) for x in re.findall(r"\n\s*v: ([0-9_]+),", txt["cls"])]
    ck("POLICY every registered policy has V = 131072", len(vs) >= 1 and all(v == 131072 for v in vs), vs)
    V = vs[0] if vs else 0
    # Lean's model
    ck("LEAN incHeadDraws = 3 + rBits", "def incHeadDraws (I : IncPub) : ℕ := 3 + I.rBits" in txt["lean"])
    ck("LEAN rBits = clog2 dPad", "def rBits : ℕ := clog2 I.dPad" in txt["lean"])
    ck("LEAN tiLog = max (clog2 tPad) lt", "def tiLog : ℕ := max (clog2 I.tPad) I.lt" in txt["lean"])
    ck("LEAN vocLog = max (clog2 v) lt", "def vocLog : ℕ := max (clog2 I.v) I.lt" in txt["lean"])
    # the numbers at the app's profile
    d_pad, t_pad = npow2(width), npow2(tokens)
    mh = len(scal) + clog2(d_pad)
    ck("COUNT d_pad = 4096", d_pad == 4096, d_pad)
    ck("COUNT m = 3 + clog2(d_pad) = 15 at the app's profile", mh == 15, mh)
    ck("COUNT the dev rung (d = 384) gives L53's MEASURED 12", len(scal) + clog2(npow2(384)) == 12)
    ti_log, voc_log = max(clog2(t_pad), lt), max(clog2(V), lt)
    ck("COUNT tiLog = 12, vocLog = 17", (ti_log, voc_log) == (12, 17), (ti_log, voc_log))
    e_in = 2 * (2 ** ti_log + 2 ** voc_log)
    eL = 2 ** 26
    ck("COUNT eI = 2(2^tiLog + 2^vocLog) = 270336", e_in == 270336, e_in)
    ck("COUNT hD: m * eI <= 3 * eL", mh * e_in <= 3 * eL, (mh * e_in, 3 * eL))
    ck("COUNT hD: eI <= eL", e_in <= eL)
    return checks, dict(m=mh, d_pad=d_pad, t_pad=t_pad, lt=lt, V=V, ti_log=ti_log, voc_log=voc_log, e_in=e_in, eL=eL)


def report(checks):
    bad = [c for c in checks if not c[1]]
    return len(checks), len(bad), bad


txt = {k: open(p).read() for k, p in SRC.items()}
checks, nums = run(txt)
for name, ok, info in checks:
    print(("ok   " if ok else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
n, nb, _ = report(checks)
print("numbers:", nums)
print(f"L57 count check: {n} checks, {nb} failed")

MUT = [
    ("shape", "tokens:128,width:3072,hidden:9216,q_heads:32,head_dim:128,kv_heads:8,log_cols:14},\nAccuracyProfile{profile:R13_SHIELD_T128_H24_DD",
     "tokens:128,width:4097,hidden:9216,q_heads:32,head_dim:128,kv_heads:8,log_cols:14},\nAccuracyProfile{profile:R13_SHIELD_T128_H24_DD"),
    ("shape", "width.next_power_of_two());", "width);"),
    ("inc", "    let gamma = tr.challenge_fp2();\n", ""),
    ("inc", "let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));", "let r_emb = tr.challenge_fp2_vec(clog2(cp.t_pad));"),
    ("inc", "    let alpha = tr.challenge_fp2();\n    let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));\n",
     "    let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));\n    let alpha = tr.challenge_fp2();\n"),
    ("tio", "stage_log_n: 12, stage_inv_rate: 4", "stage_log_n: 13, stage_inv_rate: 4"),
    ("cls", "v: 131_072,", "v: 262_144,"),
    ("lean", "def incHeadDraws (I : IncPub) : ℕ := 3 + I.rBits", "def incHeadDraws (I : IncPub) : ℕ := 2 + I.rBits"),
    ("lean", "def rBits : ℕ := clog2 I.dPad", "def rBits : ℕ := clog2 I.tPad"),
]
caught = 0
for i, (k, old, new) in enumerate(MUT):
    assert txt[k].count(old) >= 1, (i, k, old[:60])
    t2 = dict(txt)
    t2[k] = txt[k].replace(old, new, 1)
    c2, _ = run(t2)
    _, nb2, bad = report(c2)
    ok = nb2 > 0
    caught += ok
    print(f"negative {i + 1} ({k}): {'caught' if ok else 'NOT CAUGHT'} by {[b[0] for b in bad][:3]}")
print(f"L57 count check negative control: {len(MUT)} single changes, {caught} caught")
sys.exit(0 if nb == 0 and caught == len(MUT) else 1)
