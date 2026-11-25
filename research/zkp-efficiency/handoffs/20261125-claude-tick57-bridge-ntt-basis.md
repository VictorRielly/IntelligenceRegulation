# Research handoff: why the spike's bridge runs a forward NTT, and whether the device already has the kernel (2026-11-25, claude tick 57, queue item 97)

From the Claude background researcher. Reading and arithmetic only: no build, no run, no web search, no Git. Written: this file,
`20261125-claude-tick57-bridge-ntt-basis.py` (standard library, under a second) and its output `...bridge-ntt-basis.out.txt`.
Triage material, not a work order.

**Read in full.** The spike runner `zk60_b6a_spike.rs` (`results/zk60_sol_20261105_w16r3/b6a/source-wp0/`, lines 1-150), the running
tree's `metal_commit_zk` and `commit_impl` (`ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs:2772-2870, 2988-3003`), `encode_fused`
(`:579-621`), the head kernel's input modes (`metal_kernels.metal:243-262`), `encode_row_zk` (`ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs:674-691`),
`ntt.rs:55-67`, and Sol's pinned `tower.rs:36-110` and `pcs/switched.rs:405-430`. Labels: COUNTED (file:line), MEASURED (record),
DERIVED (arithmetic in the script).

## 1. Result

**Pass, "removable by committing in the other basis", and the route to it is an existing kernel pair.** The bridge exists only because
the device commit's API takes evaluations; the CPU tower's definition takes coefficients; the two meet at the same codeword, so the bridge is an
adapter, not part of the commitment.

- **CPU basis (the tower's W and W2):** the row is a vector of coefficients. `CoefficientRs::encode` (`tower.rs:72-92`): entry i times 7^i,
  zero-pad to `positions`, one forward NTT of size `positions`. Its `generator` (`tower.rs:94-108`) is the powers of a point, i.e. the same coefficient reading.
- **Device basis (`metal_commit_zk`):** the row is n evaluations on the size-n subgroup. `commit_impl` runs an inverse transform (`encode_fused`
  with `MODE_COPY` and the 1/n scale, `metal.rs:2866`), then the coset-powers-and-pad head with a forward transform of size nn
  (`MODE_ZK`, `:2870`), then the column hash. Same as the CPU's `encode_row_zk` (`pcs.rs:674-691`: `ntt.inverse`, pad, `pows`, `ntt.forward`).
- **Why the bytes agree:** forward then inverse is the identity, so the spike's 96 forward transforms (`zk60_b6a_spike.rs:96-99`) followed by the device's
  inverse hand the coefficient row back unchanged; the spike passes one zero pad word per row (`zeros = vec![0; W_ROWS]`, line 76, so `q = 1`; the
  device refuses `q = 0`, `metal.rs:2998-3001`), and with a zero pad the ZK head (`metal_kernels.metal:248-260`) multiplies coefficient i by `pows[i]` and writes
  zeros beyond, exactly the tower's encode. The run asserts equal keyed leaves, equal sampled columns and equal salted root (spike `:124-131`, MEASURED).
  DERIVED check at toy size (script part A, n = 16, 64 positions, q = 1 zero pad): the two routes give identical codewords, and a nonzero pad does not.

## 2. Cost of the bridge, and what the device would shed (script parts B, C, D)

- **Host:** 96 rows x (2^14 / 2 x 14) = **11,010,048 butterflies**, plus a 12.6 MB `to_vec` so the rows can be transformed in place (`:96-99`). MEASURED prep timer
  (`measure.log`, 7 measured iterations): **5.88 ms at rate 1/4** (6.24 at 1/8, 5.82 at 1/2), 0.53 ns per butterfly all-in on five threads.
  It is 3.7 to 6.6 times the device commit itself (1.67, 1.18, 0.88 ms). Removing the bridge returns all of it (the upload stays inside the commit's encode wall).
- **Device:** the inverse pass is 13 to 19% of a commit's device total in the retained staged logs (TinyLlama golden logs, rate 1/4, 2^14 -> 2^16, eight lines,
  4.0 to 4.4 us a row against forward 15.5 to 16.1 us), so **0.16 to 0.22 ms** of the spike's own 1.18 ms, an upper reading since staged timings split one buffer
  into parts. The 12.6 MB `to_vec` and the host transform vanish; the device gets cheaper, not dearer.

## 3. How the device could take coefficients (existing kernels, one host edit)

By reading only, no existing function does it, but no new kernel is needed:

1. The default path is not the fused one: `HL_METAL_FUSED_RS` is off unless set (`metal.rs:462-478`, default `false`), so `commit_impl` takes the two-stage branch
   (`:2865-2872`): `encode_fused(... MODE_COPY, ... Some(ninv))` from the upload buffer `d` into `t`, then `encode_fused(&t ... MODE_ZK)` into the encoded buffer.
2. A coefficient-input entry point (an `Init` variant or a flag on `metal_commit_zk`) would skip the first call and give `d` to the second as source
   (`log_src = log_n` already means "2^log_src words of the source row", `encode_fused :588`). The `t` buffer (`rows * n * 8` bytes, `:2809`) is not needed.
3. Under `HL_METAL_FUSED_RS=1` the zero-gather DIF-INTT to DIT-FWD kernel does the inverse inside; that mode would have to decline for the new entry or gain a
   forward-only variant. It is off in production, so this is a note, not a blocker.

This is a source change in the running tree's Metal file (the prover), so it needs a ruling and the byte-identity gates (the spike's own asserts, plus the
`encode_conformance_tests` vectors, `pcs/encode_conformance_tests.rs`). Proof bytes: **0 words changed**, since the codeword is the same.

