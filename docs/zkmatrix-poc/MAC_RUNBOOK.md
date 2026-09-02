# MAC RUNBOOK — the ordered queue for the Mac (M3 Ultra, 256 GB)

Status: LIVE (written 2026-09-02, orchestrator/Claude, round 10).
Who runs it: Victor (or Grok/Cursor) on the Mac. The WSL laptop
cannot run any 8B shape (15 GB); every run below either needs the
Mac's memory or gives the Mac's own CPU number for the record.
New to the project? Read `START_HERE.md` §1-3 first (ten minutes).

**What this queue produces, in plain words.** M1 gives the Mac's own
time for the reference proof (the 125M rig) and how it scales with
threads. M2-M3 finish the second real checkpoint's qualification.
M4 produces the first proof of an 8B-width layer ever run. M5 is the
first evidence that covers every layer of an 8B model, and its
T-scaling leg measures how much of a proof is weights (fixed per
model) versus activations (per token) — the number the new 50
tokens/s target is stated in. M6 is the working proof-of-concept
run: the whole 32-layer feed-forward stack in one proof.

## 0. Conventions (read once)

- All commands are typed from the repository root on the Mac.
- The Mac has no CUDA. Everything here is CPU. `ZK_THREADS=n` sets
  the thread count; the proof bytes are identical for any n, so a
  thread ladder is a pure timing experiment.
- **Timing label.** Before any timed run, check whether the frugal-lm
  training job (F2) is running: `top -l 1 | head -15`. If it is, the
  run is `NOISY-SHARED`; if not, `QUIET`. Write the label next to
  every wall time you paste. M1 and M5's ladder are only worth
  running QUIET.
- **Wall + memory capture.** Prefix long commands with
  `/usr/bin/time -l` (macOS). At the end it prints `real` seconds and
  `maximum resident set size` in BYTES (divide by 1,073,741,824 for
  GiB). Paste both.
- **Logs.** `mkdir -p results/uperf` once. Send every run's output
  to `results/uperf/mac_<task>_<YYYYMMDD>.log` with `> file 2>&1`.
  The `.log` files are not committed (large); the numbers are.
- **One heavy job at a time.** macOS has no `flock`; just do not
  start the next heavy run until the previous one has exited.
- **Long runs survive a closed terminal** if you start them as
  `nohup <command> > <log> 2>&1 &` (or inside `tmux`/`screen`).
  Check progress with `tail -3 <log>`.
- **STOP rule.** Any `accept = false`, any digest mismatch, any
  panic: stop that task, paste the last 30 lines of the log into
  §R below, commit, push. A mismatch is a finding, not a failure.
- **How to report.** Append your numbers to §R (RESULTS, append-only,
  newest last) in this file, then:
  `git add docs/zkmatrix-poc/MAC_RUNBOOK.md results/*.json results/*/digests.txt results/*/manifest.json`
  `git commit -m "MAC: <task> done — <one line of numbers>"`
  `git push`

## M0. Sync, build, gate pass (~30-40 min, mostly the test suite)

```
git pull
cargo build --release --manifest-path zkmatrix-rs/Cargo.toml
zkmatrix-rs/target/release/ring_matmul freeze-check; echo "freeze-check exit=$?"
zkmatrix-rs/target/release/ring_matmul uperf-pc diff-battery
python3 -m unittest discover -s tests
```

ACCEPT: build green; freeze-check prints `ok` rows and exits 0
(102 ok rows expected); diff-battery ends green; the suite reports
81 tests with 0 failures (2 skips are normal). Anything else: STOP
and paste.
RECORD (§R): the freeze-check exit code and row count, the suite
line, the commit hash `git rev-parse --short HEAD`.

## M1. The reference rig on the Mac: 12x512 walls + a thread ladder (T1)

WHY: the Mac's own number for the reference proof has never been
taken since the kernel campaign; every Mac estimate in the ledgers is
arithmetic. The ladder shows how the CPU path scales with threads.

```
mkdir -p results/uperf
sysctl -n hw.ncpu          # note N = the core count
```

1. The fast yardstick, oracle and fast (each ~5-10 min; the two
   EVAL-PROOF DIGEST lines MUST be identical — if not, STOP):
```
ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/mac_fp_3x16_oracle.log 2>&1
/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/mac_fp_3x16_fast.log 2>&1
grep -h 'EVAL-PROOF DIGEST\|accept' results/uperf/mac_fp_3x16_*.log
```
2. The real thing, QUIET, one run per thread count (the 1T run is
   the ledger's convention and may take ~10-15 min; the others are
   shorter; peak RSS ~7-11 GB):
