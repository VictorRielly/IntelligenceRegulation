# U-PERF3 round 9 — the committed-h encoding (the F1 full-mode price, re-derived)

Status 2026-09-01: design memo, orchestrator (lane II-style). The
F1 ruling (2026-08-31) adopted FULL MODE and named the committed-h
encoding as the price of admission. This memo's finding: **the
price was an artifact of the prototype's layout, not a property of
full mode** — the v3 statement already commits h in the right
form, and the expensive objects (the act-h group, the width
planes) both dissolve under a routing change. The verification
rungs are listed; nothing here is built yet.

## 0. The answer in one paragraph

Lane GG's full-mode prototype was built on the v2-era pass layout,
where h exists only as the 15-bit accumulator H and the int8 h8 —
so the aggregate's range facts over h needed FRESH commitments: the
act-h group (+6.29M rings at 12x128, 2x the act group, the measured
OOM driver; +25.2M rings at 12x512) and the width planes (+4.5M —
GG's R1 finding that "committed limbs cannot close the off-table
gap" FOR THE BOOLEANITY-ZC FORM). But the PoC statement going
forward is MM's COMPOSED V3, whose entry list already commits
h16's limbs (Hlo, Hhi — 8-bit planes, entries 13/14, consumed by
the limb-split down matmul) and the requant objects (H, Rh). Full
mode on v3 should therefore route h's range facts through LOOKUPS
over the EXISTING commitments (the S2 LogUp machinery — measured
GO, claims bit-identical, no width planes needed) instead of
booleanity zero-checks over fresh bit planes. The act-h group and
the width planes both vanish; the marginal full-mode bill becomes
the lookup instances' helper/multiplicity objects plus sub-1M-ring
limb splits for the remainder columns.

## 1. The three candidates, counted at 12x512 [derived from GG's R1 rows + the v3 entry list]

| candidate | new commitments | rings at 12x512 | notes |
|---|---|---:|---|
| C0: GG as-built (naive act-h bit planes + width planes, zc-booleanity route) | act-h group + width planes | **+29.7M** | measured: 12x128 full OOM at 14.8 GiB |
| C1: coarser l0_q on the act-h group | act-h at fewer/wider limbs | ~+12-18M [MODEL] | still a fresh group; strictly dominated by C2 |
| **C2: v3-routed lookups (RECOMMENDED)** | NONE for h16 (Hlo/Hhi exist); Rh limb split +~0.2M rings; per-instance LogUp helper + multiplicities | **~+1-3M class [MODEL, rung V2 counts it]** | h16 range = 256-row identity lookups over Hlo and Hhi; Rh range = a 2^sh-row lookup or its own 2-limb split + 256-row lookups |

The C2 helper caveat, stated honestly: the LogUp helper column
h_i = 1/(alpha - key_i) is K-FIELD-valued and alpha-dependent (a
mid-transcript commitment wave — the F2/MM precedent makes that
ordering routine now). Its commit bill was inside S2's measured-GO
walls at 2^20 but has NO precise counted row at 12x512/8B — that
count is verification rung V2, and it is the only object that
could materially move the C2 total.

## 2. What this does to the owed 8B full-mode recount

On lane OO's new baseline (commit ~61 GB, pass peak lvl-0 ~72 GB,
~56 GB margin — range-form counts): under C2, full mode adds ~zero
commit-phase weight (the h limbs are already in the act group's
bill) + the helper/multiplicity objects [MODEL pending V2] + the
remainder limb planes (~1-2 GB class at 8B). **The full-mode 8B
peak plausibly REMAINS at lvl-0 ~72 GB** — i.e., the F1 ruling
costs approximately nothing in memory IF C2 verifies. Under C0 it
would have cost the ~130-160 GB class. This memo therefore
supersedes the rulings block's first estimate.

## 3. Verification rungs (round 10; each small)

- **V1**: wire ONE h16 range fact as a 256-row lookup over the
  existing Hlo commitment in the full-mode aggregate path;
  differential vs the E5/table form. (The load-bearing rung.)
- **V2**: the helper/multiplicity commit bill, counted precisely
  from the S2 structures at 12x512 and the 8B shapes — the only
  open number in §1.
- **V3**: all h + remainder facts routed; re-run `uperf-a pass 12
  128 full` — the acceptance is that it NO LONGER OOMs the 15 GiB
  box and the peak lands near range-mode's.
- **V4**: the 8B full-mode counted row on OO's baseline (closes
  the owed recount).

## 4. Honesty

Nothing here is measured yet except the C0 baseline (GG's) and
S2's 2^20 GO; C2's totals are [MODEL] until V1-V4. The width-plane
dissolution assumes the off-table gap is closed by the LOOKUP form
(it is, by construction — the table IS the range) — GG's contrary
finding applied to the booleanity-zc form only. If V2 finds the
K-field helper bill dominant, the fallback is C1 with the helper
shared across instances (the S2 aggregate form), counted then.
