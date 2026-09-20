# Evidence: the RUN gate with the PLANE INDEX TABLE, 2026-09-20

The RUN gate run on the two NEW capture bundles, the ones that carry
`run.json["plane_index"]` (stage 15 of the Rust lane, 2026-09-20). Tool:
`scripts/zk60_native_run_gate.py`, with the new stage 8
(`scripts/zk60_native_rg_planes.py`, `scripts/zk60_native_rg_terminals.py`,
`scripts/zk60_native_rg_tcontrols.py`). Report:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §6. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`, round 2.

**Nothing here is a privacy acceptance and no file here establishes a privacy
property.** Recomputing the verifier's own final check at a captured run's
real challenges is a CONSISTENCY statement about that receipt. The disclosure
figures of stages 3 and 4 are still ranks of an explicitly stated LINEAR
model at ONE development shape, and the hash layer is still argued.

## Clock

Written 2026-09-20. The four gate runs below were taken between **14:33:55
and 14:34:42 PDT** on the shared WSL laptop, CPU only, one at a time.

## Input, READ-ONLY and NOT copied here

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`, four
independent honest three-block runs at the development rung (24 tokens,
width 96, hidden 192, 6 query heads over 2 key-value heads; 1,024 columns,
inverse rate 4, 256 opened columns), schema `hashline-native-capture/4-run`.
The four are FOUR DIFFERENT RUNS with fresh randomness each — `run-c-tame`
is not `run-a-tame` with a field added.

| bundle | stage | `manifest.json` SHA-256 (of the file, as read) | `total_bytes` | source commit | has `plane_index` |
|---|---|---|---:|---|---|
| `run-c-tame` | 15 | `76bad2d92b874b14a3d67629e802fe540975d12c2f6c2bc592162c0c733d25c9` | 38,509,009 | `aff891d` | **yes** |
| `run-d-zero` | 15 | `4cd9f2bbeaf8552a37a4433736a62a5f3c7f3c35c00373d31e12a8b5b27be83e` | 38,499,945 | `aff891d` | **yes** |
| `run-a-tame` | 14 | `20732d786cf6472c74017ae29fa8c4a26629daba9dcfc6147de47a7ff0e0cad4` | 38,484,890 | `cb27845d5ad3a0e401c48c4eebeac7fe4a86f171` | no |
| `run-b-zero` | 14 | `a0184d2d49f983319d576fb8f250aae21183d9a8301917e08cd4b38121c4d74d` | 38,482,131 | `cb27845d5ad3a0e401c48c4eebeac7fe4a86f171` | no |

Every bundle's own manifest hashes are re-checked by the gate's stage 1; the
line above is the hash of the manifest FILE itself, which stage 1 does not
cover, so that this record pins the input end to end. `run-c-tame` and
`run-d-zero` pin `argument.rs 909670c9`, `layout.rs fec2e647`,
`protocol.rs 4e916c69` and `plane_index.rs 9de8320a`, which are exactly the
digests the Python port declares in `zk60_native_rg_terminals.PORTED_FROM`;
a pin that moved makes every slot NOT CHECKED rather than silently wrong.

## Exact commands

```
cd /home/victor/wt-zk60-jointview
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920

python3 scripts/zk60_native_run_gate.py \
  --bundle $B/run-c-tame --other $B/run-d-zero --old $B/run-a-tame \
  --evidence results/zk60_native_run_gate_planeindex

python3 scripts/zk60_native_run_gate.py \
  --bundle $B/run-d-zero --other $B/run-c-tame --old $B/run-a-tame \
  --evidence results/zk60_native_run_gate_planeindex
```

`--old` names a bundle written BEFORE stage 15; it is control CT-4's input,
and without it that control reports itself skipped rather than passed.

The two OLD bundles were re-run into their own (pre-existing) directory, so
that the committed record there stays in step with the tools now in the tree:

```
python3 scripts/zk60_native_run_gate.py \
  --bundle $B/run-a-tame --other $B/run-b-zero --old $B/run-b-zero \
  --evidence results/zk60_native_run_gate
python3 scripts/zk60_native_run_gate.py \
  --bundle $B/run-b-zero --other $B/run-a-tame --old $B/run-a-tame \
  --evidence results/zk60_native_run_gate

python3 scripts/zk60_native_rg_recdiff.py \
  <the committed record at d0c8699> results/zk60_native_run_gate/run-a-tame.json \
  --out results/zk60_native_run_gate_planeindex/old_bundle_run-a-tame.diff.json
```

## Files here

| file | what |
|---|---|
| `run-c-tame.json`, `run-d-zero.json` | the whole gate's record for each new bundle, `stage8_plane_index_and_terminals` included |
| `run-c-tame.log`, `run-d-zero.log` | the console line per stage |
| `*.done` | `0` = the gate passed |
| `old_bundles_unchanged.json` | the two OLD bundles' channel tables before and after this round, matched by channel NAME |
| `old_bundle_run-a-tame.diff.json`, `old_bundle_run-b-zero.diff.json` | the same two records diffed leaf by leaf |

## What stage 8 found, both new bundles, identically

| | figure |
|---|---|
| plane index: `A` planes / rows | **83** planes tiling **377** rows, exactly, no gap and no overlap |
| plane index: `H` planes / rows | **52** planes whose two halves (`re`, `im`) tile **470** rows, exactly |
| the totals against each stage's own `A` / `H` opening | equal, all three stages |
| every plane read by some slot | yes (no committed plane unaccounted for) |
| `len(terminals) == len(planes)` | 176 terminals against 176 planes, per stage, all three |
| private tables' slice offsets inside the plane they name | 226 of 226, per stage, all three |
| terminal identity: slots covered | **12 of 23**, in every stage |
| terminal identity: checks equal | **36 of 36** (`fin == c*mask_eval + poly(terminals)`) |
| ... and matching the capture's own `terminal_polynomial` | **36 of 36** |
| public tables rebuilt and digest-matched | **11 per stage**: `supp(T)`, `supp(Ht)`, `supp(L)`, `supp(D)`, `supp(S)`, `supp(F)`, the causal mask, the all-ones `Dom::Tab` vector |
| slots still OPEN | **11**, all for one reason: the bundle carries no public table VALUES and theirs are not a function of the shape |
| controls | **five, all fire** |
| whole gate, per bundle | 10.8 s / 11.2 s |

## The channel table, before and after

| | before (commit `d0c8699`) | after |
|---|---|---|
| `run-c-tame`, `run-d-zero` | — (these bundles did not exist) | 24 channels: 2 constructed, **3 derived**, 4 argued, **15 open** |
| `run-a-tame`, `run-b-zero` | 23 channels: 2 constructed, 2 derived, 4 argued, **15 open** | 24 channels: 2 constructed, 2 derived, 4 argued, **16 open** |

The terminal-identity channel is now TWO entries — the slots the gate
recomputes and the slots whose public tables the bundle does not carry —
because one status cannot honestly describe a channel that is 12/23
evaluated. For a bundle with no plane index table both halves are OPEN,
which is why the old bundles read 16 of 24 and not 15 of 23; nothing they
MEASURE moved (see `old_bundles_unchanged.json`: 21 of the 23 channel
entries are byte-identical, and the leaf diff shows no rank, count,
disclosed dimension, challenge count or control figure changed).
