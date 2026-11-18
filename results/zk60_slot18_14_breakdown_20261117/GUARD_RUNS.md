# Guarded Runs Ledger — `zk60_slot18_14_breakdown_20261117`

All 15 measurement leaves executed under `scripts/zk60_resource_guard.py` at the default `5.0 s` poll interval (`enforce=watchdog-only`), with `PYTHONDONTWRITEBYTECODE=1`, `>= 13 s` inter-leaf gaps, `test ! -e /tmp/HOLD`, and `pgrep -f ds4-bench` verified `none` both before and after every leaf.

Reference binary (unmodified `BIN_U`, pre-A33 `a6eee4b0`):
- `ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7`

Externalized raw hardware GPU trace archive (`> 1 MiB` rule respected; `0` files `> 1 MiB` in `results/zk60_slot18_14_breakdown_20261117/`):
- `/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/` (`9` `.tsv.gz` files: 6 from 3-arm breakdown + 3 from knob probe)

| # | Guard Run ID | Label | Class | Need / Cap | Exit | Child Wall | Peak RSS | Peak VRAM | Min Avail | `ds4-bench` (pre / post) |
|---:|---|---|---|---|---:|---:|---:|---:|---:|---|
| 1 | `2d4710ba8038` | `agy-census_r13_8b` | `cpu` | `4G / 12G` | `0` | `0s` | `0.00G` | — | `210.59G` | `none / none` |
| 2 | `ee02f205e155` | `agy-census_r13_shield` | `cpu` | `4G / 12G` | `0` | `0s` | `0.00G` | — | `210.99G` | `none / none` |
| 3 | `a617c8f27be1` | `agy-w16r2_8b_armA_prod_batched` | `gpu` | `12G / 24G` | `0` | `6s` | `4.16G` | `6143 MiB` | `203.37G` | `none / none` |
| 4 | `ac256eb6f0df` | `agy-w16r2_8b_armB_unbatched_sync_lin1` | `gpu` | `12G / 24G` | `0` | `6s` | `4.34G` | `6135 MiB` | `203.37G` | `none / none` |
| 5 | `58a32b6e2495` | `agy-w16r2_8b_armC_unbatched_sync_lin0` | `gpu` | `12G / 24G` | `0` | `8s` | `4.25G` | `6262 MiB` | `203.09G` | `none / none` |
| 6 | `8aa8f9249888` | `agy-r13_shield_armA_prod_batched` | `gpu` | `12G / 24G` | `0` | `11s` | `8.58G` | `12249 MiB` | `196.22G` | `none / none` |
| 7 | `719b70075309` | `agy-r13_shield_armB_unbatched_sync_lin1` | `gpu` | `12G / 24G` | `0` | `11s` | `7.70G` | `12252 MiB` | `196.50G` | `none / none` |
| 8 | `0c1520605e64` | `agy-r13_shield_armC_unbatched_sync_lin0` | `gpu` | `12G / 24G` | `0` | `21s` | `8.58G` | `12998 MiB` | `195.55G` | `none / none` |
| 9 | `9f624c870f68` | `agy-w16r2_8b_knob_tail250` | `gpu` | `12G / 24G` | `0` | `7s` | `3.86G` | `6136 MiB` | `203.48G` | `none / none` |
| 10 | `9c1069bcc259` | `agy-w16r2_8b_knob_tail500` | `gpu` | `12G / 24G` | `0` | `6s` | `3.86G` | `6136 MiB` | `203.36G` | `none / none` |
| 11 | `380108594ac1` | `agy-w16r2_8b_knob_tg256_th18` | `gpu` | `12G / 24G` | `0` | `6s` | `4.17G` | `6118 MiB` | `203.49G` | `none / none` |
| 12 | `1e88204d23b8` | `agy-serve4_1A_default25` | `gpu` | `40G / 52G` | `0` | `127s` | `32.40G` | `25750 MiB` | `164.15G` | `none / none` |
| 13 | `5d310ce2a734` | `agy-serve4_2B_tail250` | `gpu` | `40G / 52G` | `0` | `130s` | `31.71G` | `23816 MiB` | `164.18G` | `none / none` |
| 14 | `be70535655fa` | `agy-serve4_3A_default25` | `gpu` | `40G / 52G` | `0` | `132s` | `31.81G` | `23098 MiB` | `164.75G` | `none / none` |
| 15 | `abf5459bac88` | `agy-serve4_4B_tail250` | `gpu` | `40G / 52G` | `0` | `131s` | `31.85G` | `23445 MiB` | `164.85G` | `none / none` |
