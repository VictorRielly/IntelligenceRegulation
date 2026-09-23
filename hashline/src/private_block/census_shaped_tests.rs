//! **STAGE 38 (TEST-ONLY): THE SHAPED BUILDER-VERSUS-KERNEL REFUSAL CENSUS**
//! — gap GS-14's first item (ruling NL-8 of
//! `ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`, finding N-9 of
//! `ZK60_NONLINEAR_CHANNEL_SHAPED_CHECK.md`).
//!
//! **THE QUESTION.** Completeness for every ADMISSIBLE witness: if the
//! witness builder (`witness.rs`) ADMITS an input on which the prover or the
//! verifier then refuses — a kernel-side overflow, a looked-up word outside
//! its table, a pair that is not a table row — an honest proof fails on a
//! legal input, and a failure that depends on the input leaks. The toy's
//! census (`refusals.rs:270-280`, asserted at `:321-322`) answers it at ONE
//! geometry, from literals: at the toy the output projection sums 16 terms
//! and its site is unreachable. At 125M it sums 768, `|aoacc| <= 768 * 127 *
//! 128 = 12,484,608`, `requant(., 7)` reaches +-97,536 and the site is
//! REACHABLE (N-9). This module is the census at EVERY registered shape, with
//! every bound computed from the [`Shape`] and nothing typed in.
//!
//! **WHAT IS ENUMERATED** (the memo `ZK60_SHAPED_REFUSAL_CENSUS.md` has the
//! full site list with file:line):
//!
//! * every data-dependent refusal of the witness builder (`witness.rs`: the
//!   range sites, the relation sites, the norm's limb window, the `A_E` pad
//!   pass, the output conversion) and of the shaped reference kernel
//!   (`private-block-kernel-shaped/src/lib.rs`: the same range and relation
//!   sites, and its checked-arithmetic `Overflow` sites);
//! * every data-dependent failure of the PROVER / VERIFIER on an admitted
//!   witness (`protocol.rs`): a U8 word outside `[0, 256)` (the histogram's
//!   bucket-0 fallback, `:434-444`, which only the LogUp identity catches), an
//!   exp pair or an activation pair that is not a table row (`:843-853`), and
//!   a LogUp multiplicity that wraps the field;
//! * the CHALLENGE-ONLY refusals are counted per shape by
//!   [`the_challenge_only_refusals_are_counted_per_shape`] and are liveness,
//!   not completeness: `c_s = 0` (`argument.rs:478`), a terminal `e` in
//!   `{0, 1}` (`:587`), the host arms' twelve `nu` draws and the pad-zero
//!   `zeta` draws through `nonzero(..)` (`:949`, drawn at `:1142-1143, 1210,
//!   1405-1406, 1552-1553, 1605-1606, 1663-1664, 1786`), the opening
//!   coefficients (`protocol.rs:246, 300, 309`) and a zero LogUp denominator
//!   (`protocol.rs:492, 569-574`).
//!
//! **THE CLASSES.** `UNREACHABLE`: the worst case over the admissible inputs
//! stays inside the class. `REACHABLE-BUILDER-REFUSES-FIRST`: the worst case
//! leaves the class, and the builder refuses AT THIS SITE, BY NAME, with a
//! class that is exactly the one the kernel refuses and the one the prover's
//! lookups admit — asserted from `lookups_at` itself by
//! [`the_builder_class_of_every_looked_plane_is_the_lookup_window_at_every_shape`]
//! and at the edge by the boundary tests. `FINDING`: reachable and not
//! covered.
//!
//! **ONE FINDING, S38-F1** (first rank; not fixed here, no production file
//! moves): at every shape whose `Dom::F` PADS (the rung, rung-G, rung-K4,
//! rung-K8 — not 125M), the padded positions carry `(g8, a16) = (0, 0)`, so
//! the never-gated activation LogUp arm looks up the pair `(128, 0)`, which
//! is a table row only when `act[128] == 0`. `FeedForwardPublic::new_shaped`
//! admits any `[i16; 256]`, and the witness builder admits every input under
//! such a table, so a legal statement with `act[128] != 0` makes EVERY honest
//! proof at those shapes fail. It depends on the PUBLIC table and the shape
//! only — the same for every private input — so it leaks nothing private;
//! it is a completeness hole in the public-statement admissibility, recorded
//! with an `#[ignore]`d reproducer. Every SiLU member has `act[128] = 0`,
//! which is why no rung proof ever met it.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A completeness census of the
//! builder, the kernel and the prover's lookups on the admissible class. It is
//! NOT a privacy result, NOT a soundness statement (the field-wrap premise of
//! `layout.rs:639-648` is soundness and is not re-derived here), and it does
//! not cover the hash layer, the PCS or the endpoint constructions beyond
//! their data-independent refusals.
//!
//! **THE CAPTURE RULE.** Everything proved here is PUBLIC SYNTHETIC test data
//! with hand-chosen integers; the prints are shape-derived bounds, site names
//! and the edge values the families were built to hit.

use super::layout::*;
use super::protocol::{act_indices, exp_deltas, lookup_values};
use super::review_tests::{outcome, Outcome};
use super::shape::{Shape, LIMBS_ISQRT};
use super::witness::{self, Witness};
use super::*;
use private_block_kernel_shaped as kshaped;
use std::collections::BTreeSet;

// ---------------------------------------------------------------- the admissible class

/// the attention int8 subset (`y`, `nm`, `q8`, `k8`, `v8`, `qr8`, `kr8`, `s8`, `o8`)
const I8N: (i128, i128) = (-127, 127);
/// the gate's class, which INCLUDES -128 (the activation table has 256 rows)
const I8: (i128, i128) = (-128, 127);
/// every int16 plane, and the hidden input's own type
const I16: (i128, i128) = (-32768, 32767);
/// `|x|` over the int16 class: `-32768` is a legal input word (`i16`)
const X_ABS: i128 = 32768;
/// `|w|` over the int8 class of every public weight and gain (`i8`)
const W_ABS: i128 = 128;
/// the RoPE tables' fixed-point one, the largest legal `|cos|`, `|sin|`
/// (`AttentionPublic::new_shaped`, `private_block.rs:488`)
const RO_ONE: i128 = 1 << F_RO;
/// the field the prover works in, `p = 2^64 - 2^32 + 1`
const P_FIELD: i128 = (1i128 << 64) - (1i128 << 32) + 1;

/// `requant` over `i128`, the kernel's and the witness's rule (round to
/// nearest, ties toward +inf; the identity at `sh = 0`)
fn rq(acc: i128, sh: u32) -> i128 {
    if sh == 0 {
        acc
    } else {
        (acc + (1i128 << (sh - 1))) >> sh
    }
}

/// `[rq(-m, sh), rq(m, sh)]`: the requantized image of `[-m, m]`
fn rq_sym(m: i128, sh: u32) -> (i128, i128) {
    (rq(-m, sh), rq(m, sh))
}

// ---------------------------------------------------------------- the census rows

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Class {
    Unreachable,
    BuilderRefusesFirst,
    Finding,
}

impl Class {
    fn name(self) -> &'static str {
        match self {
            Class::Unreachable => "UNREACHABLE",
            Class::BuilderRefusesFirst => "REACHABLE-BUILDER-REFUSES-FIRST",
            Class::Finding => "FINDING",
        }
    }
}

/// One data-dependent refusal site at one shape.
struct Row {
    /// the site: the builder's refusal string where there is one
    site: &'static str,
    /// builder file:line / kernel file:line / the downstream check
    at: &'static str,
    /// does any position of this site exist at this shape?
    exists: bool,
    /// the worst case over the admissible class of the value the site tests
    reach: (i128, i128),
    /// the set the value must stay in (the builder's, kernel's and lookup's class)
    range: (i128, i128),
    /// does the builder refuse AT THIS SITE, with THIS range, before the value
    /// reaches anything downstream?
    builder_guards: bool,
}

impl Row {
    fn class(&self) -> Class {
        if !self.exists || (self.range.0 <= self.reach.0 && self.reach.1 <= self.range.1) {
            Class::Unreachable
        } else if self.builder_guards {
            Class::BuilderRefusesFirst
        } else {
            Class::Finding
        }
    }
}

/// The shape-derived facts every row reads.
struct Bounds {
    /// `D_max = isqrt(1 + width * 32768^2)` over the int16 class — note
    /// 32768, not the 32767 `Shape::new` uses for `d_max`: `-32768` is legal
    d_max: i128,
    /// the norm quotient's worst case: `|q| <= floor(|g| / 2 + 1/2)` because
    /// `|x_i| <= D` (`D = isqrt(ceps + sum x^2) >= |x_i|`)
    y_abs: i128,
}

fn bounds(sh: &Shape) -> Bounds {
    let ss_max = NORM_CEPS as i128 + sh.width as i128 * X_ABS * X_ABS;
    let d_max = witness::isqrt(u64::try_from(ss_max).expect("ss fits u64")) as i128;
    Bounds { d_max, y_abs: (W_ABS + 1) / 2 }
}

