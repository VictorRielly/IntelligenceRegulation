#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v21 staging, gate round 18, 2026-10-29: native R9 ->
R12 -> R12b, and the token tree frozen-r14 on top of R12b] The READINGS behind
the source pins a capture from token frozen-r14 (or from native R12b) carries
for the native files, read step by step from the last native digest the gate
read (native R9, `zk60_native_rg_tinyllama_r9_pins`, tools v17) or, for
`run_capture.rs`, from token frozen-r12's `aaff4e6e` (read in v20 together
with the round-16 capture hooks, `zk60_native_rg_classpins.HOOKED_READINGS`).
READ 2026-10-29 ~02:25-02:40 UTC by a reading sub-lane of the privacy-gate
lane with `diff -u` over the frozen copies; nothing was built or run.  The
parent merges these dicts; no existing digest or reading changes here.

THE TREES.  Native R9 `results/zk60_1b_native_20261017/r9/frozen-tree/`
(af90c703...); native R12 `.../r12/frozen-tree/` (tree 1e406781..., 225
files, FROZEN 2026-10-26); native R12b `.../r12b/frozen-tree/` (tree
51de5b83..., 229 files, `r12b/manifest_frozen.json`); token frozen-r12
`results/zk60_token_io_r1_20261017/frozen-r12/` (native R8 based); token
frozen-r13 / frozen-r14 (rebased onto native R12b; r14 manifest
`manifest_final_r14.sha256`, 258 files, list sha256 0b4c429b..., every digest
below re-hashed against it; frozen-r14 is UNREVIEWED by its own lane's
statement, `frozen-r14.FROZEN.txt`).  The v20 capture tree (frozen-r12 plus
the gate's round-16 hooks) is `ops/zkp-mvp/token-io/` (run.rs `ebc64fd1`,
run_capture.rs `d1e25882`).

R12 = R9 + D38 / F1-F3: four Shieldstral-1.0-3B profiles (T128 / T256, each
with and without DD), the decoupled-head development rung
(`hashline-zk-mr1/private-block-rung-hd-t32-dev/1`), YaRN / llama3 RoPE
transforms as PUBLIC tables (`rope.rs`), the query axis `q_pad = h_pad *
head_dim` given its own name, and an optional tied-embedding record in the
trained statement.  R12b = R12 + the D24 review's fixes R12-F1..F3 (the tied
tables recomputed from the authenticated checkpoint, `tied_tables.rs` /
`tied_tables/derive.rs`; bounded regular-file hashing; `--rope-from-export`
refused at a pinned transform).  D24 review round 10 ACCEPTED R12 WITH FIXES
and round 11 ACCEPTED R12b for the fix scope, both saying "existing profiles
byte-identical" (`results/zk60_d24_review_20261017/REVIEW_R12.md` section 1,
`REVIEW_R12B.md` section 4); neither is a privacy review, and the reading here
is the evidence, the reviews are cited.

THE PROFILE GATES [READ].  Every R12 / R12b change is one of:
* gated on a NEW profile by name: `SHIELDSTRAL_PROFILES` (shape.rs:122),
  `TRAINED_HD_RUNG_PROFILE` (shape.rs:129), `Geometry::Shieldstral* /
  RungHdDev` (trained_block.rs), the five new run profiles (run.rs:152-157);
* the query axis renamed, `Shape::q_pad()` (shape.rs:1935) in place of
  `d_pad` / `q_width()` in place of `width` at the Q / O sites: the identity
  wherever `h_pad * head_dim == d_pad` and `q_heads * head_dim == width`.  R9's
  `Shape::build` REFUSED `d_pad != h_pad * head_dim` (the refusal R12 removes,
  shape.rs:724-729), so every shape R9 could build has q_pad == d_pad; the
  registry arguments give both equalities at every pre-R12 shape (TinyLlama
  32 x 64 = 2048, Llama-3-8B 32 x 128 = 4096, rung-TC 12 -> 16 x 32 = 512 =
  pad(384), DD rung 8 x 32 = 256, the dev rungs g / k4 / p2 / c6 / w14 / e32 /
  t24, the toy, 125M) [COUNTED]; only rung-HD differs (q 512, d_pad 256);
* optional trained-statement fields emitted ONLY at a tied model (Shieldstral)
  or a scaled RoPE (trained_statement.rs:801, 845);
* the frozen RoPE generator itself at every unscaled profile (rope.rs:219-221);
* `#[cfg(test)]` code (`run_capture.rs` is a test-only module,
  private_block.rs:242-243 in frozen-r14).
