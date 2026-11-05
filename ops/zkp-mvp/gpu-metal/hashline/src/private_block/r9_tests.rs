//! **NATIVE LANE, ROUND 9: DD, THE PER-ROW DIVISION DICTIONARY** (register
//! entry D30; `results/zk60_gpt_nonlinear_review_20261018/dd_check/CHECK.md`
//! B-1..B-8). TEST CODE ONLY. Public synthetic data only. NOT a soundness or
//! privacy acceptance: D30 sends the built relations to an independent
//! soundness review and to the gate first.
//!
//! * the profile gate: DD is three NEW profiles; every other profile keeps 23
//!   slots, 50 mask rows, 34 functionals, its plane lists, its schedule and
//!   its profile strings (check (c)); a DD profile runs a 24th slot;
//! * the door: a shape that pads its dictionary is refused by name; the cap
//!   counts `{0} U outputs` — 32 passes (the older 8B T32 export's e_s 1
//!   table), 33 refuses, by name, before any header;
//! * completeness on a GENERIC honest witness (dense weights, heads that
//!   differ, the independent reference kernel's output);
//! * the mutations D30 and CHECK.md name, each shown to PASS against its
//!   lapsed construction and to be CAUGHT by the construction as built:
//!   D-3 (an unconstrained slot), D-4 (the row key dropped), the dictionary's
//!   LogUp columns left out of the single sum claim; D-8 (multiplicities
//!   chosen after alpha) caught because `M_dd` is committed in `A`.

use super::layout::*;
use super::shape::{NormCalibration, Shape, DD_CAP};
use super::witness::{self, Witness};
use super::*;

fn dd_rung() -> Shape {
    Shape::rung_dd(&super::trained_calib_tests::rung_tc_calibration()).expect("the DD development rung")
}

/// the public statement of nine true-size words with an exp table of score
/// exponent `e_s` and a SiLU member (the rung's f_e 12, head_dim 32)
fn block_with(sh: &Shape, w: &[Vec<i8>; 9], e_s: i32, silu: (i32, i32)) -> (BlockPublic, Vec<i64>, Vec<i16>) {
    let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(e_s, sh.head_dim, sh.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, silu.0, silu.1).expect("a frozen SiLU member");
    let aw = super::grow_tests::pad_attention_weights(sh, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(sh, &w[5], &w[6], &w[7], &w[8]);
    let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the attention statement");
    let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    (BlockPublic::new(public, ff), exp.to_vec(), act.to_vec())
}

/// the INDEPENDENT shape-driven reference kernel's block output at `sh`
fn kernel_out(sh: &Shape, w: &[Vec<i8>; 9], x: &[i16], exp: &[i64], act: &[i16]) -> Vec<i16> {
    use private_block_kernel_shaped as k;
    let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
    let ksh = super::parity::kernel_shape(sh);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let wr = k::WeightsRef { wq: &w[0], wk: &w[1], wv: &w[2], wo: &w[3], gamma_a: &w[4], gamma_m: &w[5], wg_t: &w[6], wu_t: &w[7], wd_t: &w[8] };
    let tr = k::TablesRef { rope_cos: &cos, rope_sin: &sin, exp, act };
    k::run_shaped(&ksh, x, &wr, &tr, &mut scratch, None, &mut out).unwrap_or_else(|e| panic!("the reference kernel refuses: {e:?}"));
    out
}

fn true_words(sh: &Shape, w: &Witness, plane: usize) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| w.planes[plane][t * sh.d_pad + i] as i16).collect()
}

/// the generic dense block at the DD rung (exp e_s 2: a 32-slot column fits)
fn generic(sh: &Shape) -> (BlockPublic, [Vec<i8>; 9], Vec<i16>, Vec<i64>, Vec<i16>) {
    let (w, input) = super::trained_calib_tests::trained_dense_words(sh, super::trained_calib_tests::TRAINED_BANDS);
    let (blk, exp, act) = block_with(sh, &w, 2, (-3, -11));
    (blk, w, input, exp, act)
}

/// resets every test hook when it goes out of scope
struct Hooks;

impl Drop for Hooks {
    fn drop(&mut self) {
        super::argument::set_dd_lapse(0);
        super::witness::set_dd_cheat(0);
        super::protocol::set_dd_moved_multiplicity(None);
    }
}

// ------------------------------------------------------------------ the gate

