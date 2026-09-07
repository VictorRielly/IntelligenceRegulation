# TASK BOARD — the standing queue of small, self-checking tasks

**2026-09-07, next Fable queue:** [round-9 review](ZK60_ROUND9_REVIEW.md)
credits lane `3ad4d97`: the archived `82314a1` run passed 12 full-hash byte
cases and 49 device oracle cases. Codex checked all 12 retained prover logs
and reran 215 CPU tool tests. This supersedes the old pending/deadlocked-run
status below, but the run predates H1 merge and cache pickup. The remaining
CL6/CL11 probes still reproduce; final combined-source validation stays open.

**Pickup:** [14 Fable tasks](ZK60_FABLE_QUEUE.md), with
[matching task records](zk60_fable_tasks.json): CL12–CL20 plus FA1–FA5.
Start baseline synchronization, evidence/runner fixes, timing validation,
empty-query and planner corrections, then the combined gate. Independent
privacy/identity analysis can proceed now. Victor also requested **CL20,
priority 3: a maintained minimal ZKP subproject**; [zkp-core](../../zkp-core/README.md)
is its design scaffold, not an extracted library. Existing experiments remain.
No production source was changed or GPU launched by this round.
**ZK60 round 8 validated:** Codex completes CL9's production handoff with
exclusive per-writer cache files and atomic publication, preserving complete
entries for concurrent readers. The old code lost 65/96 saves in the new
regression; thread/process, stale-name, reader and cleanup controls pass with
the fix. ZK v3 now reports cache hits/misses. **151 Rust tests, 144 Python/native
tests with zero skips, four frozen proofs, cold/warm full-byte cache parity
and public-receipt checks pass.** [Closure and validation provenance](ZK60_ROUND8.md)
separate the full run from the final cleanup retest. Reviews/todos are already
pushed as `a0495dc`; independent privacy review and final GPU gates remain open.

**Historical round-8 launcher correction (successful later run reviewed above):** the final floor launcher has deadlocked
**twice** by taking `/tmp/zk-build.lock` outside `cl1_floors.sh`, which requests
the same lock inside. Both attempts stopped before compilation; Codex
terminated only their waiting lock requests with approval. **Do not repeat
that wrapper.** Use the outer heavy lock only:

```sh
flock /tmp/zk-heavy.lock /home/victor/wt-zk60-cl1/results/cl1_floors.sh /tmp/zk60-final-floors-fresh
```

Choose a fresh scratch directory and put that command inside the usual
detached log/exit-marker wrapper, without an outer build lock. Pick up H1
isolation from published `3ff8d5f` before the final gate.
[Round-8 review](ZK60_ROUND8_CLAUDE_REVIEW.md) records 215 passing CPU tool
tests, resolved findings and new CL6/CL7/CL11 follow-ups. Codex owns CL9's
`wcache.rs` and ZK driver-report fix; its final Rust/cache checks and the
144-test Python/native suite pass as recorded above.

**ZK60 round 7 validated:** the [actual FFN diagnostic](ZK60_FFN_MASK_DIAGNOSTIC.md)
reproduces tiny X/h16 recovery and T32 linear-functional disclosure from
verified P1/P3 proofs, including fresh randomness. It changes only unit-test
instrumentation; the independent joint privacy audit and repair remain open.
H1 verifier fixtures are process-isolated to fix their compact-PCS test race.
**147 Rust tests, 144 Python/native tests with zero skips, four frozen full
proof hashes, B4 parity and separate-process B5 verification pass**; the 63
library tests also pass at sixteen test threads. [Round-7 closure](ZK60_ROUND7.md)
and [evidence](../../results/zk60_round7_validation.json) record the result.

Claude Fable's committed responses are reviewed through `9b24975`. Earlier
raw-allocation, missing-feature and planner lifetime findings are superseded;
the remaining warm-pool fallback boundary and CL4 parser/final-source gate
are in the [integration review](ZK60_CL1_INTEGRATION_REVIEW.md). The
[CL5/CL9](ZK60_CL5_CL9_REVIEW.md) and [CL8/CL10](ZK60_CL8_CL10_REVIEW.md)
reviews add reproducible CPU findings to the existing todos. Lane source was
not edited or merged. The historical round snapshots below retain their
original counts and writing-time status.

