# Independent adversarial privacy review, round 5: D33's re-pin onto frozen-r9, and the next-token statement draft v2

Reviewer: the same independent Claude Opus 5.5 agent as rounds 1–4. I did not
write the re-pin note, the draft, the gate tools, or the native or token code.
- Written 2026-10-20 05:22–05:30 UTC.
- Paper only, plus short read-only `python3 -I` checks: no builds, proofs,
  git writes or jobs.
- The ledger is `PROGRESS.md`, section ROUND 5.
- To avoid a name clash, the token tree's code reviews are called **token
  REVIEW5 / REVIEW6** here (`results/zk60_token_io_review_r1_20261017/`).

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's.

**Objects** (hashes checked):
- (A) `results/zk60_gate_tinyllama_20261017/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md`
  (`c4d88df1…`);
- (B) `results/zk60_gate_tinyllama_20261017/round11/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT_v2.md`
  (`34562422…`);
- frozen-r9: `results/zk60_token_io_r1_20261017/frozen-r9/` (236 files,
  `b666a991…`).

---

## 0. Verdicts, in plain words

**(A) The frozen-r9 re-pin: YES.** It meets D33's condition 7 on the same
footing as the tk7 note I accepted in round 4.
- Exactly one block-path file moved, `run.rs`. Its two hunks add two
  token-profile strings and their shape arms, which D33's profile can never
  select.
- Both hashes are kept, and frozen v14 refuses the new digest first.
- The ten records equal tk7's in every deterministic figure, which I
  re-compared.
- The tk9 trained-block CLI publishes R7's identity, with only the fresh
  endpoint roots different.

The decision must name what it names, as PR4-1 did (PR5-1).

**(B) The next-token draft v2: READY for the security owner and Victor.**
Every item of my round-4 closed list (PR4-12) is closed, by code, measurement
or a register ruling, and I re-checked the load-bearing ones in the source:
- **F-T1 is closed by code.** Both production callers now seal before the
  run header. The CLI's `seal_chain` builds each block with the witness
  builder, checks int16 range, parity and CS-3, and takes the next token from
  the builder's last plane. The switch that could skip this is the constant
  `false` outside test builds.
- **F-T2** is priced by **D34**, and D34's premises still hold in frozen-r9.
- **The evidence D33 required is now measured:**
  - the surjection on the new slots (PR4-7);
  - the root-rebuild replay of the token stages, on frozen-r7 and frozen-r9
    code with equal byte counts (PR4-8);
  - the b4 calibration attribution, plus **D35** (PR4-9);
  - a named binary, with a CLI-path capture on frozen-r9 pins (PR4-10).
- **The deployment items PR4-15/16/17 are built.**
- **Token REVIEW6** finds frozen-r9 demo-fit: LOW / INFO only, nothing
  affecting soundness or leaking.

**The frozen-r7 → frozen-r9 carry of the ten harness captures suffices
without the re-capture (PR5-4).** The proving path after the header is
frozen-r7's line for line, so no receipt byte or draw moves.

**The decision should record four things (PR5-3):**
- the pins and the binary;
- D34 and D35;
- D29's extension to token runs;
- that the harness figures are carried.

The rest is wording (PR5-5..PR5-8).

---

## 1. (A) The re-pin onto frozen-r9

### 1.1 Checked

- **The changed set** [checked by me]. Against frozen-r7, frozen-r9 changes
  12 files and adds 3; `diff -rq` lists them.
  - Exactly one is on the block or run path: `private_block/run.rs`.
  - The rest are `token_io*` and `examples/zk60_token_io.rs`.
  - `protocol.rs`, `trained_block.rs`, `shape.rs`, `trained_statement.rs`,
    `private_block.rs` and all of `zkp-core` are unchanged.
- **The `run.rs` hunks** [read by me]:
  - two `pub(crate) const` token profile strings (T128 TinyLlama and 8B);
  - `TOKEN_IO_RUN_PROFILES` grown from 3 to 5 entries;
  - two `run_shape` arms keyed by those strings.
  - D33's profile is matched by string equality and selects the arm it
    selected before. The registry is read only to refuse token profiles in a
    blocks-only statement, and to require one in a token run. Nothing D33
    absorbs or proves moves.
- **Pins.**
  - Frozen v14 refuses `run.rs` `cc2c4204` by name and suspends all 13
    stages (`probe_before_repin/`).
  - v15 adds the reading and keeps every earlier digest. frozen_v15 equals
    its manifest (65 of 65, checked), and the queues ran under it.
  - The second toolcheck line (64) is v14's check for the probe.
- **The gate re-run.** 10 of 10 tk9 records PASS, with 0 unexplained leaves.
  - My own comparison against `tk7-summary.json`: no difference in replay
    counts, hash counts, terminal identity (23 / 46 / 506), channels, mask
    entries, joint couplings, preimage leaves, or export and stage verdicts.
  - The L22 identity `68ad19c8…` is recomputed.
