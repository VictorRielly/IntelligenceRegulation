# Build check of the installed-profile Lean branch (`agy/lean-w16r2-shield` at `dd255855e`)

Definition (posted and pushed before the run): `ops/zkp-mvp/RECOVERY_COORDINATION.md`, entry of 2026-11-25T23:51:52Z; the pass
rule is in the docstring of `run_check.py`.

- **What was built:** a private copy of `dd255855e:formal`, with build products cloned from the coordinator's own full build of
  the merged tree of Nov 25 (guard run `4d7436f61c9f`). Against that tree the branch adds 18 files (17 Lean modules and
  `verify_export_u1.py`) and changes none. The root file does not import the new modules, so the module that imports all the
  others (`BlockW16U1Done`) was built by name.
- **Result, `check1` (guard run `e0002060be37`, 51 s, peak 13.61 GiB): GREEN by the posted rule.** Root build: exit 0, nothing
  rebuilt. `lake build ZK60Formal.BlockW16U1Done`: exit 0, no error line, no warning; 17 of 17 modules built (2.0 to 11 s each)
  and 17 of 17 fresh `.olean` files. Axiom report, six of six names, each on `propext`, `Classical.choice`, `Quot.sound` only:
  `shieldU1_circuitIff`, `shieldU1_circuitIff_policy`, `shieldU1_run_exists`, `block_knowledge_alg_w16r2_shield_lk26`,
  `block_knowledge_define_alg_w16r2_shieldU1`, `block_knowledge_w16r2_shieldU1`.
- **Source scan:** the word sorry occurs once in the header comment of each file and never in code; no `axiom`, `native_decide`,
  `unsafe`, `implemented_by`, `opaque`, `maxHeartbeats`, `maxRecDepth`.
- **What this does not say:** that the statements are the right ones for the installed profile. The last theorem is a
  single-block statement with premises left for the run level (`BlockW16U1Done.lean:59-97`: that the verifier is the code's block
  verifier, an assumed bound on the endpoint event, and run-level items); the file's header lists them. An independent read has
  not been done.
- **Root step, `root1` (guard run `bc445d6747f2`, 7 s, peak 3.83 GiB; rule in the docstring of `run_check.py`, posted before the run): GREEN.**
  The author had not answered two requests for the root imports, so the coordinator added the 17 import lines to the root file
  in the private copy, at its end, in dependency order. `lake build ZK60Formal`: exit 0, no error line, only the root rebuilt,
  none of the 17 modules rebuilt. The six axiom reports come out through the root import alone, on the three standard axioms.
- **Merged** as `cb58d6b12` (merge of `dd255855e`, 18 files added, nothing else changed), followed by one commit that adds the
  same 17 lines to `formal/ZK60Formal.lean`; the root file and the 17 sources in the repository are byte-identical to the
  private copy that was built.
- **Independent read:** `results/zk60_claude_review_20261116/W16U1_READ_20261126.md` (about 2,700 of 9,623 lines; no High finding).
