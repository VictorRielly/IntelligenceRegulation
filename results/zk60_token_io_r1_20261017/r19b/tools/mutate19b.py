#!/usr/bin/env python3
"""Token round 19b: test-killing mutations of the r19b tree (each applied, tested and reverted by r19b_chain.sh).

usage: mutate19.py apply NAME | revert NAME | list | describe NAME

A mutant is a list of operations on the r19b tree: ("edit", FILE, OLD, NEW) replaces ONE exact text (it must occur
exactly once), ("append", FILE, TEXT) adds TEXT at the end of FILE (round 19b: after its tests module) and ("create",
FILE, TEXT) adds a NEW file (it must not exist; its new directories are recorded). `apply` saves every edited file's
bytes and sha256 under r19b/mutants/NAME/ first; `revert` restores them, checks the sha256s, deletes the created files
and the directories it made (only if empty), and checks the tree's touched paths are back. (r19/tools/mutate19.py
re-rooted, plus `append` and round 19b's mutants; round 19's 20 are unchanged.)

Round 18's set, on the r19 tree (killed by a test, cargo exit 101, unless noted):
  fix1-revert      classify_batch.rs: BatchClaim::hold keeps no directory (A5 fix 1 undone)
  fix2-revert      s25_tests.rs: the follower drops every `#[path]` child (round 18's fix 2, re-targeted at round 19's
                   follower); killed by s25_tests::r18_the_census_reads_the_batch_files_through_their_path_lines
  rng-plant        classify_batch.rs: a seeded ZkRng::new planted in production text; the generator census
  label-plant      classify_batch_plan.rs: a literal absorb label planted; the label scan
  one-post-revert  classify_batch.rs: a repeated flag no longer refused
  job-order        classify_batch.rs: jobs proved in reverse order (the FIXED-ENTROPY harness: test exit 101)
  reused-draw      zkp-core/src/rng.rs: from_os reuses one process-wide draw (the harness: unread blocks, exit 97)
R18-2, one seeded generator hidden behind each module-line shape the round-18 follower missed (REVIEW_R18 §5), in a
new production file declared from token_io/classify_cli.rs:
  hide-<shape>-u   the declaration and the file only (production change only): the suite as it stands must kill it
                   (the census's module graph and the label scan's module check both meet an unlisted module)
  hide-<shape>-l   the same, AND the census's edge list / file count extended to include it (as if someone listed the
                   edge without reading the file): the generator census itself must find the ZkRng::new in it
  shapes: oneline (`#[path = "r19_plant.rs"] mod r19_plant;`), comment (a line comment between #[path] and mod),
          pubin (`pub(in crate::private_block) mod`), pubself (`pub(self) mod`), grandchild (a plain `mod r19_plant;`
          in classify_cli.rs, file token_io/classify_cli/r19_plant.rs)
E7 (derive.rs):
  e7-ignore-models ZK60_MODELS is ignored (always $HOME/models); the default-checkpoint test
  e7-empty-is-set  an EMPTY ZK60_MODELS counts as set; the default-checkpoint test
  e7-precedence    the default wins over a declared checkpoint_file; the precedence test
ROUND 19b (REVIEW_R19 R19-1, R19-2):
  e7-no-pin-compare  derive.rs: the whole-file SHA-256 comparison (`:194` in r19) DELETED; killed by
                     tied_tables::derive::tests::r19b_checkpoint_open_refuses_a_same_size_file_that_is_not_the_pinned_checkpoint
  e7-follow-symlink  tied_tables.rs `regular`: `symlink_metadata` -> `metadata` and no O_NOFOLLOW (a symlinked file is
                     followed); killed by tied_tables::derive::tests::r19b_checkpoint_open_refuses_a_symlinked_checkpoint_file
  after-tests-rng    derive.rs: a seeded generator `fn` AFTER its tests module; the generator census
  after-tests-label  derive.rs: a literal absorb label AFTER its tests module; the label scan
  after-tests-mod-u  derive.rs: a `#[path]` module AFTER its tests module (file tied_tables/r19b_plant.rs, a seeded
                     generator); the census's graph and the label scan's module check
  after-tests-mod-l  the same, and the edge and the count 48 listed in the census: the census finds the generator
  include-u          token_io/classify_cli.rs: `include!("r19b_plant.rs");` (file token_io/r19b_plant.rs, a seeded
                     generator); the census and the label scan (the follower refuses include!)
  macro-mod          src/lib.rs: a `#[macro_export]` macro expanding to `mod r19b_macro_plant;`, invoked in
                     token_io/classify_cli.rs (file token_io/classify_cli/r19b_macro_plant.rs, a seeded generator): no
                     scan sees a `mod`; the directory check (s25 r19b_every_rs_file_...) must find the new file
"""
import hashlib, json, os, sys

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r19b"
SAVE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/mutants"
PB = "hashline/src/private_block/"
TIO = PB + "token_io/"

