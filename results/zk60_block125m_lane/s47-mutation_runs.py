#!/usr/bin/env python3
"""Stage 47, task 2 (ruling LW-2): the G-R4 check's three mutations m1, m2, m4
re-demonstrated against the LANE's copy of gr4_check_tests.rs.

Each mutation is inserted into PRODUCTION source of this worktree, one at a
time (the same one-line edits as the review branch's
results/zk60_blinding_law_gr4_check/mutation_runs.py, re-anchored on the lane
tip), and then, in one cargo invocation under the build lock:

  * the lane's gr4_check_tests (toy, rung-G, run boundary) - must FAIL on the
    toy and rung-G replays, naming the mutated root (m1 -> A, m2 -> H, m4 -> M);
  * stage 36's assertion 6 (s36_tests::the_only_relations_imposed_on_drawn_
    values_are_the_three_the_schedule_declares) - stays GREEN: the documented
    blindness;
  * stage 36's six-shape count test (a_block_proof_consumes_exactly_the_
    counted_stream_at_every_shape) - stays GREEN: no mutation moves a count.

The ORIGINAL BYTES are written back in a `finally`, whatever happens. Nothing
mutated is ever committed. The script starts by requiring the production
files clean and ends by printing `git --no-pager diff` of protocol.rs, zk.rs
and zkp-core (must be EMPTY) and asserting `git diff --quiet` on them.

Run detached:
  setsid nohup bash -c 'python3 <this> >> s47-mutation_runs.out 2>&1; echo $? > s47-mutation_runs.done' &
Writes s47-mut-<id>.log, s47-mutation_runs.json; prints to stdout.
"""
import json
import pathlib
import subprocess
import sys

WT = pathlib.Path("/home/victor/wt-zk60-block125m")
OUT = WT / "results/zk60_block125m_lane"
PROTO = WT / "hashline/src/private_block/protocol.rs"
ZK = WT / "hashline/src/zk.rs"
DIFF_PATHS = ["hashline/src/private_block/protocol.rs", "hashline/src/zk.rs", "zkp-core"]

A_FILL = "    for x in &mut a_data[lay.a_mask_base * n..] {\n        *x = rng.fp();\n    }\n"
H_FILL = "    for x in &mut h_data[lay.h_mask_base * n..] {\n        *x = rng.fp();\n    }\n"
ALPHA_TAGGED = ("pub fn mask_commit_tagged(", "    let masks: Vec<CfsMask> = specs.iter().map(|&(n, d)| CfsMask::random(rng, n, d)).collect();\n")

A6 = "s36_tests::the_only_relations_imposed_on_drawn_values_are_the_three_the_schedule_declares"
COUNT = "s36_tests::a_block_proof_consumes_exactly_the_counted_stream_at_every_shape"
GR4_TOY = "gr4_check_tests::gr4_replay_toy_block_commits_exactly_the_predicted_stream"
GR4_G = "gr4_check_tests::gr4_replay_rung_g_block_commits_exactly_the_predicted_stream"
GR4_B = "gr4_check_tests::gr4_replay_boundary_commits_exactly_the_predicted_stream"
TESTS = [A6, COUNT, GR4_TOY, GR4_G, GR4_B]


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


MUTATIONS = [
    # (id, file, description, expected root named by the replay's failing assertion, apply)
    ("m1", PROTO, "A's proximity row: a DRAWN word overwritten after the fill (`a_data[lay.a_prox * n] = Fp::ZERO;`)", "A",
     lambda t: once(t, A_FILL, A_FILL + "    a_data[lay.a_prox * n] = Fp::ZERO;\n")),
    ("m2", PROTO, "an A reserved-pair word copied into H's reserved rows (`h_data[lay.h_mask_base * n] = a.data[lay.a_mask_base * n];`)", "H",
     lambda t: once(t, H_FILL, H_FILL + "    h_data[lay.h_mask_base * n] = a.data[lay.a_mask_base * n];\n")),
    ("m4", ZK, "alpha: slot 1's first CFS coefficient := slot 0's inside zk::mask_commit_tagged (`masks[1].coeffs[0] = masks[0].coeffs[0];`)", "M",
     alpha),
]


