# A5 review: `zk60_classify prove-batch` (one model load for a whole post)

Reviewer: Claude, independent, read-only. Written 2026-10-29 22:16 UTC (read from `date -u`).
Candidate: `results/zk60_astra_20261026/a5_batch_candidate/` (`native.patch` against
`frozen-r16b/hashline`). All five staged files and all three baseline files re-hashed and equal to
`native_sources.json` [MEASURED]. The patch equals a fresh `diff -u` of the staged files against r16b [MEASURED].
No build, no test run, no proof. One light Python check (section 3, item 7).

## Verdict: READY WITH FIXES

In plain words: the design is sound by reading. Every proof still draws its own fresh operating-system
randomness. Nothing shared between proofs can be changed by a proof. Every block reload is still
digest-checked. The single `prove` path is unchanged except for one redundant check. The app-side event
router never reports more than "unverified".

Two things must be fixed in the adoption round before the batch proves any real post:
a failed batch leaves earlier receipts that look finished (finding 1), and the two new production files
sit outside the randomness census (finding 2). There are no blocking findings.

The byte-identity rule cannot be checked as the code stands: randomness is OS-seeded and there is no seed
flag. Section 4 gives a way to check it with no source change, on the real release binaries.

## 1. Findings

### 1. [fix-before-adoption] A failed batch leaves earlier receipts that look finished

Where: `classify_batch.rs:127-133` (the job loop); `classify_cli.rs:629` (`claimed.keep()` at the end of
each job). Staged files.

What happens: each job keeps its directories as soon as it finishes. Suppose job k fails, or the guard
kills the batch, or it runs out of memory. Then jobs 0 to k-1 stay on disk with:
- `<out>/` and all 28 segments;
- `<out>.unverified-statement/statement.json`;
- the owner's `input.dec`.

That is exactly what a finished single prove leaves. A fresh `verify` accepts it. If all of a category's
chunks finished before the failure, `label` can pass for that category. Today the batch prints `refused`
and the fail-closed line, and `batch_request.py` refuses the stream, so the app would not count these runs.
But the files still break the acceptance rule: no receipt that looks complete after a failure.

Fix:
- (a) Native. When `shared` is `Some`, `prove_with_public` returns the three paths it claimed (`out`,
  `unverified`, `owners_dir`). The batch pushes them into one batch-level `Claimed`. That is the existing
  type: its `Drop` removes each path and prints a `removed` line. Call `keep()` only after the last job,
  just before `batch-proved`.
- (b) App. A kill skips `Drop`. So when a batch ends without `batch-proved`, remove (or rename aside)
  every `out`, `.incomplete`, `.unverified-statement` and `owner_dir` path listed in its
  `batch-request.json` before any retry. Add that helper and its test to `batch_request.py`.
- (c) Add the native control in section 4, step 10.

### 2. [fix-before-adoption] The new production files are outside the randomness census

Where:
- frozen-r16b `s25_tests.rs:1595-1625` (`production_sources`);
- `s25_tests.rs:1700-1760` (the generator census; exactly 7 `ZkRng::from_os` sites, line 1752);
- `hash_domain_tests.rs:396-406` (the absorb-label scan, an explicit file list);
- staged `classify_cli.rs:522-523` (`#[path = "classify_batch.rs"] mod batch`).

What happens: the census reads `src/private_block/<module>.rs` and one level of children.
`classify_batch.rs` and `classify_batch_plan.rs` are grandchildren loaded by `#[path]`. So neither scan
reads them.

They are clean today. I read both files. Neither names `ZkRng`, a transcript, an absorb, a seal or an
endpoint. But a later edit could add a seeded generator there and the census would stay green. Condition 6
of the accepted toy statement rests on this census: "fresh operating-system randomness per proof; no seeded
configuration on this profile's path" (quoted at `s25_tests.rs:1666-1667`).

