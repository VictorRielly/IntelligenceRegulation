# A13: each fork's before-challenge part during the sealing pass (2026-11-05): a negative result

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A13. Byte-preserving.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, the
A11/A12/A8 defaults, on the shared M3 Ultra.

## Plain summary

- **The idea.** A fork's transcript starts from `S0`, which needs every boundary root, so no fork starts until the whole
  sealing pass (32 serial witness builds) has run. But `protocol::prove_core` uses no transcript until it absorbs `A`'s
  root. Everything before that point needs only the block's own witness and the fork's generator:
  - `A`'s rows from the witness, the lookups and histograms, the CS-3 refusal;
  - `A`'s mask rows (`rng.fill_fp`);
  - `A`'s commitment and `M`'s commitment.

  A13 makes that part for each block beside the sealing pass, so the fork starts from it.
- **It is byte-identical, and tested.** Details in §1 and §3.
- **It does not pay, so the default is OFF** (`HL_D55_AHEAD` unset). The exploratory A/B (§4, 2 passes, both orders)
  [MEASURED]:
  - with all 32 parts made beside the sealing pass, the request's forks phase falls **−9.4%** (3.81 → 3.45 s);
  - but the sealing pass rises **+9.2%** (4.24 → 4.63 s) and the statement checks and commit phase +17%;
  - so one request from its input is **+1.1%** (worse, within the noise);
  - the 4-request stream is **−7.3%** steady (worse);
  - smaller windows and other side-worker counts do no better (§4);
  - the peak footprint roughly doubles (§5).
- **Why** [INFERRED]: the sealing pass is on the critical path, and its witness builds fill the cores in bursts. The parts
  add about 13 CPU-seconds during the sealing pass (42.9 → 55.8 CPU-s), and the chain slows by about what the forks
  save. In the stream the sealing side becomes the bottleneck: a sealing pass with its parts takes 5.9–6.1 s.
- **The ceiling was lower than estimated.** Taking the whole part off the forks saved 0.36 s of the forks phase, not
  the ~0.75 s the per-block phase times suggested. Even a free part would take about 0.3 s (−3.6%) off one request
  [INFERRED], not the 0.8 s first estimated.
- **The mitigations in stage 4** (side workers at background QoS, parts not yet started handed back to the forks)
  and **a separate candidate item** (the sealing pass's witness builds in a smaller rayon pool, harness probe `sp16` /
  `sp8`) are §6. Stage 4 was still running when this was written; its results are in `s4.progress` and
  `s4_d55_ab.log`.
- **The coordinator's decision:** the ahead mode is not merged (no gain, added complexity in two privacy-gated files).
  The code is committed separately on this lane's branch as a record.

## 1. What moved ahead, and why no byte can move

**`protocol.rs`:** `prove_core` is now `prove_core_before` followed by `prove_core_after`, with a `CoreAhead` state
between them.
- **The before-part** holds the witness, the lookup values, the histograms, the committed `A` and the committed `M`,
  and their two roots, not yet absorbed. It is exactly `prove_core`'s old statements, in order.
- **The one reordering:** `A`'s root is absorbed after `M` is committed instead of before. `zk::mask_commit_tagged`
  reads no transcript, so the transcript sees the same absorbs (`A`, then `M`, then the LogUp challenges) and the
  generator the same draws:
  1. `A`'s mask rows;
  2. `A`'s pads and salts;
  3. `M`'s masks;
  4. everything after.
- **Nothing before the split is derived from the transcript.** `rng` is the only stateful input.
- **A check:** `prove_core_after` refuses a state made for another profile or layout.

**`run_fork.rs`:** the fork's context is split into an early part and a late part (`ForkLate`: the roots, IO data and
binding).
- `ForkCtx::prove_one` builds the fork's ONE `ZkRng::from_os` (the D55 census's site, unchanged) and runs the
  before-part.
- **Before the commit phase,** it returns the fork as a `Parked` value with the generator inside, moved by value: never
  cloned, copied or shared, and nothing else draws from it.
- **After the commit phase,** `finish_one` opens `fork(S0, k)` and runs the rest, on any fork worker.
- **Entry points:**
  - `prove_run_with_forks_sealing`: one request, in one scope;
  - `seal_ahead` then `prove_run_with_forks_ahead`: a stream's form, which checks the binding and the blocks object.
- **The queue:** `Slots`. The sealing pass hands witnesses over in block order, and side workers on their own rayon
  pools take the lowest block first. In stage 4's form, a part not yet started when the forks run is taken back whole.
- **Switches:**
  - `HL_D55_AHEAD=<window>`: default 0, off;
  - `HL_D55_AHEAD_WORKERS`: default 2;
  - `HL_D55_AHEAD_POOL`: default 6;
  - `HL_D55_AHEAD_QOS`: 0 none, 1 utility, 2 background.