/// **THE CENSUS AT ONE SHAPE.** Every bound below is computed from `sh`; the
/// only literals are the calibration constants of `layout.rs` (which the
/// kernel's `calib` copies, asserted by `parity.rs`) and the int8 / int16
/// classes the TYPES enforce.
fn census(sh: &Shape) -> Vec<Row> {
    let b = bounds(sh);
    let (d, f, dh, t) = (sh.width as i128, sh.hidden as i128, sh.head_dim as i128, sh.tokens as i128);
    let one_e = 1i128 << sh.f_e;
    let one_p = 1i128 << F_P;
    let isqrt_win = 1i128 << (8 * LIMBS_ISQRT);
    let den_max = b.d_max << (NORM_TN + 1);
    let norm_win = 1i128 << sh.norm_wrho;
    // the output projection's image, then residual 1 over what AO's own check admits
    let ao = rq_sym(d * 127 * W_ABS, SH_AO);
    let ao_admitted = (ao.0.max(I16.0), ao.1.min(I16.1));
    let lookup_pads = LOOKUP_DOMS.iter().any(|dom| sh.pads(*dom));
    let totals = sh.totals();
    let max_count = totals.u8_lookups.max(totals.exp_pairs).max(totals.act_pairs) as i128;
    // the kernel's largest intermediate over every checked op (`lib.rs:124-158`)
    let kernel_max = [
        NORM_CEPS as i128 + d * X_ABS * X_ABS,                              // norm: ss
        2 * X_ABS * W_ABS * NORM_CN as i128 + (b.d_max << NORM_TN),         // norm: numerator
        den_max,                                                            // norm: denominator
        d * b.y_abs * W_ABS + (1 << (SH_QKV - 1)),                          // matmul Q/K/V, FFN gate/up, + rounding bias
        2 * RO_ONE * 127 + (1 << (SH_ROPE - 1)),                            // rope
        dh * 127 * 127 + (1 << (SH_S - 1)),                                 // score
        t * one_e,                                                          // softmax total
        one_e << F_P,                                                       // softmax numerator
        one_p * 127 + (1 << (SH_O - 1)),                                    // PV
        d * 127 * W_ABS + (1 << (SH_AO - 1)),                               // matmul Wo
        2 * X_ABS,                                                          // residuals
        X_ABS * X_ABS + (1 << (SH_H_PROD - 1)),                             // FFN product
        f * X_ABS * W_ABS + (1 << (SH_Z - 1)),                              // matmul Wd
    ]
    .into_iter()
    .max()
    .expect("a kernel bound");
    let mut rows = Vec::new();
    // norm_a reads x_in (int16 by its type); norm_m reads xres1 (int16 by the
    // builder's residual-1 check, which runs before it) — the same class
    for norm in ["norm_a", "norm_m"] {
        rows.push(Row {
            site: "norm denominator",
            at: if norm == "norm_a" { "witness.rs:373-375 (limb window), :385-387 (den <= 0) / kernel lib.rs:557, :561-562 / Dom::L byte limbs of D, a1, a2 [norm_a]" } else { "witness.rs:373-375, :385-387 via :649 / kernel lib.rs:557, :561-562 via :800 / Dom::L byte limbs [norm_m]" },
            exists: true,
            // D >= 1 (ceps = 1) and a2 = 2D - a1 <= 2D
            reach: (1, 2 * b.d_max),
            range: (1, isqrt_win - 1),
            builder_guards: true,
        });
        rows.push(Row {
            site: "norm quotient/remainder (quotient)",
            at: if norm == "norm_a" { "witness.rs:393-395 / kernel lib.rs:569-570 / sym(A_Y) [norm_a]" } else { "witness.rs:393-395 via :649 / kernel lib.rs:569-570 via :800 / sym(A_YM) [norm_m]" },
            exists: true,
            reach: (-b.y_abs, b.y_abs),
            range: I8N,
            builder_guards: true,
        });
        rows.push(Row {
            site: "norm quotient/remainder (remainder window)",
            at: if norm == "norm_a" { "witness.rs:393-395 / kernel lib.rs:569-570 / A_NR*, A_NS* limbs [norm_a]" } else { "witness.rs:393-395 via :649 / kernel lib.rs:569-570 via :800 / A_MR*, A_MS* limbs [norm_m]" },
            exists: true,
            reach: (0, den_max - 1),
            range: (0, norm_win - 1),
            builder_guards: true,
        });
    }
    let qkv = rq_sym(d * b.y_abs * W_ABS, SH_QKV);
    for (site, at) in [
        ("Q", "witness.rs:485 / kernel lib.rs:726 / sym(A_Q8)"),
        ("K", "witness.rs:486 / kernel lib.rs:727 / sym(A_K8)"),
        ("V", "witness.rs:487 / kernel lib.rs:728 / sym(A_V8)"),
    ] {
        rows.push(Row { site, at, exists: true, reach: qkv, range: I8N, builder_guards: true });
    }
    let rope = rq_sym(2 * RO_ONE * 127, SH_ROPE);
    rows.push(Row { site: "QR", at: "witness.rs:490 / kernel lib.rs:732 / sym(A_QR8)", exists: true, reach: rope, range: I8N, builder_guards: true });
    rows.push(Row { site: "KR", at: "witness.rs:492 / kernel lib.rs:733 / sym(A_KR8)", exists: true, reach: rope, range: I8N, builder_guards: true });
    rows.push(Row { site: "score", at: "witness.rs:507 / kernel lib.rs:749 / sym(A_S8)", exists: true, reach: rq_sym(dh * 127 * 127, SH_S), range: I8N, builder_guards: true });
    // MASK is the minimum of the score class and the max takes the FIRST
    // strict maximum, so position 0 (always supported) wins every tie
    rows.push(Row {
        site: "causal maximum attainment",
        at: "witness.rs:525-527 / kernel lib.rs:618-619 / SC_RS selector",
        exists: true,
        reach: (MASK_SCORE as i128, MASK_SCORE as i128),
        range: (i128::MIN, I8N.0),
        builder_guards: true,
    });
    rows.push(Row {
        site: "exp difference",
        at: "witness.rs:533-535 / kernel lib.rs:624-625 / the exp pair lookup",
        exists: true,
        reach: (0, I8N.1 - MASK_SCORE as i128),
        range: (0, 255),
        builder_guards: true,
    });
    rows.push(Row {
        site: "exp difference (the A_E pad pass)",
        at: "witness.rs:639-641 (builder only; no kernel counterpart) / the exp pair lookup on the padded Dom::S cube",
        exists: true,
        // true positions [0, 254]; a padded (h, t) row has A_MX = 0 and A_S8 = 0, so delta is 0 or 127
        reach: (0, I8N.1 - MASK_SCORE as i128),
        range: (0, 255),
        builder_guards: true,
    });
    // `Sum` holds `exp[0] = 2^fE` at the selected position and at most
    // `tokens` entries of at most `2^fE` (the statement's own exp rules)
    rows.push(Row {
        site: "softmax denominator",
        at: "witness.rs:541-543 / kernel lib.rs:632-633 / SC_RS",
        exists: true,
        reach: (one_e, t * one_e),
        range: (one_e, t * one_e),
        builder_guards: true,
    });
    rows.push(Row {
        site: "softmax quotient/remainder (quotient)",
        at: "witness.rs:554-556 / kernel lib.rs:643-644 / A_PL* limbs",
        exists: true,
        reach: (0, one_p),
        range: (0, one_p),
        builder_guards: true,
    });
    rows.push(Row {
        site: "softmax quotient/remainder (remainder window)",
        at: "witness.rs:554-556 / kernel lib.rs:643-644 / A_SR*, A_SG* limbs",
        exists: true,
        reach: (0, t * one_e - 1),
        range: (0, (1i128 << sh.wrho_s) - 1),
        builder_guards: true,
    });
    // the softmax weights of a row sum to at most 2^fP
    rows.push(Row { site: "O", at: "witness.rs:590 / kernel lib.rs:783 / sym(A_O8)", exists: true, reach: rq_sym(one_p * 127, SH_O), range: I8N, builder_guards: true });
    rows.push(Row { site: "AO", at: "witness.rs:594 / kernel lib.rs:793 / A_AL0, A_AL1 limbs of ao + 32768", exists: true, reach: ao, range: I16, builder_guards: true });
    rows.push(Row {
        site: "residual 1",
        at: "witness.rs:599-601 / kernel lib.rs:796-798 / A_X1L0, A_X1L1 limbs",
        exists: true,
        reach: (-X_ABS + ao_admitted.0, I16.1 + ao_admitted.1),
        range: I16,
        builder_guards: true,
    });
    rows.push(Row { site: "FFN gate", at: "witness.rs:667 / kernel lib.rs:808 / the activation pair's index g8 + 128", exists: true, reach: rq_sym(d * b.y_abs * W_ABS, SH_G), range: I8, builder_guards: true });
    rows.push(Row {
        site: "FFN gate (activation index)",
        at: "witness.rs:678-679 / kernel lib.rs:812-813 / the activation pair lookup",
        exists: true,
        reach: (I8.0 + 128, I8.1 + 128),
        range: (0, 255),
        builder_guards: true,
    });
    rows.push(Row { site: "FFN up", at: "witness.rs:671-673 / kernel lib.rs:810 / A_UL0, A_UL1 limbs", exists: true, reach: (-(d * b.y_abs * W_ABS), d * b.y_abs * W_ABS), range: I16, builder_guards: true });
    rows.push(Row { site: "FFN product", at: "witness.rs:683 / kernel lib.rs:818 / A_HL0, A_HL1 limbs", exists: true, reach: rq_sym(X_ABS * X_ABS, SH_H_PROD), range: I16, builder_guards: true });
    rows.push(Row { site: "FFN down", at: "witness.rs:685 / kernel lib.rs:820 / A_ZL0, A_ZL1 limbs", exists: true, reach: rq_sym(f * X_ABS * W_ABS, SH_Z), range: I16, builder_guards: true });
    rows.push(Row { site: "residual 2", at: "witness.rs:707-709 / kernel lib.rs:823-825 / A_X2L0, A_X2L1 limbs", exists: true, reach: (2 * I16.0, 2 * I16.1), range: I16, builder_guards: true });
    rows.push(Row { site: "residual 2 (output conversion)", at: "witness.rs:58 / kernel lib.rs:828 / the output endpoint", exists: true, reach: I16, range: I16, builder_guards: true });
    // ---- the prover / verifier side, on an ADMITTED witness ----
    rows.push(Row {
        site: "U8 word at a padded position",
        at: "protocol.rs:396-417 (lookup_values over the PADDED cube) + :434-444 (bucket 0) / the U8 LogUp identity",
        exists: lookup_pads,
        // every ZERO-rule plane is zero on the pad, so a word is its lookup's
        // constant: 0 for byte / scaled, 127 for both halves of sym
        reach: (0, 127),
        range: (0, 255),
        builder_guards: true,
    });
    rows.push(Row {
        site: "exp pair not a table row",
        at: "protocol.rs:843-847 / the exp LogUp identity; the builder writes A_E = exp[delta] at EVERY position (witness.rs:536, :633-644)",
        exists: true,
        reach: (0, 0),
        range: (0, 0),
        builder_guards: true,
    });
    rows.push(Row {
        site: "activation pair not a table row (true position)",
        at: "protocol.rs:848-853 / the activation LogUp identity; the builder writes a16 = act[g8 + 128] (witness.rs:677-680)",
        exists: true,
        reach: (0, 0),
        range: (0, 0),
        builder_guards: true,
    });
    // S38-F1: the padded Dom::F position carries (g8, a16) = (0, 0); the pair
    // (128, 0) is a row iff act[128] == 0, and nothing requires that
    rows.push(Row {
        site: "activation pair not a table row (padded Dom::F position)",
        at: "protocol.rs:848-853 over the PADDED Dom::F cube (argument.rs:1566-1569: the LogUp arm is never gated) / FeedForwardPublic::new_shaped (private_block.rs:566-577) admits any act[128]",
        exists: sh.pads(Dom::F),
        // what act[128] may be under the constructor, against the one value the pad pair needs
        reach: I16,
        range: (0, 0),
        builder_guards: false,
    });
    rows.push(Row {
        site: "LogUp multiplicity wraps the field",
        at: "protocol.rs:824-853 (histograms) / Fp::new(count)",
        exists: true,
        reach: (0, max_count),
        range: (0, P_FIELD - 1),
        builder_guards: true,
    });
    rows.push(Row {
        site: "kernel checked-arithmetic overflow (every Overflow site)",
        at: "kernel lib.rs:124-158 via :508, :525, :555-565, :592-593, :623-637, :743, :768, :796, :816, :823; the builder's unchecked i64 over the same bounds",
        exists: true,
        reach: (-kernel_max, kernel_max),
        range: (-(i64::MAX as i128), i64::MAX as i128),
        builder_guards: true,
    });
    rows
}