Fix (test code only): make `production_sources` follow `classify_cli.rs`'s production `#[path]`
children, with a fail-closed enumeration like the `tied_tables` one at `s25_tests.rs:1628-1633`.
Alternatively, list both files in both scans. The site count should stay 7.

### 3. [note] `classify_batch.rs` has never been type-checked

The light check only parsed it with `rustfmt`. Only `classify_batch_plan.rs` was compiled, standalone
(13 tests, `check-1/evidence.json`).

I checked name resolution by reading:
- the glob import from the parent module;
- private parent items, which a child module can see;
- `SharedProve`'s private fields, which the child can use;
- `owner_dir_at`, which is `pub(super)` in `token_io::cli`;
- the `#[path]` nesting.

I found nothing that should fail to compile. The adoption build is its first real compile.

### 4. [note; needs the coordinator's explicit reading of rule 3] What is reused across proofs

Kept per proof:
- Two new block readers per job: the sealing pass (`classify_cli.rs:591`) and the prove pass (`:611`).
- Every block reload is compared with the digest pass (frozen `load.rs:269-288`). That is 2 x 26 = 52
  checked reloads per job.

Reused across proofs, in memory, and immutable:
- The one digest pass, `ExportPublic`: the layer digests and the trained statement.
- The one R-C2 derivation, `BoundClassifierTables`: the 805 MB embedding and the margin row.

None of these types has a `Cell`, `RefCell`, `Mutex` or lazy cache. The batch only lends `&` references.
So a proof cannot change what the next proof sees.

The tables are not re-read from disk for each proof. The per-proof `st.check_tables` in
`prove_classify_run_with` (frozen `classify_run.rs:123`) compares the statement with that same in-memory value. This stretches N-r13-5's
"one authenticated pass" from one process to one post.

I read this as meeting rule 3. No on-disk weight is used without its digest check, and an in-memory value
cannot drift. But the rule says "no weights reused across proofs without that check". The coordinator
should rule on that wording for the tables explicitly.

### 5. [note] The chunk plan is hard-coded twice

`classify_batch.rs:85-91` builds the expected plan from T = 128 and overlap 8 before the export loads. The
native plan comes later, from `chunk_plan` (`classify_cli.rs:235-238`).

They agree today. For all 336 allowed lengths, the batch's plan, the native `chunk_ranges` formula and the
app's `category_work_plan` give the same jobs. The largest post gives 22 jobs and at most 8 chunks per
category. Length 337 needs 9 hate chunks and is refused [MEASURED: light Python, section 3 item 7].

Fix (cheap): in the preflight loop (`:119-125`), refuse unless `ch.count` equals the expected count for that
policy. Then a future overlap change fails before any proof, not at `label`.

### 6. [note] Bad activations are found late

A wrong or repeated `sequence_dir` for job k is caught only by job k's sealing pass. By then jobs 0 to k-1
have finished: about 7.3-7.6 minutes each [READ FROM FILE: r16 real prove totals 439-456 s]. This feeds
finding 1.

Fix (cheap; after the load and before job 0):
- refuse repeated sequence directories;
- check that each job's `x_in_L00` equals the embedding of its own item. That is `honest_inputs` plus one
  786,432-byte read (128 x 3072 x 2).

### 7. [note] `O_NOFOLLOW` is a raw number

`classify_batch.rs:30` uses `custom_flags(0x20800)`. That is `O_NOFOLLOW | O_NONBLOCK` on x86-64 Linux only.
On aarch64 Linux, 0x20000 is `O_LARGEFILE`, so a symlinked request would be followed silently. macOS
values differ again.

Fix: add a `compile_error!` outside x86-64 Linux, or use per-target constants. Also, only the request's mode
is checked, not its owner uid. The existing content-file rule works the same way.

### 8. [note] Private inputs under a receipt parent are not refused natively

`classify_batch_plan.rs:79-105` refuses an owner directory under any receipt parent. It does not refuse the
content file, the request or a sequence directory there. All three are private: the activations are
computed from the content.

