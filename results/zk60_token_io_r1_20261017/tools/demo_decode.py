#!/usr/bin/env python3
"""Decode token ids to text for the presenter demo (round 10). Owner-side only.

usage: demo_decode.py {llama3|tinyllama} --ids-file FILE      (comma / whitespace separated ids)
       demo_decode.py {llama3|tinyllama} --id-file FILE       (exactly one id: the owner's token file)
       demo_decode.py {llama3|tinyllama} --id N

Round 11 (review REVIEW6 TR7-3): the demo reads the opened answer from the owner's 0600
`next_token` file with --id-file, so the id never appears on a command line (PR4-17's rule);
--id stays for hand use with public ids.

Prints one JSON line {"text": ...}. The ids file is the prompt owner's 0600 prompt file;
a file readable by group or others is refused. Tokenizers: Llama-3's tokenizer.json (the
`tokenizers` library) and TinyLlama's tokenizer.model (the calibration lane's spm_bpe.py,
imported read-only), the same files the fidelity lane encodes with.
"""
import argparse
import json
import os
import stat
import sys

LLAMA3 = "/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json"
TINY_DIR = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929"
TINY = "/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/tokenizer.model"


def ids_of(path):
    st = os.stat(path)
    if not stat.S_ISREG(st.st_mode) or st.st_mode & 0o077:
        raise SystemExit(f"{path}: not a regular file of mode 0600")
    with open(path) as f:
        return [int(x) for x in f.read().replace(",", " ").split()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model", choices=["llama3", "tinyllama"])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--ids-file")
    g.add_argument("--id-file")
    g.add_argument("--id", type=int)
    a = ap.parse_args()
    if a.id_file:
        ids = ids_of(a.id_file)
        if len(ids) != 1:
            raise SystemExit(f"{a.id_file}: holds {len(ids)} ids; a token file holds exactly one")
    else:
        ids = ids_of(a.ids_file) if a.ids_file else [a.id]
    if a.model == "llama3":
        from tokenizers import Tokenizer
        text = Tokenizer.from_file(LLAMA3).decode(ids, skip_special_tokens=True)
    else:
        sys.path.insert(0, TINY_DIR)
        from pathlib import Path
        from spm_bpe import SpmBpe
        bos = 1
        text = SpmBpe(Path(TINY)).decode([i for i in ids if i != bos])
    print(json.dumps({"text": text}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
