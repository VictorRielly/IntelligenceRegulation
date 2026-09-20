# `results/zk60_native_privacy_gate_channels/` — the OPEN-channel lane's evidence

Produced on branch `zk60-native-jointview`, 2026-09-20, by the lane recorded
in `docs/zkmatrix-poc/ZK60_NATIVE_GATE_CHANNELS_PROGRESS.md` and reported in
section 14 of `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`. **Nothing here
is a privacy acceptance and nothing here establishes a privacy property.**

| file | what it is |
|---|---|
| `privacy_gate.json` | the P10 gate's record AFTER the masking commitment M was ported: 28 channels, **11 CONSTRUCTED / 2 DERIVED / 8 ARGUED / 7 OPEN** on every one of the four captures, with M's own stage (`masking_commitment_M_opening`) and M's three controls |
| `gate_baseline.log`, `.done` | the same gate BEFORE the port: 8/2/8/10, 192.7 s, exit 0. The baseline `privacy_gate.json` it wrote is the version committed one commit earlier in this lane |
| `gate_with_M.log`, `.done` | the run that produced the current `privacy_gate.json`: 221.8 s, exit 0 |
| `tests_baseline.log`, `.done` | the suite before the lane: **139 tests, 185.1 s, OK** (1 skip, 1 expected failure) |
| `tests_mask_only.log`, `.done` | `tests/test_zk60_native_mask_commit.py` alone: **21 tests, 40.5 s, OK** |
| `tests_after.log`, `.done` | the suite after the lane: **161 tests, 213.1 s, OK** (1 skip, 1 expected failure) |
| `regen_groups.log`, `.done` | the small-model-groups record regenerated after the pad-budget guard moved into the base class (0.6 s) |
| `regen_jointview.log`, `.done` | the FIRST joint-view regeneration, which **failed**: the new base-class guard refused `group_pad_freedom`'s call on the deliberately out-of-budget case. Kept deliberately — the guard caught a real caller on its first run |
| `regen_jointview2.log`, `.done` | the joint-view record regenerated after that caller moved to the unguarded entry point: 23.5 s, every stage ok |

Reproduce (about 222 s on the WSL box, single core, no GPU and no build):

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
```

**What the record contains.** Counts, dimensions, ranks, indices, booleans,
digests and challenge-derived field elements. The blinding this lane exhibits
for M — 256 pads per a-row, the two b rows, the two u rows — is recorded as a
sha256, not as values; it is prover randomness the tool CONSTRUCTS, not
anything read from a capture. The coefficient vectors are generated from a
published seed and are not witnesses. It contains no witness value, no mask
coefficient of the real prover, no salt and no private plane.