The app path is safe. `batch_request.py` keeps all three under the 0700 job directory. The owners also live
there, and owners under a receipt parent are refused. A hand-built request is not covered.

Fix: apply the same `starts_with(receipt parent)` refusal to these inputs.

### 9. [note] `model_loads: 1` and `table_loads: 1` are printed constants

`classify_batch.rs:126` prints them as fixed text, and `batch_request.py:179-180` checks them. They prove
nothing.

Better evidence for rule 3: print each job's reload counts (`seal_blocks.loads` and `blocks.loads`; expect
26 and 26) in `batch-job-proved`, and check them in the router. Leave the single path's `proved` event
unchanged.

### 10. [note] A capture source pin moves

`src/private_block.rs` is in the capture's `OWN_SOURCE_FILES` (frozen `run_capture.rs:252`). The patch's
one-line `pub use` change moves that pin.

No proof byte depends on it. What the run header absorbs is `expected.to_bytes()`, not the source text.
`classify_cli.rs` also changes; it is not in `CLASSIFY_SOURCE_FILES` (`run_capture.rs:2635`).

Declare the moved pin in the adoption round's freeze note for the gate lane, as r16b did for `classify.rs`.

### 11. [note] The router sees only stdout and the exit code

`split_unverified_log` (`batch_request.py:157-232`) is strict. The app integration must still require the
guard record: exit 0, `child_rc` 0, not killed, not refused. `shieldstral_prover._guard` does this for
single proves (`apps/proven-media/proven_media/shieldstral_prover.py:104`).

### 12. [note] Memory and duration for a full post are not measured

A batch holds the export's public side, the 805 MB embedding and the content for its whole run. One single
prove holds the same things during its proof.

Per-proof peak should match a single prove: 8.1-8.3 GiB RSS and up to 11.5 GiB cgroup [READ FROM FILE: r16
`real-prove-*.guard.json`]. Allocator growth over 22 proofs is unknown.

A 22-job post takes about 22 x 330-440 s, roughly 2.0-2.7 hours. That is an estimate from the r16 timings
[READ FROM FILE]. It needs its own time window and a `--max-secs` that covers it. A guard kill in the middle
is finding 1.

### 13. [note] Baseline state, and rebasing onto r17

`frozen-r16b.FROZEN.txt` and `frozen-r17.FROZEN.txt` both say UNREVIEWED at freeze. I found no later
acceptance in `PROGRESS.md`.

The three modified files are byte-identical in frozen-r16b and frozen-r17 [MEASURED: sha256]. The other
token-io sources this review relies on are identical too: classify, classify_tied, classify_run, load, cli
and zkp-core `rng.rs`. So the patch applies unchanged to r17.

### 14. [note] Docs

The module text (`classify_cli.rs:1-13`) and the header of `examples/zk60_classify.rs` do not describe
`prove-batch`.

## 2. What the coordinator asked, answered

### State that now lives across proofs
- **Randomness.** Each classify proof makes exactly two OS-entropy reads:
  - the input-endpoint seal (`classify_cli.rs:604`, then `endpoint_g.rs:269`);
  - the run stream (`classify_run.rs:146`).

  Each `ZkRng::from_os` opens `/dev/urandom` and reads 32 new bytes (`zkp-core/src/rng.rs:30-51`). No
  generator, seal, endpoint owner, transcript, witness source or block reader outlives its job; all are
  locals of `prove_with_public`. The batch adds no generator. Cross-proof independence (X-1) rests on fresh
  reads exactly as before.
- **Hidden statics.** I swept non-test production code for `Cell`, `RefCell`, `Mutex`, `OnceLock`, `Atomic`
  and statics. I found only:
  - the legacy FFN host-buffer pools (`zk.rs:2450`, `layer.rs:347`), which the private block does not reach
    (`run_capture.rs:212-213` says the same);
  - the GPU pools, which are not compiled into the CPU-only CLI (`cli/zk60_classify.r16b.BUILD.txt`);
  - environment-flag `OnceLock`s;
  - `#[cfg(test)]` hooks.

  `ExportTokenBlocks` keeps a one-block cache, but it is per reader, and the readers are per job.

