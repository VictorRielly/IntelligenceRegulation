# Evidence: the RUN gate under the KEYED HASH RULE, 2026-09-20

The RUN gate run on the two TAGGED capture bundles — the ones stage 18 of
the Rust lane re-took under decision D19's separating hash tag, carrying
every public table's values. Tool: `scripts/zk60_native_run_gate.py`, with
the round-3 modules `zk60_native_rg_hashrule.py` (the rule and the keyed
transcript), `zk60_native_rg_hashlayer.py` (stage 9), and
`zk60_native_rg_hcontrols.py` (the rule's controls), plus the eleven new
ports in `zk60_native_rg_terminals.py`. Report:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §7. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`, round 3.

**Nothing here is a privacy acceptance and no file here establishes a
privacy property.** Which BLAKE3 made a receipt, and whether the receipt is
self-consistent at its real challenges, are not statements about what it
discloses. The disclosure figures of stages 3 and 4 are the same ranks of
the same explicitly stated LINEAR model at ONE development shape, and the
HIDING of an unopened leaf is still argued (M-2, M-3).

## Clock

Written 2026-09-20. The six gate runs below were taken between **17:12 and
17:18 PDT** on the shared WSL laptop, CPU only, one at a time; the 125M
timing run on the same box had finished at 16:39 (`m125-one-block-tagged
.done`), so nothing else was competing for a core.

## Input, READ-ONLY and NOT copied here

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`. Six
independent honest three-block runs at the development rung (24 tokens,
width 96, hidden 192, 6 query heads over 2 key-value heads; 1,024 columns,
inverse rate 4, 256 opened columns), schema `hashline-native-capture/4-run`.
They are SIX DIFFERENT RUNS with fresh randomness each: `run-e-tame-tagged`
is not `run-c-tame` re-keyed.

| bundle | stage | hash rule | public tables | `manifest.json` SHA-256 (of the file, as read) | `total_bytes` | source commit |
|---|---|---|---|---|---:|---|
| `run-e-tame-tagged` | 18 | **`blake3-keyed/1`** | **values** | `0cddba4b36962a13714c0603485ab46787c6c31d0be325e4edad645320012105` | 41,256,627 | `facc057` |
| `run-f-zero-tagged` | 18 | **`blake3-keyed/1`** | **values** | `57cd8437dee6e9529633b780415393b107c4d10f1d7396f93d07fbd1cdf5996e` | 41,249,809 | `facc057` |
| `run-a-tame`, `run-b-zero` | 14 | legacy (pre-tag) | no | (round 1's README) | 38,484,890 / 38,482,131 | `cb27845` |
| `run-c-tame`, `run-d-zero` | 15 | legacy (pre-tag) | no | (round 2's README) | 38,509,009 / 38,499,945 | `aff891d` |

Every bundle's own manifest hashes are re-checked by the gate's stage 1; the
column above is the hash of the manifest FILE itself, which stage 1 does not
cover, so that this record pins the input end to end.

**The source pins moved, and the move was read.** The tagged bundles pin
`argument.rs 909670c9` and `plane_index.rs 9de8320a` — byte-identical to the
stage-15 bundles, so no ported polynomial is in question — and they pin
`layout.rs b765bdcb`, `protocol.rs e012450b` and (new) `shape.rs 9ac32109`.
Those three diffs are the D19 hash-tag plumbing and the T-3 / T-4
path-length checks; nothing this port reads changed. The two new digests
are accepted BY NAME in `zk60_native_rg_terminals.ALSO_ACCEPTED` /
`PINNED_IF_PRESENT` with that reason, and any other move still makes every
slot NOT CHECKED.

## Exact commands

```
cd /home/victor/wt-zk60-jointview
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
E=results/zk60_native_run_gate_tagged

# the two TAGGED bundles
python3 scripts/zk60_native_run_gate.py --bundle $B/run-e-tame-tagged \
    --other $B/run-f-zero-tagged --old $B/run-a-tame --evidence $E
python3 scripts/zk60_native_run_gate.py --bundle $B/run-f-zero-tagged \
    --other $B/run-e-tame-tagged --old $B/run-b-zero --evidence $E

# the four SUPERSEDED bundles, re-run and diffed against their round-2 records
for p in run-a-tame run-b-zero run-c-tame run-d-zero; do
  python3 scripts/zk60_native_run_gate.py --bundle $B/$p --other <the other> \
      --old $B/run-a-tame --evidence $E/old
  python3 scripts/zk60_native_rg_recdiff.py <the round-2 record> \
      $E/old/$p.json --out $E/old/$p.diff.json
done
python3 scripts/zk60_native_rg_recclass.py $E/old/*.diff.json \
    --out $E/old/old_bundles_unchanged.json

# the tests
python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate*.py' -v
python3 -m unittest discover -s tests -p 'test_zk60_native*.py' -v
```

The round-2 records the diffs are taken against are the committed ones at
`HEAD` before this round refreshed them in place (`git show
HEAD:results/zk60_native_run_gate/run-a-tame.json` and the three siblings);
after the diff, `results/zk60_native_run_gate/` and
`results/zk60_native_run_gate_planeindex/` were refreshed with the round-3
tools, as round 2 did for round 1's, so that the tracked evidence always
matches the tool bytes in the tree.

## Files

| file | what |
|---|---|
| `run-e-tame-tagged.json`, `run-f-zero-tagged.json` | the whole gate record, nine stages |
| `run-{e,f}-*.log`, `*.done` | the run's stdout and its exit code |
| `old/run-{a,b,c,d}-*.json` | the four superseded bundles re-run under round 3 |
| `old/run-{a,b,c,d}-*.diff.json` | each one diffed leaf by leaf against its round-2 record |
| `old/old_bundles_unchanged.json` | those diffs classified: **0 unclassified leaves** |
| `tests_tagged.log` | this round's own test file, 29 tests |
| `tests_run_gate_all.log` | the three RUN-gate test files, **94 tests, OK** |
| `tests_native_all.log`, `.done` | the whole native suite |
| `tests_existing_{before,after}.log` | the two assertions round 3 had to move, before and after |

## The figures (MEASURED, both tagged bundles unless a column says otherwise)

### The rule (stage 1, and the new `hash_rule` block)

| | `run-e-tame-tagged` / `run-f-zero-tagged` |
|---|---|
| rule DERIVED from the profile the shape names | `blake3-keyed/1` |
| keys re-derived here and compared with the bundle's `keys_hex` | **4 of 4** |
| context strings compared with the ones pinned in the tool | **4 of 4** |
| the bundle's declared profile against the shape's | equal (`…private-block-rung-g-t24-dev/1`) |
| the run profile (the transcript DOMAIN) | `…private-run-rung-g-t24-dev/1` — a DIFFERENT string, as it should be |
| refusals | none |

### The replay under the tag (stage 2)

Round 1's counts exactly, under another hash function:

| | round 1 (legacy) | round 3 (tagged) |
|---|---|---|
| run binding | reproduced | **reproduced** |
| transcript positions compared as (state, next) | 375 | **375** |
| challenges re-derived and compared | 6,086 | **6,086** |
| final transcript counter | 6,918 | **6,918** |
| segment position tags (from a discarded CLONE, which carries the key) | 6 of 6 | **6 of 6** |
| challenges NOT re-derived | none | **none** |

### The hash layer, COMPUTED (stage 9 — new)

| | figure |
|---|---|
| openings re-hashed (M, A, H, Input, + Output in the last stage) | **13** |
| opened columns re-hashed and re-authenticated | **3,328 of 3,328** |
| path lengths checked against the tree depth (12) | **3,328** |
| bytes hashed | 7,751,680 |
| distinct salted leaves | 3,222 / 3,218 (the rest are repeated column indices — sampling with replacement) |
| cross-rule probe: wrong rules tried on one column | **4**, none reached the root |

### The terminal identity (stage 8)

| | round 2 (stage-15 bundle) | round 3 (tagged bundle) |
|---|---|---|
| slots evaluated | 12 of 23 | **23 of 23** |
| slot checks equal, all stages | 36 of 36 | **69 of 69** |
| matching the capture's own `terminal_polynomial` | 36 | **69** |
| slots OPEN | 11 | **0** |
| public tables REBUILT here and digest-matched, per stage | 11 | **16** |
| public tables TAKEN from the capture, per stage | 0 | **15** |
| structure checks on captured tables | — | **45** (15 × 3 stages) |
| every carried public table against its own `len` and SHA-256 | — | **93 of 93** |

### Unchanged: the disclosure model

| | both tagged bundles |
|---|---|
| disclosed, `A@k` / `H@k` / boundaries / endpoints | 0 / 2 / 0 / 0 |
| each boundary on its reserved rows | rank **6 of 6**, disclosed **0**, determinant nonzero |
| the three roles of a boundary plane | parts 0,0,0, sum 0, joint **0**, 8 identified rows, 1,248 classes |
| adjacent stage pairs | 202 × 2,505, joint **4** = sum 4 |
| the whole run | 308 × 3,761, joint **6** = sum 6 |
| H-pad, computed | 248 of 248 / 246 of 246 |
| the six stage-6 controls | all fire |

### Controls

Eight on the terminal channel (CT-1 … CT-8) and six on the rule (CH-1 …
CH-6); **all fourteen fire** on both bundles. The two sharpest:

* **CH-4** — the bundle renamed `legacy`: refused by name, and then, with
  the legacy rule actually computed, the run binding does not reproduce
  (6,854 replay failures) and **0 of 3,328** columns authenticate.
* **CT-7** — one captured public table value changed by +1 with the digest
  check dropped: the identity fails at **exactly** stage 0 slot 5 and
  nowhere else.

### The channel table, recounted from the tool's own array

| bundle | total | constructed | derived | argued | **open** |
|---|---:|---:|---:|---:|---:|
| `run-e-tame-tagged`, `run-f-zero-tagged` | **25** | 2 | **5** | 4 | **14** |
| `run-c-tame`, `run-d-zero` (re-run) | 25 | 2 | 4 | 4 | 15 |
| `run-a-tame`, `run-b-zero` (re-run) | 25 | 2 | 3 | 4 | 16 |
| the tagged bundles, if round 2's table were used | 24 | 2 | 3 | 4 | 15 |

One entry was ADDED (the hash rule of the run, DERIVED) and one was CLOSED
(the eleven table-bearing slots, now DERIVED), so the open count falls by
one and the total rises by one.

### The four superseded bundles

`old/old_bundles_unchanged.json`: **0 unclassified differing leaves** on all
four. Every difference is a wall clock, a tool SHA-256, one of the two new
record blocks, the replay naming its rule, the new (empty) fields about
captured tables, the reworded OPEN reason, or the insertion of one channel
entry — 2,222 / 2,223 / 2,831 / 2,831 identical leaves. No rank, disclosed
dimension, challenge count, slot check or control figure moved.

## What this evidence does NOT establish

* **Not a privacy property and not a privacy acceptance.** Ruling M-8's
  decision, D8/D11 and the run's joint-law composition are untouched.
* **The hash layer's HIDING is still argued.** Stage 9 authenticates the
  columns that were OPENED; what an unopened leaf hides is M-2 either way.
* **A captured public table is checked against the capture's own length,
  SHA-256 and the structure its builder gives it — never against the weight
  matrix the statement names**, because no bundle carries a weight.
* **Two runs, one development shape.** Nothing here is about the 125M shape.
* The keyed rule is an idealisation: D19 reads BLAKE3's modes as a family of
  independent random functions, and two profiles share a key only with
  negligible probability rather than never (ruling T-1 as amended).