/// **Check (c): a non-DD profile is untouched.** Every registered non-DD
/// trained shape and the toy keep 23 slots, 50 mask rows, 34 functionals,
/// no dictionary line, no 24th slot line, and their profile strings; the DD
/// profiles run 24 slots with 52 mask rows and 36 functionals, a dictionary
/// line, and their own plane lists.
#[test]
fn a_non_dd_profile_has_no_24th_slot_and_its_strings_are_unchanged() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    let plain = [
        Shape::toy(),
        Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap(),
        Shape::tinyllama_trained(32, &tl, 9).unwrap(),
        Shape::tinyllama_trained(64, &tl, 9).unwrap(),
        Shape::tinyllama_trained(128, &tl, 9).unwrap(),
        Shape::llama3_8b_trained(32, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(64, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(128, &l8, 9).unwrap(),
    ];
    let strings = [
        "hashline-zk-mr1/private-block-t32-poc/2",
        "hashline-zk-mr1/private-block-rung-tc-t32-dev/2",
        "hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/2",
        "hashline-zk-mr1/private-block-tinyllama-1.1b-t64-trained/2",
        "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-trained-block/2",
        "hashline-zk-mr1/private-block-llama-3-8b-t32-trained/2",
        "hashline-zk-mr1/private-block-llama-3-8b-t64-trained/2",
        "hashline-zk-mr1/private-block-llama-3-8b-t128-trained/2",
    ];
    for (s, want) in plain.iter().zip(strings) {
        assert_eq!(s.profile, want, "a profile string moved");
        assert_eq!((s.dd_cap, s.n_slots(), s.m_rows(), s.n_functionals()), (0, 23, 50, 34), "{}", s.profile);
        let lay = Layout::for_shape(s).unwrap();
        let d = lay.describe();
        assert!(!d.iter().any(|l| l.contains("dictionary") || l.starts_with("slot 23")), "{}: a dictionary line in a non-DD schedule", s.profile);
        assert_eq!(lay.slots().len(), 23);
        assert!(!s.a_plane_doms().contains(&Dom::Dd) && !s.h_plane_doms().contains(&Dom::Dd));
    }
    let tl_dd = Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap();
    let l8_dd = Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap();
    for s in [dd_rung(), tl_dd, l8_dd] {
        assert_eq!((s.dd_cap, s.n_slots(), s.m_rows(), s.n_functionals()), (DD_CAP, 24, 52, 36), "{}", s.profile);
        let lay = Layout::for_shape(&s).unwrap();
        let d = lay.describe();
        assert!(d.iter().any(|l| l.starts_with("dictionary (D30): cap=32")), "{}", s.profile);
        assert!(d.iter().any(|l| l.starts_with("slot 23 [DD dictionary zero-check")), "{}", s.profile);
        let ids = Ids::new(&s).unwrap();
        assert_eq!(s.a_plane_doms().iter().filter(|d| **d == Dom::S).count(), 5, "a DD score entry keeps five planes");
        assert_eq!(s.a_plane_doms().iter().filter(|d| **d == Dom::Dd).count(), 2 + s.limbs_p() + 2 * s.limbs_sigma_s());
        // CHECK.md E-1: P_dict and M_dd sit BELOW the histograms, so the
        // prover writes them into A
        assert!(!ids.is_multiplicity(ids.pdict()) && !ids.is_multiplicity(ids.mdd()));
        assert!(ids.mdd() < ids.at(A_MU8));
        // CHECK.md E-2: the dictionary's table helper is a TABLE helper (sign -1)
        let hids = HIds::new(&s).unwrap();
        assert!(hids.is_table(hids.gdd()) && !hids.is_table(hids.stuple()));
        // CHECK.md P-6: `u` stays the last H plane, on Dom::Tab
        assert_eq!(hids.u(), hids.n_h() - 1);
        assert_eq!(s.h_plane_doms()[hids.u()], Dom::Tab);
        // the score domain's byte lookups: sym(s8) and the rsl pair only
        assert_eq!(s.lookups_per_position(Dom::S), 4);
        assert_eq!(s.lookups_per_position(Dom::Dd), (s.limbs_p() + 1) + 2 * (s.limbs_sigma_s() + 1));
    }
}

/// **The DD door (B-3 by restriction):** a shape whose dictionary would pad
/// is refused by name; the three registered DD shapes pass.
#[test]
fn a_dd_shape_that_pads_is_refused_by_name() {
    let mut s = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    assert_ne!(s.h_pad, s.q_heads, "the rung-TC pads its heads (12 of 16)");
    s.dd_cap = DD_CAP;
    let e = s.check_dd_geometry().expect_err("a padded head axis was admitted under DD");
    assert!(e.contains("DD (D30) needs an unpadded dictionary") && e.contains("pads its head axis"), "{e}");
    let mut s2 = dd_rung();
    s2.dd_cap = 24;
    assert!(s2.check_dd_geometry().unwrap_err().contains("not a power of two"));
    dd_rung().check_dd_geometry().unwrap();
}

/// **The cap (D30 condition 6, CHECK.md C-1 / B-7 / B-8).** `n_col` counts
/// `{0} U outputs`: the older Llama-3-8B T32 export's e_s 1 table (f_e 9,
/// head_dim 128) needs EXACTLY 32 and passes; a table needing 33 is refused
/// by name; the column is sorted, starts at 0 and pads with 0.
#[test]
fn the_cap_admits_32_and_refuses_33_by_name() {
    let (t32, _) = crate::tables_attn::exp_member(1, 128, 9);
    let col = dd_e_column_of(&t32, DD_CAP).expect("the e_s 1 8B table (n_col 32) passes the cap");
    assert_eq!(col.len(), 32);
    assert_eq!(col[0], 0);
    let distinct: std::collections::BTreeSet<i64> = std::iter::once(0).chain(t32.iter().copied()).collect();
    assert_eq!(distinct.len(), 32, "the older 8B T32 export's table is the boundary case");
    // 33: the same table with one more distinct value
    let mut t33 = t32.to_vec();
    let spare = (1..512).find(|v| !distinct.contains(v)).unwrap();
    let last = t33.len() - 1;
    t33[last] = spare;
    let e = dd_e_column_of(&t33, DD_CAP).expect_err("a 33-slot column was admitted");
    assert!(e.contains("D30 / B-8") && e.contains("33 slots") && e.contains("cap of 32"), "{e}");
    // padding: a short column is padded with 0 after its largest value
    let (t3, _) = crate::tables_attn::exp_member(4, 128, 9);
    let c3 = dd_e_column_of(&t3, DD_CAP).unwrap();
    let n = std::iter::once(0).chain(t3.iter().copied()).collect::<std::collections::BTreeSet<i64>>().len();
    assert!(c3[..n].windows(2).all(|p| p[0] < p[1]) && c3[n..].iter().all(|v| *v == 0), "{c3:?}");
}

/// **The door refuses an over-cap block BEFORE any header**: the witness
/// builder, `BlockPublic::check_for_shape` (CS-1 / CS-4, which the run prover
/// takes before its header) and the run prover itself — no segment exists.
#[test]
fn an_over_cap_block_is_refused_before_any_header() {
    let sh = dd_rung();
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    // e_s 0 at head_dim 32, f_e 12: far more than 32 distinct outputs
    let (blk, exp, _) = block_with(&sh, &w, 0, (-3, -11));
    let n = std::iter::once(0).chain(exp.iter().copied()).collect::<std::collections::BTreeSet<i64>>().len();
    assert!(n > DD_CAP, "the e_s 0 table needs {n} slots");
    let e = match witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input) {
        Ok(_) => panic!("the builder admitted an over-cap table"),
        Err(e) => e,
    };
    assert!(e.contains("D30 / B-8"), "{e}");
    let e = blk.check_for_shape(&sh).expect_err("the block statement fits a DD shape over the cap");
    assert!(e.contains("D30 / B-8"), "{e}");
    // the run prover refuses at CS-1 / CS-4, before the endpoints are opened,
    // the randomness seeded or the header absorbed: no segment is handed out
    let (ok_blk, _, ok_input, _, _) = generic(&sh);
    let w_ok = witness::build_shaped(&sh, ok_blk.attention(), ok_blk.feed_forward(), &ok_input).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let plane = |p: usize| -> Vec<i16> { w_ok.planes[p].iter().map(|v| *v as i16).collect() };
    let ctx = *blake3::hash(b"native r9: over-cap door").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).unwrap();
    let blocks = vec![blk];
    let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(&sh, 1), ctx, expected, &blocks, &[(0, 0)], &super::trained_calib_tests::synthetic_statement(&sh, &blocks));
    eprintln!("R9 over-cap: the run statement {}", match &st { Ok(_) => "constructs (the run prover must refuse)".to_string(), Err(e) => format!("refuses: {e}") });
    if let Err(e) = &st {
        assert!(e.contains("D30 / B-8"), "the run statement refused for another reason: {e}");
    }
    if let Ok(st) = st {
        struct One(Option<Witness>);
        impl super::run::RunWitnessSource for One {
            fn witness(&mut self, _k: usize) -> Result<Witness, String> {
                self.0.take().ok_or_else(|| "consumed".into())
            }
            fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
                Err("one block".into())
            }
        }
        let mut segs = 0usize;
        let e = super::run::prove_run(&st, &blocks, &mut One(Some(w_ok)), owners, &mut |_, _| {
            segs += 1;
            Ok(())
        })
        .expect_err("the run prover admitted an over-cap block");
        assert!(e.contains("D30 / B-8") && segs == 0, "{e} ({segs} segments)");
    }
}