### Shared `ExportPublic` and `BoundClassifierTables`
Both are plain data, lent by `&`, with no interior mutability. See finding 4.

### Tied parameters and the table binding, per policy
- The R-C2 derivation and the file comparison run once (`classify_batch.rs:116`, under policy 0).
- That is correct: the derived row depends only on the export profile's (yes, no, scale), and every policy
  must equal those values (`classify_tied.rs:193-201`).
- All three moderate policies carry yes 13059, no 2649, c 0 and one scale (`classify.rs:205-221`) [READ FROM
  FILE].
- The per-policy check runs three times for each job: in the batch preflight (`classify_batch.rs:121`), in
  prove (`classify_cli.rs:570`) and in the statement constructor (`classify.rs:976`).
- Block reloads keep their digest check (finding 4).

### The single `prove` path
- By reading, `shared = None` runs the r16b sequence unchanged.
- The draw order is unchanged: the endpoint seal, then the run stream.
- The transcript order is unchanged.
- The only addition is `bound.check_for(...)` (`classify_cli.rs:570`). The statement constructor already runs
  it (`classify.rs:976`). It is pure, with no randomness and no transcript. It only moves the same refusal
  ahead of the content read.
- Verifier, input-owner and label code is byte-identical to r16b [MEASURED: diff]. Byte behaviour still needs
  section 4, step 7.

### D45 and owner-private handling
The batch:
- takes exactly the three registered moderate policies, in D37 order (`classify_batch_plan.rs:6-10, 25-42`);
- refuses missing, repeated, reordered or extra jobs;
- requires the request's N to equal the content's length, and checks the model identity;
- refuses `--content` and standard input;
- refuses existing outputs and sidecars, `..` paths and symlink aliases;
- makes every owner check before any load (with an explicit `--owner-dir`, `owner_dir_at` creates nothing);
- never verifies, and prints `verified:false`;
- prints the fail-closed line on every refusal.

Content appears only in the 0600 content file. Stdout carries only public values: lengths, policy, chunk,
verdict, paths. Owner directories are 0700 and `input.dec` is 0600 (existing code). Python writes the job
directory 0700 and its files 0600.

### The router (`batch_request.py`)
It never reports more than `status: unverified`. It refuses:
- a non-zero exit;
- a missing, duplicated or reordered job or segment;
- any refusal, removal or unknown event;
- events after completion;
- duplicate JSON keys, NaN and Infinity;
- a changed identity, total, policy, floor or receipt size;
- `verified: true`.

[READ: lines 157-232; Astra's 20 tests passed, `check-1/evidence.json`; their hashes match the current files
[MEASURED].]

## 3. Evidence behind the numbers
1. Hashes of all staged, baseline and r17 files [MEASURED, sha256].
2. Single real T128 prove: prove 328.4 s and total 439.2 s (the sexual log); guard wall 439.3-455.9 s over the
   three categories; receipt 848,412,096 bytes; peak RSS 8.08-8.27 GiB; cgroup 9.42-11.5 GiB [READ FROM FILE:
   `r16/logs/real-prove-*.log`, `*.guard.json`].
3. Fresh checks: verify about 68-70 s, input-owner about 67-68 s, label about 66-67 s [READ FROM FILE].
4. App guard budgets (GiB need / cap / seconds): seqgen 1.5/3/600, prove 10.4/11.5/1200, verify 2.9/7/600,
   inowner 2.9/7/600, label 2.9/7/1800 [READ FROM FILE: `shieldstral_runtime.py:32-33`].
5. Full suite s21: 890 s, peak RSS 7.89 GiB, cgroup 8.22 GiB, declared 8.5 / cap 10 [READ FROM FILE:
   `frozen-r16b.FROZEN.txt`].