PLANT_RNG = (
    "// MUTANT rng-plant (token round 19): a planted seeded generator\n"
    "#[allow(dead_code)]\n"
    "fn r18_planted_seeded_generator() -> crate::zk::ZkRng {\n"
    "    crate::zk::ZkRng::new(7, b\"r18-plant\")\n"
    "}\n\n"
)
PLANT_FILE = (
    "// MUTANT (token round 19, REVIEW_R18 R18-2): a seeded generator hidden behind a module line\n"
    "#[allow(dead_code)]\n"
    "fn r19_planted_seeded_generator() -> crate::zk::ZkRng {\n"
    "    crate::zk::ZkRng::new(7, b\"r19-plant\")\n"
    "}\n"
)
ANCHOR = "#[path = \"classify_batch.rs\"]\nmod batch;\n"
SHAPES = {
    "oneline": ("#[path = \"r19_plant.rs\"] mod r19_plant;\n", "token_io/r19_plant.rs"),
    "comment": ("#[path = \"r19_plant.rs\"]\n// MUTANT: a comment between the attribute and `mod`\nmod r19_plant;\n", "token_io/r19_plant.rs"),
    "pubin": ("#[path = \"r19_plant.rs\"]\npub(in crate::private_block) mod r19_plant;\n", "token_io/r19_plant.rs"),
    "pubself": ("#[path = \"r19_plant.rs\"]\npub(self) mod r19_plant;\n", "token_io/r19_plant.rs"),
    "grandchild": ("mod r19_plant;\n", "token_io/classify_cli/r19_plant.rs"),
}
EDGE_ANCHOR = "            (\"src/private_block/token_io/classify_cli.rs\", \"src/private_block/token_io/classify_batch.rs\"),\n"
COUNT_OLD = "    assert_eq!(graph.files.len(), 47, "
COUNT_NEW = "    assert_eq!(graph.files.len(), 48, "

MUTANTS = {
    "fix1-revert": [("edit", TIO + "classify_batch.rs", "        self.dirs.extend(dirs.iter().map(|d| d.to_path_buf()));\n", "        let _ = dirs;\n")],
    "fix2-revert": [("edit", PB + "s25_tests.rs", "            out.push((child, true));\n", "            let _ = child;\n")],
    "rng-plant": [("edit", TIO + "classify_batch.rs", "// TOKEN ROUND 18: the round's tests (test code only), a child of this module so\n",
                   PLANT_RNG + "// TOKEN ROUND 18: the round's tests (test code only), a child of this module so\n")],
    "label-plant": [("edit", TIO + "classify_batch_plan.rs", "pub(super) const MAX_JOBS: usize = 24;\n",
                     "pub(super) const MAX_JOBS: usize = 24;\n#[allow(dead_code)]\nconst R18_PLANT: (&str, &[u8]) = (\"absorb\", b\"r18-planted-label\");\n")],
    "one-post-revert": [("edit", TIO + "classify_batch.rs", "    if let Some(k) = BATCH_FLAGS.iter().find(", "    if let Some(k) = BATCH_FLAGS.iter().filter(|_| false).find(")],
    "job-order": [
        ("edit", TIO + "classify_batch.rs", "    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate() {\n",
         "    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate().rev() {\n"),
        ("edit", TIO + "classify_batch.rs", "        let (seal_loads, prove_loads) = *claim.reloads.get(index).ok_or(",
         "        let (seal_loads, prove_loads) = *claim.reloads.last().ok_or("),
    ],
    "reused-draw": [("edit", "zkp-core/src/rng.rs",
                     "            let mut source = std::fs::File::open(\"/dev/urandom\")?;\n            Self::from_entropy_reader(domain, &mut source)\n",
                     "            static REUSED: std::sync::OnceLock<[u8; 32]> = std::sync::OnceLock::new();\n"
                     "            let e = *REUSED.get_or_init(|| { let mut b = [0u8; 32]; std::io::Read::read_exact(&mut std::fs::File::open(\"/dev/urandom\").unwrap(), &mut b).unwrap(); b });\n"
                     "            Self::from_entropy_reader(domain, &mut &e[..])\n")],
    "e7-ignore-models": [("edit", PB + "tied_tables/derive.rs", "models.filter(|m| !m.is_empty())", "models.filter(|_| false)")],
    "e7-empty-is-set": [("edit", PB + "tied_tables/derive.rs", "models.filter(|m| !m.is_empty())", "models")],
    "e7-precedence": [("edit", PB + "tied_tables/derive.rs",
                       "    match declaration.opt(\"checkpoint_file\").map(J::str).transpose()? {\n        Some(declared) => Ok(std::path::PathBuf::from(declared)),\n        None => default(),\n    }\n",
                       "    match default() {\n        Ok(p) => Ok(p),\n        Err(_) => declaration.opt(\"checkpoint_file\").map(J::str).transpose()?.map(std::path::PathBuf::from).ok_or_else(|| \"no checkpoint\".to_string()),\n    }\n")],
}
for shape, (decl, rel) in SHAPES.items():
    base = [("edit", TIO + "classify_cli.rs", ANCHOR, ANCHOR + decl), ("create", PB + rel, PLANT_FILE)]
    MUTANTS[f"hide-{shape}-u"] = base
    MUTANTS[f"hide-{shape}-l"] = base + [
        ("edit", PB + "s25_tests.rs", EDGE_ANCHOR, EDGE_ANCHOR + f"            (\"src/private_block/token_io/classify_cli.rs\", \"src/private_block/{rel}\"),\n"),
        ("edit", PB + "s25_tests.rs", COUNT_OLD, COUNT_NEW),
    ]