// ------------------------------------------------------------ completeness

/// **Completeness on a GENERIC honest witness** (dense weights, heads that
/// differ, the INDEPENDENT reference kernel's output): the DD witness's
/// output is the kernel's bit for bit, every dictionary slot holds the floor
/// quotient and its remainders, the multiplicities count every score entry
/// once, and a one-block bound run proves and verifies; a two-block run with
/// a second, different block proves and verifies too.
#[test]
fn a_generic_honest_witness_proves_and_verifies_under_dd() {
    let sh = dd_rung();
    let (blk, w, input, exp, act) = generic(&sh);
    let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the honest DD witness");
    let ids = Ids::new(&sh).unwrap();
    assert_eq!(true_words(&sh, &wit, ids.at(A_X2)), kernel_out(&sh, &w, &input, &exp, &act), "the DD witness and the independent reference kernel disagree");
    // heads differ (the recipe's S19-F1 regime)
    let s8 = &wit.planes[ids.at(A_S8)];
    let blkln = sh.t_pad * sh.t_pad;
    assert!((1..sh.q_heads).any(|h| s8[h * blkln..(h + 1) * blkln] != s8[..blkln]), "every head carries the same scores");
    // the dictionary, slot by slot (B-1, B-7)
    let ecol = blk.attention().dd_e_column(DD_CAP).unwrap();
    let (cap, tp) = (DD_CAP, sh.t_pad);
    let sum = &wit.planes[ids.at(A_SUM)];
    let mut counted = 0i64;
    for ht in 0..sh.size(Dom::Ht) {
        for k in 0..cap {
            let x = ht * cap + k;
            let q = (ecol[k] << 9) / sum[ht];
            assert_eq!(wit.planes[ids.pdict()][x], q, "slot ({ht}, {k}) is not the floor quotient");
            counted += wit.planes[ids.mdd()][x];
        }
    }
    assert_eq!(counted as usize, sh.size(Dom::S), "the multiplicities do not count every score entry once");
    assert_eq!(super::protocol::dd_misses(&Layout::for_shape(&sh).unwrap(), &wit, &ecol), 0);
    let _ = tp;
    let one = super::trained_calib_tests::prove_one_bound(&sh, &blk, wit).expect("the DD block proves");
    super::trained_calib_tests::verify_one_bound(&sh, &blk, &one.expected.to_bytes(), &one.seg).expect("the DD block verifies");
    eprintln!("R9 DD rung, one block: segment {} B", one.seg.len());
}