## 4. Falsifiable test (not scheduled; in an isolated copy)

- **T-B1:** add the coefficient-input entry (skip the `MODE_COPY` pass), drop the bridge from the spike's M1, keep the three asserts (leaves equal the CPU
  tower's, sampled columns equal, root equal) at rates 1/8, 1/4, 1/2. Pass: asserts hold at all three rates, `prep_host_ms` is 0 (a few hundred
  microseconds if the upload is timed separately), `gpu_ms` falls by 0.10 to 0.25 ms at 1/4. Fail: leaves differ (then the device's `MODE_ZK` is not the
  tower's encode at q = 1; the conformance vectors say where).

## 5. Expected effect

Host time of the size step: **-5.9 ms at rate 1/4** (6.2 at 1/8, 5.8 at 1/2) of the +99 ms spike gap, with tick 56's other changes untouched; stacked with them,
tick 56's remainder of about 29 ms falls to about 23 ms, still above the +15 ms line (the 5.9 ms was counted there as "bridge"). Committed words: 0. Proved tokens
per second: at most x ms x 32 / 3,180 of the 3.18 s period, so 5.9 ms is at most 5.9 x 32 / 3,180 = 5.9% of a request's period at full pass-through, and the hidden share is
unmeasured. The size step is a build under D82; this is a host change inside it, not a protocol change.

## 6. Risks and not verified

- The bridge could be avoided only if the real B6a W rows reach the commit as coefficients. In the pinned prover they do (`switched.rs:416-424`: `open_zk_vectors`
  rows are packed and handed to `prepare_w`, whose code is `CoefficientRs`); I did not read `pack`, so whether the 96 rows are produced as one contiguous buffer
  (the spike assumes so) is unchecked.
- `MetalCommit` keeps `data` (the uploaded rows) for the hiding form and `fold_rows_*` reads it as evaluation-basis rows (`metal.rs:1629-1688`). A coefficient-basis store
  folds coefficient rows by the same linear weights, which is what the tower wants, but I did not trace any fold or `columns()` call that interprets the stored rows as
  evaluations; T-B1 does not test folds.
- W2 (width 1,024, 16 rows x 2 components, 32,768 positions) is the same adapter in the tower (`switched.rs:413`); the spike keeps it on the host, so the device-W2 route
  (tick 56 section 1) carries the same coefficient-input requirement and no bridge cost is measured for it.
- The device-inverse share comes from TinyLlama golden logs, not the spike's 96-row shape; the spike's own record has only the whole commit's GPU time.
