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

## M1b. The reference shape in FULL proof mode (new 2026-09-02; the laptop cannot hold it)

WHY (updated 2026-09-02 late): the laptop now runs BOTH Stage-A
modes at 12 x 512 after lane WW's memory diet (7.2 GB each; the
earlier 15 GB kills were a pre-diet layout). This item is therefore
no longer a blocker — it is the Mac's own CPU number for the two
Stage-A modes at the reference shape (useful for the thread ladder
and the 8B extrapolation), lower priority than M4-M6. Skip it if
time is short.

```
ZK_THREADS=8 M125_EXPORT_DIR=results/m125_ffn_export /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-a pass 12 512 full > results/uperf/mac_stagea_12x512_full.log 2>&1
ZK_THREADS=8 M125_EXPORT_DIR=results/m125_ffn_export /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-a pass 12 512 range nooracle > results/uperf/mac_stagea_12x512_range.log 2>&1
grep -h 'RSS high-water\|accept\|TRANSCRIPT DIGEST\|commit\|prove\|verify\|real\|maximum resident' results/uperf/mac_stagea_12x512_*.log
```
(`results/m125_ffn_export` is the Mac's own frozen 125M export, which
exists there; ~5-15 min each [MODEL]; expect the full run's peak well
above 15 GB.)
ACCEPT: `accept true` in both.
RECORD (§R): for each mode: the three `RSS high-water` lines, peak
RSS in GiB, commit / prove / verify seconds, bytes, the label.

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
calibration `results/m8b_int8_calibration_wsl.json` (passed
explicitly below — the script's default name is NOT the committed
file).

1. Export (~10-25 min, RSS ~3 GB, F2 may run):
```
/usr/bin/time -l python3 scripts/m8b_export_ffn.py --ckpt ~/models/mistral-7b-v0.1 --cal-json results/m8b_int8_calibration_wsl.json --profile v3 --margins results/m8b_margins_mistral_wsl.json --text ~/models/fineweb-edu/sample_text.txt --out results/m8b_mistral_v3_export_mac > results/uperf/mac_export_mistral.log 2>&1
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

## M9. THE FIRST 8B PROOF ON THE HASH LINE (hashline `--profile v3`; new 2026-09-02, lane ZB)

WHY: the hash line (`hashline/`, the Ligero + sumcheck prover; ~100-
bit hash-only soundness, no lattice) proves the SAME widened-stack v3
statement as `ring_matmul uperf-v3` — the int16-out activation table,
the int16 classes, round-to-nearest requant, the exact up-scaling
branch — and on the laptop it is 6-7x the lattice line per proven MAC.
Lane ZB proved ONE Mistral-7B layer with it on the laptop (T=16: 10.5
s, 7.5 GB; T=256: 14.5 s, 10.3 GB, all 8 threads) and measured the
T-split: a 7B layer at T=512 needs ~13.3 GB, which the laptop cannot
hold safely, and the 32-layer pass holds ~14 GB with one witness
resident at a time. The Mac runs what the laptop cannot: every layer
of the 8B model, layer 0 at the full T=512, and THE FIRST FULL 32x512
8B PASS in one transcript. All CPU, no CUDA (the crate's GPU feature is
off by default and never built here). The proof bytes are
deterministic (blake3 Fiat-Shamir): the Mac's proof of a given
statement at given parameters equals the laptop's byte for byte, which
the optional 125M leg checks against a committed digest.

PREREQ: M4 step 1 done (`results/m8b_mistral_v3_export_mac/` with its
256 .bin files; if the Mac's export differs from the committed digests
only in the X/a16/u16/h16/z16 lines — the known float-rounding effect —
it is still a valid witness: the reader below checks the export
against ITS OWN sidecar). The Rust toolchain from M0. `mkdir -p
results/uperf`. Every number: label QUIET / NOISY-SHARED per §0.
N below = `sysctl -n hw.ncpu` (the cores are uniform; use them all).

0. Build + tests (~1-2 min cold [MODEL]; no CUDA):
```
cargo build --release --manifest-path hashline/Cargo.toml
cargo test --release --manifest-path hashline/Cargo.toml 2>&1 | grep 'test result'
hashline/target/release/hashline tables-v3 | tail -2
```
   ACCEPT: build green; the first `test result` line says `22 passed;
   0 failed`; `tables-v3` prints 15 member lines ending with a digest
   and no panic (the 15 frozen int16-out members regenerated and
   digest-pinned; the last line is `gelu-tanh-int16out-table-v3 (eGate
   -1, eOut -9): ... digest 046effd433a6ca20..`).
1. The reader + the exact chain against the Mac's export (~3 min at
   N threads [MODEL: 9 s + 128 s at 8T on the laptop]; RSS < 1 GB):
```
/usr/bin/time -l hashline/target/release/hashline check-export --profile v3 --export results/m8b_mistral_v3_export_mac > results/uperf/mac_hl_checkexport.log 2>&1
/usr/bin/time -l hashline/target/release/hashline chain --profile v3 --export results/m8b_mistral_v3_export_mac --threads N > results/uperf/mac_hl_chain.log 2>&1
grep -h 'check-export v3\|chain v3:\|real\|maximum resident' results/uperf/mac_hl_checkexport.log results/uperf/mac_hl_chain.log
```
   ACCEPT: `check-export v3: 256/256 tensor digests reproduce` and
   `chain v3: 32/32 layers reproduce the export's a16/u16/h16/z16`
   (every per-layer line says `range facts HOLD`). Anything else:
   STOP and paste (a mismatch here means the Mac's export and the
   Rust chain disagree on the statement — a finding, not a failure).
