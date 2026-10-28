# Where the MVP stands, in plain words

**2026-10-19 16:18 UTC — the prover now carries the fidelity fixes.**
- **Both recalibrated stacks proved on native R8** (per-layer values for every
  calibration constant), bit-exact against the integer reference at every
  layer, verified in a fresh process from a verifier's copy, 11/11 controls
  refused [MEASURED, n=1]: TinyLlama `dg` T128 (every layer at its own
  constants) prove 183 s, receipt 498 MB; Llama-3-8B `b7voc0` T128 (b7 + the
  layer-0 vocabulary recalibration) prove 479 s quiet box, receipt 923 MB,
  verify 43 s. Receipt sizes are unchanged: the fixes cost no proof size.
- **The 8B layer-0 refusals are gone:** the recalibrated layer 0 accepts all
  128,256 vocabulary tokens (it refused " ." and "Tags" before) [MEASURED,
  exhaustive]. On the demo prompt, integer and float agree on the next token
  (11, margins 9.5 / 7.0 logits).
- **Fidelity is still far from parity** [MEASURED]: 8B b7 LAMBADA first 100
  items 0.54 vs float 0.78 (−24 points); TinyLlama b4 perplexity 1.23x / 1.29x.
  The `dg` per-layer calibration and the 8B dg build are being measured next.
- **Token lane round 6 done** (owner-directory race fixed, the demo reads its
  pins from an approval record, 8B demo passed end to end, full suite 740/0);
  round 7 moves it onto R8 and runs the demo on the recalibrated 8B export.

**2026-10-19 13:38 UTC — demo-ready CLI, honest baselines, fidelity target set.**
- **Demo flow for the trained 8B next-token proof** (`results/zk60_token_io_r1_20261017/tools/r4_cli_demo.sh`):
  `prove` 227 s (laptop CPU; 471 MB) -> `verify` 90 s (pinned to the trained
  model identity and the token-profile digest; the verifier publishes the
  statement itself) -> `owner` 83 s (re-verifies, then the prompt owner reads
  token 11) -> `input-owner` (the prompt owner confirms the proof used their
  32-token prompt). A layer-0 pre-check refuses the two tokens that overflow on
  today's 8B export (" ." and "Tags") by name before anything runs. Reviewed
  (token review rounds 1–4; round-4 fixes under confirmation).
- **Honest speed baseline** (`results/zk60_cpu_inference_baseline_20261019/README.md`):
  plain CPU inference of an 8B Llama at 8-bit takes ~1.55 s for 32 tokens and
  ~5.6 s for 128; the private proof takes 156 s and 433 s — about 100x and
  77x [MEASURED]. Tokens/s improves with prompt length up to ~128–256 tokens
  (~0.3 tok/s on the laptop CPU), then falls as attention grows.
- **Fidelity (D32: no performance degradation versus float).** Proposed
  threshold (for Victor): perplexity <= 1.01x float on FineWeb and WikiText,
  LAMBADA >= 99% of float, zero refusals. Today: TinyLlama 1.23x / 1.28x, 8B
  1.63x / 1.77x. Per-layer constants close ~52% of TinyLlama's gap (1.105x /
  1.121x) with no new proof planes; native round R8 is adding them for every
  shift. The 8B refused every WikiText window at layer 0 (token " ."); a
  vocabulary-wide recalibration of layer 0 (no proof cost) is in progress.
- **Privacy at trained TinyLlama size:** the statement is final after three
  independent review rounds and the gate's R7 re-gate; acceptance awaits
  Victor's word in the console.

**2026-10-19 10:20 UTC — first private proof of a trained Llama-3-8B's NEXT
TOKEN.** One proof: a 32-token hidden prompt -> the trained int16 embedding ->
all 32 trained blocks (streamed; layer 1 at its own score shift) -> final norm
-> per-row int8 head -> greedy token, sealed in a hidden output fingerprint;
the verifier sees no prompt, no activation and no token (D25). Token 11,
confirmed by three independent references (float head's top-2 margin 4.40
logits); bit-exact at all 32 layers; receipt 471,285,072 B; prove 191.7 s on
the laptop CPU, peak 3.44 GiB; fresh-process verify 43.4 s under a 95-bit
policy; 65 of 65 applicable tamper controls caught; whole-run soundness 97
bits; full suite 729 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r3/trained-ho00/`]. The integer head
meets D25 T4 at 8B (100% agreement with the float head wherever its margin is
>= 0.3; 99.1–99.8% overall). Independent review of this rung running.

**Also since 10-18:** the fidelity-improved 8B T128 block stack (layer 1 at
score shift 7; held-out top-1 0.651 -> 0.673) proved (471.6 s, shared box) and
was re-verified independently (identity 97c4acda…); quiet-box 8B stacks: T32
156.2 s, T128 432.5 s. Native R6 and R7 frozen and accepted / under review
(R7: stale-writer handling, backend allow-list). Privacy evidence at trained
TinyLlama size complete on R5b; the second independent privacy review lists
five closing items (re-pin and re-gate on R7, G-7, a 2-block root-rebuild
check, a text consolidation, owner confirmations D28/D29 — done); those are in
progress. GPU slot-18 kernel at 25.9 ms = 19.4% of 256 GB/s (laptop clock
capped at ~1.1 GHz); lane paused with a 5090 start plan. Victor's GPT
conversations yielded DD (per-row division dictionary, −20.8% committed at
8B T512, exact), admitted into the 8B T512 profile specification as D30; FN
withdrawn as a question.

**2026-10-18 01:42 UTC — first private proof of a trained model's NEXT TOKEN.**
TinyLlama-1.1B, a 32-token hidden prompt: hidden token ids -> embedding (indexed
lookup into the public int16 table) -> all 22 trained blocks -> final norm ->
per-row int8 head with 12-bit multipliers -> greedy choice (lowest-id ties),
the token sealed in a hidden output fingerprint, all **one proof under one
transcript**; the verifier sees no prompt, no activation and no token (D25).
Next token 29914, confirmed four independent ways (in-test reference, the
Python reference, the fidelity lane's integer head and its float head).
Receipt 255,258,816 B in 24 segments (equal to the counted lengths); prove
85.3 s on the laptop CPU, peak 2.45 GiB; fresh-process verify 10.6 s under a
95-bit minimum policy; a one-bit change refused; 55 of 55 applicable tamper
controls caught exactly where predicted; whole-run soundness 97 bits (meets
D27); full suite 708 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r2/ho00/`]. Built on the design that
passed two adversarial checks and on the tiny rung R1 that passed an
independent code review; the review of this rung (R2) is running. **Not yet:**
the hidden-length variant (D26), the privacy gate for the token stages
(G-1..G-7), and Llama-3-8B (rung R3). Not a privacy acceptance.

**2026-10-18 00:10 UTC — overnight checkpoint.**
- **First private Llama-3-8B stack at T128:** all 32 blocks, a 128-token
  hidden prompt, one proof: 607 s total on the laptop CPU with the R5b
  safeguards (487 s before them; the difference is a second witness build for
  the refusal-before-header rule), receipt 922,711,264 B, parity bit-exact,
  fresh-process verify with 11 tamper controls refused (0.21–0.26 proved
  positions/s) [MEASURED, shared box, n=1]. The T64/T128 profiles are under
  independent review (round 5).
- **R5b frozen (2026-10-18 00:06:31Z):** fixes the privacy review's blocker P-1
  (inadmissible inputs refused before the run header; the public statement is
  promoted only after a fresh verify), review r4's two verifier-DoS findings,
  and the gate's operating rules (allow-listed run label, hidden inputs kept
  out of the verifier's copy, refusal messages without data-derived counts,
  backend recorded). Suite 692 passed / 0 failed. Privacy gate re-capture and
  re-gate with tools v5 (pins now enforced) running on it.
- **GPU go/no-go:** 11.7% of the laptop GPU's bandwidth on the feed-forward
  zero-check, byte-identical to the CPU: improve kernels before porting more
  (register spills found; next round estimated 33–42%). Refitting the cost model
  on the 8B T128 stack confirms the plan: T512 on a 5090 is about 0.6–0.8
  positions/s with today's code, 6.6–8.6 with the whole prover on the GPU at
  today's efficiency, 9.4–11.8 with the attention-layout changes; 50 needs
  kernels near roofline.
- **Next-token proof:** rung R1 (tiny vocabulary) passes its full suite after
  census fixes and an independent code review (sound as built); review fixes
  TR-1..TR-4 and rung R2 (TinyLlama, 22 blocks) in progress.
- **Fidelity:** 8B T64 and T128 exports verified bit-exact; layer 1's weak spot
  traced to large negative attention scores setting a coarse scale; a per-layer
  score shift lifts held-out top-1 at T128 from 0.651 to 0.673 (KL 0.61 -> 0.50)
  with no layout change — native round R6 is adding it.