6. Free disk: 468 GB [MEASURED, `df`]; bubblewrap 0.6.1 present [MEASURED, `bwrap --version`].
7. Plan check: all 336 lengths agree, 22 jobs at most, 8 chunks at most, 337 refused [MEASURED: light Python,
   `/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/plan_check.py`;
   it reads only the app planner and the policy candidates file].

## 4. Byte-identity test plan

### 4.1 Why the code cannot test this as it stands
Randomness is OS-seeded: two `from_os` reads per proof, and no seed flag. A seeded hook in the source would
move frozen gates. The s25 census pins exactly 7 `ZkRng::from_os` sites and forbids any other `ZkRng`
constructor in production text (`s25_tests.rs:1720-1752`). Condition 6 of the accepted toy statement forbids a
seeded configuration on the path. So I do not recommend a source hook.

### 4.2 The narrowest hook: none in the source
Run the real release binaries inside a bubblewrap mount namespace, with `/dev/urandom` replaced by a FIFO. The
FIFO holds public, fixed 32-byte blocks in draw order. `from_os` opens `/dev/urandom` by path on every call.
So:
- each draw takes the next block;
- the batch is given the per-job blocks concatenated, in job order;
- a skipped draw leaves blocks unread (exit 97);
- an extra draw blocks on its read until the guard's `--max-secs` ends it;
- a value reused across jobs changes the bytes.

Production is untouched: no code change and no flag.

**The receipts made this way do not hide anything** (public, fixed entropy). Use the public test sentence
below. Never publish these receipts, never give them to the app, and delete them at the end. Keep only the
logs, the guard JSONs and the comparison output, under `results/zk60_token_io_r1_20261017/r18/` (the
`/tmp`-loss rule).

Run every heavy step with the CLAUDE.md detach recipe (`setsid nohup` and a `.done` marker), with the guard
inside it, one at a time. The guard's heavy lock serializes them. Read `guard status` before any timing.

### 4.3 Commands (for a script)

```bash
R=/home/victor/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
A5=$R/results/zk60_astra_20261026/a5_batch_candidate
EX=$R/results/zk60_shieldstral_export_20261026/native_low_h24_t128
TAB=$R/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier/token_io
WRITER=$R/results/zk60_shieldstral_export_20261026/write_item_activations.py
VENV=$R/apps/proven-media/.venv/bin/python
R16B=$R/results/zk60_token_io_r1_20261017/cli/zk60_classify.r16b.release.bin
H=$R/ops/zkp-mvp/token-io-r18/hashline          # the lane's r18 tree: patch applied (adjust the name)
CAND=$H/target/release/examples/zk60_classify
EQ=/home/victor/zk60-artifacts/token-io/r18-a5-eq       # receipts, logs, entropy (outside git)
OWN=/home/victor/zk60-owner-private/token-io/r18-a5-eq  # content, activations, owners (outside git, 0700)
JOB=$OWN/batch; L=$EQ/logs; LBL=zk60-classify-verdict
P0=shieldstral-1.0-3b-moderate-sexual/1; P1=shieldstral-1.0-3b-moderate-violence/1; P2=shieldstral-1.0-3b-moderate-hate/1
```

