# `results/zk60_native_privacy_gate_channels/` — the OPEN-channel lane's evidence

Produced on branch `zk60-native-jointview`, 2026-09-20, by the lane recorded
in `docs/zkmatrix-poc/ZK60_NATIVE_GATE_CHANNELS_PROGRESS.md` and reported in
section 14 of `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`. **Nothing here
is a privacy acceptance and nothing here establishes a privacy property.**

> **2026-09-20, later: `privacy_gate.json` was REGENERATED here too, and
> not one channel moved.** The run that wrote it finished at 05:01 and the
> pad-budget guard moved into `scripts/zk60_native_jv_cfs.py` at 05:02,
> inside the same commit, so the record's `tool_sha256` named tool bytes
> that no longer existed — the only key in which it was behind. Re-running
> the documented command reproduced it exactly: **267.7 s, four captures
> `ok`, marker `0`**
> (`results/zk60_native_gate_record_refresh/gate_refresh_channels.log`), and
> the new file differs from the pre-refresh one in `seconds` and that one
> hash and in nothing else. `gate_with_M.log` below is the original 221.8 s
> run of `d360466`. **No number quoted in any report changed.**

> **2026-09-22 (round 9e): `privacy_gate.json` was RE-TAKEN, and only the
> clock and three tool digests moved.** The toy gate's manifest cross-check
> was fixed — it used to skip itself silently on a bundle whose manifest is
> named `capture-validation.json` or whose `accepted` is one record, and it
> now refuses by name — so the bytes of `zk60_native_jv_capture.py` and of
> the two gates that list it changed, and every record naming them had to be
> re-taken. The documented command reproduced this record leaf for leaf apart
> from those three `tool_sha256` entries and `seconds` (233.8 s → **222.1 s**,
> four captures `ok`, marker `0`); the manifest block is **identical**. The
> comparison is `results/zk60_native_manifest_check_20260922/repin_diff.txt`,
> the reason is in `results/zk60_native_gate_record_refresh/README.md`, and
> the reading is §8.7 of
> `docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md`. **No number quoted in
> any report changed.**

> **2026-09-22 (round 9f): `privacy_gate.json` was RE-TAKEN again, and only
> the clock and two tool digests moved — one of them new.** Finding P36-2 of
> the stage-36 pre-read: `zkp-core/Cargo.toml` (the `test-observers` feature
> must stay out of `default`) and `hashline/Cargo.toml` (it must stay in
> `[dev-dependencies]`) decide whether the read-only test observers can
> compile into a release build, and **nothing pinned either file**. Both are
> now pinned at main's `4751b93` bytes in the new
> `scripts/zk60_native_manifest_pins.py`, with a CONTENT assertion beside the
> digest, and this gate calls the check before it reads anything and exits 3
> on a refusal. The documented command reproduced this record leaf for leaf
> apart from `tool_sha256/zk60_native_privacy_gate.py`, the NEW
> `tool_sha256/zk60_native_manifest_pins.py` leaf and `seconds` (222.1 s →
> **221.3 s**, four captures `ok`, marker `0`): **3 differing leaves, 0
> unexpected**. The comparison is
> `results/zk60_native_manifest_pins_20260922/repin_diff.txt`, the reason is
> in `results/zk60_native_gate_record_refresh/README.md`, and the reading is
> §8.8 of `docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md`. **No number
> quoted in any report changed.**

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
