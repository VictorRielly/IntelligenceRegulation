#!/usr/bin/env python3
"""Token round 16 (1): resolve the diff3 conflicts left by r16_rebase.py apply, one rule per block.

Every block `<<<<<<< token / ||||||| r12b / ======= / >>>>>>> r13` is replaced by the resolution named below
(by file and block index). Rules:
  both      token side, then r13 side (additive registrations on both sides)
  r13       r13 side only (the same code line on both sides; R13 carries the token lane's visibility)
  custom    a hand-written text (array lengths summed; counted afterwards by r16_count.py)
Refuses if a file has a different number of blocks than listed. Writes r16/conflicts_resolved.json.
"""
import json, re, sys, datetime

ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r16/hashline/src/private_block"
OUT = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/conflicts_resolved.json"
BLOCK = re.compile(r"<<<<<<< token\n(.*?)\|\|\|\|\|\|\| r12b\n(.*?)=======\n(.*?)>>>>>>> r13\n", re.S)


def hd_lane(tok, base, new):
    assert tok == "    let lane: [(&str, &str); 24] = [\n", tok
    assert base == "    let lane: [(&str, &str); 16] = [\n", base
    assert new.startswith("    let lane: [(&str, &str); 28] = [\n")
    return new.replace("[(&str, &str); 28]", "[(&str, &str); 36]", 1)


def rc_own(tok, base, new):
    assert tok == "pub(super) const OWN_SOURCE_FILES: [&str; 26] = [\n", tok
    assert base == "pub(super) const OWN_SOURCE_FILES: [&str; 20] = [\n", base
    assert new.startswith("pub(super) const OWN_SOURCE_FILES: [&str; 32] = [\n")
    return new.replace("[&str; 32]", "[&str; 38]", 1)


def s25_count(tok, base, new):
    add = " + super::accuracy_profile_tests::registered_runs().len()"
    assert add in new and add not in tok
    anchor = " + super::token_io::classify::registered_classify_runs().len(),"
    assert anchor in tok
    return tok.replace(anchor, " + super::token_io::classify::registered_classify_runs().len()" + add + ",", 1)


def s25_scan(tok, base, new):
    push = '    out.push(("src/private_block/tied_tables/derive.rs".to_string(),source("src/private_block/tied_tables/derive.rs")));\n'
    assert new.startswith(push), "R13's side no longer starts with R12b's derive push"
    assert base == push
    return tok + new[len(push):]


RULES = {
    "tied_tables.rs": ["r13"],
    "hash_domain_tests.rs": [hd_lane],
    "run_capture.rs": [rc_own],
    "s24_tests.rs": ["both", "both"],
    "s33_tests.rs": ["both"],
    "s25_tests.rs": [s25_count, s25_scan],
}


def main():
    report = {"utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "files": {}}
    for name, rules in RULES.items():
        p = f"{ROOT}/{name}"
        s = open(p).read()
        blocks = list(BLOCK.finditer(s))
        if len(blocks) != len(rules):
            sys.exit(f"{name}: {len(blocks)} blocks, {len(rules)} rules")
        out, pos, done = [], 0, []
        for m, rule in zip(blocks, rules):
            tok, base, new = m.group(1), m.group(2), m.group(3)
            if rule == "both":
                res = tok + new
            elif rule == "r13":
                res = new
            else:
                res = rule(tok, base, new)
            out.append(s[pos:m.start()])
            out.append(res)
            pos = m.end()
            done.append({"rule": rule if isinstance(rule, str) else rule.__name__,
                         "token_lines": tok.count("\n"), "r13_lines": new.count("\n"), "result_lines": res.count("\n")})
        out.append(s[pos:])
        t = "".join(out)
        for mk in ("<<<<<<< ", "||||||| ", ">>>>>>> "):
            if mk in t:
                sys.exit(f"{name}: a marker {mk!r} is left")
        open(p, "w").write(t)
        report["files"][name] = done
    json.dump(report, open(OUT, "w"), indent=1)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