/// every registered shape, and the test-only rung-K8 of stage 37
fn census_shapes() -> Vec<Shape> {
    vec![
        Shape::toy(),
        Shape::rung(),
        Shape::rung_g(),
        Shape::rung_k4(),
        super::k8_tests::rung_k8(),
        Shape::rung_p2(),
        Shape::rung_c6(),
        Shape::rung_w14(),
        Shape::rung_e32(),
        Shape::m125(),
    ]
}

fn short(sh: &Shape) -> &'static str {
    match sh.profile {
        TOY_PROFILE_STR => "toy",
        s if s == super::shape::FROZEN_SEAM_RUNG_PROFILE => "rung",
        "hashline-zk-mr1/private-block-rung-g-t24-dev/1" => "rung-G",
        "hashline-zk-mr1/private-block-rung-k4-t24-dev/1" => "rung-K4",
        s if s == super::k8_tests::K8_BLOCK_PROFILE => "rung-K8",
        "hashline-zk-mr1/private-block-rung-p2-t32-dev/1" => "rung-P2",
        "hashline-zk-mr1/private-block-rung-c6-t32-dev/1" => "rung-C6",
        "hashline-zk-mr1/private-block-rung-w14-t64-dev/1" => "rung-W14",
        "hashline-zk-mr1/private-block-rung-e32-t32-dev/1" => "rung-E32",
        "hashline-zk-mr1/private-block-m125/1" => "125M",
        _ => "unregistered",
    }
}

const TOY_PROFILE_STR: &str = super::shape::TOY_PROFILE;

/// **THE CENSUS, SHAPE BY SHAPE, WITH EVERY BOUND FROM THE SHAPE.** Counted,
/// never proved: the 125M rows are arithmetic on `Shape::m125()` and no
/// witness is built. The expectations are stated site by site; the one
/// geometry-dependent reachable site is `AO` (width > 258), and the one
/// FINDING is S38-F1 at the four shapes whose `Dom::F` pads.
#[test]
fn the_shaped_refusal_census_classifies_every_data_dependent_site_at_every_shape() {
    let always_unreachable = [
        "norm denominator",
        "norm quotient/remainder (quotient)",
        "norm quotient/remainder (remainder window)",
        "causal maximum attainment",
        "exp difference",
        "exp difference (the A_E pad pass)",
        "softmax denominator",
        "softmax quotient/remainder (quotient)",
        "softmax quotient/remainder (remainder window)",
        "O",
        "FFN gate (activation index)",
        "residual 2 (output conversion)",
        "U8 word at a padded position",
        "exp pair not a table row",
        "activation pair not a table row (true position)",
        "LogUp multiplicity wraps the field",
        "kernel checked-arithmetic overflow (every Overflow site)",
    ];
    let always_builder_first = ["Q", "K", "V", "QR", "KR", "score", "residual 1", "FFN gate", "FFN up", "FFN product", "FFN down", "residual 2"];
    let mut tally: Vec<String> = Vec::new();
    for sh in census_shapes() {
        let name = short(&sh);
        assert_ne!(name, "unregistered", "a census shape has no short name: {}", sh.profile);
        let rows = census(&sh);
        // the site list is the same at every shape: 34 rows (the three norm rows twice)
        assert_eq!(rows.len(), 34, "{name}: the census lost or gained a row");
        let mut counts = [0usize; 3];
        for r in &rows {
            let c = r.class();
            counts[c as usize] += 1;
            let norm = ["[norm_a]", "[norm_m]"].into_iter().find(|tag| r.at.ends_with(tag)).unwrap_or("");
            eprintln!(
                "S38 CENSUS {name:>8} | {:<58} | reach [{}, {}] | class [{}, {}] | {}{}",
                format!("{} {norm}", r.site).trim_end(),
                r.reach.0,
                r.reach.1,
                if r.range.0 == i128::MIN { "-inf".to_string() } else { r.range.0.to_string() },
                r.range.1,
                c.name(),
                if r.exists { String::new() } else { " (no position at this shape)".to_string() }
            );
            if always_unreachable.contains(&r.site) {
                assert_eq!(c, Class::Unreachable, "{name}: `{}` ({}) is reachable: reach {:?} against {:?}", r.site, r.at, r.reach, r.range);
            } else if always_builder_first.contains(&r.site) {
                assert_eq!(c, Class::BuilderRefusesFirst, "{name}: `{}` ({}) is not reachable-and-guarded: reach {:?} against {:?}", r.site, r.at, r.reach, r.range);
            } else if r.site == "AO" {
                // the one geometry-dependent site: 127 * width must leave int16
                let reachable = (sh.width as i128) * 127 > I16.1;
                let listed = ["rung-C6", "rung-W14", "rung-E32", "125M"].contains(&name);
                assert_eq!(reachable, listed, "{name}: the AO threshold (width > 258) and the stated shape list disagree");
                let want = if listed { Class::BuilderRefusesFirst } else { Class::Unreachable };
                assert_eq!(c, want, "{name}: AO is {} (reach {:?})", c.name(), r.reach);
            } else if r.site == "activation pair not a table row (padded Dom::F position)" {
                let listed = ["rung", "rung-G", "rung-K4", "rung-K8"].contains(&name);
                assert_eq!(sh.pads(Dom::F), listed, "{name}: Dom::F pads at a shape the S38-F1 list does not name, or the reverse");
                let want = if listed { Class::Finding } else { Class::Unreachable };
                assert_eq!(c, want, "{name}: S38-F1's row is {}", c.name());
            } else {
                panic!("{name}: the census row `{}` has no stated expectation", r.site);
            }
        }
        tally.push(format!("{name}: {} unreachable / {} reachable-builder-refuses-first / {} finding", counts[0], counts[1], counts[2]));
    }
    for line in &tally {
        eprintln!("S38 CENSUS TALLY {line}");
    }
    // N-9's own figures, from the shape and not retyped from the note
    let m = Shape::m125();
    let aoacc = m.width as i128 * 127 * 128;
    assert_eq!(aoacc, 12_484_608, "N-9's |aoacc| bound at 125M");
    assert_eq!(rq(aoacc, SH_AO), 97_536, "N-9's requant(., 7) at 125M");
    // and the toy census's own AO premise, re-derived by the same function
    assert_eq!(rq(Shape::toy().width as i128 * 127 * 128, SH_AO), 2_032, "the toy's AO image (refusals.rs:279)");
}

