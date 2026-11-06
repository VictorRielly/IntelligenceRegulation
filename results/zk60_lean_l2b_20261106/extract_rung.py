#!/usr/bin/env python3
"""Extract the trace lines of the Rust export (`L1<TAB><tag><TAB><name><TAB>...`) for the given tags from a log,
into the TSV `L1Check.lean` reads (`<tag><TAB><name><TAB>...`), and print its size and SHA-256.

usage: extract_rung.py <log> <out.tsv> <tag> [<tag> ...]
"""
import hashlib
import sys


def main():
    log, out, tags = sys.argv[1], sys.argv[2], set(sys.argv[3:])
    n = 0
    with open(log) as f, open(out, "w") as g:
        for line in f:
            if not line.startswith("L1\t"):
                continue
            cells = line.rstrip("\n").split("\t")
            if len(cells) >= 3 and cells[1] in tags:
                g.write("\t".join(cells[1:]) + "\n")
                n += 1
    data = open(out, "rb").read()
    print(f"{out}: {n} arrays, {len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