2. THE FIRST 8B-WIDTH LAYER ON THE MAC, T=16 (~10 s at 8T on the
   laptop; RSS 7.5 GB [MEASURED there]; the eight tamper legs re-prove
   the layer eight more times, ~1.5 min total [MODEL]):
```
/usr/bin/time -l hashline/target/release/hashline layer 0 16 --profile v3 --export results/m8b_mistral_v3_export_mac --threads N --all-tampers > results/uperf/mac_hl_l0_t16.log 2>&1
grep -h 'statement\|tamper\|GREEN\|RED\|real\|maximum resident' results/uperf/mac_hl_l0_t16.log
```
   ACCEPT: `tamper None: ACCEPT ...`, eight `REJECT` lines, `layer 0
   (v3): GREEN`. RECORD: the prove / verify seconds and proof bytes of
   the ACCEPT line, `real`, peak RSS, the label.
3. Every layer of the 8B model at T=16 (32 runs; ~6 min at 8T
   [MODEL], less at N; STOP at the first RED):
```
for L in $(seq 0 31); do hashline/target/release/hashline layer $L 16 --profile v3 --export results/m8b_mistral_v3_export_mac --threads N > results/uperf/mac_hl_l${L}_t16.log 2>&1 || break; done
grep -h 'GREEN\|RED' results/uperf/mac_hl_l*_t16.log | sort | uniq -c
grep -h 'tamper None' results/uperf/mac_hl_l*_t16.log | awk '{print $5}' | sort -n | sed -n '1p;16p;32p'
```
   ACCEPT: `32 layer (v3): GREEN` (the uniq -c line), no RED. RECORD:
   the count; the min / median / max per-layer prove seconds (the
   second grep prints them); the label.
4. Layer 0 at the FULL T=512 (the row the laptop cannot take: ~18-20
   s at 8T and ~13.3 GB [MODEL from the laptop's T=16/128/256 rows:
   ~9 s + ~7.0 GB of weight work per layer, plus ~13.5 ms + 11.7 MB per
   token row]):
```
/usr/bin/time -l hashline/target/release/hashline layer 0 512 --profile v3 --export results/m8b_mistral_v3_export_mac --threads N > results/uperf/mac_hl_l0_t512.log 2>&1
grep -h 'commit W\|commit A\|helpers\|zero-check\|openings\|tamper None\|GREEN\|RED\|real\|maximum resident' results/uperf/mac_hl_l0_t512.log
```
   ACCEPT: `ACCEPT` + `GREEN`. RECORD: prove / verify / proof bytes,
   the eight phase lines (commit W is the weight part; commit A +
   helpers + the zero-checks are the activation part), `real`, peak
   RSS in GiB, the label. With the T=16 row this gives the Mac's own
   weight/activation split.