// ---------------------------------------------------------------- the lookup windows

/// The set of single values a plane may take under every single-term U8
/// lookup `lookups_at` puts on it, scanned: `None` if no lookup names it.
fn admitted_by_lookups(lks: &[Lk], plane: usize) -> Option<(i64, i64)> {
    let mine: Vec<(i64, i64)> = lks.iter().filter(|l| l.terms.len() == 1 && l.terms[0].0 == plane).map(|l| (l.terms[0].1, l.cst)).collect();
    if mine.is_empty() {
        return None;
    }
    let ok = |v: i64| mine.iter().all(|(c, cst)| (0..256).contains(&(cst + c * v)));
    let vals: Vec<i64> = (-1024..=1024).filter(|v| ok(*v)).collect();
    let (lo, hi) = (*vals.first().expect("an admitted value"), *vals.last().expect("an admitted value"));
    assert_eq!(vals.len() as i64, hi - lo + 1, "plane {plane}: the admitted set is not an interval");
    assert!(lo > -1024 && hi < 1024, "plane {plane}: the scan window is too narrow");
    Some((lo, hi))
}

/// The value window a little-endian group of byte-limb planes admits:
/// every limb but the top must be a full byte, and the top may be narrowed
/// by a `scaled` lookup. `256^(n-1) * (top_max + 1)` values.
fn limb_window(lks: &[Lk], planes: &[usize]) -> i128 {
    let (last, lower) = planes.split_last().expect("a limb group");
    for p in lower {
        assert_eq!(admitted_by_lookups(lks, *p), Some((0, 255)), "a lower limb {p} is not a plain byte");
    }
    let (lo, hi) = admitted_by_lookups(lks, *last).expect("the top limb is looked up");
    assert_eq!(lo, 0, "the top limb {last} admits a negative value");
    (256i128).pow(lower.len() as u32) * (hi as i128 + 1)
}

/// **THE ORDER CHECK, FROM THE PRODUCTION LOOKUP LIST.** A site the builder
/// checks must be checked with the same or a TIGHTER class than the prover's
/// lookups admit. Every range below is read off `lookups_at` at the shape and
/// compared with the builder's own class; every plane `lookups_at` narrows is
/// accounted for, so no lookup can narrow a plane the census does not name.
#[test]
fn the_builder_class_of_every_looked_plane_is_the_lookup_window_at_every_shape() {
    for sh in census_shapes() {
        let name = short(&sh);
        let ids = Ids::new(&sh).expect("the plane map");
        let lks: Vec<Lk> = LOOKUP_DOMS.iter().flat_map(|dom| lookups_at(&sh, &ids, *dom)).collect();
        let mut seen: BTreeSet<usize> = BTreeSet::new();
        // (1) the attention int8 subset: builder [-127, 127] == sym()
        for p in [A_Y, A_YM, A_Q8, A_QR8, A_O8, A_K8, A_V8, A_KR8, A_S8] {
            let got = admitted_by_lookups(&lks, ids.at(p)).unwrap_or_else(|| panic!("{name}: toy plane {p} carries no lookup"));
            assert_eq!((got.0 as i128, got.1 as i128), I8N, "{name}: toy plane {p}'s lookups admit {got:?}, the builder's class is {I8N:?}");
            seen.insert(ids.at(p));
        }
        // (2) the gate carries NO U8 lookup: its class [-128, 127] is the
        // activation pair's 256-row index, which the builder's check equals
        assert_eq!(admitted_by_lookups(&lks, ids.at(A_G8)), None, "{name}: a U8 lookup narrows the gate below the activation table's 256 rows");
        assert_eq!(I8.1 - I8.0 + 1, U8_LEN as i128, "{name}: the gate class is not the activation table's row count");
        // (3) int16 planes: two byte limbs of v + 32768 (the offset is the
        // argument's relation constant), so 2^16 values == the builder's int16
        for pair in [[A_XL0, A_XL1], [A_AL0, A_AL1], [A_X1L0, A_X1L1], [A_X2L0, A_X2L1], [A_ZL0, A_ZL1], [A_UL0, A_UL1], [A_HL0, A_HL1]] {
            let planes = [ids.at(pair[0]), ids.at(pair[1])];
            assert_eq!(limb_window(&lks, &planes), I16.1 - I16.0 + 1, "{name}: int16 limb pair {pair:?}");
            seen.extend(planes);
        }
        // (4) the requantization remainders, biased into [0, 2^sh) by the
        // requant rule itself: the window must be EXACTLY 2^sh
        for (planes, sh_bits) in [
            (vec![A_RQL], SH_QKV),
            (vec![A_RKL], SH_QKV),
            (vec![A_RVL], SH_QKV),
            (vec![A_RQRL], SH_ROPE),
            (vec![A_RKRL], SH_ROPE),
            (vec![A_RSL], SH_S),
            (vec![A_RO0, A_RO1], SH_O),
            (vec![A_RAL], SH_AO),
            (vec![A_RGL], SH_G),
            (vec![A_RH0, A_RH1], SH_H_PROD),
            (vec![A_RDL], SH_Z),
        ] {
            let ps: Vec<usize> = planes.iter().map(|p| ids.at(*p)).collect();
            assert_eq!(limb_window(&lks, &ps), 1i128 << sh_bits, "{name}: remainder limbs {planes:?} against 2^{sh_bits}");
            seen.extend(ps);
        }
        // (5) the two norms' rho / sigma: builder `rho, sigma < 2^norm_wrho`
        // (witness.rs:393) == the limb window, with or without C-6's drop
        for group in [(0..ids.ln).map(|k| ids.nr(k)).collect::<Vec<_>>(), (0..ids.ln).map(|k| ids.ns(k)).collect(), (0..ids.ln).map(|k| ids.mr(k)).collect(), (0..ids.ln).map(|k| ids.ms(k)).collect()] {
            assert_eq!(limb_window(&lks, &group), 1i128 << sh.norm_wrho, "{name}: a norm remainder window differs from the builder's 2^{}", sh.norm_wrho);
            seen.extend(group);
        }
        // (6) the softmax remainders: builder `sigma_s < 2^wrho_s`
        // (witness.rs:554) == the window; `rho_s` is not checked by the
        // builder, and is bounded by `rho_s < Sum <= tokens 2^fE`, which the
        // window must hold
        let sg: Vec<usize> = (0..ids.ls).map(|k| ids.sg(k)).collect();
        let sr: Vec<usize> = (0..ids.ls).map(|k| ids.sr(k)).collect();
        assert_eq!(limb_window(&lks, &sg), 1i128 << sh.wrho_s, "{name}: the sigma_s window");
        assert_eq!(limb_window(&lks, &sr), 1i128 << sh.wrho_s, "{name}: the rho_s window");
        assert!((sh.tokens as i128) << sh.f_e <= 1i128 << sh.wrho_s, "{name}: rho_s < Sum <= tokens 2^fE does not fit the rho_s window");
        seen.extend(sg);
        seen.extend(sr);
        // (7) the softmax quotient: builder `p <= 2^F_P` (witness.rs:554) is
        // TIGHTER than the window 2^(F_P + 1) — the right direction
        let pl: Vec<usize> = (0..ids.lp).map(|k| ids.pl(k)).collect();
        let pw = limb_window(&lks, &pl);
        assert!((1i128 << F_P) < pw, "{name}: the p window {pw} does not hold the builder's p = 2^F_P");
        seen.extend(pl);
        // (8) the isqrt witness: builder `D, a1, a2 < 2^24` (witness.rs:373)
        // == three byte limbs, every Dom::L sub-plane a plain byte
        for p in [A_LIMB, A_LIMBM] {
            assert_eq!(admitted_by_lookups(&lks, ids.at(p)), Some((0, 255)), "{name}: an isqrt limb plane is not a plain byte");
            seen.insert(ids.at(p));
        }
        assert_eq!(1i128 << (8 * LIMBS_ISQRT), 1i128 << 24, "{name}: the isqrt window");
        // nothing else is narrowed by a U8 lookup
        let looked: BTreeSet<usize> = lks.iter().flat_map(|l| l.terms.iter().map(|(p, _)| *p)).collect();
        assert_eq!(looked, seen, "{name}: a plane is narrowed by a U8 lookup the census does not account for");
        assert!(lks.iter().all(|l| l.terms.len() == 1), "{name}: a multi-term U8 lookup appeared");
        eprintln!("S38 WINDOWS {name}: {} looked planes, every one's lookup window equals (or, for p, contains) the builder's class", looked.len());
    }
}

