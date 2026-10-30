# Privacy gate round 24: the gate's tools re-pinned to token rounds 18, 19 and 19b (tools v24)

Gate lane, 2026-10-30, 15:34–16:15 UTC (times from `date -u`). **Not a privacy acceptance.** Draft v3 of the
classifier statement was not edited.

## In plain words

* **Two of the 72 source files a classifier capture pins changed between token rounds 17 and 19b.** One is a
  re-exported function name (`src/private_block.rs`, round 18's batch command). The other is where the verifier
  looks for the 7.7 GB Shieldstral checkpoint (`tied_tables/derive.rs`, round 19's "E7"; round 19b added only
  comments and tests). No other pinned file moved, and no byte of a proof, a statement or a capture moves with
  these two. I checked this from the frozen trees, not from the token lane's notes.
* **Tools v24 now read those two files.** Each new version of each file has a written reading that chains back to
  the version the gate read before. The gate's copy of the checkpoint rule now follows E7 exactly, including
  Rust's refusal of an empty declared path, which v23 got wrong.
* **The checks pass with the new pins and fail with the old.** The old tools (v23) refuse every r18, r19 and
  r19b capture by name, on exactly those two files. The new tools accept them, and still refuse an r14 capture.
* **A real capture made by the r19b release binary passes the whole v24 gate.** It is a small one, at the
  classifier rung: the named binary proved and verified a run, and the CLI's own door re-verified it with the
  recorder attached. v24: PASS, no declared limit, every part true, every control that applies fired. v23 on the
  same capture: refused by name.
* **Not shown here:** a real Shieldstral-size capture made by an r18 / r19 / r19b binary, and anything about the
  batch command (`prove-batch`) beyond the code reading. See §6 for what a v4 of the statement would need.

## 1. What moved, r17 → r18 → r19 → r19b [MEASURED: `READINGS_R24.json`, `8cc99202…`]

All five frozen trees re-hash to their manifests (r16b 301, r17 303, r18 306, r19 306, r19b 306 files; none moved,
no unlisted file). r17 → r19b moves 10 paths. The recorder's three pin lists (38 + 29 + 5 = 72) are the same in
r17, r18, r19 and r19b.

| What the gate pins | r17 | r18 | r19 | r19b | Where in the gate |
|---|---|---|---|---|---|
| `src/private_block.rs` (capture pin) | `2af1df7d` | **`96c1cd16`** | `96c1cd16` | `96c1cd16` | r13_pins `PRIVATE_BLOCK_T16` (the r16b link, kept) → new `PRIVATE_BLOCK_T18` |
| `src/private_block/tied_tables/derive.rs` (capture pin) | `c5bec3c6` | `c5bec3c6` | **`4b53222b`** | **`1d615010`** | r13_pins `DERIVE_T16` (:206, the r16b link, kept) → new `DERIVE_T19`, `DERIVE_T19B` |
| derive.rs's location rule, mirrored | absolute `DEFAULT_CHECKPOINT` | same | E7 | E7 | classtied `SHIELD_DEFAULT_CHECKPOINT` (v23 :334, used :414) → `shield_checkpoint_path` |
| derive.rs's line citations | — | — | — | — | classtied's READ comment (v23 :303) and two docstrings (v23 :388, :498) |
| classifier CLI binary | `81bd8624` | `110f0c53` | `841ba983` | `6d65d32e` | **no tool pin** (see below) |

* `private_block.rs` r17 → r18: one line (`:142`), the `pub use` of the classifier CLI bridge names one more
  function, `classify_prove_batch_command`. No byte any capture or proof absorbs.
* `derive.rs` r18 → r19 (+97 / −3) and r19 → r19b (+136 / −0): the production text without comment lines
  differs r16b → r19b in exactly the E7 lines (3 removed, 20 added): the absolute path becomes
  `CHECKPOINT_IN_MODELS`, `default_checkpoint(_from)` and `checkpoint_path_with`, and the one call site uses
  them. `Checkpoint::open`, the size / header / whole-file SHA-256 / consumed-tensor pins, `rotate`, `quantize` and
  the margin row are unchanged. No absorb, transcript or BLAKE3; `Sha256::new(` 5 → 5. r19b adds only `///`
  text and two `#[cfg(test)]` tests.
* **The CLI binary is not a tool pin.** No frozen v23 tool names any classifier binary digest. A CLI-path
  capture records its binary in its README note; the draft and the round records name binaries. So nothing in
  the tools "moves" with it. v24 adds a report-only table of the five binaries (`TOKEN_CLI_BINARIES`, each
  re-hashed against `cli/binaries_r*.sha256`) and `capture_cli_binary()`, which reads a capture's README. It is
  never part of a pass / refuse decision.
* **Nothing else the gate consults moved.** Of every pin table the v23 gate consults (the block port's
  `PORTED_FROM` / `ALSO_ACCEPTED` / `PINNED_IF_PRESENT`, the classifier port's five digests, r13_pins'
  terminal table, the r17 and H19 readings), only r13_pins' `TOKEN_R16B_DIGESTS` names a moved file, and only
  these two. `classify_cli.rs` and `examples/zk60_classify.rs` moved but are not capture pins (they appear only in
  v19 / v21 report-only lists). `classify_cli::door`, which the gate's CLI-path captures go through, is byte-equal
  r17 vs r19b, and so is everything from `door` to the end of that file once comment lines are dropped.

## 2. Tools v24 (every change; the patches hold every changed line)

`frozen_v24/`, manifest `gate-tinyllama.tools.frozen.v24.sha256` = 80 files, **sha256
`b0532c6e9ef4998f5b25bab6d7af4fd36204cf935b12102e5442954182095efc`**. Patches: v23 → v24 scripts `c23698cd…`
(33,491 B), tests `33ba4ce3…` (13,260 B); vs original `74ea696a…`. v23 is unchanged.

* `zk60_native_rg_r13_pins.py`: module text (:82-91); `DERIVE_T16`'s comment (:206); new constants
  `PRIVATE_BLOCK_T18`, `DERIVE_T19`, `DERIVE_T19B`, `RUN_CAPTURE_T17`, the r17 / r18 / r19 / r19b trees and the r19b
  manifest's list digest (:214-228); `TOKEN_R19B_DIGESTS`, the r19b terminal table (:263); `TOKEN_R19B_READINGS`
  with its three readings (:585-637); `_all_readings` includes them (:767); `self_check` chains the r19b terminals
  (:808-816), re-hashes them in frozen-r19b (:829-834) and against `manifest_final_r19b` (:853-865). **`DERIVE_T16`
  and `PRIVATE_BLOCK_T16` keep their values.** In the gate's reading-chain model they are the r16b links; the
  terminal for derive.rs moves to `DERIVE_T19B` in the new terminal table. Overwriting them would break the r16b
  self-check and misname the r16b reading.
* `zk60_native_rg_classpins.py` (:803-982, appended): `TOKEN_CLI_BINARIES`; `_reading_v24` (the r19b readings
  in front of v23's); `classify_capture_pins_v24`; the dispatcher → v24 (v23's, v22's and v21's rules kept for the
  record); `_capture_pin_files` (the 72, parsed from a tree's run_capture.rs); `r19b_self_check()`;
  `capture_cli_binary()`.
* `zk60_native_rg_classtied.py`: module text (:46-53); the READ comment cites r19b's digest and lines beside
  r16b's (:311-337: `Checkpoint::open` :182-220, whole-file pin :216, consumed-tensor pin :325, `rotate`
  :223-238, `quantize` :240-247, `recompute_profile` :287-336, the path at :304); **`SHIELD_DEFAULT_CHECKPOINT`
  removed**, replaced by `SHIELD_CHECKPOINT_IN_MODELS` (:357), `shield_default_checkpoint(env)` (:364) and
  `shield_checkpoint_path(decl, env)` (:382); `_shield_stream` calls it (:475); two docstrings (:449, :559).
* `zk60_native_rg_classgate.py`: module text only (:99-106).
* `tests/test_v4_status_g10.py`: `ClassifierV23`'s port assertion now calls `classify_capture_pins_v23` by name
  (:1764; the dispatcher is v24's); new class `ClassifierV24` (8 tests, :1835-).

**The mirrored checkpoint rule** (derive.rs `1d615010` :53-70 plus `regular`):

| Case | Rust (r19b) | v23 gate | v24 gate |
|---|---|---|---|
| `checkpoint_file` declared | the declared path; the default not evaluated | same | same |
| declared but **empty** | the empty path, refused by `regular` | **used the default** | refused |
| declared, not a string (null too) | refused (`J::str`) | null → default | refused |
| none declared, `ZK60_MODELS` set and non-empty | `$ZK60_MODELS/<place>`, never HOME | the fixed path | same as Rust |
| `ZK60_MODELS` empty or unset, `HOME` set and non-empty | `$HOME/models/<place>` | the fixed path | same as Rust |
| neither set (or both empty) | refused | the fixed path | refused |
| a symlinked model file | refused (`regular`) | followed | **still followed** (not changed; both authenticate the bytes) |

Tested by `ClassifierV24.test_e7_checkpoint_rule_mirrored` (the cases of derive.rs's two E7 tests, transcribed,
plus the empty and non-string declarations) and `test_e7_rule_is_what_the_stream_opens` (at the call site: a
set `ZK60_MODELS` naming a missing file is refused there and never falls back to `HOME`, whose file exists on
this box; `ZK60_MODELS=""` falls to `HOME`; a wrong-size file there is refused by the size pin; an empty
declaration is refused before anything is opened). On this box the rule gives v23's path, a regular file of the
pinned 7,698,241,104 B.

## 3. The checks that read the token tree, re-run [MEASURED: `PIN_CENSUS_R24.json`, `3b815b3d…`]

With frozen v24, and frozen v23 as the control, each in its own process:

| Check | v24 (new pins) | v23 (old pins) |
|---|---|---|
| capture pin rule on the 72 pins of frozen-r17 | accepted | accepted |
| … of frozen-r18 | accepted | **refused**: private_block.rs |
| … of frozen-r19 / r19b | accepted | **refused**: private_block.rs `96c1cd16`, derive.rs `4b53222b` / `1d615010` |
| on the captures on disk: r19b P-18 / r17 real / r16b real / r14 short | ok / ok / ok / refused | **refused** / ok / ok / refused |
| r13_pins self-check | ok, 155 digests re-hashed (incl. the r19b terminals) | ok at r16b, 119 |
| r17 self-check / r19b self-check | ok / ok | ok / — |

Controls inside v24: with the round-24 readings removed, the rule refuses r19b by name and the r19b self-check
fails on both files; with derive.rs's r19b terminal set back to `DERIVE_T16`, the r13 self-check fails. Both
fire.

The census (round 22's C-R1 census of unkeyed BLAKE3 inputs, re-checked at r19b): 12 of the 13 sites' files are
unchanged r17 → r19b; the 13th (`BlockPublic::digest`, private_block.rs :880-893) has its file moved but those
lines are equal. The changed production files (private_block.rs, derive.rs, classify_cli.rs,
examples/zk60_classify.rs, the new classify_batch.rs and classify_batch_plan.rs) add no BLAKE3, hasher, absorb,
squeeze, transcript, generator or SHA-256 token; the two batch files contain none at all. A planted BLAKE3 call
in a copy is seen.

Suites: **111 OK** (v23's 103 + 8 new) in frozen v24 (60.7 s, 0.43 GiB), in staging, and in the gate's working
copy after v24 was installed there (80 / 0 / 0; 60.7 s, 0.47 GiB).

## 4. The real check: a capture made by the r19b binary [MEASURED, shared box, n = 1]

**Why this one.** It is the cheapest capture that a release binary of r19b itself makes. The P-18 hook in
frozen-r19b (`capture_the_classify_cli_verify_path`) runs the named binary's `prove` and `verify` as separate
processes at the classifier rung, then reads the run directory through the CLI's own door and verifies it with
the recorder attached. A Shieldstral-size capture would need a real prove (about 8 minutes and 8 GiB per
category, REVIEW_R18) and a 7.7 GB checkpoint stream.
The R13 rung capture (H19-1) is made in-process by the test build, not by the release binary; it would carry the
same 72 pins, and no production block file moved, so it would add nothing to the re-pin question.

* The gate's copy `capture-tree-r19b` = frozen-r19b, 306 / 306 files, no `target/` copied.
* Test build: `gate24-build-tests`, build 2.9 / 3.5 GiB, 188 s, peak RSS 2.37 GiB (cgroup 2.82).
* Capture: `gate24-cap-p18-r19b`, cpu 1.0 / 2.0, 2.9 s, 0.21 GiB. The binary
  `cli/zk60_classify.r19b.release.bin` re-hashed to `6d65d32e…` first. CLI prove 1.7 s, CLI verify 0.3 s,
  recorded verify 0.4 s. Bundle `classify-rc3-cli-p18-r19b-gate24`: schema `7-classify-run`, profile
  `…rung-tc-t32-public-row-dev/1`, one block, 72 source pins, 20.3 MB; the README names the r19b binary by path
  and SHA-256.
* **Frozen v24's whole classifier gate on it: status PASS, no declared limit, 0 false parts, 0 unfired controls**
  (light 0.8 / 2.0, 289 s, 0.27 GiB). Integrity with 72 pins; the replay reproduces the run binding (4,224
  challenges, 203 positions); per-commitment, mask / CFS and joint views ok; 12 / 12 classifier slots with 19 public
  tables rebuilt and none taken; NL-1; B-3; the one public bit; D41; the block stage 23 / 23 slots; the full
  zero-data preimage over 952,463 view entries, 0 differing, 2,304 salted leaves authenticated; the joint
  preimage; controls CC-1..CC-6, CC-8 / CC-9, C13-2..C13-4, J-1..J-3 fire, C13-1 not applicable (a full-length item
  has no pad position). A dev run with the staging copy gave the same (300 s).
* **Frozen v23's whole gate on it: REFUSED by source pins, exit 3, in 0.7 s** — the two pins by name, nothing else
  evaluated.
* The capture (21.3 MB, 7 files) and the build output (63.5 MB) were then deleted (D46). Kept: the capture's
  manifest and README, every file's SHA-256 re-checked against its manifest, and the gate records
  (`CAPTURE_P18_R19B.json`, `CLEANUP.json`). The tree `capture-tree-r19b` (sources only) stays for a re-capture.

## 5. Not done, and notes

* No real Shieldstral T128 capture by an r18 / r19 / r19b binary. Its cost: one prove with the r19b binary
  (about 8 min and 8.2 GiB peak per category, an 848 MB receipt: REVIEW_R18), a test build of `capture-tree-r19b` (~3 min, 2.4 GiB), the H19-2 recorded
  verify through the door (one 7.7 GB checkpoint stream; a 2.4 GB values bundle), then the gate (round 20's full run
  4 h at 6.5 GiB; the NL-1 style run 12 min at ~3 GiB).
* No capture of the batch path. `prove-batch` at the rung is not possible: production builds the batch `Spec`
  for `SHIELD_T128` only (REVIEW_R18 N-6). A batch job's receipt is verified by the unchanged verifier, so a
  door capture of one batch job's run directory would be an ordinary H19-2 capture of a Shieldstral run (the cost
  above; a batch of three jobs took 1,418 s).
* N24-1: the gate's checkpoint stream still follows a symlinked model file, which Rust refuses. Both
  authenticate the bytes (size, whole-file SHA-256, consumed tensor), so this is not a soundness or privacy point;
  left for a later round.
* N24-2: v24's legacy-rung path (the classifier rung, not R13) had last run in v21; it holds on an r19b capture.

## 6. What a v4 of the classifier statement would need to cover r18 / r19b

Draft v3 names the r16b (`dfb8025e…`) and r17 (`81bd8624…`) binaries, frozen-r16b / r17, and the 72 pins under the
v23 rule, and puts `prove-batch` and every r18 binary outside it (§1, §6, §8, §9). A v4 would need:

1. **The binaries and trees by name.** `cli/zk60_classify.r18.release.bin` `110f0c53…` (frozen-r18, list
   `1ca1b2d7…`), `r19` `841ba983…` (frozen-r19, `91585afe…`), `r19b` `6d65d32e…` (frozen-r19b, `cfae2d1e…`). Or
   name only r19b, the reviewed tip.
2. **The pins.** The 72 under the v24 rule, with this round's readings (private_block.rs `96c1cd16`, derive.rs
   `1d615010`), tools v24 `b0532c6e…`; condition 7 / lapse rows updated.
3. **Why the real-shape evidence carries.** Round 20's real capture and rounds 21–23's results came from the r17
   bundle. Carrying them to r19b receipts rests on two things: the reading here (no production byte on the prove
   or verify path moved r17 → r19b, only a re-export, E7's file location, the new batch files and doc text), and
   the token lane's byte-identity point (r19b's job-0 receipt equals r18's and r16b's on 30 / 30 files under fixed
   entropy; one input point, n = 1). Or a real r19b capture (§5).
4. **E7 as an operating rule.** The verifier reads the checkpoint at the declared `checkpoint_file`, else
   `$ZK60_MODELS/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors`, else the same under `$HOME/models/`,
   else refuses; a symlinked model file is refused; `O_NOFOLLOW` only on Linux x86-64 (REVIEW_R19B N-6). The
   bytes are authenticated wherever they are read from, so this moves no privacy term.
5. **The batch path, if `prove-batch` is to be covered** (v3 §6 lists what naming it needs):
   * the §2 corollary's hypothesis 1 read for several runs in one process: each job's own two OS-entropy draws,
     its own seal, transcript and readers, everything shared lent read-only (REVIEW_R18 §2); the fixed-entropy
     evidence (each job reads exactly its 64 B, nothing unread, the reused-draw mutant killed); J = all the jobs of
     the post (up to 22 at T128);
   * A5 fixes 1 and 2 adopted (r18, reviewed) and the census reading the batch files (done in r18 / r19 / r19b;
     this round's census finds no hash or generator token in them);
   * **R18-1, still open: the app's batch path through the terminal collector, quarantine of any unfinished
     batch before a retry, and that `.batch-quarantine/` is never published** (release builds abort on panic, so a
     crash leaves finished-looking receipts of a failed post; publishing them would show which category failed,
     against rule R1). It needs its own review of Astra's app half; Astra's ledger keeps native r18 unadopted
     until then;
   * the D46 operating rule for a large post (a 22-job batch writes ~18.7 GB: announce, size `--max-secs`).
6. **Which binary made each piece of evidence** (v3 already lists this for r16b / r17): add this round's r19b
   P-18 rung capture and the token lane's r19b checks.

## 7. Evidence

| What | Path | sha256 |
|---|---|---|
| readings (trees, pins, diffs, door, binaries) | `round24/READINGS_R24.json`, `round24/readings/*.diff` | `8cc99202…` |
| pin and census checks, official | `round24/PIN_CENSUS_R24.json` | `3b815b3d…` |
| the capture tree copy | `round24/COPY_TREE.json` | `6c3abaa8…` |
| build / capture logs and guard records | `round24/logs/build.*`, `round24/logs/capture.*` | |
| v24 gate on the r19b capture | `round24/v24/v24-classify-rc3-cli-p18-r19b-gate24.json` | `274c8a37…` |
| v23 gate on it (control) | `round24/ff/ff-v23-classify-rc3-cli-p18-r19b-gate24.json` | `f394efda…` |
| capture record (manifest, README, file hashes) | `round24/CAPTURE_P18_R19B.json`, `round24/capture_p18_r19b/` | `c5f0a597…` (capture manifest `55c49aaa…`) |
| clean-up | `round24/CLEANUP.json` | `0510f749…` |
| tools v24 | `ops/zkp-mvp/gate-tinyllama/frozen_v24/`, `gate-tinyllama.tools.frozen.v24.sha256` | `b0532c6e…` |
| scripts | `round24/{readings,copy_tree,lean_check,pin_census,freeze_v24,r24_install_wc,record_and_clean}.py`, `r24_capture.sh`, `r24_official.sh` | |
