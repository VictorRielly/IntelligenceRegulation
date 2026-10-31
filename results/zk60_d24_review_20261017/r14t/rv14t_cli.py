"""D24 review R14-tier: reviewer-run CLI end-to-end gate of the tiered path.

Runs Sol's final portable CLI binary (pinned by sha256) on the actual T128
export: one tiered 2-layer prove, one untiered 1-layer prove, then fresh
public-only verifiers on COPIES of each artifact, each case in its own
process. Everything written lives under the work directory given.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path("/Users/victorrielly/IntelligenceRegulation")
TIER = REPO / "results/zk60_sol_20261031/r14-security-tier"
BIN = TIER / "zk60_split_stack.portable.bin"
BIN_SHA = "82d87bf610b09d1089b16fc5b8f5bfae1b64b91f31900015b01f571f89c0d17a"
EXPORT = REPO / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
REF = REPO / "results/zk60_1b_native_20261017/r14/astra-smoke-prefix-1"
ENV = dict(os.environ, RAYON_NUM_THREADS="4", VECLIB_MAXIMUM_THREADS="1", OPENBLAS_NUM_THREADS="1")


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def run(work, label, args):
    t = time.time()
    r = subprocess.run([str(BIN), *args], env=ENV, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (work / (label + ".log")).write_text(r.stdout)
    events = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    rec = {"label": label, "returncode": r.returncode, "seconds": round(time.time() - t, 2),
           "last": events[-1] if events else r.stdout[-400:]}
    print(json.dumps(rec), flush=True)
    return rec, events


def prove(work, name, layers, tier):
    out = work / name / "run"
    out.parent.mkdir(parents=True)
    args = ["stack-prove", "--experimental-r14", "--export", str(EXPORT), "--layers", layers,
            "--seq-dir", str(REF), "--out", str(out), "--witness-cache-gib", "0"]
    if tier:
        args += ["--security-tier", tier]
    rec, events = run(work, name + "-prove", args)
    assert rec["returncode"] == 0, rec
    proven = [e for e in events if e.get("event") == "proven"]
    assert len(proven) == 1
    return out, proven[0]["statement_identity"], proven[0]["binding"]


def clone(work, src, case):
    dst = work / "cases" / case / "run"
    dst.parent.mkdir(parents=True)
    # Segment files are only read by the verifier: hard-link them (no copy).
    # The statement directory is mutated per case: real copies.
    shutil.copytree(src, dst, copy_function=os.link)
    shutil.copytree(src.with_name("run.unverified-statement"), dst.with_name("run.unverified-statement"))
    return dst


def verify(work, label, artifact, layers, model, binding, minimum):
    args = ["stack-verify", "--experimental-r14", "--export", str(EXPORT), "--layers", layers,
            "--artifact", str(artifact), "--expect-statement", model, "--expect-binding", binding]
    if minimum:
        args += ["--min-security-tier", minimum]
    return run(work, label, args)


def main(work):
    work = Path(work)
    work.mkdir(parents=True, exist_ok=False)
    assert sha(BIN) == BIN_SHA
    results = {"binary_sha256": BIN_SHA, "cases": []}

    def case(label, rec, expect_ok, needle=None):
        msg = json.dumps(rec["last"])
        ok = (rec["returncode"] == 0) if expect_ok else (rec["returncode"] == 1 and needle in msg)
        results["cases"].append({**rec, "expected": "accept" if expect_ok else needle, "as_expected": ok})
        return ok

    # ---- tiered 2-layer run (one internal boundary) -------------------------
    L2 = "24..26"
    base, model, binding = prove(work, "tier", L2, "95")
    ub = base.with_name("run.unverified-statement")
    exp = (ub / "expected.bin").read_bytes()
    stj = json.loads((ub / "statement.json").read_text())
    results["tier_expected_bin_len"] = len(exp)
    results["tier_expected_magic"] = exp[:8].decode()
    results["tier_statement_schema"] = stj["schema"]
    results["tier_statement_security"] = stj.get("security")

    def mutate_expected(case_name, fn):
        a = clone(work, base, case_name)
        p = a.with_name("run.unverified-statement") / "expected.bin"
        p.write_bytes(fn(bytearray(p.read_bytes())))
        return a

    a = clone(work, base, "no-minimum")
    case("tier-no-minimum", verify(work, "tier-no-minimum", a, L2, model, binding, None)[0], False,
         "--min-security-tier is required")
    for m in ("100", "128"):
        a = clone(work, base, "min-" + m)
        case("tier-min-" + m, verify(work, "tier-min-" + m, a, L2, model, binding, m)[0], False,
             "below the verifier minimum")
    a = clone(work, base, "min-garbage")
    case("tier-min-garbage", verify(work, "tier-min-garbage", a, L2, model, binding, "95.0")[0], False,
         "expected tier 95, 100 or 128")

    def flip(at):
        def f(b):
            b[at] ^= 1
            return bytes(b)
        return f
    for name, at in (("units-lsb", 200 + 80 + 64), ("lookup-lsb", 200 + 80), ("blocks", 208), ("q", 200 + 48)):
        a = mutate_expected("flip-" + name, flip(at))
        case("tier-flip-" + name, verify(work, "tier-flip-" + name, a, L2, model, binding, "95")[0], False,
             "policy binding differs")

    def tier100(b):
        b[200:208] = (100).to_bytes(8, "little")
        return bytes(b)
    a = mutate_expected("tier-code-100", tier100)
    case("tier-code-100", verify(work, "tier-code-100", a, L2, model, binding, "95")[0], False,
         "only the MVP 95 tier")

    def strip(b):
        return b"HLR14IO1" + bytes(b[8:200])
    for m in ("95", None):
        a = mutate_expected("strip-v1-" + str(m), strip)
        case("tier-strip-to-v1-min-" + str(m), verify(work, "tier-strip-v1-" + str(m), a, L2, model, binding, m)[0],
             False, "policy plan/model/context differs")

    def statement_edit(case_name, old, new):
        a = clone(work, base, case_name)
        p = a.with_name("run.unverified-statement") / "statement.json"
        t = p.read_text()
        assert old in t, (case_name, old)
        p.write_text(t.replace(old, new, 1))
        return a
    sec = json.dumps(stj["security"], separators=(",", ":"))
    a = statement_edit("statement-v1-schema", '"schema":"zk60-trained-split-stack-run/2","security":' + sec,
                       '"schema":"zk60-trained-split-stack-run/1"')
    case("tier-statement-as-v1", verify(work, "tier-statement-as-v1", a, L2, model, binding, "95")[0], False,
         "canonical rendering")
    wb = stj["security"]["whole_bits_floor"]
    a = statement_edit("statement-bits", '"whole_bits_floor":%d' % wb, '"whole_bits_floor":%d' % (wb + 2))
    case("tier-statement-bits", verify(work, "tier-statement-bits", a, L2, model, binding, "95")[0], False,
         "canonical rendering")

    a = clone(work, base, "honest")
    rec, events = verify(work, "tier-honest-min-95", a, L2, model, binding, "95")
    case("tier-honest-min-95", rec, True)
    ok = [e for e in events if e.get("event") == "verified"]
    results["tier_honest_promoted"] = bool(ok and ok[0].get("statement_promoted"))
    pub = json.loads((a / "statement/statement.json").read_text())
    results["tier_published_schema"] = pub["schema"]
    results["tier_published_security"] = pub.get("security")
    results["tier_published_expected_equal"] = (a / "statement/expected.bin").read_bytes() == exp
    rec, _ = verify(work, "tier-reverify-published", a, L2, model, binding, "95")
    case("tier-reverify-published", rec, True)

    # ---- untiered (v1) 1-layer run under the same final binary --------------
    L1 = "25..26"
    vbase, vmodel, vbinding = prove(work, "v1", L1, None)
    vexp = (vbase.with_name("run.unverified-statement") / "expected.bin").read_bytes()
    vst = json.loads((vbase.with_name("run.unverified-statement") / "statement.json").read_text())
    results["v1_expected_bin_len"] = len(vexp)
    results["v1_expected_magic"] = vexp[:8].decode()
    results["v1_statement_schema"] = vst["schema"]
    results["v1_statement_has_security"] = "security" in vst
    base = vbase
    a = clone(work, vbase, "v1-min-95")
    case("v1-min-95", verify(work, "v1-min-95", a, L1, vmodel, vbinding, "95")[0], False,
         "unrated legacy statement has no tier")
    a = clone(work, vbase, "v1-honest")
    case("v1-honest-no-minimum", verify(work, "v1-honest-no-minimum", a, L1, vmodel, vbinding, None)[0], True)

    results["all_as_expected"] = all(c["as_expected"] for c in results["cases"])
    (work / "RESULT.json").write_text(json.dumps(results, indent=1) + "\n")
    print(json.dumps({"all_as_expected": results["all_as_expected"], "cases": len(results["cases"])}), flush=True)
    sys.exit(0 if results["all_as_expected"] else 3)


if __name__ == "__main__":
    main(sys.argv[1])