// ---------------------------------------------------------------- the unreachable premises

/// **THE PREMISES OF THE UNREACHABLE ROWS, EXERCISED AT EVERY SHAPE** (the
/// toy's `the_unreachable_refusal_sites_have_their_premises` and
/// `the_softmax_weights_of_a_row_sum_to_at_most_one`, shape-driven): the norm
/// quotient closed form over each shape's own `D_max` and every i8 gain; the
/// softmax row sum over each shape's own token count and `F_E`; and the
/// statement rules the softmax rows rest on are REFUSED when broken.
#[test]
fn the_unreachable_sites_premises_hold_at_every_shape() {
    for sh in census_shapes() {
        let name = short(&sh);
        let b = bounds(&sh);
        // the int16 extreme -32768 moves D_max past Shape::d_max's 32767-based
        // figure by at most a few units; the window must hold THIS one
        assert!(b.d_max >= sh.d_max, "{name}: D_max over int16 is below the shape's");
        assert!((b.d_max << (NORM_TN + 1)) <= 1i128 << sh.norm_wrho, "{name}: den_max {} exceeds the norm window 2^{}", b.d_max << (NORM_TN + 1), sh.norm_wrho);
        assert!(2 * b.d_max < 1i128 << (8 * LIMBS_ISQRT), "{name}: 2 D_max leaves the isqrt limb window");
        let d_max = b.d_max as i64;
        for dv in [1i64, 2, 3, 4, 17, 255, 4096, 65535, d_max - 1, d_max] {
            for x in [-dv, -dv + 1, -1, 0, 1, dv - 1, dv] {
                // |x| <= 32768 and |x| <= D
                if x.abs() > 32768 {
                    continue;
                }
                for g in [-128i64, -127, -1, 0, 1, 127] {
                    let (num, den) = (2 * x * g * NORM_CN + (dv << NORM_TN), dv << (NORM_TN + 1));
                    let (q, rho) = (num.div_euclid(den), num.rem_euclid(den));
                    assert!((-(b.y_abs as i64)..=b.y_abs as i64).contains(&q), "{name}: norm quotient {q} at D={dv} x={x} g={g}");
                    assert!((rho as i128) < 1i128 << sh.norm_wrho && ((den - 1 - rho) as i128) < 1i128 << sh.norm_wrho, "{name}: norm remainder window");
                }
            }
        }
        // the softmax row: Sum in [2^fE, T 2^fE], p <= 2^fP, sum_j p_j <= 2^fP
        let one_e = 1i64 << sh.f_e;
        for t in [0usize, 1, 7, sh.tokens / 2, sh.tokens - 1] {
            for pattern in 0..4usize {
                let e: Vec<i64> = (0..=t)
                    .map(|j| match pattern {
                        0 => one_e,
                        1 => if j == 0 { one_e } else { 1 },
                        2 => one_e - (j as i64 % one_e),
                        _ => if j % 2 == 0 { one_e } else { one_e / 2 },
                    })
                    .collect();
                let total: i64 = e.iter().sum();
                assert!((one_e..=(sh.tokens as i64) * one_e).contains(&total), "{name}: Sum outside its class");
                let p: Vec<i64> = e.iter().map(|v| (v << F_P) / total).collect();
                assert!(p.iter().all(|q| (0..=1i64 << F_P).contains(q)), "{name}: a softmax quotient out of class");
                assert!(p.iter().sum::<i64>() <= 1i64 << F_P, "{name}: the softmax weights sum above 2^fP at t={t}");
                assert!(((total - 1) as i128) < 1i128 << sh.wrho_s, "{name}: sigma_s leaves its window");
            }
        }
        // O over the 2^fP bound, and the causal / exp premises
        assert!(rq(((1i128 << F_P) * 127) as i128, SH_O) <= 127 && rq(-(1i128 << F_P) * 127, SH_O) >= -127, "{name}: O can leave the int8 subset");
        assert_eq!(MASK_SCORE as i128, I8N.0, "the mask is no longer the minimum of the score class");
        assert!(127 - MASK_SCORE < 256, "the largest exp difference leaves the table");
        // the calibration the kernel copies is the one the census reads
        assert_eq!((kshaped::calib::SH_Q, kshaped::calib::SH_QR, kshaped::calib::SH_S, kshaped::calib::SH_O, kshaped::calib::SH_AO), (SH_QKV as i32, SH_ROPE as i32, SH_S as i32, SH_O as i32, SH_AO as i32));
        assert_eq!((kshaped::calib::SH_G, kshaped::calib::SH_U, kshaped::calib::SH_H, kshaped::calib::SH_Z), (SH_G as i32, 0, SH_H_PROD as i32, SH_Z as i32));
        assert_eq!(kshaped::calib::MASK, MASK_SCORE);
    }
    // the statement rules the softmax rows rest on are enforced by
    // construction: an exp table without E[0] = 2^fE, outside [0, 2^fE] or
    // not monotone, and a RoPE entry above 2^F_RO, are refused by name
    let s = Shape::rung_g();
    let base = Spec::base(&s);
    let mut cases: Vec<(&str, Spec)> = Vec::new();
    let mut e0 = base.clone();
    e0.exp[0] -= 1;
    cases.push(("exp E[0]", e0));
    let mut er = base.clone();
    er.exp[5] = -1;
    cases.push(("exp range", er));
    let mut em = base.clone();
    em.exp[10] = em.exp[9] + 1;
    cases.push(("exp monotone", em));
    let mut ro = base.clone();
    ro.cos[s.head_dim / 2] = (1 << F_RO) + 1;
    cases.push(("rope range", ro));
    for (what, sp) in cases {
        let aw = super::grow_tests::pad_attention_weights(&s, &sp.w[0], &sp.w[1], &sp.w[2], &sp.w[3], &sp.w[4]);
        let r = AttentionPublic::new_shaped(&s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &sp.cos, &sp.sin, &sp.exp);
        assert!(r.is_err(), "{what}: a table breaking the softmax / rope premise was admitted");
    }
}

/// **THE CHALLENGE-ONLY REFUSALS, COUNTED PER SHAPE** (liveness, not
/// completeness: each is refused if a Fiat-Shamir draw hits a set of
/// negligible size, and none depends on the witness except the zero LogUp
/// denominator, whose chance is at most 256 / |Fp2| per looked value set).
/// The census owes these as a list (ruling NL-6 / finding N-6).
#[test]
fn the_challenge_only_refusals_are_counted_per_shape() {
    for sh in census_shapes() {
        let name = short(&sh);
        let ids = Ids::new(&sh).expect("the plane map");
        let slots = sh.slots();
        let ext: usize = slots.iter().map(|(_, e, _)| *e).sum();
        let hosts = SLOT_KINDS.iter().filter(|k| **k == SlotKind::Host).count();
        // the pad-zero terms: one zeta per slot hosting a padded domain's ZERO planes
        let zeta: BTreeSet<usize> = ALL_DOMS.iter().filter(|d| !super::pad::zero_rule_a_planes(&sh, &ids, **d).is_empty()).map(|d| super::pad::pad_zero_host(*d)).collect();
        assert_eq!(hosts, 6, "{name}: the host arms are SC_TZC, SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC");
        eprintln!(
            "S38 CHALLENGE-ONLY {name}: c_s = 0 x{} (argument.rs:478); e in {{0,1}} x{ext} (argument.rs:587); nu = 0 x{} (argument.rs:949 via :1142, :1405, :1552, :1605 x2, :1663); zeta = 0 x{} (argument.rs:949 via :1143, :1210, :1406, :1553, :1606, :1664, :1786); zero group member coefficient over {} opening groups (protocol.rs:300, the A and H groups; one draw per claim); dependent proximity x4 (protocol.rs:309, A, H and two endpoints); zero terminal mask coefficient (protocol.rs:246); zero LogUp denominator (protocol.rs:492, :569-574)",
            N_SLOTS,
            2 * hosts,
            zeta.len(),
            sh.a_groups() + sh.h_groups()
        );
        if name == "125M" {
            // GN-8's own count, re-derived: five padded host slots at 125M
            assert_eq!(zeta.len(), 5, "125M's zeta draws");
        }
        if name == "toy" {
            assert!(zeta.is_empty(), "the frozen toy carries no pad-zero machinery");
        }
    }
}

// ---------------------------------------------------------------- the boundary families

/// A hand-built PUBLIC SYNTHETIC statement at a shape, in the reference
/// kernel's own TRUE-sized word order, so that one value feeds the builder,
/// the kernel and the prover.
#[derive(Clone)]
struct Spec {
    /// `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd]`: attention matrices
    /// `(output, input)`, feed-forward `(input, output)`, all true-sized
    w: [Vec<i8>; 9],
    cos: Vec<i64>,
    sin: Vec<i64>,
    exp: Vec<i64>,
    act: Vec<i16>,
    x: Vec<i16>,
}

