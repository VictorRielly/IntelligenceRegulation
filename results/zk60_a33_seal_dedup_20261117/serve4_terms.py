#!/usr/bin/env python3
"""A33 serve4 follow-up: per-term medians (unpatched A against patched B) from the serve4 logs, with the definitions of
results/zk60_claude_review_20261116/batch7_review/recompute_logs.py (adapted: its REQ and STREAM regexes; warm passes only).

usage: serve4_terms.py <prefix> [<prefix> ...]     prefixes of raw/<prefix>serve4_<i><A|B>.log, e.g. m_ f_
Terms (per request unless noted; q = request index in the pass, L = 2 lanes):
  cadence       (result[3]-result[0])/3 per pass                  (the steady cadence)
  prove call    pc, q>=1            forks, commit, preflight, join: the phases inside it, q>=1
  receipt write w, q>=1
  prover wait   'waited' = prover start - sealing done, q>=1
  admission     sealing turn(q) - sealing done(q-1), q>=2 (the lane admission wait; 0 when the lane was free)
  sealing ov    sealing pass of requests 1..3 (beside a proof)    sealing solo: request 0
  result gap    result[q]-result[q-1], q>=1
  CPU           user+sys seconds per pass (STREAM line)
No GPU trace was on (HL_A27_GPU_TRACE unset), so the witness products' commit-to-start wait and the prover's GPU-busy time are not available.
"""
import re
import statistics as st
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(?P<arm>[^\]]+)\] pass (?P<p>\d+) request (?P<q>\d+): "
    r"arrived (?P<arr>[0-9.]+), sealing turn (?P<turn>[0-9.]+), sealing side done (?P<sdone>[0-9.]+) \(sealing pass (?P<seal>[0-9.]+) s\), "
    r"prover (?P<ps>[0-9.]+)-(?P<pe>[0-9.]+) \(waited (?P<wait>[0-9.]+) s; prove call (?P<pc>[0-9.]+) s: "
    r"preflight (?P<pre>[0-9.]+), commit (?P<com>[0-9.]+), forks (?P<forks>[0-9.]+), join (?P<join>[0-9.]+)\), "
    r"receipt write (?P<w>[0-9.]+) s \([^)]*\), result (?P<res>[0-9.]+);")
STR = re.compile(r"\[serve4\] pass (?P<p>\d+): .*?user (?P<u>[0-9.]+) s \+ sys (?P<sy>[0-9.]+) s")


def med(v):
    return st.median(v)


def load(path):
    t = path.read_text()
    reqs = {}
    for m in REQ.finditer(t):
        g = m.groupdict()
        reqs[(int(g["p"]), int(g["q"]))] = {k: float(v) for k, v in g.items() if k not in ("arm", "p", "q")}
    cpu = {int(m.group("p")): float(m.group("u")) + float(m.group("sy")) for m in STR.finditer(t)}
    return reqs, cpu


def terms(reqs, cpu):
    ps = sorted({p for p, _ in reqs})
    T = {k: [] for k in ["cadence", "prove call", "forks", "commit", "preflight", "join", "receipt write", "prover wait", "admission", "sealing ov", "sealing solo", "result gap", "CPU s/pass", "seal-prove overlap", "seal turn after prover(q-1) start", "seal done before prover(q-1) end"]}
    for p in ps:
        T["cadence"].append((reqs[(p, 3)]["res"] - reqs[(p, 0)]["res"]) / 3)
        T["sealing solo"].append(reqs[(p, 0)]["seal"])
        T["CPU s/pass"].append(cpu[p])
        for q in range(1, 4):
            r = reqs[(p, q)]
            T["prove call"].append(r["pc"])
            T["forks"].append(r["forks"])
            T["commit"].append(r["com"])
            T["preflight"].append(r["pre"])
            T["join"].append(r["join"])
            T["receipt write"].append(r["w"])
            T["prover wait"].append(r["wait"])
            T["sealing ov"].append(r["seal"])
            T["result gap"].append(r["res"] - reqs[(p, q - 1)]["res"])
            prev = reqs[(p, q - 1)]
            T["seal-prove overlap"].append(max(0.0, min(r["sdone"], prev["pe"]) - max(r["turn"], prev["ps"])))
            T["seal turn after prover(q-1) start"].append(r["turn"] - prev["ps"])
            T["seal done before prover(q-1) end"].append(prev["pe"] - r["sdone"])
            if q >= 2:
                T["admission"].append(max(0.0, r["turn"] - reqs[(p, q - 1)]["sdone"]))
    return T


