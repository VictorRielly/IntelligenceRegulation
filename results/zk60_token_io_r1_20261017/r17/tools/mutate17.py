#!/usr/bin/env python3
"""Token round 17: test-killing mutations of the r17 tree (each applied, tested and reverted by r17_chain.sh).

usage: mutate17.py apply NAME | revert NAME | list

Each mutant replaces ONE exact text (it must occur once) in one source file; `apply` saves the original's bytes and
sha256 under r17/mutants/NAME.orig, `revert` restores them and checks the sha256. (Same rules as r16b/tools/mutate16b.py.)
A mutant with several (old, new) pairs applies all of them to the same file.

  h19-3-off     plane_index.rs: the A plane names from the legacy table again and the R13 slots' legacy push bodies (the
                frozen-r16b bytes' behaviour; R19-PIN-1); killed by r17::r17_the_plane_index_builds_at_an_r13_shape_...
  h19-4-off     run_capture.rs: `bundle_is_classify` tests the production classifier profiles only (frozen-r16b; F19-1);
                killed by r17::r17_an_r13_rung_classify_run_is_recorded_under_the_classifier_schema
  replay-blind  run_capture.rs: the export replay derives every table but never compares it with the recorded digest;
                killed by r17::r17_a_recorded_table_that_disagrees_with_the_export_is_refused_by_the_replay
  group-skip    run_capture.rs: the recorder does not list the FFN group column as a statement table (it would then
                carry values no replay checked); killed by r17::r17_an_r13_capture_with_table_values_records_every_...
"""
import hashlib, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r17/hashline/src/private_block"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/mutants"

MUTANTS = {
    "h19-3-off": ("plane_index.rs", [
        ("    let r13 = ids.accuracy().is_ok();\n", "    let r13 = false && ids.accuracy().is_ok();\n"),
        # (16:08 fix: the first form `Ok(low) if false =>` did not COMPILE (E0004), a false kill; this form keeps
        # the match exhaustive and always takes the legacy arm)
        ("    let a_names = match ids.accuracy() {\n", "    let a_names = match ids.accuracy().and(Err::<&super::accuracy_layout::AccuracyIds, String>(String::new())) {\n"),
    ]),
    "h19-4-off": ("run_capture.rs", [
        ("    super::run::is_classify_run_profile(b.profile.as_str())\n", "    super::run::CLASSIFY_RUN_PROFILES.contains(&b.profile.as_str())\n"),
    ]),
    "replay-blind": ("run_capture.rs", [
        ("        if want.len() != t.len || got != t.sha256 {\n", "        if want.len() != t.len && got != t.sha256 && false {\n"),
    ]),
    "group-skip": ("run_capture.rs", [
        ("        (SC_FZC, 0) => \"group_column\",\n", ""),
        ("    (SC_FZC, 0),\n    (SC_TAB, 1),\n", "    (SC_TAB, 1),\n"),
        ("const R13_REQUIRED_STATEMENT_TABLES: [(usize, usize); 16] = [\n", "const R13_REQUIRED_STATEMENT_TABLES: [(usize, usize); 15] = [\n"),
    ]),
}


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main():
    cmd = sys.argv[1]
    if cmd == "list":
        print(" ".join(MUTANTS))
        return
    name = sys.argv[2]
    f, pairs = MUTANTS[name]
    path = os.path.join(TREE, f)
    os.makedirs(SAVE, exist_ok=True)
    orig = os.path.join(SAVE, f"{name}.orig")
    if cmd == "apply":
        b = open(path, "rb").read()
        s = b.decode()
        for old, _ in pairs:
            if s.count(old) != 1:
                sys.exit(f"{name}: the text to mutate occurs {s.count(old)} times in {f}: {old!r}")
        if os.path.exists(orig):
            sys.exit(f"{name}: {orig} exists (an earlier mutant was not reverted)")
        open(orig, "wb").write(b)
        open(orig + ".sha256", "w").write(sha(b) + "\n")
        for old, new in pairs:
            s = s.replace(old, new)
        open(path, "w").write(s)
        print(f"applied {name} to {f} (original sha256 {sha(b)[:16]}, mutant {sha(s.encode())[:16]})")
    elif cmd == "revert":
        b = open(orig, "rb").read()
        want = open(orig + ".sha256").read().strip()
        assert sha(b) == want
        open(path, "wb").write(b)
        assert sha(open(path, "rb").read()) == want
        os.rename(orig, orig + ".reverted")
        os.rename(orig + ".sha256", orig + ".sha256.reverted")
        print(f"reverted {name}: {f} back to {want[:16]}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
