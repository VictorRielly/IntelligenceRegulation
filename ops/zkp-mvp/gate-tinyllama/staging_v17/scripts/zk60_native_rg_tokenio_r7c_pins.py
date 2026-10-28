#!/usr/bin/env python3
"""[GATE ROUND 7, tools v9, 2026-10-19] The source pins of a TOKEN-I/O run
capture written from the token lane's tree "uncommitted-token-io-r7c"
(`ops/zkp-mvp/token-io/hashline/`), and the reading behind each.

A token bundle pins 52 files.  Two sets cover them:

* `R7_PINS_READ_IN_V8`: the 46 pins of the gate's R7 bundles
  (`~/zk60-artifacts/tinyllama-trained-r7-capture-*`, manifest
  `source_pins`), every one checked ok by tools v8's
  `check_run_layer_pins` and readings (v6 R5b readings, v8 R7 readings).  A
  token bundle pin equal to one of these carries that reading.  At r7c, 40
  of the 52 are.
* `TOKEN_R7C_READINGS`: the 12 that are not (6 changed, 6 new).  They were
  READ by the privacy gate's reading helper on 2026-10-19 (17:46:55 UTC;
  `results/zk60_gate_tinyllama_20261017/token_io/readings/token_r7c_pin_readings.json`)
  and spot-checked by this lane:
  * shape.rs and trained_statement.rs equal native R8;
  * run.rs is native R8 + 33 token lines;
  * run_capture.rs descends from the native writer 1d43d68c, NOT from the
    gate's 31557a27 (the gate's trained-calibration capture patch is absent,
    so a token bundle's `shape` has no trained-calibration keys);
  * the token header's six absorbs are as transcribed.

The pins are matched BY FILE NAME: the token writer inserts its six files at
positions 16-21, which moves every later pin (the helper's correction 2).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

R7_PINS_READ_IN_V8 = {
    '../zkp-core/src/field.rs': 'df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13',
    '../zkp-core/src/hashtag.rs': '71bf33150a296c2ce4da49d189c6d84a9f741b9ada1ef2488711938cffd6b651',
    '../zkp-core/src/lib.rs': '388f012fbb535617bc5a105de8640c84b5572544284cb4947a4ad7606e891164',
    '../zkp-core/src/merkle.rs': '6e7817bd767a883985bfcd62b7a387d0c5f4c361010c4c5db37f5087d965744a',
    '../zkp-core/src/mle.rs': 'b20c8b75c9246471fe1cc395122558eba715f66d9efe1dc4cd5be1750f2e542e',
    '../zkp-core/src/ntt.rs': '97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890',
    '../zkp-core/src/pcs.rs': '5c9cfc4e9c84283309f4c47f87d4a9146e2c9c9f5b52aa608b4ce6a7588cd495',
    '../zkp-core/src/pcs/backend.rs': 'ff2cb5c1806b34653f8a44ad82f54201fb5d9f6ba2602afe5efeae4d104e0103',
    '../zkp-core/src/pcs/encode_buffer.rs': '3c01433d84507cddadcf5c1387c08948fd3efe853a066d74690c0a6e1ce3dd70',
    '../zkp-core/src/rng.rs': '0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb',
    '../zkp-core/src/sumcheck.rs': 'fc7374bbd5e5cc4ede62e8a21d325eb62acff9b9dcc786d12eae39efbdfdbb95',
    '../zkp-core/src/sumcheck/grouped.rs': '7777a19c8db97694c51e66c78d1a7688573158bddaa7fcb370345ebd14ab669b',
    '../zkp-core/src/sumcheck/rounds.rs': 'c60520596e6d855687e0a225850850c12bd15b8741522de69a624f0db8a003df',
    '../zkp-core/src/tables.rs': '8cc95bc8b576907a99f24755cd9d16ea8904cd9ccc514f32f471a95ca8f13e50',
    '../zkp-core/src/transcript.rs': 'cc9752d0ef9bcd6d7b20e94e611ff26748593a2ea1a4f55b63d8c221715f1967',
    'src/causal_oracle.rs': '758bd3401cc726dd621ff0b04b9d7b09a50decc773f03f4a21ddbc031921d85a',
    'src/export_v3.rs': 'e0394ab4113d150336ee91353d7ba26589d5e4dffcb3cb7d2ad0fea833842acb',
    'src/field.rs': '1dc6c53b9d3b014b8cabfb784c15dcbddde31bc58e6d7216101c6a4fbbf45669',
    'src/gpu/mod.rs': 'd651be2ccf8f19ff75fe6bca5ad42f4b773b569d0ae2017306f0bf819c51b283',
    'src/merkle.rs': '06fd5f0bd725599d601dacb1b8aac1e797914c7ca8c344c0a52a412260b47eee',
    'src/mle.rs': 'bffe83fb5636f445f3a5a3b85141c374bdfeb4e4716c386eec30d10f5ed33741',
    'src/ntt.rs': 'a7f7ac0b838747c4de59e8226213500a41c047356ddd8bcdb3ab906818843c7c',
    'src/pcs.rs': '8b14096b66f6597e3cdfe239a7359457dd17dfd475c2a5d0f4e112a41342127f',
    'src/private_block.rs': '386194fe90f01829feea20d012f4d50eabf53c1e9e2977fc2e03fbe918293587',
    'src/private_block/argument.rs': '02df55ebec4da046d5522dfc14bf17a691c1fca851f014ba50a759502804e3b5',
    'src/private_block/boundary.rs': '5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581',
    'src/private_block/endpoint_g.rs': '6e3691d0bfa1c1fb1f66b9be8ae5438597492c62dc00451d6f25dbff90ab84ce',
    'src/private_block/hash_domain.rs': 'da61c1d97ca1cd6d35071e3917cfdb900a2039c5abd213cdfe2f0ccc251ed3cd',
    'src/private_block/layout.rs': 'ee871fff7eed377cafcb05ec0438df95a70695ae8fdcd5b5822f5f40663b0ee9',
    'src/private_block/pad.rs': '4f0c11c50503dd8cb4fb38d2b5be5e4f08ec310ee916b83a357f0283ede9eb42',
    'src/private_block/plane_index.rs': '13a7dd6ff1f9178dd640e3d38309a5581a39cf13c9c61238c41ceba83420afbf',
    'src/private_block/protocol.rs': '85ca893173c4bfc0d8c88be69dbd0834831d4aec4ec9783c66e0b61d614615f6',
    'src/private_block/run.rs': 'ad92be08fe55b86ea1f75931130a49d76de5c867c36210864694c2e1cd3dc0e9',
    'src/private_block/run_capture.rs': '31557a2722997d900bcf21e67f3aa312b9bf7f70ea81a0212470c32602c5be6f',
    'src/private_block/run_sink.rs': '005bac239d8dd616a46573f948c30ce1e2c540e02cf97035d3c457717c32921d',
    'src/private_block/shape.rs': '7b0c9742db3434fd2283ce23b6fb4d6f623a57b2f73fe026fc80bfc2ae3cc5f6',
    'src/private_block/trained_block.rs': '30cb9a31703a7a074c9028d9bb7941fa96be7fb736287305fb0a5c2702a57ff7',
    'src/private_block/trained_statement.rs': '6f18efcd0fe584e1539e98e525ded8e9aa60c75c01c5b028aeb10a12a8de1c34',
    'src/private_block/wire.rs': 'c8c13033f341ed40bd524091cfe870be3cb54433de566a6d9f4078c15cac374f',
    'src/private_block/witness.rs': '130f6301ba1118a9dd90f852d8bd5adf076ef4222fb58eb0e1b17a3c0a83de94',
    'src/private_seam.rs': '2f36c779e79c4d7a45538fb1d596a83e6eef9fe18f1b5e138b7d72afd3ee8cf5',
    'src/sumcheck.rs': 'f097dd71fab7888e95e61a29ab035b13153313d068e7547d91acbfd20c7bc566',
    'src/tables_attn.rs': '5a874788e20581010b492d50ccc5e662255115c65b9eebcf2f88314733b121e3',
    'src/tables_v3.rs': '726c9355f9e663ef1a43dc9efe17cb2c85aa3583977d0c794dad4cf21a24715d',
    'src/transcript.rs': '4850b2b4dc80317659fd643908e307ca58923c98e98baf32c4c1623ba239fd78',
    'src/zk.rs': '66d1128675bea3b473abd4f2fe70d470b1abc19a7fe5a579a227616d76280e32',
}

TOKEN_R7C_READINGS = {
    'src/private_block.rs': {
        '45286ae8f3be17da7f0938cec7ed0d689ba80f2ffda1d73d3b9329b3b25c3130': {
            'base': '386194fe90f01829feea20d012f4d50eabf53c1e9e2977fc2e03fbe918293587',
            'blob': '5f95ca0125505f1dd878d5cef8bbd4b8f78824a7',
            'bytes': 61160,
            'diff_stat': (
                '2 hunks, +11 / -0 against R7 386194fe; 1 hunk, +8 / -0 (token only) against native R8 '
                '08551c3d'
            ),
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] read against `386194fe` (R7): +11 / -0, two hunks: the token '
                "module and its CLI re-exports (:119-126), and native R8's cfg(test) module `r8_tests` "
                '(:178-180); against native R8 (`08551c3d`) only the first remains. '
                '`ExpectedIo::to_bytes`, `calibration_identity`, every statement check, and the cfg(test)'
                ' gating of `run_capture` / `run_capture_tests` (:222-225) are outside both hunks. No '
                'byte of any run moves.'
            ),
            'transcribed_by_the_gate': [],
        },
    },
    'src/private_block/run.rs': {
        '2c158dc9c22c23e46e1fc9b8b1215555880a3e7e8642703cc47d37f24b6116f2': {
            'base': 'ad92be08fe55b86ea1f75931130a49d76de5c867c36210864694c2e1cd3dc0e9',
            'blob': '23e2efa5a7af731840790c7fc79718405d4ea0a1',
            'bytes': 80119,
            'diff_stat': (
                '7 hunks, +73 / -24 against R7 ad92be08; 4 hunks, +33 / -0 (token only) against native R8'
                ' d913a081'
            ),
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] read against `ad92be08` (R7, read in round 6): `diff -u` is +73 / '
                '-24, seven hunks; against the native R8 freeze `d913a081` only hunks 1, 2, 7 and the '
                'token half of 4 remain (+33 / -0), so hunks 3, 5, 6 and the R8 half of 4 are native R8. '
                "TOKEN: three new run profile strings and TOKEN_IO_RUN_PROFILES (:101-119); CS-7's "
                'registry admits each over the same trained shape its blocks-only twin names (:153-155); '
                'a blocks-only bound statement refuses a token profile (:365-367; the unbound `new` '
                "already refuses every trained-calibration shape, :319-321); the block run's capture "
                "header carries `token: None` (:682). NATIVE R8: `stage_cal` (:300) holds each stage's "
                "whole calibration, the run shape's for every stage (:439) unless trained record k "
                '`has_own` (:380-384: `apply_own` on the run base, validated by '
                '`Shape::with_layer_calibration`); `stage_line` appends one clause per OWN_FIELDS field '
                "whose value differs (:543-553; an sh_s-only clause is R7's text); `stage_shape(k)` is "
                "the run shape's clone when the whole calibration is equal (:559-566). R8 is INERT at "
                'both pg_rot1 TinyLlama T32 exports (see `r8_inert_when`): every stage at the run shape, '
                "every schedule line R7's. **Outside every hunk**: `transcript` (tagged constructor, run-"
                'shape SEVEN u64, expected-IO, public-statement, parameters, calibration = the trained '
                'identity, schedule, :604-622), `position_tag` (:706-713), `stage_layout` (:693-695), '
                "`RunVerifier::step`'s per-stage absorbs and boundary rule (:1141-1150) and the draw "
                "order. At the TinyLlama T32 profile no byte of a blocks-only run moves. The token run's "
                'block stages call the same `protocol::verify_core` / `prove_core` (protocol.rs 85ca8931,'
                ' the R7 digest) at `TokenRunStatement::stage_shape`.'
            ),
            'transcribed_by_the_gate': ["the three token run profile strings (:101-116), of which the TinyLlama T32 one is the capture's profile", 'for a re-pinned trained TinyLlama statement: the R8 stage-line clause rule (:543-553), empty at pg_rot1_export_T32'],
        },
    },
    'src/private_block/run_capture.rs': {
        'aaff4e6e20c4deca7a0342f5b7dd2b9ac53a2837432af72f57c8a852e479db5e': {
            'base': '31557a2722997d900bcf21e67f3aa312b9bf7f70ea81a0212470c32602c5be6f',
            'blob': 'd190b626cbfbb1692f4c674077b05e84b3fea6fe',
            'bytes': 132875,
            'diff_stat': (
                '19 hunks, +911 / -57 against the gate R7 copy 31557a27; 17 hunks, +909 / -12 against the'
                " native R7 writer 1d43d68c (the file's actual ancestor). The difference, 3 hunks / +2 / "
                "-45, is the gate lane's 2026-10-17 patch being ABSENT."
            ),
            'moves_a_block_stage_byte': 'see reading',
            'reading': (
                "[TOKEN-IO R7c] [READ] read against `31557a27` (the gate's R7 copy): +911 / -57, nineteen"
                " hunks. That base is NOT this file's ancestor: against the native frozen R7 writer "
                "`1d43d68c` (also native R8's) it is +909 / -12, seventeen hunks, each a token addition "
                'or an `L` -> `stages_total(h)` generalisation; the three further hunks against '
                "`31557a27` (@@ -1329, @@ -1734, @@ -1971) are the privacy-gate lane's own 2026-10-17 "
                'trained-calibration patch, which this tree never carried. TOKEN HOOKS: '
                '`stage_begin_stage(k, kind, bytes, start_tag, b_root, a_root, h_root, mask_root, planes,'
                ' tr)` (:968) refuses a block header, an open stage, an out-of-order k, a kind other than'
                ' IN (k = 0) / BLOCK (1..=L) / OUT (L + 1) and a boundary root the schedule does not '
                'declare; builds the run plane index from the block Layout (BLOCK) or a TokenPlanes table'
                ' (IN / OUT, layout digest = SHA-256 of `StageLayout::describe`); then replays the stage '
                "prefix on the recorder's OWN transcript (:1073-1092): pb-run-stage k; pb-run-block "
                '(embedding digest for IN, block_digests[k - 1] for BLOCK, head digest for OUT); B, rows,'
                ' log-cols when the stage commits a boundary (IN: boundary 0 = B_in; BLOCK k: boundary k '
                'in token numbering; OUT: none); A, rows, log-cols; M; 3 + r_emb_len (IN) / 2 (OUT) / 3 '
                '(BLOCK) Fp2 draws; H, rows, log-cols. `stage_slot(def, spec, acc, proof, rho, c, '
                'mask_eval, before, after)` (:1114) refuses a stage slot in a block stage (:1123) and '
                "replays exactly the block `slot`'s sequence (definition draws up to the verifier's "
                'checkpoint :1149, pb-slot :1152, c :1153 compared, pb-scalar :1158, `sumcheck::verify` '
                "over main + ext :1160, pb-term :1171) at the slot's DECLARED (main, ext, degree), then "
                "writes the block slot record's keys (slot, name, kind, main, extension, degree, "
                'definition_challenges, c, scalar, claimed_sum, rho, sumcheck_final, mask_eval, '
                'terminal_polynomial, terminals, rounds, hosted, tables, before_definition, before, '
                "after) with the stage's own role names and FIXED coordinates as {fixed}; unlike the "
                'block `slot` (:1367-1390) it does not compare the private-table order with an '
                'independent plane-index derivation: the slot plane list is recorded AS OBSERVED '
                '(`slot_planes_source`, :555). Token header facts (TokenFacts :386): run_profile, V, '
                'V_pad, T, t_pad, d, d_pad, variant, mode, limbs, window_bits, mult_bits, emb / head '
                'digests, BOS, final norm (g0, Cn_f, tn_f, Ceps_f), (s_in, s_out), tier (name, Q, stage '
                'log_n / rate, endpoint log_n / rate), the two TokenEndpointFacts, both token roots, '
                'boundaries 0 = B_in .. L = B_out, r_emb_len, both stage layouts. Geom roles and kinds '
                'are strings set by the CALLERS (no list here): A-in / H-in / E-token-in '
                '(stage_in.rs:457, :463, :469), A-out / H-out / B-out / E-token-out (stage_out.rs:819, '
                ":825, :839, :862), and for each block's boundary opening role Input with commitment_kind"
                ' B-in at block 0, internal-boundary after (token_io/run.rs:911-912); new kinds stage-in,'
                ' stage-out, token-endpoint (token_io.rs:1059), B-in, B-out. NO-OP WITHOUT A RECORDER: '
                'every hook runs inside `with` (:774), `checkpoint` returns None without a recorder '
                '(:1280-1282) and `stage_slot` returns at once on None (:1115); the module is '
                '`#[cfg(test)]` (private_block.rs:222-223); hooks take `&Transcript` and draw only on the'
                " recorder's own copy; no transcript or receipt byte moves. A BLOCK RUN'S BUNDLE: "
                '`write_run`, `write_stage`, `begin_run_with` and the block `slot` are outside every '
                'token hunk and are selected when header.token is None (:1590, :1635, :2794), so '
                "run.json, every stage-NN.json and README.md are byte for byte the NATIVE R7 writer's; "
                "manifest.json's `source_pins` gains six entries INSERTED at indices 16-21, so "
                'trained_block.rs moves from index 16 to 22 and every shared pin shifts by six, against '
                "the function's own rule that new entries are appended and nothing re-sorted (:2869-2872)"
                " [READ; the in-file comment calls it a PURE ADDITION, :261]. Against the gate's R7 "
                'bundles a TinyLlama-T32-trained BLOCK bundle written by this file would also lose the 13'
                ' `shape` keys (trained_calibration, norm_tn, norm_cn_a, norm_cn_m, norm_ceps, sh_ao, '
                'sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z, d_max) and the trained README sentence. The token '
                "bundle's `shape` carries none of the 13 either [READ tinyllama-t32-L1-dense-"
                'pt1/run.json].'
            ),
            'transcribed_by_the_gate': ["the stage-prefix replay order (:1073-1092) as the gate's own transcript of an IN / BLOCK / OUT stage opening", "SCHEMA_TOKEN hashline-native-capture/6-token-run (:2107) and the 56 token ALLOWED_KEYS (:2686-2741) for the gate's closed-schema mirror", "write_run_token's `token_io` member (keys and order, :2264-2333) and write_stage_token's members, with logup_challenges = the first 3 (IN, BLOCK) or 2 (OUT) draws and r_emb = the rest for IN (:2133-2137, :2160-2161)", 'the boundary numbering of a token bundle: 0 = B_in committed at stage 0 and opened at stage 1, L = B_out committed at stage L and opened at stage L + 1 (write_run_token :2291-2305)', 'source_pins order: 23 own files, the six token files at indices 16-21, trained_block.rs at 22 (:219-278); key any pin lookup by file name, not index'],
        },
    },
    'src/private_block/shape.rs': {
        '8c62519c98e36ae966b7f9480e1d47884c57526c2ccf0288deb1286ca1a0fb34': {
            'base': '7b0c9742db3434fd2283ce23b6fb4d6f623a57b2f73fe026fc80bfc2ae3cc5f6',
            'blob': 'a17d0826a0f23754d524e161f5d62c942c497334',
            'bytes': 119159,
            'diff_stat': "1 hunk, +37 / -12 against R7 7b0c9742; byte-identical to native R8's shape.rs",
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] read against `7b0c9742` (R7, read in round 6): +37 / -12, one '
                "hunk; the file is byte-identical to the native R8 freeze's (`8c62519c`). "
                '`with_score_shift(sh_s)` is now `with_layer_calibration(&NormCalibration { sh_s, '
                '..self.norm_calibration() })` (:1481-1483) and has no production caller left (its '
                'callers are test modules) [READ grep]. NEW `with_layer_calibration(cal)` (:1496-1523): '
                'refused unless trained_calibration; `cal.derive_at_width(self.width)` (:238: width '
                'class, tn class, cn_a / cn_m <= 2^20, ceps <= 2^40, sh_ao <= 8, the six shift windows, '
                'D_max in three byte limbs, the remainder window exactly four limbs); clones and sets the'
                ' eleven constants plus the derived norm_wrho and d_max; `check_constructed` and '
                '`check_trained_class`; then rebuilds `Ids` / `HIds` and refuses unless n_a, (ln, ls, lp)'
                " and n_h equal this shape's (the plane list unmoved). It is called only for a record "
                'with own constants (run.rs:382, trained_statement.rs:647, trained_block.rs:938-941 and '
                ':2066, token_io/run.rs:231 and :258), which no record of the pg_rot1 TinyLlama T32 '
                'exports has. The trained geometry table and its TinyLlama T32 entry (`trained_geometry`,'
                ' :367), ruling C-4 (:306, :817-849), `hash_tag` (:1810), `true_size` (:1860), `pads` '
                '(:1885), `Shape::slots` (:2008) and the calibration validator itself are outside the '
                'hunk. At these exports no shape value and no byte moves.'
            ),
            'transcribed_by_the_gate': [],
        },
    },
    'src/private_block/token_io.rs': {
        '396daba1a49477ba7f2034a31d053f51b41d67704487fc78ab65ce604029092a': {
            'base': None,
            'blob': '250300d85c06e402b7cac7282b00181166e3fbfc',
            'bytes': 72455,
            'diff_stat': 'new file, 1557 lines',
            'moves_a_block_stage_byte': False,
            'reading': (
                "[TOKEN-IO R7c] [READ] New: the token run's module root (production, except the cfg(test)"
                ' registries, test modules and capture Geom helpers). TIER: `Tier` (:119-133); '
                '`Tier::R1_MVP` = {name `mvp-95-whole-run (D27)`, opened_cols 256, stage_log_n 12, '
                'stage_inv_rate 4, ep_log_n 8, ep_inv_rate 8, lookup_ext_degree 2} (:143), the one '
                'REGISTERED tier (:149); `check` (:160-201) refuses F_p^k with k != 2, out-of-range '
                'geometry, Q != zk.rs MASK_Q (TR-2), DESIGN B-1 floors, unregistered levers. PROFILE '
                'DOOR: `TokenProfile::new` (:368-438): V in 2..=2^17, BOS < V, g0 in [1, 127], Cn in [1, '
                '2^20], Ceps in [1, 2^40], tn in 1..=16, head multipliers in [1, 2^12], no head word '
                '-128, D_max in three limbs, final-norm window exactly 32 bits, keyed window over the '
                "whole multiplier class with limbs = ceil(window / 8) and p's margin, stage domains <= "
                '2^17. DOMAIN HELPERS, each lifted to the stage row width: ti_log = max(clog2 T_pad, '
                'stage_log_n) (:445), voc_log = max(log V_pad, .) (:449), lo_log = max(clog2 18, .) '
                '(:453), do_log = max(clog2 d_pad, .) (:457), vo_log = max(log V_pad, .) (:461), tab_log '
                '= max(8, .) (:465); in_ep_words = max(T_pad, 2^ep_log_n) (:471), out_ep_words = '
                '2^ep_log_n (:475). `describe_under` / `digest_under` (:484-519; the rung-TC and '
                'TinyLlama T32 profiles keep the legacy text `token-io R1:`, :249-251). LAYOUT: '
                '`StageLayout::new(params, a_log, h_log, h_sign, h_u, sched)` (:714-745): A planes '
                'contiguous from row 0, rows_of(log) = max(1, 2^log >> log_n) (:709-711); a_mask_base = '
                'a_data_rows; a_prox = a_mask_base + 2 * sum(a_sites); a_rows = a_prox + 2; each H plane '
                'a (re, im) pair of rows_of rows; h_mask_base = h_data_rows; h_prox = h_mask_base + 2 * '
                'sum(h_sites); h_rows = h_prox + 2. Accessors: a_site / h_site = mask_base + 2 * (prefix '
                '+ k) (:753-764), a_site_rows / h_site_rows = [mask_base, prox) (:765-770), h_u_rows = '
                "the zero-sum plane's two rows (:771-774), m_rows = 2 * slots + 4 (:775-777), mask_specs "
                '= (main + ext, degree) per slot (:778-780), n_functionals = sum(1 + [Standalone]) + '
                'number of host groups (:785-787); `logup_sum_claim` (:791-800). SLOT RUNNER: '
                '`run_stage_slot` (:901-1039) on the verify side, in order: schedule checks (:906-914), '
                'the capture checkpoint (:919, test only), absorb pb-slot (:920), draw c and refuse zero '
                '(:922-925), absorb pb-scalar (:973), `sumcheck::verify(claimed, degree, main + ext)` = '
                'one sc-round absorb and one draw per round (:975; zkp-core sumcheck.rs:152-163), g_val '
                '(:992), refuse a degenerate e (:997), absorb pb-term (:1000), claims at '
                "sched.row_log[cm] (:1002-1010), M functionals (:1017-1029), the capture's `stage_slot` "
                "(:1035-1037, test only). These are argument.rs `run_slot`'s operations in the same order"
                ' (:476, :480, :600, :602, :626, :629); the definition draws precede the call, in the '
                "stage modules' `define`. `finish_functionals` (:1165-1172): per slot in slot order "
                '[Gamma_s if Standalone] then eval_s, host Gammas deferred and appended last, count == '
                'n_functionals, as argument.rs:640-655 and :1958-1962. Also: the one-site token endpoint '
                'claim schedule (:1184-1197), the stage wire (:1238-1402), the owner check (:1532-1557). '
                'Nothing here is called by a block stage.'
            ),
            'transcribed_by_the_gate': ["StageLayout::new's row rule (:709-745) and accessors a_site / h_site / a_site_rows / h_site_rows / h_u_rows / m_rows / mask_specs / n_functionals (:753-787)", "finish_functionals' M functional order (:1165-1172 with :1017-1029)", "run_stage_slot's verify-side sequence pb-slot, c, pb-scalar, sc-round x (main + ext), pb-term (:920-1000)", "TokenProfile's domain helpers ti / voc / lo / do / vo / tab and in_ep_words / out_ep_words (:445-477)", "Tier::R1_MVP's levers (:143)"],
        },
    },
    'src/private_block/token_io/cli.rs': {
        '04e328686466e1e5fcbe997e5599d8fc658bcbc48bec163f9840338226691dfe': {
            'base': None,
            'blob': 'c693bff3528b99e63fa780c0d5a256f080e7c33b',
            'bytes': 42710,
            'diff_stat': 'new file, 814 lines',
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] New, REPORT-ONLY. The CLI bridge (prove, profile, verify, owner, '
                "input-owner). `render` (:136-183) is the only writer of a token run's statement, schema "
                '`zk60-token-io-run/2`: schema, scope, statement_written_by, prover_reported {backend, '
                "gpu_declines, what} (checked by R7's `check_prover_reported`), run_profile, "
                'block_profile, blocks, export_variant, export_profile_sha256, '
                'trained_statement_identity, layers_with_own_calibration (R8; empty at the pg_rot1 '
                'exports), tables {three SHA-256, V, d}, bos, final_norm, token_profile_digest, '
                'context_label, context, both token endpoint roots, whole_run_floor_bits, parameter_line.'
                ' `statement_of` (:220-226) rebuilds the TokenRunStatement from public files at '
                'Tier::R1_MVP and the public-row variant, context = stack_context(variant, layers, label)'
                ' with the one admitted label `zk60-token-io-next-token` (:85). Verify pins --expect-'
                'statement (the trained identity, :576-585) and --expect-token-profile (the token profile'
                " digest, :592-599), requires the found statement to be byte for byte `render`'s "
                '(:648-650), verifies under --min-bits (default 95, :624, :663), then publishes '
                "statement/ {statement.json, segments.json}. Prove (:475-571) checks B_in = the export's "
                "x_in_L00 (:504-506), takes the next token from the last layer's x_out row T - 1 "
                "(:507-514), writes the owners' decommitments to a 0700 owner directory and an UNVERIFIED"
                ' statement. No run_capture call anywhere in the file: a CLI token run cannot be captured'
                ' [READ grep].'
            ),
            'transcribed_by_the_gate': [],
        },
    },
    'src/private_block/token_io/load.rs': {
        '998bc0e85e94e1d797e8de1129f4de3e16f9cf94944207b327abcae231a07669': {
            'base': None,
            'blob': 'a77e618324465e566077b443735cb8c80ec99ff3',
            'bytes': 13537,
            'diff_stat': 'new file, 273 lines',
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] New, REPORT-ONLY. Decides the public inputs a token run binds. '
                '`read_manifests` (:83-114): token_io.json embedding_table {sha256, shape [V, d]} and '
                'head_manifest.json {V, d, bos, head_int8_perrow.bin.sha256, head_mult12.bin.sha256, '
                'final_norm {g0, cn_calibrated as Cn, tn, ceps}}, V and d cross-checked, a token_io.json '
                "bos must equal the head manifest's; bounded strict reads, no link followed. "
                '`load_token_tables` (:163-176) reads the three tables at exact lengths with streamed '
                "SHA-256 checks; the binding rests on the tables' own digests (TokenTables::emb_digest / "
                'head_digest), not on the manifests. `token_run_profile_of` (:179-188) maps the block '
                'profile to its token run profile. `ExportPublic::load` (:205-230): '
                '`TrainedExport::load`, `run_constants` (the R8 path, inert at the pg_rot1 exports), '
                '`shape_for`, every layer loaded (record and digest kept, block dropped), and the '
                'TrainedModelStatement built under the TOKEN run profile (:228). `ExportTokenBlocks` '
                '(:236-273) reloads block k at its stage and refuses unless its digest is the digest '
                "pass's (CS-6), one block resident. No transcript operation."
            ),
            'transcribed_by_the_gate': [],
        },
    },
    'src/private_block/token_io/run.rs': {
        '924ee3e27aea8da26e04567d556fc66af6cfbfcc11a7ffc8dca7a235cc9d1ae1': {
            'base': None,
            'blob': '3cec90c0a73e0d6ca041eb0f990cd0be7f9c7d10',
            'bytes': 54132,
            'diff_stat': 'new file, 1092 lines',
            'moves_a_block_stage_byte': 'see reading',
            'reading': (
                '[TOKEN-IO R7c] [READ] New. HEADER (`TokenRunStatement::transcript`, :422-436): '
                '`protocol::tagged_transcript(sh, token profile bytes)`; absorb run-shape = EIGHT u64 LE '
                '[L, sh.tokens (T), width, sh.hidden (the true FFN width), q_heads, kv_heads, head_dim, '
                'tp.v (the TRUE V, not V_pad)] (:425-429; capture tinyllama-t32-L1: [1, 32, 2048, 5632, '
                '32, 4, 64, 32000]); expected-IO = `token-io-expected/v1` + in-spec digest + in root + '
                'out-spec digest + out root (:282-290); public-statement = blake3(`hashline/token-io-run-'
                'blocks/v1` + block digests + emb + head) (:292-301); parameters = `parameter_line` '
                '(:311-344: the block line, with `/two-internal-boundaries/` for non-legacy profiles, L, '
                'boundary, token-endpoint and stage geometry, `describe_under`, the whole-run floor and '
                'opening count); calibration = blake3(`hashline/token-io-calibration/v1` + the trained '
                'identity + the token profile digest) (:303-309), NOT the trained identity itself as a '
                'blocks-only run absorbs (run.rs:619); schedule = blake3(`hashline/token-io-run-'
                "schedule/v1` + length-prefixed lines: parameter line, the block Layout's describe at the"
                " RUN shape, stage IN's and OUT's describe, the stage lines) (:397-419). `stage_lines` "
                "(:348-395) number boundaries from 1 (`boundary 1 = B_in`); the capture's token numbering"
                ' starts at 0. R8 ported: `stage_cal` from the trained records with a record-k-is-block-k'
                ' check (:221-234), `stage_shape` (:253-260), stage-line clauses (:364-371); inert under '
                '`r8_inert_when`. VERIFIER (`verify_token_run_with`, :833-955): before any segment, '
                '`variant_is_built` (:165-170: only the public-row variant), `tier.check`, the whole-run '
                'floor against the policy, L blocks and L + 2 segments, NTT fit, table digests '
                '(:837-851). Stage order: stage IN (segment 0, header tag compared in decode, trailer '
                ':868-870); blocks k = 0..L-1 as stages k + 1: CS-1/4/6 (:878), decode and path depths, '
                'capture `stage_begin_stage(k + 1, BLOCK)` (:885), absorb pb-run-stage k + 1, pb-run-'
                'block = block_digests[k], absorb_root B = the root of boundary k + 1 in token numbering '
                '(boundary_spec(k + 1), BoundarySpec index k + 2; B_out at k = L - 1), carried in the '
                'block segment (:886-890); `protocol::verify_core` at stage_shape(k) with IO mask rows '
                '[boundary k site 1, boundary k + 1 site 0] (:572-574, :892-893); then ONE opening of '
                "boundary k in token numbering (B_in at k = 0) with claims = pending (stage IN's IN-01 "
                "claims at k = 0, else block k - 1's slot-22 claims) then this block's slot-21 claims "
                '(:895-904); trailer (:931-933); stage OUT (segment L + 1, stage index L + 1, B_out '
                'opened inside it, trailer :946-948); `run_accepted` (:952, test only). `position_tag` '
                "(:589-596) is run.rs's character for character. The prover's order mirrors this "
                '(:703-823). A token block stage is a block stage (the same verify_core) inside a '
                'different transcript and stage numbering; its IO roles are two-site boundaries at both '
                'ends, block 0 included.'
            ),
            'transcribed_by_the_gate': ['the six header absorbs in order and their byte compositions (:282-309, :311-344, :397-436)', 'run-shape words [L, T, width, hidden, q_heads, kv_heads, head_dim, V] (:426)', 'the stage order IN, blocks 1..L, OUT and the trailer checks (:857-948)', "a block stage's B absorb = boundary k + 1 (token numbering) and its one opening = boundary k with claims pending-then-incoming (:886-904)", 'variant_is_built (:165-170)', 'the boundary numbering offset: stage lines 1-based (:353, :373), capture facts 0-based'],
        },
    },
    'src/private_block/token_io/stage_in.rs': {
        '0387e6b1a9f617eb21bf79e76bf131dff8ba62a8ff6df875e0a78de606717728': {
            'base': None,
            'blob': '4318aa7a66ecd840aca52b27e0a2eba08e91f7cd',
            'bytes': 23366,
            'diff_stat': 'new file, 484 lines',
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] New. `layout` (:38-55): four Standalone slots, no hosts: IN-00 IO-'
                'in (main clog2(in_ep_words), ext 1, degree 3, A 1, IO 1), IN-01 query zero-check (main '
                'ti_log, degree 4, A 1, H 1, IO 1), IN-02 table zero-check (main voc_log, degree 4, A 1, '
                'H 1), IN-03 zero-sum (main stage_log_n, degree 2, H 1); row_log [A, H, In = input token '
                'endpoint, Out = B_in] = [lt, lt, ep_log_n, block endpoint_log_n] (:51); A = [tok on Ti, '
                'm on Voc], H = [h_q on Ti, h_tab on Voc, u one row], signs [1, -1, 1], h_u = 2 (:54). '
                'A_GROUPS 3, H_GROUPS 4 (:33-34). VERIFY PREFIX (:429-436): absorb_u64 pb-run-stage 0; '
                'absorb pb-run-block = emb_digest; absorb_root B (B_in root, b_spec.commitment_rows, '
                'b_spec.log_n); absorb_root A (a_rows, stage log_n); absorb M (bare root); `challenges` '
                '(:239-247): beta, gamma, alpha, then clog2(d_pad) r_emb coordinates (11 at d_pad 2048), '
                'g_emb = gamma * 135; then absorb_root H. CONFIRMED as the bullet states. OPENINGS '
                "(:447-469): M (`mask_verify_tagged`), A-in, H-in (the LogUp sum claim appended to H's "
                'claims, :451), the input token endpoint; each preceded by a transcript-free schedule '
                "check (`check_opening` replays on a clone). B_in is NOT opened here: IN-01's claim is "
                "returned (:470) and opened in block 0's stage. SLOT TABLES (`define`, :149-221): IN-00 "
                'draws tau (clog2 words); Eq(tau), PUBLIC supp(T, in_ep_words) (:165), tok read with the '
                'top ti_log - lw bits fixed to 0 (:166-168), the endpoint on its own cube; poly eq * (end'
                " - supp * tok), so the endpoint's pad words must be zero. IN-01 draws tau (ti_log), mu "
                'x3, zeta x1 (nonzero); Eq, PUBLIC supp(T, 2^ti_log) (:179), PUBLIC u0 = supp(1, '
                '2^ti_log) (:180), B_in read at (rho row bits, r_emb FIXED) (:185-187); clauses LogUp, '
                'BOS u0 * (tok - BOS) with its own mu, pad (1 - supp)(tok + zeta h_q) (:189-195). IN-02 '
                'draws tau (voc_log), mu x2, zeta; Eq, PUBLIC supp(V, 2^voc_log) (:203), PUBLIC tau table'
                ' (true rows v + beta E~(v, r_emb) + g_emb, padded rows repeat row 0, :145-147); pad (1 -'
                ' supp)(m + zeta h_tab) (:209). IN-03 no draws; PUBLIC all-ones over 2^h_log[H_U] (:215).'
                ' Capture plane names A_TOK, A_MULT / H_Q, H_TAB, H_U and slot roles [A-in, H-in, '
                'E-token-in, B-in] (:476-484, test only).'
            ),
            'transcribed_by_the_gate': ['layout (:38-55)', 'the verify prefix pb-run-stage 0, pb-run-block emb, B, A, M, beta, gamma, alpha, r_emb x clog2(d_pad), H (:429-436, :239-247)', 'the opening order M, A-in, H-in, input token endpoint (:447-469)', 'the public tables per slot: IN-00 supp(T, words) :165; IN-01 supp(T, 2^ti) :179 and u0 :180; IN-02 supp(V, 2^voc) :203 and tau :145-147; IN-03 ones :215; the fixed r_emb coordinates on B_in :185-187'],
        },
    },
    'src/private_block/token_io/stage_out.rs': {
        '69abed433fd751bf12b30fca40174ca21638230fd9e39af69ea07b987d03e8ca': {
            'base': None,
            'blob': '03504cec880b670a1077543a5303c5eaf66b4e52',
            'bytes': 41081,
            'diff_stat': 'new file, 892 lines',
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] New. `layout` (:77-119): eleven slots: OUT-00 IO-in (main clog2 '
                'd_pad, degree 2, Standalone, A 1, IO 1), OUT-01 SS (do_log, 4, Private, A 1), OUT-02 TZC'
                ' (TO_LOG = 1, 3, Host of SS, A 11), OUT-03 LZC (lo_log, 4, Standalone, A 1, H 1), OUT-04'
                ' HEAD (clog2 d_pad, 2, Private, A 1), OUT-05 DZC (do_log, 5, Standalone, A 13, H 6), '
                'OUT-06 VZC (vo_log, 5, Host of HEAD, A 1 + L + 2, H ceil(L / 2)), OUT-07 RSEL (vo_log, '
                '4, Standalone, A 1 + L + 1), OUT-08 TAB (tab_log, 3, Standalone, A 1, H 1), OUT-09 ZS '
                '(stage_log_n, 2, H 1), OUT-10 IO-out (clog2 out_ep_words, 3, Standalone, A 1, IO 1); '
                'hosts [(TZC, [SS]), (VZC, [HEAD])]; row_log [lt, lt, In = B_out at block endpoint_log_n,'
                ' Out = output token endpoint at ep_log_n]; A = [To x4 at log 1, LIMB on Lo, twelve Do, e'
                ' and L keyed limbs on Vo, the U8 histogram on Tab]; H = [Lo helper, six Do helpers, '
                'ceil(L / 2) Vo helpers, the table helper (sign -1), u]. A_GROUPS 18, H_GROUPS 6 '
                '(:74-75). At the R2 capture (L = 7 limbs): A 26 planes / 182 rows, H 13 planes / 110 '
                'rows, M 26 rows, 20 functionals [READ capture stage_out_layout]. VERIFY PREFIX '
                '(:793-800): absorb_u64 pb-run-stage = stage_index (the run passes L + 1, '
                'token_io/run.rs:945); absorb pb-run-block = head_digest; absorb_root A; absorb M; gamma '
                'then alpha (2 Fp2, g_u8 = gamma * TAG_U8); absorb_root H. No boundary absorb. CONFIRMED '
                'as the bullet states. OPENINGS (:809-860): M, A-out, H-out (LogUp sum claim appended, '
                ":813), B-out (claims = block L - 1's pending claims, then OUT-00's, :826-834), the "
                'output token endpoint. SLOT TABLES (`define`, :336-542): OUT-00 draws tau (d_bits); no '
                'public table; x read with the lift bits fixed 0, B_out read at fixed_bits(T - 1, t_bits)'
                ' then rho (:358-363). OUT-01 no draws; PUBLIC supp(d, do_n) (:367). OUT-02 draws tau '
                '(1), mu x4, nu, zeta; Eq, PUBLIC u0 = supp(1, 1 << TO_LOG) = supp(1, 2) (:377), nine '
                'limb slices at A_LIMB offsets 2k (:381-383); pad (1 - u0)(D + zeta Dsq); host term nu * '
                'u0 * (Dsq + a1 - Ceps) (:386-392). OUT-03 draws tau (lo_log), mu x2; PUBLIC live-limb '
                'indicator {z : z even, z / 2 < 9} = {2k : k < 9} (:400); pad (1 - s) * limb. OUT-04 '
                'draws r_j (vo_log, kept for VZC); PUBLIC Wf = head_fold(eq(r_j)[..V], d_pad) (:412-418).'
                ' OUT-05 draws tau (do_log), mu x10, zeta; PUBLIC supp(d, do_n) (:426); pad (1 - g) * '
                'zeta_fold of the twelve Do planes. OUT-06 draws tau (vo_log), mu x(2 + ceil(L / 2)), nu,'
                ' zeta; Eq(tau) and Eq(r_j) (no redraw, :463), PUBLIC supp(V, vo_n) (:464), PUBLIC iota '
                '(:465); pad (1 - s) * zeta_fold(e, limbs). OUT-07 draws c x3, no Eq; PUBLIC supp(V, '
                'vo_n), iota, u0 = supp(1, vo_n) (:495-497). OUT-08 draws tau (tab_log), mu x2, zeta; '
                'PUBLIC supp(256, tab_n) (:514), PUBLIC (z mod 256) + g_u8 (:517). OUT-09 PUBLIC all-ones'
                ' (:528). OUT-10 draws tau (clog2 256); PUBLIC u0 = supp(1, 256) (:535). Capture slot '
                'roles [A-out, H-out, B-out, E-token-out] (:890, test only).'
            ),
            'transcribed_by_the_gate': ['layout (:77-119)', 'the verify prefix pb-run-stage L + 1, pb-run-block head, A, M, gamma, alpha, H (:793-800)', 'the opening order M, A-out, H-out, B-out, output token endpoint (:809-860)', 'the public tables per slot (:367, :377, :400, :418, :426, :464-465, :495-497, :514, :517, :528, :535) and the fixed T - 1 row bits on B_out (:361)'],
        },
    },
    'src/private_block/trained_block.rs': {
        '0943baded99b1fb1a887a8a18d5d17d35b22a64a8f0b78f77e3062efa63d7846': {
            'base': '30cb9a31703a7a074c9028d9bb7941fa96be7fb736287305fb0a5c2702a57ff7',
            'blob': '803fe40983b7c2e543d9bd7267c076d1bb005c3d',
            'bytes': 154060,
            'diff_stat': (
                '16 hunks, +73 / -57 against R7 30cb9a31 (8 native R8 + 8 visibility); 8 hunks, +10 / -10'
                ' (visibility only) against native R8 cc401eb4'
            ),
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] read against `30cb9a31` (R7): +73 / -57, sixteen hunks; against '
                'the native R8 freeze (`cc401eb4`) only the eight `fn` -> `pub(crate) fn` hunks remain '
                '(flags, flag / need / js, refuse_prover_private_entries, write_new, stack_context, '
                'render_segments_json, check_statement_dir, publish_statement_dir), which the token CLI '
                'imports (token_io/cli.rs:74); the other eight are native R8. R8: '
                '`per_layer_cal_fields()` (:825-827) replaces `sh_s_per_layer()`: the OWN_FIELDS indices '
                'profile.json lists in per_layer_constants_differ; NEW `masked` sets those fields to a '
                'base (:830-837); `run_constants` reads every layer manifest once and, with per-layer '
                'fields and non-uniform profile constants, takes the run base as the most common tuple of'
                ' those fields (ties: the smallest in canonical order, sh_s first) (:850-888); '
                '`load_layer_mode` requires masked(lc, run) == run (:933), records own_of(run, lc) (:937)'
                ' and validates a layer with own constants at `with_layer_calibration` (:938-941); '
                "`record.own` (:1060); the sealing pass builds each witness at the layer's own "
                'calibration and caches one Layout per calibration (:2051, :2066, :2082); the stack '
                'statement renders own constants under their export keys (:2425; an sh_s-only record '
                'renders as in R6 / R7). INERT at pg_rot1_export_T32 and pg_rot1_b4_T32_cal128 (see '
                '`r8_inert_when`): base None, `masked` the identity, lc_run = lc as in R7, own all None, '
                'no with_layer_calibration call, no own field rendered. The block-building path the '
                'TinyLlama captures use (`load_layer`) and the CLI statement bytes do not move at these '
                'exports [MINE from READ]. The token run reaches this file through load.rs '
                '(`TrainedExport::load`, `run_constants`, `shape_for`, `load_layer`, `reload_block`) and '
                'the CLI helpers.'
            ),
            'transcribed_by_the_gate': [],
        },
    },
    'src/private_block/trained_statement.rs': {
        'e623c2278042a42ef55d005236f0509a27b57f1baf368eee52eec05ea9125a13': {
            'base': '6f18efcd0fe584e1539e98e525ded8e9aa60c75c01c5b028aeb10a12a8de1c34',
            'blob': '0c4b0a43cd9b9f5ca97fc8ad0d4d54327668a6dc',
            'bytes': 36556,
            'diff_stat': (
                "6 hunks, +113 / -23 against R7 6f18efcd; byte-identical to native R8's "
                'trained_statement.rs'
            ),
            'moves_a_block_stage_byte': False,
            'reading': (
                '[TOKEN-IO R7c] [READ] read against `6f18efcd` (R7): +113 / -23, six hunks, all NATIVE '
                "R8; the file is byte-identical to the native R8 freeze's (`e623c227`). "
                '`LayerRecord::sh_s: Option<u32>` becomes `own: [Option<i64>; 11]` (:372), one entry per '
                "OWN_FIELDS (:381-393: export key, identity label, schedule label), sh_s FIRST with R6's "
                'labels sh-score-layer / score shift; helpers `cal_field` (:396), `apply_own` (:414, a '
                'u32 field out of range is refused, never wrapped), `own_of` (:437), `has_own` (:449); '
                'both constructors set [None; 11]. `check_self_with` (:631-648): each Some must differ '
                'from `cal_field(&sh.norm_calibration(), i)` (R7 compared sh_s with '
                '`self.calibration.sh_s`), then `apply_own` and `sh.with_layer_calibration`. `encode` '
                'writes `OWN_FIELDS[i].1` as u64 ONLY for a Some entry, in canonical order, after exp-e-s'
                " (:725-732), replacing R7's sh-score-layer-only write. With every record [None; 11] (the"
                " pg_rot1 exports), the encoding and the identity bytes are R7's; an sh_s-only statement "
                'encodes as R6 / R7 (same label, same u64). The rest of `encode` (:665-747) and the '
                "identity's blake3 domain (:750-755) are outside every hunk. NOTE [READ load.rs:228 and "
                'encode :669]: a token run builds its trained statement under the TOKEN run profile, and '
                "`run-profile` is an encoded field, so the token run's trained identity is a different "
                "digest from the blocks-only statement's of the same export [MINE from READ]; the token "
                'header absorbs it only inside its own calibration digest (token_io/run.rs:303-309).'
            ),
            'transcribed_by_the_gate': ["for the gate's independent identity recomputation (stage 14, E1-E4) once the trained TinyLlama statement is re-pinned onto this tree: per layer, after exp-e-s, one u64 per Some own entry labelled OWN_FIELDS[i].1 in canonical order (:725-732); none at pg_rot1_export_T32, so the R7 encoding stands"],
        },
    },
}