**2026-10-17 21:10 UTC — evening checkpoint: 8B stack 2.2x faster end to end,
security accounting corrected, five rulings recorded, next-token proof
designed and being built.**
- **Speed (startup cleanup, speed plan task 1 MET):** the private 32-block
  Llama-3-8B stack at T32 now takes **171.6 s total** (was 384.5 s this
  morning; target <= 180 s): weight digest pass 15.3 s (was 83.0), block
  reloads 16.0 s (was 79.2), witness 21.4 s, block proofs 118.8 s, in-process
  verify off (the fresh-process verify remains the check). Same statement
  identity 259dad7c…, same 465,815,776-byte receipt, parity bit-exact
  [MEASURED, shared box, n=1; `results/zk60_1b_native_20261017/r5/`]. That is
  0.19 proved positions/s at T32; the speed target (50/s on a 5090 at T512)
  still needs the whole prover on the GPU (speed plan).
- **GPU go/no-go (task 2), interim:** slot 18's zero-check runs on the laptop
  GPU with byte-identical rounds and seeded proof bytes at four shapes, 0
  silent fallbacks; a 22-block TinyLlama T128 stack with it proves and
  verifies fresh. Open: inside the stack the slot runs ~5x slower than in
  isolation; the bandwidth verdict waits for that diagnosis.
- **Reviews:** the independent review accepted the Llama-3-8B profile changes
  on soundness (round 3); its verifier-DoS finding (unbounded segment reads)
  is fixed in the frozen round-5 tree, which is under review now (round 4).
- **Security accounting (register D15, two notes):** the "106 bits per
  opening" ignored padding, and the lookup bound is now the checked
  (N + 2303)/|F|. Trained stacks are **about 97.4–98.2 bits whole-run**; an
  8B run at 512 tokens about 94.7 (about 99.7 as forger work per attempt).
  **Victor's D27:** about 95 bits whole-run is the MVP target at the named
  workload, 100 next, 128 for the product, with selectable tiers later for
  critical applications; throughput is not traded for bits at the MVP.
- **Rulings recorded today:** D23 and D19b accepted; D25 (next-token proof:
  one hidden token per run, hidden and sealed prompt length, lowest-id ties,
  per-row integer head matching the float head wherever its top-2 margin is
  >= 0.3 logits, private owner hand-off, BOS forced); D26 (security owner:
  the two-site input endpoint); D27 (soundness target).
- **Next-token proof:** design v3 passed two adversarial checks (three holes
  found and fixed before any code), paper reference 20 tests green; integer
  head fidelity measured on TinyLlama (98.9% overall, 100% wherever the float
  head is not a near-tie); the first native rung (tiny vocabulary, 2 blocks)
  is being built. Cost at 8B T32: about +3% proving time [MODEL].
- **Privacy gate (TinyLlama T32, 22 blocks):** the dense 22-block pass PASSES
  with every control family firing; the all-zero pass reconstructs every
  published value with 0 differing (25 million in the joint check); finding
  G-10 repaired. Owed before any acceptance: re-capture from the frozen
  round-5 tree (running), an independent re-read and adversarial review of
  the draft (running), and the remaining items of the draft's §10b. **No
  privacy acceptance at the trained shape yet.**