impl Spec {
    /// every weight zero, both gains 127, the identity RoPE, the shape's exp
    /// member, the frozen SiLU member (`act[128] = 0`) and `x = 1`
    fn base(s: &Shape) -> Spec {
        let (d, f, kvw, half) = (s.width, s.hidden, s.kv_heads * s.head_dim, s.head_dim / 2);
        let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member");
        assert_eq!(act[128], 0, "the SiLU member's gate-0 row is not 0");
        Spec {
            w: [vec![0; d * d], vec![0; kvw * d], vec![0; kvw * d], vec![0; d * d], vec![127; d], vec![127; d], vec![0; d * f], vec![0; d * f], vec![0; f * d]],
            cos: vec![1i64 << F_RO; s.tokens * half],
            sin: vec![0; s.tokens * half],
            exp: exp.to_vec(),
            act: act.to_vec(),
            x: vec![1; s.tokens * d],
        }
    }
    fn statement(&self, s: &Shape) -> BlockPublic {
        let aw = super::grow_tests::pad_attention_weights(s, &self.w[0], &self.w[1], &self.w[2], &self.w[3], &self.w[4]);
        let fw = super::grow_tests::pad_ff_weights(s, &self.w[5], &self.w[6], &self.w[7], &self.w[8]);
        let public = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &self.cos, &self.sin, &self.exp).expect("the family's attention statement");
        let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &self.act).expect("the family's feed-forward statement");
        BlockPublic::new(public, ff)
    }
    fn witness(&self, s: &Shape) -> Result<Witness, String> {
        let blk = self.statement(s);
        witness::build_shaped(s, blk.attention(), blk.feed_forward(), &self.x)
    }
    fn kernel(&self, s: &Shape) -> Result<Vec<i16>, String> {
        let ksh = kshaped::Shape::new(s.tokens, s.width, s.hidden, s.q_heads, s.kv_heads, s.head_dim, s.f_e, F_P, s.wrho_s, s.norm_wrho);
        let mut scratch = vec![0i64; ksh.scratch_len()];
        let mut out = vec![0i16; ksh.x_len()];
        let wr = kshaped::WeightsRef { wq: &self.w[0], wk: &self.w[1], wv: &self.w[2], wo: &self.w[3], gamma_a: &self.w[4], gamma_m: &self.w[5], wg_t: &self.w[6], wu_t: &self.w[7], wd_t: &self.w[8] };
        let tr = kshaped::TablesRef { rope_cos: &self.cos, rope_sin: &self.sin, exp: &self.exp, act: &self.act };
        kshaped::run_shaped(&ksh, &self.x, &wr, &tr, &mut scratch, None, &mut out).map_err(|e| format!("{e}"))?;
        Ok(out)
    }
    /// set input column `c` at every token
    fn set_x_col(&mut self, s: &Shape, c: usize, v: i16) {
        for t in 0..s.tokens {
            self.x[t * s.width + c] = v;
        }
    }
    /// row `r` of an `(output, input)` matrix `m` with `inner` inputs
    fn set_row(&mut self, m: usize, r: usize, inner: usize, vals: &[i8]) {
        self.w[m][r * inner..(r + 1) * inner].copy_from_slice(vals);
    }
    /// column `c` of an `(input, output)` matrix `m` with `outer` outputs
    fn set_col(&mut self, m: usize, c: usize, outer: usize, vals: &[i8]) {
        for (i, v) in vals.iter().enumerate() {
            self.w[m][i * outer + c] = *v;
        }
    }
}

/// the gain that makes a norm output exactly 1 on a column whose input is 1,
/// when every column of the row is +-1: `D = isqrt(1 + width)` and
/// `q = floor((2 D 1024 + D 2048) / (D 4096)) = 1`
fn gain_for_one(s: &Shape) -> i8 {
    let dd = witness::isqrt(1 + s.width as u64);
    i8::try_from(dd).expect("the gain for a unit norm output fits i8")
}

/// the largest accumulator whose requantization is `hi`, and the smallest
/// whose requantization is `lo`
fn acc_top(sh: u32, hi: i64) -> i64 {
    ((hi + 1) << sh) - witness::half(sh) - 1
}
fn acc_bottom(sh: u32, lo: i64) -> i64 {
    (lo << sh) - witness::half(sh)
}

/// Integer weights in `[-128, 127]` with `sum_i v_i w_i = target` EXACTLY
/// (greedy on `|v|`, stable order): panics if the family's activations cannot
/// hit it, which is a design error of the family and not a finding.
fn solve(v: &[i64], target: i64) -> Vec<i8> {
    let mut order: Vec<usize> = (0..v.len()).filter(|i| v[*i] != 0).collect();
    order.sort_by_key(|i| std::cmp::Reverse(v[*i].abs()));
    let mut w = vec![0i8; v.len()];
    let mut rem = target;
    for i in order {
        let k = (rem / v[i]).clamp(-128, 127);
        w[i] = k as i8;
        rem -= k * v[i];
    }
    assert_eq!(rem, 0, "the family's activations cannot hit the accumulator {target} exactly");
    w
}

/// token 0's row of a `Dom::D` plane, true columns
fn d_row(s: &Shape, w: &Witness, plane: usize) -> Vec<i64> {
    (0..s.width).map(|i| w.planes[plane][i]).collect()
}
/// token 0's row of `o8`, in TRUE `Q`-axis order `h * head_dim + i`
fn o8_row(s: &Shape, ids: &Ids, w: &Witness) -> Vec<i64> {
    (0..s.width).map(|j| w.planes[ids.at(A_O8)][super::grow_tests::q_axis_index(s, j)]).collect()
}
/// token 0's row of `h16`, true hidden columns
fn h_row(s: &Shape, ids: &Ids, w: &Witness) -> Vec<i64> {
    (0..s.hidden).map(|j| w.planes[ids.at(A_H16)][j]).collect()
}

/// One reachable site's family: the builder's refusal string, the toy id of
/// the plane whose extreme sits on the class edge in the INSIDE case, and
/// that edge.
#[derive(Clone, Copy, Debug)]
struct Family {
    site: &'static str,
    plane: usize,
    edge: i64,
}

const FAMILIES: [Family; 12] = [
    Family { site: "Q", plane: A_Q8, edge: 127 },
    Family { site: "K", plane: A_K8, edge: 127 },
    Family { site: "V", plane: A_V8, edge: 127 },
    Family { site: "QR", plane: A_QR8, edge: 127 },
    Family { site: "KR", plane: A_KR8, edge: 127 },
    Family { site: "score", plane: A_S8, edge: 127 },
    Family { site: "residual 1", plane: A_X1, edge: 32767 },
    Family { site: "FFN gate", plane: A_G8, edge: -128 },
    Family { site: "FFN up", plane: A_U16, edge: 32767 },
    Family { site: "FFN product", plane: A_H16, edge: 32767 },
    Family { site: "FFN down", plane: A_Z16, edge: 32767 },
    Family { site: "residual 2", plane: A_X2, edge: 32767 },
];
const AO_FAMILY: Family = Family { site: "AO", plane: A_AO, edge: 32767 };

