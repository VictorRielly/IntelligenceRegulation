| # | forgery | predicted | actual (verifier's refusal, first 150 chars) | verdict |
|---|---|---|---|---|
| R2-1 | (#1, second row) e on the padded entry V + 3, tok = V + 3, M = max + 1 | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17d | y outside int8 (hot Cn) with in-window remainders | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| R2-2 | (#2, second row) non-maximal j >= 4096, M = max + 1, deltas in bytes (A6-only) | [OutSlot(7)] | stage OUT slot 07 [OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 13 | tie broken the wrong way (higher id chosen) | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| R2-3 | (#12b, second row) non-maximal j >= 4096, M = l_j, delta field values in a non-byte 7th limb | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 4 | tok_0 = BOS + 1, h_q(0) = 0, row 0 arbitrary (the CHECK2 N-1 forgery) | [InSlot(1)] | stage IN slot 01 [IN-01 query zero-check: LogUp + BOS (own mu_bos) + pad, fresh mu each]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17a | final norm: y off by one (rho, sigma re-derived) | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 23 | a verifier configured with another embedding word | [Binding] | token I/O wire: this segment belongs to another run | AS PREDICTED |
| 23 | a verifier configured with another head word | [Binding] | token I/O wire: this segment belongs to another run | AS PREDICTED |
| 23 | a verifier configured with another head multiplier | [Binding] | token I/O wire: this segment belongs to another run | AS PREDICTED |
| 23d | BOS = V | [the token-I/O door] | token I/O: the BOS constant 300 is outside its class [0, V) with V = 300 (CHECK2 N-2) | AS PREDICTED |
| 23d | BOS = 128000 under V = 300 | [the token-I/O door] | token I/O: the BOS constant 128000 is outside its class [0, V) with V = 300 (CHECK2 N-2) | AS PREDICTED |
| 23d | g0 = 128 | [the token-I/O door] | token I/O: the final norm's uniform gain g0 = 128 is outside its class [1, 127] | AS PREDICTED |
| 23d | g0 = 0 | [the token-I/O door] | token I/O: the final norm's uniform gain g0 = 0 is outside its class [1, 127] | AS PREDICTED |
| 23d | Cn = 2^20 + 1 | [the token-I/O door] | token I/O: the final norm's Cn = 1048577 is outside its class [1, 2^20] | AS PREDICTED |
| 23d | Ceps = 0 | [the token-I/O door] | token I/O: the final norm's Ceps = 0 is outside its class [1, 2^40] | AS PREDICTED |
| 23d | Ceps = 2^40 + 1 | [the token-I/O door] | token I/O: the final norm's Ceps = 1099511627777 is outside its class [1, 2^40] | AS PREDICTED |
| 23d | tn = 10 (window 31, not 32) | [the token-I/O door] | token I/O: the final norm's remainder window tn + 1 + bits(D_max) = 31 bits; this rung's plane list is pinned at exactly | AS PREDICTED |
| 23d | tn = 12 (window 33) | [the token-I/O door] | token I/O: the final norm's remainder window tn + 1 + bits(D_max) = 33 bits; this rung's plane list is pinned at exactly | AS PREDICTED |
| 23d | a head multiplier 0 | [the token-I/O door] | token I/O: head row 0's multiplier 0 is outside its declared class [1, 2^12] (D25 T4 as amended) | AS PREDICTED |
| 23d | a head multiplier 2^12 + 1 | [the token-I/O door] | token I/O: head row 0's multiplier 4097 is outside its declared class [1, 2^12] (D25 T4 as amended) | AS PREDICTED |
| 22 | the receipt re-read under variant P-selector-sealed-in-input | [Door] | token I/O run: the P-selector-sealed-in-input variant is not built (D26's two-site endpoint is the next rung; review TR-3) | AS PREDICTED |
| 22 | the receipt re-read under variant F-selector-sealed-in-output | [Door] | token I/O run: the F-selector-sealed-in-output variant is not built (D26's two-site endpoint is the next rung; review TR-3) | AS PREDICTED |
| 20 | (public-row analogue) segments out of order | [the run's counted segment geometry] | token I/O wire: segment 0 is 7421464 B, the counted length is 1224328 | AS PREDICTED |
| 21 | (public-row analogue) endpoint declared with another row count | [the derived geometry] | token I/O wire: segment 0 is 1224328 B, the counted length is 1226376 | AS PREDICTED |
| 6 #8 #19 | hidden-length variant (SBOOL, IO-s, the sealed selector) | - | not applicable to the public-row rung R1 (D26's two-site endpoint is the next rung) | N/A at R1 |
| R2-4 | (#15, second row) a delta limb that is not a byte at an entry >= 4096 (same delta value) | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 5 | tok_0 != BOS, otherwise honest | [InSlot(1)] | stage IN slot 01 [IN-01 query zero-check: LogUp + BOS (own mu_bos) + pad, fresh mu each]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17b+ | final norm: D off by one (isqrt relations kept in the field) | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 1 | e on a padded vocabulary entry, tok = V, M = max + 1 | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| R2-5 | a nonzero delta limb on the padded entry V + 7 (second row) | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 7 | consistent re-lookup in A_in (tok, row, histogram) under the honest seal | [InSlot(0)] | stage IN slot 00 [IN-00 IO-in: token endpoint = supp_T tok (whole padded plane)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17b- | final norm: D off by one (isqrt relations kept in the field) | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 2 | non-maximal j, M = max + 1, deltas in bytes (A6-only) | [OutSlot(7)] | stage OUT slot 07 [OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 10a | nonzero pad word in the input token endpoint | [InSlot(0)] | stage IN slot 00 [IN-00 IO-in: token endpoint = supp_T tok (whole padded plane)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| R2-6 | stage IN histogram: one count moved from a second-row id to its first-row twin (tok, rows honest) | [InLogUp] | stage IN H (the LogUp sum claim is part of this opening): pcs zk: group 3: <v, c> != combined claim | AS PREDICTED |
| 17c-i | D16 half-p alias of D, limbs honest | [OutSlot(2)] | stage OUT slot 02 [OUT-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 16a | wrong embedding row | [InLogUp] | stage IN H (the LogUp sum claim is part of this opening): pcs zk: group 3: <v, c> != combined claim | AS PREDICTED |
| 3 | e, delta honest; tok' = j + 1, M = l_j + 2^-v (A3-only) | [OutSlot(7)] | stage OUT slot 07 [OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| R2-7 | (#16c, second row) padded token id V + 11, histogram on that pad entry | [InSlot(2)] | stage IN slot 02 [IN-02 table zero-check: h_tab (alpha - tau) = m + pad, fresh mu each]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17c-ii | D16 half-p alias reconstructed by its limbs, relations kept | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 16b | one changed word of an embedded row | [InLogUp] | stage IN H (the LogUp sum claim is part of this opening): pcs zk: group 3: <v, c> != combined claim | AS PREDICTED |
| 11b | wrong output token: A_out tok and endpoint another id, M unchanged | [OutSlot(7), OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 17e | x int16 limbs off by one (xl1 + 1) | [OutSlot(5)] | stage OUT slot 05 [OUT-05 DZC final-norm quotient + x limbs + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 16c | padded token id V, histogram on the pad | [InSlot(2)] | stage IN slot 02 [IN-02 table zero-check: h_tab (alpha - tau) = m + pad, fresh mu each]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 9 | output plane seals another id (A_out honest) | [OutSlot(10)] | stage OUT slot 10 [OUT-10 IO-out: output endpoint = u0 tok (whole 256-word plane)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 16c2 | padded token id V, histogram unchanged | [InLogUp] | stage IN H (the LogUp sum claim is part of this opening): pcs zk: group 3: <v, c> != combined claim | AS PREDICTED |
| 10b | nonzero pad word in the output token endpoint | [OutSlot(10)] | stage OUT slot 10 [OUT-10 IO-out: output endpoint = u0 tok (whole 256-word plane)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 16d | histogram off by one | [InLogUp] | stage IN H (the LogUp sum claim is part of this opening): pcs zk: group 3: <v, c> != combined claim | AS PREDICTED |
| 12a | non-maximal token, M = l_j, delta field values truncated to bytes | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 12b | non-maximal token, M = l_j, delta field values in a non-byte top limb | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 14a | two-hot selector | [OutSlot(6), OutSlot(7)] | stage OUT slot 07 [OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 14b | fractional selector (1/2, 1/2) | [OutSlot(6)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 14c | selector (2, -1) | [OutSlot(6), OutSlot(7)] | stage OUT slot 06 [OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
| 15 | a delta limb that is not a byte (same delta value) | [OutLogUp] | stage OUT H (the LogUp sum claim is part of this opening): pcs zk: group 5: <v, c> != combined claim | AS PREDICTED |
| 18 | public row: stage OUT computes from row T - 2 | [OutSlot(0)] | stage OUT slot 00 [OUT-00 IO-in: x = B_out row T-1 (fixed public row bits)]: sumcheck round 0: s(0) + s(1) != claim | AS PREDICTED |
