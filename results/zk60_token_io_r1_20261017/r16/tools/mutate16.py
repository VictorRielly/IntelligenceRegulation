#!/usr/bin/env python3
"""Token round 16: test-killing mutations of the r16 tree (each applied, tested and reverted by r16_mut.sh).

usage: mutate16.py apply NAME | revert NAME | list

Each mutant replaces ONE exact text (it must occur once) in one source file; `apply` saves the original's bytes and
sha256 under r16/mutants/NAME.orig, `revert` restores them and checks the sha256. (Same rules as r14/tools/mutate.py.)

  gate    classify.rs: stage_shape returns the run seed's shape at an R13 profile (the token lane's pre-round-16
          behaviour: no per-layer gate denominator); killed by r16_an_r13_classifier_run_with_two_gate_denominators_...
  prehdr  classify_run.rs: the verifier's pre-header per-stage block check removed; killed by
          r16_a_block_at_another_stage_shape_and_the_run_seed_shape_are_refused
  bits    token_io/run.rs: the R13 block term charged at the legacy degree (3 T_d instead of 4 T_d); killed by
          r16_the_r13_whole_run_figure_charges_the_degree_two_tables_and_clears_95
  reuse   classify_tied.rs: the loader's derivation reused without comparing its margin parameters; killed by
          r16_the_loaders_tied_derivation_is_reused_only_with_the_bound_margin_parameters
"""
import hashlib, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r16/hashline/src/private_block/token_io"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/mutants"

MUTANTS = {
    "gate": ("classify.rs",
             "            let g = self.stage_gate.get(k).copied().flatten().ok_or_else(|| format!(\"classifier run: block stage {k} carries no R13 gate denominator\"))?;\n            sh.with_accuracy_gate_shift(g)",
             "            let _g = self.stage_gate.get(k).copied().flatten().ok_or_else(|| format!(\"classifier run: block stage {k} carries no R13 gate denominator\"))?;\n            Ok(sh)"),
    "prehdr": ("classify_run.rs",
               "    if sh.accuracy_stack() != super::super::accuracy_precision::Stack::Legacy {\n        for k in 0..l {",
               "    if false && sh.accuracy_stack() != super::super::accuracy_precision::Stack::Legacy {\n        for k in 0..l {"),
    "bits": ("run.rs",
             "    Some(n + 4 * t_d - 1)",
             "    Some(n + 3 * t_d - 1)"),
    "reuse": ("classify_tied.rs",
              "            let r = match pre.filter(|p| p.margin == Some(want)) {",
              "            let r = match pre.filter(|_p| true) {"),
}


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main():
    cmd = sys.argv[1]
    if cmd == "list":
        print(" ".join(MUTANTS))
        return
    name = sys.argv[2]
    f, old, new = MUTANTS[name]
    path = os.path.join(TREE, f)
    os.makedirs(SAVE, exist_ok=True)
    orig = os.path.join(SAVE, f"{name}.orig")
    if cmd == "apply":
        b = open(path, "rb").read()
        s = b.decode()
        if s.count(old) != 1:
            sys.exit(f"{name}: the text to mutate occurs {s.count(old)} times in {f}")
        if os.path.exists(orig):
            sys.exit(f"{name}: {orig} exists (an earlier mutant was not reverted)")
        open(orig, "wb").write(b)
        open(orig + ".sha256", "w").write(sha(b) + "\n")
        open(path, "w").write(s.replace(old, new))
        print(f"applied {name} to {f} (original sha256 {sha(b)[:16]})")
    elif cmd == "revert":
        b = open(orig, "rb").read()
        want = open(orig + ".sha256").read().strip()
        assert sha(b) == want
        open(path, "wb").write(b)
        assert sha(open(path, "rb").read()) == want
        os.rename(orig, orig + ".reverted")
        print(f"reverted {name}: {f} is back to sha256 {want[:16]}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
