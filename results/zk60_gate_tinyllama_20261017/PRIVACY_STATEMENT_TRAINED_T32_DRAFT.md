# Privacy statement for the trained TinyLlama-1.1B T32 profile — DRAFT (not in force)

Drafted 2026-10-17, from about 12:50 UTC, by the PRIVACY GATE lane (a
delegated Claude Opus 5.5 agent). It follows the form of
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` (register D22).
**Revised in round 3 (18:50-21:10 UTC):** the 22-block all-zero run and the
22-block arms (both inputs) are now measured; Victor accepted D19b and D23
(19:28 UTC); G-10 is repaired (tools v4); G-11 is added;
the native lane's port of the CS rulings is read; §10 now says, item by item,
what is closed by evidence and what remains.
**Revised in round 4 (21:35-22:xx UTC), after the independent adversarial
review** (`results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`,
21:06-21:28 UTC; findings P-1 to P-22). Every finding is folded in. §3b maps
each finding to where it landed. The gate's own findings (P-2, P-9, P-10,
P-11, P-20, P-21) are repaired in tools v5. P-1 belongs to the native lane
(a new freeze, R5b), and P-12 is being ported. The review is one reader plus
three helpers, not a ruling.

| Status | **DRAFT, for the security owner. NOT a privacy acceptance, and nothing on this page establishes a privacy property.** It proposes a sentence and lists what that sentence would rest on, what changes at the trained layout, what has been measured at that layout, and what is still owed. Every step of it carries the same caveat as D22's: the arguments it leans on were drafted, attacked and ruled for the TOY and for the 125M development shape. Each was re-read here **for the trained layout by me, and then once more by an independent reviewer** (REVIEW.md §2: each step goes through with the trained numbers; every residual of §4 reproduced). That is one attack per step, not a drafter / checker / ruling cycle. The reviewer's verdict is **"not yet"**: two blockers, one of which (P-2) is now repaired. D22 still covers only the toy block. |
|---|---|

**Labels.** [MEASURED] means a run happened and a record is cited.
[COUNTED] means arithmetic from the code and the shape. [ARGUED] means a drafted
argument that survived one independent attack, as its disposition rules.
[READ] means a fact read in a cited source line or document. **[MINE]** means
my own reading or arithmetic for this page, checked by nobody. The evidence is
in `results/zk60_gate_tinyllama_20261017/` (called **EV** below); its ledger
is `EV/PROGRESS.md`.

## 0. In plain words

- **What would be claimed.** A verifier who receives a verified private run
  of trained TinyLlama blocks at 32 tokens learns, from its bytes, nothing
  about the hidden input, the hidden output, the hidden activations or the
  hidden planes between blocks. "Nothing" here means beyond a distance of
  about 2^-70 per 22-block run. The claim holds in the model Victor accepted
  for the toy (D19, D20, D21), plus D19b, which he accepted at 19:28 UTC on
  2026-10-17 (register). **For an admissible input** (the CLI's admission
  predicate, §2), whether the prover refuses depends on the input only
  through a residual of about 2^-113. An inadmissible input IS refused, and
  that refusal fact is outside the statement (P-8).
- **What has been measured at this shape.** The privacy gate's whole set of
  linear checks was run on real receipts:
  - two-block runs, on a real held-out input and on the all-zero input;
  - one-block runs, on both;
  - the full 22-block stack, on the real input AND on the all-zero input
    (which proves and verifies as one bound run): the per-commitment and
    whole-run figures, the masking layer with its controls on both, and the
    full zero-data preimage and joint assignment of every commitment of the
    run (all-zero input: 0 of 25,005,697 entries differing; real input: 0 of
    24,976,715). In the same real-input pass the control families P, M, X,
    C, CH and M9-1/2 fired; CH-6 was skipped by name. The record is ok
    true. CT, GQ and M9-3 did not run at L = 22 (P-17).

  Every figure came out as predicted beforehand, apart from eight slips of
  mine, recorded in EV (§7, G-9). None of them is a gate figure that failed.
- **What is not done.** All of these are owed before a ruling, and are listed
  in §10:
  - **P-1 (blocking, native lane).** The R5 post-port tree's `stack-prove`
    breaks ruling H-1 (endpoints sealed by the witness builder's own pass)
    and M-9 / D12b(1) (`statement/` written only after verification). A
    new freeze, R5b, will repair it. The evidence here is of tree A, which
    satisfies both rules but lacks the CS rulings (G-1). Captures resume on
    R5b.
  - The gate has to be re-run on bundles captured from R5b, with that
    tree's pins read (G-1 / G-8 as evidence).
  - **P-12:** the stage-47 root-rebuild check (G-R4) is being ported to the
    trained tree. Its result is in §3 step 4.
  - The review's conditions P-3 to P-7 are now in §5 and §6, as conditions
    and operating rules a deployment must keep. Two of them have code
    repairs owed: the run context comes from a free `--label` (C-R4), and
    the hidden input lives inside the export directory (P-5).
  - The trained code can now send tagged commitments to the GPU (G-6).
  - (D19b and D23, which were Victor's, were ACCEPTED by him at 19:28 UTC on
    2026-10-17; see `docs/zkmatrix-poc/ZK60_DECISIONS.md`. That is not a privacy acceptance.)
  - The independent review is in (REVIEW.md). It is one attack, not a
    ruling, and its must-fix items are folded in (§3b).

## 1. Scope — what a statement would cover

| | |
|---|---|
| Block profile | `hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1` (`shape.rs` `TINYLLAMA_T32_TRAINED_PROFILE`) |
| Run profile | `hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1` (`run.rs` `RUN_PROFILE_TINYLLAMA_T32_TRAINED`) |
| Shape | 32 tokens; width 2048; hidden 5632 (padded to 8192); 32 query heads of 64 over 4 key-value heads. Rows 2^12 wide at rate 1/4, 256 opened columns. Endpoints have 21 rows (16 data + 5); a boundary has 22. Per stage, A has 1,729 rows (1,487 data, 120 claims, 36 groups) and H has 1,798 rows (50 claims, 9 groups) [MEASURED, every record] |
| Form | **Only a BOUND RUN.** A single-block receipt is refused at a trained-calibration profile (R2-4, `protocol::single_block_profile_allowed`). "One block" means a run with L = 1. The run header absorbs the trained-model statement's identity as its `calibration` word (`RunStatement::new_bound`) |
| Calibration | `pg_rot1_export_T32` (profile.json sha256 `b25ba5f5…`), the model at revision `fe8a4ea1`. tn 10; Cn_a 3999; Cn_m 3122; Ceps 91,255; shifts qkv 8 / score 6 / o 9 / ao 3 / gate 8 / product 14 / down 5; f_e 9. The exp and SiLU tables differ per layer (7 distinct SiLU members, 2 distinct exp tables over the 22 layers). The residual basis is rotated by a public randomized Hadamard map |
| Lengths in evidence | L = 1 (layer 0), L = 2 (layers 7–8), L = 22 (all; statement identity `68ad19c8…`, the same statement the native lane's 22-block stack proved) |
| Hash rule | D19a tag: keyed BLAKE3, four keys derived from the block profile (re-derived by the gate and equal to the declared keys) |
| Sealing | The prover, at proof time (D18, option A) |
| Path | **CPU only: an OPERATING RULE, not a scope fact the artifact shows** (P-7). CPU and CUDA paths draw identically and produce receipts of the same form, `statement.json` does not record the backend, and tagged commitments are no longer declined by the accelerator in this tree (G-6). Until the backend is recorded in the statement or the deployment binary is named by digest, the rule lives in §6 |
| Code | Evidence: tree A, `ops/zkp-mvp/trained-1b-gate/` (the frozen review copy `trained-1b-review-r2` plus test-only capture code). The tree a statement must name: the native lane's post-port freeze **R5b** (pending; R5 = `d67fae7e…` is superseded by P-1). **No commit, no integrated tree.** A statement has to name an integrated tree and its pin set (§5, condition 7) |
| Evidence path | The bundles come from a TEST HARNESS (`run_capture_tests.rs`: the `TrainedChain` witness source, `prove_run`, `new_bound`). The CLI uses `StackSource`, and in R5 also `prove_run_with(CacheBlocks)` and `new_bound_from_digests`. In R5, `prove_run` = `prove_run_with(SliceBlocks)` and `new_bound` = the CS-1 / CS-4 checks + `new_bound_from_digests` [READ, review P-18], so the prover core is shared and only the block and witness sources differ. A capture through the CLI's own path is recommended (as D22 did) |
| Coverage over L | Draws per run = 2,329,764·L + 30,208·(L−1) + 51,712 [COUNTED, review P-19]. The CLI accepts any contiguous `--layers A..B`; the evidence covers {0}, {7, 8} and {0..21}. The recommended object is the full 22-layer stack; L = 1 and 2 are diagnostics |

**Not in scope; each owes the argument again:**

- any other calibration under the same profile string (finding F-6 of the D24
  review: one profile string covers a family of calibrations, which the
  statement identity separates; the gate read pg_rot1 only — see §7, G-7);
- any T other than 32;
- the GPU path (G-6);
- hidden weights (P3; NL-7 says the non-linear argument does not carry);
- sealing in advance (D8, D11, D18 option B);
- joining two finished runs (D12a);
- the embedding, final norm, LM head and token selection (D13; outside the
  proved stack);
- soundness.

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression
> function being ideal also at a chaining value the adversary knows (D19b,
> accepted by Victor 2026-10-17 19:28 UTC), and assuming the prover's generators' joint
> output is indistinguishable from uniform (E-1; X-1 across runs), a verifier
> who receives an **accepted** run directory of this profile with L blocks
> (accepted = a fresh-process verification passed, and `statement/` written
> only then: M-9 / D12b(1), P-1), bound to its trained-model statement, with
> the export and the context fixed before and independently of any hidden
> input (P-4, C-R4), and who makes at most `q ≤ 2^128`
> hash queries, sees a view within about **2^-74.8 (L = 1), 2^-73.8 (L = 2),
> 2^-70.4 (L = 22)** per run of a distribution that does not depend on the
> hidden run input, output, activations or internal boundary planes — for
> every **admissible** hidden run input, admissibility being a joint
> condition on all L blocks (R-1.1). Whether an attempt on an admissible input
> is refused is, up to **2^-117.4 / 2^-116.4 / 2^-113.0** (two-world
> distance), a function of the verifier-visible challenges and the public
> tables alone.

The numbers are [COUNTED] (§4), recounted independently by the review
(REVIEW.md §3: every figure equal). The structure is the run statement of
`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §1 at this shape. The
sentence stands or falls with §3's five steps and the conditions of §5.

