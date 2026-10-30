#!/usr/bin/env python3
"""Token round 14: test-killing mutations of the r14 tree (each applied, tested and reverted by r14_mut.sh).

usage: mutate.py apply NAME | revert NAME | list

Each mutant replaces ONE exact text (it must occur once) in one source file; `apply` saves the original's
bytes and sha256 under r14/mutants/NAME.orig, `revert` restores them and checks the sha256.

  n2    classify_tied.rs: the post-derivation profile-digest check removed (REVIEW_R13 N-r13-2's mutant
        `skip-second-digest`); killed by r14_the_post_derivation_profile_digest_check_...
  pad   stage_in_c.rs: the template clause's indicator pi no longer covers the trailing pad positions (the
        sealing pass still refuses them); killed by r14_a_doctored_pad_position_is_refused
  bind  classify_tied.rs: BoundClassifierTables::check_for's trained-statement test removed; killed by
        r14_tables_bound_to_another_trained_statement_are_refused_at_every_entry_point
"""
import hashlib, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14/hashline/src/private_block/token_io"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r14/mutants"

MUTANTS = {
    "n2": ("classify_tied.rs",
           "    if tied.profile_sha256 != *statement_profile_sha256 {\n        return Err(\"classifier (R-C2): the derivation read a profile.json other than the one the trained statement binds\".into());",
           "    if false && tied.profile_sha256 != *statement_profile_sha256 {\n        return Err(\"classifier (R-C2): the derivation read a profile.json other than the one the trained statement binds\".into());"),
    "pad": ("stage_in_c.rs",
            "let i_pi = b.public((0..sn).map(|t| if cp.is_template(t) { Fp2::ONE } else { Fp2::ZERO }).collect());",
            "let i_pi = b.public((0..sn).map(|t| if cp.is_template(t) && !(t >= cp.item_len() && t < cp.tokens) { Fp2::ONE } else { Fp2::ZERO }).collect());"),
    "bind": ("classify_tied.rs",
             "        if self.model_identity != model.identity() || self.profile_sha256 != model.calibration.export_profile_sha256 {",
             "        if false && (self.model_identity != model.identity() || self.profile_sha256 != model.calibration.export_profile_sha256) {"),
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
