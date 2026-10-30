#!/usr/bin/env python3
"""Token round 18: test-killing mutations of the r18 tree (each applied, tested and reverted by r18_mut.sh).

usage: mutate18.py apply NAME | revert NAME | list

Each mutant replaces ONE exact text (it must occur once) in one source file of the r18 tree; `apply` saves the
original's bytes and sha256 under r18/mutants/NAME.orig, `revert` restores them and checks the sha256. (Same rules as
r17/tools/mutate17.py.) A mutant with several (old, new) pairs applies all of them to the same file.

Killed by a test of the suite (cargo test, exit 101):
  fix1-revert      classify_batch.rs: `BatchClaim::hold` keeps the reload counts but NOT the job's directories (Fix 1
                   undone); killed by batch::r18::r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind
  fix2-revert      s25_tests.rs: `production_sources` follows no `#[path]` child and checks no edge list (Fix 2 undone);
                   killed by s25_tests::r18_the_census_reads_the_batch_files_through_their_path_lines
  rng-plant        classify_batch.rs: a seeded `ZkRng::new` planted in production text; killed by
                   s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system
  label-plant      classify_batch_plan.rs: a literal absorb label planted in production text; killed by
                   hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table
  one-post-revert  classify_batch.rs: a repeated flag is no longer refused; killed by
                   batch::r18::r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read
Killed by the FIXED-ENTROPY harness (r18/tools/run_fixed.sh + the ignored rung byte-identity test):
  job-order        classify_batch.rs: the jobs are proved in REVERSE order (each still with its own flags), so job 1
                   takes the draws meant for job 0: its bytes differ from the single prove's (test exit 101)
  reused-draw      zkp-core/src/rng.rs: `ZkRng::from_os` reads /dev/urandom ONCE per process and reuses those 32 bytes
                   for every later generator (a draw reused across proofs): blocks are left unread (harness exit 97)
"""
import hashlib, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r18"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/mutants"
PB = "hashline/src/private_block/"

PLANT_RNG = (
    "// MUTANT rng-plant (token round 18): a planted seeded generator\n"
    "#[allow(dead_code)]\n"
    "fn r18_planted_seeded_generator() -> crate::zk::ZkRng {\n"
    "    crate::zk::ZkRng::new(7, b\"r18-plant\")\n"
    "}\n\n"
)

MUTANTS = {
    "fix1-revert": (PB + "token_io/classify_batch.rs", [
        ("        self.dirs.extend(dirs.iter().map(|d| d.to_path_buf()));\n", "        let _ = dirs;\n"),
    ]),
    "fix2-revert": (PB + "s25_tests.rs", [
        ("    while k < out.len() {\n", "    while k < out.len() && false {\n"),
        ("    assert_eq!(edges, want, \"the production `#[path]` children on the path moved (REVIEW A5 finding 2): read each new one, then list it here\");\n",
         "    let _ = (edges, want);\n"),
    ]),
    "rng-plant": (PB + "token_io/classify_batch.rs", [
        ("// TOKEN ROUND 18: the round's tests (test code only), a child of this module so\n",
         PLANT_RNG + "// TOKEN ROUND 18: the round's tests (test code only), a child of this module so\n"),
    ]),
    "label-plant": (PB + "token_io/classify_batch_plan.rs", [
        ("pub(super) const MAX_JOBS: usize = 24;\n",
         "pub(super) const MAX_JOBS: usize = 24;\n#[allow(dead_code)]\nconst R18_PLANT: (&str, &[u8]) = (\"absorb\", b\"r18-planted-label\");\n"),
    ]),
    "one-post-revert": (PB + "token_io/classify_batch.rs", [
        ("    if let Some(k) = BATCH_FLAGS.iter().find(", "    if let Some(k) = BATCH_FLAGS.iter().filter(|_| false).find("),
    ]),
    "job-order": (PB + "token_io/classify_batch.rs", [
        ("    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate() {\n",
         "    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate().rev() {\n"),
        ("        let (seal_loads, prove_loads) = *claim.reloads.get(index).ok_or(",
         "        let (seal_loads, prove_loads) = *claim.reloads.last().ok_or("),
    ]),
    "reused-draw": ("zkp-core/src/rng.rs", [
        ("            let mut source = std::fs::File::open(\"/dev/urandom\")?;\n            Self::from_entropy_reader(domain, &mut source)\n",
         "            static REUSED: std::sync::OnceLock<[u8; 32]> = std::sync::OnceLock::new();\n"
         "            let e = *REUSED.get_or_init(|| { let mut b = [0u8; 32]; std::io::Read::read_exact(&mut std::fs::File::open(\"/dev/urandom\").unwrap(), &mut b).unwrap(); b });\n"
         "            Self::from_entropy_reader(domain, &mut &e[..])\n"),
    ]),
}


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        print(" ".join(MUTANTS))
        return
    if cmd not in ("apply", "revert") or len(sys.argv) != 3 or sys.argv[2] not in MUTANTS:
        sys.exit(__doc__)
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
    else:
        b = open(orig, "rb").read()
        want = open(orig + ".sha256").read().strip()
        assert sha(b) == want
        open(path, "wb").write(b)
        assert sha(open(path, "rb").read()) == want
        os.rename(orig, orig + ".reverted")
        os.rename(orig + ".sha256", orig + ".sha256.reverted")
        print(f"reverted {name}: {f} back to {want[:16]}")


if __name__ == "__main__":
    main()
