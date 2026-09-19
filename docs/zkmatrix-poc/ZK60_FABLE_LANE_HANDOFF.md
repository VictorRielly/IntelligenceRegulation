# Fable lane handoff — branch `zk60-mvp-fable` (pushed; tip `679ac26`, base `763e308`)

Written by the interactive Claude Fable 5.1 session on 2026-09-18 so the
integrator can find two unreviewed deliveries. This file is a pointer only;
the shared boards are the integrator's.

## 1. Round 2 of the MVP security decision (2026-09-15) — answers the "next acceptance gate" of `ZK60_MVP_REVIEW.md`

Memo: `docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md` on the branch. It does **not**
repeat the two rejected round-1 claims; it rules the opposite way on both:

- the caller-fixed external-root obligation **stays** and is met by a
  simulator that programs exactly one random-oracle point per endpoint root
  (two per proof) in the programmable-ROM model Fiat–Shamir already assumes;
  the joint-preparation workflow programs none;
- the adaptive lift is a lemma whose hypothesis is the **joint** law of every
  field value at fixed challenges; the round-1 marginal evidence did not supply
  it, and Codex's `H(mask), mask ⊕ w` counterexample violates the hypothesis,
  not the lemma.

Executable: BLAKE3 transcript replay of the four round-22 receipts (every
captured checkpoint matches; the six FFN slots' challenges recovered), the
joint PCS-side view **with opened columns** (disclosed = O8's numbers exactly),
the joint CFS/M-opening view at captured challenges (honest disclosed 0),
the root simulator bookkeeping, and the sequential-kernel lemma checked
exhaustively on finite models. One-command gate
`scripts/zk60_mvp_joint_view_gate.py` (10 stages, all passed; record under
`results/zk60_mvp_joint_view_evidence/`).

## 2. Private attention construction (2026-09-16) — A1–A4 for the custom-PCS path

Memo: `docs/zkmatrix-poc/ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`; schedule
`zk60_private_attention_schedule.json`. Six private claimed sums via masked
scalars hosted by ν-batched zero-checks (the FFN's gu/ZC20 form), QKV slot
split by domain, one zero-sum row for the nineteen helper sums, histograms
committed, eighteen mask slots / 40-row M, hosts after hosted slots. Rank
tool (whole A/H/W disclosed 0, H = public identity only; 33 tests) and CFS
tool (18 slots, 5 host groups; 97 checks, 14 tests). Row cost ≈ 77 MB at
A00, dominated by the two 65,536-entry tables.

## 3. Disposition of the zkVM construction review (2026-09-18)

`docs/zkmatrix-poc/ZK60_ZKVM_REVIEW_DISPOSITION.md` on the branch: every
[RECALLED] item of the headless review's §15 checklist verified in the local
risc0 3.0.x source (fetched 2026-09-18 08:17), with corrections: the guest
toolchain and crates are present; Docker is absent; a CUDA Groth16 path
exists but its rzup component is not installed; the rv32im segment prover
adds no blinding rows (composite receipts are never public, as a fact); the
target is exactly 97 bits conjectured at 2^20 segments. Ruling: sound as a
functional intermediate with Groth16 receipts, under three rulings for
Victor (sub-128-bit deviation, trusted setup, prover path) and a new
endpoint/weight identity profile.

## 3a. Source review of `zkvm-block/` (2026-09-18, evening)

`docs/zkmatrix-poc/ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on the branch:
guest, statement, model, host, wrap and the security calculator read line
by line against D5 and the disposition. Verdict: consistent, no defect;
eight hardening items (host should scrub `RISC0_DEV_MODE` itself; wrap
should pin the native tool hashes; default to removing the private work
directory after a verified wrap; add the P1 secret-scan and P3
constant-cycle evidence; label the image ID unreproduced; keep segments at
or below 2^20; add a D4 claim-shape regression). D7 remains Victor's.

## 3b. First Groth16 receipt verified; evidence retained (2026-09-18 19:18)

The security owner re-verified `demo-public/groth16.bin` (785 bytes) in a
fresh process: `{"verified":true,"kind":"groth16"}`. Public artifacts were
copied to `results/zk60_loop_20260918/block-integration/groth16_public/`
(no private files) because `/tmp` evidence does not survive a reboot. D6 is
closed in the register. For Codex: the eight hardening items of §3a are the
suggested next hardening pass; the P1 secret-scan and P3 constant-cycle
evidence are the two cheapest. `MVP_STATUS.md` now carries the plain-words
status Victor asked for; please keep it current when your loop lands news.

## 3c. Token-model build failure diagnosed (2026-09-18 19:23 markers)

`token-build.done` and `token-proof.done` are both `1`. The build launcher's
stage `token-host-build` runs
`cargo build --release --offline --locked -p zk60-token-host -p zk60-token-wrap --examples`;
with `--examples` cargo builds only the example targets of those packages,
so `zkvm-block/target/release/zk60-token-host` is never produced (the
stage "succeeds" in 0.11 s), the launcher then fails with
`FileNotFoundError` on that path, and `token_prove.py` refuses to start.
Fix: `--bins --examples` (or drop `--examples` from that stage and build the
example packages separately, as `token-export`/`token-rust-vectors` already
do). Everything before it passed (workspace tests 82 s, export, Rust and
Python vectors agree on all three digests).

## 3d. Hardening lane `zk60-zkvm-hardening` (from db021ba) and a reproducibility finding

Opus agents under the security owner implemented the review's items on a
lane branched from Codex's checkpoint: runner `secret-scan` stage (61
tests), host environment scrub plus executor cycle/segment reporting, the
P3 constant-cycle gate with a real executor run (nine inputs: padded total
cycles and segment count identical, user cycles vary by 17,610 = 0.27%,
declared as host-side timing leakage only; record under
`results/zk60_zkvm_hardening/cycle_gate/`), and wrap-side additions
(the checkpoint already pinned the tool hashes in `zkvm-native-tools`, so
the lane adds a `check-tools DIR` subcommand, a test that the linked pins
equal `groth16-native-files.json`, default removal of the private work
directory after a verified wrap with `--keep-work` to retain it, and
claim-shape regressions for Paused, non-empty assumptions and wrong
verifier parameters, with the check ordering documented). **Lane pushed:
`zk60-zkvm-hardening`, four commits.** Verified by the security owner: host
6 tests, wrap 8 tests, runner 61 tests, cycle gate 12 tests, real
`check-tools` on the extracted tools. Two contract notes for integration:
(a) the runner now passes `--keep-work` (it owns the private tree); a hand
run of `wrap` removes the work directory on success; (b) the host refuses
`RISC0_*`/`BONSAI_*` switches loudly before scrubbing `RUST_LOG*`, so the
refusal semantics of the checkpoint are preserved. Known box quirk hit
again: the toolchain-directory cargo fails on the `ff` crate with
`Unrecognized option: 'check-cfg'`; the `~/.cargo/bin/cargo` shim works.

**Finding for the approval record:** the guest image ID is
build-path dependent. Every guest-affecting source on the lane is
byte-identical to the checkpoint, yet `image-id` prints
`c5a04b83448eb2a17919e38a9a00db7edfab4bdc979800ee867be11f5dc295a5`
instead of `8d74aab3…98d9`, because the guest ELF embeds one absolute
source path (`private-block-kernel/src/lib.rs`) and `risc0-build` 3.0.6
applies no path remap outside its Docker mode. Consequence: the approved
image ID is reproducible only from `/home/victor/IntelligenceRegulation`
or a reproducible build; the README's "locally built, unreproduced" label
now has a concrete cause, and a registry entry should pin the build path
or move to the Docker build before any approval.

## 3e. Native private attention delivery: compile pass and R-1/R-2 reviews in progress (2026-09-18, late evening)

The headless attention lane's delivery (`/tmp/wt-zk60-attention-fable-20260918`,
uncompiled: cargo was denied there) has been copied unchanged onto lane
`zk60-attention-compile` (from db021ba). Three Opus agents under the
security owner are running there: (1) compile and run its own tests and
example with the smallest fixes and no design change (design-level
failures are reported, not patched); (2) its review request R-1, the
pair-schedule rank and CFS slot checks regenerated on the layout it
actually declares (306/290 rows, 75/35 sites, 18 slots); (3) its request
R-2, the no-wraparound bounds, isqrt/softmax exactness and the
extension-round premise per slot. **Done and pushed (`zk60-attention-compile`, three commits):** the delivery
compiled with zero fixes; 11 unit + 4 integration + 1 doc tests pass; the
example proves in 0.09 s (2,245,800-byte receipt) and verifies in a fresh
process with three refusals; R-1 regenerated on the declared layout gives
disclosed 0 on A, every group and each endpoint, H residual = the public
identity, all 18 slots and 5 host groups pass the CFS criterion, 11 rank
and 7 CFS negative controls fire, and every derived count matches the
note (29/29); R-2 holds (all bounds < 2^49, exact limbs, isqrt/softmax
pinned, extension premise mechanically verified) with eight cosmetic flags.
Disposition: `ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md` accepts the
deviations (single U8 table, degree-4 softmax, no W under P1, module-local
rows, extra refusals) as the experimental component; it is not a block
(norm_m, FFN seams, residual 2 remain) and not whole-proof privacy. Codex:
integrate, the three cosmetic follow-ups, and a schema-3 capture writer so
the round-2 joint tools run on its real receipts.

## 4. Relation to the zkVM loop of 2026-09-17

Both deliveries concern the custom-PCS path, which remains the route to the
throughput target. The zkVM route is the shorter path to a complete private
tiny block; its receipt-kind, security-bits and leakage questions are being
assessed by the headless Fable lane, and the interactive session will
adjudicate that review against `ZK60_PRIVACY_REQUIREMENTS.md` when it lands.
