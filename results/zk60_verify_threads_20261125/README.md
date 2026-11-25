# Is the "one thread" verifier time of the 8B test a one-thread time? (2026-11-25, Claude co-coordinator)

**No.** The line `serial: verified (D12a verifier, one thread) in X s` of test
`d55_ab_one_request_serial_against_forks` times the serial verifier (one block after another) with its inner loops on
the process's whole thread pool. With the pool limited to one thread the same line reads 2.3 to 2.7 times longer.

Definition and reading rule: `ops/zkp-mvp/RECOVERY_COORDINATION.md`, entry of 2026-11-25T16:09:40Z, pushed
(`456387539`) before the set ran. Reading as applied: `READING_set1.txt` (output of `read_vt.py set1`).

## What was run

- Lib test binary built from head `4f028964e` (`binary.sha256`), profile W16R2_8B_T128_H24, 32 blocks, diagonal
  test weights, one request, receipt 818,728,480 B in every process.
- One process per arm, each its own guarded job, order p, d, t1, t1d, t1d, t1, d, p (`run_vt.py`):
  `p` nothing set; `d` `HL_A26_PCS_SPARSE=0`; `t1` `RAYON_NUM_THREADS=1`; `t1d` both.
- All eight processes passed. No other guarded job ran inside the window (16:10:09Z to 16:19:29Z). One unguarded
  Lean compile of another lane was running when the set began (`raw/set1.status_pre.txt`).

## Measured [MEASURED, set1, seconds printed by the test for one 32-block receipt]

| arm | pool | column loop | serial verifier line | six-worker verifier line |
|---|---|---|---|---|
| p | default (32 logical CPUs) | sparse (default) | 3.77, 3.34 | 1.39, 1.71 |
| d | default | dense | 5.40, 5.27 | 1.29, 1.25 |
| t1 | one thread | sparse (default) | 9.04, 8.59 | 7.87, 7.42 |
| t1d | one thread | dense | 12.78, 13.00 | 10.73, 11.89 |

## Reading 1 (the basis)

R = mean(t1) / mean(p) = 2.48. The two `p` processes differ by 12.1 percent of their mean, so by the repeat rule the
figure read is the least favourable pair, 8.59 / 3.77 = **2.28**, at or above the bar of 1.5: **the serial line is not
a one-thread time.** One thread's work for a block of this receipt is 8.815 s / 32 = **275.5 ms** (268.4 to 282.5) with
the sparse column loop, and 402.8 ms (399.4 to 406.2) with the dense one.

Withdrawn by the rule: the split of "141.9 ms a block" (the Nov 5 record, 4.54 s / 32) into transforms, column
products and other work in research ticks 58 and 60, and the checking-time ranges for the size step built on it
(x1.6 to x3.1 in tick 58 and my triage of it, x1.15 to x3.1 in tick 60, x1.4 to x3.1 in my triage of tick 60).
Tick 58's statement that the size-step study's "0.433 CPU-seconds a block" was 3.05 times too high is withdrawn
with them: one thread's work measured here is 0.28 s a block with the sparse loop and 0.40 s with the dense loop
that the Nov 5 code had. No replacement range is given; this set has no phase marks.

## Reading 2 (the sparse column loop)

One-thread saving: mean(t1d) - mean(t1) = **4.08 s a request, 127 ms a block** (pairs 3.74 to 4.41 s). Tick 60
bounded it at no more than 32 to 49 ms a block; the measured saving is 2.6 to 4.0 times that bound. On the default
pool the serial line gains 1.78 s a request (pairs 1.50 to 2.06 s).

## Reported without a rule

- The six-worker verifier line is 1.25 to 1.71 s on the default pool and 7.42 to 11.89 s with a one-thread global
  pool, so the "6 threads" of that line are not its only threads either.
- On the default pool the six-worker line does not show the sparse loop's gain (1.39 and 1.71 s sparse against 1.29
  and 1.25 s dense). Two processes an arm with one pair 21 percent apart: not read as a loss.

## Not claimed

- Nothing about today against Nov 5: a different binary and day, no control.
- Nothing about trained weights. These are diagonal test weights, where the public weight folds are nearly free.
- Nothing about where the 275 ms go. That needs phase marks on a one-thread pool (new test code).
- Nothing about the prover: a one-thread pool slows it too, and its times in these logs are not read.

## Files

`run_vt.py` (runner), `read_vt.py` (the reading), `READING_set1.txt`, `binary.sha256`, `raw/` (per process: log,
guard record, done marker; per label: results, machine state before the run, runner output; `smoke*` is the
two-block harness check made before the definition was posted).
