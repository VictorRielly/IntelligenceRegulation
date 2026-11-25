# A21. A restricted head fits the existing row width, but grows the opening

At the Shieldstral 3B T128 R13 public-row profile, 16 registered label
IDs need 15 differences. The packed estimate keeps the
4,096-column stage and uses only 107 addressed positions of the
existing limb row. It still adds 28 A mask rows and 28 M rows. The
estimated OUT-C frame grows by **1,098,720 bytes**. So A18's
no-row-growth and under-1-MB condition does not hold at 16 labels
with a separate private dot-product slot per difference. No
vocabulary-wide plane is needed in either estimate.

## Baseline correction

The actual R13 OUT-C frame is **3,292,120 bytes** in all three retained
public records [MEASURED]. A18's 7,161,056 B number is a **generator
draw-byte count**, not the frame length. It comes from the G-R4 seeded
replay. The stage counter independently reconstructs the recorded
3,292,120 bytes, including the carried boundary opening. This is not a
stage measurement for the installed W16R2 profile.
[Retained record](../../../results/zk60_astra_20261026/a3_classifier_native_20261105/public-evidence/hate-record.json) ·
[R13 geometry check](../../../results/zk60_sol_20261105_w16r3/b3/SHIELD_CLASSIFIER_SCOPE_495.md) ·
[G-R4 draw count](../../../docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md#L476)

## What the counter says

Both estimates are **Shieldstral 3B T128 R13 public-row**, one output
position, 3,072 hidden values padded to 4,096. The baseline is reconstructed
from OUT-C's eight native slots and checked against the retained frame.
Counts above two labels are **derived design estimates**. A/H elements
are pre-encoding committed message cells, including reserved rows,
as defined by the design counter. M rows are reported separately.
[Counter](../../../results/zk60_token_io_design_20261017/token_io_count.py) ·
[Reproducible model](20261125-apps-restricted-head.py)

| Layout | Labels | A / H / M rows | A + H elements | OUT-C frame | Added bytes |
|---|---:|---:|---:|---:|---:|
| Existing margin | 2 | 76 / 38 / 20 | 466,944 | 3,292,120 | 0 |
| Packed bank | 4 | 80 / 38 / 24 | 483,328 | 3,449,080 | 156,960 |
| Packed bank | 8 | 88 / 38 / 32 | 516,096 | 3,763,000 | 470,880 |
| Packed bank | 16 | 104 / 38 / 48 | 581,632 | 4,390,840 | 1,098,720 |
| Separate limbs | 4 | 86 / 46 / 28 | 540,672 | 3,766,648 | 474,528 |
| Separate limbs | 8 | 106 / 62 / 44 | 688,128 | 4,715,704 | 1,423,584 |
| Separate limbs | 16 | 146 / 94 / 76 | 983,040 | 6,613,816 | 3,321,696 |

The current class allows five byte limbs per margin and starts the
margin limbs at offset 32. Packing a bank gives extent
(32 + 15 cdot 5 = 107) at 16 labels. The **packed estimate** keeps the
same A limb row and existing H helper pair. It charges each additional
dot-product slot its own A pair, A opening group and two M rows. It
requires a redesigned host that checks the bank against the separate
private sums. The **separate estimate** repeats the current limb and
helper layouts for each extra difference. It budgets an extra host
slot, one A data row, one H data pair, and their claim pairs and groups.
Neither estimate assumes that fresh claim points can be merged.
[Native OUT-C slots](../../../results/zk60_sol_20261105_w16r3/b3/source-d26-sealed-statement541/hashline/src/private_block/token_io/stage_out_c.rs) ·
[Margin window](../../../results/zk60_sol_20261105_w16r3/b3/source-d26-sealed-statement541/hashline/src/private_block/token_io/classify.rs#L671)

## Decision test

If this work proceeds, use the packed bank as the first layout to
check. Pin the public label IDs, a common quantized score scale and
offsets, and an exact tie rule. The relation would prove that one
registered score beats the other registered scores for the hidden
input. It would not prove human authorship, an unrestricted vocabulary
argmax, or a multi-token generation chain.

Before timing, prototype the 16-label layout locally and compare the
emitted frame geometry with the 104 / 38 / 48 row estimate. Require
the host to reject a changed comparison or wrong tie break, verify
the new challenge and hash-input shape checks, and confirm the
4,096-column limb bank. The counter does not prove the new host
equations, zero knowledge, refusal or calibration behavior, timings,
or installed-profile bytes. The 1 MB target is already missed in both
counted layouts at 16. Meeting it would require a different opening
or sumcheck schedule.