**Step 0, set up (light).**
```bash
mkdir -p $EQ/batch $EQ/single $EQ/r16b $EQ/ent $EQ/fail $L
mkdir -m 700 -p $OWN $OWN/single-owner $OWN/r16b-owner $OWN/fail $OWN/fail/owners $OWN/fail/empty
python3 -c "import hashlib,sys; d=sys.argv[1]; blk=lambda t: hashlib.sha256(b'a5-eq/'+t.encode()).digest(); S={'sanity':['s0','s1'],'batch':['e0','r0','e1','r1','e2','r2'],'job0':['e0','r0'],'job1':['e1','r1'],'job2':['e2','r2']}; [open(f'{d}/{n}.bin','wb').write(b''.join(map(blk,v))) for n,v in S.items()]" $EQ/ent
```
Save as `$EQ/ent/run_fixed.sh`:
```bash
#!/bin/bash
# TEST ONLY. run_fixed.sh BLOCKS -- CMD...: run CMD with /dev/urandom replaced by a FIFO holding BLOCKS
# (32-byte blocks, in draw order). Exit 97 if CMD left any block unread. An extra draw blocks; the guard's
# --max-secs ends it. Receipts made this way do not hide anything: never publish, never give to the app.
set -u
blocks=$1; shift; [ "${1:-}" = -- ] && shift
fifo=$(mktemp -u "$(dirname "$blocks")/fifo.XXXXXX"); mkfifo -m 600 "$fifo"
exec 3<>"$fifo"            # read-write open: never blocks; keeps the pipe alive between the prover's reads
cat "$blocks" >&3
bwrap --dev-bind / / --bind "$fifo" /dev/urandom --die-with-parent -- "$@"; rc=$?
left=$(python3 -c 'import os
os.set_blocking(3, False)
try: print(len(os.read(3, 1 << 16)))
except BlockingIOError: print(0)')
exec 3<&-; rm -f "$fifo"
echo "{\"event\":\"fixed-entropy\",\"block_bytes\":$(stat -c %s "$blocks"),\"unread_bytes\":$left,\"rc\":$rc}" >&2
[ "$rc" = 0 ] || exit "$rc"; [ "$left" = 0 ] || exit 97
```
Sanity check (light). Expect two hex lines equal to sha256(`a5-eq/s0`) and sha256(`a5-eq/s1`),
`unread_bytes 0`, and exit 0. If this fails, stop: the plan needs another entropy route.
```bash
$G --class light --label tio18-a5-ent-sanity --log $L/sanity.log --result-json $L/sanity.guard.json -- bash $EQ/ent/run_fixed.sh $EQ/ent/sanity.bin -- python3 -c "[print(open('/dev/urandom','rb').read(32).hex()) for _ in range(2)]"
```

**Step 1, build and run the regressions (build class).** First apply the patch to the r18 tree and fix
findings 1 and 2.
```bash
$G --class build --need-gib 2.5 --cap-gib 3.5 --label tio18-a5-cli --wait-secs 14400 --max-secs 2400 --log $L/cli.log --done $L/cli.guard.done --result-json $L/cli.guard.json -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
```
Then run the lane's full suite exactly as s21 (declared 8.5 / cap 10 GiB). Record `sha256sum $CAND`.

**Step 2, prepare one public post (light).** This is Astra's test sentence: 17 ids, so 3 jobs of 1 chunk each.
Expect the output `3 17`.
```bash
/usr/bin/env PM_PROVER=shieldstral $VENV -c "import sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; plan=b.proof_plans.category_work_plan(17, b.runtime.templates()); m=b.prepare_text('a5eq', 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.', plan, sys.argv[2], sys.argv[3], reserved_context=b.records.screening_context()); print(len(m['jobs']), m['content_total'])" $A5 $JOB $EQ/batch
```

**Step 3, activations (cpu).** The app's seqgen budget is for one item; this request has three.
```bash
$G --class cpu --need-gib 1.5 --cap-gib 3 --label tio18-a5-act --wait-secs 14400 --max-secs 1800 --log $L/act.log --done $L/act.guard.done --result-json $L/act.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 $VENV $WRITER --request $JOB/activation-request.json --out $JOB/activations
```

**Step 4, the batch with fixed entropy (cpu, heavy).**
```bash
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-batch --wait-secs 14400 --max-secs 3600 --log $L/batch.log --done $L/batch.guard.done --result-json $L/batch.guard.json -- bash $EQ/ent/run_fixed.sh $EQ/ent/batch.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove-batch --export $EX --tables $TAB --content-file $JOB/content.ids --batch-file $JOB/batch-request.json --label $LBL
```