```
ZK_THREADS=1  /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/mac_fp_12x512_1t.log 2>&1
ZK_THREADS=8  /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/mac_fp_12x512_8t.log 2>&1
ZK_THREADS=16 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/mac_fp_12x512_16t.log 2>&1
ZK_THREADS=N  /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/mac_fp_12x512_Nt.log 2>&1
grep -h 'EVAL-PROOF DIGEST\|accept\|commit\|prove\|verify\|real\|maximum resident' results/uperf/mac_fp_12x512_*.log
```
ACCEPT: `accept = true` in every log; the EVAL-PROOF DIGEST identical
across all four; the statement digest line starts with
`76dbf2040409333e`.
RECORD (§R): per thread count: commit / prove / verify seconds, the
`real` wall, peak RSS in GiB, the label (QUIET/NOISY-SHARED).

## M2. Download Gemma-4-12B (T13; ~23 GB; no RAM; F2 may run)

```
python3 -c "import os; from huggingface_hub import snapshot_download; snapshot_download('google/gemma-4-12B-it-qat-q4_0-unquantized', local_dir=os.path.expanduser('~/models/gemma-4-12B-qat'), allow_patterns=['*.safetensors','*.json','tokenizer.model'])"
ls ~/models/gemma-4-12B-qat/
du -sh ~/models/gemma-4-12B-qat/
```
(If `huggingface_hub` is missing: `pip install huggingface_hub`.)
ACCEPT: `config.json`, `model.safetensors`, `tokenizer.json` present;
~23 GB. No login should be needed (verified on WSL 2026-08-25); a 403
is a finding — paste it.
RECORD: one line.

## M3. The Gemma qualification gate on the Mac (T14; ~15-40 min; RSS < 6 GB)

PREREQ: M2, and the FineWeb-Edu text sample at
`~/models/fineweb-edu/sample_text.txt` (produced by the Mistral
download step in `U_PERF3_MVP8B_SCALING.md` §5.2 step 2; if it is
absent on the Mac, run that one step first — same sampler data as
the WSL runs is REQUIRED so the verdicts compare).

```
python3 scripts/m8b_gemma4_walker.py --decode "The chemical symbol for gold is" --template
python3 scripts/m8b_gemma4_walker.py --probe --template
python3 scripts/m8b_gemma4_walker.py --text ~/models/fineweb-edu/sample_text.txt --out-json results/m8b_gemma4_calibration_mac.json
```
NOTE: `--template` is REQUIRED for this instruction-tuned checkpoint;
without it the plain decode produces degenerate output by design.
ACCEPT: step 1 completes with " Au"; step 2 puts at least 3 of 5
prompts in the top-2 ranks (WSL scored 5/5 at rank 0); step 3 exits
0 and prints a VERDICT block whose violation counts, exponent tables
and member digests MATCH the committed
`results/m8b_gemma4_calibration.json` (116,852 violations, +17.60
nats — that FAIL is the expected, already-recorded verdict; your run
is the cross-check). A mismatch: paste both.
RECORD: the VERDICT block; commit the JSON.

## M4. The Mistral v3 export on the Mac + verify + THE FIRST 8B-WIDTH LAYER PROOF (T15)

WHY: the 8B witness files (.bin) are laptop-local and too large to
ship; the Mac re-exports from its own copy of the checkpoint and
must reproduce the committed digests. Then it runs the proof rung
that the laptop cannot (out of memory at 15 GB).

PREREQ: Mistral-7B-v0.1 at `~/models/mistral-7b-v0.1` (if absent:
`python3 -c "import os; from huggingface_hub import snapshot_download; snapshot_download('mistralai/Mistral-7B-v0.1', local_dir=os.path.expanduser('~/models/mistral-7b-v0.1'), allow_patterns=['*.safetensors','*.json','tokenizer.model'])"`,
~17 GB); the FineWeb sample from M3's PREREQ; the committed
calibration `results/m8b_int8_calibration.json` (the script's
default; if the Mac lacks it, `git pull` brought it).

1. Export (~10-25 min, RSS ~3 GB, F2 may run):
```
/usr/bin/time -l python3 scripts/m8b_export_ffn.py --ckpt ~/models/mistral-7b-v0.1 --profile v3 --margins results/m8b_margins_mistral_wsl.json --text ~/models/fineweb-edu/sample_text.txt --out results/m8b_mistral_v3_export_mac > results/uperf/mac_export_mistral.log 2>&1
tail -5 results/uperf/mac_export_mistral.log
diff results/m8b_mistral_v3_export_mac/digests.txt results/m8b_mistral_v3_export/digests.txt && echo DIGESTS IDENTICAL
```
   ACCEPT: the log ends with `range-fact violations across the export
   pass: 0`; the diff is empty. If ONLY the `X`/`a16`/`u16`/`h16`/`z16`
   lines differ while every `WgT`/`WuT`/`WdT` line is identical, that
   is the known Mac-vs-x86 float-rounding effect seen at 125M: the
   export is still a valid witness — paste which lines differ and
   continue. If any WEIGHT digest differs: STOP and paste.