**2026-10-17 18:35 UTC — clean shutdown at 14:59, resumed at 18:21; no new
result yet.** The laptop shut down cleanly at 14:59:58 UTC (every guarded job
got SIGTERM; not a freeze) and booted again at 18:21. Correction to the 14:00
block below: the GPU go/no-go experiment had code written but **never ran on
the GPU** — its first device test was killed after 6 s by the shutdown. Also
cut off: the native round-5 test suite (never started), the 8B T64 calibration
export, and the review's last checks. The privacy gate's 22-block all-zero
pass finished before the shutdown: 0 differing values in the masking layer
(355,410 checked) and in the joint run (25,005,697); its FAIL flag appears to
come from controls that were not requested in that pass (being confirmed).
Everything uncommitted was pushed as snapshot 6 of
`snapshot/20261017-uncommitted`. Six lanes restarted behind the resource guard
(`ops/zkp-mvp/LANE_RULES_20261017.md`): GPU zero-check go/no-go, native R5
suite + startup cleanup + 8B T64/T128 phase ladder, review verdict on the 8B
profile, privacy gate controls and G-10, 8B calibration B6, and a paper design
for proving embedding, head and token choice (D13's next milestone).

**2026-10-17 14:00 UTC — how far from 50 proved tokens/s, measured-model
answer.** The costed speed plan ([ZK60_SPEED_PLAN_20261017.md](ZK60_SPEED_PLAN_20261017.md))
fits a per-phase cost model to today's TinyLlama ladder and predicts the
measured 8B T32 stack within 3.1%. Its projection for private Llama-3-8B at
T=512 on one RTX 5090 [MODEL]: today's code ~0.55 positions/s; the whole prover
on the GPU at this project's measured GPU efficiency ~7–9; with commitment
kernel and attention layout improvements ~11 (high end 22). **50 is reachable
only if every GPU kernel moves its counted bytes at about 23–34% of the 5090's
bandwidth** (today's commitment kernel: ~13% on the laptop). The plan's
go/no-go experiment — the FFN zero-check (slot 18) on the laptop GPU, with
measured bandwidth — started at 13:55 UTC; below ~10% the remaining levers
are design changes needing Victor's rulings (LogUp-GKR helpers, code rate
1/2, 16-bit range tables), which together still reach only ~13–16 [MODEL].

**2026-10-17 13:20 UTC — first complete private proof of a trained 8B model's
transformer stack.** All 32 blocks of Llama-3-8B (NousResearch/Meta-Llama-3-8B
rev 315b2009…, 8,030,261,248 parameters) proved as ONE bound private run at
T=32 (hidden input, output, activations and boundaries; public weights);
native witness bit-exact with the Python integer reference at all 32 layers;
calibration export `llama3_8b_pg_rot1_T32` (held-out top-1 0.62 FineWeb /
0.55 licence). Laptop CPU, shared box, n=1: total 384 s (weight loading 79 s,
witness 19 s, block proofs ~110 s, in-process verify 93 s), receipt
465,815,776 B in 32 segments, fresh-process verify 96 s, peak RSS < 2 GiB; 11
run-level tamper controls refused, honest run still verifies. Statement
identity 259dad7c…. Evidence `results/zk60_1b_native_20261017/r4/`.
The same stack on the laptop GPU (commitments on the device, "gpu: ON", 0
declines) took 391 s with the same statement identity: level with the CPU at
T32, where reloading the 8B weights (about 2.5 s per layer, three times per
run) dominates and the block proofs are 3.4–3.7 s each.
**Not yet:** speed (0.08 proved positions/s total; target 50 on a 5090),
T > 32, embedding/head (D13), fidelity (layer-1 attention sink), independent
review of the 8B profile changes, privacy acceptance at this shape, D23.

**2026-10-17 11:15 UTC — trained 1.1B stack 9x faster; first context ladder.**
Building the witness once and in parallel took the 22-block TinyLlama stack
from 529 s to 56 s at T32. Ladder on identical weights (CPU / laptop GPU,
shared box, n=1, each verified in a fresh process): T32 56 / 61 s, T64 85 /
89 s, T128 169 / 143 s — **0.76 proved positions/s on CPU and 0.90 with the
GPU at T128**, receipts 251 / 333 / 498 MB. The block proofs are now 72–81% of
the time; GPU commitments help from T128. T256+ needs more host memory than the
laptop has. D24 and the trained profile are accepted on soundness after two
independent review rounds. Next: Llama-3-8B calibration (running), an 8B
profile, and a T32 private 8B stack attempt on this laptop.

**2026-10-17 10:15 UTC — first complete linked proof of a trained model's
transformer stack.** All 22 TinyLlama-1.1B blocks as ONE private run (hidden
32-token input, output, activations and every block boundary; public weights),
calibration `pg_rot1` (held-out top-1 agreement with the float model 0.70–0.73,
no refused inputs). CPU, shared laptop, n=1: 528.9 s total, of which ~450 s is
building the witness twice on one thread and ~60 s the block proofs; receipt
251 MB; fresh-process verify 4.9 s; peak 2.15 GiB; 11 run-level tamper controls
refused. Before it, the independent review accepted the D24 norm rule but
found a real hole in the trained loader (an unchecked export constant let a
forged output verify); fixed the same morning (every export-chosen constant now
has a checked class; the forgery is refused) and under focused re-review.
**Not yet:** privacy acceptance at this shape, T above 32, GPU stack timing
(running), embedding/head (D13's next milestone), 8B.

**2026-10-17 05:20 UTC — first proofs of a real trained model's blocks.**
Every one of TinyLlama-1.1B's 22 transformer blocks was proved privately
(hidden 32-token input, output and activations; public weights) and each proof
verified in a fresh process from its bytes; the native prover's numbers equal
the independent Python integer reference bit for bit at every layer. Per block
on the laptop CPU: prove 3.2–4.2 s, verify 0.27–0.40 s, 11.6 MB, under 0.9 GiB
[MEASURED, shared box, n=1]. Layer 0 refused all 15 tamper/mismatch controls.
Full native suite 518 passed / 0 failed; frozen toy receipts unchanged.
**What it is not:** 22 separate one-block proofs, not a linked stack (nothing
yet ties block k's output to block k+1's input); proved on the low-fidelity
calibration `a` (held-out top-1 0.136 vs float); conditional on the independent
review of proposed ruling D24 (running); no privacy acceptance at this shape.
The calibration lane found a usable per-profile calibration (`pg_rot1`: top-1
0.698, perplexity 36.5 vs 29.3 float, no refusals) that needs four requant
shifts to become profile constants; the native lane is doing that now, then
the linked 22-block stack on CPU and GPU. Victor flagged arXiv 2610.08258
(zkLLMPoT, v2 11 Oct 2026): it hides weights with public audit inputs (the
reverse of our P1) and reports 41–59 s at 1.1–1.5B for "covered operators";
an assessment is running. Mac M3 Ultra (256 GB) not yet reachable; 5090 not
yet installed. [Checkpoint](ZK60_1B_CHECKPOINT.md).

**2026-10-17 02:20 UTC — work resumed after a 17-day gap; no new proof yet.**
Nothing native ran between 2026-09-30 01:38 UTC and today: the recovery session
of 09-29 ended abruptly (cause unknown; one minute earlier the resource guard's
memory cap had correctly killed an oversized test), and since then only the
hourly researcher worked (cycles 41–51, CPU-only arithmetic studies; none
changes the prover). The three answers are unchanged from the 09-30 block
below: **(1) workable proof:** complete private proofs exist for the tiny
block (two lines, privacy accepted only there) and for synthetic 125M-shape
stacks; **no trained block has been proved yet**. **(2) speed:** best complete
stack rate is 1.25 proved positions/s (synthetic 12-block 125M shape, laptop
GPU-assisted), about 40x short of 50 even at that small size; for 8B the
project's own projection is 0.6–1.2 tokens/s on a 5090 with today's code and
5–13 with every sumcheck on the GPU (not built), so **50 needs a design change,
not tuning**. **(3) what blocks the MVP:** a trained-model profile (norm
constants, calibration, weight loading), then the 22-block TinyLlama stack,
privacy re-checks at the new shape, and for 8B the RTX 5090 machine (Linux not
yet installed). Today: all uncommitted work since 09-23 was pushed as branch
`snapshot/20261017-uncommitted` (preservation only); the Llama-3-8B download
resumed; two lanes started — the native TinyLlama profile (proposed ruling D24:
lower the norm precision constant instead of adding a fifth limb) and the
calibration fidelity ladder with exports for a bit-exact parity check.
[Checkpoint and lanes](ZK60_1B_CHECKPOINT.md).

**2026-09-30 01:27 UTC: the box froze on 2026-09-29 (17:40 PDT); heavy work now goes through one
guard.** The machine died with five heavy jobs live, including the first
production 12-block GPU stack run, which therefore has **no result** (its log
stops after a GPU commitment; nothing was published). The exact cause is not
proven (no out-of-memory or GPU-memory error was logged); the fix is that
every build, proof, calibration and benchmark now runs through
`scripts/zk60_resource_guard.py`: one heavy job at a time, kernel-enforced
memory caps, GPU-idle checks and a permanent record of measured peaks
([rules and limits](ZK60_RESOURCE_PROTOCOL.md); 45 tests pass; Codex found and
we fixed a bug where the guard could have adopted its caller's session scope).
Nothing about proof speed changed. Best measured number is still the earlier
**synthetic** 12-block, 125M-geometry stack on this laptop's 4070:
1.25 proved positions/s over the whole test wall, about **40x short** of 50.
No trained 1B block or stack has been proved. Lane status: TinyLlama
calibration (Python reference) and the trained-profile prototype (five-limb
norm; its lost scratch work was recovered from a transcript, 7 fast tests pass)
are running again behind the guard; the production stack run waits for the
guard's small-shape canary. This is a stability fix, not a milestone.

**September 29, Tech Week demonstration:** the local browser demo now uses
real retained 785-byte Groth16 receipts for the small block and synthetic
two-block token model. Fresh-process verification and proof/policy tampering
controls pass. The HTTP path passes 32 checks across all three modes,
including artifact downloads and request boundaries; 69 demo and existing
zkVM-runner tests pass. Saved verification does not generate a new proof.
The live native synthetic-block option also passes, generating a 2,816,472-byte
proof and independently verifying it with tamper controls. Its 0.256-second
complete check is a shared-machine toy diagnostic, not a trained-model rate.
It uses a public fixture and the shared heavy-job lock; its first attempt
deferred while another proof held that lock. Trained
calibration/import and model-scale privacy/performance remain outstanding.
[Run the demo and review its exact scope](ZK60_TECHWEEK_DEMO.md).
GPT-6.1-Sol supplied the demo backend/readiness review; the existing Sonnet 5.5
lane supplies the separate native stack CLI. The hourly research supervisor
was confirmed alive and unpaused on the host at 00:12 UTC September 30
(17:12 PDT September 29); its next cycle is due at 17:45 PDT.

**Latest direction, 2026-09-26.** Target a complete private **8B-parameter
forward-pass proof at >=50 proved tokens/s on an RTX 5090 or another high-end
GPU**. Victor explicitly permits more tokens to amortize initialization and
initial prefill. The old 512-token / 10.24-second window is a reference, not
a mandatory latency limit. Measure larger workloads, report both sustained
and total-workload throughput, and retain setup, witness, proof and verification
clocks. [Current target and workload accounting](ZK60_THROUGHPUT_TARGET.md).
D13's first MVP still covers the hidden transformer blocks; token generation
is the following milestone. No complete private 8B timing exists yet.

**2026-09-27 UTC, Sol team checkpoint.** Three GPT-6 Sol agents completed
their native fusion, keyed GPU commitment and memory/model-readiness batches. The
fusion candidate passes core debug/release, 512 native tests (17 ignored),
fresh/cross-version receipt verification and nine corruption refusals. Its
six-run CPU A/B completed: the fused evaluator was 1.66% slower in mean
proving and 10.38% slower in the softmax slot (two non-warm samples per arm).
It is demoted; the grouped baseline stays in place. The keyed GPU candidate
now passes resident, forced streaming, compact-pad and complete small tagged
block CPU/GPU receipt checks on the RTX 4070 Laptop. The first streaming
launch failure is retained separately; the corrected attempt passed and all
source/binary/log hashes were rechecked. Independent review found no concrete
static defect; core debug/release pass 74 unit + 2 integration tests each.
The broader device oracle passes all 189 cases. Native GPU-feature release
coverage is 491 passing tests plus one successful missing-fixture rerun,
17 ignored; it is not a single full-suite pass. All eight frozen legacy
proofs now match exactly across resident/forced-chunk configurations. One
runner falsely rejected v3's success marker; its failed report is preserved,
with an explicit source/log/proof-hash adjudication and six passing remaining
cases. Root rechecked the 184 source, six binary and six continuation log
hashes. The six-run dense CPU/GPU A/B is complete and all receipts verify.
Two non-warm samples per arm give mean proving **32.95 s CPU / 17.13 s GPU**
and whole test-process elapsed **39.895 s / 30.055 s**. Mean peak host RSS
falls from **10,524 MiB to 4,411.5 MiB**; VRAM peak was not measured.
This is one synthetic 125M block, two CPU threads, RTX 4070 Laptop, shared
host. One GPU witness build took 10.66 s versus 5.77 s in the other sample;
the hourly researcher was active. Each sample uses a fresh process, so
startup and verification remain in whole-process elapsed. This is not
steady-state throughput or a complete-model rate. Softmax proof work remains
roughly half the GPU-assisted prover's time. See the
[A/B evidence](../../results/zk60_sol_gpu_20260927/attempt-5-dense-ab/report.json).
No 5090, full trained 8B or larger-profile privacy result is established.
[Team/evidence map](ZK60_SOL_TEAM_20260927.md).

An allocation-free audit of the historical 7.24B Mistral geometry counts
25.70 GiB retained payload at 512 tokens and 70.57 GiB at 1,024 tokens,
before weights and some scratch. These are lower bounds for unregistered
layouts, not measured peak memory or 8B proofs. All 256 historical FFN
export tensor files are missing; their manifest survives. A trained full-
block importer/calibration and a literal 8B checkpoint remain outstanding.
[Model and memory audit](../../results/zk60_sol_model_20260927/layout-readiness.md).

Victor has both the RTX 5090 machine and the M3 Ultra available (256 GB
unified memory, corrected by Victor on 2026-10-17; earlier text said 512 GB).
The 5090 machine needs a fresh Linux installation; neither new machine has
been validated remotely. The [setup guide](ZK60_HARDWARE_SETUP.md) starts
with a USB Ubuntu installer made on the Mac, followed by driver and read-only
host checks. The Mac's first role is CPU reference/witness work; there is no
Metal proof backend. Memory-bounded commitments are an active follow-up.
A small CPU streaming-root/recomputed-opening prototype passes eight legacy
and tagged fixtures: identical leaves, roots, opening bytes, transcripts and
RNG continuation, with mutation refusals. Releasing A/H codewords would
reduce the T512 retained floor to 5.35 GiB. This is a test-only prototype;
production lifetimes, measured peaks and throughput still need validation.
The successful **GPU chunked path already streams codewords and recomputes
queried columns**. Its separate A/H retained bounds are 5.18/14.23 GiB on
host and 5.17/14.22 GiB in VRAM at T512/T1024; the earlier 25.70/70.57 GiB
floors describe materialized storage or CPU fallback. Host witness/helper
overlap remains at least 9.86/27.17 GiB before other scratch.
[Updated tier-specific audit](../../results/zk60_sol_model_20260927/gpu-chunked-memory-audit.md).

The persistent hourly research supervisor was resumed and its host process
confirmed alive; its first sandbox restart failed before research began, and
the host restart retains the hourly schedule. A separate session research
agent completed a [resource-budget handoff](../../research/zkp-efficiency/handoffs/20260926-forward-budget-and-traffic.md).
Its 14 arithmetic checks are not prover or GPU measurements. Raw-log correction:
the historical FFN-only 196.79 s is internal wall time; enclosing process elapsed
is 200.09 s. Both exclude the earlier witness export/inference work.

Implementation has resumed in an isolated Rust candidate: the research lane's
grouped-equality softmax evaluator is wired into the real SC_SZC slot. Core
debug/release tests pass (73 unit + 2 integration each), including masked
bytes/challenges/finals and a release work-count check (1,403 -> 1,148 expensive
bracket calls). Eight targeted native tests also pass: dense/padded block and
three-block-run verification, inconsistent-witness refusals, and independent
polynomial oracles at every registered shape. Fresh/archived receipts cross-
verify in four processes with nine corruption refusals. **The full native suite
has now passed: 512 tests, 17 explicitly ignored.** All nine validation steps
pass; 183 source hashes, three binaries and all nine log hashes were rechecked.
The dense grouped A/B has completed: all six proofs verify at 40,783,352
bytes. Two non-warm runs per arm show proving 37.63 / 36.84 s before versus
34.86 / 33.31 s after: about 8.5% less proving time on average in this
shared two-thread CPU diagnostic. The full softmax slot falls about 18.4%;
the known witness+prove+serialization sum falls about 7.2%. Warmup proving
times were nearly equal (34.69 / 34.38 s), and two samples per arm do not
establish a stable production speed factor or p95. Both binaries include
small-slot test oracles; no GPU/8B or privacy-scope result follows.
[Retained candidate and validation](../../results/zk60_grouped_rounds_20260926/README.md)
record the evidence and audited phase summary.

**Live work checked at 05:41 UTC:** the hourly GPT-6 Sol research supervisor
is alive and unpaused, idle between cycles; cycle 0013 completed and the next
is due at 05:52:33 UTC. The earlier implementation/benchmark batches are
finished; no full 8B proof or 5090 benchmark is running. Cycle 0013 tests a
synthetic device-round schedule for softmax sumcheck: 110 round-point checks,
91 final-table checks and eight mutation controls pass on CPU. It does not
implement the actual native polynomial, BLAKE3 transcript or CUDA path.
The next implementation gate is exact native masked-transcript parity before
a device round/fold implementation and whole-proof timing. The eleventh
cycle's direct-helper experiment has a roughly 3% parent-phase ceiling in
the cited earlier CPU workload. The ninth cycle's fused fold/next-round
proposal was implemented and measured above, then demoted after slower
results despite lower counted table traffic.
Victor requested periodic updates; active sessions report here in chat, and
each background cycle must refresh the durable
[progress report](../../research/zkp-efficiency/PROGRESS.md). Local reports
are not automatic chat notifications.

The separate R2a allocation A/B completed: all six dense 125M proofs verify
at 40,783,352 bytes. Non-warm proving seconds: old 44.51 / 40.27, new
39.73 / 40.10, two CPU threads. Native compilation overlapped part of this
shared-box measurement; no reliable end-to-end gain is established. These
conditions differ from the earlier 17.4–19.4 s CPU runs, which they do not
replace. No new privacy acceptance or private-model speed is claimed.

**Updated 2026-09-22, during shaped-block integration, by the Codex/Fable
loop (after the 01:04 laptop restart; see §3 item 4).** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

**Current speed and completeness (2026-09-22).** The latest dense synthetic
block at the 125M geometry proves in **17.4–19.4 seconds on CPU**, down from
27.7 seconds; its receipt is 40,783,352 bytes and verification takes
1.15–1.34 seconds [MEASURED, shared box]. The 17.40-second run separately
spent 5.24 seconds preparing the witness, so it is at least 22.64 seconds
before verification. The latest twelve-block dense run remains **397.71
seconds**, with 14.45-second verification and 484,107,456 receipt bytes; it
predates the latest speed changes and has not been re-timed with them. The
five-second goal concerns a model pass; the single-block clock alone does
not establish its distance from that goal.

All transformer-block operations and twelve-block chaining are implemented
and exercised on synthetic public weights with hidden activations. The
grouped-attention completeness repair has been independently reviewed.
Whole-proof privacy acceptance remains confined to the small CPU toy block;
the larger profiles' privacy argument, trained-model integration and the
production run interface remain unfinished. Main's host optimization is
accepted; the combined larger-block source at lane `fee1a8d` has passed its
16-step CPU integration baseline in `/tmp/wt-zk60-shaped-20260920`, with
source-pinned results under `results/zk60_shaped_integration_20260922/baseline/`
there. The retained logs and all 179 source hashes were checked again: no
mismatch. This is not final integration acceptance; device checks, wider
privacy acceptance and the production model run remain outstanding. No new
model-scale or GPU timing is implied by that integration work.

**2026-09-22, isolated sumcheck candidate:** an additive evaluator interface
and redundant-evaluation shortcut pass core debug/release checks, all 512
native tests across a full run plus a fixture-only rerun, and old/new receipt
verification. Four dense 125M block proofs also pass at the unchanged receipt
size. On two Rayon threads, the softmax sumcheck phase measured 9.05–9.26 s
before versus 8.55–8.59 s after (two samples each). Whole proving time varied
from 38.96–61.79 s before and 38.06–43.02 s after, so no reliable end-to-end
speedup is established. The candidate test binary includes extra small-slot
oracle checks. This is not yet integrated into main or a new privacy/GPU
acceptance; it does not replace the earlier differently situated CPU clocks
or the 8B target. [Source, tests and retained measurements](../../results/zk60_sumcheck_rounds_20260922/README.md).

**Target reaffirmed by Victor, 2026-09-22:** five seconds for an **8B-parameter
model on better hardware with a GPU**. The 125M CPU runs are development
measurements, not the target workload/hardware. Retain the current 512-token
prefill window when comparing throughput, and report proof generation,
witness preparation and complete readiness separately. The recorded public
Mistral-7B measurement is **58.40 seconds for FFN only**, or **8.77 proved
tokens/s** over that window; attention is excluded. Its complete logged wall
time is 196.79 seconds (2.60 tokens/s). There is no measured 54-second
FFN-plus-attention result. Five seconds over the same window would be 102.4
proved tokens/s; none of these rates measures autoregressive generation.

**Latest integrated speed work:** corrected direct-plane GPU uploads and
private host buffer/fold reuse pass 43 isolated validation steps, including
307 storage-feature tests, 189 actual-device cases and twenty frozen proof
comparisons. Main's separate rebuild and receipt checks also pass: two fresh
receipts, fourteen cross-version verifications and 24 GPU-feature private-IO
tests under all buffer/fold settings. Floors v11 pins the new inventory, with
89 tooling tests passing. [Evidence and limits](ZK60_HOST_PRIVATE_INTEGRATION_20260920.md).
These checks establish correctness; they do not measure private-model speed.

The preceding exact int8/int32 row folds pass all twelve
CPU/GPU proof-byte gates, fresh native receipt verification in both modes,
and repaired private-IO P1/P3 checks. Dense synthetic folds improve
2.32–2.42x; sparse cases are mixed. Full-model proving time remains
unmeasured. [Evidence and limits](ZK60_ROWFOLD_INTEGRATION_20260919.md).

> **CORRECTION, 2026-09-20 18:40 — read this before the 125M paragraphs
> below.** A defect was found today in the private block at every shape with
> more than one key-value head (both development sizes and the 125M shape;
> **not** the small accepted test block, whose acceptance D22 stands). **The
> verifier refuses an honest proof as soon as the hidden data differs between
> attention heads.** Every 125M result below — one block, two blocks, twelve
> blocks, tagged and untagged — was obtained on a synthetic input in which
> every head sees the same data, where the defect does not show. **So those
> results are true of the input they proved, and the 125M private block is NOT
> yet a working proof for general inputs.** The cause is understood (two
> attention steps treat a shared index as fixed where it must be summed over —
> the security owner's own construction error in generalising to grouped
> heads, missed by the design's checker and the code review because nobody
> proved a generic honest input); it costs completeness, and as far as argued
> not soundness: nothing false was accepted. The fix is being written now; it
> will change the proof bytes and sizes of the shaped profiles, and the 125M
> figures will be re-measured on dense weights and a generic input. The
> feed-forward half held up under the same test: dense weights, generic data,
> tampering at the wide hidden indices rejected. Found by the dense-weights
> test added this afternoon (finding S19-F1, lane `zk60-private-block-125m`).
>
> **Repaired the same evening (19:30), review pending.** The two attention
> steps now sum over the shared index. The honest input that was refused is
> accepted; a generic input on **fully dense** weights proves and verifies at
> the development size, as a three-block run too; tampering in the second
> key-value group is rejected by the verifier; the small accepted test block's
> bytes did not move. **At the 125M shape, one block on fully dense weights
> with a generic hidden input: prove 27.67 s, verify 1.12 s, receipt
> 40,783,352 bytes, peak 9.99 GiB; on the all-zero input: prove 26.98 s,
> verify 1.23 s** [MEASURED by the security owner, one run each, laptop CPU,
> shared box, 19:25]. Dense weights cost no measurable time. **These two are
> the first 125M results on a non-degenerate input; the twelve-block figures
> below have NOT been re-measured yet**, and an independent review of the
> repair (soundness, masking budget, completeness) is running. Still no
> privacy claim for anything but the small test block.
>
> **21:02 the same evening — reviewed, and the twelve-block run redone on a
> non-degenerate input.** The independent review found no hole in soundness,
> completeness or the masking budget, and confirmed that nothing false could
> have been accepted before the repair. **All twelve blocks at the 125M shape,
> fully dense public weights, a generic hidden input, one run under one
> transcript: prove 397.71 s, verify by streaming 14.45 s, receipt
> 484,107,456 bytes (equal to the counted figure), peak memory 10.15 GiB**
> [MEASURED by the security owner, one run, laptop CPU, shared box, 20:53].
> Every block's wide hidden layer, every attention head and every key-value
> group carries non-trivial values in that run. **This supersedes the
> twelve-block figures below as the project's 125M result**; they stay on the
> page as the record of what was run on the degenerate input. The privacy
> gate has not yet been run on a non-degenerate input (in progress at the
> development size), and **no privacy is claimed for any of this.**

**The 125M-shape block now proves in 17.4–19.4 s instead of 27.7 s — same
bytes, same refusals; independently reviewed (added 2026-09-21 10:00; second
sample and the range added 12:57).** *A second run of the same prover on the
same shared laptop, with a counting diagnostic switched on, took 19.36 s
(verify 1.34 s, same receipt length, peak 10,141 MiB); the parts of that run
the diagnostic does not touch moved more than the prove did, so it reads as
run-to-run spread, and the honest statement is a range from two runs, not
17.40 s.* One
block at the 125M shape, fully dense public weights, a generic hidden input:
**prove 27.71 → 17.40 s (37% less), verify 1.28 → 1.15 s, receipt 40,783,352
bytes in both, peak memory 10,232 → 10,156 MiB** [MEASURED, one run each,
laptop CPU, shared box; lane `zk60-private-block-125m` at `309d238`, log
`q28-m125-final-dense.log`, re-read by the security owner]. Nothing the prover
sends changed: the work was in how the same numbers are computed — the
lookup inverses come from a 256-entry table instead of 98.6 million
inversions (4.06 → 1.08 s), and the tables each of the 23 sub-arguments
starts from are built once and faster (6.01 → 0.59 s), with the slowest
sub-arguments roughly halved. The small accepted test block's bytes did not
move; the test filter is 319 passed, 0 failed. Because receipts are not
reproducible (fresh randomness every attempt, by an accepted privacy
condition), "same bytes" rests on ten old-against-new equality tests, the
size pins and honest proofs verifying — so an independent reviewer who did
not write the code attacked it. **Reviewed 10:40: no defect found, no
production line changed.** A complete twelve-block 125M run written by the
OLD prover is accepted by the NEW verifier (15.20 s, 476 MiB); 1,800
randomised old-against-new comparisons agree; the whole test filter passes
again on one thread (327 passed, 0 failed); no changed computation is
reachable from the verifier. The review also found four places where the
tests are thinner than the claim (one changed sum has no direct
old-against-new test, and the small shapes never take the parallel branches);
the security owner ruled that these are closed on the lane before the
integrator takes the stage (`ZK60_BLOCK125M_S28_DISPOSITION.md`). The all-zero
control run: 17.71 s, same receipt length. **What this does and does not mean
for the target:**
about 79% of the remaining 17.40 s (13.8 s: the shared masked-sumcheck loop
6.6 s, the two commitments 6.5 s, the openings 0.7 s) sits in code the
integrator owns, and the commitments are exactly what a GPU takes — but the
hash rule this profile uses does not run on the GPU path yet. This is a CPU
result at a 125M-shape block; the 5-second target is defined on the 8B
model's pass, where the best measured figure is still 58.4 s on public
inputs. It does not move that figure.

**Where the privacy of the 125M-shape block and of a twelve-block run stands
(added 2026-09-21 00:06).** Privacy is **accepted for one artifact only**, the
small test block (register D22); it was re-confirmed last night against the
integrator's newly merged code, and its checks now watch every source file on
its path. *2026-09-22: the integrator delivered a capture of a proof made by
the merged code's own binary; the gate replayed on it — every one of its 132
source pins matches the tree the acceptance names, no figure of record moved,
all ten tamper controls fire — so the acceptance now rests on the merged
tree's proofs as well as the old tree's. Same scope: that one small block, on
the CPU.* For the shaped block and a run, **nothing is accepted**, and this is
the honest state of the five-step argument:

| Step | Development sizes (two head geometries) | The 125M shape |
|---|---|---|
| The all-zero reference input proves and verifies | done | one block done; a two-block all-zero run done and captured (2026-09-21 08:57); a twelve-block all-zero run not run |
| Per commitment, the verifier's linear view discloses nothing | argument checked by an independent implementation and ruled; measured on fully dense inputs | **MEASURED for the first time (2026-09-21 11:18), on two two-block runs, dense and all-zero: the big commitment of hidden values discloses 0; the helper commitment discloses 2, checked to be exactly the public lookup identity; endpoints 0; the boundary between blocks 0 on all 6 of its reserved rows; the masking commitment 0; the whole run the sum of its parts.** 180 figures were predicted from the shape before the run and none came out unexplained. The independent tool first failed on three sub-arguments — a defect in the TOOL that only this shape could show (three of its domains are exact powers of two), now fixed with its own control |
| The gate constructs matching blinding values | **done for all ten commitments of a run, the two big ones included (2026-09-21 05:59): 4.76 million published values of four real runs reproduced from all-zero data, none differing**; **since 08:03 also the masking commitments, and one joint assignment for a whole run (4.95 million values over four runs, none differing)** | **done for two-block runs (2026-09-21 12:49, read out of the committed record by the security owner): all seven commitments on both the dense and the all-zero capture — 8.26 million published values each reproduced from all-zero data, none differing — and these per-commitment assignments are shown to be compatible with one another (no coupling between commitments touches a blinding row), so together with the masking layer they form one assignment for the whole run, 8.30 million values; about 21 minutes a run at 5.5 GB.** *Said more exactly at 14:26 after a second agent verified the first: the 8.30 million is the SUM of values each checked once in its own part, not a separate third check.* **Completed 2026-09-22 10:02: the repaired tool's full pass at 125M landed — every tamper-control family now fires at this size, and the 125M record carries the same channel table as the small shapes (28 channels: 10 constructed, 5 derived, 4 argued, 9 open). Three more small shapes that reach the 125M block's row width, head size, endpoint geometry and a layout correction went through the whole gate with nothing unexplained.** Not done: a twelve-block run (eleven internal boundaries instead of one) |
| All published values jointly do not depend on the input | accepted as a reduction; three named gaps being drafted or tested | the same |
| The hash layer and the step to the real (hashed) protocol | computed for what a proof opens; the argument for a run was checked independently and ruled on 2026-09-21 01:15 — it holds with changes, and its last step (composing the blocks of a run in sequence) is reduced to named hypotheses, not closed | for what a proof opens: 2,304 opened columns (52.9 MB) re-hashed under independently derived keys and authenticated, and all 27,828 challenges re-derived (11:18); the argument is the same document as at the development sizes |

Sized terms so far for a twelve-block 125M run [COUNTED, each recounted
independently]: the blinding sampler's bias about 2^-69.3 (decision D9); a
refusal that could depend on the input about 2^-114.8; a refusal on unlucky
challenges about 2^-58.8 per run, which costs a failed run and discloses
nothing. **What this means in plain words: the
construction has survived every attack thrown at it on the privacy side, one
of yesterday's attacks found a real completeness bug that is now fixed, and
the remaining work is argument and measurement, not redesign — but it is not
finished, and at the 125M size part of it will rest on argument plus
measurements at smaller sizes that share its geometry.**

**Latest on the fast line's private block (added 2026-09-20 07:10 by the
security owner's session):** one **complete transformer block with hidden
input, hidden output and hidden activations now proves and verifies at a real
model's shape** — the 125M class: 512 tokens, width 768, hidden 2048, 12 query
heads over 4 key-value heads — on the fast native line, on this laptop's CPU.
**Prove 26.89 s, verify from bytes 1.04 s, receipt 40,782,792 bytes, peak
memory 10.42 GiB** [MEASURED, one run, shared box, 2026-09-20 07:03; the
paper model had said 25–36 s and about 11 GiB]. What that is and is not:
**synthetic weights, one block of twelve, no GPU, and NOT a privacy claim at
this shape** — the privacy checks are owed again at every new shape and need
capture bundles that do not exist yet. Before it ran, the design was attacked
on paper (a padding hole was found and closed before anyone built it), grown
test-first through a small padded shape, and the code was attacked by an
independent reviewer who could not get a false statement accepted; the toy
block's bytes are unchanged, confirmed by verifying receipts made before the
work began. Lane `zk60-private-block-125m` (pushed, not yet integrated);
ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` on that branch. **For the toy block
only, the privacy argument now has a checked core at every step**;
the three rulings from Victor were accepted at 13:45, followed by D22 below
([one page](ZK60_RULINGS_FOR_VICTOR_PRIVACY.md);
[superseded draft](ZK60_PRIVACY_STATEMENT_TOY_PROFILE_DRAFT.md)).

**First privacy acceptance on the fast line (2026-09-20 13:46, register
D22):** the **toy private block** — one block, 32 tokens, width 16, public
synthetic weights — is accepted as private by the security owner, in the model
Victor accepted the same day (D19 the hash as an ideal random function, D20
timing/memory/power out of scope with refusals kept in, D21 rejected receipts
never sent and captures counted as publishing): a verifier's view is within
about 2^-77.7 per proof of one that does not depend on the hidden data. **For
that one small artifact and nothing else** — not the 125M block below, not any
multi-block run, not real weights, not sealing in advance. It is an argument
whose every step survived one independent attack, not a proof the security
owner re-derived; [the statement](ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md) lists
its residuals, the seven conditions under which it lapses and what reopens it.

**The separating hash tag is in, and the twelve-block run was re-measured
under it (added 2026-09-20 16:40):** decision D19 obliged every new shape to
hash its transcript, its column digests, its Merkle leaves and its Merkle
nodes under separate keys. That is built (register D19a; BLAKE3's keyed mode,
four public keys per shape, the verifier deriving them from the profile it
trusts; the toy block is never tagged, so the accepted bytes above do not
move), reviewed by the security owner, and authorised by the integrator as an
additive change to its files. **Under the tag, all twelve blocks at the 125M
shape prove and verify as one run: prove 393.59 s, verify by streaming
14.09 s, receipt 484,100,736 bytes (equal to the counted figure), peak memory
10.15 GiB; one block alone: prove 27.87 s, verify 1.21 s, 40,782,792 bytes**
[MEASURED, one run each, shared laptop with an agent active, CPU only, finished
16:39]. That is about 5% slower than the morning's untagged runs (370.61 s;
26.54 s) — **not attributable to the tag**: the two hashing phases moved one
up and one down, and a phase with no hashing in it moved more than either.
**A caveat on every 125M figure on this page, found 2026-09-20 17:30:** the
synthetic public weights used by all shaped tests are *diagonal* (64 on the
diagonal, zero elsewhere). Where the hidden layer is wider than the model
(2048 against 768), the upper part of the hidden layer therefore carries zeros
in every proof run so far: the wide geometry has been exercised in its sizes,
padding and checks, **not in its numbers**. No defect was found (the layout
was read line by line and one public table re-derived by arithmetic), and
proving time barely depends on the values (one phase skips zero weights; about
a second per twelve-block run [MODEL]). A dense-weights test with a
non-trivial hidden input is being added now, at the development size first.
The run now leaves its **public statement** beside its segments (written only
after the whole run verified), so a fresh process can check it. **Still no
privacy claim for anything but the toy block**, and the integrator has not yet
integrated or reproduced these runs.

**ALL TWELVE BLOCKS, ONE PROOF (added 2026-09-20 11:25):** a **private run of
all twelve transformer blocks at the 125M shape — hidden input, hidden output,
every activation and every block-to-block boundary hidden — proves and
verifies under one transcript: prove 370.6 s (6.2 minutes, about 30.9 s per
block, flat), verify 13.7 s by streaming one 40 MB segment at a time, receipt
484,100,736 bytes (equal to the counted figure to the byte), peak memory
10.15 GiB, on this laptop's CPU** [MEASURED, one run, shared box, finished
11:22]. What it is not: **synthetic weights, not a trained checkpoint; the
blocks only (no embedding, no output head — decision D13 says the blocks are
enough for the first MVP); no GPU; and no privacy claim for a run exists yet**
— the privacy checks for a multi-block run are designed and not built. Its
whole-run soundness is about 2^-97.5 by the project's accounting and its
receipt is 484 MB against a 256 KB budget; both are on Victor's page as
deviations for him to rule on.

**And blocks now chain (added 2026-09-20 10:48):** a private **run of two
blocks under one transcript** — block 1's hidden output is block 2's hidden
input, never published — proves and verifies at the same 125M shape: **prove
62.9 s, verify 2.0 s, receipt 81.1 MB in two segments** [MEASURED, one run,
shared box, CPU]. A verifier rejects a second block that was run on anything
other than the first block's output. This matters because separately finished
private proofs cannot be joined afterwards; a full model has to be one run.
Twelve blocks are counted at about 6.3 minutes of proving, 12.5 s of verifying
and 484 MB [COUNTED], with a whole-run soundness of about 2^-97.5 by the
project's accounting — and **no privacy claim exists for any run yet**; the
design, its independent check and the rulings are
[here](ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md) (register entry D12a).
Where a private block's 26.5 s goes is measured too: one softmax check 25%,
lookup inversions 15%, the two commitments 25%, the feed-forward part 5%
([plan §5.2b](ZK60_MVP_COMPLETION_PLAN.md)).

## 1. Do we have a workable proof?

**A complete small-block experiment works. The model MVP remains open.** Today at 19:18 the
first complete transformer block (T32 tokens, width 16, FFN 16, two heads,
the real integer kernel: both RMS norms, QKV, RoPE, causal integer softmax
attention, PV, output projection, both residuals, SiLU FFN) was proven by
re-execution inside the RISC Zero zkVM and wrapped into a **785-byte Groth16
receipt** that verifies in a fresh process in 8 ms. Seven corruption
controls (wrong context, model, input, output; truncated, trailing,
tampered bytes), plus the inner receipt kind, are rejected. Inputs, outputs
and activations are hidden under the reviewed Groth16 premises;
the public artifact is the receipt plus a 144-byte policy of digests.

| Stage | Result | Label |
|---|---|---|
| inner STARK proof (succinct receipt, 223,514 bytes) | 3,743 s on the shared laptop CPU, two threads | [MEASURED, NOISY-SHARED] |
| Groth16 wrap with the extracted native prover | 197 s | [MEASURED, NOISY-SHARED] |
| independent verification | 0.008 s | [MEASURED] |

**And, at 21:34, the first proof of actual token generation:** the
two-block token model (public embedding, two complete blocks with their
hidden seam, final norm and head, greedy next token; synthetic T32 fixture
with a 32-word vocabulary, not a trained model) proven by re-execution and
wrapped to a 785-byte Groth16 receipt; independently verified, eleven
rejection controls pass, and the block-profile verifier refuses it as a
different profile. Prove 7,488 s (2 h 5 min) on the shared CPU, wrap 197 s
[MEASURED, NOISY-SHARED]. Public artifacts retained under
`results/zk60_loop_20260918/token-integration/token_public/`.

What it rests on: RISC Zero's proof system at about 97 bits conjectured
soundness (D3), the Groth16 trusted setup (D4), Groth16 receipts only (D5),
and the salted-SHA-256 endpoint profile accepted under D7 at 11:50 on
September 19. The D7 qualifiers remain explicit: salt secrecy protects the
toy answer (the model library still accepts zero/repeated salts), the image
is locally built and not independently reproduced across directories, and
timing is declared leakage; the scan and cycle check cover only the block
program. Both receipts use synthetic tiny fixtures and make no model-speed
claim. D13 makes hidden model blocks the first MVP; token generation follows.

**On the custom prover line (hashline), the first complete private block now
proves and verifies (2026-09-19, 05:14), and at 06:25 the security owner
accepted it as an experimental component — still not a privacy acceptance.**
The same kind of block as above (T32 tokens, width 16, two heads,
feed-forward width 16: attention, both norms, both residuals, the SiLU
feed-forward) in **one native proof with no seam**, inputs, outputs and
activations hidden, weights public, on a public synthetic fixture. On the
security owner's own run: **prove 0.095 s, verify 0.043 s in a fresh process
from bytes only, receipt 2,816,472 bytes** — exactly the size the design
derived before any code existed [MEASURED, NOISY-SHARED, diagnostic only]; 38
unit, parity and tamper tests and 4 integration tests pass; the witness
matches the integer reference kernel element for element on 1,200 cases,
refusing exactly where the kernel refuses; nine tampers, including the one
that would let a prover choose the block's output, are rejected by the
verifier. For scale: the zkVM line needed 3,743 s for the same block. Since
then (05:49) **the project's leak-checking tools have been run on the real
source** (46 of 46 counts equal the design, nothing disclosed in any opening
group or at either endpoint, all 22 negative controls fire, zero differences
from the paper run) and **an independent adversarial code review found no
blocking problem** (every hidden plane is pinned, every relation equals the
reference kernel's, it could not construct a false proof the verifier
accepts); its two small defects and its missing tamper tests were closed by
06:19, every new tamper caught exactly where it was predicted, including the
one case where only a single lookup stands between a prover and a free hidden
value; 46 unit and 4 integration tests pass on the security owner's own run,
and a receipt made before those fixes still verifies after them. **What it
is not:** not a privacy acceptance (those tools check a
linear-algebra model that leaves out several channels; the caller-fixed-root
obligation D8/D11 is open; the joint-view gate on captured receipts is
unmet), not a trained model, and **not a speed result for 8B**: the form
built here deliberately gives up the GPU feed-forward prover, and a tenth of
a second at width 16 says nothing about width 4096. Branch
`zk60-private-block`; record
`results/zk60_private_block_evidence/README.md` there.

**Codex integration, 2026-09-19:** both native profiles are now in the main
worktree. The integrated block produces a fresh 2,816,472-byte receipt in
0.062–0.064 s and verifies it independently in 0.020–0.021 s on this shared
CPU with two threads; the original lane receipt verifies too [MEASURED,
NOISY-SHARED, tiny fixture only]. Fifty-seven combined Rust tests, 29
block-inventory tests, the full Python regression (1,098 tests, 61 skipped)
and native freeze pass. Attention's repeated byte-lookup inversions are
removed and its fixture scale labels corrected. Whole-proof privacy and
model-scale speed remain open. [Integration and evidence](ZK60_ATTENTION_INTEGRATION_20260919.md).

**Verifier captures now retained:** source-pinned recordings from two fresh
attention receipts and two complete-block receipts reproduce exactly in fresh
verifier processes. They include all 18/23 slots, M and PCS openings, pads,
sampled columns, salts and paths. Forty-nine native unit tests and 13 Python
capture controls pass; both pre-instrumentation receipts still verify.
[Capture format and review boundary](ZK60_NATIVE_CAPTURE.md),
[validation manifest](../../results/zk60_native_captures_20260919/validation.json).
This closes the capture-writer prerequisite. The complete joint-view analysis
and D8/D11 still need acceptance; no new proving-speed claim follows.

**GPU optimization validated:** Claude's compact intermediate for non-hiding
openings and the parallel host column split pass the integration checks:
261 CPU Rust tests, four configurations of 34 required-device commitment
tests, 12 device cache tests, all twelve frozen CPU/GPU/forced-chunked proof
digests, and native freeze. The full Python run covered 1,140 tests (61
skipped); its single lock-related error is resolved by a test-isolation fix
and a passing 18-test targeted rerun.
The local four-kernel gain is 1.162× [MEASURED]; its full-pass saving is only
0.8–1.8 seconds [COUNTED]. No new 8B proof clock is claimed. The next host
work targets redundant integer conversion/packing and repeated reductions.
[Review and retained evidence](ZK60_FSP_L9_INTEGRATION_20260919.md).

What else exists on that line: a private feed-forward component at the same tiny shape
with a bounded privacy diagnostic (whole-proof privacy not accepted, D8
open); public-IO proofs of real 8B feed-forward stacks (below); the private
attention schedule designed and rank-checked, and its native implementation
built and reviewed at the tiny geometry as an experimental component (§3
item 1).

## 2. How slow are we against the target?

The active target is **five seconds for an 8B model on better GPU hardware**,
reaffirmed by Victor on 2026-09-22. The older written 5–15-second FFN-only
contract remains a historical component benchmark; it does not establish
completion of the private model pass including attention. Keep the 512-token
prefill workload and the p95-over-20-warm-runs, idle-machine reporting rules.
The custom prover is the speed path; the 125M CPU clocks are development data.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO**, lane AL after the host fix | laptop RTX 4070 (55–70 W) | prove **58.40 s**, verify 1.08 s, proof 1.23 GB | **11.7× slower** than 5 s, 3.9× slower than 15 s, for the proving phase | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and accepted P1 privacy** | not yet built at 8B | no measurement | unknown | earlier ~290 s estimate withdrawn: the +4.7% CPU surcharge does not transfer to the GPU, and the legacy privacy profile has disclosure defects |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

The newer lane-AL result supersedes the earlier 95-second lane-AH headline.
Its retained log also records **134.50 s witness load+chain** and **196.79 s
total wall**; 58.40 s is the proving phase, not complete request readiness.
[Original measurement](../../results/hashline_convert_r3.log).

**Activation-side arithmetic (weight-commit phase subtracted).** The table
divides 512 tokens by the measured prove time minus its weight-commit phase
(Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2). This is an
optimistic accounting boundary, not a measured warm-cache rate: `--wcache`
still pays validation, upload and encoding work. Its warm-path performance
must be measured on the current implementation.

| run | prove | of which commit W | activation side | **tokens/s, W phase subtracted** | with W |
|---|---:|---:|---:|---:|---:|
| public IO, laptop GPU (lane AL, 2026-09-04, host fix, cold W cache) | 58.40 s | 19.823 s | 38.577 s | **13.3** | 8.8 |
| public IO, laptop GPU (lane AH, 2026-09-04) | 95.5 s | 41.9 s | 53.5 s | **9.6** | 5.4 |
| legacy `--zk`, laptop GPU (lane AI, same day; card 8.2 GB, run paged at 8.6 GB; privacy claim subsequently invalidated) | 265.3 s | 54.2 s | 211.2 s | **2.4** | 1.9 |
| public IO, laptop CPU (2026-09-03) | 510 s | 225 s | 285 s | **1.8** | 1.0 |

Labels: [MEASURED, NOISY-SHARED] per row; the division is [COUNTED]. These
are prefill rates (512 tokens per proof), FFN-only. The legacy `--zk` row was
starved of video memory (55% of its time is one paging-bound phase). It is
not a measurement of the repaired private profile or of a larger card.
The legacy profile's known disclosure defects remain decisive regardless
of those timings. One-token-at-a-time decode is far worse per
token: a single layer at 16 tokens cost 72% of the same layer at 256 on
the CPU, so per-token cost at small batches is 10–20× the prefill figure
[COUNTED from one measurement]; no decode run exists at 8B.

A bigger GPU (a 5090 or an H100) has not been measured. The project's own
throughput model says the built design does not reach the goal on any GPU
without the recorded design changes (preprocessed weights, the two-tier
opening; `START_HERE.md` §2 and §5), and that those changes were counted,
not built. Honest summary: **on today's laptop the public-IO 8B proof is
one to two orders of magnitude off the target, and the private version of
it does not exist yet.**

## 3. What blocks a private, model-scale MVP at speed, and what is being done

1. **Private attention on the custom line: implemented and reviewed at the
   tiny geometry (2026-09-18, late evening).** A delegated Fable lane built
   the native masked prover and verifier to the construction; the security
   owner's lane compiled it with zero fixes, ran its 16 tests, proved and
   fresh-process-verified the example (0.09 s, 2.2 MB receipt), regenerated
   the rank and CFS checks on the layout it actually declares (nothing
   disclosed; H residual = the public identity; all 18 slots and 5 host
   groups pass) and re-derived the arithmetic bounds (all hold). Accepted as
   an experimental component (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md`
   on branch `zk60-attention-compile`). Using one 8-bit range table instead
   of the 65,536-entry ones cut the commitments to 306 and 290 rows. Still
   missing for this attention-only profile: the second norm, the FFN and
   residual 2; the complete-block profile above now includes them.
   The 2026-09-19 gap inventory
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on `zk60-attention-compile`)
   sorted fifteen gaps into engineering and construction work under D12.
   The capture writer, fixture scale-tag fix and tiny-block kernel parity
   are now implemented and tested; model-width construction remains open.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist and real native captures are retained. Their joint-view
   adapters and the caller-fixed-root obligation are still open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **Current lanes:** Fable's GPU kernels and host staging port, then a
   separately labelled repaired-mask cost probe; Codex's capture review
   handoff and remaining zkVM hardening/ceremony integration. No model-width
   GPU measurement window is reserved. The two-block token-model proof landed
   (§1). **Earlier restart/build history:** the
   laptop restarted at 01:04 on 2026-09-19**: git and the retained receipts
   are intact and everything was already pushed, but the `/tmp` scratch area
   is gone, which killed the queued ceremony checker before it ran (Codex
   relaunches it) and erased the uncommitted Opus phase-diagnostics work
   (restarts from zero). **Both Groth16 receipts were re-verified in fresh
   processes after the restart** (block and token; each profile's verifier
   refuses the other's receipt) [MEASURED]. Three read-only reviews by the
   security owner's Opus agents landed by 01:30: the token model's source
   review (no code defect; the retained build-source record is stale for
   the wrapper; hardening items for Codex), the response to Codex's review
   of the hardening lane (all six of its findings correct, four already
   fixed soundly, one new low-severity gap), and the inventory of what a
   complete private block on the custom line still needs. That inventory's
   central finding is now **ruling D12**: the two existing components may
   not be joined by sharing one hidden commitment between two proofs,
   because two openings at that geometry reveal all 512 hidden words; a
   block is one proof under one transcript, and the second norm must prove
   its output's range because the feed-forward prover does not. **At 03:01
   the design of the complete private block was accepted as the design to
   build** (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on
   `zk60-attention-compile`): the attention construction is grown into the
   whole block, so there is no seam to prove; drafted and independently
   checked by delegated agents, with the project's rank and slot tools run on
   a paper description of the whole block (nothing disclosed; every negative
   control fires) [COUNTED on a description, not measured on code]; 22
   corrections made binding, including two that would have been soundness
   holes (a block whose output the prover could choose, and an activation
   table whose value range nothing enforced). This is a design, not a privacy
   acceptance and not a speed result. Expected size at the tiny shape: a
   2.8 MB receipt. Building started on `zk60-private-block` at 04:07;
   the initial witness-only checkpoint was subsequently superseded by the
   complete proof and its integration described in §1. Earlier items:
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`), now implemented and verified on branch
   `zk60-zkvm-hardening` for Codex to integrate (secret-scan stage,
   environment refusal and scrub, cycle reporting, constant-cycle gate with a
   real executor run, tool-check command, work-directory cleanup,
   claim-shape regressions). Codex reviewed that delivery (no acceptance
   defect in the Rust; one runner incompatibility with the token profile and
   several wording and test-scope corrections, which Codex is applying). The
   ceremony checker never ran (see the restart above); no ceremony-check
   success is claimed. **Rulings made by Victor on 2026-09-19 (11:50):** D7
   accepted — the zkVM line's two receipts may now be called private under
   D3, D4, D5 and D7, with three written qualifiers (salt secrecy carries the
   32-value toy answer; the program's identity depends on its build
   directory; timing is declared leakage); D9 accepted as stated (a privacy
   residual of about 2^-72); D10 declined (the compact proof format cannot
   run privately); new D13, the hidden blocks are enough for the first MVP
   and generating a word is the next milestone; new D14, a costed memo for
   the one design lever that could take a 5090 below 10 s, paper only; and
   the RTX 5090 install is a go (date, machine and RAM still to be named).
   **Speed, honestly, as of 13:42 (`ZK60_FIVE_SECOND_PLAN.md`, three dated
   corrections at the top of its §5):** 5 s is outside every assumption
   recorded in this repository, and the costed memo commissioned under D14
   confirms the one design lever left cannot reach it (best case on a 5090
   about 7–9 s, for 15–25 lane-weeks and a 60% larger proof). The plan's three
   software steps were built today, all byte-identical and green: together
   they are worth **about 4–5 s of the 58.40 s [COUNTED]**, not the 24 s first
   projected — every counted step shrank three- to seven-fold when measured.
   On this laptop the public 8B pass is a roughly 55 s pass. Whether the 5090
   reaches 15 s is **open** until its first measurement; 16–19 s of today's
   pass is host work the card does not touch.
   **The most valuable missing number now exists, at the small shape:** the
   *repaired* private mask scheme ran for the first time above the tiny shape
   (45 runs, zero refusals, 12 layers × 512 tokens at the 125M shape, three
   arms on one binary, endpoints public in all three — a cost probe, not a
   privacy result): **repaired ÷ legacy = 1.06 on the GPU binary and 1.00 on
   the CPU binary; repaired ÷ public = 2.05 on the GPU** [MEASURED]; proof
   bytes +0.75% over legacy; by row count +1.8% at Mistral width and about
   +1.6% on a Mistral layer [COUNTED, not run]. So the repaired masks cost
   what the legacy ones did, within a few per cent; what is still unmeasured
   is the other half of P1, the hidden endpoints at model width.
   **Privacy path, same day:** on Codex's retained captures of two block and
   two attention receipts, a gate that replays the transcript at the
   receipts' real challenges finds nothing determined about the hidden data
   beyond public identities, with the 256 sampled columns included, and every
   sabotage control caught — evidence on a linear model of four receipts,
   **not** a privacy acceptance (D8/D11 open); and the private block's norm
   was shown free of the soundness gap the older prover has, with the
   precondition for widening it recorded as D16.
5. **A reproducibility fact to settle before any approval record:** the
   guest image ID depends on the build directory (the ELF embeds one
   absolute source path and the non-Docker build applies no path remap), so
   the approved ID `8d74aab3…98d9` is reproducible only from the main
   checkout's path or from a reproducible Docker build.

## 4. Where the evidence is

Public artifacts of today's Groth16 receipt are retained under
`results/zk60_loop_20260918/block-integration/groth16_public/` (policy,
receipt, public model, stage records, hashes); the `/tmp` originals do not
survive a reboot and a new randomized receipt would have different bytes. The loop's own
record is `ZK60_MVP_LOOP_20260918.md`.

## 2026-09-29 (PDT): VC readiness snapshot for Tech Week SF

Added 17:40 PDT on 2026-09-29 (00:40 UTC on 09-30) by the Lane D agent.
This section repeats the facts in
[`results/zk60_vc_readiness_20260929/READINESS.md`](../../results/zk60_vc_readiness_20260929/READINESS.md).
That note also has a one-page `DEMO_SCRIPT.md`, the projection arithmetic
(`extrapolate.py` → `extrapolation.json`) and a light rehearsal script. No
heavy proof ran. Nothing in this section is a new ruling or privacy
acceptance.

**What can be shown truthfully now.** Everything below was re-checked on the
laptop CPU between 17:18 and 17:24 PDT (`rehearsal-20260930T002413Z.json`):
- Both retained 785-byte Groth16 receipts verify in fresh processes, with
  exit 0 in about 0.08 s each including the wrapper. One is the tiny complete
  block; the other is the synthetic two-block token model.
- A one-bit-flipped copy of the block receipt is refused.
- The toy native private block (the D22 profile) proves in 0.10-0.11 s.
  A fresh process verifies it in 0.05-0.06 s and refuses three corrupted
  copies [MEASURED].

Before quoting D22 on stage, confirm that the 2026-09-20 example binary
matches D22's source pins. The integrator's browser demo
(`ZK60_TECHWEEK_DEMO.md`) is the stage vehicle for these checks.

The scale evidence is unchanged:
- One synthetic 125M-geometry block: 17.13 s GPU-arm proving versus 32.95 s
  on a 2-thread CPU.
- The twelve-block 125M-geometry run: 397.71 s on CPU, or **1.29 proved
  tokens/s**. This is the only measured complete-stack rate: synthetic
  weights, CPU, one run.
- A twelve-block GPU attempt today (`results/zk60_mvp_20260929/baseline-stack-gpu/`)
  failed at harness setup because its receipt directory was missing. It was
  not a proof failure.

**Projection, labelled [MODEL].** Each measured phase of the 125M A/B is
scaled by its own layout domain. This gives 2.18x per block at the TinyLlama
1B geometry and 3.09x at the Llama-3-8B block geometry. Plain row counts give
2.25x and 3.25x. Prove-only rates for 512 tokens:

| Configuration | Stack prove | Proved tokens/s |
|---|---:|---:|
| 1B, 22 blocks, laptop GPU arm | 822 s | **0.62** |
| 8B, 32 blocks, laptop GPU arm (does not fit this laptop) | 1,692 s | **0.30** |
| 8B, RTX 5090 with today's code | — | 0.62-1.23 |
| 8B, 5090 with every proof sumcheck on the GPU (not built) | — | 5.1-12.6 |
| 1B, 5090 with every proof sumcheck on the GPU (not built) | — | 10.5-26.1 |

The witness build must also move to the GPU. At 8B it is 27-285 s per block
on CPU [MODEL band]. The gap to 50 at 8B is 165x on the laptop today and
4-10x in the best counted scenario. **No recorded assumption reaches 50
proved tokens/s for a private 8B stack.** Larger workloads amortize under 1%
today, because per-token proof work dominates.

**Claims to avoid** are listed in READINESS §3. In short: no full or trained
model has been proved privately; no private rate exists at 1B or 8B; D22
covers only the CPU toy; the 97-bit, Groth16-setup and unreproduced-image
qualifiers travel with the 785-byte receipts; the fast line's receipts are
about 41 MB per 125M block; there are no 5090 numbers; and there has been no
third-party audit.

**Next measurements** (the READINESS §4 week plan, aligned with the
integrator's gates):
1. Retry the twelve-block 125M GPU run.
2. One synthetic TinyLlama-geometry block on the 4070. It is projected at
   37 s, and the counted floors are about 3.7 GiB VRAM and 6.9 GiB host.
3. The 22-block 1B-geometry run.
4. Laptop thread scaling.
5. The first 5090 A/B, only if Linux is installed by about 10-02.

The trained TinyLlama block is the integrator's 10-02 stretch gate.
