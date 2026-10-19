#!/usr/bin/env python3
"""Layer-0 prompt pre-check for the token-I/O demo (coordinator add-on, 2026-10-19).

Some prompt tokens leave the int8 range already at layer 0 (their embedding row alone
drives a Q/K/V value past 127), so a proof of a prompt containing one is refused at the
first block. Layer-0 values depend on the token only, so the fidelity lane checked the
whole vocabulary exhaustively (`fp_vocab0.py`). This tool turns that scan into a cheap
check that runs BEFORE anything is built or proved:

  record --scan SCAN.json [--scan ...] [--also-export DIR ...] --out LIST.json
      fingerprints each scanned export's layer-0 inputs (the embedding table, layer_00
      gamma_a / wq / wk / wv and the layer_00 manifest without its RoPE entries) and
      writes the refusal list keyed by that fingerprint. An --also-export must have the
      same fingerprint as a scanned export, or nothing is written.
  check --export DIR [--emb DIR] (--seq ID | --prompt ID,ID,...) [--list LIST.json]
      exit 2 and name every listed token in the prompt (id, text, positions, site, the
      fix); exit 0 "clear" when none is in it; exit 0 "not-covered" when the export's
      fingerprint has no recorded scan (nothing is claimed then; the prover still
      refuses at block 0 if a value leaves its range); exit 1 on a usage/read error.

The RoPE entries are left out of the fingerprint because they depend on the sequence
length T only: a shorter export's RoPE tables are a byte prefix of the scanned T's
(checked by `record` for every --also-export), so its positions are a subset of the
scanned ones, and V carries no RoPE. This is a demo convenience, not a soundness
mechanism: the proof system refuses such prompts on its own.
"""
import argparse
import hashlib
import json
import os
import sys

DEFAULT_LIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "layer0_refusals.json")
FIX = ("a layer-0 recalibrated export is coming from the calibration/fidelity lanes "
       "(results/zk60_fidelity_parity_20261019/PROGRESS.md, 13:26 UTC 2026-10-19 vocabulary scan); "
       "until it lands, choose a prompt without this token")
ROPE_ARRAYS = ("rope_cos", "rope_sin")
LAYER0_FILES = ("gamma_a.bin", "wq.bin", "wk.bin", "wv.bin")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 22)
            if not b:
                return h.hexdigest()
            h.update(b)


def layer0_manifest_without_rope(export):
    with open(os.path.join(export, "layer_00", "manifest.json")) as f:
        m = json.load(f)
    for a in ROPE_ARRAYS:
        m.get("arrays", {}).pop(a, None)
    m.get("tables", {}).pop("rope", None)
    return m


def fingerprint(export, emb):
    parts = {"embedding_int16.bin": sha256_file(os.path.join(emb, "embedding_int16.bin"))}
    for n in LAYER0_FILES:
        parts["layer_00/" + n] = sha256_file(os.path.join(export, "layer_00", n))
    canon = json.dumps(layer0_manifest_without_rope(export), sort_keys=True, separators=(",", ":"))
    parts["layer_00/manifest.json without RoPE"] = hashlib.sha256(canon.encode()).hexdigest()
    whole = hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
    return whole, parts


def display(text):
    # byte-level BPE: U+0120 is a leading space, U+010A a newline
    return text.replace("Ġ", " ").replace("Ċ", "\n")


def rope_is_prefix(short, long):
    for a in ROPE_ARRAYS:
        with open(os.path.join(short, "layer_00", a + ".bin"), "rb") as f:
            s = f.read()
        with open(os.path.join(long, "layer_00", a + ".bin"), "rb") as f:
            l = f.read(len(s))
        if s != l:
            return False
    return True


