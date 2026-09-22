#!/usr/bin/env python3
"""Who moved what: merge-base 3811e55 vs main 4751b93 vs lane base fee1a8d.

For each pinned path, say whether MAIN changed it since the fork, whether the
LANE changed it, or both -- which is exactly what decides whether the
integrator's merge of the two can be predicted from any digest in hand.
Also check every pinned path's main digest against the pinned tool's own
accepted values.
"""
import hashlib
import subprocess
import sys

WT = "/home/victor/wt-zk60-block125m-review"
FORK, MAIN, BASE, TIP = "3811e55", "4751b93", "fee1a8d", "29cba9a"

sys.path.insert(0, "/home/victor/wt-zk60-jointview/scripts")
import zk60_native_mask_commit as mc  # noqa: E402
import zk60_native_terminal_polys as tp  # noqa: E402


def paths(pins):
    return [p[0] if isinstance(p, (tuple, list)) else p for p in pins]


def pinmap(pins):
    out = {}
    for p in pins:
        if isinstance(p, (tuple, list)):
            path = p[0]
            d = next((x for x in p[1:] if isinstance(x, str) and len(x) == 64), None)
            out[path] = d
    return out


def dig(commit, path):
    r = subprocess.run(["git", "--no-pager", "-C", WT, "show", f"{commit}:{path}"],
                       capture_output=True)
    if r.returncode != 0:
        return None
    return hashlib.sha256(r.stdout).hexdigest()


pins = {}
pins.update(pinmap(mc.SOURCE_PINS))
pins.update(pinmap(mc.PATH_PINS))
for k, v in pinmap(tp.SOURCE_PINS).items():
    pins.setdefault(k, v)

also = {}
for k, v in mc.ALSO_ACCEPTED.items():
    also[k] = v if isinstance(v, str) else (v.get("sha256") or v.get("digest") or str(v))

order = []
for p in paths(mc.SOURCE_PINS) + paths(mc.PATH_PINS) + paths(tp.SOURCE_PINS):
    if p not in order:
        order.append(p)
order += ["zkp-core/Cargo.toml", "hashline/Cargo.toml"]

print(f"{'path':52} {'fork':10} {'main':10} {'lanebase':10} {'tip':10}  who moved it")
print("-" * 120)
both = []
for p in order:
    f, m, b, t = dig(FORK, p), dig(MAIN, p), dig(BASE, p), dig(TIP, p)
    mm = (m != f)
    lm = (b != f)
    who = []
    if mm:
        who.append("MAIN")
    if lm:
        who.append("LANE(pre-36)")
    if t != b:
        who.append("DELTA-36")
    if not who:
        who = ["nobody"]
    if mm and lm:
        both.append(p)
    s = lambda x: (x or "--------")[:10]
    print(f"{p:52} {s(f)} {s(m)} {s(b)} {s(t)}  {' + '.join(who)}")

print()
print("BOTH main and the lane moved these since the fork (a merge makes a NEW blob):")
for p in both:
    print("   ", p)

print()
print("pin-of-record / ALSO_ACCEPTED check against main 4751b93:")
bad = 0
for p in order:
    if p not in pins:
        print(f"   {p:52} NOT IN THE TOOL'S PIN SET")
        continue
    m = dig(MAIN, p)
    rec = pins[p]
    alt = also.get(p)
    if m == rec:
        verdict = "at the pin of record"
    elif alt and isinstance(alt, str) and m in alt:
        verdict = "at the SECOND accepted digest"
    elif alt and not isinstance(alt, str):
        verdict = f"second-digest entry present ({type(alt).__name__}) -- check by hand"
    else:
        verdict = "NOT ACCEPTED"
        bad += 1
    print(f"   {p:52} {verdict}")
print("not accepted:", bad)
