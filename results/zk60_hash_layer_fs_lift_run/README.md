# `zk60_hash_layer_fs_lift_run` — evidence for the run's hash layer and FS lift

Written for `docs/zkmatrix-poc/ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` by a
delegated Opus drafter, 2026-09-21, for the security owner.
Lane read (read-only): `/home/victor/wt-zk60-block125m` at **`8c5922b`**.

**Nothing here was built, proved, verified or benchmarked.** No witness, no
salt, no private plane and no receipt byte is read by either file. Both are
pure arithmetic over geometry constants quoted from named source lines, plus
one read of already-existing capture bundles' PUBLIC tag fields.

## Files

| file | what it is |
|---|---|
| `run_hash_counts.py` | the counting script: seven controls that reproduce already-published figures, then the new counts for the run's hash layer at three configurations |
| `run_hash_counts.json` | its output (`python3 run_hash_counts.py > run_hash_counts.json`) |
| `tag_identity_check.txt` | the output of the one data check: finding F-1, that a run segment's 32-byte END tag equals the next segment's START tag, on all ten run-capture bundles the lane holds |

## How to reproduce

```
python3 /home/victor/IntelligenceRegulation/results/zk60_hash_layer_fs_lift_run/run_hash_counts.py
```

Under a second, no dependencies. The `tag_identity_check.txt` check reads
`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-*/stage-*.json`
and only their `start_tag` / `end_tag` members, which are public transcript
positions the verifier re-derives.

## The controls, and why they are first

The project's discipline is that a counting method reproduces published
figures before it computes new ones. All seven pass exactly:

| control | reproduces | source |
|---|---|---|
| C1 | the toy's 12,288 salts, `sum L_s = 583`, **327,052** `fp()` draws and 2^-77.7 | decision D9; `ZK60_HASH_LAYER_AND_FS_LIFT.md` sections 1.1 and 5.1 |
| C2 | the toy's tree tables 240.7 / 453.2 / 212.5 / 1,200.6 / 1,654.8 / 40.4 % and the `M` row 248.2 / 481.4 / 233.2 / 1,653.8 / 2,136.2 / 26.1 % | `ZK60_D8_D11_RESTATEMENT.md` section 3.3; `ZK60_HASH_LAYER_AND_FS_LIFT.md` section 1.2 |
| C3 | 686,990 / 8,704 / 7,424 and 2,093,226 (rung-G); 9,029,742 / 108,032 / 91,392 and **109,728,040** and 2^-69.3 (125M); `sum L_s = 1,208` | `ZK60_JOINT_LAW_COMPOSITION_RUN.md` section 6.1 |
| C4 | **2,473,984** salts for a twelve-block 125M run | same memo, section 3.5 |
| C5 | **3,328** opened columns of a three-block run | `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md`, round 3 |
| C6 | 2^-118.4 per block and 2^-114.8 for a twelve-block run | `ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md` ruling S-4 |
| C7 | the run gate's MEASURED `final_counter` on five bundles, from `challenges_checked + 64 (4L+1)`: 6,918 / 6,924 / 6,924 / 7,686 / 7,686 | `/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_*/`, field `stage2_transcript_replay` |

C3's figures are reproduced with the **pre-repair** slot schedule, which is
what that memo counted. At `8c5922b` the stage-20 S19-F1 repair has landed
and the draw counts are 38 (rung-G) and 62 (125M) per block higher; the
script reports both and the memo says so.

## What the script does not do

It does not count the 23 slots' per-slot **definition** draws (`tau`, `mu`,
`nu`, `zeta`, `r_*` in `argument.rs`), so its squeeze figure is a **lower
bound**. Where the gate has measured the live squeeze counter the script uses
that instead (rung-G L = 3: 6,924; rung-K4 L = 3: 7,686), and the difference —
978 and 987 over three stages — is exactly the definition draws. At the 125M
shape nothing is measured and the script uses an explicit bound of 1,024
definition draws per stage. Every term that number enters is 2^-110 or
smaller.

It proves nothing. It evaluates the formulas the memo derives.