- **Stage 47.** The five block replays pass on tk9. The token replays also
  pass on the r9 code, with byte counts equal to tk7's.
- **The CLI.**
  - `zk60_trained_block.tk9.release.bin` = `911e82f0…` (checked).
  - `stack-prove` sealed before the header; a fresh `stack-verify` published
    the statement.
  - The published `statement.json` against tk7's: 52 leaves each, and **only
    `/expected_io` differs**, the fresh endpoint roots (checked).

### 1.2 Findings on (A)

- **PR5-1 (the lift decision must name):**
  - **frozen-r9's 52 pins**, keeping the R7 and tk7 readings;
  - **the trained-block CPU binary `911e82f0…`**. It was built in the gate
    copy's path, so the statement names these bytes, or a lane-built binary
    named by digest;
  - **the two carries by reading**, as in the tk7 decision: P-18's capture
    and gate, and the 22-block pass F.

  If the frozen-r7 lift (round 4, YES) has not yet been ruled, it can be
  folded into this one. frozen-r9 differs from frozen-r7 on the block path
  only by the inert `run.rs` hunks.
- **PR5-2 (optional).** Capture and gate the existing
  `~/zk60-artifacts/tinyllama-cli-tk9-run-l2/`, as PR4-2 suggested for tk7.

---

## 2. (B) The next-token draft v2

### 2.1 The round-4 closed list (PR4-12), item by item