**Steps 5-6, three single proves with the candidate (cpu, heavy, one at a time).** Use i = 0, 1, 2 with
`P=$P0`, `$P1`, `$P2`.
```bash
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-single-c$i --wait-secs 14400 --max-secs 1800 --log $L/single-c$i.log --done $L/single-c$i.guard.done --result-json $L/single-c$i.guard.json -- bash $EQ/ent/run_fixed.sh $EQ/ent/job$i.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove --export $EX --tables $TAB --policy $P --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c$i --out $EQ/single/c$i --owner-dir $OWN/single-owner/c$i --label $LBL
```

**Step 7, the r16b control for job 0 (cpu, heavy).** This shows the single path's refactor is byte-preserving
against the reviewed binary.
```bash
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-r16b-c0 --wait-secs 14400 --max-secs 1800 --log $L/r16b-c0.log --done $L/r16b-c0.guard.done --result-json $L/r16b-c0.guard.json -- bash $EQ/ent/run_fixed.sh $EQ/ent/job0.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $R16B prove --export $EX --tables $TAB --policy $P0 --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c0 --out $EQ/r16b/c0 --owner-dir $OWN/r16b-owner/c0 --label $LBL
```

**Step 8, compare byte for byte (light).** Do this before any verify: verify writes into the run directory.
Save as `$EQ/compare.py`:
```python
import hashlib, json, os, sys
EQ, OWN = sys.argv[1], sys.argv[2]
def tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in files:
            p, h = os.path.join(root, f), hashlib.sha256()
            with open(p, 'rb') as fh:
                for b in iter(lambda: fh.read(1 << 20), b''): h.update(b)
            out[os.path.relpath(p, d)] = h.hexdigest()
    return out
def triple(out, owner):
    return {'receipt': tree(out), 'statement': tree(out + '.unverified-statement'), 'owner': tree(owner)}
rows, ok = [], True
for i in range(3):
    b = triple(f'{EQ}/batch/a5eq-c{i}', f'{OWN}/batch/owners/c{i}')
    s = triple(f'{EQ}/single/c{i}', f'{OWN}/single-owner/c{i}')
    same = b == s and all(b.values())
    rows.append({'job': i, 'batch_equals_single': same, 'files': sum(map(len, b.values()))}); ok &= same
r = triple(f'{EQ}/r16b/c0', f'{OWN}/r16b-owner/c0'); s0 = triple(f'{EQ}/single/c0', f'{OWN}/single-owner/c0')
rows.append({'job': 0, 'r16b_equals_candidate_single': r == s0 and all(r.values())}); ok &= r == s0
print(json.dumps({'ok': ok, 'rows': rows})); sys.exit(0 if ok else 1)
```
```bash
$G --class light --label tio18-a5-compare --log $L/compare.log --result-json $L/compare.guard.json -- python3 $EQ/compare.py $EQ $OWN
```
If the r16b control differs, first rerun step 5 for c0 and compare it with its own first run. That tells
"not deterministic" apart from "the refactor changed bytes".

**Step 9, the router and the fresh checks (light, then cpu).** The router must return `unverified`:
```bash
/usr/bin/env PM_PROVER=shieldstral $VENV -c "import json,sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; m=json.load(open(sys.argv[2]+'/batch-request.json')); out=''.join(l for l in open(sys.argv[3]) if l.startswith('{\"event\"') and 'fixed-entropy' not in l); print(b.split_unverified_log(out, 0, m, 17)['status'])" $A5 $JOB $L/batch.log
```
Print the reviewed r16b fresh-check commands:
```bash
/usr/bin/env PM_PROVER=shieldstral $VENV -c "import json,shlex,sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; m=json.load(open(sys.argv[2]+'/batch-request.json')); [print(n, shlex.join(c)) for n, c in b.fresh_check_commands(m, 17, sys.argv[2])]" $A5 $JOB
```
Run each printed command in its own fresh process:
```bash
$G --class cpu --need-gib 2.9 --cap-gib 7 --max-secs 600 --label tio18-a5-<name> --log $L/<name>.log --result-json $L/<name>.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 <command>
```
Use `--max-secs 1800` for the label commands.