**Admissible (P-8)** means: the input passes the CLI's admission predicate.
That predicate has three parts: the trained door, the witness builder's
refusal sites at these constants, and bit-exact parity against the Python
reference at every layer. Whether an input is admissible depends on the
data. A missing receipt discloses that bit to anyone who expected one. The
refusal fact is outside every statement (RUN.md §5.2).

## 3. What it would rest on, step by step, at the trained layout

For each step: the argument of record; **what changes at the trained
layout**; what is MEASURED here; what is OWED. The layout changes that matter
are these:

- **(a) The pad set is {F, L, Tab}.** D, Ht, Kv, Q, S and T are exact powers
  of two. At 125M the pad set was {Ht, L, D, Q, S, Tab}. Dom::F pads here and
  did not at 125M: 2,560 of 8,192 per token, 81,920 positions.
- **(b) Per-profile constants.** The D24 norm (tn, two separate Cn, Ceps) and
  seven windowed requantization shifts are now shape fields, read by the
  relations of slots 02, 14, 15, 16, 17 and 18. They also set the top-limb
  coefficients of `lookups_at` (`2^(8-sh)`, `2^(16-sh)`).
- **(c) Per-layer public tables** (exp `e_s`, SiLU member, weight folds).
- **(d) The rotated basis.** A public change of basis of the residual stream,
  folded into the public weights.
- **(e) Duplicate lookups.** At sh_qkv = sh_g = 8 the scaled top-limb lookup
  of RQL, RKL, RVL and RGL has coefficient 1. It is then the same lookup as
  the byte lookup already in the list. Unlike correction C-6 for the norm, it
  is not dropped, so H carries two helper planes of equal value for each
  (§7, G-7).
- **(f) Code lineage.** The trained tree lacks the 125M lane's stages 36–45
  (§7, G-1).

### Step 1 — the all-zero input is admissible, proves and verifies

- **Argument.** None needed beyond the run. The zero chain is zero at every
  block (x = 0, so every norm is 0, attention is 0, the residual is 0, the
  FFN is 0), with Ceps > 0 keeping the norm's denominator non-zero.
- **Changes here.** Real weights, and the zero plane on them.
- **MEASURED.** The all-zero plane on the trained blocks proves and verifies
  with the production run verifier, captured with the recorder attached:
  - L = 2, layers 7–8: `EV/capture-zero.*`, 50 s, 1.01 GiB;
  - L = 1, layer 0: `EV/l1/capture-l1-zero.*`;
  - **L = 22, all 22 trained blocks as one bound run** (round 2, 13:43-13:53
    UTC): `EV/l22/capture-l22r2-zero.*`, bundle
    `~/zk60-artifacts/tinyllama-trained-capture-zero-l22r2` (371,073,602 B),
    548.7 s, peak RSS 2.33 GiB. Its computed prediction equals the dense
    run's on every replay, hash and joint figure
    (`EV/l22/prediction_tinyllama_l22r2_zero.json`).
- **OWED.** Nothing for this step at L = 1, 2 and 22. (At 125M the 12-block
  all-zero run was row 1's open item; here it is closed.)

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

**Argument of record:** `ZK60_GENERIC_RANK_LEMMA_SHAPED.md`, accepted with
changes S-1…S-6 [ARGUED, its disposition], plus the four closures GS-4, GS-5,
GS-11 and GS-12 (`ZK60_GS4_GS5_GS11_GS12_CLOSURES.md`, ruled GC-1 and GC-2).

**What changes here [MINE].** The lemma is about commitment geometry: rows,
reserved pairs, groups, proximity pair, pad count equal to opened columns. It
is not about the relations' coefficients, so (b), (c) and (d) do not enter it.
Its shape invariants hold, checked against the bundles:

- S-1, `log(Dom::Tab) == log_cols`: 12 = 12, measured in the prediction.
- S-3, head_dim 64 < row width 4096.
- S-6, `log T` = 5 < 12.
- C-4, the mask budget: largest `L_s` 97 + 256 ≤ 512.

Of the four closures:

- GS-5's formula is derived for any n and Q; here n = 4096 and Q = 256.
- GS-11 holds: M's geometry is identical (50 rows, 34 functionals, measured).
- GS-4 holds: exclusivity measured 16 of 16 on every commitment.
- **GS-12 is NOT vacuous here**, for the first time at a real shape, because
  of (a): Dom::F pads. Its closure rests on three things: every admitted
  witness carries `(g8, a16) = (0, 0)` at a padded F position; ruling
  **S38-F1(a)** refuses `act[128] ≠ 0` wherever F pads; ruling **CS-3**
  refuses any activation miss before the first commitment. **Both rulings
  are absent from the tree these bundles were captured from (G-1).** The
  native lane ported both in its round 5 (`ops/zkp-mvp/trained-1b/`:
  S38-F1(a) at `hashline/src/private_block.rs:677-678`, CS-3's
  `refuse_lookup_misses` at `private_block/protocol.rs:948`, before the first
  draw and the A commitment) [READ, not yet tested by a suite run, not yet
  captured through the gate]. What holds for the captured tree is
  [MEASURED]: `act[128] = 0` in all 22 layers' activation tables of
  pg_rot1, recovered by the gate from each stage's public table and equal to
  the export's `act.bin` (and since tools v5 checked against the export by
  the gate itself, E4). **Correction (review P-15):** the earlier sentence
  "for this export, not as an enforced invariant" overstated the gap. Tree
  A's door requires every layer's `act` to equal a frozen SiLU member
  (`trained_block.rs:813-816`), and every member has `act[128] =
  round(silu(0)) = 0`. So the closure is enforced for every export the door
  admits, apart from R2-a's out-of-door shape, which the CLI cannot reach.
  The draft also understated what is at stake. A padded F position carries
  the constant pair (128, 0). If `act[128] ≠ 0`, every proof fails
  verification **for every input**. That is a liveness question, not a
  disclosure channel.

**MEASURED** (`EV/l2/tl-{dense,zero}-a.json`, `EV/l1/tl-l1-*-a.json`,
`EV/l22/tl-l22-dense-a.json`):

- A disclosed 0 everywhere (rank 74 of the 74 generators on the non-data
  rows).
- H disclosed 2, computed equal to the public LogUp identity (exact u* =
  per-indicator).
- Both endpoints 0.
- Every internal boundary 0, its reserved block of rank 6 of 6; at L = 22,
  all 21 boundaries.
- M 0.
- k0 = 0 everywhere; exclusivity 16 of 16 on every commitment.
- The H-pad cross-check has full rank.
- These figures are the same for the dense and the all-zero bundles.

**OWED.**

- GS-12's enforcement (G-1, G-8): ported in the native tree, owed as
  evidence on a tree the gate has read (capture, re-pin, re-gate).
- G-7's reading for the duplicate helper planes. The linear view is measured
  unaffected (H stays at 2), because the lemma does not look at data values.
- The lemma's own errata at this shape: none expected [MINE].

### Step 3 — the gate constructs blinding that reproduces the view under the all-zero input

**What changes here.** The tools had to be ported:

- 21 source digests re-read and re-pinned, with readings;
- the terminal identity reading the per-bundle calibration;
- D24's window in the prediction;
- control CT-5 generalised to the first padded domain;
- the one-block predictor branch.

The port moves no frozen figure: the original and ported tools, run on the
frozen rung-K4 bundle with controls, agree on 5,261 record fields, with 0
unexplained differences (`EV/equivalence/equivalence-k4.json`; again with
tools v3 and v4: `EV/p2/equivalence-k4-v3.json`, `EV/v4/equivalence-k4-v4.json`).

**MEASURED.**