Which thread or pool runs a part changes no word (A11).

**s25's generator census still holds** (`s2_s25.log`, 20/20):
- two `from_os` sites, in `prove_one` and `prove_forks_inner`;
- no `ZkRng::new` in the file;
- `ForkCtx` carries no generator.

**For the privacy review:** the W-8(5) wording "built in its worker" becomes "built by the thread that starts the
fork's proof, moved with the parked fork". One generator per fork, `L + 1` per run.

## 2. Measure first (stage 1) [MEASURED, `s1.progress`, `s1_d55.log`]

**The sealing pass** (`HL_D55_SEALED=1`, timeline on):
- **Time:** 4.30 s (in the N = 1 call) and 4.01 s (N = 6).
- **CPU:** 41.7 / 41.0 CPU-seconds, that is about **10 of 32 cores busy** on average. Of that, **26 s is system time**
  and 15 s user.
- **GPU:** busy only **10.3%** (the 224 witness-product command buffers, 1.8–2.0 ms each).

**The before-part per block** (the phase clock):

| phase | N = 1 (global pool, alone) | N = 6 (in the fork run) |
|---|---:|---:|
| A: witness planes into rows | 17.35 ms | 30.07 ms |
| A: lookup values + byte histogram | 12.45 | 32.61 |
| A: exp/act indices + two histograms | 1.89 | 2.94 |
| A: mask + proximity rows | 3.15 | 10.68 |
| A: commit (encode + Merkle) | 23.88 | 59.72 |
| M: mask commit | 4.72 | 3.82 |
| **before-part** | **63.4 ms (21.5% of 295 ms)** | **139.8 ms (21.5% of 649 ms)** |

At N = 6 that is 4.47 s summed over the forks, about 0.75 s of forks-phase wall [INFERRED]. The forks phase's GPU was
busy 67–73%.

## 3. Byte evidence [MEASURED, stage 2, all passed]

**The split core at the W16R2 rung golden** (`w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads`,
CPU in the suite; `…_on_the_device`, Metal):
- The generator is moved to another thread, which runs the before-part in a rayon pool of 1, 2 or 6 threads; the rest
  runs on the first thread.
- `96e4f0b6` every time (`s2_split_cpu.log`, `s2_split_metal.log`).
- A state made for another profile is refused.

**The fork path** (`run_fork_a13_tests.rs`, CPU in the suite, Metal ignored and run by name; `s2_bytes_cpu.log`,
`s2_bytes_metal.log`). A D55 receipt cannot be made twice: its generators are the OS's, and its endpoint owners are
consumed and have no `Clone`. So the tests use test-only seeded generators (`SeededForks`, whose maker is in the test
file):
- **Every fork, directly:** on one statement and one commit phase, each fork of an L = 4 W16R2 rung run proved whole
  equals the same fork parked (part pools 1, 2, 6; finished in reverse order on pools of 1, 3, 2), byte for byte:
  the fork frame, the end state and the joined claims.
- **The three real paths:** `prove_run_with_forks`, `prove_run_with_forks_sealing`, and `seal_ahead` on another
  thread then `prove_run_with_forks_ahead`, at:
  - windows 1, 2, 4, 9;
  - N = 1, 3 (CPU) and 1, 3, 6 (Metal);
  - side workers (1, global pool), (2, 3), (3, 6).

  In every case:
  - the receipt verifies;
  - its head is the replayed commit phase's;
  - the forks parked are the window's;
  - each interior fork equals that fork recomputed the other way;
  - every receipt is 61,301,184 B.

**The census and regression subset:** s25 20/20 (`s2_s25.log`), every non-ignored D55 test 25/25 (`s2_fork_tests.log`).

## 4. The A/B (stage 2, exploratory) [MEASURED, `s2_d55_ab.log`]

In-process, N = 6, 2 passes, arm order reversed in the second pass. Five arms:
- `noahead`;
- `ahead32`: window 32, 2 side workers of 6 threads;
- `ahead16`;
- `ahead32+aw1`: one side worker;
- `ahead32+aw3+ap4`: three side workers of 4 threads.

The proof-only call is a control (it has no sealing pass, so no part is made ahead). It moved −3.5% to +2.1%, so this
run's noise is about ±3%.

**One request, its own clocks** (`seal_pairs.py`, `s2_seal_pairs_*.md`; base first / test first / order bias solved
out):