**ZK60 round 6 validated:** [B5 public two-block composition](ZK60_PUBLIC_CHAIN.md)
passes 143 integrated Rust tests, all 144 Python/native tests (zero skips),
four frozen CPU artifacts and separate-process byte verification of a
4,290,981-byte receipt. Layer order, external context/tensors and the actual
public residual seam are authenticated; genuine inconsistent constituents and
freshly rebuilt boundary mismatches reject. [Round-6 ownership and closure](ZK60_PARALLEL_ROUND6.md)
and `results/zk60_round6_validation.json` record exact evidence. This remains
public-only, not private generation or a speed result.
The reviewed Claude/Fable handoff is pushed as `606a24e`: CL2 source fixes are
present at pinned `6e28b6f`, but CL3 accounting/fallback parity and CL4 timing/
GPU-required/full-hash gates still hold integration. Claude's concurrent edits
were excluded. [Fable's priority queue](ZK60_FABLE_QUEUE.md) includes the
source-derived actual-FFN mask inventory; the attempted reproduction worker
produced no implementation or executed result. The independent privacy gate
remains outstanding. GPU/PCS ownership is unchanged.

**ZK60 round 5 validated:** round 4 is committed and pushed as `5657a8d`;
the expanded Claude queue/review is pushed as `4a58f12`. H1/R1 continuation
passes 129 Rust tests, 144 full Python/native tests (zero skips), four frozen
CPU artifacts and public receipt byte parity. The reported fixture-path
failures are repaired; both formerly skipped real-data smokes now pass.
Victor requested continued implementation and a substantial Claude queue:
[ten Claude tasks, CL2–CL11](ZK60_CLAUDE_QUEUE.md), with explicit dependencies,
file ownership and acceptance. [CL1 review](ZK60_CL1_INTEGRATION_REVIEW.md)
holds integration pending correctness/fallback/measurement follow-ups; observed
tip `c9fc897` includes the pooled-memory correction. Codex verifier hardening
and full Python fixture selection are validated in [round 5](ZK60_PARALLEL_ROUND5.md).
Claude's GPU/PCS ownership continues; the memory planner transfers to Claude
for CL3. Fable's independent privacy/identity gate remains outstanding.

**ZK60 round 4 validated and pushed:** [overall milestone map](ZK60_STATUS.md) separates
completed public/private components from the full private-LLM and performance
gates. [Round-4 ownership](ZK60_PARALLEL_ROUND4.md) covers the new externally
bound public receipt and bounded component codec. 124 Rust tests, 48 targeted
Python tests and four frozen CPU proof artifacts pass; separate-process
verification of the 2,144,946-byte public receipt passes. Claude's CL1 handoff
below is delivered on `zk60-cl1`, not merged; integration review and the broader
Python fixture-path repair are Codex's next tasks. GPU/PCS ownership and
Fable's independent privacy review remain reserved.

**ZK60 round 3 integrated:** prior work is pushed as `24ae746` on the existing
performance branch. [Round-3 handoff](ZK60_PARALLEL_ROUND3.md) covers the
executed attention metadata schedule, fixed-oracle P0 block proof and reviewed
pending private-FFN interface proposal. The tiny public block's real internal
X/Z seams and approved weight roots verify; rebuilt mismatches reject.
This is not a private block or an application input/output-bound receipt.
Privacy audit remains a gate; Claude's existing task and reserved files remain
untouched. Exact combined checks are in `results/zk60_round3_validation.json`.

**2026-09-04 execution queue:** Victor requested implementation of the
60-tokens/s plan and documented work for Fable and Claude. See
[ZK60_EXECUTION.md](ZK60_EXECUTION.md) for scope, ownership, acceptance
gates and handoffs. Fable's identity review is ready for pickup; Claude's
GPU-memory task is **queued after its current task**, not an interruption
or replacement of that work. Codex's foundation changes were developed in
an isolated checkout; the validation record distinguishes completed checks
from the full-scale benchmarks still pending.

**Integrated: complete-PoC parallel round 2:** see
[ZK60_PARALLEL_ROUND2.md](ZK60_PARALLEL_ROUND2.md). Victor approved
autonomous work on complete private proofs, end-to-end profiling and a
focused literature review. The fixed block contract, causal witness oracle,
experimental equality receipt, CPU attribution and research are integrated:
94 Rust tests, 48 targeted Python tests and four frozen CPU proof gates pass.
A pre-existing singleton mask-rank hazard requires independent review before
private application use. [Round 1](ZK60_PARALLEL_ROUND1.md) is also integrated.
Claude's current task and reserved GPU/PCS files were not reassigned; no full
private 8B GPU runs on this laptop. No complete private LLM/60-tokens/s result yet.

Status: LIVE (opened 2026-08-17). Companion to CONTINUATION.md (the
phase plan) and PROGRESS_UPERF.md (the ledger). This page exists so
that ANY agent — Claude, Grok/Cursor, a human — can advance the
prove/verify clocks without reopening design. Every task below names
its files, its exact commands, and a byte-identity acceptance. If a
task's acceptance fails, revert the task's code and record the failure
here; do not "fix forward" into the transcript.

If you are Grok/Cursor: read Section 0, then start at Section 3, take
the first task in the ORDER Section 0 names, and follow it literally.

## 0. HANDOFF STATE (the orchestrator keeps this current at every push)

WHY THIS SECTION: Victor's Claude usage can run out MID-TRANCHE. When
that happens the repository must be continuable by Grok alone. This
block is the always-current answer to "what is going on and what do I
do". If the AS-OF date below is stale by more than a day, trust the
ledger's newest Agent-status sections over this block.

**AS OF 2026-09-04 22:xx (NEWEST BLOCK. ZK60 TASK CL1 IS DONE:
**P3 RUNS ON THE DEVICE AT MISTRAL WIDTH**, which it could not do this
morning, and the surcharge lane AM had to leave unmeasured is +20.0%):**
- **LANE `zk60-cl1` (worktree `wt-zk60-cl1`), branched at `87c5338`,
  pushed, NOT MERGED** — integration is Codex's/Victor's call, not this
  lane's. Full record: `docs/zkmatrix-poc/ZK60_CLAUDE_GPU.md`.
- **THE DEFECT WAS AN ASYMMETRY.** `dev_commit_from` (non-hiding) has
  chunked by size AND fallen back to chunked on allocation failure since
  [UPERF3-AC]; `dev_commit_zk_from` (hiding) took both `rows*nn` buffers
  unconditionally and died. Rung 1 derived the peak BEFORE running
  anything: `[rows*(n+q+2*nn)+nn]*8` = **12,142 MiB on an 8,188 MiB
  card**, whose largest single take is **5,387.0 MiB — exactly the
  `cuMemAlloc(5387 MB)` of the morning's failure**, pinning it to
  `d_coef2`. Even had that succeeded, the phase needs 12.1 GB.
- **IT COULD NOT SIMPLY MIRROR THE NON-ZK CODE**: `columns_chunked`
  re-encodes with neither pads nor coset scaling, so dropping `enc`
  without a pad/coset-aware opening would have **silently produced wrong
  openings**. `columns_chunked_zk` was mandatory, not tidy.
- **MEASURED** (one Mistral layer, d 4096 / f 14336, T=512, one session,
  same binary and seed, BOTH ARMS ON THE GPU, single run):
  **PROVE P1 3.453 s -> P3 4.142 s = +20.0%**; bytes +0.163%; VRAM peak
  5,182 MB (P3) vs 5,282 (P1); the device commit **TAKEN** where it was
  DECLINED. Both digests reproduce lane AM's rung-2 values exactly
  (`b5da6c38..`, `190e85a1..`), and AM made its P3 digest on the CPU
  fallback — so this is also a CPU/GPU byte-identity gate at real width.
  Four layers: VRAM peak **FLAT** at 5,182 MB.
- **THIS RETIRES AM's CAVEAT.** "P3's structural cost at Mistral width
  REMAINS UNMEASURED" and "do not quote 4.26 -> 15.82 s" are answered:
  the 3.71x was an artefact of the device decline, as rung 2 suspected.
  The same layer is **15.82 -> 4.142 s = 3.82x** purely by fitting.
- **AND IT CORRECTS THIS BOARD'S OWN EARLIER ENTRY TODAY.** The line
  "the 16 GB+ board is what makes sub-3% the DEPLOYED figure ... P3
  cannot get on the device at all at this width" is **too strong at
  Mistral width** — chunking puts it there on 8 GB. The bigger card is
  still what the 8B pass and the fast tier's spill want.
- **GATES**: `results/cl1_floors.log` exit 0 — **12 byte gates** (4
  fixtures x CPU / GPU / GPU with `HL_ZK_CHUNK=1` forced), the CL1 GPU
  oracle suite 6/6 **including a negative control** that proves the
  oracle discriminates, and **105 crate tests**. `HL_ZK_CHUNK=0` retains
  the pre-CL1 resident path byte-for-byte.
- **NEWLY POSSIBLE, DELIBERATELY NOT RUN**: the 32-layer 8B P3 pass on
  the device. The brief says stay small without the 5090 and this box
  froze three times today. Launch it detached under the heavy lock with
  a `.done` marker, `nvidia-smi` near 0 first, and grep for `gpu: ON`.
- **A PRE-EXISTING RED, NOT THIS WORK's**: `python3 -m unittest discover
  -s tests` is **3 failures + 1 error** of 81 (lane AO reported "one
  error"; the fuller count is `test_ring_freeze_check`,
  `test_freeze_rows_uagb1_bf`, `test_pass_smoke_real_data`,
  `test_freeze_rows`). ONE root cause: they want
  `results/m125_ffn_export/`, and this box has the activation planes in
  `results/m125_ffn_export_wsl/` (which is what `M125_EXPORT_DIR` and
  the byte gates already point at). `tests/` is nobody's lane right now
  — it needs an owner, and CLAUDE.md treats this suite as load-bearing.

**AS OF 2026-09-04 11:1x (THE 8B PRODUCT
NUMBER REPRODUCED BYTE FOR BYTE ON A SECOND TREE; A THIRD BOX FREEZE,
AND THE CULPRIT IS NOT THE ONE THE LEDGER NAMED):**
- **THE BOX FROZE A THIRD TIME, at ~11:06.** Boots today: 10:15, 10:31,
  11:07. Nothing was lost — the tree is clean, `git fsck` exits 0, there
  are no zero-byte objects (the `core.fsyncObjectFiles=true` fix from
  the block below did its job) and nothing was unpushed.
- **LANE AM RUNG 3 RAN, and its FAST TIER IS GREEN**: the 8B P1 pass
  reproduces lane AI's round-14 product number EXACTLY — sha256
  `930ce9a0..`, **1,285,578,368 B** — on a tree that does NOT carry AL's
  host-wall fix. Recorded in **80c2ecd** (lane pushed). Prove read
  238.37 s against AI's 265.34; **that is noise, not a speedup** — there
  is no mechanism for it in AM's tree and this box's ~2x run-to-run
  variance covers 10%. **The byte identity is the result.**
- **THE FREEZE WAS THE P1 ARM's SPILL, NOT P3's ALLOCATION.** This
  corrects the prediction rung 2 left behind. The P1 arm's `vram peak
  8585 MB` on an **8,188 MB** card made the kernel log
  `dxgkio_make_resident: Ioctl failed: -12` in pairs **every ~2 minutes
  for that arm's whole six minutes** (10:59:30, 11:01:35, 11:03:41,
  11:05:48), and journald's last record of the boot is 11:05:48 —
  **three seconds BEFORE the P3 arm even started.** P3's clean-fallback
  half worked exactly as predicted (declined 5387/449/378 MB, proved
  layers 0 and 1 on the CPU at 19.6/20.5 s, layer 0's 40,251,860 B
  matching rung 2's P3 layer size byte for byte); it was simply started
  against a card that P1 had not released.
- **NEW STANDING RULE (widens rung 2's, which is not enough alone): the
  8B P1 pass is ITSELF a freeze risk on this 8 GB card.** Never chain a
  second GPU pass behind it inside one script — WSL does not return VRAM
  promptly, so the second pass starts against a full card. Run the tiers
  as SEPARATE detached jobs with `nvidia-smi` verified idle between them.
- **RUNG 3 IS COMPLETE — THE FULL TIER PROVES AN 8B MODEL** (c6089fe,
  lane pushed). The salvage arm (P3 alone, `HL_GPU` unset so the binary
  cannot touch the device and cannot freeze the box) came back
  **ACCEPT**: `1fee4813..`, **1,287,678,592 B**, PROVE 499.04 s,
  **VERIFY 1.99 s**, exit 0. Three results:
  - **Hiding the weights at 8B costs +2,100,224 B = +0.163% of bytes.**
    Rung 2 measured +0.16% at ONE Mistral layer; full model and single
    layer agree to three digits. **The full tier's overhead is TIME,
    not bytes**, and that now holds at product scale.
  - **VERIFY DOES NOT MOVE** — 1.99 s vs P1's 2.02 s. Hiding the weights
    costs the verifier NOTHING. For a deployed product this is the line
    that matters most.
  - Operational: leaving `HL_GPU=1` when the device commit cannot fit
    costs **~25%** (19.6/20.5 s per declining layer vs ~15.3 s with the
    GPU off) — launch a P3 pass with `HL_GPU` UNSET, do not merely let
    it decline. And max RSS is **13.97 GB on a 15 GB box**: nothing may
    run beside the full tier at 8B.
- **THE ONE-AXIS ANSWER, AND IT IS THE HEADLINE: HIDING THE WEIGHTS
  COSTS UNDER 3%** (32fbad7). The P1 baseline on the SAME CPU path,
  same binary, seed and shape — mode the ONLY variable:

  | | P1 (public W) | P3 (private W) | cost of hiding |
  |---|---:|---:|---:|
  | PROVE | 485.33 s | 499.04 s | **+2.82%** |
  | `commit W` | 214.337 s | 217.694 s | **+1.57%** |
  | VERIFY | 1.95 s | 1.99 s | +2.1% |
  | bytes | 1,285,578,368 | 1,287,678,592 | **+0.163%** |

  **The privacy tier is not a different regime; it is a rounding error
  on the same argument.** Round 14's ruling-grade +178% was ZK vs
  NON-ZK — a DIFFERENT step. Once you are already paying for ZK,
  hiding the weights too is nearly free.
- **THIS CORRECTED AN EARLIER CLAIM IN THIS SAME BLOCK.** It said
  `commit W` was "the full tier's structural cost, 43.6% of the prove",
  comparing 217.694 s to P1's **46.978 s** — but that was P1 ON THE GPU
  WITH THE CACHE, i.e. the two-axis trap. On one axis P1's `commit W` is
  **214.337 s**. `commit W` is ~44% of the prove **in BOTH modes**: it
  is the cost of committing the weights at all, NOT of hiding them.
- **THE HARDWARE ARGUMENT, RESTATED CORRECTLY AND MORE SHARPLY**: the
  16 GB+ board is what makes sub-3% the **DEPLOYED** figure instead of a
  CPU-path figure. On a GPU P1 reaches the device (`commit W` 46.978 s —
  a **4.6x on 44% of the prove**) and P3 cannot get on it at all at this
  width (`cuMemAlloc(5387 MB)` on 8,188 MB). **The full tier is already
  nearly free in principle; only the card stands between that and
  practice.**
- **THE PRIVACY CLAIM AT 8B IS NOW TWO-SIDED AND DECISIVE:**

  | | P1 | P3 |
  |---|---:|---:|
  | int8-class words | 13,845,980 | **148** |
  | runs of >= 100 | 1,009 | **0** |
  | words inside runs | 10,848,770 | **0** |

  **93,554x**, and the structure names itself: P1's run lengths are
  `[(10752, 1007), (10753, 2)]` — 1,007 runs of EXACTLY 10,752 — and the
  W commitment is **10,752 DATA rows**. Those runs ARE the weight
  columns, lying in the P1 proof in full, one per opened position. P3
  removes every one. The 148 caveat is RETIRED: it is one ten-thousandth
  of one percent of the P1 count with no run structure.
- **A GATE PASSED ON THE WAY: the CPU and GPU paths agree BYTE FOR BYTE
  at 8B.** The baseline ran on the CPU and produced `930ce9a0..` /
  1,285,578,368 B — the same digest the GPU gave this morning and the
  same one lane AI recorded in round 14. **Three reproductions, two
  device paths, two trees.**
- **ROUND 15 IS CLOSED.** Lane AM merged (0a59923) and the MERGED-TREE
  FLOORS ARE GREEN: `results/floors_round15_am.log`, exit 0 —
  **8 byte gates** (v2 `50cf7bdf..`, v3 `5f368db6..`, zk `021485e4..`,
  zkv3 `40eb5479..`, each on BOTH binaries), **41/41 tests** (40 + lane
  AM's new one asserting a P3 proof does not verify as P1, a P1 proof
  does not verify as P3, and a function-1 proof does not verify as
  function-2), and **both builds from scratch**. The `zkv3` gate is the
  load-bearing one: it proves AM's mode selector left P1's bytes
  untouched. AM's charter is met in full and no lane is now live.
- **RULED (Victor, console 2026-09-04): "575 W is fine" — THE CONTRACT
  BOUND IS AMENDED, THE CARD IS NOT CAPPED.** `TARGET_CONTRACT.md` §4
  now reads **<= 600 W** (a class of part, not one product's TDP), and
  `BLACKWELL_5090_RUNBOOK.md` §5's cap-and-record paragraph is
  superseded. Still worth taking one `-pl 450` row alongside the stock
  one — not for the contract, for COMPARABILITY with every row measured
  before the ruling.
- **THE TOOLKIT UPGRADE WAS ATTEMPTED AND REVERTED: THE BLOCKERS ARE
  ORDERED, DRIVER FIRST. [TESTED]** NVRTC was moved 12.1.105 -> 12.8.93
  on the quiet box; the next GPU run said `gpu: off (... 
  CUDA_ERROR_UNSUPPORTED_PTX_VERSION, "the provided PTX was compiled
  with an unsupported toolchain.")`. **NVRTC 12.8 emits a PTX ISA that
  driver 566.14 cannot load** — minor-version compatibility covers the
  driver API, not the emitted PTX ISA. Reverted the same minute, GPU
  restored (`gpu: ON — RTX 4070 Laptop, sm_89`), floors re-certified.
  **Upgrading the toolkit ahead of the driver does not clear a blocker;
  it removes the GPU.** Runbook §3a now carries this.
  - **AND IT FAILS QUIETLY**: the binary did NOT crash — it fell back to
    CPU and still printed `PASS ACCEPT`, the reason on one `gpu: off`
    line. **Always grep a run header for `gpu: ON` before believing a
    GPU number.**
- **SO THE NEXT STEP IS VICTOR'S, AND IT IS ON WINDOWS**: install the
  NVIDIA driver **>= 570** host-side. This CANNOT be done from inside
  WSL — the WSL GPU stack takes its driver from the Windows host.
  Everything after it is scripted and quick (runbook §3a): re-point two
  symlinks at `/home/victor/cuda-nvrtc-128` (**NVRTC 12.8.93 is already
  downloaded and waiting**, installed side-by-side so `torch
  2.4.1+cu121` keeps its pinned 12.1.105), bump `cudarc` `cuda-12040`
  -> `cuda-12080`, re-run the floors. ~15 min of quiet box, not a
  tranche-sized window.
- **THEREFORE ROUND 16 IS NOT GATED ON THE UPGRADE** and should open
  now. The old worry — that opening lanes shuts the upgrade window —
  was based on the upgrade being a big operation; it is three commands
  and a floors run, so a short pause later is enough.
- **ROUND 16 IS OPEN (ec02f0d). BRIEFS ARE WRITTEN AND BOTH WORKTREES
  EXIST** — `wt-uperf3-an` (branch `uperf3-an`) and `wt-uperf3-ao`
  (branch `uperf3-ao`), both at ec02f0d. The briefs are in
  `PROGRESS_UPERF3.md` under "## ROUND 16"; each lane's ownership block
  is authoritative and the two share NO file (AN = the statement
  surface, AO = the device/encoding surface).
- **LANE AN IS MERGED AND CERTIFIED — FUNCTION 2 EXISTS.** The ZK
  content filter proves and verifies on the merged tree;
  `results/floors_round16_an.log` exit 0, **8 byte gates, 42/42 tests,
  both builds**. Built form: the single-score predicate
  `z16[row][col] - tau >= 0`, frozen set = literally
  `PredicateSpec { row, col, tau }`, one masked degree-3 sumcheck whose
  claimed sum is the PUBLIC threshold, riding the LAST LAYER ONLY.
  **Cost is under the noise floor** — prove 18.54 -> 18.23 s (the
  predicate arm is the faster one), bytes **+0.3166%** of which only
  **1,200 B is the argument itself**; +0.022% against the 8B pass
  [arithmetic]. New statement digest `3143d424e8990993`, CPU/GPU
  byte-identical.
  - **VERIFY LANE REPORTS, DO NOT TRUST THEM.** AN's closing message
    cited a tip `08bb3ec` that DOES NOT EXIST in the repository. The
    real tip is `af514ac` — verified against the remote, and that is
    what was merged. Everything else it reported checked out.
  - **AND IT FOUND A REAL ERROR IN A RULING**: `PROOF_FUNCTIONS.md` §5
    told it to reuse "the q46 remainder bit-planes tied to q31 by the
    U-L modulus link". **That machinery is in the LATTICE channel, not
    hashline** (`grep -rl q46 hashline/src` returns nothing). §5 is now
    corrected with §5a. **Lesson recorded: a ruling that names specific
    machinery must say WHICH PROVING CHANNEL it lives in, and should be
    grepped before it is written down.**
- **LANE AO IS MERGED — L9 IS TAKEN, AND THE BRIEF WAS WRONG ABOUT IT
  IN EVERY PREMISE.** Merged-tree floors GREEN
  (`results/floors_round16_close.log`, exit 0, 8 gates, 42/42, both
  builds); AO's own gates were TWELVE green, twice (8 standard + 4 with
  the chunked path forced). AO built the attribution harness BEFORE
  optimising — the right order, and it is what exposed the following.
  - **THE THREE PREMISES WERE AJ ROUND-14 FIGURES LABELLED [COUNTED]
    AND NEVER MEASURED.** "1.6e10 butterfly/s vs a 4.6e11 roof" -> the
    kernels actually run at **4.00e10**; the old figure divided W's
    butterfly count by a span that also held the d2h, the allocations,
    the host column assembly and the A and H openings. "66 of 256 GB/s,
    not bandwidth" -> `k_dif_pa` **197.6 GB/s** and dense `k_ntt_p2`
    **200.5**, i.e. **77-78% of the roof and CLOSED — it IS bandwidth
    bound.** "A launch-structure problem" -> launch residue **0.9%**.
    **LESSON, and it is the same shape as §5's: a [COUNTED] number is
    not a [MEASURED] one, and a lane brief must not promote it to a
    premise.**
  - **THREE LEVERS, ALL BYTE-IDENTICAL**: the first `rb` stages of a
    zero-padded bit-reversed transform are a BROADCAST not arithmetic
    (**1.37x**, also on the commit's encode path); a runtime integer
    division per butterfly where the stride is a power of two but not a
    compile-time constant, replaced by shift+mask (**1.18x**, and
    PARITY on the dense kernel already at the memory roof — the
    control); and output pruning, the brief's one surviving suggestion,
    since only **244 of 4,096** residues can produce a sampled column
    (**4.38x** on that kernel).
  - **MEASURED** (small shapes only, as briefed): four re-encode
    kernels **1.484x** (ABBA over four processes, spread 2.5%),
    `columns_chunked` **1.292x**, commit encode NTT 1.156x.
- **ORCHESTRATOR CORRECTION TO AO's OWN PROJECTION — IT UNDERSELLS
  ITSELF.** AO closed by projecting "~4 s off an **86 s** prove, about
  1.05x", and said the pass's largest item is "**38.7 s of host time in
  `layer.rs`**, identified by AJ in round 14 and STILL UNASSIGNED".
  **That is round-14 state and it is stale: lane AL took exactly that
  item in round 15 and merged it** (22b975f). Post-AL the 8B prove is
  **58.40 s**, host time inside the prove is **11.9 s**, and the
  `layer.rs` residue is **~7.5 s**. So the same ~4 s lands on 58.40 s,
  not 86 — **about 1.07x** — and, more to the point, **the device is
  now ~80% of the prove, so device work is worth MORE than it was, not
  less.** The closing line "a 1.48x on device kernels cannot move a
  pass whose largest item is a host loop" describes a pass that no
  longer exists. **This is my error, not the lane's: my brief pointed
  it at round-14 evidence (`hashline_hostwall_gpu.md`) without saying
  AL had superseded the host-wall half of it.**
- **ROUND 16 IS CLOSED**, both lanes merged, merged-tree floors green.
  The lane briefs:
  - **FUNCTION 2 — THE ZK CONTENT FILTER. Its trigger has now fired.**
    The third ruling deferred it with "NOT a lane yet ... it becomes a
    lane when AM reports"; AM has reported. **It needs no further
    ruling**: `PROOF_FUNCTIONS.md` §5 already DECIDED the simplest form
    — binary output, ONE non-negativity fact
    (`y[accept] - y[reject] >= 0`), acceptable set frozen per
    deployment, output committed because it already is, **no new
    machinery** (the q46 remainder bit-plane range proofs tied to q31 by
    the U-L modulus link do this today). Counted cost: one range fact
    per proof, below measurement noise. It builds entirely on the FAST
    tier, which is the tier Victor's second ruling put the headline on.
  - **THE FAST TIER TOWARD 60 TOK/S** (the headline track per the second
    ruling). Unowned device work: **L9**, the opening re-encode 13.83 s
    (1.6e10 Goldilocks mul/s against a ~4.6e11 ALU ceiling and 66 of
    256 GB/s — a latency and launch-structure problem, output pruning
    counts at ~1.6x), the encode NTT 13.88 s, the sumchecks 5.47 s.
  - Measure these ON the new card, not before: tuning against a board
    that spills and freezes is optimising against the wrong machine.
- **THE TELEGRAM ROUTER WAS DEAD ALL BOOT, and would have been every
  boot.** `tg-router`'s pidfile check was existence-only, and after a
  reboot the low pids are handed straight back out — pid 1200 had been
  inherited by a `claude` worker thread, so the router refused to start
  and every approval would have missed its window. `alive()` now also
  requires `tg-router` in the pid's `/proc/<pid>/cmdline`. Running as
  pid 3000.

**AS OF 2026-09-04 10:31+ (WSL box clock — the blocks
below labelled 2026-09-05 are earlier work, the box clock and the
console labels have drifted a day. LANE AL MERGED AND THE MERGED-TREE
FLOORS ARE GREEN; A LOST-COMMIT RECOVERY, AND ITS ROOT CAUSE FIXED):**
- **LANE AL IS MERGED (22b975f) — THE HOST WALL IS GONE.** 8B prove
  **98.54 -> 58.40 s** in a controlled one-session A/B (**1.687x**), or
  **86.00 -> 58.40 s = 1.47x** against the round-14 ledger — quote the
  second against the ledger, it is the conservative one. Proof
  `dc980e81..4536c` BYTE-IDENTICAL, 1,234,936,956 B. **8.77 tok/s at 8B
  prefill, up from 5.20.** Host time INSIDE the prove fell 49.8 -> 11.9 s
  (50.5% -> 20.4% of the total) and all of it came out of `layer.rs`;
  the device columns moved 1-7%, as they must — the lane touched no
  kernel.
- **THE ITEM WAS MISNAMED.** L2b was booked as the plane -> Fp
  *conversion*; it is an **ALLOCATION** item. `vec![Fp::ZERO; w_len]`
  does NOT specialize to `alloc_zeroed` because `Fp` is a user type, so
  every layer single-threadedly wrote 1.4 GB of zeros over ~344k
  first-touch page faults that the fill then overwrote — ~27 s of an
  86 s prove. Fixed by a two-slot host staging pool (`HL_AL_POOL=0` to
  switch off) plus folding the matmuls straight off the int8 planes
  (`HL_AL_I8FOLD=0`). Peak RSS +0.76 GB is the pool by design; VRAM
  unchanged.
- **MERGED-TREE FLOORS GREEN** (`results/floors_round15_al.log`,
  exit 0): 8 byte gates — four per binary — plus `cargo test` 40/40 and
  both builds from scratch. The merged tree's `hashline/` is
  byte-identical to AL's tip 4b00f4a, which additionally passed AL's
  twelve-gate variant.
- **NEXT FACTOR IS DEVICE WORK AGAIN**: the opening re-encode 13.83 s
  (lever L9, still unowned), the encode NTT 13.88 s, the sumchecks
  5.47 s, and the ZK prover still declining the device path at Mistral
  width (lane AI's item). The layer.rs host residue is down to ~7.5 s.
- **A COMMIT WAS LOST AND RECOVERED — READ THIS BEFORE TRUSTING ANY
  REFLOG.** WSL was torn down after 01:37:23 on 2026-09-04 without a
  clean unmount — **THE BOX FROZE** (Victor found it frozen and
  force-restarted it; journald's last record for that boot is 01:37:17,
  six seconds before the corrupt objects' mtime). The lane-AL merge
  commit was in flight: three loose objects were left ZERO-BYTE and the
  branch ref pointed at a commit never written to disk, so every git
  command failed with `loose object ... is corrupt`. **Nothing was
  lost** — both merge parents were already pushed (87da3169 and
  4b00f4a). Recovery: quarantine the empty objects (git skips
  re-creating an object whose file already exists, so a repo stays
  broken until they are moved), `git reset --hard 87da3169`, re-merge,
  re-resolve the append/append ledger conflict keeping BOTH sides. The
  redone merge's root tree hashed to `58b0fa85` — one of the three
  quarantined zero-byte objects — which is byte-level proof the
  reconstruction matches what was lost.
- **WHY THE FREEZE HAPPENED — VRAM, NOT HOST RAM. This is the important
  one.** The kernel's LAST message of that boot, at 01:37:17, was
  `misc dxg: dxgk: dxgkio_make_resident: Ioctl failed: -12`, twice.
  `-12` is ENOMEM and `dxgkio_make_resident` is WSL's GPU RESIDENCY
  ioctl, so **the box died of VRAM exhaustion**; under WSL a residency
  request is backed by host paging, which is why the whole VM froze
  instead of one process dying. It fired four seconds after lane AM's
  rung-2 tamper legs started asking for their **5,387 MB** hiding-W
  commitment on an 8,188 MB card. VRAM was ALREADY contended: the same
  message appears at 00:11:03 and 00:27:52 that night, right after a
  `hashline` SIGABRT (signal 6) from lane AI's binary at 00:10:19.
  **STANDING RULE FROM THIS: never run a second GPU process beside a P3
  pass on the 8 GB box, and check `nvidia-smi` reads 0 MiB before
  launching one.** On a clean box the identical allocation fails CLEANLY
  at the CUDA layer (`cuMemAlloc(5387 MB): CUDA_ERROR_OUT_OF_MEMORY`)
  and falls back to the CPU path — that is the whole difference between
  a completed rung and a nine-hour outage.
- **THE GIT DAMAGE WAS A CONSEQUENCE, AND ITS OWN CAUSE IS ALSO FIXED.**
  A freeze plus a force-restart loses the page cache; git 2.34.1 leaves
  `core.fsyncObjectFiles` at **false**, so loose objects are written and
  never fsynced, and on ext4 `data=ordered` with delayed allocation the
  directory entry survives while the data blocks do not — exactly the
  zero-byte signature. Now `true` in this repo's local config.
  **Worktrees share the main repo's config, so every lane inherits it**;
  other repos on this box (frugal-lm) do NOT — set it there too, or
  globally, if a lost commit would hurt.
- **THE REAL EXPOSURE IS UNPUSHED LANE COMMITS**, which is Victor's
  standing Grok-resumable rule restated: this crash could only ever have
  destroyed work that had not been pushed. It also cost **~9 hours of
  idle box** (01:37 -> 10:31) — the no-hangup protocol cannot help when
  the box is frozen, and this is the SECOND hard stop in ~6 hours of
  wall time (see the 2026-09-04-late block below). Both are now
  attributable to GPU memory pressure, not to sleep settings.
- **LANE AM (uperf3-am, 9893832) — rungs 0-2 DONE and pushed, rung 3
  never run.** MODE P3 EXISTS: the hiding per-proof weight commitment;
  41/41 tests; P1's 12x512 v3 still `40eb5479..` byte-identical.
- **RUNG 2 RE-RAN GREEN AFTER THE TEARDOWN** (killed at 01:37:13 with 3
  lines in the log, re-enqueued on the heavy lock, self-started 10:46:09,
  exit 0). One Mistral layer, d 4096 / f 14336, T=512, GPU binary
  [MEASURED]: **8/8 tamper legs REJECT** and the honest run ACCEPTs
  (`layer 0 (v3) [ZK]: GREEN`); **the clear-value scan goes 180,450
  int8-class words under P1 -> ZERO under P3**, and the size cost is
  **+65,632 B = +0.16%** (40,186,228 -> 40,251,860 B). The privacy claim
  holds at real width and costs essentially no bytes.
- **DO NOT QUOTE 4.26 -> 15.82 s AS THE P3 SURCHARGE.** The P1 arm ran
  the device commit; the P3 arm DECLINED it —
  `cuMemAlloc(5387 MB): CUDA_ERROR_OUT_OF_MEMORY` — and fell back to CPU,
  because P3 forbids the weight cache and must commit W hidingly every
  proof, and that allocation cannot fit an 8,188 MB card already spilling
  at 8,585 MB under P1. So 3.71x is P3-on-CPU against P1-on-GPU on THIS
  box, NOT P3's structural cost, which is still unmeasured at Mistral
  width. **This sizes lane AI's "the ZK prover declines the device path"
  item at 5,387 MB** and makes the 16 GB+ board decisive for the full
  tier as well as the fast one — the 5090 settles both at once.
- **IF YOU ARE PICKING UP LANE AM — THIS BULLET IS SUPERSEDED.** Both jobs
  it used to name are done: rung 2's ledger prose was written in 3e8d0c7,
  and rung 3 HAS run (its fast tier is green and recorded in 80c2ecd).
  Read the 2026-09-04 11:1x block at the TOP of this section instead.

**AS OF 2026-09-05 (ROUND 14 CLOSED — all three lanes merged, floors
green — AND TWO CORRECTIONS THAT MOVED THE PLAN'S ARITHMETIC TWICE):**
- **ROUND 14 IS CLOSED.** AK, AI and AJ all merged; the merged-tree
  floors are GREEN (8 byte gates on both binaries, tests, both builds:
  `results/floors_round14_ai.log`, exit 0).
- **AK — the crash damage is undone, and lever L5 landed.** AG's
  digests reproduce BYTE FOR BYTE on the merged tree (the 12-layer
  full-model pass c91f8713.. at 404,327,452 B exactly, the Mistral
  layer's byte counts exactly, 10/10 legs rejecting) against exports
  regenerated from scratch. Then the CLAIM FOLD: the 12-layer proof
  **404.3 -> 282.2 MB (-30.2%)** with **VERIFY -69%** for +7.1% prove.
  `HL_NO_FOLD=1` still reproduces c91f8713.., so every pre-fold record
  stays checkable. The cause was bigger than AG estimated: a PCS group
  is keyed by the claim's COLUMN TAIL, so 41 points on A cost 13.25 MB
  of the attention half's 27.3.
- **AI — THE PRODUCT NUMBER EXISTS**: the 8B proof, on a GPU, with
  privacy. `pass 32 512 --zk --profile v3`, mode P1, ACCEPT, **265.34 s
  prove / 2.33 s verify / 1,285,578,368 B / sha256 930ce9a0..**, 1.93
  tok/s. **CORRECTION 1, RULING-GRADE: the P1 surcharge is +178% on a
  GPU, not the +4.7% AD measured on a CPU** — the bytes carried over
  (+4.10%) but the time did not, because on the CPU the ZK work hides
  inside 15 s of host arithmetic. NEVER multiply a GPU row by 1.047.
  It is a lever not a wall: helpers + commit H is 146.26 s of the
  265.34 (55%) and the device NTT 119.10 vs 15.85 — recorded as lever
  **L8**. Also: the per-layer VRAM drain is NECESSARY (proven — with it
  off, layer 1 dies at `cuMemAlloc(1514 MB)`), and the 8 GB part SPILLS
  (8,585 MB VRAM on an 8,188 MB card), so layer 0 proves in 4.36 s and
  layers 1-31 in 8.42 s. **A 16 GB+ board should give ~140 s instead of
  265 with NO code change** [PREDICTION] — the cheapest thing the 5090
  settles, on day one.
- **AJ — the host wall gave 1.034x, not 2.4-2.9x.** 8B prove **88.90 ->
  86.00 s**, proof dc980e81.. byte-identical, uploaded 59,861 -> 9,328
  MB (6.4x), VRAM 5,651 -> 5,249 MB, h2d 12.81 -> 8.31 s. Twelve byte
  gates green (four per binary, plus four with the chunked path FORCED
  so the frozen 125M digests exercise the new code). **CORRECTION 2:
  the plan's items were mis-attributed.** B1 conflated the upload
  (13.05 s, AJ's, fixed) with the plane -> Fp CONVERSION, which is in
  `layer.rs`; B4 was wrong outright (serialization is 0.03 s and runs
  outside the prove clock); pinned staging does not raise the h2d rate
  on this box. **38.7 s of the remaining 86.00 s is host work in
  `layer.rs`** — the conversion, the 1.4 GB `w_data` allocation, and
  the folds (8.1 s measured) — a file NO round-14 lane owned. That was
  an orchestration error in the round-14 briefs, not a lane failure.
- **ROUND 15 OPEN: lane AL** owns exactly that item (layer.rs's v2/v3
  FFN prover bodies + pcs.rs). Ceiling **~1.82x** on the prove. The
  device half is already built and byte-gated — AJ's `k_widen`
  reconstructs field elements from packed signed integers and is
  already on the live path. **This item also decides whether the RTX
  5090 buys ~1.4x or ~4x**, so NO headline measurement is scheduled
  before it lands (the card-size test in the runbook is the exception —
  it needs no code).
- **5090 readiness, code half DONE**: AJ added `(10,0) => compute_100`
  and `(12,0) => compute_120` to `arch_str` plus a LOUD stderr warning
  on any generic-PTX fallback. Remaining: CUDA >= 12.8 and driver >=
  570, which must NOT be done while lanes are live (`cuda-root` is
  shared by every worktree).
- **A NEW LEVER NOBODY HAS TAKEN (L9)**: the opening's re-encode runs
  at 1.6e10 Goldilocks mul/s against a ~4.6e11 ALU ceiling and 66 of
  256 GB/s — a latency and launch-structure problem, not a bandwidth
  one; output pruning counts at ~1.6x.
- **WHERE THE PLAN STANDS AFTER BOTH CORRECTIONS**: the 8B VERDICT IS
  UNCHANGED — the counted floor is a hardware bound, not a statement
  about our code, so the honest 8B band (14.9-42.5 today, 31.8-90.9
  with L8) still contains 60 at its top. What moved is how far our code
  sits from that floor. 30B receded twice and now lands at ~32 tok/s
  with every lever at its midpoint, which is the strongest argument yet
  FOR the 8B ruling.

**AS OF 2026-09-04 late (THE HARD REBOOT AND THE RECOVERY; AG AND AI
MERGED; THE 60 TOKENS/S PLAN; ROUND 14 OPEN):**
- **THE BOX STOPPED HARD at 19:14:34 on 2026-09-03** (truncated agent
  transcript, no shutdown record, new boot 23:01) with two lanes in
  flight. Nothing committed was lost: lane AG had committed through
  rung 5 and lane AI through rung 2, and both branches are now pushed.
  What WAS lost is everything the lanes kept in `/tmp` — including the
  ATTENTION EXPORT DIRECTORIES that lane AG's full-layer gates consume,
  so AG's digests are unverifiable until lane AK regenerates them.
  **The lesson is the standing one: durable artifacts go in `results/`,
  never `/tmp`.**
- **LANE AG MERGED (6854d2c) — THE FIRST FULL-LAYER PROOF.** Attention,
  the two norms, the residual stream and the layer-to-layer seam are in
  the statement. The 12-layer 125M full-model pass with seams bound
  ACCEPTS at 94.54 s / 404.3 MB (sha256 c91f8713..), 5.9x the FFN-only
  pass; one full Mistral-7B layer proves in 12.91 s at T = 16 with
  10/10 tamper legs rejecting. **The full-layer surcharge SHRINKS with
  width and GROWS with context** — 6.1x at 125M/T512, 1.17x at 8B/T16,
  1.61x at 8B/T64, AE's counted 2.87x at 8B/T512.
- **LANE AI MERGED AT RUNG 2 (fd8c8c1)**, deliberately not at its head:
  the ZK prover's own device gate is generalized (one Mistral layer in
  ZK on the GPU 16.34 -> 4.94 s, byte-identical; 12x512 GPU ZK wall
  4.06 s p50; 8/8 legs reject at Mistral width), but its rung-3 code
  compiles and was NEVER MEASURED, so it stays on the branch.
- **THE 60 TOKENS/S PLAN (b0c4821), `docs/zkmatrix-poc/U_PERF3_SIXTY_TOKENS_PLAN.md`.**
  Completing the statement costs **3.55x** (attention 2.87x [COUNTED],
  ZK P1 1.047x [MEASURED], the range facts 1.18x [MODEL]). Applied to
  lane YY's H100 cells: **30B honest = 2.3-17 tok/s scaled, 13-39 at
  the counted floor — 60 is OUTSIDE both**; **8B honest = 7.3-53
  scaled, 40-113 at the floor — 60 is INSIDE the floor.** The floor at
  30B is set by hashing 311 GB of encoded activations per proof, which
  no kernel work touches. **THE PoC IS THEREFORE RETARGETED AT 8B** and
  the hashed-byte volume (rate 1/2 and/or a 31-32-bit field) is named
  as the one design change that decides whether 30B follows.
- **ROUND 14 OPEN (e994bb7)**, three lanes on disjoint files: **AJ** =
  the host wall (the four items that are 56-63 s of the measured 95.5 s
  8B GPU pass; lever L2, 2.4-2.9x, the most certain factor in the
  budget); **AK** = regenerate the attention exports, re-establish AG's
  digests on the merged tree, then fold the claims (lever L5); **AI**
  continuing at rung 3 (the 32-layer 8B ZK pass on the GPU — the
  product number under P1).
- Merged-tree floors: `results/floors_round13_merge.log` with a `.done`
  marker; the runner is `scripts/floors_round13_merge.sh`, which carries
  the four gates' exact commands, reference sha256 prefixes and byte
  counts for BOTH binaries. **Check the marker before trusting the
  merge.**
- **RULING (Victor, console 2026-09-04): THE PoC TARGET SHAPE IS 8B** —
  the claim is *60 proven tokens per second, 8B-class model, complete
  transformer layers, mode P1, 512-token prefill, one H100, p95 over 20
  warm runs*, which sits inside the counted floor (40-113 tok/s honest),
  so the remaining distance is kernel quality and not design. TWO
  CONSEQUENCES: the rate/field change is **DEFERRED** (it moves the 30B
  floor, 8B does not need it — no code before a costed memo, and it is
  the 30B follow-on's first question), and **HARDWARE BECOMES BINDING**
  rather than merely cheap information, because the ruled claim names
  its machine and "one H100" cannot be claimed from a laptop.
- **HARDWARE (Victor, 2026-09-04): AN RTX 5090 IS AVAILABLE** and
  becomes the primary development and measurement machine. Full setup
  requirements in `docs/zkmatrix-poc/BLACKWELL_5090_RUNBOOK.md`. The
  three things anyone touching this must know: (1) **it buys only ~1.4x
  until lane AJ's host wall lands** — 56-63 s of the measured 95.5 s 8B
  pass is HOST work a faster device does not touch, so the headline
  measurement must not be scheduled before AJ closes; (2) **the box is
  not Blackwell-ready** — driver 566.14 and CUDA 12.1 against the 570+
  and 12.8+ that `sm_120` needs, plus an `arch_str` arm in
  `gpu/cuda.rs` (owned by lane AJ, requested from it), and the toolkit
  upgrade must NOT happen while lanes are running because
  `/home/victor/cuda-root` is shared by every worktree; (3) **the 5090
  is a 575 W part against the contract's 450 W bound** — cap it with
  `nvidia-smi -pl 450` and record the cap, or amend the contract, which
  is a ruling and not a benchmark-runner's choice. Counted worth:
  1792 GB/s vs the laptop part's 256 (7.0x), 0.53x an H100 SXM, giving
  **21-60 tok/s at 8B honest at the counted floor** — 60 at the top
  edge. With >= 64 GB of host RAM it also brings the 32-layer 8B
  full-model pass home from the Mac.
- **AWAITING VICTOR (one ruling, DEFERRED ON PURPOSE)**: the H100. Do
  not decide it until AJ's host wall has landed and a real 5090 number
  exists — only then is the gap to 60 tok/s known, and the choice
  between renting for a day and doing more kernel work is made with a
  number instead of a band. Already answered and not to be reopened:
  the privacy mode is P1, and the PoC shape is 8B.

**AS OF 2026-09-04 (LANE AH COMPLETE AND MERGED — THE 8B GPU PASS IS
NOW 95 s; the 125M-shaped kernels are gone):**
- **THE 8B GPU PASS: 175.09 s -> 95.48 s** [MEASURED], the proof
  still sha256 dc980e81.. / 1,234,936,956 B (hand-verified); RSS 5.33
  -> 3.80 GB; VRAM 4,175 -> 5,651 MB; **3.02e10 proven MAC/s = 5.35x
  the CPU pass**. **AC's 76 s of declined kernels (44% of the prove)
  is now ZERO**: over 32 layers the zero-check F went 46.64 -> 4.65
  s, zero-check D 7.48 -> 0.79 s, helpers + commit H 35.24 -> 5.36 s,
  and 12.3 GB less is uploaded per pass. One Mistral layer at T=512:
  5.515 -> **3.090 s** (RSS 4.17 -> 2.48 GB). The GPU ZK prove at
  12x512 v3: 4.56 -> **4.16 s**, its table zero-check 0.700 -> 0.322
  s. At the 125M shape the looping kernels cost NOTHING (generic
  0.327/0.085 s vs templated 0.338/0.095) — so the templated kernels
  can be retired; they are kept only because earlier published rows
  were taken with them.
- **TOKENS/S AT 8B: 2.92 -> 5.36** [MEASURED, prefill T=512, P0,
  FFN-only, laptop GPU] — **the low end of lane YY's modelled 5.2-16
  band is now REACHED**, and proven MAC/s 3.02e10 sits inside the
  memo's 2.9-8.8e10. The fix closed the entire share AC attributed to
  declined kernels (1.83x against AC's 1.5x [MODEL]). The remaining
  distance to the band's upper end is FOUR HOST items with known
  byte-preserving fixes (plane->Fp conversion + pageable upload; the
  encode NTT; the opening's re-encode; the Merkle and serialization
  of a 1.23 GB proof) — **none of them a shape problem**.
- **THE NEXT LEVER, now unblocked**: `zk.rs` has its OWN device-shape
  gate (`nb_f == 1 && nb_d == 3`), so the ZK prover still declines the
  device path at Mistral width even though the kernels now exist.
  Generalizing it is the same three-edit pattern and yields **a GPU 8B
  ZK row nobody has** — the product number under Victor's P1 ruling.
  Lane AI opened for it.
- Gates: all four green on BOTH binaries at every rung and re-verified
  on the merged tree; 40/40 tests; 8/8 tamper legs reject through the
  GPU ZK prover. Disclosed by the lane: rung 3 required one tagged
  block in `zk.rs`, which its ownership listed read-only while the
  rung asked for exactly that port; the host arm is the old code
  verbatim and no other line changed.

**AS OF 2026-09-03 late (LANE AE — THE ATTENTION VERDICT, both chains
GREEN at Mistral-7B; the full-layer PROOF is the remaining core):**
- **THE MISTRAL-7B ATTENTION VERDICT [MEASURED]: the attention core
  AND the seams are int8-clean; the residual stream is the one
  poisoned site — as at 125M, unlike Gemma** (whose QK-norm sites
  were dirty). Per-site int8 deltas (nats, first order, 2 val
  windows, ref 1.640302): Wattn +0.0074, Wnorm -0.0004, xattn
  +0.0046, q +0.0006, k +0.0017, v +0.0037, scores +0.0017, exps
  +0.0038, probs +0.0092 (the fixed-point floor), ctx +0.0021, ao
  +0.0799, **xres +9.7232**.
- **THE RESCUE COSTS ONE CLASS MORE THAN AT 125M.** xres at int16
  gives +0.1205 — a 9.6-nat rescue that still MISSES the +0.1 class
  (at 125M int16 gave +0.0000). **xres needs int24**; and `ao`,
  clean on its own, costs the composed stack its class unless it is
  int16. The row to quote: **stack_wide (xres int24, ao int16) =
  +0.0266**, inside the class and better than Gemma's +0.0854. Cause:
  Mistral's massive-activation residual — xres's exponent jumps at
  layer 2 and stays for 30 layers, absmax/p999 ratio 2348. Statement
  consequence: xres and therefore THE SEAM are int24 (two 16-bit
  limbs against the existing table, no new table); ao is an int16
  lookup; the residual class is a per-instance parameter (125M needs
  only int16). Only **2 exp members over 32 layers**. Record:
  `results/m8b_mistral_attn_at_o1.json`.
- **BOTH CHAINS GREEN**: the python oracle (`scripts/attention_hash_ref.py`)
  and the Rust chain (`hashline attn-chain`) reproduce **64/64 tensor
  digests + the chain digest at BOTH 125M layer 0 and Mistral-7B
  layer 0**; a negative control (one flipped input integer) breaks 54
  of 64. No requant bumps at either instance. **Two spec corrections
  the running chain found**: the RMSNorm division is ROUND, not floor
  (floor lost half a step on ~49% of every norm output; no parity
  witness needed — double both sides), and the RoPE requant is
  scale-changing in general (kr needs +1 bit at Mistral layer 0).
- **WHAT ATTENTION COSTS THE PROVER [COUNTED]**: committed elements —
  125M attention 29.11 M vs the FFN half's 8.13 M (**3.58x**; a full
  layer 4.58x); Mistral 103.85 M vs 55.57 M (1.87x; a full layer
  **2.87x**). The six committed per-head T x T planes are 48-65% of
  the attention witness and are **QUADRATIC in the token count**
  while the FFN half is linear — **attention, not the FFN, sets the
  context-length cost**. [MODEL] at each instance's measured rate: a
  125M full layer ~8.6 s (vs 1.88 s FFN-only), a Mistral full layer
  ~45.8 s (vs 15.95 s), a 32-layer FULL-MODEL prove **~24 min**
  against the measured 510 s FFN-only. So the FFN-only 8B proof is
  ~35% of a full proof's cost (it is ~70-78% of the MACs — the two
  fractions differ because attention commits more per MAC).
- **RUNGS 4-5 NOT STARTED** (the full-layer prover/verifier: per-head
  matmul sumchecks with the GQA index, the RoPE coordinate-flip
  zero-check, the fused LogUp with the masked row-sum and division
  checks, the inverse-sqrt limb lookups, two residual pins, the seam;
  then tamper legs and CPU/GPU byte-identity). The lane stopped at a
  fully committed, fully gated boundary with a "WHERE THE LANE
  STANDS" block listing exactly what remains. THE FULL-LAYER ROW IN
  PROVING_CHANNEL_OPTIONS §3 STAYS EMPTY UNTIL IT IS MEASURED.

**AS OF 2026-09-03 late (LANE AD COMPLETE AND MERGED — ZERO KNOWLEDGE
AND THE 8B SEMANTICS ARE NOW THE SAME PROOF; the P1 surcharge SHRINKS
with model width):**
- `--zk --profile v3` is a real path (it was a refusal). NEW GATE:
  `pass 12 512 --zk --seed 1 --profile v3` -> sha256 **40eb5479..**
  (87,697,008 B), CPU (3 runs) == GPU (3 runs); re-verified on the
  merged tree. The other three gates unchanged. ZB's **eight** v3
  tamper legs under `--zk` at T=512, at layer 0 AND at layer 3 (the
  negative-shift branch), CPU and GPU: **8/8 reject each time**, with
  identical rejection strings on both provers; the pass-level requant
  tamper rejects at layer 6.
- **THE HEADLINE, and it is good news for the product ruling**: the
  mode-P1 zero-knowledge surcharge **SHRINKS as the model widens**.
  At 125M it is +16.8% prover / +23.9% bytes; **at 8B width — one
  real Mistral-7B layer at T=512, CPU — it is +4.7% prover (15.73 vs
  15.02 s), +3.9% bytes (40.2 vs 38.7 MB), +0.9% memory** [MEASURED].
  The reason is structural: P1 leaves the WEIGHTS public, and at a
  wide model the weight commitment and its column openings dominate,
  so the masked activation side is a shrinking share. The 32x512 8B
  pass models to ~534 s / ~1,283 MB in mode P1 [MODEL]. **Privacy for
  the inputs is close to free at 8B.**
- One named, unapplied lever: the table zero-check still runs on the
  HOST and is 1.14 s of the 5.63 s GPU ZK prove (20%) — porting it to
  the existing kernels is byte-preserving. Also unapplied: composing
  lane AC's chunked weight commitment so a GPU 8B ZK row exists (the
  8 GB part still declines the 5.4 GB commit in AD's base).

**AS OF 2026-09-03 late (LANE AF COMPLETE AND MERGED — THE PROOF-SIZE
LEVER, with a soundness ruling for Victor):**
- **`--pcs compact`** (`results/hashline_compact_12x512.md`): a
  BaseFold-class commitment (ePrint 2023/1705 [EXTERNAL]) — a batched
  sumcheck whose challenges drive a FRI fold of the same polynomial's
  Reed-Solomon codeword; ALL of a layer's claims on W, A and H become
  one random combination, so it is **one opening per layer instead of
  three**, and the opening's size does not depend on the claim count.
  [MEASURED]: 12x512 v2 **13.5 MB vs 66.8 (4.96x smaller) at 1.87x
  the prover**; v3 17.4 vs 70.8 MB (4.07x, 1.82x); **one Mistral-7B
  layer at T=512: 1.94 MB vs 38.7 (19.9x smaller) at 4.36x the
  prover**. [COUNTED] for the 32x512 8B pass: **~62 MB vs 1.23 GB
  (19.9x)** at ~2,163 s vs 510. The ratio GROWS with the model
  because the old opening grows as the square root of the witness and
  this one grows logarithmically. Tampers: 3 PCS legs at every size +
  4 in unit tests, 6/6 v2 statement legs, 8/8 v3 legs, all rejecting
  at the same sites. Two byte-identical memory fixes on the way
  (no codeword clones; one group streamed at a time) also took
  12x512 from 31.8 to 28.8 s and 2.23 to 1.78 GB.
- **RULING FOR VICTOR (soundness)**: the compact form's total
  soundness is **2^-98.2 at 125M and 2^-95.1 at 8B, i.e. 3-11 bits
  BELOW the Ligero form's 2^-106** and just under the project's
  "~100-bit" class. The deficit is the per-fold field term, so it is
  recovered by a LARGER FIELD or smaller pieces, NOT by more queries.
  Adopt the compact form as a size option at 95-98 bits, or hold it
  until a bigger field lands? Recorded, not assumed; the Ligero form
  remains the DEFAULT and byte-identical (all three gates green).
- **TWO HONEST NON-COMPOSITIONS.** (1) **The size win and the GPU
  speed win do not compose today**: a compact commitment is never
  device-resident, so `--pcs compact` on the GPU binary is 34.96 s —
  SLOWER than CPU-only. The choice is 2.50 s / 66.8 MB (GPU+Ligero)
  or 28.8 s / 13.5 MB (CPU+compact); the four kernels a port needs
  are listed in the record. (2) **The compact form is not hiding**:
  `--pcs compact --zk` is refused. Lane ZA's pad rows and mask rows
  do NOT survive (there are no rows and no systematic positions), and
  four new surfaces are exposed; ZA's CFS-masked sumchecks, salted
  leaves and committed multiplicities DO survive. A ZK-compact form
  needs randomness in extra multilinear VARIABLES (one extra random
  piece in the batch). Free lever counted: a **Merkle cap** removes a
  further 29% of the bytes at zero soundness and zero prover cost
  (~9.6 MB at 125M, ~44 MB at 8B).

**AS OF 2026-09-03 late (LANE AC COMPLETE AND MERGED — THE 8B PASS ON
A GPU, and an honest correction to the throughput model):**
- **THE 8B GPU ROW** [MEASURED, WSL-BOX 8T GPU NOISY-SHARED;
  `results/hashline_8b_gpu.md`]: the same Mistral-7B 32x512 FFN
  statement, `HL_GPU=1` with chunked weight commitments and the
  per-model weight cache — **PROVE 175.09 s (cold cache) vs 510.38 s
  on the CPU = 2.9x; VERIFY 1.09 s; RSS 5.33 GB (CPU 13.99); VRAM
  4,175 MB; 1.648e10 proven MAC/s**; per-layer 5.47 s mean (±3.5%
  over 32 layers). **BYTE-IDENTICAL**: one sha256
  (dc980e81..) over three 1,234,936,956 B proofs — uncached CPU,
  GPU cold cache, GPU warm cache; the fourth configuration (cached
  CPU) closed with a 2-layer Mistral-width triple (CPU 44.69 /
  CPU-warm 37.67 / GPU-warm 10.74 s, all b0efed43..). The weight
  cache is worth ~9 s per GPU pass and ~67 s per CPU pass.
- **THE CORRECTION (ruling-grade, and it touches every projected
  column)**: tokens/s at 8B prefill, mode P0, FFN-only — laptop CPU
  **1.00 tok/s**, which hits lane YY's modelled cell exactly; laptop
  GPU **2.92 tok/s**, which is **1.8x BELOW YY's modelled [5.2, 16]
  band**. Cause, measured: **76 s of the 175 (44%) are still on the
  HOST** — the two zero-checks and the LogUp helper columns are
  declined by the device-shape gate because the GPU kernels are
  templated on the 125M block shape (13/15 tables) while Mistral's
  F-side check has 73. So §3.3's "entirely device-shaped" premise
  is TRUE at 125M (measured 5.3x) and FALSE at Mistral width. A
  block-looping kernel (byte-preserving) models to 105-125 s =
  4.1-4.9 tok/s — still under the band. **Every desktop-board and
  H100 column in U_PERF3_ROUTE_B_THROUGHPUT.md rests on that same
  premise and should be read as an upper bound until the kernels
  are shape-general.** Named levers, in order: (a) the block-looping
  zero-check/helper kernels (~1.5x of the 8B pass); (b) raw-plane
  upload with device-side conversion and pinned staging (~10-15 s).

**AS OF 2026-09-03 evening (ROUND 12 IN FLIGHT — a usage-limit cutout
hit all four lanes at once; all work preserved, lanes relaunched;
lane branches PUSHED):**
- **THE CUTOUT**: the session's model limit killed lanes AC, AD, AE
  and AF within minutes of each other. Nothing was lost: `uperf3-ac`
  had rungs 0-3 committed, `uperf3-ad` rungs 0-1, `uperf3-ae` rung 0
  (with rung-1 results left uncommitted in the worktree), `uperf3-af`
  nothing (its construction left uncommitted). All four branches are
  now PUSHED to origin (`uperf3-{ac,ad,ae,af}`), and all four lanes
  were relaunched with resume protocols that commit within 15
  minutes. STANDING LESSON (already in CLAUDE.md's spirit): every
  lane brief must say "commit rung 0 within 15 minutes and after
  every rung" — the two lanes that did survived the cutout intact.
- **PRESERVED, ALREADY MEASURED (on the lane branches, not yet
  merged)**: **lane AC rung 3 — THE FIRST 7B-WIDTH LAYER PROOF ON A
  GPU**: Mistral-7B layer 0 at T=512 with `HL_GPU=1`, the weight
  tensor committed in 11 chunks of 1,024 rows (it was DECLINED
  outright at 5.4 GB before): **PROVE 5.56 s cold / 4.94 s warm
  cache vs 16.55 s on the CPU, RSS 4.2 GB (CPU 12.7), VRAM peak
  4,175 MB, proof sha256 179ec2fb.. byte-identical across
  CPU/GPU/cold/warm** [MEASURED]; the per-model weight cache works.
  **Lane AE rung 1 (partial)**: the Mistral-7B attention calibration
  gate ran EQUIV green (hooks-off walker bit-exact: hidden 97deb9f4..,
  logits 885b401b..) and STATS (263.6 s, 4 windows), and got 6 of its
  attribution sites — baseline 1.6403, Wattn +0.0074, Wnorm -0.0004,
  xattn +0.0046, q +0.0006, k +0.0017 — **all clean so far**; the
  remaining sites include `xres`, the ONE poisoned site at both Gemma
  and 125M, so the verdict is still open.

**AS OF 2026-09-03 (ROUND 11 CLOSED — eight lanes; THE FIRST FULL 8B
FFN PROOF measured; RULING: mode P1; ROUND 12 OPENED):**
- **RULING (Victor, console 2026-09-03: "Let's continue with private
  inputs/ public weights for now, but add private weights as a
  todo")**: the product privacy mode is **P1** (inputs/activations
  private, weights public; lane ZA's `--zk`). **TODO T18 — private
  weights (P2/P3)**: lane ZZ's option 2 (per-model Poseidon2 weight
  tree + per-proof ZK inner proof of the column check; ~2 lane-weeks;
  spikes O2-1..O2-3; a written simulator required). Not started.
- **THE CLARIFICATION (Victor asked whether the Mistral proof was
  "full, attention and everything")**: NO — the 2026-09-03 proof is
  FEED-FORWARD ONLY (three matmuls + SiLU table + requant/range
  facts, all 32 layers, one transcript); attention, RoPE, the norms,
  the embeddings/head and the layer-to-layer seams are NOT in it
  (the same "FFN tower" limitation as the lattice line's composed
  statement). FFN-only is ~69-78% of a real token's MACs and an
  unknown share of its proof cost. The full-layer statement is round
  12's long pole (lane AE).
- **THE MEASURED STATE OF THE HASH LINE**: 125M 12x512 in 3.4 s on
  the laptop GPU (byte-identical to CPU); the P1 ZK form +60% on the
  GPU; Mistral-7B 32x512 FFN-only in 510 s on the laptop CPU (14 GB,
  1.23 GB proof; the model predicted 492). The lattice line: every
  lever measured, best 1.77x; no 8B shape has run.
- **ROUND 12 LANES** (PROGRESS_UPERF3.md, self-contained briefs; all
  in hashline/, strict file ownership): **AC** = the per-model weight
  cache + the chunked W encoding so the 8B pass runs on the GPU —
  the measured 8B GPU number; **AD** = `--zk` composed with
  `--profile v3` (the 8B number becomes the P1 number); **AE** =
  ATTENTION + norms + seams in the statement — the full-layer proof
  (calibration gate on Mistral attention -> python oracle -> Rust
  chain -> the proof at 125M -> a Mistral full layer); **AF** = the
  proof-size lever (a compact PCS behind `--pcs compact`; 1.23 GB ->
  MB class). Victor: choice C (hardware) and the Mac's M9.

**AS OF 2026-09-02 late (ROUND 10 CLOSED, ROUND 11 OPENED; three
rulings; the Mac runbook unchanged):**
- **ROUND 10 CLOSED**: all four lanes merged at 0dc31f7, floors green
  on the CPU and GPU binaries. Net: no lever measured makes the
  lattice proof faster than today's pass at 125M (QQ: the two-tier
  opening with preprocessed weights at PARITY, bar 5x; RR: Stage A on
  the GPU at parity only with the batched transport); the wins are
  bytes (2.15-2.25x) and memory (7.5 -> 3.1 GB at 12x128; the first
  Stage-A 12x512 run that fits the laptop, 11.2 GB); the tokens/s
  model puts the lattice line at 2-15 tok/s for 30B prefill on one
  H100 at best. Details in the four lane bullets below.
- **RULINGS (Victor, console 2026-09-02: "Let's do 1) and 2) go ahead
  and work on variant B as well as a separate attempt")**: the
  hash-based comparison prototype STARTS NOW; the kappa-4 helper is
  the full-mode encoding; the batched claim transport is the Stage-A
  transcript form; Variant B is built as a separate attempt. The
  ledger's RULINGS block (2026-09-02) records the reading and its
  revert condition.
- **LANE UU LANDED THE SAME DAY (merged 0f51720; `hashline/` builds
  here in 13 s, 19/19 unit tests).** THE COMPARISON ROW [MEASURED,
  WSL-BOX 8T CPU-ONLY NOISY-SHARED]: the hash-based prototype proves
  the IDENTICAL 12x512 exact-int8 statement (48/48 tensor sha256s and
  12/12 layer z digests reproduced) in **23.0 s p50 prove (21.5-23.7
  over 4 runs, incl. all commitments) + 2.8 s verify, 66.8 MB proof,
  1.56 GB peak RSS, 1.26e9 proven MAC/s**; seven tamper legs reject.
  Vs the lattice line: PARITY with its GPU-assisted 21.0 s, 3.5x
  under its CPU-only 81.5 s, 4.3x less memory, 44x larger proofs,
  slower verify (2.8 vs 1.7 s), NOT zero-knowledge, hash-only
  ~100-bit (Goldilocks + deg-2 ext; RS rate 1/4, 256 column checks;
  blake3). Phase shares at 8T: commitments 47%, zero-check sumchecks
  30%, PCS openings 17%, matmul sumchecks 6% — all GPU-native work;
  UU's estimate for the RTX 4070 port: ~1.5-2.5 s per pass [MODEL].
  Thread scaling INVERTED beyond 8T on the hybrid part (22T 37-39 s).
  Record: results/hashline_pass_12x512.md; PROVING_CHANNEL_OPTIONS.md
  §2 status + §3 row. FOLLOW-ON LANES OPENED: **XX** = hashline on the
  GPU (proofs byte-identical CPU vs GPU; the measured wall); **YY** =
  the Route-B throughput model (lane TT's seven items for the hash
  line, incl. the ZK surcharge — Victor's ZK rule is non-negotiable —
  and the proof-size lever).
- **THE FIRST FULL 8B FEED-FORWARD PROOF (2026-09-03, orchestrator-run
  on the laptop; `results/hashline_mistral_32x512.log`)** [MEASURED,
  WSL-BOX CPU 8T NOISY-SHARED]: `hashline pass 32 512 --profile v3`
  over the real Mistral-7B v3 export — **PROVE 510.38 s, VERIFY 1.21
  s, proof 1,234,936,956 B (1.23 GB), peak RSS 13.99 GB, ACCEPT**;
  2.886e12 MACs, 5.655e9 proven MAC/s; wall 650 s incl. 136 s of
  witness load + chain; sha256 dc980e81... Phases (summed): commit W
  225.0 s | commit A 81.8 | helpers + commit H 102.7 | matmuls 10.1 |
  zero-checks 58.6 | PCS openings 31.7. Per layer ~15-16 s after the
  first two (24 s, cold). READINGS: (1) the lattice line has never
  run ANY 8B shape (its one-layer rung OOMs this box; T15-T17 wait
  on the Mac); the hash line did the whole stack here in 14 GB. (2)
  Lane YY's model predicted 492 s for this exact cell [MODEL] —
  measured 510 s, +3.7%: the Route-B model's 8B row is now
  VALIDATED, which lends its H100 rows their first measured anchor
  (the hardware factor stays [MODEL]). (3) 225 s of the 510 are the
  weight commitments = per-model work under P0/P1 — the per-proof
  remainder is ~285 s CPU (1.8 tok/s at 8B on this CPU); on the
  laptop GPU (6-7x measured at 125M) ~40-50 s [MODEL]. (4) The
  1.23 GB proof is the sqrt-class size YY flagged; the PCS swap is
  the lever. MAC_RUNBOOK M9 now has a laptop reference number.
- **LANE ZA LANDED (merged; `results/hashline_zk_12x512.md`) — THE ZK
  FORM (mode P1: inputs/activations private, weights public) behind
  `--zk --seed N`.** Built: Ligero/Brakedown ZK pads (256 per row on a
  coset; no systematic column opened) + salted leaves + mask rows for
  every clear vector (5 in A, 5 in H per layer, each asserted at run
  time to touch a mask row); CFS-masked sumchecks via a transcript
  round hook with the last-round extension masking every private
  terminal; a per-layer mask commitment with a product-form test;
  committed multiplicities (histogram rows in A, table-side helpers
  in H, the LogUp identity as one value-0 sum claim); one NEW GPU
  kernel (`k_zk_pad_scale`), no existing kernel edited. IDENTITY: the
  non-zk proof unchanged (50cf7bdf.. both binaries); the ZK proof
  `--seed 1` = 021485e4.. (87,228,528 B) from 3 CPU + 4 GPU runs;
  27/27 tests; 7/7 tamper legs reject under `--zk` on both provers.
  UNIFORMITY (in code, two int8 witnesses x 40 openings): all 37K+
  opened entries distinct and outside the witness range; chi-square
  236-293 vs the 310.5 critical value; the non-zk contrast opens
  42/252 raw int8 values. SURCHARGE [12x512, 8T, NOISY-SHARED, p50]:
  GPU 2.46 -> **3.93 s (+60%)**, verify 0.25 -> 0.38 s, bytes 66.8 ->
  **87.2 MB (+30%)**, RSS 0.78 -> 0.90 GB, VRAM 2.43 -> 3.03 GB; CPU
  14.78 -> 16.55 s (+12%). Above lane YY's counted +2-8% / +1-8%
  because two gaps in the memo's sketch had to be closed (the mask
  row under a challenge-dependent weight -> tied to the last-round
  extension, which also masks the nonlinear terminals; the masking
  polynomial's own ZK opening). STILL REVEALED by design: the
  weights and their opening, shapes, shifts, the table digest. Side
  effect: the non-zk CPU pass 16.9 -> 14.8 s (small rounds
  single-threaded, byte-identical). Open: fold the masked matmul
  terminals into the zero-checks (-8% bytes), the ZK encode on the
  DIF/DIT NTT pair, the table zero-check on the device; composing
  `--zk` with `--profile v3` (the driver refuses the combination
  today with a clear message). Merge note: ZA and ZB both extended
  the driver at the same point; resolved by keeping both blocks with
  composed dispatch; all three byte gates (v2 50cf7bdf.., v3
  5f368db6.., zk-seed-1 021485e4..) re-verified here on both binaries.
- **LANE ZB LANDED (merged fast-forward; `results/hashline_v3_12x512.md`;
  MAC_RUNBOOK M9).** (1) `--profile v3 --export DIR`: the widened-stack
  semantics in hashline (15 frozen int16-out table members regenerated
  and digest-pinned to the engine's; round-nearest requant as the
  balanced-remainder identity; the exact up-scaling branch); the m8b
  export reader: 96/96 (125M v3) and **256/256 (Mistral-7B, 7 GB of
  bins found under wt-uperf3-aa)** tensor sha256s; the exact chain
  reproduces a16/u16/h16/z16 on **12/12 (125M) and 32/32 (Mistral-7B)
  layers**, every range fact holds. (2) The v3 proof at 125M 12x512:
  sha256 5f368db6.. (70.8 MB) byte-identical CPU (3 runs) vs GPU (2);
  CPU prove 17.40 s (+3.5% vs v2), GPU 2.74 s (parity); 8/8 tamper
  legs reject on CPU and GPU incl. the two v3-only legs; the v2 gate
  50cf7bdf.. unchanged. (3) **THE FIRST REAL 8B-WIDTH LAYER PROVEN IN
  THIS PROJECT** [MEASURED, WSL-BOX CPU 8T NOISY-SHARED]: Mistral-7B
  layer 0 at T=16 prove 10.53 s (commit W 8.58 s) / verify 0.03 s /
  25.9 MB / RSS 7.48 GB; T=128 11.67 s / 8.78 GB; T=256 14.51 s /
  10.28 GB — the split ~9 s + 7.0 GB of weight work per layer, ~13.5
  ms + 11.7 MB per token row; T=512 models to ~18 s / 13.3 GB here
  [MODEL]; `HL_GPU=1` declines the 5.4 GB weight commit on the 8 GB
  part and falls back to CPU bytes (a chunked encoding is the
  follow-on). (4) **MAC_RUNBOOK M9 = the first full 8B FFN proof on
  the hash line, on the Mac CPU: all 32 layers at T=16, layer 0 at
  T=512, then the 32x512 pass (~10 min, ~14 GB, 1.2 GB proof
  [MODEL]).** Optional orchestrator-run posted: the 32x512 Mistral
  pass on THIS box (~10 min, ~13.5 GB of 14 available; exit 137 is
  the record) — queued after lane ZA frees the box.
- **LANE XX LANDED (merged; `results/hashline_gpu_12x512.md`) — THE
  HASH LINE ON THE GPU [MEASURED, WSL-BOX 8T + RTX 4070 Laptop,
  NOISY-SHARED]: PROVE 3.40 s p50 (3.38-3.49), VERIFY 0.42 s, the
  proof BYTE-IDENTICAL to the CPU proof (sha256 50cf7bdf.. from 3 CPU
  + 4 GPU runs; 3x16 596b9c79.. both ways), 0.78 GB RSS + 2.43 GB
  VRAM, 8.5e9 proven MAC/s = 6.1x the lattice line's 1.4e9 on the
  same device; all 7 tamper legs reject through the GPU prover.**
  Per-phase (CPU UU -> CPU now -> GPU, s): commit W 2.19 -> 1.98 ->
  0.43 | commit A 3.98 -> 3.64 -> 0.95 | helpers+H 4.58 -> 4.18 ->
  0.50 | matmul g/u 0.77 -> 0.37 -> 0.39 | matmul d 0.60 -> 0.22 ->
  0.27 | zc20 4.50 -> 3.76 -> 0.35 | zc17 2.30 -> 1.75 -> 0.10 |
  openings 3.96 -> 1.43 -> 0.35. Two byte-identical CPU fixes on the
  way (the CPU row is now 17.4-20.9 s; the verifier 2.8 -> 0.3-0.7
  s). UU's [MODEL] 1.5-2.5 s MISSED at 3.4 s: ~1.5 s device time
  (the NTT at ~34 G butterflies/s, far under the part's ceiling) +
  ~1.9 s HOST work the estimate did not count (witness planes -> Fp
  + upload, small sumchecks, Merkle levels, bookkeeping, syncs) —
  all with byte-preserving fixes, none applied; a quieter-box run
  proved in 2.75 s (noise ~20%). FOR THE ROUTE-B MODEL: the laptop
  GPU factor is MEASURED at 6.0-6.8x over the CPU row (YY's [MODEL]
  range was 5-15x — the low-middle), with ~2x more available in the
  host remainder. NEXT (opened): ZA = the hashline ZK form (needed
  under any privacy mode); ZB = the widened-stack (v3) semantics +
  the 8B export reader so the Mac can take the FIRST MEASURED 8B
  PROOF on the hash line (MAC_RUNBOOK M9).
- **LANE WW LANDED (merged; `results/uperf3_ww_12x512_stage_a.md`).**
  (1) THE DEFAULTS: `full` = the kappa-4 helper (confirmed); the
  batched claim transport is the Stage-A DEFAULT, `ZK_RR_ZC_CLAIMS=gg`
  = GG's form (opt-in). **NEW STAGE-A IDENTITY for the floors**:
  12x64 statement 441ca5db.. | transcript c0b8236f..; 12x128
  dc3100e7.. | 1644b4e1..; 12x512 ee87f414.. | e0b3b985.. (CPU ==
  GPU); the old 44528c6a.. / e5085602.. remain reachable under `gg`.
  Full-mode identity: 12x512 8d1ef1a8.., 12x128 4b02815d.., 3x16
  6863f0d6... (2) THE COLD-DESCENT-KERNELS CAUSE, found and fixed:
  RR's zc module kept 3.31 GB of VRAM past the Stage-A phase; k9's
  budget is fixed at init and its idle slabs stay held; the oracle
  leg's ixf tables then declined (free 0.34 GB), fell to k9's upload
  path, and k9's `make_room` fired MID-WAY through the ixf grow loop,
  freed the tables just grown, uploaded to ptr 0 ->
  CUDA_ERROR_INVALID_VALUE -> k9 disabled for the process -> all
  descents on the CPU. Fix (additive, default-preserving; every
  frozen digest unchanged incl. the frozen pass's EVAL-PROOF
  742d88e1../4c259008..): `zc_agg_release()`, room made ONCE before
  the grow loop + `k9_trim_idle()`, called by the driver at the end
  of the Stage-A phase. One-process oracle now matches standalone
  within noise (12x512: 18.2 vs 16.9 s prove, ixf opens 5x).
  (3) THE DRIVER DIET: **12x512 FULL mode 7,156 MiB == range 7,152
  MiB (was OOM at 15.18 / 14.4 GB)**; 12x128 full 8,072 -> 2,884 MiB
  (one h_sum claim per pair — a full-mode transcript change with a
  soundness note; prover objects dropped before verify; the act-h
  claim rows made compact — SS's V4 had counted them DENSE, ~95 GB
  per side at 8B). (4) THE HONEST 12x512 A/B [GPU 8T NOISY-SHARED,
  x3]: oracle standalone 3.3-3.6 / 16.9-17.7 / 3.8-4.4 s (1,509,911
  B, 2,833 MiB); Stage-A RANGE 6.4-7.1 / 18.8-19.1 / 4.6-5.0
  (670,891 B, 7,152 MiB) — prove parity 1.02-1.03x, total 1.15-1.18x,
  bytes 2.25x smaller; Stage-A FULL 6.2-7.3 / 74.5-82.9 / 10.4-14.6
  (900,003 B) — 4.0-4.4x the prove (the scalar-K degree-18 lookup
  sumchecks, 44-47 s) for 1.68x fewer bytes. (5) 8B full-mode memory
  RE-ESTIMATE: **~85 GB [MODEL]** (replaces the lower-bound caveat;
  the pre-diet form would have been ~260 GB). Rulings: the
  pair-level h_sum grounding (soundness note lane-written); k9's
  init-time budget (the driver trim is the mitigation); the
  scalar-K lookup sumchecks are full mode's lever if it ships.
- **LANE ZZ LANDED (merged; `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`,
  1,132 lines, docs only) — THE PRIVATE-WEIGHTS ANSWER FOR ROUTE B.**
  Three ways, one keeps 50 tok/s at 30B reachable: **option 2, never
  send the sampled weight columns** — the weight tree committed ONCE
  per model under an arithmetic hash (Poseidon2; 2-18 min on a GPU
  at 30B, off the clock), and per proof the verifier's column check
  (256 columns x 2,648 rows x 3 inner products + hashes + Merkle
  paths: 5.9e6 Poseidon2 permutations, ~4.4e9 native multiplies at
  30B [COUNTED]) proven inside a fresh ZK GKR/sumcheck proof with
  masked clear vectors. Per-proof surcharge on one H100 50-180 ms
  at the floor, 0.16-3.6 s scaled [MODEL] vs a 3.7-62 s P0 prefill
  proof -> its 30B prefill cells are P0's own (46-137 floor / 7.8-58
  scaled tok/s); reaches 50 under exactly P0's conditions (batched
  or 512-token prefill, upper half of the hardware range, >= ~50
  GB/s device hash rate). Hinges on: the inner ZK prover's overhead
  over native (5-20x, the one uncounted constant), and a WRITTEN
  simulator — the published Orion was found unsound [EXTERNAL,
  ePrint 2024/1164]. Option 1 (re-commit per proof) reaches 50 only
  with >= 16 stacked prefills per proof + a token-streaming
  commitment (258 GB working set). Option 3 (the lattice hybrid) is
  the AUDIT channel, not a throughput route: the lattice weight
  opening is 100-1,000x the hash line's on the same board, and the
  cross-commitment bridge (a Goldilocks-extension claim opened from
  the q31 commitment) has no recorded design — the cheapest honest
  bridge forces a >= 46-bit weight modulus. No fourth way found.
  Batch-1 decode: unreachable for every option. Corrections to YY:
  the recovery horizon is 257/513 proofs at the 8B/30B optimum
  (65 was the 125M set); only W needs the inner proof, not A/H.
  SPIKE LIST with sizes (§7): Z-1 the hashline ZK form (1 lane-day,
  needed under ANY privacy mode); O2-1 Poseidon2 + the W tree behind
  a switch (2-3 d); O2-2 the inner statement + ZK GKR at 12x512 with
  the outer verifier accepting with W columns absent, K_ov measured
  (3-5 d); O2-3 the simulator/extractor (1 d, docs); O2-4 device port
  (an XX rung). **FOR THE RULING: P1 (private inputs) costs 2-8% and
  needs none of this; P2/P3 (private weights) costs option 2's ~two
  lane-weeks to a first measured row.**
- **LANE VV LANDED (merged a630f25; `results/uperf3_vv_variant_b.md`).
  VARIANT B AT THE BAR: NOT MET — 1.77x [MEASURED]** (real 12x512
  weight group, RTX 4070, 8T, per-model part warm, n=5: 1.24 s min /
  1.29 median per proof vs the built opening's 2.20-2.23 s in the
  same run; 2.31x if the built precommit is charged; claims
  byte-identical, wire digest identical x5). Better than QQ's design
  of record (parity) but the floor is the ~200K-ring recursion prove
  (0.39-0.52 s, frozen machinery) + the launch-bound value-fold GEMM
  + the v-pass — the recursion alone exceeds the 0.44 s a 5x bar
  allows at this shape. 8B/30B rows [MODEL on measured constants]:
  14-48 s / 54-201 s per proof = 4.4-15x / 4.6-18x — STRADDLING the
  bar; settleable only by an 8B-shape run (Mac or a desktop board).
  Gates green: +3.45 / +1.74 / +1.42 bits at 12x512 / 8B / 30B
  (QQ's count reproduced). SOUNDNESS (rung 1, before code): not a new
  lemma — the same exact-digit fold-norm law at base 8 (a value ring
  is one balanced digit), 8x fewer MSIS columns — but a NEW PROTOCOL
  OBLIGATION: the int8 range of the value tier must live in a
  per-model certificate (digit planes + recomposition claims + a
  second opening of the value-tier commitment) or a per-proof 256-row
  lookup; neither built. Two attribution fixes landed (QQ's clock
  carried 0.3-0.5 s of differential bookkeeping; the fold's "host
  tail" was a serial challenge draw, now pooled 0.37 -> 0.08 s).
  RULING ITEMS: the int8-value class row; the per-model weight
  certificate form; the pooled draw as a prover-side form. FOR THE
  THROUGHPUT MODEL: the lattice line's 30B band is unchanged.
- **LANE YY LANDED (merged 3c4dc8a): `U_PERF3_ROUTE_B_THROUGHPUT.md`
  — the hash line's tokens/s model on lane TT's yardstick.** From
  UU's measured row and the crate's loops: per-model 2.19 s (the W
  commit), per-proof weight side 1.52 s (linear, 4.33 mult-adds per
  weight), activation side 19.2 s (84%) at 12x512; scaled: 8B x 512 =
  492 s on the laptop CPU (1.0 tok/s), 30B x 512 = 1,546 s (0.33)
  [MODEL from MEASURED]; hardware factor for this device-native mix
  laptop GPU 5-15x [MODEL until XX], 4090 15-75x, H100 25-180x. **THE
  VERDICT: 50 tok/s at 30B on one H100 is reachable on Route B ONLY
  for prefill / batched proving (B >= 4-16), FFN-only, in modes P0/P1
  (weights public), in the upper half of the hardware range (>= ~90x
  over the CPU row; sustained device hash rate >= ~50 GB/s) — it
  hinges on lane XX's two numbers. Batch-1 decode at 50 tok/s: not
  reachable under any counted assumption (the linear weight opening
  alone is 25-60 ms per proof at 30B vs the 20 ms budget). Under
  P2/P3 (weights private) NO counted cell reaches 50.** THE
  STRUCTURAL FINDING (§4.4): a cached hash-based weight commitment
  leaks 256 encoded columns per proof — the weights are recoverable
  after ~65 proofs — so P2/P3 need a fresh W commitment per proof
  (+44% at 8B x 512, +54% at 30B; 7-23 s of hashing per proof on an
  H100), unless an UNCOUNTED design lands: Orion-class hidden-column
  openings (an inner proof of ~1e9 constraints per proof at 30B) or a
  lattice-hybrid weight commitment (the lattice channel's hiding
  commitment for W, the hash channel for the activations, a ZK
  cross-commitment link). ZK for the activations (P1) is cheap:
  +2-8% prover. Proof size: the sqrt class is 613 MB / 1.5 GB per
  8B/30B proof; a WHIR/STIR-class PCS swap gives 3-12 MB at x0.94-1.4
  prover — mandatory before any decode artifact. **RULING FOR
  VICTOR: which privacy mode is the product?** P1 (open weights,
  private inputs — the natural mode for open-weight models such as
  the Mistral/Gemma checkpoints in hand) keeps Route B on the 50
  tok/s path; P2/P3 (proprietary weights) needs the weight-privacy
  design priced first (a docs-only lane, ZZ, opened for that).
- **ROUND 11 LANES** (PROGRESS_UPERF3.md, self-contained briefs):
  **UU** = the hash-based prototype ("Route B") as a NEW crate
  `hashline/` on the SAME 12x512 int8 statement — Goldilocks field,
  Ligero/Brakedown-class multilinear commitment, the matmul sumcheck,
  LogUp lookups; the deliverable is the MEASURED comparison row in
  PROVING_CHANNEL_OPTIONS.md §3 with tamper legs; **VV** = Variant B
  of the two-tier opening (tier-1 over int8 value rings; QQ counted
  8-15x at 8B) against the original >= 5x bar at the 12x512 weight
  group, soundness note first; **WW** = the Stage-A defaults
  (rulings 2-3), the cold-descent-kernels finding from leg C, the
  driver diet so 12x512 runs in both Stage-A modes on the laptop,
  and the honest 12x512 A/B.

**AS OF 2026-09-02 (ROUND 10 OPENED — the throughput round; the Mac
runbook is the Mac's queue):**
- **THE GOAL (Victor 2026-09-02)**: >= 50 proven tokens/s for a
  30B-class model on ONE GPU (H100-class allowed) — "the competition
  to beat" is the Attestable claim (53/77 tok/s, one H100, [EXTERNAL]).
  START_HERE.md §2 has the conversion; lane TT owns the honest model.
- **ROUND 10 LANES (PROGRESS_UPERF3.md, self-contained briefs)**:
  QQ = the two-tier opening + WEIGHT PREPROCESSING on the GPU cost
  model (count, build, measure; the reopen bar = per-proof
  weight-side opening >= 5x the built GPU path at the 12x512 weight
  group, claims bit-identical); RR = Stage A's aggregate on the
  device (measures the factor the 2026-08-30 board line guessed at
  1.2-1.5x — that line is UNSOURCED, see below); SS = committed-h
  V1-V4; TT = the tokens/s model + the audit of the unsourced line.
- **LANE TT LANDED (merged aae3478): `U_PERF3_THROUGHPUT_MODEL.md`
  — THE TOKENS/S MODEL, every number sourced.** The verdict, plain:
  the built system is a ~0.6-0.8 tok/s system at 8B prefill on the
  laptop and ~0.0025 tok/s at batch-1 decode (every proof re-proves
  the whole weight side) [MODEL from the one measured pass]; the
  recorded design path (Stage A + two-tier opening + weight
  preprocessing), at its OWN modelled constants, gives **2-15 tok/s
  at 30B prefill and 0.05-0.7 tok/s at 30B decode on one H100
  [MODEL on MODEL]**, 3-30x lower at the constants the spike
  measured. **Under no assumption recorded in this repository does
  the lattice line reach 50 tok/s at 30B on one GPU.** Batch-1
  decode is floored by reading the weight digits (13 of the 20 ms
  budget even packed and H100-resident); 512-token prefill makes the
  weight side irrelevant and turns the question into the
  activation-side proving rate: 1.6e12 MAC/s needed vs a best
  modelled 0.5-3.3e11 (U2, memo §7.4 — no lane measures it; it is
  the choice-D question). Round 11 is cut from QQ rung 4, RR rung 5
  and Mac M5 — not from any tokens/s number.
- **LANE RR LANDED (merged; the measured Stage-A-on-GPU factor —
  `results/uperf3_rr_stage_a_gpu.md`).** The aggregate zero-check
  prover on the device: 5.0-5.9 s -> 0.58 s (**8.6-10x**,
  bit-identical, agg-battery 46234986.. with the device forced on
  every aggregate). But the Stage-A prove WALL with lane GG's claim
  transport only moves 17.6-19.4 -> 13.4-13.5 s (**1.31-1.44x** —
  the number the retracted line guessed), and Stage A stays
  1.36-1.40x SLOWER than the built pass at 12x128, because the
  critical path is the act-group opening's per-contrib phases (~700
  rank-1 plane claims). With an opt-in BATCHED claim transport
  (`ZK_RR_ZC_CLAIMS=batched`; a Stage-A transcript variant, served
  values unchanged, the claim count 997 -> 439 — **RULING ITEM**):
  Stage-A prove == oracle prove (7.5 s, 1.00x), verify at parity,
  total 1.14x (the planes commit +1.6 s), and **peak RSS 7.5 -> 3.1
  GB** at 12x128. FOR THE THROUGHPUT MODEL: Stage A + GPU buys NO
  speed over the built pass at 125M — it buys bytes (2.15x) and
  memory; the opening is 70% of the prove wall (lane QQ's territory).
  Two device races found and fixed. **Leg C at 12x512 (batched, GPU)
  RAN AND FITS: commit 6.1 / prove 17.9 / verify 4.5 s, 670,891 B,
  accept, 11.2 GB process peak** — the first Stage-A run of the
  reference shape on this box; vs the frozen pass's Aug-18 QUIET row
  (prove 15.5 s) that is parity-class at 2.25x fewer bytes. (Its
  in-process oracle leg ran with cold descent kernels — not the
  reference; see the ledger.) Legs A/B are Mac-only (M1b). All round
  10 floors green on the merged tree, CPU and GPU binaries.
- **LANE QQ LANDED (merged 6b6ae1f; floors green on the merged tree:
  diff-battery 17.2 s, freeze-check 102 ok exit 0, 3752cba4.. /
  46234986.. / be89d5da.. unchanged, range 12x64 digest 44528c6a..
  unchanged). THE REOPEN BAR IS NOT MET — MEASURED 1.00x**: the
  two-tier opening with the weights PREPROCESSED (per-model part
  built once, 2.34 s, held warm) proves the real 12x512 weight group
  in 2.08 s per proof vs 2.09 s for the built GPU opening [WSL-BOX
  8T GPU NOISY-SHARED], claims byte-identical across 3 proofs. On
  the way: the redesign memo's C-R1 count was wrong AGAINST itself —
  the swap-order linear pass is ONE existing GEMM, so on 1 CPU
  thread the spike goes from 1.10x to 3.42x [MEASURED]; but on the
  GPU the built opening already runs that GEMM class, and the
  two-tier's own floors (a ~200K-ring recursion, a fold over 8x the
  value rings, a per-tensor host tail) add up to parity. Projection
  [MODEL from the measured constants K1-K8]: 8B weight side 62-75 s
  per proof vs ~210 s built (2.8-3.4x) on the 4070; a "Variant B"
  (tier-1 over int8 value rings, +1.74 bits at the gate) counts at
  14-27 s (8-15x) — a DESIGN CHANGE needing a ruling, not built.
  The per-proof weight lever is now the digit-ring FOLD (58-73%),
  not the linear pass. **For the 50 tok/s question this settles U1
  at the low band: the lattice line's 30B one-H100 prefill cell is
  the (c') class (~0.5-3 tok/s), not (c).** Weight preprocessing
  itself WORKS and is bit-identical (the per-model/per-proof
  boundary exists: `uperf-t repeat`).
- **LANE SS LANDED (merged 827e90b; floors green on the merged tree:
  diff-battery 16.4 s, freeze-check 102 ok exit 0, 3752cba4.. /
  46234986.. / be89d5da.. unchanged, range 12x64 digest 44528c6a..
  unchanged).** FINDING that corrects the committed-h memo: the
  full-mode "act-h group" is the S2 LogUp HELPER of the SiLU lookups
  (one helper per key, 2 digit rings each), not a range-fact
  commitment of h — so routing range facts through lookups (the
  memo's C2) costs 32x MORE, not less; C2 is retired. What works
  instead: a kappa-level partial-fraction helper (kappa 4 = degree
  18) that cuts the act-h group 16x — **12x128 full mode now runs at
  8,072 MiB (was OOM at 14,777), accept, bytes 860,867**; the 8B
  full-mode peak becomes ~78 GB on OO's 72 GB baseline (~87 GB until
  a claim-kernel diet lands) — the owed recount is CLOSED (the S2
  form would have been ~285 GB and six groups). **TWO RULINGS FOR
  VICTOR**: (1) adopt the kappa-4 helper as THE full-mode encoding
  for T17's freeze set (a Stage-A full-mode transcript change; the
  S2 form stays reachable as `full-s2`); (2) kappa 5+ needs a
  one-line denominator reduction in `sumcheck::lagrange_eval`
  (frozen file, i64 overflow above degree ~20) — not needed for
  kappa 4. **CAVEAT (orchestrator-run, later the same day): the
  Stage-A composed driver at 12x512 OOM-KILLS the 15 GB box in BOTH
  modes** — full 15.18 GB (8.3 GB after the helper commit, 12.2 GB
  after the aggregate checks, killed in the openings), range 14.4 GiB
  (lane GG projected exactly this on 2026-08-28 and deferred the
  shape; the diets since did not bring it under the box). So on the
  laptop the Stage-A reference shape is 12x128 (both modes accept
  there), RR's 12x512 A/B is Mac-only (MAC_RUNBOOK M1b, new — CPU
  numbers for both modes), the 8B full-mode figure (~78-87 GB) is a
  LOWER BOUND until M1b lands, and a Stage-A driver diet (the nrw-88
  zero-check transient ~5 GB, the claim tables, SS's claim kernels)
  is a named round-11 item. The frozen pass at 12x512 is unaffected
  (6.7 GB with the GPU).
- **RETRACTED (lane TT, memo §5.6)**: the 2026-08-30 "~25-35 tok/s
  amortized; levers 1.2-1.5x / 1.3x / 1.1-1.2x -> ~65" line below —
  none of its five numbers derives from anything recorded; the
  nearest recorded row is 13-26 tok/s of an 8B FFN-only model on one
  DESKTOP board [MODEL]; no pipelining or spine-amortization lever
  exists in any design. Weight preprocessing has never been built
  or measured (lane QQ rung 4 is its first measurement).
- **THE MAC QUEUE IS NOW `docs/zkmatrix-poc/MAC_RUNBOOK.md`** — the
  ordered, self-contained list (sync + gate pass, T1 with a thread
  ladder, T13/T14, T15, T16 with the T-scaling leg that measures the
  weight-vs-activation split, T17 both forms). Victor pulls and runs;
  results are pasted back per the runbook's RECORD lines.

**AS OF 2026-09-01 (ROUND 9 MERGED; the speed question put to Victor;
START_HERE.md written):**
- **NEW: `docs/zkmatrix-poc/START_HERE.md`** — the plain-words
  onboarding page (what is built, the measured numbers, why the
  5-15 s goal is hard, what was tried, the five choices A-E, the
  working rules, the map, a glossary). Anyone new reads it FIRST.
- **PP/X2 MERGED (8e2060d)**: the 125M attention calibration table
  (`results/m125_attn_at_o1.json`): core int8-clean without QK-norm,
  ONE poisoned site (xres, rescued by int16), ONE exp member for the
  whole model, stack_wide +0.0314. X3 (one full attention layer
  proven at 125M) is next on the attention ladder.
- The committed-h memo landed (72caf67): the full-mode price is a
  layout artifact; rungs V1-V4 defined for the next round.
- **THE SPEED QUESTION (Victor, console 2026-09-01: "reach the 5-15 s
  per proof goal as quickly as we can" -> "decide how to proceed
  together")**: the recorded state is that the lattice line's
  enumerated moves count to ~100-160 s/board (II's 2026-08-28
  closing verdict); START_HERE.md §7 lists the five choices (A: the
  two-tier opening re-counted and measured on the GPU cost model;
  B: the Stage-A aggregate on the device; C: desktop-class hardware
  under the ladder; D: the hash-based comparison prototype; E: the
  8B MVP on the Mac + committed-h V1-V4 + X3). NOTHING IS STARTED;
  the next round opens when Victor rules.
- Config housekeeping (not project code): the allowlist synced with
  CLAUDE.md (4014cb5); no Bash command has prompted since auto mode
  went on in mid-August.

**AS OF 2026-08-29 evening (MAC-BOX SYNCED to the round-6 tree; full
Mac gate pass green):**
- The Mac pulled 9a8fa3d and now BUILDS — two aarch64 cfg gates were
  missing from the WSL rounds (the `psi_avx2::mac_fold_row` call in
  eval_proof.rs, the sha flag print in uperf-m); fixed, x86
  byte-identical.
- Full MAC gate pass [box QUIET, F2 training not running]:
  freeze-check FULL exit 0 (102 ok rows), suite 81/81 OK,
  diff-battery, uperf-s 48-leg 3752cba4.. + agg 136-leg 46234986..,
  uperf-w 23/23, agg-matmul, bh-verifier, v3 smoke + chain-m125 all
  12 layers, uperf-x 8/8 be89d5da.. Logs:
  `results/uperf/mac_sync_20260829_*`.
- **FINDING**: `pass-agg seam` had been silently broken since
  [UPERF2-Q] — the row-factor memo (keyed (q, s), scale folded in)
  ignores the battery's in-place scale perturbation. Battery
  artifact, production unaffected; the battery now drops the memo at
  the perturbation, seam 12/12 green. The drift-loud-memo question is
  left for Victor. Full record: the 2026-08-29 orchestrator note in
  PROGRESS_UPERF3.md.
- The Mac queue (T13/T14/T15 + the 7B proof rung) is runnable on a
  building, fully gated tree.

**AS OF 2026-08-31 (ROUND 8 MERGED + the day's rulings recorded):**
- **RULED: T17 = BOTH forms; F1 = FULL MODE** (F2 thereby adopted;
  the compact committed-h encoding = the round-9 design item; the
  8B recount owed — see the ledger's 2026-08-31 rulings block).
- **NN/X1 LANDED**: the full attention layer's 66 typed entries
  (spec §4.1 reconciled EXACTLY, 4 deltas flagged), the layer value
  chain byte-identical vs the python oracle at 6 (seed,T) pairs,
  PW-1..4 builders 19/19 F5 legs (digest f2f39137..), per-head
  X-S1 proving 2/2 accepts + 7/7 tampers at pre-registered gates;
  the X3 needs list (10 items, incl. NEW freeze rulings: AM-2 exp
  members, rope rows, range widths). X2 (AT-O1 at 125M) is next on
  the attention ladder.
- **OO/DIET 3 LANDED digest-identical**: the compact BfPlane store
  — 12x64 RSS -23% on top of HH+KK (cumulative -46..47% vs round
  5); **8B: commit ~61 GB, the pass peak now lvl-0 ~72 GB — under
  128 GB with ~56 GB margin (range-form counts); 30B: the layer
  store off the critical list (~40-46 GB), the new 30B peak = the
  weight-group terms ~265-270 GB (future levers named)**. The
  full-mode recount (owed per the F1 ruling) starts from these
  numbers.
- Six battery digests + freeze-check + both anchors green on the
  merged tree. The Mac path unchanged: T15 -> T16 -> T17 (both
  forms).

**AS OF 2026-08-30 late (ROUND 7 MERGED — the PoC sprint's WSL side
is COMPLETE; five battery digests + freeze-check green on the tree):**
- **LL/W-1 LANDED**: the claim tables split at 8B (f k=7, d k=2,
  all under the audited 2^25 cap); null split byte-identical; the
  forced-window battery (zc digest 01ca048b..); honest +139 KB at
  32x512 (corrects the memo's ~30 KB); the yardstick pays +0.
- **MM/THE COMPOSED v3 STATEMENT LANDED**: cross-layer seams BOUND
  (seam-edge MLE pins + the clamp-pair vs a statement-derived
  saturation table + Rs range — all existing machinery classes, no
  registry additions); composed battery 4/4 (digest 7465fa05..,
  surgical rejects incl. the honestly-recorded leg fix); the
  6-layer composed differential PASSED (12L = Mac-class, 10.6 GB
  measured at 6L); **the real-Mistral shape-general smoke is
  PROVABLE (39 legal seam clamps, 0 violations)**.
- **NEW MAC TASK T17 (after T15; KIND=RUN)**: the composed
  32-layer statement — `ZK_MODEL_EXPORT_DIR=<mistral v3 export>
  ring_matmul uperf-v3 composed 16 32` (add `diff` for the 32
  independent-proof differential if time permits; /usr/bin/time
  -l; expect ~40+ GB RSS [MODEL], hours-class at T=16 CPU). THIS
  IS THE WORKING PoC RUN. **RULED (Victor 2026-08-31): BOTH
  forms** — run the declarational composed statement over the real
  export AND the calibrated-tower composed proof (`composed-chain`
  feeds the tower; the same arm family), and the write-up states
  each object's meaning plainly. ALSO RULED: F1 = FULL MODE for
  the freeze set (see the ledger's 2026-08-31 rulings block: F2
  thereby adopted; the compact committed-h encoding is the round-9
  design item; the 8B memory recount owed).
- The Mac queue order stands: T1 -> T13/T14 -> **T15 -> T16 ->
  T17**.

**AS OF 2026-08-30 (MAC SYNC MERGED + the PoC sprint scoped):**
- **THE MAC GATE PASS IS GREEN** (0aed842, box QUIET): freeze-check
  FULL exit 0, suite 81/81, every battery digest byte-identical on
  aarch64 incl. the attention spike (be89d5da..); two aarch64 cfg
  gates fixed; the seam battery's silent-vacuity defect fixed
  (battery artifact; +1 ruling: the drift-loud memo).
- **STILL OPEN ON THE MAC (the PoC path, in order)**: T1 (the
  12x512 walls + digests), T13/T14 (Gemma), **T15 (the v3 exports
  + verify-export + the >15 GB per-layer proof rung)**, and THEN
  the NEW milestone: **the 32x16 8B YARDSTICK — the first full
  8B FFN proof (~95 GB, fits the Mac; needs W-1 column-splitting
  first, ~2-3 d WSL CODE — the last named code blocker)**.
- **THE STANDING TARGET (Victor 2026-08-30): ~80 proven tokens/s
  per H100 board at 30B** — currently counted ~25-35 amortized;
  the enumerated levers (Stage-A aggregate GPU port + fold fusion
  1.2-1.5x, pipelining 1.3x, spine amortization 1.1-1.2x) compose
  to ~65; the last ~1.3x needs an act-side opening idea — the
  round-7+ optimization campaign, informed by the first real
  Mac/H100 measurements. **[RETRACTED 2026-09-02: none of these
  numbers is derived from anything recorded — see
  U_PERF3_THROUGHPUT_MODEL.md §5.6 for the audit and §4 for the
  sourced table; kept here as history.]**
- **ADVERSARIAL_TESTING_PLAN.md is DOCUMENTED AND SHELVED** per
  Victor's directive (surfaces ranked, campaign phased, activates
  by ruling after the PoC); its §3 standing rule (tamper legs ship
  with every statement feature, same commit) is adopted NOW.
- **ROUND 7 (the PoC sprint) IN FLIGHT**: LL = W-1 column-splitting
  (the claim-table blocker); MM = the COMPOSED v3 statement (the
  cross-layer z->X seam binding — 32 per-layer proofs are not a
  model proof; MM's map-the-gap rung defines T17).
- **NEW MAC TASK T16 (after T15's Mistral export; KIND=RUN)** —
  the per-layer 8B evidence ladder (no new code needed): for l in
  0..31: `ZK_MODEL_EXPORT_DIR=<mistral v3 export>
  zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 <l> 16
  32` (each proves layer l against the 32-layer stack; ~>15 GB RSS
  each, fine on the Mac; wrap each in /usr/bin/time -l). ACCEPT:
  32/32 `accept = true`; paste per-layer wall + peak RSS + the
  statement-bytes line into the log; STOP+paste on any reject.
  This is the first full-model-COVERAGE 8B proof evidence (the
  seams are MM's T17 — say so in any write-up). T17 (the composed
  32-layer statement on the Mac) gets exact commands when lane MM
  lands.

**AS OF 2026-08-29 (ROUND 6 MERGED; main current; four battery
digests + all identity anchors green on the final tree):**
- **JJ — SPIKE X-S1 GREEN ON ALL FOUR ACCEPTANCES: the first
  attention machinery exists** — a committed integer softmax chain
  end-to-end through the real claim machinery (2435 cms / 703
  pins, the REAL fused (d,E) LookupAt pair, one rolling
  transcript); 8/8 tamper legs at pre-registered gates (XS1
  battery digest be89d5da..); values byte-identical to
  scripts/attention_spec_spike.py, synthetic + Gemma-calibrated;
  the Stage-A leg byte-identical vs the descent oracle at
  attention widths. MVP-2's X1 rung (entry classes + PW wirings)
  is UNBLOCKED. New ruling item: the exp-member C5/AM-2 promotion
  (lane-local members await the X1 freeze set).
- **KK — DIET 2 landed digest-identical**: the verifier A_0
  streams (the ~70 GB 8B verify phase -> ~6 GB); phi_1 windowed.
  **8B 32x512 peak ~116 GB with ~12 GB margin, ROBUST (one phase
  above 75 GB, was four)**; next lever = the i8 layer store
  (-> peak ~72 GB class). Cumulative diet at 125M: -23..-31% RSS.
- **The composition ladder**: diet x Stage A ACCEPTS in one binary
  at 12x64 + 12x128 (bytes 2.1-2.15x smaller, prove +15%, the
  diet reaches Stage-A mode) — the F1 ruling input.
- Design memo Appendix A carries the A.1/A.2/A.3 amendment texts;
  U_PERF3_S4_REDESIGN.md is the closed headline record. RULINGS
  PENDING: the round-5 five + AM-2/exp-members.

**AS OF 2026-08-28 (ROUND 5 MERGED; main fast-forwarded; all gates
+ both identity anchors green on the final tree):**
- **ROUND 5 VERDICTS**: **GG — STAGE A IS INTEGRATED ON THE REAL
  PASS**: range AND full modes ACCEPT at 3x16 behind the selector
  (default byte-identical); descent transcript -23x, total -41%;
  12x128 A/B [CPU NOISY]: bytes 2.15x smaller, wall +15%, RSS 2x
  at this small shape (full mode OOM = finding F1's face); every
  claim grounded bit-for-bit; O-4 masked at pass level with real
  commitment binding. **HH — the W-8 diet landed digest-identical**
  (RSS -12..-27% at 125M; walls +8-12% as priced): **32x16 8B
  yardstick ~95 GB (fits 128 GB TODAY); 32x512 ~116 GB without
  descents** [COUNTED]; spec corrections recorded (CRS stream;
  the phi_1 omission ~46 GB at 8B = the next diet rung). **II —
  the S4 redesign memo CLOSED: the composed best case is 1.6-2.5x
  vs the 5x bar; NO spike S5; the 5-15 s question on this line is
  CLOSED absent a structurally new idea**
  (U_PERF3_S4_REDESIGN.md).
- **RULINGS AWAITING VICTOR (the round-6 opening decisions)**:
  (1) adopt the fallback headline posture formally (integrated
  Stage A + route 3, GPU port as multiplier — now the measured
  recommendation of BOTH round-5 paths); (2) F1 — Stage-A round-1
  scope: RANGE-ONLY (84/96 cols, silu descents kept; dodges the
  +25.2M-ring act-h growth) vs full-with-committed-h; (3) F2 —
  the act-h third-group ordering amendment (the design memo's
  ordering is circular as written); (4) OQ-2 — the {0,1} alphabet
  (sign-binary planes prove the two-sided range, not [0, 2^w));
  (5) EE's q46-aggregate question. The Mac/other-compute queue
  (T13/T14/T15) is unchanged and ready.

**AS OF 2026-08-27 (round 3 WSL program COMPLETE; lanes
uperf3-aa/bb/cc pushed):**
- **RULINGS (Victor, console 2026-08-26/27)**: percol-eZ tried and
  MEASURED (whack-a-mole: the z residues are ~7 ROAMING val-tail
  elements; chasing them costs +0.04..+0.09), then **CLAMP-AT-Z
  ADOPTED** — the z requant relation is CLAMPED (the C5 tables' D1
  +-32767 convention extended); free margins (7 bits: X x4 + gate
  l34 + h l30/39/43) carry the other sites. Gemma quality of
  record: **+0.0380** (vs +0.1049 percol / +0.1082 whole-plane
  margins).
- **AA — COMPLETE except the report block**: Mistral export (12-bit
  free margins, 0 viols) AND **the REAL Gemma-4-12B v3 export (48
  x T=512, adopted 7-bit set, 0 viols AND 0 z clamps on the export
  window; sidecar carries `00 zpolicy clamp`)**. --tables C5
  record: 14 members used, EVERY digest byte-matches the frozen
  registry — NO C5 additions needed.
- **BB — both real checkpoints RECONCILE byte-for-bit**: Mistral
  (silu, 128 plane legs) + **Gemma (gelu, 192 plane legs)** through
  verify-export (per-tensor e_w3 + family sniffing + a legible
  zclamps guard). m125 e2e ACCEPT post-migration. Forward: the
  clamp-selector z gadget (only needed when a witness window
  actually clamps); **the 7B/12B PROOF rungs are MAC tasks
  (measured: 15.08 GB OOM at 1x16 on this box, weights-dominated)**.
- **CC — COMPLETE**: attention core INT8-CLEAN per-tensor; the four
  seam sites widened-int16 RESCUE (stack_wide +0.0854 vs +14.83);
  postn +0.19 residue open (MVP-2 design pass). Design memo §1.6b
  = the measured exponent data.
- OPEN: (1) round-3 lane report blocks + MERGE (Claude/Victor); (2)
  the Mac queue after the merge — T13/T1/T4/T12/T14 + the NEW 7B
  proof rung task; (3) MVP-2 planning on §1.6b's measured ground
  (incl. postn); (4) the Euler-architecture weight-smoothness
  thread (PROGRESS_UPERF3.md orchestrator note 2026-08-26 night:
  smoothness must be INDUCED; proof-side delta/K-anchor commitment
  compression once a smooth checkpoint exists — frugal-lm side
  experiment, separate sessions).
- **ROUNDS 3 AND 4 ARE MERGED (2026-08-28) — main is
  FAST-FORWARDED to the merged tree.** Gates on the final tree ALL
  GREEN: diff-battery, freeze-check 102 ok rows, the 48-leg digest
  3752cba4.. UNCHANGED with lanes DD+EE+FF's code live, uperf-w
  23/23, EE's agg-battery 136 legs digest 4623..., v3 smoke +
  chain-m125 12/12, the uperf-t planner arm.
- **ROUND 4 VERDICTS**: DD — the E_c kernels took the zero-check
  from the spike's 1.6x to 2.7x wall vs the descents (AVX2,
  transcript-invariant). EE — the aggregate: rounds 13.3x, wire
  6.6x, MAC-NEUTRAL (structural win); O-4 mask landed. **FF —
  spike S4 is a MEASURED NO-GO on 2 of 4 criteria** (prove-group-
  equivalent 1.1x at 1T / 0.6x at 7T vs the required >= 5x;
  tt_verify 3.9-4.7 s vs sub-second; cause: the memo modeled ~19K
  w-only recursion rings, the real tier-2 input is u-digit-
  dominated at 1.65M). Claims equality and the 8B planner gate
  were GO. **AWAITING VICTOR (ruling-grade per the memo's own
  text): accept the fallback headline posture (Stage A + (iii) +
  route 3, ~100-160 s/board) or commission a redesigned front
  end.** Stage A proper is unaffected and validated.
- **NEW MAC TASK T15 (after T13; Grok-format, KIND=RUN)**: the
  real-checkpoint v3 rungs on the Mac (the bins are WSL-local;
  the Mac re-exports from its own checkpoints): (1) after T12's
  download: `python3 scripts/m8b_export_ffn.py --profile v3
  --margins results/m8b_margins_mistral_wsl.json` per the script
  header, into results/m8b_mistral_v3_export_mac; digests must
  MATCH the committed WSL sidecar rows; (2) after T13: the same
  via `python3 scripts/m8b_gemma4_walker.py --export-v3 ...
  --margins results/m8b_margins_gemma_percol_mz0_wsl.json --text
  <fineweb sample>`; (3) `ZK_MODEL_EXPORT_DIR=<export>
  zkmatrix-rs/target/release/ring_matmul uperf-v3 verify-export`
  (expect PASSED, 128/192 plane legs); (4) THE PROOF RUNG:
  `ZK_MODEL_EXPORT_DIR=<mistral export> ring_matmul uperf-v3
  e2e-m125 0 16 1` — needs > 15 GB RSS (measured OOM on the WSL
  box; the Mac's 256 GB holds it); paste accept/wall/RSS. STOP and
  paste on any digest mismatch — a mismatch is the finding.
- **NEW STANDING PROTOCOL (CLAUDE.md "Heavy runs: detach, queue,
  marker"):** heavy runs launch `setsid nohup` under
  `flock /tmp/zk-heavy.lock` with a `.done` exit-code marker, and
  follow-ups are ENQUEUED on the lock so the box keeps working when
  a session dies. ANY resuming agent: check for fresh `.done`
  markers + half-written logs in the worktrees' results/ FIRST and
  integrate them (ledger line + commit) before starting new work.

**AS OF 2026-08-25 (commit 73adfb3 + round-2 lanes cut):**
- DONE and pushed to main: U-PERF3 round 1 (8B scaling memo, Stage-A
  spike GO/GO, headline-routes memo); the Mistral-7B calibration
  finding (the checkpoint fails TARGET_CONTRACT §2 as written — see
  PROGRESS_UPERF3.md "T12 WSL validation pass"); the general
  quantization contract draft (QUANTIZATION_CONTRACT_DESIGN.md,
  awaiting Victor's ruling); Gemma 4 12B QAT scoped (favorable dims,
  no license gate).
- **v3 ADOPTED (Victor, console 2026-08-26: "Let's continue
  adopting this v3 fix")** — the widened-stack amendment is the
  contract's default qualification profile; both checkpoints
  qualify (Mistral +0.216, Gemma +0.035;
  U_PERF3_QUANTIZATION_MEASUREMENTS.md). ROUND 3 IN FLIGHT
  (branches uperf3-aa/bb/cc): AA = margin bits to 0 violations +
  the v3 witness exports (both checkpoints) + the int16-out table
  digests; BB = the v3 statement in the engine (widened classes,
  h16 limb-split down matmul, round-mode requant, the C5 registry
  rows under the ruling; v2 default byte-identical is the floor);
  CC = the attention-site qualification gate (the MVP-2 de-risk
  measurement). **Grok note: T12's export step stays gated until
  lane AA lands the v3 export flags on main** (the old per-tensor
  export would produce a witness the v3 statement rejects); T13/
  T1/T4 and T12's calibration cross-check unchanged; T14
  unchanged.
- LANE Y LANDED AND MERGED (2026-08-25): the Gemma 4 12B reference
  walker, VALIDATED (semantics pinned to the transformers source;
  templated factual probe 5/5 rank-0; templated greedy "...gold is
  Au."). **T14 is now OPEN with exact commands** (Section 3) — the
  full C4 gate can run on the Mac OR on this box once agent V
  frees the CPU. Gate risk recorded: the smoke shows hot early
  layers (X absmax 165.9 at l0) — whether QAT tamed the outlier
  profile is exactly what the verdict decides.
- LANE W LANDED AND MERGED (2026-08-25, gates re-run green on the
  merged tree): the rig accepts arbitrary model shapes — `BfModel`
  loaded from `ZK_MODEL_EXPORT_DIR`'s digests.txt (default = the
  M125 consts, freeze rows byte-identical), accumulator classes
  derived from the dims, the planner declines infeasible candidates
  instead of panicking (the 8B group counts now plan). FIRST PROOFS
  through the generalized loader: 1x16 + 3x16 accept,
  digest-identical to the m125 path. `uperf-w battery` (23 legs) is
  a standing gate now.
- LANE X LANDED AND MERGED (2026-08-25): the attention statement
  design memo (docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_
  DESIGN.md, 859 lines) — MVP-2 full-layer multiples ~x2.0 over
  FFN-only at the 8B shapes [MODEL]; finding: as-built full-layer
  8B peak ~260-300 GB exceeds the Mac -> Stage A is MVP-2's
  memory-feasibility REQUIREMENT; spike X-S1 (integer softmax
  chain) named; 10 spec amendments AM-1..AM-10 queued for Victor's
  contract ruling.
- **GROK: your order is T13 -> T1 -> T4 -> T12 -> T14 (Section 3;
  T14 only once its status says its scripts are on main).** Nothing
  else. Specifically:
  - NEVER touch, merge, rebase, or continue the uperf3-* branches —
    even if they look finished. Claude or Victor merges lanes.
  - NEVER edit Rust or protocol files; every Grok task is KIND=RUN
    (run commands, paste outputs, commit results).
  - If a task's ACCEPT fails: STOP that task, paste the full output
    into Section 5's log with the date and box, commit, push, and
    move to the NEXT task in the order. A pasted failure is a
    COMPLETED Grok task — do not try to fix code.
  - Commit and push (main) after EVERY completed task, not at the
    end of the session: one task = one commit, message prefix
    `U-PERF3 GROK: <task id>`.
- RULES FOR WRITING NEW GROK TASKS (Claude/Victor): KIND=RUN only;
  numbered steps with ONE command per step; no compound shell, no
  env-var prefixes unless the task text gives the exact line to
  paste; an explicit ACCEPT and an explicit STOP per step; name the
  RAM/disk/time cost up front; say what to commit.

## 1. Rules (read once)

1. **Differential floor.** A performance change is accepted ONLY if
   (a) its function-level battery leg holds byte equality against the
   reference implementation, (b) `ring_matmul freeze-check` exits 0
   with every pre-existing digest unmoved, and (c) the EVAL-PROOF
   DIGEST printed by `uperf-pc pass-profile` is identical before and
   after at the same shape (Section 2.3). A speedup that moves any of
   those is a bug — revert.
2. **Transcript-preserving only.** Do not change what is absorbed into
   the transcript, the order of RNG draws, planner parameters (r cap,
   kappa, e caps), or any freeze row. Those are R-rows: file them in
   U_PERF_WAVE_REPORT.md Appendix R for Victor's ruling, do not build.
3. **One task, one commit** (or a short series of commits), message
   prefix `U-PERF PC:` and the task id, e.g.
   `U-PERF PC: T4 matvec_modq_small_multi (NTT-domain, O3) — battery leg green`.
4. **Timing labels are mandatory**: `[MAC-BOX]` or `[WSL-BOX]`, `1T` or
   `NT`, `QUIET` or `NOISY-SHARED` (frugal-lm training on the Mac =
   NOISY). Wall numbers without labels are not recorded.
5. **Do NOT touch**: `codex-audit-*`, `scripts/logup_*_spike.py`,
   `src/manifest.rs`, kfield/sumcheck/gkr/gkr_masked internals (PA's
   zone), lookup/digits/fold/pass_agg/t_blind/descent_fold/wire.
   In-scope files for the clock work: `zkmatrix-rs/src/ring/eval_proof.rs`,
   `zkmatrix-rs/src/aux_ntt_core.rs` (additive only), the `bg_*` /
   `agg_*` / `bk_*` / `uperf_pc_*` sections of
   `zkmatrix-rs/src/bin/ring_matmul.rs`, `tests/test_uperf_pc.py`,
   `docs/zkmatrix-poc/U_PERF_WAVE_REPORT.md`, this file,
   `PROGRESS_UPERF.md`.
6. **Record every result** in the task's `RECORD` target with the
   4-line format: date+box+label / command / verdict+numbers /
   commit hash. Then flip the task's status here.

## 2. Box facts and recipes

### 2.1 The two boxes

| | MAC-BOX (M3 Ultra) | WSL-BOX (Intel Core Ultra 9 185H) |
|---|---|---|
| RAM | 256 GB | 15 GB |
| frugal-lm ckpt + `results/m125_ffn_export/*.bin` | YES | ckpt YES (tarball, 2026-08-17); the frozen export's 36 weights YES (byte-identical), its 12 X files **NO** (Mac Metal rounding) — instead the local re-export `results/m125_ffn_export_wsl/` (valid witness, X differs) via `M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` |
| composed pass 12x512 (RSS 41-47 GiB) | runs | **cannot run** (RAM); 3x16 and per-layer T=16 rigs RUN with `M125_EXPORT_DIR` set |
| `freeze-check` | full, exit 0 required | first 98 rows green, then panics at the UAGB1-BF rows (missing export) — EXPECTED here |
| python suite | all green required | 77 pass, 2 skip, and EXACTLY these 4 fail for the same missing-export reason (freeze-check SIGABRT / layer00_X.bin): `test_ring_freeze_check`, `test_freeze_rows_uagb1_bf`, `test_pass_smoke_real_data`, `test_freeze_rows` (tblind) — measured 2026-08-17 at 213dfa2, 469 s; re-measured 2026-08-18 at a42e54d (after U-PERF2 rounds 1-8): 81 tests, 75 pass / 2 skip / exactly the same 4, 590 s (lanes P/Q building concurrently). Any OTHER failure is real. |
| `uperf-pc diff-battery`, `agg-matmul ...`, `bh-verifier ...`, `agg-kel`, unit rigs | run | run |
| build | `cargo build --release` in `zkmatrix-rs/` (or `--manifest-path` from the root — the two are now the SAME build: `zkmatrix-rs/.cargo/config.toml` no longer sets `target-cpu=native`, which was measured 3-4x SLOWER on the WSL box and applied only cwd-dependently) | same (plain `cargo`; the rustup proxy is ahead of snap on PATH) |
| timing status | frugal-lm F2 training may be running (check `top`) -> label NOISY-SHARED | usually quiet; is the TARGET_CONTRACT "CPU reference machine" |

So: code + function-level batteries can be written and verified on
EITHER box; the 125M profiles / A/Bs / full freeze-check / suite /
pass-agg batteries are MAC-BOX tasks.

### 2.2 Commands (all from the repo root unless noted)

```
# build (from zkmatrix-rs/)
cargo build --release
# gates
zkmatrix-rs/target/release/ring_matmul freeze-check            # exit 0, no FAIL rows [MAC full; WSL panics at BF rows]
zkmatrix-rs/target/release/ring_matmul uperf-pc diff-battery   # every optimization's byte-equality leg
python3 -m unittest discover -s tests                          # suite (~15-20 min MAC; export-dependent tests skip on WSL)
# profiles (MAC only; minutes to ~1.5 h)
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16      # fast yardstick (~6-8 min): FULL-STATEMENT attribution + EVAL-PROOF DIGEST
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512    # the real thing (~80 min prove + verify before the kernels)
zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 12 512    # composed scope only (no table descents; BG rig)
zkmatrix-rs/target/release/ring_matmul pass-agg prove 12 512 p0        # composed-scope prove+verify (BG rig)
zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p0   # FULL-STATEMENT prove+verify (BK rig, the PoC number)
zkmatrix-rs/target/release/ring_matmul pass-agg battery                # 14 legs, ~70 min [MAC]
zkmatrix-rs/target/release/ring_matmul pass-agg seam                   # 12/12 psi-seam differential (~1 min)
zkmatrix-rs/target/release/ring_matmul agg-matmul battery              # 23 legs, ~4 min, synthetic (runs on WSL)
zkmatrix-rs/target/release/ring_matmul bh-verifier battery             # BH differential + BF-F3 legs (synthetic)
```

Wrap long runs in `/usr/bin/time -v` (Linux) or `/usr/bin/time -l`
(macOS) so wall + peak RSS land in the record.

### 2.3 The EVAL-PROOF DIGEST (the composed-pass differential gate) and the two env knobs

`uperf-pc pass-profile <layers> <t>` prints
`[UPERF-PC] EVAL-PROOF DIGEST <hex>` = SHA-256 over both groups'
GroupEvalProof wire fields (b_rows, u0, ugh0, level_us, floor,
tcap_attempts) in order. It must be IDENTICAL at the same
(layers, t, mode) before and after any Phase-0 change. Baselines are
recorded in Section 4 as they are measured (T1).

Two environment knobs make every A/B a ONE-BINARY affair:

- `ZK_UPERF_ORACLE=1` routes every Phase-0 kernel entry point
  (matvec / ring-ip / level-h / the claim-kernel passes / the
  verifier's factored psi) to its pre-optimization oracle at runtime.
  Same binary, same box, same shape: run once with it (the "before")
  and once without (the "after"); the digests must be identical and
  the walls are the A/B.
- `ZK_THREADS=n` (default 1 = the ledger's 1T convention) sizes the
  kernel thread pool; every parallel split is over independent
  exact-integer work with a fixed reduction order, so the digest is
  identical for any n (the battery asserts it at 1/2/7). Record NT
  numbers as a separate row, never in place of the 1T number.

## 3. The queue (ordered; take the first OPEN task your box can do)

Legend: WHO = MAC | WSL | ANY (which box can do it); KIND = RUN (run
commands, paste numbers), CODE (write code + battery leg), DESIGN (not
for a mechanical agent — leave for Claude/Victor).

---

### T0 — hygiene at every commit  `STANDING`  WHO: ANY  KIND: RUN
Before every commit that touches Rust: `cargo build --release` green,
`uperf-pc diff-battery` green, `freeze-check` (MAC: exit 0; WSL: 98
rows then the expected BF panic — paste the last `ok` row). Before
every PUSH from the MAC: full suite green.

---

### T1 — pass-profile BASELINE + AFTER (attribution table + digest)  `OPEN`  WHO: MAC  KIND: RUN
WHY: nobody has run the composed-pass profile; every share above is
BG-F3 arithmetic. This gives the measured before/after tables AND the
digest identity for O2/O3/O5/T8b (which landed 2026-08-17 on the WSL
box with battery legs only). ONE binary, two env settings (2.3).
STEPS (`full-profile` = the FULL-STATEMENT rig incl. the 10 descent
pairs — the PoC number, ~80 min before; `pass-profile` = the composed
scope without table descents — use it only if full-profile cannot run):
1. `git pull`; `cargo build --release` (in zkmatrix-rs/); `mkdir -p results/uperf`.
2. Fast yardstick, BEFORE then AFTER (each ~5-10 min):
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_oracle.txt 2>&1`
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_fast.txt 2>&1`
   The two `EVAL-PROOF DIGEST` lines MUST be identical. If not: STOP,
   record, do nothing else (that is a bug report, not a fix).
3. The real thing, AFTER first (so the useful number exists early),
   then BEFORE (~80-90 min; peak RSS ~47 GiB; nothing else heavy):
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_fast.txt 2>&1`
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_oracle.txt 2>&1`
4. Optional NT row: `ZK_THREADS=8 ... full-profile 12 512` (digest
   identical; record as a separate NT row). The phase table's
   `bk.descent-trees` / `bk.descent-gkr` / `bg.commit-phase` /
   `bg.claim-layer` / `bg.prove-group` / `bg.verify-group` rows are the
   next round's priority order.
5. Copy the phase tables (the `ep.*` / `bg.*` rows), `accept`, walls
   (commit/prove/verify), and the digests into U_PERF_WAVE_REPORT.md
   Section 4.2 (before/after per shape) and Section 4 of THIS file.
ACCEPT: `accept = true` everywhere; digests identical oracle vs fast
(and vs NT); the 12x512 statement digest equals the frozen
`76dbf2040409333e` prefix printed by the rig.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2; TASK_BOARD Section 4;
PROGRESS_UPERF.md log line ("T1/T4 measured: ...").
NOTE: `results/uperf/` is new; add a `.gitignore` with `*.txt` if the
files are large, and paste the tables into the report.

---

### T2 — the h cross-garbage in the NTT domain (O2)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `eval_proof::level_h_pairs` + `ntt_gemm_modq_small` + oracle
`level_h_pairs_ref`; `bg_level_h` / `agg_level_h` switched; battery
leg "O2 level-h" 35/35; freeze-check rows identical to the pre-change
baseline; `agg-matmul battery` 22/22 + passed; `bh-verifier battery`
passed. Kernel-bench [WSL-BOX 1T QUIET] `uperf-pc kernel-bench 64
2048`: 0.245 us/product NTT vs ~5.0 us/product kara (r=16 oracle run)
=> ~20x on the level-0 term on this box (Section 4 of
U_PERF_WAVE_REPORT.md). Remaining for T4: the 12x512 digest + wall.
WHY: the largest term of the composed prove (~500M + ~227M ring-mults at
125M, ~2 us each on `ring_ip_modq_small`). Same arithmetic, ~15-25x.
WHAT: `eval_proof::level_h_pairs(ctx, phi_slices, w_slices) -> Vec<Poly>`
— r x chunk mod-q slices and r x chunk small slices, returns the
r(r+1)/2 h polys in pair order (j <= k), computed as D independent
(r x chunk) x (chunk x r) integer GEMMs in the NTT domain (transform
each ring once, split-halves lazy accumulation, exact-integer capacity
windows from `aux::max_n_acc`, one inverse per (pair, window)), with
`level_h_pairs_ref` = the current kara loop kept as the oracle.
Callers `bg_level_h` (bin, ~line 29152) and `agg_level_h` (bin, ~line
20068) switch to it. Battery leg in `uperf_pc_diff_battery`: random
q31 AND q46, r in {1,2,3,5,8}, chunk in {1,7,64,257}, w with extreme
digits (+-s_max, zero rings, whole-zero slices), windows crossing (q46
+ s_max 64 => 32-term windows), and the over-capacity fallback.
ACCEPT: leg prints `O2 level-h: N/N byte-identical`; freeze-check per
T0; `agg-matmul battery` 23/23; then (MAC) pass-profile 3x16 digest ==
T1 baseline.
RECORD: U_PERF_WAVE_REPORT.md Section 3 (O2), this row.

---

### T3 — matvecs in the NTT domain (O3)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `matvec_modq_small` (all call sites, prover + verifier) and
`ring_ip_modq_small` ride the kernel; new `matvec_modq_small_multi`
in `bg_matvec_chunks` / `agg_level_t`; oracles `*_ref`; battery leg
"O3 matvec" 63/63; same transcript gates as T2. Kernel-bench: 0.65
us/product NTT vs ~5.3 us kara [WSL-BOX 1T].
WHAT: `eval_proof::matvec_modq_small_multi(ctx, m, rows, cols, s_list)
-> Vec<Vec<Poly>>` (one M, many small vectors; M transformed once per
call, u-major accumulation into rows x len(s_list) accumulators);
`matvec_modq_small` and `ring_ip_modq_small` bodies switched to the
same window-accumulate primitive with the kara bodies kept as
`*_ref` oracles. Callers: `bg_matvec_chunks` (bin ~29107),
`agg_matvec_chunks` (bin ~20040) use `_multi`. Battery legs as in T2
(shapes rows in {1,11}, cols in {1,5,64,301}, both q's, extreme digits,
window crossings, fallback).
ACCEPT/RECORD: as T2 (leg `O3 matvec: N/N byte-identical`).

---

### T4 — the rest of the rig gates after T1  `OPEN (after T1)`  WHO: MAC  KIND: RUN
STEPS (all at HEAD, fast path): `freeze-check` exit 0 (full, incl. the
BF rows); `pass-agg seam` 12/12; `pass-agg battery` 14/14 (~70 min);
`table-descent prove 12 512 p0` for the full-statement wall (also once
with `ZK_UPERF_ORACLE=1` if time permits — the two `accept`/bytes
lines must match); the python suite green before any push.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2, PROGRESS_UPERF.md log line,
this row.

---

### T5 — the two claim-kernel passes, factored (rows pass + phi pass)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: Claude preferred (ANY with care)  KIND: CODE
DONE: `eval_proof::kernel_pass_factored` (+ `ColBlockCache`, `cq0_block`,
`g_block`), wired at the prover's two passes and the verifier's
non-recursed rows_eval; `bg_kernel_pass` kept as the oracle; battery
leg "O5 kernel-pass" 6/6; kpass-bench 512x2048: rows 42.6x, phi 51.5x
[WSL 1T]. Details: U_PERF_WAVE_REPORT.md Section 3 (O5). The text
below is the derivation as built (kept for the record).
WHY: `bg_kernel_pass` (bin ~29210) is the second-largest prover term:
per DIGIT ring it calls `claims.kw_value_row` (per value ring: 128 x
n_contrib x 2 K-field mults — likely the hidden cost) and then 16
`ring_mul_split_kara_fast`; twice (rows pass, then phi pass): ~365M
ring-mults + ~1.4G K-mults at 125M.
WHAT (exact identities; everything below is a re-association of the
same mod-q sums, so byte identity is by construction; the current
`bg_kernel_pass` is the oracle). Notation: tensor with `rows x cols`,
`cols % 128 == 0` (all 125M tensors; else fall back to the oracle
path), value ring vr = (row, cb) with cb = column block, digit ring u =
(vr, limb), radix_u = 2^(e0*limb); K-field bilinearity:
`kf.mul(x, y)[d] = sum_{d1} x[d1] * (Y^{d1} * y)[d]`; contributions
`c` = (scale_c, row_c[.], col_c[.]) with kw_u[c1] = sum_c
kf.mul(scale_c*row_c[row], col_c[cb*128 + c1]).
- Hoist: `sr_c[row] = kf.mul(scale_c, row_c[row])` once per (c, row).
- phi pass: for each (c, cb, d1) precompute the mod-q RING
  `G_c[cb][d1] = sum_{c1} conj(X^{c1}) * ( sum_d (Y^{d1} * col_c[cb*128+c1])[d] * alpha_d )`
  (n_contrib x nb x 16 rings per tensor — trivial). Then for every
  value ring: `PHI_vr = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1]`
  (16 x n_contrib scalar-x-ring MACs with u128 lazy accumulation, one
  mod-q reduce), and `phi_u = radix_limb * PHI_vr` per limb. This is
  the verifier's `psi_level0_factored` trick on the prover side.
- rows pass: `V_vr = sum_limb radix_limb * w_(vr,limb)` (the value
  ring recomposed mod q — small rings x radix, exact); then per
  (c, d1): `T_c[d1][cb] += sr_c[row][d1] * V_vr` over rows (scalar x
  ring MACs, u128 lazy); finally
  `b_rows[d] = sum_c sum_{d1} sum_{c1} conj(X^{c1}) * sum_cb (Y^{d1} * col_c[cb*128+c1])[d] * T_c[d1][cb]`
  (n_contrib x 16 x 128 x nb scalar-x-ring MACs — trivial).
Both passes become O(n_value_rings x 16 x n_contrib) scalar-ring MACs
(~6G mult-adds at 125M, seconds) with NO per-ring K-mults and NO ring
mults. Keep the misaligned/absent-kernel path on the oracle.
Battery leg: synthetic groups (the `bh-verifier` builders + the real
`bg_build_groups` on the 3x16 shape on the MAC), byte identity of
`b_rows` and of every `phi` ring against the oracle.
ACCEPT/RECORD: as T2 (leg `O5 kernel-pass: N/N byte-identical`).

---

### T6 — multithread the kernels (rayon, deterministic)  `LANDED for the Phase-0 kernels 2026-08-17 (Claude, WSL); the rest OPEN`  WHO: ANY  KIND: CODE
DONE: `ZK_THREADS=n` pool in eval_proof.rs; the NTT GEMM (transforms
per ring, the D coefficient positions of the accumulate, the scatter,
the flush), the factored phi pass (value-ring blocks), the rows pass
(per-range partial T sums reduced in order + per-(kernel, cb) block
products) and the verifier's factored psi (value-ring blocks) all
split over independent exact-integer work. Battery identical at
ZK_THREADS 1/2/7. Kernel-bench 64x8192 [WSL]: level-h 7.6 s (1T) ->
1.24 s (20T) = 6.6x on this hybrid 6P+8E box; kpass-bench 512x2048:
rows 2.55 -> 0.74 us/digit ring, phi 2.39 -> 0.91 at 7T (fixed
per-tensor precomputes bound the gain at this size).
OPEN (same recipe): `bg_fold`/`agg_fold` (T7), the transport levels
(T3b), the descents (PA/BK zone — see T11), commit's chain derivation.
RECORD: U_PERF_WAVE_REPORT.md Section 4 (a 1T vs NT row from T1 step 4).

---

### T7 — `bg_fold` / `agg_fold` in the NTT domain (small)  `OPEN`  WHO: ANY  KIND: CODE
`z_u = sum_j c_j * w_{j,u}` (small x small, exact i64) — currently
`poly_mul_small` schoolbook (16K MACs each, n_0 of them, ~1-2% of the
prove). Transform c_j once (r NTTs), per u r forward + 1 inverse
transform; exact by the small-operand bound (128 * 2 * 64 << p/2).
Oracle = current loop; battery leg; ACCEPT/RECORD as T2.

---

### T8 — verifier attribution toward the <= 2 s line  `OPEN`  WHO: MAC  KIND: RUN
`pass-profile` now prints `bg.verify-group` (per-group verifier total)
next to the shared `ep.*` counters; T1's table gives the split. Known
O(n_0)-class verifier terms to expect: `psi_level0_factored_multi`
(per VALUE ring: 16 kara ring-mults beta x conjq + 1 per digit-ring
chunk change — ~24M + ~10M ring-mults at 125M, i.e. ~70 s of the
199.6 s) and `transport_level` at level 1 (~12 kara ring-mults per
next-witness ring, ~750K rings per group, prover AND verifier).
RECORD: U_PERF_WAVE_REPORT.md Section 2 (verify table).

### T8b — the verifier's `psi_level0_factored_multi`, factored  `LANDED 2026-08-17 (Claude, WSL)`  WHO: ANY  KIND: CODE
DONE: the aligned branch now uses `PhiFactored` (T5's machinery: no
per-row K-mults / per-value-ring beta x conjQ ring-mults; one
c_k x PHI ring-mult per (value ring, k-run) remains) — battery leg
inside "O5 kernel-pass" (== compute_psi(phi0_reference_multi) at two
chunk splits, both moduli). Rig verify A/B rides T4.

### T3b — `transport_level_from_psi` in the NTT domain  `OPEN`  WHO: ANY  KIND: CODE
General x general operands: the 12-24 alphas are fixed rings
(transform once); per next-witness ring the operands are psi[src] /
a_mat[.][src] scaled by radix (mod q). Needs the limb-split contract
(aux `A1LimbCommitKernel` pattern, or `ring_mul_q_limbsplit`'s exact
recompose) — ~12 general ring-mults per ring today, ~750K rings per
group at level 1, prover AND verifier. Oracle: the current function.
ACCEPT/RECORD: as T2 (leg `O6 transport: N/N byte-identical`).

---

### T9 — memory diet for the 15 GB reference box  `OPEN`  WHO: ANY (c: Claude preferred)  KIND: CODE
The composed pass peaks at 41-47 GiB. Where it goes: the eval-proof
phase holds phi (n_0 x Poly: ~8 GiB for the act group) + w0 for both
groups (~12 GiB as Vec<Vec<i64>> with per-ring heap headers); but the
PASS PEAK (47 GiB, UAGB1_TABLE_DESCENT_REPORT 3.3) is the DESCENT
phase's tree batches ("nrw-88's 16-tree batch") — so a 15 GB-box diet
needs the descent trees streamed/batched smaller (BK/PA zone; T1's
`/usr/bin/time -l` RSS + the bk.descent-* rows tell how much) AS WELL
AS the two items below. Transcript-neutral steps on the eval-proof
side:
(c) FIRST (biggest, mechanical after T5/T8b): never materialize phi
at level 0. In `bg_prove_group`: (1) replace the level-1
`transport_level(ctx, &phi_cur, ...)` by
`transport_level_from_psi(ctx, &psi0, ...)` with `psi0 =
psi_level0_factored_multi(ctx, kf, group, &mk, &alphas0, &c0,
plan0.chunk)` — EXACTLY what `bg_verify_group` already does at level
1 (the `pass-agg seam` differential is the proof it is
compute_psi(phi_cur) bit for bit); (2) feed `bg_level_h` at level 0
from a phi PROVIDER instead of `phi_cur`: add
`level_h_pairs_with(ctx, phi_block: impl Fn(j, u0, &mut [Poly]),
w_slices, chunk)` whose a-side rings are produced per u-block by
`PhiFactored::value_ring` (per digit ring v = j*chunk + u: locate
(tensor, vr, limb) — consecutive u are consecutive v, so one PHI_vr
per value ring per pass, cached across the l0 limbs; radix scale per
limb) — the same arithmetic as the phi pass, no extra cost, and the
12 GiB `phi_cur` is never allocated (`phi_cur.truncate(n0)` and the
level-1 `phi_cur.resize` go away; deeper levels keep their small
materialized phi). Battery: the O5 leg's groups through the provider
vs `level_h_pairs` on the materialized phi.
(a) then w0 as a flat `Vec<i8>` (digits |w| <= 64) with slice views
at the consumers (matvec / level-h / fold / floor) — invasive, second.
(b) drop slices as level 0 consumes them.
Target: 12x512 P0 under 14 GiB so the TARGET_CONTRACT reference box
can run it. Measure with `/usr/bin/time -v` (Linux) — WSL-verifiable
once the export is copied over (T10).
RECORD: PROGRESS_UPERF.md log; TARGET_CONTRACT note if the reference
box becomes runnable.

---

### T10 — copy the m125 export to the WSL box  `MOSTLY DONE 2026-08-17`  WHO: Victor  KIND: RUN
DONE: Victor delivered the checkpoint tarball + the val shard; the WSL
box re-exported everything (`results/m125_ffn_export_wsl/`, 36/36
weights byte-identical, X differs by mlx CPU-vs-Metal rounding, 0
range violations) — the 3x16 / T=16 rigs run here with
`M125_EXPORT_DIR` set. REMAINING (small): the Mac's 12
`results/m125_ffn_export/layerXX_X.bin` files (~4.7 MB) copied to the
same path here would make freeze-check's UAGB1-BF rows and the frozen
statement digest reproducible on this box too.

---

### T11 — DESIGN items (not for a mechanical agent)  `OPEN`  WHO: Claude/Victor  KIND: DESIGN
(a) Prover-side rank-structured Phi_0: after T5 the prover's phi pass
is `PHI_vr = sum_{c,d1} sr_c[row][d1] * G_c[cb][d1]` per value ring
(16 x n_contrib scalars against 16 cached rings per (col kernel,
cb)); the next step is to feed `level_h_pairs` per u-block from that
form (never materialize the 11 GiB phi) — memory item T9(c).
(a') THE VERIFIER <= 2 s LINE (PoC-complete criterion 1(b)) — memo
2026-08-17 (orchestrator), supersedes the "chunk alignment" sketch:
after T8b the verifier's level-0 work is O(n_value_rings x 16 x
n_contrib) scalar MACs (~8.6G at 125M: ~14 s [WSL 1T], ~7 s [MAC 1T])
plus the transport levels (~25 s -> lane C), the descent verifies
(~36 s -> lane A) and small terms; the 1T verify after this round
lands in the ~40-60 s class, NOT <= 2 s. The chunk-alignment idea is
WITHDRAWN: at the 125M point every tensor (~41K digit rings) is
SMALLER than the level-0 chunk (~122K), so each chunk position u is
folded across ~r different tensors — the fold cannot be pushed
through the row structure and the "S[u'][j]" reuse has size ~1. A
verifier sublinear in n_value_rings needs a PROTOCOL change (a
polylog-verifier opening layer, or the prover supplying Psi_0 with
its own checkable proof) — design-trench work, not an R-row. The
practical route to a 2 s-class verify is `ZK_THREADS` on the
reference box (22 threads: ~2-4 s projected) — which requires
relaxing TARGET_CONTRACT's "single-threaded" wording to "single
machine, N threads stated" (Victor's ruling; an amendment, not code).
(b) R-row: the planner's r = 64 cap trades bytes for the Theta(n_0*r)
garbage; at r = 32 the h term halves and the artifact grows (derive
the bytes; the P0 artifact sits at 0.48x its gate). Transcript-
changing: Victor's ruling, freeze rows re-pinned if adopted.
(c) The GPU rung (CONTINUATION Phase 3): T2/T5's D-batched integer
GEMMs and the A1 commit kernel are the two kernels to port first.

---

### T12 — the 8B FFN calibration + export on the Mac  `OPEN — DOWNLOAD APPROVED (Victor, console 2026-08-24: "Go ahead with the mistral download")`  WHO: MAC  KIND: RUN
WHY: MVP-1 (PROGRESS_UPERF3.md) proves the 8B FFN shape with REAL
int8-calibrated weights; this produces the witness in the rig's
layout. Gates M3/M8 of the MVP plan. Needs Victor's go for the
download (~17 GB network, ~30 GB disk). RAM < 4 GB RSS (streamed) —
F2 training may keep running; nothing here is timed.
PREREQS (one-time): a python3 with numpy;
`pip install huggingface_hub tokenizers pyarrow` (network — part of
the same go-ahead). All commands from the repo root.
STEPS: follow `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` Section
5.2 LITERALLY — it is this task in board format with the exact
commands (download Mistral-7B-v0.1 ungated; FineWeb-Edu parquet +
text extraction; the `--decode "The chemical symbol for gold is"`
sanity gate BEFORE anything long — STOP and paste if " Au" is
absent (gate revised 2026-08-24: the earlier France prompt false-
fails in fp32 — memo §5.2 step 3 has the record); calibration
~20-45 min; export ~10-25 min; `--weights-only` re-check). PASTE into the log: the per-layer exponent table, every
`silu-int8-table-v2 member` line (W-6 flags), the variant-A
violation count, the VERDICT block, peak RSS.
COMMIT: results/m8b_int8_calibration.json,
results/m8b_ffn_export/digests.txt + manifest.json (+ the script's
.gitignore). The .bin files stay on the Mac; keep `layer00_*.bin`
handy for the WSL sync (~180 MB).
DO NOT run the rig on the export: the 32x16 rung is GATED on the MVP
plan's M1+M2 code rungs (W-5/W-4/W-2 — the rig is hard-coded to the
125M shape today and will panic). The board gets the exact rig
command when M1 lands.
ACCEPT: memo §5.2 steps 3-6 green; the JSON + manifest + digests
committed; the paste in the log.
RECORD: TASK_BOARD §4 + a PROGRESS_UPERF3.md log line ("T12 done:
eW range …, silu members …, violations 0/…, RSS … GB").

---

### T13 — download Gemma 4 12B QAT on the Mac  `OPEN`  WHO: MAC  KIND: RUN
WHY: the prime "native" candidate checkpoint (QAT-trained with int8
activations) for the general quantization contract; the Mac will run
its qualification gate (T14) and, if it qualifies, the 12B proof.
Verified on the WSL box 2026-08-25: NO license gate, no token needed.
COST: ~23 GB network + 23 GB disk; minutes to ~1 h depending on
bandwidth; no RAM to speak of. F2 training can keep running.
STEPS:
1. `python3 -c "import os; from huggingface_hub import snapshot_download; snapshot_download('google/gemma-4-12B-it-qat-q4_0-unquantized', local_dir=os.path.expanduser('~/models/gemma-4-12B-qat'), allow_patterns=['*.safetensors','*.json','tokenizer.model'])"`
   (If `huggingface_hub` is missing: `pip install huggingface_hub`
   first — that is the T12 prereq set.)
2. `ls ~/models/gemma-4-12B-qat/`
   ACCEPT: config.json, model.safetensors, tokenizer.json present.
   STOP if a login/403 error appears — paste it (the WSL box needed
   no token; a gate here is news).
3. `du -sh ~/models/gemma-4-12B-qat/`
   ACCEPT: ~23 GB.
RECORD: one log line in Section 5 ("T13 done: 23G, files listed"),
commit, push.

---

### T14 — the Gemma 4 qualification-gate run on the Mac  `GATED (watch for scripts/m8b_gemma4_walker.py on main)`  WHO: MAC  KIND: RUN
WHY: THE decisive measurement for the "native" route — does a
QAT-int8-activation checkpoint pass the contract's calibration gate
(0 range-fact violations + small loss delta) where Mistral-7B failed
with 14,531 violations and +8.18 nats? If yes, this checkpoint is
the MVP vehicle.
GATE: OPEN as of 2026-08-25 — lane Y landed; the scripts are on
main. `git pull` first.
PREREQ: T13 done; the FineWeb-Edu text file from T12 step 2 (same
sampler data as the Mistral baseline — REQUIRED so the verdicts are
comparable). COST: each 48-layer decode pass ~2-6 min on the Mac;
the full calibration ~15-40 min [MODEL]; RSS < 6 GB; F2 can run.
STEPS (all from the repo root; the walker defaults to
`~/models/gemma-4-12B-qat` = T13's location):
1. `git pull`
2. `python3 scripts/m8b_gemma4_walker.py --decode "The chemical symbol for gold is" --template`
   ACCEPT: the completion contains " Au".
   STOP+paste if not. **NOTE: `--template` is REQUIRED — without it
   this instruction-tuned checkpoint greedy-decodes degenerate
   zeros; that is a known property of the model (its own
   generation_config suppresses those tokens), NOT a bug — do not
   report a plain-decode failure.**
3. `python3 scripts/m8b_gemma4_walker.py --probe --template`
   ACCEPT: >= 3 of the 5 factual prompts in the top-2 ranks (the
   WSL reference run scored 5/5 at rank 0 — paste your ranks; a
   materially worse table is a STOP+paste).
4. The full qualification gate (the C4 verdict):
   `python3 scripts/m8b_gemma4_walker.py --text ~/models/fineweb-edu/sample_text.txt --out-json results/m8b_gemma4_calibration_mac.json`
   ACCEPT: the script exits 0 and prints a VERDICT block. **The WSL
   verdict already landed 2026-08-25 (FAIL: 116,852 violations,
   almost all at the z site of ~6 layers with the FFN internals
   clean; +17.60 nats; committed as
   results/m8b_gemma4_calibration.json) — your run is the CROSS-
   CHECK: the violation counts, exponent tables and member digests
   must MATCH that JSON. A mismatch is the finding — paste both.**
   Any exception/assert = STOP+paste.
5. Commit `results/m8b_gemma4_calibration_mac.json` + paste the
   VERDICT block into Section 5's log; push.
RECORD: the full verdict block (violations by class, loss delta, the
member digests) pasted into Section 5 + PROGRESS_UPERF3.md log line;
commit results JSONs; push.

## 4. Baselines and digests (append-only)

| date | box/label | shape | command | EVAL-PROOF DIGEST | prove s | verify s | commit |
|---|---|---|---|---|---|---|---|
| (T1 fills this) | | | | | | | |

## 4b. Round 2 + 3 (U-PERF2, 2026-08-17 — PROGRESS_UPERF2.md)

Round 2 LANDED and MERGED (a450b1f): **A** = descents (pads never
materialized, five-table round kernel, deterministic threads: prove
2.07x at 1T, 6.6-7.2x at 8T on the depth-20 bench, RSS -33%) and **C**
= eval-proof leftovers (fold NTT 4-6x, transport 3.4x, psi 3x, and the
FINDING that the Goldilocks NTT was branchy — branchless primitives
1.5/2.07 us per transform now carry every kernel). Real data reached
the WSL box (checkpoint + val shard -> `results/m125_ffn_export_wsl/`),
so the 3x16 full-statement rig runs here: **oracle 682.8 s -> 43.7 s
at 1T (15.6x) -> 16.6 s at 8T (41x), verify 1.9 s at 8T, every digest
identical** (U_PERF_WAVE_REPORT.md 4.2). Round 3 lanes **D** (claim
layer + commit phase threading) and **E** (descent callers on lane
A's drop-ins, descent VERIFY attribution, small-cols aux tensors) are
LANDED and MERGED too (4dcaea6): claim layer 3.5x/11x, chain GEMM
10x, tree callers streamed, small-cols aux K-rows 42x, parallel CRS
XOF; real-data batteries green. **3x16 now: 30.6 s at 1T (22x), 9.9 s
at 8T (69x); 12x64 at 8T: 46.0 s, 12.2 GiB RSS.** Round 4 lanes **F**
(memory diet — w0 compact, phi never materialized; the 12x512 rig on
the 15 GB box) and **G** (descents round 2: fold/extract fusion,
arena, thread scaling) LANDED too (d38e9ce): RSS 3x16 2.9 -> 0.96
GB, 12x64 12.2 -> 4.0 GB; **12x128 runs here now: 58.3 s at 8T, 6.4
GB**; descents -29% more. Round 5 lanes **H** (descent tree layer
checkpointing + pool — the last blocker for 12x512 on the 15 GB box)
and **I** (SIMD Goldilocks NTT) LANDED too (a087a7d, 96559ee): SIMD
transform 2.2-3x; descent trees checkpointed/released/compact — and
**THE PoC SHAPE RAN ON THE 15 GB REFERENCE BOX: 12x512 full statement,
8 threads, 155.6 s wall (commit 11.7 / prove 134.9 / verify 7.3), 1.51
MB artifact, 10.98 GB RSS, accept** (U_PERF_WAVE_REPORT.md 4.2). 3x16:
25.0 s at 1T / 8.5 s at 8T (80x vs the same-box oracle). A 20-run
p50/p95 series at 12x512 DONE (4.3: p50 153.1 / p95 155.9 s at 8T).
Round 6 LANDED (34a8eb8, c210ea9): AVX2 K-field kernels (J) and **the
GPU rung step 1 (K: `--features gpu-cuda`, `ZK_GPU=1`, RTX 4070 Laptop
via WSL2, bit-identical, 8-10x on the ported GEMM)** — **12x512 now
106.8 s CPU-only / 85.0 s with the GPU at 8 threads** (report 4.2).
Round 7 LANDED (100a41c, f90a438): psi0 + leftovers (M) and the descent
round / ixf on the device (L) — **12x512: 96.7 s CPU-only / 60.2 s
with the GPU at 8 threads; verify 2.6 s; 3x16 4.5 s.**
Round 8 LANDED (109b879, 96bac25): the descent tree device-resident
end to end (N) and the claim layer's table pool + device-built
zero-check tables on a device-resident chain (O; the GEMM u32-limb
form was measured and refuted) — **12x512: 34.1 s with the GPU at 8
threads (commit 5.0 / prove 24.9 / verify 2.6), peak RSS 6.7 GB; 86.1
s CPU-only; 12x128 15.6 s; 3x16 4.3 s; every digest identical.**
Round 9 LANDED (214ebc5 + the Q merge): the descent kernels' floor
(P: one launch per round, device eq, slab allocator — the kernels
themselves are at 70-88% of the K-mult ceiling on this part) and the
prover's CPU-side blocks (Q: level-h device session, one combine
kernel family, int8 chain GEMM on device, mask/shift digits, 4-lane
SHA-NI CRS) — **12x512: 21.0 s with the GPU at 8 threads (commit 2.5 /
prove 15.5 / verify 1.7; three QUIET runs 21.0/21.1/20.9), 6.7 GB;
81.5 s CPU-only; 12x128 10.5 s; 3x16 3.4 s; every digest identical.**
THE KERNEL CURVE HAS FLATTENED (what is left sums to ~3-4 s): the
next step is a ruling — PROGRESS_UPERF2.md "Decision memo
(orchestrator, 2026-08-18)": (1) the lattice line's protocol change
(T11: a batched sumcheck-class opening layer; design memo first),
(2) the hash-based/float-mix channel as a comparison prototype,
(3) a Metal port for the M3 Ultra as the named GPU. Grok-shaped
work is (3) once the kernel set is frozen, plus T1.
Honest position: 34 s is a 12x512 slice of the 125M FFN on a laptop
GPU; the 8B contract shape is ~30-100x the work on a ~4-6x part [MODEL]
(3-14 min) — "minutes on one desktop GPU" is the honest projection for
this protocol; 5-15 s needs T11's design items or the float/int-mix route.

**RULING 2026-08-18 (Victor): route (1) — the lattice line, to a
COMPLETE 8B FFN MVP (minutes accepted), the route-1 protocol work
alongside, a creative search for the headline within the line; the
float/int-mix channel documented, not started
(PROVING_CHANNEL_OPTIONS.md). Tranche U-PERF3 (PROGRESS_UPERF3.md):
lanes R (8B scaling memo + MVP plan + the 7B/8B export scripts), S
(spike S1/S2 of the Stage-A protocol change), T (headline routes memo).**

**U-PERF3 round 1 LANDED (2026-08-23, merged to main):** lane R —
`U_PERF3_MVP8B_SCALING.md` complete (counted 8B sizes; the W-1..W-11
what-breaks table; 32x512 needs the W-8(a) memory fix even on the
Mac's 256 GB, ~184 GB peak with it; honest Mac CPU walls [MODEL]
~15-30 min at 32x16, ~35-75 min at 32x512; plan M0-M8) + the m8b
scripts, validated on the 125M ckpt byte-identically (36/36 weight
digests, 108/108 exponents, 12/12 verify checks). Lane S — spike
S1/S2 both **GO** (`U_PERF3_SPIKE_REPORT.md`: S1 9-25x
K-mult-equivalents / 12-16x rounds / 45-55x wire vs the masked
descent at 2^20; S2 claims equal bit-for-bit vs the descent oracle,
rounds 274->20; battery 48 legs byte-identical at 1/2/7T; caveat:
the prototype E_c kernel is ~8x off the K9 kernel's quality — the
counted win needs a production kernel). Lane T —
`U_PERF3_HEADLINE_ROUTES.md`: ranked recommendation for the second
design freeze = the opening re-architecture (Stage A + one-point
front end + two-tier sqrt serving + weight-group preprocessing; 8B
~20-40 s one desktop board, ~6-13 s four [MODEL]; verifier
sub-second 1T), then the route-3 board port; folding deferred to
MVP-2 as the memory tranche; de-risking spike **S4** named (2-4
days, no freeze move). AWAITING VICTOR: the T12 download go, the
S4/round-2 ruling, Mistral-vs-Llama naming (memo §5.1).

**Grok (Mac) — the RUN queue (ORDER PER SECTION 0: T13 -> T1 -> T4
-> T12 -> T14; T13/T14 are in Section 3 above):**
1. **T1 (still open, still valuable):** `uperf-pc full-profile 12 512`
   at ZK_THREADS 1, 8, 16 (and one `ZK_UPERF_ORACLE=1` run); digests
   must match the WSL box's (statement 2f8a92f8… / EVAL 4c259008…);
   record walls + phase table + `/usr/bin/time -l` peak RSS. This is
   the [MAC-BOX] row of the PoC shape and the Mac is where the 8B MVP
   will run CPU-only (256 GB). Walls are NOISY-SHARED while F2
   trains — label them; the digest identity is the load-bearing part.
2. **T4 (open):** the rig gates at HEAD on the Mac — full
   `freeze-check` exit 0 (incl. the BF rows), `pass-agg seam` 12/12,
   `pass-agg battery` 14/14 (~70 min), `table-descent prove 12 512
   p0`, the python suite green. Independent of everything else and
   nobody has run the full-statement rig on the Mac at HEAD.
3. **T12 — AMENDED 2026-08-24 after the WSL validation run
   (PROGRESS_UPERF3.md "T12 WSL validation pass"): the checkpoint
   DOES NOT CALIBRATE under the spec as written** (14,531 held-out
   range-fact violations, +8.18 nats through the int8 chain;
   weights-only +0.08 — emergent activation outliers, the known
   >= 7B phenomenon). Therefore: steps 1-4 of memo §5.2 (download,
   decode gate — now the gold prompt, calibration) are STILL ON as
   a digest cross-check: the calibration JSON's exponent table,
   silu-member list, violation counts and verdict must MATCH
   results/m8b_int8_calibration_wsl.json (committed). **The EXPORT
   (steps 5-6) is GATED on Victor's spec ruling** — its 0-violations
   assert will fail by design; do not run it, that is not a bug.

## 5. Log (append-only, newest last)

- 2026-08-17: board opened by Claude after the status recalculation
  (PROGRESS_UPERF.md 2026-08-17 section). T2 started by Claude on the
  WSL box; T1 is the first MAC task.
- 2026-08-17 (later): T2, T3, T5, T8b, T6(kernels) LANDED on the WSL
  box with their battery legs (`uperf-pc diff-battery`: O1 4/4, O2
  35/35, O3 63/63, O5 12/12, E2E 2/2 — the last is the whole
  bg_prove_group + bg_verify_group on a synthetic mixed-tensor group
  with a forced 2-level schedule, proven under oracle AND fast routing
  in one process: proofs field-identical, both verify), freeze-check
  rows identical to the pre-change baseline, `agg-matmul battery` +
  `bh-verifier battery` green (also at ZK_THREADS=7). Kernel benches
  [WSL 1T]: level-h 21.8x, matvec 8.0x, kernel passes 42.6x / 51.5x,
  all byte-identical; 20T level-h 6.6x more. Commits 353a75d, 31e8840,
  213dfa2 (pushed to main + perf/zk-batch-optimizations).
  NEXT for the MAC (Grok): T1 — one binary, `ZK_UPERF_ORACLE=1` for the
  before, plain for the after; `full-profile 3 16` first (digests must
  match), then `12 512`.
- 2026-08-18 (Claude, WSL): rounds 4-8 of U-PERF2 landed (see 4b) — the
  PoC shape 12x512 is 34.1 s with the reference box's laptop GPU at 8
  threads (155.6 s at the status recalculation), 6.7 GB, byte-identical.
  Round 9 launched (P descent kernels, Q prove-group/commit/CRS/
  transport). Grok/Mac: T1 stands (`uperf-pc full-profile 12 512` at
  ZK_THREADS 1/8/16 + one `ZK_UPERF_ORACLE=1` run, digests must match).
- 2026-08-18 (later): round 9 landed — 12x512 8T+GPU 21.0 s QUIET (x3),
  CPU-only 81.5 s, digests identical; the kernel curve has flattened;
  decision memo written for Victor (PROGRESS_UPERF2.md). Nothing new
  for Grok until the ruling except T1 and the Metal-port question.
- 2026-08-18 (ruling): Victor chose route (1). U-PERF3 opened; T12 (the
  8B export on the Mac) added as the next Grok RUN task, gated on lane
  R's scripts; T1 unchanged.
- 2026-08-23 (Claude, WSL): status check — nothing pushed from the Mac
  since the ruling (T1 unrecorded, §4 baseline table still empty; T12
  was legitimately blocked on lane R). The 2026-08-18 session had died
  ~25 min into round 1 leaving lanes R/S/T stalled with uncommitted
  work in their worktrees; all three resumed, completed, and MERGED
  (see §4b round-1 block). Gates on the merged tree: diff-battery
  green, uperf-s battery 48 legs digest 3752cba4…, freeze-check WSL
  form (98 rows ok, expected BF panic). T12 moved into §3 with exact
  commands and UNBLOCKED (pending Victor's download go); Grok queue
  now T1 -> T4 -> T12.
- 2026-08-24 (Victor, console): T12 download APPROVED ("Go ahead with
  the mistral download"). Claude/WSL starts the same pipeline here as
  a VALIDATION pass (829 GB free disk; the scripts stream < 4 GB RSS):
  download -> decode gate -> calibration -> export into a WSL-labeled
  directory (results/m8b_ffn_export_wsl). Purpose: answer W-6/W-7
  (SiLU member, remainder widths) and memo §4.3's real-7B untested
  items TODAY, and give the Mac run a weight-digest/exponent
  cross-check; it ALSO dissolves memo §5.1 decision (4) (Mac->WSL
  export-slice transport) — the WSL box can cut its own 1x16 dev-rung
  slices from a local export. The Mac T12 remains the digest
  authority for the 8B rig's witness.