**Step 10, the fail-closed control (normal entropy; after the fix for finding 1).** Save as
`$EQ/make_fail_request.py`:
```python
import json, os, sys
src, own, eq = sys.argv[1:4]
m = json.load(open(src))
for r in m['jobs']:
    r['out'], r['owner_dir'] = f"{eq}/{r['name']}", f"{own}/owners/{r['name']}"
m['jobs'][1]['sequence_dir'] = f"{own}/empty"      # job 1 must refuse before its header
fd = os.open(f"{own}/batch-request.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
os.write(fd, json.dumps(m).encode()); os.close(fd)
```
```bash
python3 $EQ/make_fail_request.py $JOB/batch-request.json $OWN/fail $EQ/fail
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-failclosed --wait-secs 14400 --max-secs 2400 --log $L/fail.log --done $L/fail.guard.done --result-json $L/fail.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove-batch --export $EX --tables $TAB --content-file $JOB/content.ids --batch-file $OWN/fail/batch-request.json --label $LBL
find $EQ/fail $OWN/fail/owners -mindepth 1 -maxdepth 1 | wc -l
```

**Step 11, clean up.** Delete `$EQ/batch`, `$EQ/single`, `$EQ/r16b`, `$EQ/fail` and every owner directory
under `$OWN`. Copy the logs, guard JSONs and `compare.log` into `results/zk60_token_io_r1_20261017/r18/`.

### 4.4 Pass criteria
- Step 0: the sanity output is as expected, with `unread_bytes 0`.
- Steps 4-7: every guard has exit 0 and `child_rc` 0. Each stderr `fixed-entropy` line shows
  `unread_bytes 0`: 192 bytes for the batch, 64 bytes for each single prove.
- Step 8: `ok: true`. For each of the 3 jobs, every receipt segment, the unverified `statement.json` and
  `input.dec` match the single run byte for byte, and r16b's job 0 matches the candidate's job 0.
- Step 9: the router returns `unverified`. All 3 verify, 3 input-owner and 3 label commands exit 0. Each label
  uses `--expect-total 17`.
- Step 10: the child exits 1. The log shows job 0's `proved`, then `removed` lines, `refused` and the
  fail-closed `app-outcome` line, and no `batch-proved`. `find` counts 0. Before the fix it counts job 0's
  leftovers; that reproduces finding 1.
- Also record the batch's `load_seconds`, each proof's time, total wall time, peak RSS and cgroup.

### 4.5 Cost (estimates from r16 timings [READ FROM FILE])
About 75 minutes of heavy-lock time:
- batch, about 20-23 minutes;
- three single proves, about 22 minutes;
- the r16b control, about 7.5 minutes;
- the fail control, about 9 minutes;
- nine fresh checks, about 10.5 minutes.

On top of that come the activations (step 3) and the build and suite (s21 took 890 s). Disk needed: 7 receipts
of 848 MB each, about 6 GB, plus 0.85 GB for the fail control. 468 GB is free [MEASURED].

## 5. What I did not check
- I did not compile, run any test, prove, or run the bubblewrap sanity step. Section 4's FIFO route is
  untested here, including how it interacts with the guard's scope and with user namespaces.
- I did not read `prove_classify_run_with`, `stage_in_c` or `stage_out_c` line by line. I read only their
  randomness sites and entry checks. For the `zk.rs` mask helpers, I relied on the static sweep and the s25
  census.
- I did not audit the `apps/proven-media` helpers (`write_private`, `in_git_tree`, `proof_plans`) beyond what
  Astra's tests and my plan check exercise. I did not measure the activation writer's memory for a
  three-item request.
- I did not confirm r16b's review state beyond its freeze note and a search of `PROGRESS.md`.
- I did not check GPU builds, non-x86-64 targets, or a multi-chunk post (more than 3 jobs). The test above uses
  1 chunk per category; a multi-chunk byte test is one more batch of, for example, 56 ids (6 jobs).
