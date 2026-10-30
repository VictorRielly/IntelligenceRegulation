#!/usr/bin/env python3
"""Gate round 19 [COUNTED]: the D34 / D40 input-dependent LogUp refusal term recounted at the R13 stack
(REVIEW_R16 §10 item 5), and the list of refusals that depend on hidden content.

THE TERM (D34, recounted for classifiers by D40). A LogUp argument inverts denominators alpha - q. Where the
SET of q values the prover inverts depends on hidden data and nothing is drawn or absorbed between the challenge
and the inversions, whether some alpha - q = 0 (a refusal) is an event whose probability can differ between two
hidden inputs. It is priced as a two-world distance 2 * (number of distinct possible hidden-dependent
denominators) / p^2 (the challenges are F_p^2). Per block the distinct values a hidden query can take are the
rows of the tables it is looked up in [READ native R13 argument_accuracy.rs / accuracy_act.rs / protocol.rs at
r16b; REVIEW_R13 §4 / §6]:
  * U8: 256 (every byte limb and every exact top-bit pin of R13's widened words and remainders queries the same
    256-row byte table, accuracy_layout.rs `lookups`);
  * EXP: 256 (the softmax exp member's table);
  * ACT3: 4096 * groups rows (the tuple (g + 2048, a_scaled, gid) table, accuracy_act.rs `table`; legacy: 256);
  so T_d = 512 + 4096 * groups per block (REVIEW_R13's T_d, groups charged at the class maximum 4); DD absent
  (no DD classifier profile is registered, N-r16-6).
Stage IN-C inverts at most T distinct tau rows (the item's own ids, template and pad ids included: a public id
only adds a challenge-only denominator), stage OUT-C at most 256 byte values (the margin limbs and the final
norm's limbs). The PAD ROWS add no distinct value: in IN-C a pad position's query is pinned to the public pad
id; in the blocks the pad rows are ordinary hidden rows whose queries fall in the same tables (the count is over
table rows, not positions). The table-side inversions (alpha - table[i]) are of public values: challenge-only.
"""
import json, math, os
P = (1 << 64) - (1 << 32) + 1
LP2 = 2 * math.log2(P)
EX = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128"


def term(blocks_td, t):
    n = 2 * (sum(blocks_td) + t + 256)
    return {"count": n, "log2": round(math.log2(n) - LP2, 3)}


groups = []
for k in range(26):
    m = json.load(open(f"{EX}/layer_{k:02d}/manifest.json"))
    groups.append(m.get("arrays", m)["silu_groups"]["shape"][0])
out = {"what": "the D34 / D40 input-dependent LogUp refusal term at the R13 stack [COUNTED]; not a privacy acceptance",
       "formula": "2 * (sum over blocks of T_d + T + 256) / p^2, T_d = 256 (U8) + 256 (EXP) + 4096 * groups (ACT3); "
                  "legacy T_d = 768 (three 256-row tables)",
       "shieldstral_groups_per_layer_READ": groups,
       "rows": {}}
for name, t in (("shieldstral-3b-t128-r13 (L 26)", 128), ("shieldstral-3b-t256-r13 (L 26)", 256)):
    out["rows"][name] = {"class_max_4_groups": term([512 + 4096 * 4] * 26, t),
                         "actual_groups_of_the_T128_export": term([512 + 4096 * g for g in groups], t),
                         "legacy_768_per_block_for_comparison": term([768] * 26, t)}
out["rows"]["D40 as accepted (legacy shape, L 26, T <= 512)"] = term([768] * 26, 512)
for l in (1, 2):
    out["rows"][f"R13 h24 dev rung (L {l}, T 32, 4 groups)"] = term([512 + 4096 * 4] * l, 32)
out["statement_figure"] = out["rows"]["shieldstral-3b-t128-r13 (L 26)"]["class_max_4_groups"]
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "R19_REFUSAL_RECOUNT.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