| Item | L = 2 dense / zero | L = 1 dense | L = 22 zero | L = 22 dense |
|---|---|---|---|---|
| Per-commitment preimage from zero data: entries, differing | 2,246,389 / 2,255,011, 0 | 1,125,324, 0 | **24,650,287, 0** (67 of 67 commitments) | **24,621,305, 0** (67 of 67 commitments) |
| Masking layer and CFS: entries, differing | 32,310, 0 (each) | 16,155, 0 | 355,410, 0 | 355,410, 0 |
| One joint assignment: entries, differing | 2,278,699 / 2,287,321, 0; four couplings respected | 1,141,479, 0 | **25,005,697, 0**; four couplings respected, 704 identified pairs all data rows | **24,976,715, 0**; four couplings respected, 704 identified pairs all data rows; ok TRUE |
| Salted leaves authenticated | 1,792 + 512 | 1,024 + 256 | 17,152 + 5,632 | 17,152 + 5,632 |
| Every control family fires (by-name skips as at 125M) | yes / yes | yes. With tools v4: C1…C4 NOT APPLICABLE by name; C5 fires on the replay AND on integrity (G-10 repaired); C6 fires; CH 6 of 7 (CH-6 skipped by name); M9-1, M9-2, M9-3 fire, M9-3's wording criterion false (G-4) (`EV/v4/tl-l1-dense-runcontrols-v4.json`) | M1…M6 fire (`EV/v4/tl-l22r2-zero-m.json`). The arms pass ran without controls: status ARMS-ONLY (G-11), see below | M1…M6 (`EV/l22/tl-l22-dense-m.json`); pass F (`EV/v4/tl-l22-dense-f.json`, tools v4, --controls): P-1…P-6 6 of 6, M1…M6, the 16 exclusivity clauses, C1…C6 6 of 6 (C5: replay and integrity refuse), CH 6 of 7 (CH-6 skipped by name; the family counts live controls only), M9-1, M9-2. **Record ok TRUE, status PASS, exit 0.** There is no terminal stage in pass F, so CT, GQ and M9-3 do not run at L = 22; the terminal identity is 506 of 506 there (pass A) |
| Channels | 28 = 10 constructed / 5 derived / 5 argued / 8 open | the same | 5 / 5 / 5 / 13 (ARMS-ONLY: the mask and joint channels stay OPEN when stage 12's `ok` is false) | 10 / 3 / 5 / 10 (the 125M lane's L = 12 pass F table; no terminal stage in the pass) |

**The 22-block all-zero arms record** (`EV/l22/tl-l22r2-zero-arms.json`,
3,570 s single-threaded, peak 5.3 GiB) exits 1, and its status file says why
(`EV/l22/tl-l22r2-zero-arms.status.json`, ARMS-ONLY, 0 unexplained leaves).
Its seven false leaves are the top-level `ok`, the four control families not
requested in that pass (CT, GQ, P, M), stage 12's `ok`, and stage 13's
`ok`. Stage 12's `ok` conjoins its unrequested controls; stage 13's `ok`
conjoins stage 12's. Every arm figure closed. Controls for those arms at this
profile are cited as follows:

- M1…M6 fired at L = 22 on both bundles.
- P-1…P-6 fired at L = 2 on both bundles and at L = 1. At L = 22 they fired
  in the dense pass F, 6 of 6.
- P-5, M-5 and C3 are the joint stage's failure modes. They fired at L = 2 on
  both bundles and in pass F at L = 22.

**OWED.** At this tree: nothing of step 3 at L = 1, 2 and 22, except CT, GQ and
M9-3 at L = 22 (a pass T with `--controls`, about 1 h more; they fired
at L = 1 and 2). It is all owed AGAIN on bundles from the post-port
tree (G-1, §10b item 1).

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** `ZK60_JOINT_LAW_COMPOSITION_RUN.md`, accepted as a
REDUCTION (R-1…R-7), conditional on G-R1 (step 2), G-R2 (the slot closures),
G-R4 (cross-role independence of the blinding) and G-R5 (step 5). The
non-linear channel's algebraic half is NL-1
(`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`). The law of the blinding
(G-R4) is `ZK60_BLINDING_LAW_GR4_DISPOSITION.md` (LW-1…LW-4).

**What changes here [MINE].**

- **G-R2, the slot closures.** The trained relations differ from the 125M
  ones by coefficients only. The argument for every slot (`argument.rs`,
  read in EV's pin readings) is the 125M argument with frozen literals
  replaced by shape fields: SC_TZC Ceps; SC_DZC 2Cn_a, 2Cn_m, 2^tn,
  2^(tn+1), 2^sh_ao, 2^sh_z; SC_FZC sh_h and sh_g; SC_QZC and SC_KVZC
  sh_qkv and sh_o; SC_SZC sh_s. Each is a non-zero public constant, so the
  structure NL-1 rests on (a public table in every monomial, degree within
  the declared degree, the mask covering each slot) is unchanged. Slot 17's
  prover is now a grouped evaluator, but the verifier's polynomial is the
  same function (read).
- **The bilinear slots 08/09** carry stage 20's repaired definition.
- **(e) duplicate helper planes.** These add two published terminals of
  equal value per duplicated lookup at slots 15, 16 and 18. That equality is
  structural and does not depend on the witness. Whether the terminal
  surjection step (`ZK60_TERMINAL_SURJECTION_REVIEW.md`) and NL-1's
  machine check accept a slot whose terminal map has two identical
  coordinates has not been re-run (G-7).
- **G-R4.** The draw discipline is unchanged in the trained tree [MINE,
  from the readings]:
  - no draw site of `zk.rs`'s masking functions moved;
  - the PCS pads and salts are drawn in the same order, before any branch,
    and `encode_buffer.rs` (unpinned, G-2) reads them only after they are
    drawn;
  - `masked_prove_rounds` publishes the same CfsMasker's rounds;
  - one generator per run (R-2) and one per endpoint.
  
  But **the machine assertions of G-R4 do not exist in this tree**: the
  stage-36 draw observers and the stage-47 root-rebuild check
  (`gr4_check_tests.rs`, LW-2) are lane stages 36 and 47, absent here
  (G-1), and absent from the native tree after its round 5 too [READ]. Draws
  are therefore [COUNTED] only (§4), not measured. The independent review
  re-scanned the draw discipline in tree A and agrees with this reading
  (REVIEW.md §2.2). It advises against the "reading suffices" alternative:
  ruling R-3's counterexample and LW-2's mutations m1, m2 and m4 pass every
  count and sum, and only the root-rebuild check catches them (P-12).
  **Round 4:** the stage-47 check is ported as a test-only module onto a copy
  of the R5 tree, run at the trained shape. Result: [GR4-PENDING].
- **R-1/H-1 and M-9.** For the first time the run has a **production
  caller**: the trained stack CLI `stack-prove`. **What follows is true of
  tree A only (P-1).**
  - It seals with the witness builder's own pass first (H-1's rule), with
    parity at every layer, before the header.
  - Its witness source takes the input at construction.
  - It writes `statement/` only after in-process verification.
  - It does **not** remove a segment directory whose run failed to verify;
    the `--lie-at-boundary` control leaves such a directory without
    `statement/`. M-9's "never transmitted, removed by whoever launched the
    run" is therefore still an operating rule.
  - **Tree B (R5, superseded) breaks both rules (review P-1, BLOCKING)**
    [READ by the review: R5 `trained_block.rs:1951-1980, 2001, 2005,
    2016-2019, 2038`]:
    - Its endpoints are sealed from the export's reference words, so a
      builder or parity refusal at block k comes after the header and after
      segments 0..k−1 are on disk. That re-opens R-1's channel (which block
      refused depends on the input).
    - Its in-process verification is off by default, and `statement/` is
      written anyway.
    - The native lane's R5b freeze is to repair this: code repair (a) of
      P-1, or a security-owner ruling (b) that amends H-1 / M-9 for this
      caller. The statement must describe the tree it names.
- **R-5, interior scales.** These are constants of the approved calibration:
  the trained statement's own `block_scales` pair, (0, 0) for pg_rot1.
  `new_with_calibration` refuses any other pair, and the measured capture
  carries `[0, …, 0]`.

**MEASURED.**

- The terminal identity at the trained constants: 46 of 46 (L = 2), 23 of 23
  (L = 1), **506 of 506 (L = 22)**.
- It is not vacuous: control family TL (`EV/l2/tl-controls-*.json`,
  `EV/l1/tl-controls-l1-dense.json`) moves each of the eleven trained
  constants one step inside its class, and **exactly** the slots the Rust
  reads it in stop matching. Restoring the frozen constants breaks exactly
  slots {02, 14, 15, 16, 18}. 15 of 15 controls fire on every bundle.
- The whole-run linear joint figure equals the sum of parts at L = 1, 2 and
  22 (2 = 2, 4 = 4, 44 = 44).

  > *Ruling R-3 applies:* "joint = sum of parts" is a consistency check of
  > the model, not evidence of independence.

**OWED.**

- G-R4's machine assertion on the named tree: the stage-47 root-rebuild
  check (P-12, being ported; see above), and LW-4's note (`CfsMask: Clone`,
  `CommittedZk` with `pub` fields) carried to that tree. "The reading
  suffices" is NOT recommended (P-12).
- NL-1's `nl_check.py` and the terminal-surjection computation re-run at the
  trained slot-IR export (G-7).