def main():
    prefixes = sys.argv[1:]
    files = []
    for pre in prefixes:
        files += sorted(RAW.glob(f"{pre}serve4_[0-9]*[AB].log"), key=lambda p: (prefixes.index(pre), int(re.match(rf"{pre}serve4_(\d+)", p.name).group(1))))
    pooled = {"A": None, "B": None}
    runs = []
    for f in files:
        who = f.name[-5]
        reqs, cpu = load(f)
        T = terms(reqs, cpu)
        runs.append((f.stem, who, T))
        if pooled[who] is None:
            pooled[who] = {k: [] for k in T}
        for k, v in T.items():
            pooled[who][k] += v
    out = []
    out.append(f"### serve4 terms, pooled over {len(runs)} runs ({sum(1 for r in runs if r[1]=='A')} unpatched, {sum(1 for r in runs if r[1]=='B')} patched); medians\n")
    out.append("| term | n (A/B) | unpatched | patched | patched minus unpatched |")
    out.append("|---|---|---|---|---|")
    for k in pooled["A"]:
        a, b = pooled["A"][k], pooled["B"][k]
        out.append(f"| {k} (s) | {len(a)}/{len(b)} | {med(a):.3f} | {med(b):.3f} | {med(b)-med(a):+.3f} |")
    out.append("")
    out.append("### per run: cadence median, steady tok/s from cadence (128/cadence), prove call, sealing ov, admission, prover wait\n")
    out.append("| run | binary | cadence s [min-max] | prove call s | forks s | sealing ov s | admission s | prover wait s | CPU s/pass |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for name, who, T in runs:
        c = T["cadence"]
        out.append(f"| {name} | {'unpatched' if who=='A' else 'patched'} | {med(c):.3f} [{min(c):.3f}-{max(c):.3f}] | {med(T['prove call']):.3f} | {med(T['forks']):.3f} | {med(T['sealing ov']):.3f} | {med(T['admission']):.3f} | {med(T['prover wait']):.3f} | {med(T['CPU s/pass']):.1f} |")
    out.append("")
    meds = {n: med(T["cadence"]) for n, _, T in runs}
    names = [r[0] for r in runs]
    out.append("pairs (A-run then the B-run that follows it), per-run cadence medians:")
    signs = []
    for i in range(0, len(names) - 1, 2):
        d = meds[names[i + 1]] - meds[names[i]]
        signs.append(d > 0)
        out.append(f"- {names[i]} -> {names[i+1]}: {meds[names[i]]:.3f} -> {meds[names[i+1]]:.3f} ({d:+.3f})")
    out.append(f"patched slower in {sum(signs)} of {len(signs)} pairs")
    ca, cb = pooled["A"]["cadence"], pooled["B"]["cadence"]
    se = (st.variance(ca) / len(ca) + st.variance(cb) / len(cb)) ** 0.5
    out.append(f"pooled cadence per pass: unpatched median {med(ca):.3f} mean {st.mean(ca):.3f} (n={len(ca)}), patched median {med(cb):.3f} mean {st.mean(cb):.3f} (n={len(cb)}); mean difference {st.mean(cb)-st.mean(ca):+.3f} s, Welch se {se:.3f}, t = {(st.mean(cb)-st.mean(ca))/se:.2f}")
    text = "\n".join(out)
    print(text)
    (HERE / f"SERVE4_TERMS_{'_'.join(p.rstrip('_') or 'old' for p in prefixes)}.md").write_text(text + "\n")


if __name__ == "__main__":
    main()