# ---- TOKEN ROUND 19b (REVIEW_R19 R19-1 / R19-2) ----
PLANT19B = (
    "// MUTANT (token round 19b, REVIEW_R19 R19-2): a seeded generator in a file no `mod` line of the scans names\n"
    "#[allow(dead_code)]\n"
    "fn r19b_planted_seeded_generator() -> crate::zk::ZkRng {\n"
    "    crate::zk::ZkRng::new(7, b\"r19b-plant\")\n"
    "}\n"
)
AFTER_RNG = (
    "\n// MUTANT after-tests-rng (token round 19b): a seeded generator after the tests module\n"
    "#[allow(dead_code)]\n"
    "fn r19b_planted_after_the_tests() -> crate::zk::ZkRng {\n"
    "    crate::zk::ZkRng::new(7, b\"r19b-after-tests\")\n"
    "}\n"
)
AFTER_LABEL = (
    "\n// MUTANT after-tests-label (token round 19b): a literal absorb label after the tests module\n"
    "#[allow(dead_code)]\n"
    "const R19B_PLANT: (&str, &[u8]) = (\"absorb\", b\"r19b-planted-label\");\n"
)
AFTER_MOD = "\n// MUTANT after-tests-mod (token round 19b): a module after the tests module\n#[path = \"r19b_plant.rs\"]\nmod r19b_plant;\n"
DERIVE = PB + "tied_tables/derive.rs"
TIED_EDGE = "            (\"src/private_block/tied_tables.rs\", \"src/private_block/tied_tables/derive.rs\"),\n"
MUTANTS.update({
    "e7-no-pin-compare": [("edit", DERIVE,
        "        if <[u8;32]>::from(hasher.finalize()) != pin.weights_sha256 { return Err(\"checkpoint SHA-256 differs from the pinned model\".into()); }\n",
        "        // MUTANT e7-no-pin-compare (token round 19b): the whole-file SHA-256 comparison is deleted\n")],
    "e7-follow-symlink": [
        ("edit", PB + "tied_tables.rs", "    let before = std::fs::symlink_metadata(path).map_err(|e| fail(e.to_string()))?;\n",
         "    let before = std::fs::metadata(path).map_err(|e| fail(e.to_string()))?; // MUTANT e7-follow-symlink\n"),
        ("edit", PB + "tied_tables.rs", "        options.custom_flags(0x20000 | 0x800); // O_NOFOLLOW | O_NONBLOCK\n",
         "        options.custom_flags(0x800); // MUTANT e7-follow-symlink: O_NONBLOCK only, a final symlink is followed\n"),
    ],
    "after-tests-rng": [("append", DERIVE, AFTER_RNG)],
    "after-tests-label": [("append", DERIVE, AFTER_LABEL)],
    "after-tests-mod-u": [("append", DERIVE, AFTER_MOD), ("create", PB + "tied_tables/r19b_plant.rs", PLANT19B)],
    "after-tests-mod-l": [("append", DERIVE, AFTER_MOD), ("create", PB + "tied_tables/r19b_plant.rs", PLANT19B),
        ("edit", PB + "s25_tests.rs", TIED_EDGE, TIED_EDGE + "            (\"src/private_block/tied_tables/derive.rs\", \"src/private_block/tied_tables/r19b_plant.rs\"),\n"),
        ("edit", PB + "s25_tests.rs", COUNT_OLD, COUNT_NEW)],
    "include-u": [("edit", TIO + "classify_cli.rs", ANCHOR, ANCHOR + "include!(\"r19b_plant.rs\");\n"), ("create", TIO + "r19b_plant.rs", PLANT19B)],
    "macro-mod": [
        ("append", "hashline/src/lib.rs", "\n// MUTANT macro-mod (token round 19b): a macro defined outside the scanned files that expands to a module\n#[macro_export]\nmacro_rules! r19b_plant_mod {\n    () => {\n        mod r19b_macro_plant;\n    };\n}\n"),
        ("edit", TIO + "classify_cli.rs", ANCHOR, ANCHOR + "crate::r19b_plant_mod!();\n"),
        ("create", TIO + "classify_cli/r19b_macro_plant.rs", PLANT19B),
    ],
})

