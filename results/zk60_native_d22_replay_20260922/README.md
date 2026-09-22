# `results/zk60_native_d22_replay_20260922/` — the toy joint gate replayed on the integrator's new-tree capture

Round 9d, 2026-09-22, lane `zk60-native-jointview`. The reading is §8 of
`docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md` and the ledger section
R9d of `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`; this directory
holds what those were computed from. **Nothing here is a privacy acceptance
and nothing here establishes a privacy property.** It is one bundle at one
toy profile on the CPU path.

## The input, which is NOT committed here

`/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922/`
in the MAIN tree, uncommitted, the integrator's. Read-only for this lane;
nothing in it was written, renamed or staged. Its digests, so a later session
can tell whether the files changed:

| file | bytes | sha256 |
|---|---|---|
| `captures/10b9d4be….json` | 9,251,420 | `e8d3c55bb16e4784e4873fb2683841096b813ff1264e2e23fdde6f71f43dd527` |
| `captures/10b9d4be….receipt` | 2,816,472 | `10b9d4be3c0af4a44c21789a30fddd716e0d8c63948e4056c6154d3d852ce64b` |
| `captures/10b9d4be….expected` | 112 | `b491fb948141cc8df7cc11bb3f75466810d39f26e2c3a127fa5b4a7965ca73a3` |
| `capture-validation.json` | 16,239 | `ff415259047756c1634f73fe10cb8c68d2d7e908f90745ba77384cd4f5722fc4` |

`bundle/` here is a byte-identical COPY of the three capture files (the copy's
digest is re-checked against the source) plus a `validation.json` built from
the integrator's manifest; it is deliberately left untracked, because the
bundle is the integrator's artifact and this lane does not publish it.

## The files

| file | what it is |
|---|---|
| `pins_check.py`, `pins_check.txt` | T2. Every one of the 132 source hashes the bundle records, against the blob `git show 4751b93:<path>` returns from the main repository; then the D22 pin set — the union of `zk60_native_mask_commit.SOURCE_PINS + PATH_PINS` and `zk60_native_terminal_polys.SOURCE_PINS`, 32 distinct paths — file by file against the pin of record and `ALSO_ACCEPTED`; then the artifacts and the verifier binary |
| `stage_bundle.py`, `staged.json` | the copy and the one-key manifest shim, recorded key by key |
| `replay.sh`, `replay.log`, `replay.done` | T3/T4. The four runs, detached under `flock /tmp/zk-heavy.lock` inside a 4 GiB `systemd-run` scope; 10:07:23 → 10:09:49 |
| `p10_staged/`, `p10_as_delivered/` | the P10 privacy gate's records, `--columns full --controls-on all`, 62.5 s and 61.5 s, markers `0` |
| `jointview_staged/`, `jointview_as_delivered/` | the native joint-view gate's records, eight stages, 10.9 s each, markers `0` |
| `leafdiff.py`, `leafdiff_p10.txt`, `leafdiff_p10_as_delivered.txt` | T3. The A/B/N leaf diff against the record of record (see below) |
| `leafdiff_jv.py`, `leafdiff_jointview.txt` | the same for the joint-view record |
| `shim_control_p10.txt`, `shim_control_jointview.txt` | the staged run against the as-delivered run: they differ in `captures_dir`, the `manifest` block and `seconds`, and in nothing else — the shim adds no fact |
| `suite.sh`, `suite.log`, `suite.done` | T6. The toy gate's own tests and the record guard |

## Why the leaf diff is an A/B/N comparison and not a plain diff

The delivered bundle is a **different receipt** from the four of 2026-09-19,
so its challenges, digests and every challenge-derived field element are
supposed to differ — exactly as they already differ between the two block
captures of record. A plain key-by-key diff would therefore report ~100
differences and say nothing.

So, with A and B the two block captures of the record of record
(`40083e7a…`, `7d334e06…`) and N the new one:

* `receipt-specific` = the leaves where A and B already disagree;
* **`moved` = the leaves where A and B AGREE and N differs.**

`moved` is the only thing that would be news, and `moved` is **0** on the P10
record and **0** at every stage of the joint-view record.

## Reproduce

```
python3 /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/pins_check.py
python3 /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/stage_bundle.py
bash    /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/replay.sh
python3 /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/leafdiff.py \
        /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/p10_staged/privacy_gate.json
PYTHONPATH=/home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922 \
python3 /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/leafdiff_jv.py \
        /home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922/jointview_staged/joint_view.json
```

The gate commands inside `replay.sh` are the ones the records of record name
in their own READMEs, with only `--captures` and `--evidence` moved. **No gate
script was edited**; the toy gate's tools are hash-pinned by
`tests/test_zk60_native_gate_record.py` and their nine/ten `tool_sha256`
values in this round's records are identical to the record of record's.
