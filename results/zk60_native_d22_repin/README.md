# `results/zk60_native_d22_repin/` — the D22 re-read and re-pin at `4751b93`

2026-09-20, lane `zk60-native-jointview`. The reading itself is
`docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md`; this directory holds
what it was computed from. **Nothing here is a privacy acceptance and
nothing here establishes a privacy property.**

## The inventory and the reading

| file | what it is |
|---|---|
| `pins.py` | regenerates the two files below; read-only (`git show` + SHA-256) |
| `pin_table.txt` | every source pin of the two toy gate tools that hold one, at the commit the tool names, at `4751b93^`, at `4751b93`, on this worktree's disk and on main's. **One pin of fourteen moves: `hashline/src/zk.rs` in `zk60_native_mask_commit.py`** |
| `capture_drift.txt` | the wider net: which of the 92 files the capture manifest records had already moved by `4751b93^` (two) and which `4751b93` moves (seven) |
| `reread.py` | regenerates `reread.txt`; locates each item by its definition line and compares its bytes at the two commits |
| `reread.txt` | the item-level verdict: **0 of 18** items of `zk.rs` on this profile's path changed, **0 of 7** of `hashline/src/pcs.rs`, **0 of 6** of the `layer.rs` items `zk.rs` imports; and `zk.rs` lines 1-2274 are byte-identical |

## The diffs of record

`zk_rs_diff.txt` (twelve hunks, all at or below line 2275),
`pcs_and_pb_diff.txt` (47 added lines, 0 deleted),
`gpu_mod_diff.txt` (0 deleted), `gpu_cuda_diff.txt`,
`layer_wcache_diff.txt`. Taken with
`git --no-pager -C /home/victor/IntelligenceRegulation diff 4751b93^ 4751b93 -- <path>`.

## The gates re-run

The three committed records were regenerated with the commands their own
READMEs give, after the pin moved and before anything was claimed. The
`diff_*.txt` files are the leaf-by-leaf comparisons of the committed bytes
with the refreshed ones, made with
`results/zk60_native_gate_record_refresh/jsondiff.py`. To redo one, take
the committed bytes back out of git — e.g.

```
git --no-pager -C /home/victor/wt-zk60-jointview show \
  556822c:results/zk60_native_privacy_gate/privacy_gate.json > /tmp/before.json
python3 results/zk60_native_gate_record_refresh/jsondiff.py \
  /tmp/before.json results/zk60_native_privacy_gate/privacy_gate.json
```

(`556822c` is the commit before the refresh; nothing was deleted, so the
old bytes of all three records stay in git history.)

| record | log / marker | seconds | differing leaves |
|---|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | `gate_p10.log`, `.done` = 0 | 221.8 (was 249.1) | **26**: `seconds`, `tool_sha256/zk60_native_mask_commit.py`, and the six keys the re-pin record adds under `masking_commitment_M_opening/source_pins/hashline/src/zk.rs` on each of the four captures |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | `gate_channels.log`, `.done` = 0 | 222.9 (was 267.7) | the same 26 |
| `results/zk60_native_joint_view/joint_view.json` | `joint_view.log` | 21.6 (was 23.5) | **4**: two wall clocks, `seconds`, and the same tool hash |

**No figure of record moved.** Both P10 records still read four captures
`ok`, 28 channels, **11 constructed / 2 derived / 8 argued / 7 open** on
every capture, 10 control names all firing, receipts 2,816,472 (block) and
2,245,800 (attention) bytes, `privacy_property_established: false`.

`suite_after.log`, `.done` — the whole `test_zk60_native*.py` set
afterwards.