- GN-1 / GS-14, completeness for every admissible witness.
  - Evidence: two held-out sequences proved through all 22 layers (native
    lane, R2-2/R2-3) and the six captures here. The calibration lane's
    Python reference refuses 0 of 36 held-out and 0 of 54 calibration
    sequences, which is admissibility in a reference, not completeness of
    the prover.
  - The shaped refusal census is not in either trained tree. Of its rulings,
    the captured tree carries none (G-1). The native tree's round 5 ports
    CS-1, CS-3, CS-4, CS-6…CS-9 and S38-F1(a), with one named test each in
    `cs_port_tests.rs`. Its suite `r5-suite2` was GREEN at 19:48 UTC (688
    passed, 0 failed, CS-6's test included; the earlier 1-failure run is
    superseded, P-17).
  - **CS-2 and CS-5 are unnecessary at trained profiles, on code facts**
    (review P-13; reading adopted by the coordinator at round 4; not a
    register ruling, for the security owner to confirm):
    - the trained shape passes no window overrides (`shape.rs:1287-1307`);
    - the door refuses a norm-window override (`:1196-1200`);
    - `check_trained_class` requires `norm_wrho` and `wrho_s` to equal
      their derived values exactly (32 and 14; `:1238-1246`), re-checked in
      `Layout::for_shape` (`layout.rs:1080-1082`);
    - width is capped at `TRAINED_WIDTH_MAX = 4096` in both trees.

    So CS-2's undersized window and CS-5's width above 16,384 cannot arise
    at a trained profile.
  - **Still owed:** the census itself at these constants. It must show that
    a builder-admitted input meets no refusal other than S-4. In R5, CS-3
    turns a lookup miss into a prover refusal after `B_k` and the earlier
    segments; with P-1 that refusal comes mid-run, covered only by M-9.

### Step 5 — the hash layer adds nothing; the lift to the hashed protocol (G-R5)

**Argument of record:** Lemma H^run and Route A^run
(`ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`, core accepted with changes H-1…H-8).
The model is D19 plus **D19b (ACCEPTED by Victor 2026-10-17 19:28 UTC, `docs/zkmatrix-poc/ZK60_DECISIONS.md`)**: this profile is TAGGED, so
it cannot rest on D19 as worded alone.

**What changes here [MINE].** The counts are new (§4): 4L + 1 roots, the leaf
and query totals. The key set is derived from the new profile strings. H-8
(constructor length against the squeeze length) was a live hazard at this
profile: the first trained run-profile string would have put the
transcript-constructor input at 68 B, equal to a `pb-run-stage` absorb. The
native lane caught it with the s25 census and lengthened the string to 66 B
(constructor 78 B, nothing at 77–79). Position tags and H-5 are unchanged in
code (run.rs absorb sequence, read). GS-7 and the explicit L = 2 hybrid stay
open as bookkeeping (as at 125M).

**MEASURED.** In every record:

- the derived keys equal the declared ones;
- every challenge is re-derived: 4,511, 9,002 and **98,822** at L = 1, 2 and
  22, the run binding reproduced and every position tag re-derived;
- every opened column is re-hashed and re-authenticated under the derived
  keys: 1,280, 2,304 and **22,784 columns (162.2 MB)**;
- four wrong hash rules never reach a root (cross-rule probe).

**Re-read independently (REVIEW.md §2.3).** The lemma and the lift carry
with these counts, under three conditions the draft did not carry; they are
now in §5 (P-3):
- **C-R1:** no 40-byte input to the unkeyed function. The trained additions
  are the stack context (≥ 71 B) and the trained identity (SHA-256, outside
  BLAKE3). The run public statement is 29 + 32L ≠ 40.
- **C-R4:** the context is a statement constant, not derived from a request
  or an input. This is live in the CLI: `--label` is free.
- **C-R5:** no tagged commitment on an unkeyed device path.

C-R2 holds: constructor inputs are 78 (run) and 70 (block), neither 47.

**OWED.** Nothing by ruling: D19b is accepted (2026-10-17 19:28 UTC). Route
B (G-H1) is not needed by a Route-A statement and stays unruled.

## 3b. The independent review (2026-10-17, 21:06-21:28 UTC), finding by finding

Source: `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`. The
reviewer did not write the draft or the tools. It re-read the three
arguments at this layout, recounted §4, re-scanned the draw discipline, and
found nothing that leaks in the measured receipts. Its verdict is "not yet".
Where each finding landed:

| # | Severity | Where it landed | State |
|---|---|---|---|
| P-1 | BLOCKING (native) | §3 step 4 (R-1/H-1, M-9), §6 (M-9), §1 (code) | Open: the native lane repairs it in R5b. Captures from R5 stopped (none ran) |
| P-2 | BLOCKING (gate) | Tools v5: pins enforced (stages suspended, `ok` fails), shared files and G-2 pinned, PASS needs zero unexplained leaves (CH-6 explained by name), negative controls PC-0..PC-9 | **Repaired** (PC-0..PC-9 exactly as predicted, `EV/v5/pincontrols/pincontrols-l1.json`; 21 existing records keep their `ok` and status, `EV/v5/verdicts-unchanged.json`; rung-K4 equivalence 0 unexplained, `EV/v5/equivalence-k4-v5r.json`) |
| P-3 | must-fix | §5 rows C-R1, C-R4, C-R5; §3 step 5; §6 | Folded. C-R4 is live in the CLI (free `--label`): code repair owed (native) |
| P-4 | must-fix | §2 sentence hypothesis; §5 row P-4; §6 | Folded |
| P-5 | must-fix | §6 operating rule | Folded. Code repair owed (native) |
| P-6 | must-fix | §6 (corrected) | Folded. Parity-message repair owed (native) |
| P-7 | must-fix | §1 (Path), §6 | Folded: CPU-only is an operating rule until the backend or the binary is in the statement |
| P-8 | must-fix | §0, §2 (admissible defined), §8 | Folded |
| P-9 | must-fix (gate) | Tools v5: `zk60_native_rg_exportcheck.py`, driver stage 14 | **Repaired** (ok on L1, L2 dense/zero, L22 dense/zero; L22 identity equal to the native CLI's 68ad19c8…; stage-to-layer maps from the CLI's block digests; tables equal per layer; EX-1..EX-6 fire; `EV/v5/export-*.json`) |
| P-10 | must-fix (gate) | Tools v5: `zk60_native_rg_schema.py` | **Repaired** (all six trained bundles: keys all on the 222-key allow-list, no forbidden word, arrays.bin covered exactly; SC-1..SC-4 fire; `EV/v5/schema-six-bundles.json`) |
| P-11 | must-fix (gate) | Tools v5: classifier rules and negatives, non-empty guards, M9-3 named and exception-safe, `--old` / `--legacy` for CT-4 / CH-6, data_rows refusal; §10a corrected | **Repaired** (47 unit tests; CT-4 and CH-6 now FIRE in the staged driver, CT 9 of 9, CH 7 of 7, `EV/v5/tl-l2-dense-t-v5.json`; the one false item left there is M9-3's wording criterion, G-4) |
| P-12 | must-fix | §3 step 4 | Being ported (stage-47 check) [GR4-PENDING] |
| P-13 | must-fix | §3 step 4: CS-2 / CS-5 unnecessary on code facts; the census owed | Folded; census owed |
| P-14 | wording | §4 | Folded (the [MINE] replaced by the reading) |
| P-15 | wording | §3 step 2 (GS-12) | Folded |
| P-16 | wording | §4 table and notes | Folded |
| P-17 | wording | §0, §10b, §10a (G-11 row), pass F status | Folded (pass F is PASS with 0 unexplained under v5) |
| P-18 | wording | §1 (evidence path), §8 | Folded; a CLI-path capture recommended |
| P-19 | wording | §1 (coverage over L) | Folded |
| P-20 | wording | Tools v5 TL-4 | **Done** (TL-4 at L22: 3 of 3, exactly stage 1's SC_TAB slot, `EV/v5/tl4-l22-dense.json`; at L2 18 of 18 TL controls) |
| P-21 | minor tool | Tools v5 G-10 extension, G10-5..G10-8 | **Repaired** (8 of 8 G-10 controls at L = 1, 2, 22, `EV/v5/g10-*.json`) |
| P-22 | wording | §4 note for the owner | Folded |

## 4. Residuals, sized [COUNTED]

Source: `ops/zkp-mvp/gate-tinyllama/counts/run_hash_counts.py`, a copy of the
lane's counting script with the TinyLlama shape added. Every old figure of
the original script reproduces byte for byte. Its parameter line equals the
bundle's character for character; its squeeze model equals the measured final
counter. Output: `EV/run_hash_counts_tinyllama.json`. The draw totals are a
COUNT: the in-situ observers of lane stages 36/46 do not exist in this tree.
Per-block draws are 2,329,764, per boundary 30,208 and per endpoint 25,856.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| Field draws per run | 2,381,476 | 4,741,448 | 51,940,888 | — |
| Sampler bias (D9): draws × 2^-96 | **2^-74.82** | **2^-73.82** | **2^-70.37** | distance |
| Input-dependent refusal (S-4): L·768/p², one world | 2^-118.42 | 2^-117.42 | 2^-113.96 | — |
| … as a two-world distance (2·L·768/p²) | 2^-117.42 | 2^-116.42 | 2^-112.96 | distance |
| Salt guessing, q·N_leaf·2^-256 (q = 2^128) | 2^-111.9 | 2^-111.1 | 2^-107.8 | distance |
| Transcript pre-query | 2^-115.5 | 2^-114.5 | 2^-111.0 | distance |
| Leaf-input / transcript-input collisions | 2^-224.8 / 2^-231.9 | 2^-223.2 / 2^-230.0 | 2^-216.6 / 2^-223.1 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | 2^-125.4 | 2^-125.4 | assumption |
| Generator-key row, 3·4·2^-256 (the value this row printed before round 4; review P-16) | 2^-252.4 | 2^-252.4 | 2^-252.4 | distance |
| Tag-key collision, C(m,2)·2^-256 at today's m profiles (D19b model) | zero by the s24 all-profile test (≤ 2^-246 for m up to ~40) | | | distance |
| Constructor vs absorb, B10: (A + q)·2^-256 (missing before round 4; P-16) | 2^-128.00 | 2^-128.00 | 2^-128.00 | distance |
| **Total distance** | **2^-74.82** | **2^-73.82** | **2^-70.37** | |
| Refusal on degenerate challenges, (3L+1)/p | 2^-62.0 | 2^-61.19 | 2^-57.93 | **liveness, not distance** (one base-field determinant per opening) |
| 2^20 runs, linear | 2^-54.8 | 2^-53.8 | 2^-50.4 | distance |
| 10^6 runs, linear (P-16) | 2^-54.89 | 2^-53.89 | 2^-50.44 | distance |

Notes (review P-16): the L = 1 column is not in
`EV/run_hash_counts_tinyllama.json`, which computes L = 2 and 22 only. It is
from the review's independent recount
(`results/zk60_privacy_review_trained_t32_20261017/recount/`), which also
reproduces every other figure here. H's "50 claims" are 49 reserved site
pairs plus the pairless LogUp sum claim. The zero-sum pair is drawn once,
inside H's data rows, not re-drawn. **For the owner (P-22):** D9 was
accepted at about 2^-75 (toy), 2^-72.9 (125M) and about 2^-72 (8B) per
proof. This statement's figure is 2^-70.37 per 22-block run, and about
2^-50.4 over a million runs. These should be printed on the owner's page;
that needs no new ruling unless the owner wants one.

The S-4 count (≤ 768 distinct inverted arguments per block) is unchanged by
per-layer tables (c). Each block's three tables still have 256 rows each, and
the run total is L × 768 as before. For an admissible witness, *whether* a
zero-denominator refusal happens is a function of the challenges and the
public tables. *Which* line returns first depends on the data. **Why, at
this tree (review P-14, replacing my earlier [MINE]):** D22 §9 item 10's
reason, "the prover inverts the whole of each table before multiplicities
enter", does not transcribe. In tree A `protocol.rs`:
- the challenges are drawn at :901-903;
- the byte table is inverted at :912, which never refuses;
- the witness-side byte helpers, `exp_den` and `act_den` follow (:913-934);
- the three whole tables are inverted only at :958-967.

The conclusion holds anyway:
- for every builder-admitted witness, every witness-side argument is a table
  row (byte ranges; exp keys checked in 0..256 at `witness.rs:643-653`; act
  keys `g8 + 128`);
- the whole tables are inverted on every attempt that reaches :958;
- nothing is absorbed or drawn in between;
- the refusal message is identical.

Which line returns first, and the time taken, are out of scope (D20).
Tree B has the same order, plus CS-3 earlier.

## 5. Conditions — the toy's seven and the shaped ones, at this tree

| # | Condition | State at the trained tree |
|---|---|---|
| 1 | One reserved pair per claim site, weights `(cm, cm·U)`; H's zero-sum pair the one exception; `audit_claims`' exclusivity is the whole defence | Code fact (the shared audit, unchanged); MEASURED 16 of 16 on every commitment at L = 1, 2, 22; the 24 exclusivity controls fire |
| 2 | Pad count = opened columns | Code fact; MEASURED pad margins 0–4, H-pad ranks full |
| 3 | `d + 1` values per round; exact-row-span assertions; zero-mask refusal; declared order of the 34 mask functionals | MEASURED (mask arm, 34 of 34, M1…M6 at L = 1, 2, 22); the prover's round evaluator changed (`masked_prove_rounds`), the published rounds did not (replay) |
| 4 | One opening per commitment; a refusal is terminal | Code fact. **CS-3 (lookup-miss refusal before the first commitment) is ABSENT from the captured tree** (G-1): an inadmissible witness that passes the builder now reaches the verifier, which rejects it (D21 covers transmission). Ported in the native tree's round 5 (`protocol.rs:948`, nothing drawn or absorbed before it) [READ, untested] |
| 5 | Every Merkle leaf salted with 32 fresh bytes; no unsalted digest published | Code fact on the CPU path (salts drawn by the core). **On a gpu-cuda build with HL_GPU=1 the unsalted columns of tagged commitments are now hashed on the device** (G-6), not covered |
| 6 | Fresh OS randomness per run; no seeded configuration | One generator per run (R-2) plus two endpoints; generator domains carry role and spec (lane stage 26, present: `endpoint_g.rs` and `hash_domain.rs` are byte-identical to the 125M-gated digests) |
| 7 | The gates' source pins; a change suspends step 3 | **Pinned for these bundles**: all 39 `source_pins` read (21 new readings, `zk60_native_rg_tinyllama_pins.py`); the remainder equal the 125M digests. **OPEN:** `encode_buffer.rs`, `sumcheck/rounds.rs` and `sumcheck/grouped.rs` are on the prover path and pinned by no bundle of the captured tree (G-2; the native tree's `SHARED_SOURCE_FILES` pins them since round 5, so a capture from it will carry them); no integrated tree to pin. Six pinned files (run.rs, layout.rs, argument.rs, protocol.rs, shape.rs, run_capture.rs) differ in the native tree: its bundles will need new readings |
| S | Shaped invariants: S-1, S-3, S-6, C-4 (in `Shape::new` at the trained tree); D24's window (`derive_at_width`, re-checked in `Layout::for_shape`); F-1's f_e class; R-5 interior scales; M-1 boundary geometry derived; H-8 constructor lengths (s25 census) | Present and exercised. **CS-1, CS-2, CS-4…CS-9 and S38-F1(a) absent from the captured tree** (G-1). The native tree's round 5 ports all of them but CS-2 and CS-5 (suite green 19:48). CS-2 / CS-5 are unnecessary at trained profiles on code facts (P-13, §3 step 4) |
| C-R1 | No 40-byte input to the unkeyed BLAKE3 function (P-3) | Holds [READ, review]: the stack context is ≥ 71 B, the trained identity is SHA-256, the run public statement is 29 + 32L B |
| C-R4 | The context label is a deployment constant, never derived from a request or a hidden input (P-3) | **LIVE in the CLI**: `stack_context(variant, layers, label)` takes a free `--label` (tree A `trained_block.rs:1517-1527, 1639`), published in `statement.json` and absorbed. Repair: an allow-listed label; until then an operating rule (§6) |
| C-R5 | No tagged commitment on an unkeyed device path (P-3) | Holds [READ, review]: `commit_zk_device` is not called from `private_block`. The keyed device path (G-6) is scoped out by the CPU-only rule |
| P-4 | The export (`profile.json`, the layer manifests, every file whose digest enters the trained statement) and the context are fixed before, and independently of, any hidden input; no hidden input is in the calibration or held-out set; no input is retried under another calibration or label | A HYPOTHESIS the sentence now carries (§2). `profile.json` carries held-out sequence names and statistics, and the identity binds its digest. Harmless for this evidence (public data); as a statement it needs the rule |

### 5a. Pin-list completeness beyond G-2 (review r4 note N-r4-d), file by file

Review r4 (`results/zk60_d24_review_20261017/R4_VERDICT.md`, N-r4-d) noted
that the capture pin list still leaves out the GPU code, `layer.rs`,
`wcache.rs`, `tables_v3.rs` and zkp-core `tables.rs`. Decided from the
source (tree A and R5; [READ], 2026-10-17 ~22:15 UTC):

| File | On the CPU-path prover's route at the trained profile? | Decision |
|---|---|---|
| `hashline/src/gpu/mod.rs` | **Yes.** `src/pcs.rs` (pinned) takes its backend from `gpu::backend()`. Without `gpu-cuda` the `#[cfg(not(feature = "gpu-cuda"))]` seam returns `zkp_core::pcs::Cpu` (never takes over) and `enabled()` is the constant false. The CLI also calls `gpu::require_live / label / declines` | **Pin it.** Writer-side ask to the native lane for R5b's `SHARED_SOURCE_FILES`; the gate adds a reading when a bundle carries it. Until then it is covered by this reading only |
| `hashline/src/gpu/cuda.rs`, `kernels.cu` | **No, provably, on a binary built without `gpu-cuda`:** `#[cfg(feature = "gpu-cuda")] mod cuda;` (gpu/mod.rs:19-20), so neither is compiled | Not pinned for a CPU statement; the CPU-only operating rule (P-7, §6) is what makes this true. A GPU statement must pin both (G-6) |
| `hashline/src/layer.rs` | **No.** Only zk.rs's FFN layer provers (`prove_layer_zk`, the v3 provers) import it (zk.rs:713, :2038). None of the functions the private block calls (`mask_commit_tagged`, `mask_open`, `mask_verify_tagged`, `masked_prove_rounds`, `extension`, `ZkRng`) uses a `layer` item, and no non-test private-block file calls the layer provers. zk.rs is pinned, so a change that made those functions reach `layer.rs` would move zk.rs's pin | Not pinned; reason recorded here |
| `hashline/src/wcache.rs` | **No.** The weight cache serves zk.rs's v3 FFN path (`--wcache`, zk.rs:2833-2838); no private-block file calls it | Not pinned; reason recorded here |
| `hashline/src/tables_v3.rs` and `zkp-core/src/tables.rs` | **Not on the prover / verifier relation:** the activation table is a public word of the block statement, carried in every stage and recovered and checked by the gate (E4, v5). **But on the trained DOOR's route:** `tables_v3.rs` is `pub use zkp_core::tables::*`, and the door admits only an `act` equal to a frozen SiLU member (tree A `trained_block.rs:813-816`, R5 :490/:914, R5 `trained_statement.rs:547`). P-15's "GS-12 is enforced for every export the door admits" rests on that registry | **Pin both, and `trained_block.rs` with them**, for the statement's every-admitted-export form (writer-side ask; `trained_block.rs` is today on the writer's NOT_ON_THE_RUNS_PATH list as a caller). The evidence does not depend on them: E4 measures `act[128] = 0` per stage against the export |

