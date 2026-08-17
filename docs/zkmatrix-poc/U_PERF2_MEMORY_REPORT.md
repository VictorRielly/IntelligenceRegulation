# U-PERF2 lane F — MEMORY DIET: the composed pass's resident set (w0 as i8, phi never materialized at level 0, CRS Arcs) — toward the 12x512 rig on the 15 GB box

Status: IN PROGRESS (skeleton, 2026-08-17). Written by lane F of the
U-PERF2 round 4 (ledger: PROGRESS_UPERF2.md "Lane F — MEMORY DIET" +
"Agent F status"). Worktree /home/victor/wt-uperf2-f, branch uperf2-f,
opened at f512ba1 (= the A/C/D/E merge 4dcaea6 + the round-4 ledger).
Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB; the local
m125 re-export IS here: `M125_EXPORT_DIR=results/m125_ffn_export_wsl`).
Every number carries `[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`; lane G
builds and runs in its own worktree during the session, and the two
lanes share the heavy runs through `flock /tmp/zk-heavy.lock` (the
12x64 rig needs ~12 GB: only under the flock and only with >= 13 GB
free). RSS rows are `VmHWM` (peak so far) and `VmRSS` (current) from
/proc/self/status at the phase boundaries, printed by the observation-
only `[UPERF2-F] RSS` rows when the prof timers are on; the process
peak is `/usr/bin/time`'s maxrss.

The rule (unchanged): every change is DIFFERENTIAL — the rig's
statement digest, counted bytes, verdict AND EVAL-PROOF DIGEST are
identical at ZK_THREADS 1 and 8, fast and oracle; the batteries hold at
ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture. The w0 type change is STRUCTURAL (no oracle exists
for a storage type) — its gate is the rig digests + the E2E leg + the
lane's own three-way battery; the phi routing keeps the materialized
path under `oracle_mode()`.

## 0. One paragraph

(to be written at close)

## 1. Items and where they land

| item | function | oracle / gate | call sites | status |
|---|---|---|---|---|
| RSS attribution rows | bin `uf_rss` (`[UPERF2-F] RSS`), hooks in bk_pass_run / bg_prove_group | observation only | the `uperf-pc *-profile` arms | LANDED (skeleton) |
| w0 as flat i8 (`DigitCols`) + `SmallRings` kernels | eval_proof.rs `DigitCols`, `SmallRings`, `*_gen` kernel bodies; bin `agg_digit_witness_cols`, bg_witness / bk_witness_*, bg_precommit / bg_prove_group / bg_matvec_chunks / bg_level_h / bg_fold | structural: rig digests + E2E + `uperf-f diff-battery` | the composed pass (BG and BK) | planned |
| phi never materialized at level 0 (`Phi0Source`, `level_h_pairs_with`, psi0 transport) | eval_proof.rs; bin bg_prove_group | `oracle_mode()` keeps the materialized path | bg_prove_group | planned |
| CRS memo Arcs (+ `ZK_CRS_MEMO=0`) | eval_proof.rs `expand_level_matrix_arc`; bin bg_* callers | values identical (same expansion) | bg_precommit / bg_prove_group / bg_verify_group | planned |

Harness: `ring_matmul uperf-f diff-battery | rss` (bin section `// [UPERF2-F]`).

## 2. Memory model (before) and the attribution — 3x16 (1T) and 12x64 (8T)

(baseline rows go here — the RSS table per phase boundary)

## 3. Method notes

(per item: the exact identities and why the bytes cannot move)

## 4. Differential evidence + gates

(battery legs, rig runs, freeze rows)

## 5. Before / after — RSS and timing rows

(3x16 1T/8T, 12x64 8T; 12x128 / 12x256 if they fit)

## 6. What is left for 12x512 on 15 GB

(the remaining terms with sizes)