/// **THE FAMILIES.** `(inside, just past)` for one site at one shape. The
/// inside case puts the site's value EXACTLY on its class edge (the plane's
/// extreme equals the edge); the just-past case moves ONE knob by the
/// smallest step that leaves the class. Every activation is read back from a
/// witness the builder built, never assumed; every target accumulator is the
/// requantization edge (`acc_top` / `acc_bottom`).
fn family(s: &Shape, fam: Family) -> (Spec, Spec) {
    let ids = Ids::new(s).expect("the plane map");
    let (d, f, dh) = (s.width, s.hidden, s.head_dim);
    let half = dh / 2;
    let g1 = gain_for_one(s);
    let wit = |sp: &Spec, what: &str| -> Witness { sp.witness(s).unwrap_or_else(|e| panic!("{}: the {what} witness of the family refused: {e}", fam.site)) };
    let mut sp = Spec::base(s);
    match fam.site {
        // one row of Wq / Wk / Wv hits the requant edge on the y vector
        // (every column y0 but the last, which is exactly 1)
        "Q" | "K" | "V" => {
            let m = ["Q", "K", "V"].iter().position(|n| *n == fam.site).expect("a projection");
            sp.w[4][d - 1] = g1;
            let y = d_row(s, &wit(&sp, "zero-weight"), ids.at(A_Y));
            let mut out = sp.clone();
            sp.set_row(m, 0, d, &solve(&y, acc_top(SH_QKV, 127)));
            out.set_row(m, 0, d, &solve(&y, acc_top(SH_QKV, 127) + 1));
            (sp, out)
        }
        // a rotation mix: at every t >= 1 the pair-0 rope is (128, -128), so
        // QR_0 = requant(128 a + 128 b, 7) = a + b with a = 64 and b = 63 / 64
        "QR" | "KR" => {
            let m = if fam.site == "QR" { 0 } else { 1 };
            sp.w[4][d - 1] = g1;
            for t in 1..s.tokens {
                sp.cos[t * half] = 1 << F_RO;
                sp.sin[t * half] = -(1 << F_RO);
            }
            let y = d_row(s, &wit(&sp, "zero-weight"), ids.at(A_Y));
            sp.set_row(m, 0, d, &solve(&y, 128 * 64));
            let mut out = sp.clone();
            sp.set_row(m, half, d, &solve(&y, 128 * 63));
            out.set_row(m, half, d, &solve(&y, 128 * 64));
            (sp, out)
        }
        // identity rope: s = q8_0 k8_0 + q8_1 k8_1 = 127 * 64 + 1 * (31 / 32)
        // = 8159 / 8160, the requant(., 6) edge of 127
        "score" => {
            sp.w[4][d - 1] = g1;
            let y = d_row(s, &wit(&sp, "zero-weight"), ids.at(A_Y));
            sp.set_row(0, 0, d, &solve(&y, 128 * 127));
            sp.set_row(0, 1, d, &solve(&y, 128));
            sp.set_row(1, 0, d, &solve(&y, 128 * 64));
            let mut out = sp.clone();
            sp.set_row(1, 1, d, &solve(&y, 128 * 31));
            out.set_row(1, 1, d, &solve(&y, 128 * 32));
            (sp, out)
        }
        // x_0 = 32766 (inside) / 32767 (just past), so y = 64 e_0; one value
        // row gives v8 = 1, and one Wo row gives ao_0 = 1
        "residual 1" => {
            sp.set_x_col(s, 0, 32766);
            let y = d_row(s, &wit(&sp, "large-x"), ids.at(A_Y));
            sp.set_row(2, 0, d, &solve(&y, 128));
            let o = o8_row(s, &ids, &wit(&sp, "value"));
            sp.set_row(3, 0, d, &solve(&o, 128));
            let mut out = sp.clone();
            out.set_x_col(s, 0, 32767);
            (sp, out)
        }
        // attention off (gamma_a = 0), so xres1 = x = 1 and nm is y0 but for
        // the last column's exact 1; the gate column hits the LOW edge -128
        "FFN gate" | "FFN up" | "FFN product" => {
            sp.w[4] = vec![0; d];
            sp.w[5][d - 1] = g1;
            let nm = d_row(s, &wit(&sp, "attention-off"), ids.at(A_YM));
            let mut out = sp.clone();
            match fam.site {
                "FFN gate" => {
                    sp.set_col(6, 0, f, &solve(&nm, acc_bottom(SH_G, -128)));
                    out.set_col(6, 0, f, &solve(&nm, acc_bottom(SH_G, -128) - 1));
                }
                "FFN up" => {
                    sp.set_col(7, 0, f, &solve(&nm, 32767));
                    out.set_col(7, 0, f, &solve(&nm, 32768));
                }
                _ => {
                    // act = 32767 off the gate-0 row (act[128] stays 0 for the
                    // pad, S38-F1), g8 = 1 on hidden column 0, u16 = 16384 / 16385:
                    // requant(32767 u, 14) = 32767 / 32769
                    for (i, a) in sp.act.iter_mut().enumerate() {
                        *a = if i == 128 { 0 } else { 32767 };
                    }
                    sp.set_col(6, 0, f, &solve(&nm, 128));
                    out = sp.clone();
                    sp.set_col(7, 0, f, &solve(&nm, 16384));
                    out.set_col(7, 0, f, &solve(&nm, 16385));
                }
            }
            (sp, out)
        }
        // act = 16384 off row 128, so h16 = u16 exactly; three hidden columns
        // carry h = 16384 / 128 / 1 and one Wd column hits the edge; x_0 = -1
        // with gamma_m[0] = 0 keeps residual 2 inside
        "FFN down" => {
            sp.w[4] = vec![0; d];
            sp.w[5][d - 1] = g1;
            sp.w[5][0] = 0;
            sp.set_x_col(s, 0, -1);
            for (i, a) in sp.act.iter_mut().enumerate() {
                *a = if i == 128 { 0 } else { 16384 };
            }
            let nm = d_row(s, &wit(&sp, "attention-off"), ids.at(A_YM));
            for (j, u) in [16384i64, 128, 1].into_iter().enumerate() {
                sp.set_col(6, j, f, &solve(&nm, 128));
                sp.set_col(7, j, f, &solve(&nm, u));
            }
            let h = h_row(s, &ids, &wit(&sp, "hidden"));
            let mut out = sp.clone();
            sp.set_col(8, 0, d, &solve(&h, acc_top(SH_Z, 32767)));
            out.set_col(8, 0, d, &solve(&h, acc_top(SH_Z, 32767) + 1));
            (sp, out)
        }
        // x_0 = 32766 / 32767 with attention off, so nm = 64 e_0; g8 = 1,
        // u16 = 64, act = 16384 gives h16 = 64 and one Wd entry gives z16 = 1
        "residual 2" => {
            sp.w[4] = vec![0; d];
            sp.set_x_col(s, 0, 32766);
            for (i, a) in sp.act.iter_mut().enumerate() {
                *a = if i == 128 { 0 } else { 16384 };
            }
            let nm = d_row(s, &wit(&sp, "large-x"), ids.at(A_YM));
            sp.set_col(6, 0, f, &solve(&nm, 128));
            sp.set_col(7, 0, f, &solve(&nm, 64));
            let h = h_row(s, &ids, &wit(&sp, "hidden"));
            sp.set_col(8, 0, d, &solve(&h, 64));
            let mut out = sp.clone();
            out.set_x_col(s, 0, 32767);
            (sp, out)
        }
        // every value dimension 127 but (kv 0, dim 0) = 1, so o8 at token 0 is
        // 127 except a few exact 1s; one Wo row hits the int16 edge. x_0 = -1
        // with gamma_a[0] = 0 keeps residual 1 inside
        "AO" => {
            sp.set_x_col(s, 0, -1);
            sp.w[4][0] = 0;
            sp.w[4][d - 1] = g1;
            let y = d_row(s, &wit(&sp, "zero-weight"), ids.at(A_Y));
            let kvw = s.kv_heads * dh;
            let v127 = solve(&y, 128 * 127);
            let v1 = solve(&y, 128);
            for r in 0..kvw {
                sp.set_row(2, r, d, if r == 0 { &v1 } else { &v127 });
            }
            let o = o8_row(s, &ids, &wit(&sp, "value"));
            let mut out = sp.clone();
            sp.set_row(3, 0, d, &solve(&o, acc_top(SH_AO, 32767)));
            out.set_row(3, 0, d, &solve(&o, acc_top(SH_AO, 32767) + 1));
            (sp, out)
        }
        other => panic!("no family for `{other}`"),
    }
}

/// Every word the PROVER would look up, over the whole PADDED cubes, exactly
/// as `prove_core` forms them (`protocol.rs:824-853`): the U8 words outside
/// `[0, 256)`, the exp pairs that are not table rows, and the POSITIONS of the
/// activation pairs that are not table rows. An admitted witness with a
/// nonzero count here cannot produce an accepted proof: the value-0 LogUp
/// identity loses its balance.
fn logup_misses(s: &Shape, blk: &BlockPublic, w: &Witness) -> (usize, usize, Vec<usize>) {
    let lay = Layout::for_shape(s).expect("the layout");
    let ids = lay.ids();
    let u8_miss: usize = lay.lookup_doms().iter().map(|dom| lookup_values(&lay, w, *dom).iter().flatten().filter(|v| !(0..U8_LEN as i64).contains(*v)).count()).sum();
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let e_plane = &w.planes[ids.at(A_E)];
    let exp_miss = exp_deltas(&lay, w).iter().enumerate().filter(|(x, dl)| !((0..U8_LEN as i64).contains(*dl) && public.exp[**dl as usize] == e_plane[*x])).count();
    let a_plane = &w.planes[ids.at(A_A16)];
    let act_miss: Vec<usize> = act_indices(&lay, w).iter().enumerate().filter(|(x, i)| !((0..U8_LEN as i64).contains(*i) && i64::from(ff.act[**i as usize]) == a_plane[*x])).map(|(x, _)| x).collect();
    (u8_miss, exp_miss, act_miss)
}

/// the (min, max) of a plane over its whole padded extent
fn extreme(w: &Witness, plane: usize) -> (i64, i64) {
    let p = &w.planes[plane];
    (*p.iter().min().expect("a plane"), *p.iter().max().expect("a plane"))
}