def sha(b):
    return hashlib.sha256(b).hexdigest()


def apply(name):
    d = os.path.join(SAVE, name)
    if os.path.exists(os.path.join(d, "record.json")):
        sys.exit(f"{name}: {d}/record.json exists (an earlier apply was not reverted)")
    ops = MUTANTS[name]
    # every op is simulated in memory first: nothing is written unless all of them apply
    current, created = {}, []
    for op in ops:
        if op[0] == "edit":
            _, f, old, new = op
            if f not in current:
                current[f] = open(os.path.join(TREE, f)).read()
            if current[f].count(old) != 1:
                sys.exit(f"{name}: the text to mutate occurs {current[f].count(old)} times in {f}: {old!r}")
            current[f] = current[f].replace(old, new)
        elif op[0] == "append":
            _, f, text = op
            if f not in current:
                current[f] = open(os.path.join(TREE, f)).read()
            if not current[f].endswith("\n"):
                sys.exit(f"{name}: {f} does not end with a line break")
            current[f] = current[f] + text
        else:
            _, f, text = op
            if os.path.exists(os.path.join(TREE, f)):
                sys.exit(f"{name}: {f} exists; the mutant creates it")
            created.append((f, text))
    os.makedirs(d, exist_ok=True)
    rec = {"edited": {}, "created": [], "dirs": []}
    for f in current:
        b = open(os.path.join(TREE, f), "rb").read()
        key = f.replace("/", "__")
        open(os.path.join(d, key + ".orig"), "wb").write(b)
        rec["edited"][f] = {"orig": key + ".orig", "sha256": sha(b), "mutant_sha256": sha(current[f].encode())}
    json.dump(rec, open(os.path.join(d, "record.json"), "w"), indent=1)
    for f, text in created:
        p = os.path.join(TREE, f)
        parent, made = os.path.dirname(p), []
        while not os.path.exists(parent):
            made.append(parent)
            parent = os.path.dirname(parent)
        for m in reversed(made):
            os.mkdir(m)
            rec["dirs"].append(m)
        with open(p, "x") as fh:
            fh.write(text)
        rec["created"].append({"file": f, "sha256": sha(text.encode())})
        json.dump(rec, open(os.path.join(d, "record.json"), "w"), indent=1)
    for f, s in current.items():
        open(os.path.join(TREE, f), "w").write(s)
    json.dump(rec, open(os.path.join(d, "record.json"), "w"), indent=1)
    print(f"applied {name}: edited {sorted(rec['edited'])}, created {[c['file'] for c in rec['created']]}")


def revert(name):
    d = os.path.join(SAVE, name)
    rec = json.load(open(os.path.join(d, "record.json")))
    for f, e in rec["edited"].items():
        b = open(os.path.join(d, e["orig"]), "rb").read()
        assert sha(b) == e["sha256"], f"{name}: the saved original of {f} is damaged"
        open(os.path.join(TREE, f), "wb").write(b)
        assert sha(open(os.path.join(TREE, f), "rb").read()) == e["sha256"], f"{name}: {f} not restored"
    for c in rec["created"]:
        os.remove(os.path.join(TREE, c["file"]))
    for m in reversed(rec["dirs"]):
        os.rmdir(m)
    os.rename(os.path.join(d, "record.json"), os.path.join(d, "record.json.reverted"))
    print(f"reverted {name}: restored {sorted(rec['edited'])}, removed {[c['file'] for c in rec['created']]} and {len(rec['dirs'])} dir(s)")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        print(" ".join(MUTANTS))
        return
    if cmd not in ("apply", "revert", "describe") or len(sys.argv) != 3 or sys.argv[2] not in MUTANTS:
        sys.exit(__doc__)
    name = sys.argv[2]
    if cmd == "describe":
        for op in MUTANTS[name]:
            print(op[0], op[1])
            print("  " + (op[3] if op[0] == "edit" else op[2]).replace("\n", "\n  "))
    elif cmd == "apply":
        apply(name)
    else:
        revert(name)


if __name__ == "__main__":
    main()