def cmd_record(args):
    entries = []
    for scan in args.scan:
        with open(scan) as f:
            s = json.load(f)
        ex = s["export"]
        fp, parts = fingerprint(ex, os.path.join(ex, "token_io"))
        entries.append({
            "fingerprint": fp,
            "fingerprint_parts": parts,
            "scan": os.path.abspath(scan),
            "scan_sha256": sha256_file(scan),
            "scan_export": ex,
            "scan_profile_sha256": s.get("profile_sha256"),
            "scan_scope": s.get("scope"),
            "vocab": s.get("vocab"),
            "class_int8": s.get("class_int8"),
            "worst_abs": s.get("worst_abs"),
            "refusing": [{"token": r["token"], "text": r["text"], "display": display(r["text"]),
                          "sites": r["sites"]} for r in s.get("rows", [])],
            "exports_matched_at_record": [ex],
        })
    for ex in args.also_export or []:
        fp, _ = fingerprint(ex, os.path.join(ex, "token_io"))
        hit = [e for e in entries if e["fingerprint"] == fp]
        if not hit:
            print(f"refused: {ex}: its layer-0 fingerprint {fp} matches no scanned export", file=sys.stderr)
            return 1
        if not rope_is_prefix(ex, hit[0]["scan_export"]):
            print(f"refused: {ex}: its RoPE tables are not a prefix of the scanned export's", file=sys.stderr)
            return 1
        hit[0]["exports_matched_at_record"].append(ex)
    out = {
        "what": "known layer-0 refusing tokens per export layer-0 fingerprint (demo pre-check; "
                "the proof system refuses such prompts on its own)",
        "fingerprint_rule": "sha256 over the SHA-256s of the embedding table, layer_00 "
                            + " / ".join(LAYER0_FILES)
                            + " and the canonical layer_00 manifest without rope_cos / rope_sin / tables.rope",
        "fix": FIX,
        "entries": entries,
    }
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    for e in entries:
        print(json.dumps({"event": "recorded", "fingerprint": e["fingerprint"],
                          "refusing": [r["token"] for r in e["refusing"]],
                          "exports": e["exports_matched_at_record"]}))
    return 0


def prompt_of(args):
    if args.prompt is not None:
        return [int(x) for x in args.prompt.split(",") if x.strip()]
    with open(os.path.join(args.export, "seq_" + args.seq, "manifest.json")) as f:
        return [int(x) for x in json.load(f)["token_ids"]]


def cmd_check(args):
    try:
        prompt = prompt_of(args)
        with open(args.list) as f:
            lst = json.load(f)
        fp, _ = fingerprint(args.export, args.emb or os.path.join(args.export, "token_io"))
    except (OSError, ValueError, KeyError) as e:
        print(f"layer0-precheck: {e}", file=sys.stderr)
        return 1
    hit = [e for e in lst["entries"] if e["fingerprint"] == fp]
    if not hit:
        print(json.dumps({"event": "layer0-precheck", "status": "not-covered", "fingerprint": fp,
                          "note": "no vocabulary scan is recorded for this export's layer 0; nothing claimed"}))
        return 0
    e = hit[0]
    refusing = {r["token"]: r for r in e["refusing"]}
    found = []
    for tok in sorted(set(prompt) & set(refusing)):
        r = refusing[tok]
        pos = [i for i, t in enumerate(prompt) if t == tok]
        found.append(tok)
        print(json.dumps({"event": "layer0-refusal", "token": tok, "text": r["display"], "positions": pos,
                          "sites": r["sites"], "class_int8": e["class_int8"], "scan": e["scan"], "fix": lst["fix"]}))
        print(f"refused before proving: prompt token {tok} {json.dumps(r['display'])} (position(s) "
              f"{', '.join(map(str, pos))}) leaves the int8 range at layer 0, site {'/'.join(r['sites'])}, "
              f"on this export (exhaustive vocabulary scan {os.path.basename(e['scan'])}); fix: {lst['fix']}",
              file=sys.stderr)
    if found:
        return 2
    print(json.dumps({"event": "layer0-precheck", "status": "clear", "prompt_tokens": len(prompt),
                      "known_refusing": sorted(refusing), "fingerprint": fp, "scan": e["scan"]}))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    r.add_argument("--scan", action="append", required=True)
    r.add_argument("--also-export", action="append")
    r.add_argument("--out", required=True)
    c = sub.add_parser("check")
    c.add_argument("--export", required=True)
    c.add_argument("--emb")
    g = c.add_mutually_exclusive_group(required=True)
    g.add_argument("--seq")
    g.add_argument("--prompt")
    c.add_argument("--list", default=DEFAULT_LIST)
    args = ap.parse_args()
    return cmd_record(args) if args.cmd == "record" else cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