2. The engine's cross-check of the export (~minutes):
```
ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac zkmatrix-rs/target/release/ring_matmul uperf-v3 verify-export
```
   ACCEPT: `PASSED`, 128/192 plane legs (the 64 absent legs are the
   T=512-only planes; that count is expected).
3. THE PROOF RUNG — one 8B-width layer, 16 tokens (RSS > 15 GB;
   minutes-class [MODEL], never measured):
```
ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=8 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 0 16 1 > results/uperf/mac_e2e_l0_t16.log 2>&1
grep -h 'accept\|commit\|prove\|verify\|bytes\|real\|maximum resident' results/uperf/mac_e2e_l0_t16.log
```
   ACCEPT: `accept = true`.
RECORD (§R): the diff verdict; verify-export's PASSED line; the proof
rung's commit/prove/verify seconds, wall, peak RSS, label; the
statement-bytes line. Commit `results/m8b_mistral_v3_export_mac/digests.txt`
and `manifest.json` (the .bin files stay on the Mac).

## M5. The per-layer 8B ladder + the T-scaling leg (T16, extended)

WHY: (a) coverage — every one of the 32 layers proven against the
32-layer stack is the first full-model-coverage evidence at 8B; (b)
THE T-SCALING LEG is new and is the measurement the throughput
model needs: a proof's cost splits into a weight part (the same for
every proof of this model) and an activation part (grows with the
token count T). Proving the same layer at T = 16, 64 and 512 and
plotting wall against T gives that split directly.

1. The T-scaling leg first (layer 0; three runs; the T=512 run is
   the longest — hours-class is possible [MODEL]; RSS grows with T
   but stays far under 256 GB):
```
for T in 16 64 512; do ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=8 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 0 $T 32 > results/uperf/mac_e2e_l0_t${T}_of32.log 2>&1; done
grep -H 'accept\|prove\|verify\|real\|maximum resident' results/uperf/mac_e2e_l0_t*_of32.log
```
   ACCEPT: three `accept = true`.
   RECORD: per T: commit / prove / verify seconds, wall, peak RSS.
   (Lane TT reads these three rows; label them QUIET/NOISY.)
2. The coverage ladder, all 32 layers at T=16 (run overnight;
   ~30-60 s per layer at 8 threads [MODEL], total under an hour if
   the model holds; STOP at the first reject):
```
for L in $(seq 0 31); do ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=8 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 $L 16 32 > results/uperf/mac_e2e_l${L}_t16_of32.log 2>&1 || break; done
grep -H 'accept' results/uperf/mac_e2e_l*_t16_of32.log | grep -c 'accept = true'
```
   ACCEPT: 32 of 32 `accept = true`.
   RECORD: the count, the min/median/max per-layer wall, peak RSS,
   and the statement-bytes line from one log.

## M6. The working PoC: the composed 32-layer statement, both forms (T17)

WHY: per-layer proofs are not a model proof; the composed statement
binds every layer-to-layer seam in one transcript. Victor ruled
(2026-08-31) that BOTH forms run: the declarational composed
statement over the real export, and the calibrated-tower composed
proof. Each object's meaning is stated plainly in the write-up (the
composed object is honestly an "FFN tower" until attention lands).
Hours-class at T=16 on CPU [MODEL]; expect 40+ GB RSS [MODEL].

```
ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=16 nohup /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 composed 16 32 > results/uperf/mac_composed_16x32.log 2>&1 &
```
then, after it finishes (`tail -3` shows `accept`):
```
ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=16 nohup /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 composed-chain 16 32 > results/uperf/mac_composed_chain_16x32.log 2>&1 &
```
Optional, if time permits (the 32-independent-proof differential):
`... uperf-v3 composed 16 32 diff > results/uperf/mac_composed_16x32_diff.log 2>&1`.
ACCEPT: `accept = true` in each; the seam count line printed by the
run (the real-Mistral smoke found 39 legal seam clamps, 0
violations on the laptop at small T).
RECORD (§R): each form's commit / prove / verify seconds, wall, peak
RSS, statement bytes, the seam line, the label.

## M7 (optional, for the throughput model). The 8B thread ladder

Only if M4 step 3 was quick (under ~10 min at 8 threads):
```
for n in 1 8 16 N; do ZK_MODEL_EXPORT_DIR=results/m8b_mistral_v3_export_mac ZK_THREADS=$n /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 0 16 32 > results/uperf/mac_e2e_l0_t16_${n}t.log 2>&1; done
```
(replace N with `sysctl -n hw.ncpu`). RECORD: wall per n.

## R. RESULTS (append-only, newest last; paste here, commit, push)

Format per entry:
```
<date> <task> [MAC-BOX <n>T QUIET|NOISY-SHARED] commit <hash>
  command: <the command as run>
  verdict: accept=<true|false>; digests <identical|DIFFER: lines>
  numbers: commit <s> / prove <s> / verify <s> / wall <s> / peak RSS <GiB> / bytes <n>
  notes: <anything odd>
```

(none yet)
