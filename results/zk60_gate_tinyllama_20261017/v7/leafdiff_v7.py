#!/usr/bin/env python3
"""TOOLS v7 RE-RUN AGAINST THE v6 RECORD OF THE SAME BUNDLE (round 6): every
leaf the two records share must be EQUAL, except

  (m) M9-3's own subtree (`stage6_negative_controls/round_9_controls/
      controls[2]/...`), which v7 changed (finding G-4 / review Q-8);
  (a) the three `ok` aggregates on M9-3's path (`/ok`,
      `/stage6_negative_controls/ok`, `.../round_9_controls/ok`);
  (v) volatile leaves: seconds, memory, `timings`, `total_seconds`,
      `tool_sha256` (the tools moved by design), `stages_run` (the v7 pass
      runs a subset of the v6 pass's stages).

Anything else that differs is a CHANGE v7 was not meant to make, and fails.

    python3 leafdiff_v7.py <v6 record> <v7 record> <out.json>
"""
import json
import re
import sys

M93 = "/stage6_negative_controls/round_9_controls/controls[2]"
AGG = {"/ok", "/stage6_negative_controls/ok",
       "/stage6_negative_controls/round_9_controls/ok"}
VOL = re.compile(r"(seconds|peak_rss|rss_mb|^/timings|^/total_seconds|^/tool_sha256|"
                 r"^/stages_run)")


def leaves(x, p=""):
    if isinstance(x, dict):
        for k, v in x.items():
            yield from leaves(v, f"{p}/{k}")
    elif isinstance(x, list):
        for i, v in enumerate(x):
            yield from leaves(v, f"{p}[{i}]")
    else:
        yield p, x


def main(a_path, b_path, out_path):
    a, b = json.load(open(a_path)), json.load(open(b_path))
    A, B = dict(leaves(a)), dict(leaves(b))
    common = [k for k in B if k in A]
    diff = [k for k in common if A[k] != B[k]]
    cls = {"m9_3": [], "aggregates": [], "volatile": [], "other": []}
    for k in diff:
        if k.startswith(M93 + "/"):
            cls["m9_3"].append(k)
        elif k in AGG:
            cls["aggregates"].append(k)
        elif VOL.search(k):
            cls["volatile"].append(k)
        else:
            cls["other"].append(k)
    m93 = b
    for part in ("stage6_negative_controls", "round_9_controls", "controls"):
        m93 = m93.get(part, {}) if isinstance(m93, dict) else {}
    m93 = m93[2] if isinstance(m93, list) and len(m93) > 2 else {}
    out = {
        "what": __doc__.strip().splitlines()[0],
        "privacy_acceptance": False,
        "v6_record": a_path, "v7_record": b_path,
        "v6_ok": a.get("ok"), "v7_ok": b.get("ok"),
        "leaves_v6": len(A), "leaves_v7": len(B), "leaves_shared": len(common),
        "shared_leaves_that_differ": len(diff),
        "by_class": {k: len(v) for k, v in cls.items()},
        "other_differences": [{"leaf": k, "v6": A[k], "v7": B[k]} for k in cls["other"]],
        "aggregate_differences": [{"leaf": k, "v6": A[k], "v7": B[k]} for k in cls["aggregates"]],
        "v7_m9_3": {"ok": m93.get("ok"), "fires": m93.get("fires"),
                    "per_domain": [
                        {"domain": p["domain"], "slot": p["slot"], "ok": p["ok"],
                         "arms": {n: {k: v[k] for k in (
                             "refusal_mechanism", "port_and_capture_numbers",
                             "slots_that_stopped_being_checked",
                             "expected_slots_to_stop", "ok")}
                             for n, v in p.get("arms", {}).items()}}
                        for p in m93.get("per_domain", [])]},
    }
    out["ok"] = (not cls["other"]) and m93.get("ok") is True
    json.dump(out, open(out_path, "w"), indent=1, sort_keys=True)
    print(f"{b_path.rsplit('/', 1)[-1]}: shared {len(common)}, differ {len(diff)} "
          f"{out['by_class']}; ok {a.get('ok')} -> {b.get('ok')}; M9-3 ok {m93.get('ok')}; "
          f"verdict {'OK' if out['ok'] else 'FAIL'}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:4]))
