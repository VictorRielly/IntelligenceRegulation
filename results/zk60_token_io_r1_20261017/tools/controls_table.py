"""Collect the R1 control results from a test log into controls.json + a markdown table.

Reads the `TOKEN-IO-R1 CONTROL #n | what | predicted [...] | actual: ... | AS PREDICTED` lines the Rust
tests print (`token_io/tests.rs`), keeps the first actual refusal per control, writes controls.json and
controls.md next to the log. One thread, < 1 s.
"""
import json
import os
import re
import sys

PAT = re.compile(r"TOKEN-IO-R1 CONTROL #(\S+(?: #\S+)*) \| (.*?) \| predicted (.*?) \| actual: (.*?) \| (AS PREDICTED|NOT AS PREDICTED)")
NA = re.compile(r"TOKEN-IO-R1 CONTROL #(\S+(?: #\S+)*) \| (.*?) \| (not applicable.*)")


def main(log):
    rows = []
    for line in open(log, errors="replace"):
        m = PAT.search(line)
        if m:
            rows.append({"control": m.group(1), "forgery": m.group(2), "predicted": m.group(3), "actual": m.group(4).strip(), "verdict": m.group(5)})
            continue
        m = NA.search(line)
        if m:
            rows.append({"control": m.group(1), "forgery": m.group(2), "predicted": "-", "actual": m.group(3), "verdict": "N/A at R1"})
    out = os.path.dirname(os.path.abspath(log))
    json.dump(rows, open(os.path.join(out, "controls.json"), "w"), indent=1)
    with open(os.path.join(out, "controls.md"), "w") as fh:
        fh.write("| # | forgery | predicted | actual (verifier's refusal, first 150 chars) | verdict |\n|---|---|---|---|---|\n")
        for r in rows:
            fh.write("| {control} | {forgery} | {predicted} | {actual} | {verdict} |\n".format(**{k: v.replace("|", "/") for k, v in r.items()}))
    bad = [r for r in rows if r["verdict"] == "NOT AS PREDICTED"]
    print(len(rows), "control lines;", len(bad), "not as predicted")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