// --------------------------------------------------------------- mutations

/// prove one block at the DD rung with the current hooks (a cheating
/// prover: CS-3's refusals off) — the PROVER must produce a receipt — and
/// return the VERIFIER's verdict under the same hooks
fn prove_and_verify(sh: &Shape, blk: &BlockPublic, input: &[i16]) -> Result<(), String> {
    let wit = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), input).unwrap_or_else(|e| panic!("the (mutated) witness did not build: {e}"));
    let _cheat = super::protocol::CheatingProver::on();
    let one = super::trained_calib_tests::prove_one_bound(sh, blk, wit).unwrap_or_else(|e| panic!("the prover produced no receipt, so the verifier was never asked: {e}"));
    super::trained_calib_tests::verify_one_bound(sh, blk, &one.expected.to_bytes(), &one.seg)
}

/// run one mutation: against its LAPSED construction it must pass (the test
/// is not vacuous), against the construction as built it must be rejected
fn mutation(name: &str, cheat: u8, lapse: u8) {
    let _h = Hooks;
    let sh = dd_rung();
    let (blk, _, input, _, _) = generic(&sh);
    super::witness::set_dd_cheat(cheat);
    super::argument::set_dd_lapse(lapse);
    prove_and_verify(&sh, &blk, &input).unwrap_or_else(|e| panic!("{name}: the cheat did NOT pass the lapsed construction, so this test proves nothing: {e}"));
    super::argument::set_dd_lapse(0);
    let e = prove_and_verify(&sh, &blk, &input).expect_err(&format!("{name}: the cheat VERIFIED against the construction as built"));
    eprintln!("R9 mutation {name}: passes the lapse, rejected as built: {}", e.chars().take(140).collect::<String>());
}