| Item | Where the draft says it landed | What I checked | State |
|---|---|---|---|
| **PR4-4** (seal before the header; the CLI path described) | frozen-r9; §2 "Admissible", §3 step 4; T-5 | **Generic prover** (`token_io/run.rs` diff r7→r9): `src.stage_in()` moved ahead of `ZkRng::from_os` and the header. Then, before either: stage IN's `lookup_misses` (new in `stage_in.rs`: ids < V, BOS, B_in rows = embedding rows, zero pads, m = histogram); both endpoint planes compared with the witnesses; per-block CS-3 through `seal_check`; stage OUT's byte check. **CLI** (`cli.rs` `seal_chain`): for each block, at its stage shape, `build_shaped` from the builder's own chain, the int16 range, parity against the export, `check_lookup_misses`. The next token comes from the builder's last plane (`cli.rs:648-658`). `cheating` is the constant `false` under `#[cfg(not(test))]` (`run.rs:734-736`) | **closed by code** |
| **PR4-5** (price the refusal) | **D34** | D34's premises hold in frozen-r9: the stage IN / OUT inversion code is unchanged r7→r9 (the `stage_in.rs` diff adds only `lookup_misses`); no retry; no position tag | **closed by ruling** |
| **PR4-7** (NL-1 S3–S5, the surjection on the 15 new slots) | round 10 | `round10/nl/nl-tinyllama-*.json` all PASS (L = 1, 2, 22, both prompts). `round10/ts/*`: the summaries match the draft's table (A_in 3/3, 0; H_in 3/4, 2 on joint {2, 3}; …) | **closed** |
| **PR4-8** (stage-47 replay of the token stages) | round 10, and tk9 | `round10/r10-l*` (r7 code) and `tk9/tok-l*` (r9 code): all PASS, "consumed exactly the predicted" 54,185,024 (L = 1) and 93,648,512 (L = 2) bytes on both | **closed** |
| **PR4-9** (b4 attribution; carried block controls) | round 10 (`v16-cal-all.json`), **D35** | The attribution record is PASS on 10 captures. D35 records the carry with lapse conditions | **closed** |
| **PR4-10** (named binary; one CLI-path capture) | b56f1b71…; `…-cli-r9` | `round10/cli9/v14-tokengate-cli9.json`: status PASS, no false parts, no unfired controls. v12 refused it first. The freeze note names the binary and the capture | **closed** |
| **PR4-15** (loud removal; leftovers) | frozen-r9 `cli.rs` | `leftover_refusal` refuses by name; `REMOVAL-FAILED` is printed loudly (`cli.rs:533-589`) | **closed by code** (plus the §6 rule) |
| **PR4-16** (the owner base) | frozen-r9 | `OWNER_BASE = "zk60-owner-private"` (`cli.rs:476`), outside the artifacts tree. The base's mode must be checked by the operator if it already existed (TR7-7, §6) | **closed** (plus the rule) |
| **PR4-17** (the prompt and token off command lines) | frozen-r9 | `--prompt` is refused (`cli.rs:318, 403`); `--prompt-file` must be a regular file of mode 0600 or 0400, or stdin; `owner` prints the token only with `--print` | **closed** |
| PR4-11 (the token tree's review) | token REVIEW5 / REVIEW6 | REVIEW6, on frozen-r9: "yes, frozen-r9 is demo-fit"; LOW / INFO only (TR7-1..7) | **closed** |
| PR4-6, 13, 14, 17 (wording) | §0, §2, §3, §4, §6 | Present | **closed** |

### 2.2 Does the carry of the harness captures suffice without the re-capture?

**Yes.** Four reasons:
1. **No published byte or draw of a T32 token receipt moves between the
   trees.**
   - Everything after the header in `prove_token_run_with` is frozen-r7's
     line for line. The diff only moves the `stage_in()` call earlier and
     adds checks before the generator exists.
   - `stage_in.rs`'s inversion and commitment code is unchanged.
   - The token stage-47 replays consume identical byte counts on r7 and r9
     code.
2. **A receipt made by the named frozen-r9 binary has passed the full token
   gate** (the CLI capture, L = 2): preimage, joint, terminals, NL-1 and
   controls.
3. **The precedent allows it.** The D22 re-pin at `4751b93` lifted its
   suspension on the old captures plus a reading. D33 carries its 22-block
   pass F the same way.
4. **Token REVIEW6** read the r7→r9 changes and confirms the claims I rely
   on.

**PR5-4.** The decision records that the ten harness figures are carried
from frozen-r7 by reading. The gate's re-capture on frozen-r9 would then
replace carried figures with measured ones. If it disagrees on any
randomness-free figure, the carry, and the decision resting on it, lapse.

### 2.3 Findings on (B)

- **PR5-3 (the decision's content).** The security owner's decision names:
  - frozen-r9's 52 pins;
  - the binary `b56f1b71…`;
  - D34 and D35;
  - **D29's extension to token runs.** T-5 now holds by code at both
    callers, which I read, so D29's reading transfers. The census is a
    completeness item for token runs too;
  - the carry (PR5-4).
- **PR5-5 (wording / scope): which trained-model identities are covered.**
  - The token CLI has no `--layers` option. The L = 2 CLI capture used a
    **view** of the export, with `profile.json`'s layer list cut to 2
    (identity `0f4cef3e…`, calibration word `45ce7431…`). Its block files and
    constants are the export's.
  - §1 should say which identities the sentence admits for L < 22: either
    list them, or admit any layer-cut view whose block files and constants
    equal the export's.
  - Such a view is a public file derived from the export, so P-4 applies to
    it: it must be made before, and independently of, any input.
- **PR5-6 (wording): T-5's scope.** T-5 ("every input-provokable refusal
  precedes the header") holds for the five in-tree witness sources, each of
  which calls `seal_check` (TR7-5). Add to §9: "a new witness source that
  skips `seal_check`". `prove_core` would still refuse a miss, but after the
  header.
- **PR5-7 (operating).**
  - **TR7-3:** the demo's decode helper takes the answer id on its command
    line. It is outside the named binary, and the token lane is fixing it.
    No demo on a real (non-public) prompt until it is fixed.
  - **Delivery to the owners is not implemented**, so both decommitments sit
    together on the prover host. Already in §6; keep it visible in the
    decision.
- **PR5-8 (wording).** §1 "Code" and §5 condition 7 split the 52 pins as
  40 + 6 + 6. The tk9 note splits the same 52 as 46 unchanged + 6 moved.
  These agree; one sentence saying so would help a reader.

### 2.4 Unchanged from round 4, re-confirmed

- **The residuals**: 2^-74.43 / 2^-73.62 / 2^-70.35, with the refusal term
  2^-116.96 / 2^-116.17 / 2^-112.93. frozen-r9 changes no draw, as the
  stage-47 byte counts show.
- **The token endpoint's rank lemma, and C-R1 / C-R2** for the token
  absorbs.
- **The τ / head-fold reading.** Not a privacy gap. Attribution is now
  measured (PR4-9).

---

## 3. Evidence (this round)

**(A)**
- `EV/tk9/` (`tk9-summary.json`, `probe_before_repin/`, `gr4-*.log`,
  `tok-*.log`, the `*.toolcheck` files).
- `EV/tk7/tk7-summary.json`.
- `EV/gate-tinyllama.tools.frozen.v15.sha256` against `frozen_v15/` (65 of
  65).
- `diff -rq` of frozen-r7 against frozen-r9, and the `run.rs` diff.
- `~/zk60-artifacts/tinyllama-cli-{tk7,tk9}-run-l2/statement/statement.json`.
- The digest of the tk9 binary.

**(B)**
- The draft v2.
- Register D29, D34, D35.
- `frozen-r9.FROZEN.txt`.
- The diffs r7→r9 of `token_io/run.rs` and `token_io/stage_in.rs`.
- frozen-r9 `token_io/cli.rs` (`seal_chain`, `prompt_of`, `OWNER_BASE`,
  `leftover_refusal`, `REMOVAL-FAILED`) and `token_io/run.rs:730-740`.
- `EV/round10/{nl,ts,cal,cli9}/`, `EV/round10/r10-l*.log`,
  `EV/tk9/tok-l*.log`.
- Token REVIEW5 and REVIEW6 (verdict sections).