| arm vs noahead | one request wall | sealing pass | sealing CPU-s | forks phase of the request | preflight + commit |
|---|---|---|---|---|---|
| ahead32 | +2.4 / −0.2 / **+1.1%** | +10.4 / +8.0 / **+9.2%** | **+30.1%** | −7.5 / −11.3 / **−9.4%** | **+17.2%** |
| ahead16 | +3.1 / +1.0 / **+2.0%** | **+7.9%** | **+14.7%** | **−5.8%** | **+12.6%** |
| ahead32+aw1 | +1.6 / −0.1 / **+0.7%** | **+10.0%** | **+30.4%** | **−10.4%** | **+13.7%** |
| ahead32+aw3+ap4 | +5.4 / −2.0 / **+1.7%** | **+11.4%** | **+25.1%** | **−10.5%** | **+19.5%** |

Means for ahead32 against noahead:
- sealing pass 4.244 → 4.632 s;
- forks phase 3.809 → 3.450 s;
- one request 8.423 → 8.514 s.

**The stream of 4** (`a11/pairs.py`, `s2_pairs_*.md`; base first / test first / solved):

| arm vs noahead | steady | amortized |
|---|---|---|
| ahead32 | −7.2 / −7.4 / **−7.3%** | **−5.5%** |
| ahead16 | −1.9 / −0.2 / **−1.0%** | **−0.5%** |
| ahead32+aw1 | **−5.5%** | **−4.0%** |
| ahead32+aw3+ap4 | **−8.4%** | **−5.4%** |

In the stream, a sealing pass with its parts took 5.9–6.1 s (`D55-AB A13 PIPE-SEAL` lines), against about 5.35 s per
request at the noahead steady state.

## 5. Memory [MEASURED, with a caveat]

- **The parked forks' own host state:** 28.64 GB for 32 (0.895 GB each: the witness, the lookup values, `A`'s host rows,
  pads and salts, `M`'s encoding), and 14.32 GB for 16.
- **Not counted:** `A`'s device copy (on Metal, its encoding and rows: about 1 GB more each [INFERRED from the layout:
  2,501 × (32,768 + 16,384) × 8 B]).
- **The process footprint** (`proc_pid_rusage` `ri_phys_footprint`, sampled every 10 ms):
  - peak 72–80 GiB with ahead32 and 70–71 GiB with ahead16;
  - 35–64 GiB with ahead off.
- **The caveat:** these are in one process with the Metal buffer pool on (up to 48 GiB kept), so they are not clean
  per-window numbers. The clean run, one process per window with `HL_METAL_POOL=0` (`s3.sh`), was not run after the
  coordinator's decision.
- **For the RTX 5090:** at about 2 GB per parked fork, a 32 GB card would bound the window at about 10 [ESTIMATE].

## 6. Stage 4: the mitigations and the sealing-pool probe

`s4.sh` (exploratory, 2 passes, both orders):
- **The new form:** queued parts, any part not started when the forks run handed back whole.
- **The side workers at macOS QoS:** `qos2` background (the efficiency cores) and `qos1` utility.
- **A separate, harness-only probe:** `sp16` / `sp8` run the sealing pass's witness builds in a rayon pool of 16 or 8
  threads instead of the 32-thread global pool. This is a candidate item of its own, not part of A13: 26 of the
  sealing pass's 42 CPU-seconds were system time (§2), as with the forks' shared pool before A11.
- The GPU timeline is on, to show whether parts delay the witness products.
- Results: `s4.progress`, `s4_d55_ab.log`, `s4_pairs_*.md`; the one-request clocks come from
  `python3 seal_pairs.py s4_d55_ab.log noahead <arm>`.

## 7. Recommendation

- **OFF.** Do not merge the ahead mode.
- **A9** (boundary commits in parallel) was not taken: it needs the boundary randomness pre-drawn through `pcs`, which
  is not cheap.
- **If the sealing-pool probe pays,** it is a separate byte-preserving item for the production sealing pass
  (`trained_block::seal_and_record`), not part of A13.

## 8. Files

- **Code** (second commit, as a record):
  - `ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs`: the split;
  - `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork.rs`: parked forks, slots, the entry points, the
    test-only seeded hook;
  - `run_fork_tests.rs`: the [A13] blocks (arm words `ahead<W>`, `noahead`, `aw<k>`, `ap<t>`, `qos<q>`, `sp<t>`;
    the footprint sampler; the per-call A13 lines). The stream's statement is now made on the sealing thread in both
    arms.
  - `w16r2_tests.rs`: the split-core golden;
  - `run_fork_a13_tests.rs`: new;
  - `s25_tests.rs`: `TEST_ONLY_FILES` gains `run_fork_a13_tests.rs`.
- **For the privacy gate:** `protocol.rs` and `run_fork.rs` changed digest on that branch only. Nothing is merged.
  `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
- **This directory:**
  - stage scripts `s1.sh`, `s2.sh`, `s3.sh` (not run), `s4.sh`, `s6.sh` (not run), with `run_stage.py`, `watch.py`;
  - `seal_pairs.py`;
  - stage logs, progress files and guard records.