/// **CHECK.md D-3: an unconstrained dictionary position.** A padding slot
/// (e = 0) of row (0, 0) holds the wrong tuple (Sum, 0, 1) with a count moved
/// onto it, and a masked score entry claims P = 1 (the PV accumulator follows
/// it, so only the dictionary can object). With the division clauses gated
/// off that slot the proof VERIFIES; with every slot constrained (B-1) it is
/// rejected.
#[test]
fn d3_an_unconstrained_slot_is_caught() {
    mutation("D-3 unconstrained slot", 1, super::argument::DD_LAPSE_GATE_LAST_SLOT);
}

/// **CHECK.md D-4: the row key dropped.** An entry of one row presents
/// another row's quotient for the same e, one count moved between the two
/// rows' slots. Keyless tuples balance; keyed by the row's Sum they do not.
#[test]
fn d4_a_dropped_row_key_is_caught() {
    mutation("D-4 row key dropped", 2, super::argument::DD_LAPSE_DROP_KEY);
}

/// **D30 condition 3: the dictionary's LogUp columns in the single value-0
/// sum claim.** An entry's P off by one with no count moved: its tuple helper
/// still satisfies its row relation, so only the sum claim can object. Left
/// out of the claim the proof VERIFIES; in it, rejected.
#[test]
fn the_dictionary_helpers_out_of_the_sum_claim_is_caught() {
    mutation("helper out of the sum claim", 3, super::argument::DD_LAPSE_OUT_OF_SUM);
}

/// **CHECK.md D-8: multiplicities chosen after alpha.** The construction
/// commits `M_dd` in `A` before beta, gamma and alpha (B-2), so a prover who
/// chooses its counts after alpha can only put them into the table helper —
/// one count moved from row (0, 0)'s e = 0 slot onto a padding slot — and the
/// dictionary zero-check's `g (alpha - tau) - M_dd` sees the committed plane
/// disagree. Rejected. (The lapsed construction, multiplicities in `H` after
/// alpha, is CHECK.md's toy D-8, 20 of 20; it is not built here.)
#[test]
fn d8_multiplicities_after_alpha_are_caught() {
    let _h = Hooks;
    let sh = dd_rung();
    let (blk, _, input, _, _) = generic(&sh);
    super::protocol::set_dd_moved_multiplicity(Some((0, DD_CAP - 1)));
    let e = prove_and_verify(&sh, &blk, &input).expect_err("D-8: counts chosen after alpha VERIFIED");
    eprintln!("R9 mutation D-8: rejected: {}", e.chars().take(140).collect::<String>());
    super::protocol::set_dd_moved_multiplicity(None);
    prove_and_verify(&sh, &blk, &input).expect("the same block without the move verifies");
}

/// the TinyLlama / 8B DD shapes build with their real calibrations' classes
#[test]
fn the_t128_dd_shapes_build_and_lay_out() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    for (dd, plain) in [
        (Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap(), Shape::tinyllama_trained(128, &tl, 9).unwrap()),
        (Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap(), Shape::llama3_8b_trained(128, &l8, 9).unwrap()),
    ] {
        let (a, b) = (Layout::for_shape(&dd).unwrap(), Layout::for_shape(&plain).unwrap());
        let n = 1u64 << dd.log_cols;
        let (ta, tb) = (dd.totals(), plain.totals());
        eprintln!(
            "R9 COUNT {}: A rows {} -> {} , H rows {} -> {}, committed {} -> {} elements ({:+.2}%), U8 lookups {} -> {} ({:+.2}%), receipt {} -> {} B",
            plain.profile,
            b.a_rows,
            a.a_rows,
            b.h_rows,
            a.h_rows,
            (b.a_rows as u64 + b.h_rows as u64) * n,
            (a.a_rows as u64 + a.h_rows as u64) * n,
            100.0 * ((a.a_rows + a.h_rows) as f64 / (b.a_rows + b.h_rows) as f64 - 1.0),
            tb.u8_lookups,
            ta.u8_lookups,
            100.0 * (ta.u8_lookups as f64 / tb.u8_lookups as f64 - 1.0),
            tb.receipt_bytes.total,
            ta.receipt_bytes.total
        );
        assert_eq!(dd.norm_calibration(), plain.norm_calibration());
        let _ = NormCalibration::FROZEN;
    }
}