## 6. Hypotheses and operating rules

- **D18**: the prover seals both endpoints at proof time. The stack CLI
  commits the first input plane and the last output plane it built (H-1).
- **D19** (accepted) and **D19b** (accepted by Victor 2026-10-17 19:28 UTC):
  the model of the tag.
- **D20** (accepted): timing, memory and power are out of scope. A 22-block
  run adds per-stage wall clock and high-water marks to what an observer
  could time. The sealing pass's duration grows with L.
- **D21** (accepted): a rejected receipt is never transmitted; a retained
  capture counts as publishing. The captures of this evidence are of
  held-out calibration data the export itself stores in the repository
  (`seq_ho00/x_in_L*.bin`), so they publish nothing new; the gate's channel
  text calling them "a public synthetic fixture" is stale (G-3).
- **M-9 / D12b(1)**: a run directory is publishable only with its statement
  written after verification. Tree A's CLI writes it so, but does not remove
  a failed directory (operating rule). **Tree B (R5) does not (P-1):** its
  in-process verification is off by default and `statement/` is written
  regardless. Until R5b repairs this, or the owner amends M-9's marker to
  "publishable only after a fresh-process `stack-verify` passed on this
  directory", a tree-B directory is not publishable.
- **Refusal reasons are never shown to anyone not entitled to the input
  (P-6, corrected).** A run's refusal names the stage. The earlier text here
  said the parity refusal prints "a token/channel position (no value)". In
  fact it prints the NUMBER of differing words and the token and channel of
  the first difference (tree A `trained_block.rs:1688`; R5 :1709, :1075).
  Witness-build refusals print the block index and the failing check, and
  per-segment stdout events show how far a run got. Repair owed (native):
  drop the count and the position, naming the layer at most. Operating rule
  now: `stack-prove`'s stdout and stderr from a run on a hidden input are
  prover-private, never retained in a published log or capture. Diagnostics
  `HL_PB_BASEFIELD` and `HL_PB_TIMING` are prover-private (P-2 of the toy
  statement).
- **The verifier's copy of the export contains no `seq_*` directory, and none
  is ever published (P-5).** `TrainedExport::load_seq` reads the hidden input
  and every per-layer reference activation from `<export>/seq_<id>/`, and
  `stack-verify` rebuilds the statement from the same directory, so shipping
  "the export" ships every hidden plane. A sequence manifest's SHA-256s
  would also allow dictionary tests. Code repair owed (native): a separate
  prover-private input path, and `stack-verify` refusing an export with
  `seq_*`.
- **CPU only (P-7).** The deployment binary is built without `gpu-cuda`
  (name it by digest in the statement), or the backend is recorded in
  `statement.json`. Until then, CPU-only is this rule, not a scope fact.
- **The context label is a deployment constant (C-R4)**, and the export
  and the context are fixed before any hidden input (P-4).
- **D23 (ACCEPTED by Victor 2026-10-17 19:28 UTC, `docs/zkmatrix-poc/ZK60_DECISIONS.md`)**: an accepted
  run's two endpoint roots are never registered, republished or referred to
  by a later artifact. It is now an operating rule this statement rests on,
  not an open question.
  **This is directly in play for the stack.** Proving the embedding or the
  LM head in a SEPARATE receipt that refers to this run's input or output root
  would put that root under D8/D11 and lapse this statement. Such proofs must
  live inside the same run, one transcript (D12a).
- **E-1 / X-1**: separate OS entropy reads are independent and uniform,
  within and across runs (LW-3).

## 7. Findings, with recommended dispositions

