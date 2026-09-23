#!/usr/bin/env python3
"""G-R4 check, item 1: the draft's mutations m1 and m2 (and an alpha mutation
m4) inserted into the PRODUCTION source of the review worktree, one at a
time, then:

  * the lane's Rust assertion-6 source scan
    (s36_tests::the_only_relations_imposed_on_drawn_values_are_the_three_the_schedule_declares),
  * the lane's count test at six shapes
    (s36_tests::a_block_proof_consumes_exactly_the_counted_stream_at_every_shape),
  * the check's value-level replay (gr4_check_tests::gr4_replay_toy_* and gr4_replay_rung_g_*),

and the ORIGINAL BYTES are written back in a `finally`, whatever happens.
Nothing is committed with a mutation in it; after the last run the script
asserts `git diff --quiet` on every production file it touched.

Run detached:  python3 mutation_runs.py   (writes mut-<id>.log, mutation_runs.json, mutation_runs.out)
"""
import json
import pathlib
import subprocess
import sys

WT = pathlib.Path("/home/victor/wt-zk60-block125m-review")
OUT = WT / "results/zk60_blinding_law_gr4_check"
PROTO = WT / "hashline/src/private_block/protocol.rs"
ZK = WT / "hashline/src/zk.rs"

A_FILL = "    for x in &mut a_data[lay.a_mask_base * n..] {\n        *x = rng.fp();\n    }\n"
H_FILL = "    for x in &mut h_data[lay.h_mask_base * n..] {\n        *x = rng.fp();\n    }\n"
ALPHA_TAGGED = ("pub fn mask_commit_tagged(", "    let masks: Vec<CfsMask> = specs.iter().map(|&(n, d)| CfsMask::random(rng, n, d)).collect();\n")

MUTATIONS = [
    # (id, file, description, apply(text) -> text)
    ("m1", PROTO, "overwrite a DRAWN A proximity-row word after the fill (the draft's m1, verbatim)",
     lambda t: once(t, A_FILL, A_FILL + "    a_data[lay.a_prox * n] = Fp::ZERO;\n")),
    ("m2", PROTO, "copy an A reserved-pair word into H's reserved rows (the draft's m2; `a_data` is moved into the A commitment by then, so the Rust reads `a.data`)",
     lambda t: once(t, H_FILL, H_FILL + "    h_data[lay.h_mask_base * n] = a.data[lay.a_mask_base * n];\n")),
    ("m4", ZK, "alpha: slot 1's first CFS coefficient := slot 0's, inside zk::mask_commit_tagged",
     lambda t: alpha(t)),
]

TESTS = ["the_only_relations_imposed_on_drawn_values", "a_block_proof_consumes_exactly_the_counted_stream_at_every_shape",
         "gr4_replay_toy_block", "gr4_replay_rung_g_block"]


def once(text, anchor, repl):
    assert text.count(anchor) == 1, f"anchor occurs {text.count(anchor)} times"
    return text.replace(anchor, repl, 1)


def alpha(text):
    sig, line = ALPHA_TAGGED
    at = text.index(sig)
    k = text.index(line, at)
    assert k - at < 800, "the draw line is not inside mask_commit_tagged"
    new = line.replace("let masks", "let mut masks") + "    masks[1].coeffs[0] = masks[0].coeffs[0];\n"
    return text[:k] + new + text[k + len(line):]


def cargo(log):
    cmd = ["flock", "/tmp/zk-build.lock", "cargo", "test", "--release", "--manifest-path", str(WT / "hashline/Cargo.toml"),
           "--lib", TESTS[0], "--", *TESTS[1:], "--test-threads=6", "--nocapture"]
    with open(log, "w") as f:
        return subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT).returncode


def outcome(log):
    text = pathlib.Path(log).read_text(errors="replace")
    res = {}
    for name in TESTS:
        ok = [l for l in text.splitlines() if l.startswith("test ") and name in l]
        res[name] = ok[0].rsplit(" ... ", 1)[-1] if ok else "NOT RUN (build failed?)"
    res["failure_lines"] = [l.strip()[:300] for l in text.splitlines() if "panicked at" in l or "root is not" in l or "UNDECLARED" in l or "no longer the declared" in l][:8]
    res["gr4_lines"] = [l for l in text.splitlines() if l.startswith("GR4 replay") and "non-vacuity" not in l]
    return res


summary = []
for mid, path, desc, apply in MUTATIONS:
    original = path.read_bytes()
    try:
        path.write_text(apply(original.decode()))
        rc = cargo(OUT / f"mut-{mid}.log")
    finally:
        path.write_bytes(original)
    res = outcome(OUT / f"mut-{mid}.log")
    summary.append({"id": mid, "file": str(path.relative_to(WT)), "mutation": desc, "cargo_exit": rc, **res})
    print(json.dumps(summary[-1], indent=1), flush=True)

clean = subprocess.run(["git", "-C", str(WT), "diff", "--quiet", "--", str(PROTO.relative_to(WT)), str(ZK.relative_to(WT))]).returncode
summary.append({"production_files_restored_git_diff_quiet_exit": clean})
(OUT / "mutation_runs.json").write_text(json.dumps(summary, indent=1) + "\n")
print("production files restored (git diff --quiet exit 0):", clean == 0)
sys.exit(0 if clean == 0 else 1)