The token tree adds, on top of R12b, exactly the token lane's hunks the gate
already read on native R8 (run.rs and private_block.rs byte-identical hunk
for hunk; trained_block.rs the same ten `fn` -> `pub(crate) fn` words as
frozen-r7's `0943bade`), two visibility / re-export changes in the R12b tied
modules, and in run_capture.rs the v20 hooks plus one classifier pin
(`classify_tied.rs`).

At the profiles the gate captured before -- the TinyLlama T32 block and token
profiles, the rung block profiles (`hashline-zk-mr1/private-block-rung-tc-
t32-dev/1` and the other registered rungs), the token rung, the classifier
rung run profile `hashline-zk-mr1/private-classify-run-rung-tc-t32-public-
row-dev/1` -- no step read here moves a receipt byte or a block stage byte
(slots, planes, the 50 mask rows / 34 functionals off DD, the schedule, the
transcript), and no public statement byte (the trained-statement identity,
the statement JSON's scope, the run header).  What moves is capture METADATA:
every bundle's `source_pins` gains rope.rs, tied_tables.rs and derive.rs, a
classifier bundle's also `classify_tied.rs`, and the classifier README says
"five" for "four".  The classifier and token lane files themselves
(classify*.rs, stage_*_c.rs, token_io*.rs, the r13 -> r14 step of
run_capture.rs) are NOT read here.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

READ_AT_UTC = "2026-10-29T02:38:21Z"

TREE = ("results/zk60_token_io_r1_20261017/frozen-r14 (manifest_final_r14.sha256, 258 files, "
        "list sha256 0b4c429bafadc5aa13c3d97634f648611ce8a76b0e27963ad6a41a2bdf630170), rebased on "
        "results/zk60_1b_native_20261017/r12b/frozen-tree (tree "
        "51de5b83bc0dcaeeeb430165081c47653ac012c462c09f3df4ce7f125faf904f, 229 files)",)
# the round-18 bundles are not captured yet; the parent fills this tuple
R18_BUNDLES: tuple = (  # [v21, filled by the gate lane 2026-10-29] the round-18 captures (token frozen-r14)
    "classify-rc3-rung-L1-v0", "classify-rc3-rung-L1-v1", "classify-rc3-rung-L1-vtie",
    "classify-rc3-rung-L2-v0", "classify-rc3-rung-L2-v1", "classify-rc3-rung-L2-vtie",
    "classify-rc3-rung-L2-v1-chunk0o27", "classify-rc3-rung-L2-v1-chunk1o27",
    "classify-rc3-rung-L2-v1-short20", "classify-rc3-rung-L1-vtie-short20", "classify-rc3-cli-p18-r14")

# ---------------------------------------------------------------- the digests (full)
# native R8 / R9 (read by earlier tools) and the token trees' bases
ARGUMENT_R9 = "112352bc35c8b877cba50707a5ea64ea239ec6c684becb193ad981bd643ff4f5"
SHAPE_R9 = "e214db86945e0b9df8336edc7974041ebcfe77f2f1884a565a77a0392fca1165"
WITNESS_R9 = "d1a859187b58ac12c9bda0b0c98c25d85d24d87b6100724fd9d697f9b7fad607"
PAD_R9 = "20afa04f6418b4f14050736f55e21d7cf15718e4632323b30427f1c21ec5b4a8"
TRAINED_STATEMENT_R9 = "ac61bf90cc0d93da24c6049d6be61e7d7b9d75c662ca3817d855692de777cb52"
TRAINED_BLOCK_R9 = "357e27974e4f3c8224cb0aca9e52a56d2e4ebef68b22e7e255febf2b3048628d"
TRAINED_BLOCK_TOKEN_R7 = "0943baded99b1fb1a887a8a18d5d17d35b22a64a8f0b78f77e3062efa63d7846"
PRIVATE_BLOCK_R8 = "08551c3d3526259aec5ee8619c9ab803677a0ae079428cb07c4254277cf1b67c"
PRIVATE_BLOCK_R9 = "5e50acd54e7e3e4926b03e9e329073116f278ad203fdcd175e3230464041432c"
PRIVATE_BLOCK_TOKEN_R12 = "a9727239c5669ae08481ab2fd2bd0f12479a63f10658501132fc306a305d3a9a"
RUN_R8 = "d913a081b82d54b6a1a67cd938afe1700910e820d9b3a97019a398f8b61ea609"
RUN_R9 = "cf80735dbea505fef939abb91ed23ed5d4b74d2a9a1464727f6f7058dfc11339"
RUN_TOKEN_R12 = "10cfc2b1aa2fb2e288300aeb924a9f2c3ae012d1e975707eb15c66a4875c2e6d"
RUN_TOKEN_R12_HOOKED = "ebc64fd159030036f126ad895e3d57442429ebe369c5b2d59f724ebd05e04fcd"
RUN_CAPTURE_R8 = "1d43d68c5f48b203cc3001dd6accf5612713a3b4a0277166daeafe14f266a503"
RUN_CAPTURE_R9 = "e1c87a07da1b59a734c99f60545ba2f6cde851215429956adf26b4340281d65a"
RUN_CAPTURE_TOKEN_R12 = "aaff4e6e20c4deca7a0342f5b7dd2b9ac53a2837432af72f57c8a852e479db5e"
RUN_CAPTURE_TOKEN_R12_HOOKED = "d1e25882ea0a74d15a70ed6982319f79883f24ac83f893c6a63b29ea288d81c5"

# native R12 / R12b and token frozen-r13 / r14 (read here)
ARGUMENT_R12 = "c4f9f9f4cb477346b03e9f769d7c3141a8529f096d08da2be6c415d5160a5e66"          # = R12b = t13 = t14
SHAPE_R12 = "9a87081897ff0ec716d7f27a2813cc32117683eb5b2f2082a248f479ef98c4c5"             # = R12b = t13 = t14
WITNESS_R12 = "a586b777c36c9fa5060d3dfa195a75ff0a2b7794a2521cad59aaf7f3f6144ec3"           # = R12b = t13 = t14
PAD_R12 = "91141ea025d01257a5f0b5007e711d883af896b72d3c109badb6999f48d78967"               # = R12b = t13 = t14
TRAINED_STATEMENT_R12 = "0fbf90ed39063532fd19c42f4d7e36b8a6a030c5cb4386c46ed4d7a393e88e5e"
TRAINED_STATEMENT_R12B = "7908d827889d5bb424b51cb470313c666533577b29fd45c78957db00963e6a1d"  # = t13 = t14
TRAINED_BLOCK_R12 = "c6d87b6e0b5d9744ecad8abe6eef922f7eaf03be5ea6c4fdf1fec98026551fa2"
TRAINED_BLOCK_R12B = "e2551aa15fddc7cf43753ca0f5ef65fe813b1f7c279f4928fad1fd6b8c5d77a5"
TRAINED_BLOCK_T14 = "f892dbc7d4de24d0a17945637107fb4e22a09d4e9a0bdc8520790352f121d06b"      # = t13
PRIVATE_BLOCK_R12 = "3810bdabc8c0ee4877302aa6819793ce0ee7865badba7f9cc54872c7b404e779"
PRIVATE_BLOCK_R12B = "b4f73a054afed47450ff846218a4453607281da16b8bc56dca904a6ee7447108"
PRIVATE_BLOCK_T14 = "295409589f53c74144ce7fe8e9e4571f614660fe69b6f6f3cbd2e382b5940256"      # = t13
RUN_R12 = "5c9f0ffc12a2a4bdc239799dde6e0c3eab3f316a7bcc6ca071719407b9e96a8d"               # = R12b
RUN_T14 = "51e8aed2c52d21149618f0ba7f16c35774dd376c4bc0c557d6c2c7ef1e4ea6e9"               # = t13
RUN_CAPTURE_R12 = "50221a02f873d98be98aaeb94b09ea5c86a6adafcfbc03160c118aa85a2a4927"
RUN_CAPTURE_R12B = "8721e83d277f4ee853603bc8d5fe63f60b2b3917b9fbee7ed2123e25d0ec76db"
RUN_CAPTURE_T13 = "2329306125671947d877431b33636c6f2dcfbe9a73f89c9d5586e4087647712f"
RUN_CAPTURE_T14 = "ef9c54dbdf9588df381055b6f959ee8d7a9f8396075c59bf2b774115b76cb012"       # r13 -> r14: the parent reads it
ROPE_R12 = "a2f34537ecebe4db8b477fca3a7bbd83ae7f62ae9ca042dc4dbe0031236b901f"              # NEW at R12; = R12b = t13 = t14
TIED_TABLES_R12B = "901fa1e4f4a1c4c5070665fc1f81534142038e362408bff4dbcb5fca1e57c8b2"      # NEW at R12b
TIED_TABLES_T14 = "049ddc181ca31435681e24199b80c03b4ffc494898be80f8515156652df1a7ce"       # = t13
DERIVE_R12B = "e2b76895fae1ee04a469f095153d8451969c637ca4dd5939dd937c159d749adf"           # NEW at R12b
DERIVE_T14 = "5cebeef0f0deea3973898648f87e1905ed87c76ddc6ceaf5a24ab742429a4f41"            # = t13

ARG, SHP, WIT, PAD = ("src/private_block/argument.rs", "src/private_block/shape.rs",
                      "src/private_block/witness.rs", "src/private_block/pad.rs")
TST, TBK, PBR = ("src/private_block/trained_statement.rs", "src/private_block/trained_block.rs",
                 "src/private_block.rs")
RUN, RCP, ROPE = ("src/private_block/run.rs", "src/private_block/run_capture.rs", "src/private_block/rope.rs")
TTB, DRV = ("src/private_block/tied_tables.rs", "src/private_block/tied_tables/derive.rs")

# the digest every chain must end at (None: the file is new in the chain)
CHAIN_ROOTS = {
    ARG: ARGUMENT_R9, SHP: SHAPE_R9, WIT: WITNESS_R9, PAD: PAD_R9, TST: TRAINED_STATEMENT_R9,
    TBK: TRAINED_BLOCK_R9, PBR: PRIVATE_BLOCK_R9, RUN: RUN_R9,
    RCP: (RUN_CAPTURE_R9, RUN_CAPTURE_TOKEN_R12), ROPE: None, TTB: None, DRV: None,
}

# the terminal digests: the capture tree (token frozen-r14) and native R12b
TOKEN_R14_DIGESTS = {
    ARG: ARGUMENT_R12, SHP: SHAPE_R12, WIT: WITNESS_R12, PAD: PAD_R12, TST: TRAINED_STATEMENT_R12B,
    TBK: TRAINED_BLOCK_T14, PBR: PRIVATE_BLOCK_T14, RUN: RUN_T14, RCP: RUN_CAPTURE_T14,
    ROPE: ROPE_R12, TTB: TIED_TABLES_T14, DRV: DERIVE_T14,
}
NATIVE_R12B_DIGESTS = {
    ARG: ARGUMENT_R12, SHP: SHAPE_R12, WIT: WITNESS_R12, PAD: PAD_R12, TST: TRAINED_STATEMENT_R12B,
    TBK: TRAINED_BLOCK_R12B, PBR: PRIVATE_BLOCK_R12B, RUN: RUN_R12, RCP: RUN_CAPTURE_R12B,
    ROPE: ROPE_R12, TTB: TIED_TABLES_R12B, DRV: DERIVE_R12B,
}

# git blob ids (sha1 of "blob <len>\0" + bytes, computed, no git write) and byte lengths
FILE_FACTS = {
    ARGUMENT_R12: ("a331c48906517a1f807b59262591520c27b0bbce", 111325),
    SHAPE_R12: ("eb0a3d543996155fdc7111c92f3b7a146f16174c", 139369),
    WITNESS_R12: ("ed412cbde8c7ad692e7c145ae925178776c6f237", 41694),
    PAD_R12: ("a9800b19c4e799ab46c095a8d1a1591c5312a35a", 57259),
    TRAINED_STATEMENT_R12: ("3d8d4f33fb4f224f0fc6d6a99ad35d1ba77610ec", 44908),
    TRAINED_STATEMENT_R12B: ("e18b5f9cd56f202ac9d9ca291466e962814586e0", 45013),
    TRAINED_BLOCK_R12: ("9a8e0b085bb34402133379bed45ed3303248d224", 172372),
    TRAINED_BLOCK_R12B: ("f3b951265da0c7bd095e5ec97fde5856e1e53052", 173673),
    TRAINED_BLOCK_T14: ("e062ea9e7151cec44e42b287b15f246a3e2e5cef", 173783),
    PRIVATE_BLOCK_R12: ("6c611ac1ca9176ffb50a0b469e3b2f21243fd782", 63099),
    PRIVATE_BLOCK_R12B: ("083e827bae23005521af90b7a1898191244a12fd", 63149),
    PRIVATE_BLOCK_T14: ("67605232b1bb26e29f5de3bdaa7722e88cde28f9", 63900),
    RUN_R12: ("c996bdea5d56be545a30f004a459948212d95667", 81309),
    RUN_T14: ("f2d7d2762924baf048b08459657fc47913b5421b", 86231),
    RUN_CAPTURE_R12: ("c902fa92fe0560d536de743cc491f19f7f34d722", 88191),
    RUN_CAPTURE_R12B: ("d3ffee1cdc8260f97703a2a8dcab53edf0455648", 88425),
    RUN_CAPTURE_T13: ("9f3746ff40ac8523ae5c618ddf6f7b1a1132ee01", 160977),
    ROPE_R12: ("66e816e11df610781f4dbf7591b639b41a8ab000", 11904),
    TIED_TABLES_R12B: ("e70eb4f4472323cf459c03f6e6c3dffe1f74300e", 4561),
    TIED_TABLES_T14: ("dd73dcecf741ac95600e540488d5c70709f5867a", 4709),
    DERIVE_R12B: ("1a4b45fe85ea030e3cfe1e17faaa90ba616c0927", 19894),
    DERIVE_T14: ("271d7117c99616cfdc58105a82b024cb0668e94e", 19927),
}

_P = "[GATE ROUND 18, native R12b] "


def _r(base, stat, reading, receipt=False, stage=False):
    return {"base": base, "diff_stat": stat, "moves_a_receipt_byte": receipt,
            "moves_a_block_stage_byte": stage, "reading": _P + reading}


# file -> new digest -> its reading against `base`
NATIVE_R12B_READINGS = {
    ARG: {
        ARGUMENT_R12: _r(ARGUMENT_R9, "+11 / -7, 1 hunk against 112352bc (native R9)",
            "ONE hunk, unconditional (no profile gate), inside the `SC_QMM | SC_KMM | SC_VMM | SC_WO` "
            "arm only (argument.rs:1323-1354 in the new tree).  The arm's tuple gains `inner`: SC_QMM "
            "(A_Y, wq, outer `sh.q_pad()` [was `sh.d_pad`], inner `sh.d_pad`); SC_KMM / SC_VMM (A_Y, wk / "
            "wv, `kvw`, `sh.d_pad`) as before; SC_WO (A_O8, wo, `sh.d_pad`, inner `sh.q_pad()` [was "
            "`sh.d_pad`]).  The coordinate tail `rho(0..ld)` becomes `rho(0..lg(inner))` (`ld = "
            "lg(sh.d_pad)`, argument.rs:1187) and the public fold `fold_rows_i8(w, outer, sh.d_pad, ..)` "
            "becomes `fold_rows_i8(w, outer, inner, ..)`.  `q_pad() = h_pad * head_dim` (shape.rs:1935) "
            "equals `d_pad` at every shape R9 could build (R9's `Shape::build` refused otherwise) and, by "
            "the registry's arguments, at every pre-R12 profile [COUNTED]; so the challenge `r_j` of "
            "length lg(outer), the coordinate list, the folded public row and the push order "
            "(a_at(plane, coords), public(fold), finish v0*v1) are R9's byte for byte at the "
            "TinyLlama T32 / token / classifier / rung-TC / registered-rung profiles, DD or not.  Only "
            "rung-HD (q_pad 512 > d_pad 256) takes another length.  The bilinear arms SC_SCORE "
            "(argument.rs:1395) and SC_PV (1431) with stage 20's repaired definition (1356), the DD arms "
            "of SC_SZC / SC_DD, every other arm, `run_slot`'s M-functional block (488), `sum_weights` "
            "(477), the slot loop over `n_slots` and the functional guard `n_functionals` are outside the "
            "hunk.  Run transcript: no absorb, draw, label or order moves at those profiles; plane lists, "
            "mask rows / functionals, schedule lines, profile texts, statement identity and capture "
            "fields untouched.  The D24 review's seeded goldens (TinyLlama T128, 8B T128, both DD) match "
            "R9 (REVIEW_R12.md section 1)"),
    },
    SHP: {
        SHAPE_R12: _r(SHAPE_R9, "+147 / -8, 10 hunks against e214db86 (native R9)",
            "Hunk 1 (+21/-1): the four Shieldstral profile strings, `SHIELDSTRAL_PROFILES` (shape.rs:122), "
            "`TRAINED_HD_RUNG_PROFILE` (129); `DD_PROFILES` [3] -> [5] appending the two Shieldstral DD "
            "strings (131; the three old entries in place, so `dd_cap` (791: membership) is unchanged at "
            "every old profile).  Hunks 2-3: `TRAINED_CALIBRATION_PROFILES` [10] -> [15], the five new "
            "profiles appended (143; used by membership only: shape.rs:1528/1575, protocol.rs:897, "
            "layout.rs:1248).  Hunk 4: `trained_rope_theta` gains a Shieldstral arm before the "
            "calibration-profile arm (an old profile gets the same base).  Hunk 5 (+41): "
            "`SHIELDSTRAL_ROPE_THETA`, `trained_rope_scaling` (Shieldstral -> YaRN, every other "
            "calibration profile -> `RopeScaling::None`, others None; 261), `rope_tables_for` (274: "
            "`rope::rope_tables(tokens, head_dim, theta, &scaling, layout::F_RO)`, which for None IS "
            "`tables_attn::rope_tables_generate` with R9's arguments, rope.rs:219-221), "
            "`shieldstral_log_cols`.  Hunks 6-7: the `ss` closure and the five new `trained_geometry` "
            "arms; every old arm is outside the hunks.  Hunk 8 (+6/-5): R9's refusal `d_pad != h_pad * "
            "head_dim` REMOVED (comment at 724-729); every shape that passed it has q_pad == d_pad "
            "(REVIEW_R12 N-1: geometry binding now rests on CS-7's registry comparison).  Hunk 9 (+54): "
            "`shieldstral_trained` / `_dd`, the `#[cfg(test)]` `shieldstral_at`, `rung_hd`, "
            "`q_width()` = q_heads*head_dim and `q_pad()` = h_pad*head_dim (1935).  Hunk 10 (+3/-1): "
            "in `slots()`' `inner`, SC_WO's round count `clog2(d_pad)` -> `clog2(q_pad())` (2279): the "
            "identity at q_pad == d_pad, so every (n, e, d) triple, `slot_terms`, `slot_lengths`, "
            "`n_slots` (2482), `m_rows` (2486), `n_functionals` (2491), the plane-domain lists and "
            "lookup domains are R9's at every old profile.  No profile text, transcript, slot, plane, "
            "mask row / functional or schedule line of an old profile moves"),
    },
    WIT: {
        WITNESS_R12: _r(WITNESS_R9, "+18 / -11, 8 hunks against d1a85918 (native R9)",
            "All unconditional and the identity at q_pad == d_pad (Dom::Q's size t_pad*h_pad*head_dim "
            "== Dom::D's t_pad*d_pad there).  Hunks 1-2: `Geom.q_pad` = `s.q_pad()` (witness.rs:249).  "
            "Hunks 3 and 5: comments only.  Hunk 4: `qix` stride `d_pad` -> `q_pad` (278).  Hunk 6: `ql "
            "= g.len(Dom::Q)` (688); the Q matmul writes width / stride `q_pad` and length `ql` (693), "
            "the Q rotation stride `q_pad`, length `ql`.  Hunk 7: `oacc` of length `ql` (728).  Hunk 8: "
            "the Wo matmul reads stride `q_pad` (866).  The quantize calls, shifts, supports, rounding "
            "and every other plane are outside the hunks.  The witness decides private values only; at "
            "the old profiles every plane value is R9's.  No transcript, slot, mask or statement "
            "byte"),
    },
    PAD: {
        PAD_R12: _r(PAD_R9, "+3 / -2, 2 hunks against 20afa04f (native R9)",
            "Hunk 1: `head_indicator` (pad.rs:82, `#[cfg(test)]` at 81), the Dom::Q stride `d_pad` -> "
            "`q_pad()` (94): TEST-ONLY.  Hunk 2: `closed_form_indicator` (production), Dom::Q's row "
            "stride factor `(d_pad, ..)` -> `(s.q_pad(), ..)` plus a comment (173-174), unconditional, "
            "the identity at q_pad == d_pad (local `d_pad = s.d_pad`).  Every indicator, support factor "
            "and pad term at the old profiles is R9's"),
    },
    TST: {
        TRAINED_STATEMENT_R12: _r(TRAINED_STATEMENT_R9, "+129 / -0, 16 hunks against ac61bf90 (native R9)",
            "Insert-only.  (1) `ModelSource::shieldstral_1_0_3b()` and a Shieldstral arm in "
            "`pinned_for_profile` (after the TinyLlama and 8B arms).  (2-6) `rope_scaling` in "
            "`IntegerCalibration` (bytes, `b\"none\"` for no transform) and in `Provenance` (default "
            "`RopeScaling::None`), carried through `as_the_code_proves` / `provenance()`.  (7) `check`: at "
            "a trained shape the bytes must equal `trained_rope_scaling(profile).encode()` (369-374; "
            "every trained shape is a calibration profile, so the pin exists and is `none` off "
            "Shieldstral); off a trained shape a non-`none` transform is refused.  (8) `TiedEmbedding`, "
            "`tied_tensor_for_profile` (566: Some only at SHIELDSTRAL_PROFILES) and the pinned tensor "
            "constants.  (9-11, 13) the `tied` field, `new` = `new_with_tied(.., None)`.  (12) the "
            "`#[cfg(test)]` synthetic constructors.  (14) `check_self`: (None, None) at an untied "
            "profile; a tied record refused there, required at Shieldstral (760).  (15) `encode`: the "
            "five tied fields ONLY `if let Some(t) = &self.tied` (801), after source-layers.  (16) "
            "`encode`: `rope-scaling` ONLY when the bytes are not `none` (845).  The geometry words "
            "(tokens..opened-cols), the schema, every other field and their order are outside the "
            "hunks, so the canonical bytes and `identity()` are R9's at every old profile (tied None, "
            "scaling none).  REVIEW_R12 section 1: the five synthetic statement identities match R9 "
            "[MEASURED there]"),
        TRAINED_STATEMENT_R12B: _r(TRAINED_STATEMENT_R12, "+4 / -2, 1 hunk against 0fbf90ed (native R12)",
            "COMMENT ONLY: `TiedEmbedding`'s doc comment says R12b's loader recomputes the tables from "
            "the authenticated checkpoint and that a declaration alone does not establish a tie.  No "
            "code line"),
    },
    TBK: {
        TRAINED_BLOCK_R12: _r(TRAINED_BLOCK_R9, "+248 / -23, 24 hunks against 357e2797 (native R9)",
            "The export reader / CLI bridge (no protocol code).  (1) imports: `layout::F_RO` dropped, "
            "`rope::RopeScaling`, `tied_tensor_for_profile`, `TiedEmbedding`.  (2) two new scope "
            "strings (Shieldstral, rung-HD).  (3) +113: `rope_scaling_of` (absent / null / `default` -> "
            "None, else yarn / llama3, `check()`), `tied_of` ((None, None) -> Ok(None) before reading "
            "anything, 543), `sha256_file`.  (4-10) `Geometry`: variants Shieldstral(T), "
            "ShieldstralDd(T), RungHdDev, their parse names, `dd()`, the new `shape_profile()`, "
            "`is_dd` / `is_shieldstral`, `tokens`, `rope_theta`, `rope_scaling()` (None off "
            "Shieldstral), `run_profile`, `run_shape`, `scope`, `shape_at` arms -- every old variant's "
            "arm returns what it returned.  (11, 15) `TrainedExport.rope_scaling / tied`.  (12) "
            "geometry inference: a Shieldstral-repo arm before the 8B arm (873; TinyLlama and 8B repos "
            "fall through as before).  (13) the Shieldstral model-pin check; the rung arm admits "
            "RungHdDev.  (14) `checkpoint_layers` for RungHdDev; the export's `rope_scaling` must equal "
            "the geometry's (1027-1031) and `tied_of` (1032): the exports checked (TinyLlama, 8B, the "
            "classifier fixture `rung-tc-t32-dev`) carry neither key [READ: profile.json keys], so None "
            "/ None and no new refusal.  (16-17, 19) `qw = sh.q_width()` (1205): the expected wq / wo "
            "shapes [qw, d] / [d, qw] and `pad_matrix(wq, qw, d, qp, dp)` / `pad_matrix(wo, d, qw, dp, "
            "qp)` (1295, 1298) -- the identity where q_width == width and q_pad == d_pad, true at every "
            "old trained geometry [COUNTED].  (18) the RoPE generator `rope_tables_for(sh, theta)` "
            "(1263) = R9's `rope_tables_generate(tokens, head_dim, theta, F_RO)` at RopeScaling::None.  "
            "(20) Provenance's `rope_scaling` and `new_with_tied(.., self.tied.clone())` (None off "
            "Shieldstral).  (21-24) `stack_scope(ex.geometry)` = `STACK_SCOPE` byte for byte off "
            "Shieldstral, in the statement JSON and the prove / verify event lines.  The padded words, "
            "block digests, statement files, context label and every check of an old geometry are "
            "R9's; no receipt, stage, statement-identity or capture byte moves"),
        TRAINED_BLOCK_R12B: _r(TRAINED_BLOCK_R12, "+29 / -21, 4 hunks against c6d87b6e (native R12)",
            "(1) `tied_of`'s doc comment.  (2) `tied_of` after the match (reached only at (Some, Some), "
            "i.e. a Shieldstral geometry with a declaration: (None, None) returns at 543 first): exact "
            "dtype / shape / length per table, `tied_tables::hash_regular_exact` in place of the "
            "unbounded `sha256_file` (removed), then `recompute_declared_tied_tables` (600) and equality "
            "of the three digests (R12-F1 / F2).  (3) `load_layer_mode`: `--rope-from-export` refused "
            "when `self.rope_scaling != RopeScaling::None` (1171; None at every old geometry, so no "
            "effect there; R12-F3).  (4) `STACK_SCOPE_SHIELDSTRAL`'s text (Shieldstral only).  Nothing "
            "at an old geometry moves (REVIEW_R12B section 4)"),
        TRAINED_BLOCK_T14: _r(TRAINED_BLOCK_R12B, "+10 / -10, 8 hunks against e2551aa1 (native R12b)",
            "The token lane's ten visibility words, `fn` -> `pub(crate) fn` on flags, flag, need, js, "
            "refuse_prover_private_entries, write_new, stack_context, render_segments_json, "
            "check_statement_dir, publish_statement_dir -- the same ten frozen-r7 / frozen-r12 carry "
            "on native R8 (`0943bade`, read for frozen-r7): applying exactly those ten replacements to "
            "R12b's bytes gives f892dbc7, and to R8's `cc401eb4` gives 0943bade [COUNTED].  No body, "
            "string or check changes"),
    },
    PBR: {
        PRIVATE_BLOCK_R12: _r(PRIVATE_BLOCK_R9, "+16 / -3, 4 hunks against 5e50acd5 (native R9)",
            "(1) `mod rope;` (production module, public tables only).  (2) `#[cfg(test)] mod "
            "r12_tests; mod r12_golden_tests;`.  (3) `Axis::len`: `Axis::Q => sh.q_pad()` (was the "
            "shared `Axis::D | Axis::Q => sh.d_pad`): the P-2 support check's axis length.  (4) "
            "`check_words`: the wq / wo length check `q * d` with `q = sh.q_pad()` (was `d * d`).  "
            "(3) and (4) are statement-shape refusals, unconditional, the identity at q_pad == d_pad.  "
            "`ExpectedIo`, `IoSpec`, `calibration_identity`, `expected.to_bytes()` and every absorbed "
            "word are outside the hunks"),
        PRIVATE_BLOCK_R12B: _r(PRIVATE_BLOCK_R12, "+3 / -0, 2 hunks against 3810bdab (native R12)",
            "`pub mod tied_tables;` (the R12b module, reached only from `tied_of` and the "
            "`zk60_tied_tables` example) and `#[cfg(test)] mod r12b_tests;`.  No item moves"),
        PRIVATE_BLOCK_T14: _r(PRIVATE_BLOCK_R12B, "+10 / -0, 1 hunk against b4f73a05 (native R12b)",
            "The token lane's one hunk after the trained_block re-export: `pub use token_io::cli::{..5 "
            "token commands}`, round 12's `pub use token_io::classify_cli::{classify_input_owner_command, "
            "classify_label_command, classify_prove_command, classify_verify_command}`, and "
            "`#[allow(dead_code)] mod token_io;` with comments (private_block.rs:122-131) -- "
            "BYTE-IDENTICAL, line for line, to frozen-r12's single hunk against native R8 (`a9727239` "
            "vs `08551c3d`, read in v19/v20) [COUNTED].  No block item moves"),
    },
    RUN: {
        RUN_R12: _r(RUN_R9, "+31 / -2, 5 hunks against cf80735d (native R9)",
            "(1) five run-profile constants (four Shieldstral, rung-HD; run.rs:152-157 in frozen-r14).  "
            "(2) their `registered_block_shape` arms.  (3) the Shieldstral block profiles' run "
            "profiles in `run_profile_of` and the refusal text widened.  (4) `RunShape::rung_hd` (324).  "
            "(5) the unbound-run refusal also names the five new run profiles (392).  All gated by "
            "profile name; the header, stage order, boundary absorb, position tags, opening order, "
            "`stage_shape`, `capture_header` and the commitment row list are outside them"),
        RUN_T14: _r(RUN_R12, "+62 / -0, 4 hunks against 5c9f0ffc (native R12 = R12b)",
            "The token lane's hunks, insert-only: (1) the five TOKEN_IO run-profile constants, "
            "`TOKEN_IO_RUN_PROFILES`, round 12's `RUN_PROFILE_CLASSIFY_RUNG_TC` and "
            "`CLASSIFY_RUN_PROFILES` (run.rs:97-143); (2) six `registered_block_shape` arms (token "
            "rung and classifier rung -> `Shape::rung_tc`, the four token trained shapes; 190-195); "
            "(3) the blocks-only refusal of a token-I/O run profile (439); (4) `token: None` and "
            "`classify: None` in `capture_header`'s RunHeader (756, 758; `capture_header` is "
            "`#[cfg(test)]`, 711).  The 62 added lines are BYTE-IDENTICAL, hunk for hunk, to the "
            "v20 capture tree's run.rs (`ebc64fd1` = frozen-r12 `10cfc2b1` + the gate's `classify: "
            "None` hook) against native R8 `d913a081`; equivalently frozen-r14 = `ebc64fd1` plus "
            "exactly native R8 -> R12b's five hunks (+50 / -3) [COUNTED].  So every block, token and "
            "classifier profile builds what the captured trees built; the round-16 hook is now in the "
            "frozen token tree, still test-only"),
    },
    RCP: {
        RUN_CAPTURE_R12: _r(RUN_CAPTURE_R9, "+4 / -1, 2 hunks against e1c87a07 (native R9)",
            "TEST-ONLY module (`#[cfg(test)] mod run_capture;`, private_block.rs:242-243).  "
            "`OWN_SOURCE_FILES` [17] -> [18], appending `src/private_block/rope.rs` with a comment.  "
            "Capture metadata only: a bundle's `source_pins` gains one entry (pure addition, as the "
            "list's own doc says).  No run.json / stage key, allow-list entry, replay or writer path "
            "moves"),
        RUN_CAPTURE_R12B: _r(RUN_CAPTURE_R12, "+5 / -1, 2 hunks against 50221a02 (native R12)",
            "TEST-ONLY.  `OWN_SOURCE_FILES` [18] -> [20], appending `tied_tables.rs` and "
            "`tied_tables/derive.rs` with a comment.  Capture metadata only (two more `source_pins`)"),
        RUN_CAPTURE_T13: _r(RUN_CAPTURE_TOKEN_R12, "+573 / -2, 15 hunks against aaff4e6e (token frozen-r12; "
            "16 under diff -U0); against the v20 capture copy d1e25882: +11 / -4, 5 hunks",
            "TEST-ONLY.  Every line accounted for [COUNTED]: (a) 562 of the 564 round-16 hook lines "
            "(v20 HOOKED_READINGS `d1e25882` = aaff4e6e + 564 insert-only: RunHeader.classify / "
            "ClassifyFacts and its header re-check, the classifier stage begin, write_stage_classify / "
            "write_run_classify, schema hashline-native-capture/7-classify-run, the classifier pins, "
            "the README) VERBATIM, in the same 12 hunks (13 under -U0, v20's count); (b) native R8 -> "
            "R12b's three hunks carried by the rebase, +9 / -2: `OWN_SOURCE_FILES` [23] -> [26] (the "
            "native 17 -> 20 plus the token lane's six), the seven lines pinning rope.rs, "
            "tied_tables.rs and tied_tables/derive.rs, and R9's `sh.slots().iter().take(sh.n_slots())` "
            "in run.json's slot list (with R12's `slots()` returning MAX_SLOTS = 24 entries, the take "
            "keeps 23 off DD: R8's list, the R9 reading); (c) two hook lines changed, +2: "
            "`CLASSIFY_SOURCE_FILES` [4] -> [5] inserting `src/private_block/token_io/classify_tied.rs` "
            "second, and the classifier README's \"the classifier's four included\" -> \"five\".  562 + "
            "9 + 2 = 573 added; removed: the [23] count line and R8's untaken slots line.  Effect: every "
            "bundle's `source_pins` gains three entries, a classifier bundle's a fourth, and a "
            "classifier README one word; no run.json / stage key, recorded value, allow-list entry, "
            "replay check or block / token writer path moves.  The r13 -> r14 step (+11, ef9c54db) is "
            "the parent's"),
    },
    ROPE: {
        ROPE_R12: _r(None, "NEW at native R12 (239 lines, 11904 bytes), read in full; = R12b = t13 = t14",
            "`RopeScaling` {None, Llama3{..}, Yarn{..}}: `shieldstral()` (YaRN factor 16, original "
            "16384, beta 32 / 1, mscale 1 / 1, truncate), `llama3_1()` (no profile uses it), "
            "`attention_factor`, `check` (finite ranges; an attention factor other than exactly 1 "
            "refused by name), `encode` / `decode` (canonical bytes `none` | `llama3`+4 x 8 | `yarn`+6 "
            "x 8+1, decode re-encodes and compares), `describe`, `inv_freq` (transformers' reference "
            "formulas, binary64), and `rope_tables(t, head_dim, theta, s, f_ro)`: for `None` it RETURNS "
            "`tables_attn::rope_tables_generate(t, head_dim, theta, f_ro)` before anything else "
            "(219-221), else cos / sin rounded half up at 2^f_ro.  No transcript, hash, commitment or "
            "relation: it decides PUBLIC tables only.  Reached from `shape::rope_tables_for` (the trained "
            "loader, trained_block.rs:1263; parity.rs is test-only), `trained_statement` (the encoded "
            "`none` bytes, never written into the identity) and trained_block's `rope_scaling_of` / "
            "`Geometry::rope_scaling`.  At TinyLlama, 8B, rung-TC (hence the token rung and the "
            "classifier rung, whose blocks are rung-TC) and the DD rung, `trained_rope_scaling` is "
            "`None`, so the frozen generator's tables, byte for byte (REVIEW_R12 test A: 15 existing "
            "shapes keep the frozen generator)"),
    },
    TTB: {
        TIED_TABLES_R12B: _r(None, "NEW at native R12b (100 lines, 4561 bytes), read in full",
            "Bounded public-file reads: `regular()` (symlink_metadata, size bound / exact, O_NOFOLLOW | "
            "O_NONBLOCK on linux x86_64, descriptor re-check incl. dev / inode), `range_hash`, "
            "`hash_regular_exact` (SHA-256 of exactly `length` bytes, refuses growth / truncation); "
            "`mod derive` and its re-exports; a `#[cfg(test)]` test.  SHA-256 over public token-table "
            "files only (outside the proof's BLAKE3 oracle classes, s25 census C1); no proof transcript, "
            "absorb or commitment.  Called only from `trained_block::tied_of` after its (None, None) "
            "early return, i.e. only at a Shieldstral geometry with a tie declared, and from the "
            "`zk60_tied_tables` example"),
        TIED_TABLES_T14: _r(TIED_TABLES_R12B, "+2 / -0, 1 hunk against 901fa1e4 (native R12b)",
            "One re-export with its comment: `pub(crate) use derive::{bf16, norm, quantize};` \"for the "
            "classifier's development-rung tied source\" (token lane R-C2).  No body changes.  The "
            "caller is the token lane's `token_io/classify_tied.rs` (not read here)"),
    },
    DRV: {
        DERIVE_R12B: _r(None, "NEW at native R12b (334 lines, 19894 bytes), read in full",
            "The Shieldstral tied-table re-derivation (R12-F1): constants (width 3072, vocab 131072, "
            "the tensor and norm names, checkpoint length 7,698,241,104, a default local checkpoint "
            "path); `norm` (final-norm class, the classifier window tn = 10, ceps < 2^40); "
            "`calibration` (profile model pin = Shieldstral, `token_io_parameters` bos = 1 and both "
            "final norms equal to the export's constants); `tied_token_calibration`; `extent` "
            "(safetensors BF16 extents); `Checkpoint::open` (bounded regular open, header length "
            "bound, SHA-256 of the WHOLE file against the pinned weights digest while capturing the "
            "norm bytes and re-checking the header, no independent lm_head); `rotate` (signed block "
            "Hadamard), `quantize` (floor(x/scale + .5), refuse outside the range, no clip), "
            "`head_row`; `recompute_tied_tables` / `recompute_declared_tied_tables` (the profile "
            "re-read and compared) / `recompute_profile` (three 1024 blocks, rotation signs digest, "
            "the tensor digest re-checked, embedding / head / multiplier SHA-256, an optional margin "
            "row); `#[cfg(test)]` tests.  SHA-256 over model and table files only; no proof "
            "transcript.  Reached only through `tied_of` at a Shieldstral geometry, the example, and "
            "(in the token tree) the token lane's classify_tied.rs"),
        DERIVE_T14: _r(DERIVE_R12B, "+3 / -3, 3 hunks against e2b76895 (native R12b)",
            "Three visibility words, `fn` -> `pub(crate) fn` on `norm`, `bf16` and `quantize` "
            "(REVIEW_R13's note); applying exactly those to R12b's bytes gives 5cebeef0 [COUNTED].  "
            "No body changes"),
    },
}

# ---------------------------------------------------------------- the per-port tables, R9 format

REPORT_ONLY = {   # the token frozen-r14 digests (the capture tree)
    WIT: (WITNESS_R12, NATIVE_R12B_READINGS[WIT][WITNESS_R12]["reading"]),
    TST: (TRAINED_STATEMENT_R12B, _P + "read via 0fbf90ed against R9's ac61bf90 (NATIVE_R12B_READINGS): "
          "insert-only; the five tied fields and the rope-scaling field enter `encode` only at a tied "
          "model / a scaled RoPE, so the identity of every old profile's statement is R9's; R12b's step "
          "is a comment"),
    TBK: (TRAINED_BLOCK_T14, _P + "read via e2551aa1 (R12b) and c6d87b6e (R12) against R9's 357e2797: "
          "Shieldstral / rung-HD geometries, the RoPE transform and tie declarations (None / None at "
          "every old export), the q-axis identities, `stack_scope` = STACK_SCOPE off Shieldstral, "
          "R12b's tie re-derivation behind `tied_of`'s early return, and the token lane's ten "
          "visibility words"),
    PBR: (PRIVATE_BLOCK_T14, _P + "read via b4f73a05 (R12b) and 3810bdab (R12) against R9's 5e50acd5: "
          "`mod rope`, `pub mod tied_tables`, test modules, the q-axis weight-shape refusals (identity "
          "at q_pad == d_pad), and the token lane's one hunk byte-identical to frozen-r12's"),
    ROPE: (ROPE_R12, NATIVE_R12B_READINGS[ROPE][ROPE_R12]["reading"]),
    TTB: (TIED_TABLES_T14, _P + "read in full at 901fa1e4 (R12b) plus the token lane's one re-export: "
          "bounded SHA-256 of public files, reached only at a Shieldstral tie (and by classify_tied.rs)"),
    DRV: (DERIVE_T14, _P + "read in full at e2b76895 (R12b) plus three visibility words: the "
          "Shieldstral tied-table re-derivation, no proof transcript"),
}
REPORT_ONLY_NATIVE_R12B = {   # the same files at the native R12b digests, should a native capture pin them
    TBK: (TRAINED_BLOCK_R12B, NATIVE_R12B_READINGS[TBK][TRAINED_BLOCK_R12B]["reading"]),
    PBR: (PRIVATE_BLOCK_R12B, NATIVE_R12B_READINGS[PBR][PRIVATE_BLOCK_R12B]["reading"]),
    TTB: (TIED_TABLES_R12B, NATIVE_R12B_READINGS[TTB][TIED_TABLES_R12B]["reading"]),
    DRV: (DERIVE_R12B, NATIVE_R12B_READINGS[DRV][DERIVE_R12B]["reading"]),
}

# no block-stage byte moves at the captured profiles (readings above), so both terminals stay pinned
TERMINALS_PINNED_IF_PRESENT = {
    SHP: {
        SHAPE_R12:
            _P + "read against `e214db86` (R9): +147 / -8, 10 hunks.  The four Shieldstral profiles and "
            "rung-HD (strings, DD / calibration-profile list membership appended, RoPE base / transform "
            "pins, `ss` and the new `trained_geometry` arms, constructors), `q_width` / `q_pad`, R9's "
            "`d_pad != h_pad * head_dim` refusal removed (every old shape keeps q_pad == d_pad "
            "[COUNTED]), SC_WO's round count `clog2(q_pad())` (the identity there).  Off the new "
            "profiles every value this port reads -- slots' (n, e, d), slot terms / lengths, n_slots, "
            "m_rows, n_functionals, plane domains, lookups, claim sites -- is R9's",
    },
    PAD: {
        PAD_R12:
            _P + "read against `20afa04f` (R9): +3 / -2, 2 hunks.  Dom::Q's row stride `q_pad()` in the "
            "test-only `head_indicator` and in `closed_form_indicator`'s bit form; the identity at "
            "q_pad == d_pad, so every indicator and pad term of an old profile is R9's",
    },
}

MASK_LAYER_PINS = {
    ARG: {
        ARGUMENT_R12: {
            "commits": TREE,
            "bundles": R18_BUNDLES,
            "reading": _P + "read against `112352bc` (R9): +11 / -7, one hunk in the four matmul arms "
            "(q-axis widths, the identity at q_pad == d_pad).  `run_slot`'s M-functional block, `fn "
            "sum_weights`, the host order, the slot loop over `n_slots` and the functional guard "
            "`n_functionals` are outside it, so the declared functional order is R9's (34 off DD, + "
            "SC_DD's two at DD)",
        },
    },
    SHP: {
        SHAPE_R12: {
            "commits": TREE,
            "bundles": R18_BUNDLES,
            "reading": _P + "`n_slots` (shape.rs:2482), `m_rows` = 2 n_slots + 4 (2486), "
            "`n_functionals` (2491) and `slots()`' cube / extension / degree rules are outside the "
            "R12 hunks; SC_WO's round count `clog2(q_pad())` equals R9's `clog2(d_pad)` at every old "
            "profile, so the mask specs (n_slots entries) are R9's; ruling C-4's budget is unchanged",
        },
    },
}

ARGUMENT_DEFINITIONS = {
    ARGUMENT_R12: (
        "repaired",
        _P + "read against `112352bc` (R9, itself R8's repaired definition plus DD arms): +11 / -7, ONE "
        "hunk, in the SC_QMM / SC_KMM / SC_VMM / SC_WO arm (the query axis q_pad for Wq's output and "
        "Wo's input; the identity at q_pad == d_pad, true at every pre-R12 profile).  The bilinear arms "
        "SC_SCORE / SC_PV (stage 20's repaired definition, argument.rs:1356-1456), every other arm and "
        "every push order, DD or not, are byte-identical to R9's",
    ),
}


# ---------------------------------------------------------------- self-checks (cheap, no I/O)
def chain(file: str, digest: str) -> list:
    """the digests from `digest` back along `base` links through NATIVE_R12B_READINGS"""
    out, cur = [digest], digest
    for _ in range(8):
        r = NATIVE_R12B_READINGS.get(file, {}).get(cur)
        if r is None:
            break
        cur = r["base"]
        out.append(cur)
        if cur is None:
            break
    return out


def self_check() -> dict:
    """every terminal digest chains to its root; every digest is 64 hex; no reading moves a byte"""
    bad = []
    hexd = set("0123456789abcdef")
    for f, table in NATIVE_R12B_READINGS.items():
        for d, r in table.items():
            for x in (d, r["base"]):
                if x is not None and (len(x) != 64 or set(x) - hexd):
                    bad.append(f"{f}: digest {x!r} is not 64 hex")
            if r["moves_a_receipt_byte"] or r["moves_a_block_stage_byte"]:
                bad.append(f"{f}: {d[:8]} moves a byte")
    for name, terms in (("token r14", TOKEN_R14_DIGESTS), ("native r12b", NATIVE_R12B_DIGESTS)):
        for f, d in terms.items():
            if f == RCP and name == "token r14":
                d = RUN_CAPTURE_T13   # r13 -> r14 is the parent's reading
            c = chain(f, d)
            roots = CHAIN_ROOTS[f] if isinstance(CHAIN_ROOTS[f], tuple) else (CHAIN_ROOTS[f],)
            if c[-1] not in roots:
                bad.append(f"{name} {f}: chain {[x[:8] if x else x for x in c]} does not reach {roots}")
    return {"ok": not bad, "problems": bad}


OPEN_QUESTIONS = [
    "run_capture.rs frozen-r13 2329306c -> frozen-r14 ef9c54db (+11 / -0, 2 hunks) is not read here (the "
    "parent's step); NATIVE_R12B_READINGS chains run_capture.rs only from 23293061.",
    "token_io/classify_tied.rs (NEW classifier pin in frozen-r13, CLASSIFY_SOURCE_FILES [5]) calls "
    "tied_tables::{norm, bf16, quantize} for the classifier's development-rung tied source (and "
    "recompute_tied_tables on the Shieldstral path); whether that moves a classifier-rung capture byte "
    "belongs to the parent's reading of classify_tied.rs / classify.rs, not to the native files here.",
    "token_io/load.rs (token lane, not read here) now builds a Provenance with `rope_scaling: "
    "ex.rope_scaling` (load.rs:230); at TinyLlama / rung-TC exports that is RopeScaling::None, so the "
    "statement identity would be unchanged -- to be confirmed by the parent's load.rs reading.",
    "Byte identity at the T32 TinyLlama, rung-TC, token-rung and classifier-rung profiles rests on this "
    "reading (q_pad == d_pad and q_width == width at every pre-R12 shape [COUNTED from the registry "
    "arguments]) plus REVIEW_R12's test A and its retained TinyLlama T32 receipt; the seeded R12 goldens "
    "cover only TinyLlama T128, 8B T128 and their DD twins.  No seeded golden at rung-TC / the classifier "
    "rung exists in the native evidence.",
    "Not pinned, so not read for the gate but noted: mvp_driver.rs (NOT_ON_THE_RUNS_PATH) changed R9 -> "
    "R12 at the same q-axis sites (`qw` / `qp` in public_words and block_of; the identity at q_width == "
    "width); parity.rs, r12_tests.rs, r12b_tests.rs, r12_golden_tests.rs, dense / grow / s24 / s25 / s33 / "
    "trained_calib / hash_domain tests are #[cfg(test)].",
    "v20's HOOKED_READINGS counts the d1e25882 hooks as 13 hunks: that is the diff -U0 count; diff -u "
    "gives 12.  The +564 / -0 count agrees.",
    "REVIEW_R12 N-1: with R9's `d_pad != h_pad * head_dim` refusal removed, a consistently edited "
    "geometry is caught by CS-7's registry comparison, not CS-8; every production entry point goes "
    "through a run (CS-7).  Any future block-level entry point must compare with the registry.",
    "frozen-r14 is UNREVIEWED by its lane's own statement (frozen-r14.FROZEN.txt); R18_BUNDLES is empty "
    "until the parent captures.",
]

ANYTHING_THAT_MOVES_A_RECEIPT_BYTE: list = []   # none at the captured profiles

MOVES_ONLY_OUTSIDE_THE_CAPTURED_PROFILES = [
    "NEW profiles only (Shieldstral T128 / T256, each +/- DD, and rung-HD): new profile / run-profile "
    "strings, their shapes (q_width 4096 vs width 3072 at Shieldstral; q_pad 512 vs d_pad 256 at "
    "rung-HD, where the SC_QMM / SC_WO lengths, Dom::Q stride and the witness strides differ), YaRN "
    "tables, the trained statement's tied-embedding fields and rope-scaling field, the Shieldstral "
    "scope strings and the tied-table re-derivation.",
]

CAPTURE_METADATA_CHANGES = [
    "every bundle's source_pins: + src/private_block/rope.rs, + src/private_block/tied_tables.rs, + "
    "src/private_block/tied_tables/derive.rs (OWN_SOURCE_FILES 23 -> 26 in the token tree)",
    "a classifier bundle's source_pins: + src/private_block/token_io/classify_tied.rs "
    "(CLASSIFY_SOURCE_FILES 4 -> 5)",
    "a classifier bundle's README: \"the classifier's four included\" -> \"five\"",
    "run.json's slot list: `take(sh.n_slots())` (23 entries off DD, as R8 / R9 recorded)",
]


if __name__ == "__main__":
    import json
    print(json.dumps(self_check(), indent=1))