| # | Finding | Recommended disposition |
|---|---|---|
| **G-1** | The trained tree (candidate + lane C + native lane) branched before the 125M lane's stages 36–45. It lacks rulings CS-1, CS-3, CS-4, CS-6, CS-7, CS-8 and CS-9; S38-F1(a); the stage-36 draw observers; the stage-47 root-rebuild check; and the stage-45 block-capture writer. None moves an absorb, a draw or a published byte (the replay with the UNEDITED tools reproduced every challenge). CS-3 sits on the refusal channel; S38-F1(a) and CS-3 are GS-12's closure (G-8); CS-6 is soundness. | **Block a statement on it.** Port the rulings into the trained tree, or rebase the trained work on the integrated 125M-lane tree, before any statement; then re-capture and re-run the gate (cheap: L = 2 in under 20 min). **Round 3:** the native lane's round 5 ported CS-1, CS-3, CS-4, CS-6, CS-7, CS-8, CS-9 and S38-F1(a) into `ops/zkp-mvp/trained-1b/` (ledger `results/zk60_1b_native_20261017/PROGRESS.md` l. 902-956; tests `cs_port_tests.rs`). It did NOT port CS-2, CS-5, the stage-36 draw observers or the stage-47 root-rebuild check. The first R5 suite (19:02 UTC) had 1 failure; `r5-suite2` was GREEN at 19:48 UTC (688 passed, CS-6's test included) and the tree was frozen (`d67fae7e…`). **Round 4:** R5 is superseded by P-1 (its CLI breaks H-1 and M-9) before any capture ran; the gate's readings of R5's nine changed pinned files are kept in `zk60_native_rg_tinyllama_r5_pins.py` (none moves a transcription; they apply to R5b wherever R5b keeps those digests). **Still blocking:** capture from R5b, read its changed pins, re-gate. |
| **G-2** | `zkp-core/src/pcs/encode_buffer.rs` (my reading: the same arithmetic as `encode_row_zk`, pads drawn before), `zkp-core/src/sumcheck/rounds.rs` and `sumcheck/grouped.rs` (prover round evaluators) are on the prover path and in no bundle's `source_pins`. | Writer-side ask: add them to `run_capture.rs::SHARED_SOURCE_FILES`, then pin them with readings (the gate's per-row reproduction already re-checks the encoding by computation). **Writer side done in the native tree** (round 5, `run_capture.rs:168`, 26 files; the three files are byte-identical in both trees). **Gate side done in tools v5:** the three are pinned with readings (`SHARED_G2_PINS`), REQUIRED from a G-2-aware writer (a missing or moved one is refused and suspends the stages that re-compute what it produces), and reported for a pre-G-2 writer (tree A) without changing any earlier verdict (review P-2; controls PC-6..PC-9). |
| **G-3** | The gate's channel text "retained captures … a deliberately public synthetic fixture" is false for trained bundles (real held-out activations). | **Done in tools v3** (13:00 UTC): a trained bundle's record now says the input is real held-out calibration data, stored by the export itself; frozen records keep their sentence (`EV/p2/tl-l1-dense-runcontrols.json`). |
| **G-4** | Control M9-3 fires on all five unpadded domains, but its own ok-criterion (the refusal naming the draw counts) is false at TinyLlama exactly as in every 125M record; "only this slot" is false for D and S because their indicators also gate slots 00/01 and 04. | Re-word the criterion to "the refusal is by name" and "only the slots `pad::indicator_slots` lists". A tool fix, no figure moves. |
| **G-5** | At L = 1 the run-control stage raises (C1/C2 need a boundary), so the CH and M9 families did not run on a one-block bundle. | **Done in tools v3:** C1…C4 are reported NOT APPLICABLE by name, C5 and C6 run, and CH and M9 fire on the L = 1 bundle (`EV/p2/tl-l1-dense-runcontrols.json`). The v3 equivalence on rung-K4 moves nothing. Exposed G-10. |
| **G-6** | **Ruling T-8 no longer holds in this tree.** Tagged commitments are offered to `Backend::try_commit_zk_keyed`, which the CUDA backend implements (`hashline/src/gpu/mod.rs:691`). Under `gpu-cuda` + `HL_GPU=1` the hidden rows and pads go to the device and unsalted keyed columns are hashed there (salts stay on the host). The native lane's GPU stack runs use it. | The statement is **CPU-only by configuration**, and says so. A GPU statement needs the DC-B device-buffer review (`ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`), the CUDA files pinned, and GPU-path captures through the gate. |
| **G-7** | At sh = 8 (one-limb shifts) or sh = 16 (two-limb), the scaled top-limb lookup has coefficient 1 and duplicates the byte lookup of the same plane. Unlike C-6, it is not dropped. pg_rot1 has four such duplicates (RQL, RKL, RVL, RGL), each giving two H helper planes with identical values and two equal terminals. The linear view is measured unaffected (H = 2, unchanged). The non-linear argument's machine check (NL-1) and the terminal-surjection computation were run at nine exports, none trained. | Re-run `nl_check.py` and the surjection computation at the trained slot-IR export. If anything objects, either restrict the declared class (sh ≤ 7, sh ≤ 15) or drop the duplicates in a new profile version (a layout change). Until then the statement covers pg_rot1's constants only, not the declared class (D24 F-6). |
| **G-8** | GS-12 is non-vacuous here (Dom::F pads, 81,920 padded positions per block), and its closure's two refusals are absent (G-1). `act[128] = 0` MEASURED in all 22 layers of pg_rot1. | Port S38-F1(a) and CS-3 (with G-1); until then the statement is limited to exports whose activation tables have `act[128] = 0`, checked by the gate per stage (it now records this). **Round 3:** both are ported in the native tree (`private_block.rs:677-678`, `protocol.rs:948`), untested and not yet captured through the gate. |
| **G-10** | At L = 1, control C5 (the only stage swapped for the other bundle's) is caught by the replay (4,770 failures, first at the stage header) but NOT by the run integrity pass: in run mode `integrity` never compares a stage's external-endpoint opening roots with `run.json`'s `external_endpoints` roots. The block reader does compare them (`zk60_native_rg_block.py:643, :737`). At L >= 2 the boundary-root check catches a swapped stage, so this was never seen. | **REPAIRED in tools v4** (round 3, 18:36-18:41 UTC): the run integrity pass now requires each external-endpoint opening to carry `run.json`'s root and row count, `opened_at_stage` = [0, L-1], and the policy's roots, scales and context to equal the declared ones. Its own negative controls G10-1..G10-4 (`zk60_native_rg_g10controls.py`) fire 4 of 4 at L = 1, 2, 22 and on rung-K4; the frozen v3 pass accepted all four at L = 1 and three of four at L >= 2. Inert on honest bundles: v4 and v3 give identical integrity records on every run bundle on disk (`EV/v4/integrity-inert.json`). See §10 item 9 for the records. |
| **G-11** | Bookkeeping, found reading the code for round 3: the staged driver prints FAIL, and the record says ok = false, for a pass run WITHOUT `--controls` whose arms all closed. The cause is that `zk60_native_run_gate.stage12` conjoins its controls into `ok` even when they were not requested, and the joint stage conjoins stage 12's `ok`. The driver's stage 11 (and stages 8 and 10) do NOT conjoin skipped controls, so the treatment is inconsistent between stages. The 22-block all-zero arms record and the L = 2 all-zero arms record were in exactly this state, and so is the 125M lane's `m125-zero-full.json`. | **Addressed in tools v4 without changing any `ok`**: `zk60_native_rg_status.py` writes a STATUS beside each record (PASS / ARMS-ONLY / NOT-OK). ARMS-ONLY requires that every false leaf be a skipped control family, or stage 12/13's `ok` with the arm recomputed closed from the record's own fields. The driver writes it as `<name>.status.json`, prints ARMS-ONLY and exits 3. Both arms records classify ARMS-ONLY with 0 unexplained leaves. The inconsistency between stages is recorded, not changed: changing `ok` would move frozen figures. **Correction (review P-11 / P-17):** the round-3 claim of "a negative for every recomputed condition" was false (3 of 9 mask-arm and 4 of ~17 joint conjuncts were tested). Tools v5 adds a negative for every conjunct of both, restricts rule (a) to the control families, requires stages 1-3 and the arms for ARMS-ONLY, flags non-bool leaves, and makes PASS need every false leaf explained by (a) or (e) (CH-6 by name). Pass F, PASS in v4 with 1 unexplained leaf, is PASS with 0 under v5. |
| **G-9** | My predictions missed eight figures. Rounds 1-2: TL-1's slot 17 (corrected in writing before the run); L = 1 roots 5 vs 4; L = 22 manifest files 5 vs 25. Round 3: the v4 equivalence's explained leaves 4 vs 5 (one more wall-clock `seconds` leaf, the same explained class). Pass F's peak was 5.26 GiB against my 5.4-5.7. Pass F's verdict was ok TRUE / exit 0 against my NOT-OK / exit 1: I assumed CH-6's by-name skip fails the hash-rule family, but that family counts only live controls (`zk60_native_rg_hcontrols.py:303-304`). The L = 2 stage-6 failure came from M9-3's criterion, and M9-3 does not run without a terminal stage. Round 4: TL-4 at L22 struck the first adjacent pair with different tables, stages 0 | 1, where I had named 7 | 8; and the v5 queue's rung-K4 equivalence used the old script, which lacks the R5 argument.rs listing class (two listing leaves, 0 figures differ), so it was re-run with `EV/v5/equivalence_v5.py`. The predictor's one-block fallback was wrong exactly as predicted beforehand. Round 3 also repeated round 2's slip of leaving `preimage` out of a run-controls stage list (attempt kept in `EV/v4/attempts/`, re-run). | None for the argument. Recorded in EV. |
| **G-12** | Review P-2: the staged driver recorded the run-layer pins and ignored their suspension map; `ok` left the pins out; shared pins never suspended anything; G-2's files were pinned nowhere. No existing record was affected (every one has pins ok). | **Repaired in tools v5** (see §3b): stages a refused pin affects are NOT RUN and leave `not_checked`, `ok` needs the pins' `ok`, a moved shared file a port reads suspends its stages, G-2 required from a G-2-aware writer. PC-0..PC-9 fire exactly as predicted (`EV/v5/pincontrols/pincontrols-l1.json`); every existing record keeps its `ok` and status (`EV/v5/verdicts-unchanged.json`, 21 records). |
| **G-13** | Review P-9 / P-10: the gate took the trained constants and tables from the prover-written bundle alone, and nothing checked a capture for material outside the writer's allow-list or for unreferenced bytes in `arrays.bin`. | **Repaired in tools v5:** the export cross-check (E1-E4, stage 14) and the closed schema (S1-S3), each with its own controls (`EV/v5/export-*.json`, `EV/v5/schema-six-bundles.json`). |

## 8. What must not be claimed, even if this came into force

That TinyLlama or "a 1B model" is private in general; that any other
calibration or token count is covered; that the GPU path is covered; that the
full model (embedding, LM head, sampling) is covered; that soundness was
reviewed here; that a constructed preimage is the LAW of the blinding (it
exhibits existence only; the law is G-R4's job); that the evidence covers
the native tree after its CS port (every bundle here is of the pre-port
tree); that this is a proof re-derived by the security owner; that the
refusal FACT is covered: whether an input is admissible is outside every
statement (P-8); that the evidence path is the CLI's: the bundles come from
the capture test harness, which shares the prover core with the CLI (P-18).

## 9. What would lapse or reopen it

- A change to any condition of §5.
- A change to any file of the pin set (once one exists for an integrated
  tree).
- A finding against any step of §3.
- A calibration or export outside what the gate measured (G-7, G-8).
- A GPU-built receipt (G-6).
- A later artifact referring to an accepted run's endpoint roots (D23).
- A reversal of D19b; a published weakness in BLAKE3 as a random function
  or in the OS generator.
- An independent reader finding that a Python port differs from the Rust it
  claims to port — in particular the per-bundle calibration transcription of
  this port (`zk60_native_rg_terminals.Calibration`; since tools v5 also
  cross-checked against the export by the gate's stage 14, P-9).
- A deployment that derives the context label from a request (C-R4), ships
  the export with `seq_*` (P-5), publishes refusal text or stdout of a hidden
  run (P-6), or runs a binary built with `gpu-cuda` (P-7).

## 10. What is owed before the security owner could rule (ranked), and what rounds 3-4 closed

### 10a. Closed by evidence since the first draft (rounds 2-4)

Each line names its record. For the measurement and repair rows, "closed"
means the work is done on the CAPTURED (pre-port) tree; it is not a ruling.
The two rows marked "closed by ruling" are Victor's rulings, recorded in the
register. None of this is a privacy acceptance.

| Item (old §10 number) | Closed by | Evidence |
|---|---|---|
| The 22-block all-zero capture (4) | The all-zero plane on all 22 trained blocks proves and verifies as one bound run, captured with the recorder attached | `EV/l22/capture-l22r2-zero.*`; `~/zk60-artifacts/tinyllama-trained-capture-zero-l22r2`; `EV/l22/prediction_tinyllama_l22r2_zero.json` |
| The 22-block full preimage and joint arm, ALL-ZERO input (4) | 67 of 67 PCS commitments: 24,650,287 entries, 0 differing. Mask: 355,410, 0. Joint: 25,005,697, 0, with all four couplings respected. Exit 1 is the ARMS-ONLY state (G-11), 0 unexplained leaves | `EV/l22/tl-l22r2-zero-arms.json`, `.status.json` |
| M1…M6 at L = 22 on the all-zero bundle (4) | All six fire on stage 0; 355,410 / 0 | `EV/v4/tl-l22r2-zero-m.json` |
| The 22-block full preimage, joint arm and per-stage control families, REAL input (4) | Pass F, tools v4, every arm and every per-stage / per-boundary control. 67 of 67 commitments: 24,621,305 entries, 0 differing. Mask 355,410, 0. Joint 24,976,715, 0, ok true. P 6/6, M 6/6, C 6/6, CH 6 of 7 (CH-6 by name), M9-1/2. **ok TRUE, status PASS, exit 0**. 4,478 s, peak 5.26 GiB, shared box, n=1 | `EV/v4/tl-l22-dense-f.json`, `.status.json` |
| G-10, the endpoint-root cross-check in the run integrity pass (9) | Repaired in tools v4. G10-1…G10-4 fire 4 of 4 at L = 1, 2, 22 and rung-K4; the frozen v3 pass accepted all four at L = 1. C5 at L = 1 now fires on integrity too. v4 equals v3 on all 30 honest run bundles on disk. The port still moves no frozen figure (rung-K4: 5,261 leaves, 0 unexplained) | `EV/v4/g10-{l1,l2,l22,k4}.json`, `EV/v4/tl-l1-dense-runcontrols-v4.json`, `EV/v4/integrity-inert.json`, `EV/v4/equivalence-k4-v4.json`, `EV/gate-tinyllama.tools.frozen.v4.sha256`, `EV/gate-tinyllama-vs-original.v4.patch`, `EV/gate-tinyllama-v3-to-v4.{scripts,tests}.patch` |
| G-5, the CH/M9 families on a one-block bundle (step 3) | Run with tools v3 and again with v4: CH 6 of 7 (CH-6 by name), M9-1/2/3 fire | `EV/p2/tl-l1-dense-runcontrols.json`, `EV/v4/tl-l1-dense-runcontrols-v4.json` |
| G-11, "FAIL" for an arms-only pass (new) | Status beside each record (PASS / ARMS-ONLY / NOT-OK), no `ok` changed. **Corrected (P-11 / P-17):** v4's tests covered only part of the recomputed conditions; v5 adds a negative for every mask-arm and joint conjunct, and tightens the rules (§3b) | `ops/zkp-mvp/gate-tinyllama/scripts/zk60_native_rg_status.py`, `tests/test_v4_status_g10.py` (47 tests at v5) |
| D23, endpoint roots never referred to later (7) | **Closed by ruling**: ACCEPTED by Victor 2026-10-17 19:28 UTC ("all recommendations yes", answering `ZK60_RULINGS_FOR_VICTOR_20261017.md`). It is now an operating rule of §6 | `docs/zkmatrix-poc/ZK60_DECISIONS.md` row D23 |
| D19b, the model of the tag (7) | **Closed by ruling**: ACCEPTED by Victor 2026-10-17 19:28 UTC, same answer | `docs/zkmatrix-poc/ZK60_DECISIONS.md` row D19b |
| G-2, writer side (2) | The native tree's `SHARED_SOURCE_FILES` pins the three prover files (round 5) | `ops/zkp-mvp/trained-1b/hashline/src/private_block/run_capture.rs:168` [READ] |
| **Independent adversarial review (old 6 and 8)** | Done 21:06-21:28 UTC by an agent that wrote neither draft nor tools. It re-read the three arguments at this layout (each goes through), recounted §4 (all equal) and re-scanned the draw discipline. Verdict "not yet"; every finding folded in (§3b). One attack, not a ruling cycle | `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`, `recount/` |
| P-2 / G-12, pins enforced (round 4) | Tools v5; PC-0..PC-9; 21 records unchanged in verdict; rung-K4 equivalence 0 unexplained | `EV/v5/pincontrols/pincontrols-l1.json`, `EV/v5/verdicts-unchanged.json`, `EV/v5/equivalence-k4-v5r.json` |
| P-9 / P-10 / G-13, export cross-check and closed schema (round 4) | Every trained bundle on disk passes; L22 identity equal to the native CLI's; every control fires | `EV/v5/export-*.json`, `EV/v5/schema-six-bundles.json` |
| P-11, CT-4 and CH-6 able to fire in the staged driver (round 4) | With `--old` / `--legacy`: CT 9 of 9, CH 7 of 7 on the L2 bundle | `EV/v5/tl-l2-dense-t-v5.json` |
| P-20, a per-layer table control at L = 22 (round 4) | TL-4: 3 of 3 at the first pair of stages with different tables | `EV/v5/tl4-l22-dense.json` |
| P-21, G-10 widened (round 4) | G10-5..G10-8; 8 of 8 at L = 1, 2, 22 | `EV/v5/g10-*.json` |
| CS-2 / CS-5 (P-13) | Unnecessary at trained profiles on code facts (review's reading, adopted by the coordinator; for the security owner to confirm) | §3 step 4 |

### 10b. Still owed (ranked)

1. **P-1 (BLOCKING, native lane): R5b.** It must restore H-1 (seal with
   the builder's own pass before the header, or seal from its output) and
   M-9 (`statement/` only after a passing verification; loud removal of a
   failed directory), or the owner must amend both rules for this caller
   (P-1 (b)). R5b also carries review r4's two DoS fixes.
2. **G-1 / G-8 as EVIDENCE on R5b.** Capture L = 1, 2 and 22 (dense and
   all-zero) from R5b; read its changed pins (the R5 readings apply wherever
   R5b keeps R5's digests); re-gate with tools v5, now pin-enforced. Run:
   - pass A at each length, the TL controls, and everything at L = 1 / 2;
   - at L22, pass T plus pass F on both bundles;
   - the export check and the schema check on every bundle.

   [native lane + this lane]
3. **P-12, G-R4's machine check:** the stage-47 root-rebuild port [GR4-STATE].
   It must be re-applied and re-run on R5b. Also carry LW-4's note.
4. **Native code repairs the statement's conditions need:**
   - C-R4: an allow-listed context label (P-3);
   - P-5: a prover-private input path, and `stack-verify` refusing an
     export that has `seq_*`;
   - P-6: the parity message without its count and position;
   - P-7: the backend recorded in `statement.json`, or the binary named by
     digest.

   Until then these are operating rules (§6).
5. **N-r4-d pins (writer-side ask for R5b):** `gpu/mod.rs`,
   `tables_v3.rs`, zkp-core `tables.rs` and `trained_block.rs` (§5a).
6. **An integrated tree and its pin set** (condition 7) [integrator + gate].
7. **G-7:** NL-1's `nl_check.py` and the terminal-surjection computation at
   the trained slot-IR export [delegated, small].
8. **GN-1 / GS-14:** the refusal census at the trained constants (P-13; the
   census module is in neither trained tree) [delegated].
9. *(Closed by ruling, §10a: D19b and D23, accepted 2026-10-17 19:28 UTC.)*
   D23 must be kept to: it constrains how the stack may be extended to the
   embedding and the LM head (§6).
10. Gate bookkeeping:
    - G-4: M9-3's wording criterion. This is the one false item left in a
      full-control pass (`EV/v5/tl-l2-dense-t-v5.json`).
    - CT, GQ and M9-3 at L = 22 (a pass T, about 30 min at TinyLlama).
    - A capture through the CLI's own path (P-18).
11. G-6 stays a scope limit, not an item: a GPU statement needs its own
    review (DC-B), the CUDA files pinned, and GPU-path captures.

## 11. Evidence index (EV = `results/zk60_gate_tinyllama_20261017/`)

| What | Where |
|---|---|
| Ledger, results tables, costs | `EV/PROGRESS.md` |
| Captures (outside the repo) | `/home/victor/zk60-artifacts/tinyllama-trained-capture-{dense,zero}-{l1,l2}`, `…-dense-l22`, `…-zero-l22r2` (`…-zero-l22` is a deliberate sentinel FILE, not a bundle) |
| Predictions written first | `EV/l2/prediction_*`, `EV/l1/prediction_*`, `EV/l22/prediction_*`, `EV/v4/prediction_v4_by_hand.json` |
| Records of record | `EV/l2/tl-{dense,zero}-{a,everything}.json`, `EV/l2/tl-zero-arms.json` (+ `.status.json`), `EV/l1/tl-l1-*.json`, `EV/l22/tl-l22-dense-{a,m}.json`, `EV/l22/tl-l22r2-zero-arms.json` (+ `.status.json`), `EV/v4/tl-l22r2-zero-m.json`, `EV/v4/tl-l22-dense-f.json`, `EV/p2/tl-l1-dense-runcontrols.json`, `EV/v4/tl-l1-dense-runcontrols-v4.json` (each v4 record has a `.status.json` beside it) |
| Port's own controls | `EV/l2/tl-controls-{dense,zero}.json`, `EV/l1/tl-controls-l1-dense.json` |
| Dense against zero | `EV/l2/witness_comparison_tl_dense_vs_zero.json` (128 figures, the 14 that differ all sampled-column) |
| The port moves no frozen figure | `EV/equivalence/equivalence-k4.json`, `EV/p2/equivalence-k4-v3.json`, `EV/v4/equivalence-k4-v4.json` |
| G-10's controls and inertness | `EV/v4/g10-{l1,l2,l22,k4}.json`, `EV/v4/integrity-inert.json` |
| Tools, frozen | `ops/zkp-mvp/gate-tinyllama/` (`original/`, `frozen_v1/`, `frozen_v3/`, `frozen_v4/`, `scripts/` = v5), `EV/gate-tinyllama.tools.frozen{,.v2,.v3,.v4,.v5}.sha256`, patches `EV/gate-tinyllama-vs-original.v{1,2,3,4,5}.patch`, `EV/gate-tinyllama-v3-to-v4.{scripts,tests}.patch`, `EV/gate-tinyllama-v4-to-v5.{scripts,tests}.patch`; freeze helper `EV/v4/freeze.py` |
| Round 4 (v5) records | `EV/v5/` (verdicts, pin controls, G-10, export, schema, TL-4, CT-4 / CH-6 pass, equivalence `equivalence-k4-v5r.json`), prediction `EV/v5/prediction_v5_by_hand.json` |
| R5 (superseded) | `EV/r5/` (copy verification, the R5 pin readings' basis, the stopped queue; no capture ran), `ops/zkp-mvp/trained-1b-gate-r5-superseded/`, readings `zk60_native_rg_tinyllama_r5_pins.py` |
| The independent review | `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md` |
| G-R4 port (P-12) | `EV/gr4/`, `ops/zkp-mvp/trained-1b-gate-gr4/` |
| Capture code | `ops/zkp-mvp/trained-1b-gate/`, `EV/trained-1b-gate-vs-review-r2.v{1,2}.patch`, `EV/trained-1b-gate.sources.v{1,2}.sha256` |
| Sized terms | `EV/run_hash_counts_tinyllama.json` |