def git_diff_quiet():
    return subprocess.run(["git", "-C", str(WT), "diff", "--quiet", "--", *DIFF_PATHS]).returncode


def cargo(log):
    cmd = ["flock", "/tmp/zk-build.lock", "cargo", "test", "--release", "--manifest-path", str(WT / "hashline/Cargo.toml"),
           "--lib", "gr4_check_tests", "--", A6, COUNT, "--test-threads=6", "--nocapture"]
    with open(log, "w") as f:
        return subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT).returncode


def outcome(log):
    text = pathlib.Path(log).read_text(errors="replace")
    lines = text.splitlines()
    res = {}
    for name in TESTS:
        hit = [l for l in lines if l.startswith("test ") and l.split(" ... ")[0].endswith(name)]
        res[name] = hit[0].rsplit(" ... ", 1)[-1] if hit else "NOT RUN (build failed?)"
    named = {}
    for label, needle in [("A", "A's root is not"), ("M", "M's root is not"), ("H", "H's root is not")]:
        named[label] = sum(1 for l in lines if needle in l)
    res["replay_failures_naming_root"] = named
    res["gr4_lines"] = [l for l in lines if l.startswith("GR4 replay") and "non-vacuity" not in l]
    res["test_result"] = [l for l in lines if l.startswith("test result:")]
    res["build_errors"] = [l for l in lines if l.startswith("error")][:5]
    return res


assert git_diff_quiet() == 0, "the production files are not clean BEFORE the mutation runs"
summary = []
for mid, path, desc, root, apply in MUTATIONS:
    original = path.read_bytes()
    try:
        path.write_text(apply(original.decode()))
        rc = cargo(OUT / f"s47-mut-{mid}.log")
    finally:
        path.write_bytes(original)
    res = outcome(OUT / f"s47-mut-{mid}.log")
    replay_failed = res[GR4_TOY] == "FAILED" and res[GR4_G] == "FAILED"
    names_root = res["replay_failures_naming_root"][root] == 2 and all(v == 0 for k, v in res["replay_failures_naming_root"].items() if k != root)
    a6_green = res[A6] == "ok"
    verdict = {"replay_fails_on_toy_and_rung_g": replay_failed, "replay_names_the_expected_root": names_root, "assertion6_stays_green": a6_green,
               "count_test_stays_green": res[COUNT] == "ok", "boundary_replay_green": res[GR4_B] == "ok"}
    summary.append({"id": mid, "file": str(path.relative_to(WT)), "mutation": desc, "expected_root": root, "cargo_exit": rc, **verdict, **res})
    print(json.dumps(summary[-1], indent=1), flush=True)

clean = git_diff_quiet()
diff = subprocess.run(["git", "--no-pager", "-C", str(WT), "diff", "--", *DIFF_PATHS], capture_output=True, text=True).stdout
print(f"git --no-pager -C {WT} diff -- {' '.join(DIFF_PATHS)}  -> {len(diff)} bytes of output (EMPTY = {diff == ''})", flush=True)
print(diff, end="", flush=True)
summary.append({"production_files_restored_git_diff_quiet_exit": clean, "git_diff_output_bytes": len(diff)})
(OUT / "s47-mutation_runs.json").write_text(json.dumps(summary, indent=1) + "\n")
ok = clean == 0 and diff == "" and all(s["replay_fails_on_toy_and_rung_g"] and s["replay_names_the_expected_root"] and s["assertion6_stays_green"] for s in summary[:-1])
print("production files restored (git diff --quiet exit 0):", clean == 0)
print("ALL EXPECTATIONS MET:", ok)
sys.exit(0 if ok else 1)