5. THE FIRST FULL 8B PASS: 32 layers x 512 tokens, one transcript
   (~10 min at 8T [MODEL: 32 x ~18 s]; peak RSS ~14 GB [MODEL] — one
   witness resident at a time, the 32 layer proofs held in memory,
   ~1.2 GB; the proof file ~1.2 GB, NOT committed; run it detached):
```
nohup /usr/bin/time -l hashline/target/release/hashline pass 32 512 --profile v3 --export results/m8b_mistral_v3_export_mac --threads N --proof-out results/uperf/mac_hl_v3_32x512.bin > results/uperf/mac_hl_pass_32x512.log 2>&1 &
```
   then, when `tail -3 results/uperf/mac_hl_pass_32x512.log` shows
   the `PASS-V3` line:
```
grep -h 'PASS-V3\|PROOF sha256\|real\|maximum resident' results/uperf/mac_hl_pass_32x512.log
grep -h '^      ' results/uperf/mac_hl_pass_32x512.log
```
   ACCEPT: `PASS-V3 ACCEPT: 32 x 512 (d 4096 f 14336): ...`. RECORD
   (§R): the whole PASS-V3 line (witness load, PROVE, VERIFY, proof
   bytes, MACs, proven MAC/s, wall), the `PROOF sha256` line (the
   Mac's digest of the first 8B pass proof — the laptop has none to
   compare with; it becomes the reference), the eight summed phase
   lines, `real`, peak RSS in GiB, the label. A `REJECT` or an exit
   137: STOP, paste the last 30 lines.
6. Optional legs (each a few minutes):
   (a) the byte-identity gate on Apple silicon — copy the laptop's
   125M v3 export (140 MB; the .bin files live on the laptop under
   `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export/`, the
   digests are committed at `results/m8b_test/m125_v3_export/`) to
   the committed path on the Mac, then
   `hashline/target/release/hashline pass 12 512 --profile v3 --export results/m8b_test/m125_v3_export --threads 8 --proof-out results/uperf/mac_hl_v3_12x512.bin`
   — ACCEPT: `PROOF sha256 5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d (70758084 B)`,
   the laptop's CPU AND GPU digest; RECORD the PROVE / VERIFY seconds
   at 8 threads (the Mac's own 125M v3 row next to the laptop's 17.4 s
   / 2.74 s) and at N threads;
   (b) the v2 gate the same way with the laptop's
   `results/m125_ffn_export_wsl/` copied over:
   `M125_EXPORT_DIR=results/m125_ffn_export_wsl hashline/target/release/hashline pass 12 512 --threads 8 --proof-out results/uperf/mac_hl_v2_12x512.bin`
   — ACCEPT: `PROOF sha256 50cf7bdfd6b5b182..` (66,844,928 B);
   (c) the proof-size parameter at 7B: step 4 again with
   `--log-cols 16` — the W matrix drops from 10,752 to 2,688 rows and
   the proof roughly halves (25.9 -> 13.4 MB at T=16 on the laptop)
   at the same wall; RECORD the bytes and prove seconds (its digest is
   a different parameter set, not comparable to (a)).
RECORD (§R), the paste-back template:
```
<date> M9 [MAC-BOX <N>T QUIET|NOISY-SHARED] commit <hash>
  step 1: check-export <n>/256; chain <n>/32 (<s> s)
  step 2: layer 0 T=16: ACCEPT prove <s> / verify <s> / <bytes> B / real <s> / RSS <GiB>; tampers <n>/8 REJECT
  step 3: 32 layers T=16: <n>/32 GREEN; prove min/med/max <s>/<s>/<s>
  step 4: layer 0 T=512: ACCEPT prove <s> (commit W <s>, A <s>, helpers <s>, zcF <s>, zcD <s>, open <s>) / verify <s> / <bytes> B / real <s> / RSS <GiB>
  step 5: pass 32x512: PASS-V3 <ACCEPT|REJECT> PROVE <s> VERIFY <s> proof <bytes> B <MAC/s> proven MAC/s wall <s> / real <s> / RSS <GiB>; PROOF sha256 <digest>
  step 6: (a) 12x512 v3 sha256 <digest> [= 5f368db6.. ?] PROVE <s>@8T <s>@NT; (b) v2 sha256 <digest> [= 50cf7bdf.. ?]; (c) log-cols 16: <bytes> B, prove <s>
  notes: <anything odd>
```
Commit only the .md (the .log and .bin files stay on the Mac).

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