/// **ONE SITE AT ONE SHAPE, BOTH SIDES OF ITS EDGE.** Inside: the builder
/// admits, the plane's extreme is EXACTLY the class edge, every checkable
/// relation holds, every word the prover would look up is a table row, the
/// reference kernel accepts with the same block output, and (when `prove`)
/// the honest proof is ACCEPTED by the verifier. Just past: the builder
/// refuses BY NAME at this site and the kernel refuses with the same string.
fn check_family(s: &Shape, fam: Family, prove: bool) {
    let name = short(s);
    let ids = Ids::new(s).expect("the plane map");
    let want = format!("fixed oracle range refusal: {}", fam.site);
    let (inside, past) = family(s, fam);
    // ---- just past: the builder and the kernel refuse at the same site ----
    match past.witness(s) {
        Err(m) => assert_eq!(m, want, "{name} `{}`: just past the edge the builder refused elsewhere", fam.site),
        Ok(_) => panic!("{name} `{}`: just past the edge the builder ADMITTED", fam.site),
    }
    match past.kernel(s) {
        Err(e) => assert_eq!(e, want, "{name} `{}`: just past the edge the kernel refused elsewhere", fam.site),
        Ok(_) => panic!("{name} `{}`: the builder refused `{want}` where the kernel ACCEPTED", fam.site),
    }
    // ---- inside: admitted, on the edge, and downstream-clean ----
    let w = inside.witness(s).unwrap_or_else(|e| panic!("{name} `{}`: the inside case was refused: {e}", fam.site));
    let (lo, hi) = extreme(&w, ids.at(fam.plane));
    let on_edge = if fam.edge < 0 { lo == fam.edge } else { hi == fam.edge };
    assert!(on_edge, "{name} `{}`: the inside case's plane spans [{lo}, {hi}], not the edge {}", fam.site, fam.edge);
    assert!(super::pad::every_checkable_relation_holds(s, &ids, &w), "{name} `{}`: the inside witness breaks a checkable relation", fam.site);
    let blk = inside.statement(s);
    let (u8_miss, exp_miss, act_miss) = logup_misses(s, &blk, &w);
    assert_eq!((u8_miss, exp_miss, act_miss.len()), (0, 0, 0), "{name} `{}`: the prover would look up a word that is not a table row", fam.site);
    let kernel = inside.kernel(s).unwrap_or_else(|e| panic!("{name} `{}`: the builder admitted the inside case and the kernel refused it: {e}", fam.site));
    let mine: Vec<i16> = {
        let out = w.output().expect("the inside output is int16");
        (0..s.tokens).flat_map(|t| out[t * s.d_pad..t * s.d_pad + s.width].to_vec()).collect()
    };
    assert_eq!(mine, kernel, "{name} `{}`: the builder's and the kernel's block outputs differ on the inside case", fam.site);
    if prove {
        let t0 = std::time::Instant::now();
        let o = outcome(s, &blk, w);
        assert_eq!(o, Outcome::Accepted, "{name} `{}`: the honest inside case was not accepted: {}", fam.site, o.short());
        eprintln!("S38 EDGE {name:>8} `{}`: inside on the edge {} PROVES AND VERIFIES ({:.2} s); just past refused by name by the builder AND the kernel", fam.site, fam.edge, t0.elapsed().as_secs_f64());
    } else {
        eprintln!("S38 EDGE {name:>8} `{}`: inside on the edge {} admitted, kernel-equal, LogUp-clean; just past refused by name by the builder AND the kernel", fam.site, fam.edge);
    }
}

/// **rung-G: every reachable site, both sides of its edge, the inside case
/// proved and verified.**
#[test]
fn every_reachable_site_refuses_by_name_just_past_its_edge_and_proves_just_inside_at_rung_g() {
    let s = Shape::rung_g();
    for fam in FAMILIES {
        check_family(&s, fam, true);
    }
}

/// **rung-K4** (padded head slots `{3, 7, 11, 15}`, two group bits).
#[test]
fn every_reachable_site_refuses_by_name_just_past_its_edge_and_proves_just_inside_at_rung_k4() {
    let s = Shape::rung_k4();
    for fam in FAMILIES {
        check_family(&s, fam, true);
    }
}

/// **rung-K8** (stage 37's three group bits, no padded head slot).
#[test]
fn every_reachable_site_refuses_by_name_just_past_its_edge_and_proves_just_inside_at_rung_k8() {
    let s = super::k8_tests::rung_k8();
    for fam in FAMILIES {
        check_family(&s, fam, true);
    }
}

/// **AO, the site N-9 names**, at the cheapest shape where it is reachable
/// (rung-C6, width 384: `requant(384 * 127 * 128, 7) = 48,768`). The builder
/// refuses `AO` by name just past the edge, the kernel with the same string,
/// and the inside case, with `ao = 32767` exactly, proves and verifies. At
/// every width <= 258 the family cannot be built at all: the census row says
/// the site is unreachable there, and this asserts the family's own solver
/// agrees at rung-G.
#[test]
fn the_output_projection_refuses_by_name_just_past_its_edge_and_proves_just_inside_at_rung_c6() {
    let s = Shape::rung_c6();
    assert!((s.width as i128) * 127 > I16.1, "rung-C6 no longer reaches AO");
    check_family(&s, AO_FAMILY, true);
    // at rung-G the largest reachable |aoacc| is below the edge
    let g = Shape::rung_g();
    assert!(rq(g.width as i128 * 127 * 128, SH_AO) < I16.1, "rung-G reaches AO after all");
    let hit = std::panic::catch_unwind(|| family(&Shape::rung_g(), AO_FAMILY));
    assert!(hit.is_err(), "an AO edge family was built at rung-G, where the census says the site is unreachable");
}

// ---------------------------------------------------------------- finding S38-F1

/// the S38-F1 statement: the base family with `act[128] = 1` — a legal
/// `[i16; 256]`, admitted by `FeedForwardPublic::new_shaped`
fn s38_f1_case(s: &Shape) -> Spec {
    let mut sp = Spec::base(s);
    sp.act[128] = 1;
    sp
}

/// **S38-F1, IN THE ORDINARY FILTER: the census row, made concrete.** At every
/// shape whose `Dom::F` pads, a statement with `act[128] != 0` is ADMITTED by
/// the constructor, the witness builder admits the input, the reference
/// kernel agrees on the output — and the prover's activation LogUp arm would
/// look up, at EXACTLY the padded `Dom::F` positions, the pair `(128, 0)`,
/// which is not a row of that table. At a shape whose `Dom::F` does not pad
/// the same statement is LogUp-clean. (The end-to-end failure is the
/// `#[ignore]`d reproducer below.)
#[test]
fn s38_f1_the_padded_feed_forward_positions_look_up_a_pair_that_is_not_a_row_when_act_128_is_nonzero() {
    for s in [Shape::rung_g(), Shape::rung_k4(), super::k8_tests::rung_k8(), Shape::rung_p2(), Shape::rung_c6()] {
        let name = short(&s);
        let sp = s38_f1_case(&s);
        let blk = sp.statement(&s);
        let w = sp.witness(&s).unwrap_or_else(|e| panic!("{name}: the builder refused the S38-F1 statement: {e}"));
        let kernel = sp.kernel(&s).unwrap_or_else(|e| panic!("{name}: the kernel refused the S38-F1 statement: {e}"));
        let out = w.output().expect("int16 output");
        let mine: Vec<i16> = (0..s.tokens).flat_map(|t| out[t * s.d_pad..t * s.d_pad + s.width].to_vec()).collect();
        assert_eq!(mine, kernel, "{name}: builder and kernel disagree on the S38-F1 statement");
        let (u8_miss, exp_miss, act_miss) = logup_misses(&s, &blk, &w);
        assert_eq!((u8_miss, exp_miss), (0, 0), "{name}: an unrelated LogUp miss");
        let pads: Vec<usize> = {
            let g = witness::Geom::new(&s);
            let sup: BTreeSet<usize> = g.support(Dom::F).into_iter().collect();
            (0..s.size(Dom::F)).filter(|x| !sup.contains(x)).collect()
        };
        if s.pads(Dom::F) {
            assert_eq!(act_miss, pads, "{name}: the activation pairs that miss the table are not exactly the padded Dom::F positions");
            eprintln!("S38-F1 {name}: act[128] = 1 admitted; {} of {} Dom::F positions (every PADDED one) look up (128, 0), not a row", act_miss.len(), s.size(Dom::F));
        } else {
            assert!(act_miss.is_empty() && pads.is_empty(), "{name}: Dom::F does not pad, yet a pair misses");
            eprintln!("S38-F1 {name}: Dom::F does not pad; the same statement is LogUp-clean");
        }
    }
}

/// **S38-F1 REPRODUCER (`#[ignore]`d: it FAILS today).** A legal public
/// statement — every weight zero, the identity RoPE, the shape's exp member,
/// and an activation table whose gate-0 row is 1 instead of 0 — and the
/// all-ones input: the builder admits it, the reference kernel admits it, and
/// the honest proof at rung-G is NOT accepted, for every private input. The
/// fix belongs to the owner of `private_block.rs` / `witness.rs` (refuse
/// `act[128] != 0` at a shape whose `Dom::F` pads, or write the pad's `A16`
/// as `act[128]` and exempt it like `A_E`); it is not made here.
#[test]
#[ignore = "S38-F1 (stage 38): a legal statement with act[128] != 0 makes every honest proof fail at a shape whose Dom::F pads; FAILS until the owner fixes the statement rule or the pad rule"]
fn s38_f1_reproducer_an_honest_proof_with_a_nonzero_gate_zero_activation_is_accepted_at_rung_g() {
    let s = Shape::rung_g();
    let sp = s38_f1_case(&s);
    let blk = sp.statement(&s);
    let w = sp.witness(&s).expect("the builder admits the S38-F1 statement");
    sp.kernel(&s).expect("the reference kernel admits the S38-F1 statement");
    let o = outcome(&s, &blk, w);
    eprintln!("S38-F1 REPRODUCER rung-G: {}", o.short());
    assert_eq!(o, Outcome::Accepted, "S38-F1: an honest proof of an admitted statement was not accepted: {}", o.short());
}
