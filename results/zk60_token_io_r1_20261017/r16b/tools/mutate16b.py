#!/usr/bin/env python3
"""Token round 16b: test-killing mutations of the r16b tree (each applied, tested and reverted by r16b_mut.sh).

usage: mutate16b.py apply NAME | revert NAME | list

Each mutant replaces ONE exact text (it must occur once) in one source file; `apply` saves the original's bytes and
sha256 under r16b/mutants/NAME.orig, `revert` restores them and checks the sha256. (Same rules as r16/tools/mutate16.py.)

  bits-l     classify.rs: the whole-run LogUp term charges ONE R13 block instead of L (REVIEW_R16 N-r16-1, the
             reviewer's `bits-l` mutant: T128's floor 96 -> 98 with every round-16 lane test green); killed by
             classify_r16_tests::r16b::r16b_the_r13_shieldstral_whole_run_floors_and_terms_are_pinned_exactly
  card-back  classify.rs: round 12's card policy put back into the pre-registered list (the frozen-r16 state, REVIEW_R16
             F-1); killed by classify_r16_tests::r16b::r16b_each_r13_shieldstral_profile_admits_exactly_the_three_...
"""
import hashlib, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r16b/hashline/src/private_block/token_io"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16b/mutants"

MUTANTS = {
    "bits-l": ("classify.rs",
               "        (n + 3 * r - 1) as f64 + (l as u128 * blk_num) as f64\n",
               "        (n + 3 * r - 1) as f64 + (1u128 * blk_num) as f64\n"),
    "card-back": ("classify.rs",
                  "    let mut v = vec![policy_rung_dev()];\n",
                  "    let mut v = vec![policy_rung_dev(), policy_shieldstral_card()];\n"),
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
