//! **INDEPENDENT ADVERSARIAL REVIEW, token I/O rung R1 (2026-10-17).** TEST
//! CODE ONLY, in the reviewer's SCRATCH copy only (never in the reviewed
//! tree). A child of `token_io::run`, so a forger's copy of the prover can
//! drive the private segment geometry exactly as someone with the source.
//!
//! Two kinds of test:
//! * `RV-xx` controls the author did not write: each MUST be refused, at the
//!   predicted slot (asserted);
//! * `TR-x` demonstrations of review findings: the current behaviour is
//!   PRINTED (marker `REVIEW-R1 FINDING`), not asserted, so a later fix does
//!   not turn the review's evidence into a red test.
//!
//! Public synthetic data only (the author's fixtures). No privacy claim.

use super::*;
use super::super::tests::{fx_generic, honest, profile, prove_pipe, statement, Fx};
use super::super::super::protocol::CheatingProver;
use super::super::super::run::RUN_PROFILE_TOKEN_IO_RUNG_TC;

fn ctx() -> Digest {
    // the author's fixture context (`tests::ctx`, private there)
    *blake3::hash(b"token I/O R1: synthetic run context").as_bytes()
}

/// prove a pipeline with the CHEATING prover (none of the honest prover's
/// refusals), then verify; the verifier's answer
fn forge(fx: &Fx, tp: &TokenProfile, mut pipe: HonestPipeline) -> Result<(), String> {
    let p = {
        let _cheat = CheatingProver::on();
        prove_pipe(fx, tp, &mut pipe).unwrap_or_else(|e| panic!("the cheating prover did not produce a receipt: {e}"))
    };
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs)
}

fn expect_refused(id: &str, what: &str, predicted: &[&str], res: Result<(), String>) {
    match res {
        Ok(()) => {
            eprintln!("REVIEW-R1 CONTROL {id} | {what} | predicted {predicted:?} | actual: ACCEPTED | A FORGERY VERIFIED");
            panic!("REVIEW {id} ({what}): A FORGERY VERIFIED");
        }
        Err(e) => {
            let hit = predicted.iter().any(|p| e.starts_with(p));
            eprintln!("REVIEW-R1 CONTROL {id} | {what} | predicted {predicted:?} | actual: {} | {}", e.chars().take(170).collect::<String>(), if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" });
            assert!(hit, "REVIEW {id} ({what}) was refused elsewhere than predicted {predicted:?}: {e}");
        }
    }
}

fn finding(id: &str, what: &str, outcome: &str) {
    eprintln!("REVIEW-R1 FINDING {id} | {what} | {outcome}");
}

fn outcome(r: &Result<(), String>) -> String {
    match r {
        Ok(()) => "ACCEPTED".into(),
        Err(e) => format!("refused: {}", e.chars().take(170).collect::<String>()),
    }
}

fn bump(v: i16) -> i16 {
    if v < i16::MAX { v + 1 } else { v - 1 }
}

// ------------------------------------------------------------------ stage IN

/// RV-01/02: the histogram mass of table row 0 moved onto a PADDED table
/// entry, where `tau(v) = tau(0)`: the LogUp identity and the LogUp sum cannot
/// see the move (the two fractions are equal), so ONLY the table zero-check's
/// pad clause (`(1 - supp_V)(m + zeta h_tab)`) can refuse it. Shows that
/// clause is live, both on `V_pad`'s pad and on the P-3 lift above it.
#[test]
fn review_stage_in_multiplicity_moved_onto_a_padded_table_entry() {
    let fx = fx_generic();
    let tp = profile(&fx);
    for (id, at, what) in [("RV-01", tp.v, "m: one count of row 0 moved to padded entry V (tau(V) = tau(0))"), ("RV-02", tp.tier.stage_n() - 3, "m: one count of row 0 moved to a lifted entry above V_pad")] {
        let mut p = honest(&fx, &tp);
        p.stage_in.mult[0] = p.stage_in.mult[0].sub(Fp::ONE);
        p.stage_in.mult[at] = p.stage_in.mult[at].add(Fp::ONE);
        expect_refused(id, what, &["stage IN slot 02 "], forge(&fx, &tp, p));
    }
}

// ------------------------------------------------------------------ stage OUT pads and rows

/// RV-03..06: the final norm's pad terms and the public row. `x` on a lifted
/// entry above `d_pad` is read by no IO slot and no SS term, so only DZC's
/// pad clause binds it; `y` on a pad column changes no logit (the head's pad
/// columns are zero), so only DZC's pad clause binds it; `x` on a pad column
/// inside `d_pad` meets IO-in first; logits from row 0 (the BOS row).
#[test]
fn review_stage_out_pad_entries_and_row_zero() {
    let fx = fx_generic();
    let tp = profile(&fx);
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_X][tp.d_pad + 5] = Fp::new(3);
        expect_refused("RV-03", "x nonzero on a lifted entry above d_pad (no IO / SS term reads it)", &["stage OUT slot 05 "], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_X][tp.d + 1] = Fp::new(3);
        expect_refused("RV-04", "x nonzero on a pad column inside d_pad", &["stage OUT slot 00 ", "stage OUT slot 05 "], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_Y][tp.d + 1] = Fp::ONE;
        expect_refused("RV-05", "y = 1 on a pad column (no logit changes)", &["stage OUT slot 05 "], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let ov = stage_out::out_values(&tp, &fx.tables, &stage_out::row_of(&tp, p.planes.last().unwrap(), 0), false).unwrap();
        p.stage_out = stage_out::witness_from_values(&tp, &ov).unwrap();
        p.out_plane = stage_out::endpoint_plane(&tp, ov.tok as u64);
        expect_refused("RV-06", "public row: stage OUT computes from row 0 (the BOS row)", &["stage OUT slot 00 "], forge(&fx, &tp, p));
    }
}

/// RV-31..33: the vocabulary and isqrt-limb pad terms. Each forgery leaves
/// the output token honest, so ONLY a pad clause can object: a second hot
/// selector entry on a padded vocabulary entry beside the honest one (A2, A3,
/// A6 all sum over `supp_V` and cannot see it); a nonzero difference limb on
/// a padded entry; a nonzero odd entry of the isqrt limb plane (To entry 1).
#[test]
fn review_vocabulary_and_limb_pad_terms() {
    let fx = fx_generic();
    let tp = profile(&fx);
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_E][tp.v + 2] = Fp::ONE;
        expect_refused("RV-31", "a second hot e entry on a padded vocabulary entry beside the honest one", &["stage OUT slot 06 "], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_LAM0][tp.v + 1] = Fp::new(5);
        expect_refused("RV-32", "a nonzero difference limb (a byte) on a padded vocabulary entry", &["stage OUT slot 06 "], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_LIMB][1] = Fp::ONE;
        expect_refused("RV-33", "isqrt limb plane: a nonzero odd entry (To entry 1 of limb sub-plane 0)", &["stage OUT slot 02 ", "stage OUT slot 03 "], forge(&fx, &tp, p));
    }
}

/// TR (informational): the TI-1 lift of `To` gives `tok` and `M` a second
/// entry that no clause pad-zeroes (D and Dsq have TZC's pad clause).
#[test]
fn review_to_entry_one_of_tok_and_m_is_unconstrained() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut p = honest(&fx, &tp);
    p.stage_out.planes[stage_out::A_TOK][1] = Fp::new(5);
    p.stage_out.planes[stage_out::A_M][1] = Fp::new(7);
    let r = forge(&fx, &tp, p);
    finding("TR-To1", "free values in To entry 1 of tok (5) and M (7), everything else honest", &outcome(&r));
}

// ------------------------------------------------------------------ the boundaries

/// RV-07/08: the two new two-site boundaries are ONE commitment for both of
/// their stages. (a) stage IN honest on B_in = E[tok], block 0 run (and
/// everything after it) on another input; (b) B_out committed with a changed
/// word of row T - 1 and stage OUT computed from it, block L - 1 honest.
#[test]
fn review_b_in_and_b_out_bind_their_two_stages() {
    let fx = fx_generic();
    let tp = profile(&fx);
    {
        let mut p = honest(&fx, &tp);
        let mut b2 = p.b_in.clone();
        let at = 3 * tp.d_pad + 7;
        b2[at] = bump(b2[at]);
        let (w, planes, ov, wout, out_plane) = downstream(&fx.sh, &tp, &fx.tables, &fx.blocks, &b2, false).unwrap();
        p.witnesses = w;
        p.planes = planes;
        p.out_values = ov;
        p.stage_out = wout;
        p.out_plane = out_plane;
        expect_refused("RV-07", "B_in: stage IN honest (E[tok]), block 0 proved on another input", &["block 0", "boundary 0"], forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let last = p.planes.len() - 1;
        let at = (tp.tokens - 1) * tp.d_pad;
        p.planes[last][at] = bump(p.planes[last][at]);
        let ov = stage_out::out_values(&tp, &fx.tables, &stage_out::row_of(&tp, &p.planes[last], tp.tokens - 1), false).unwrap();
        p.stage_out = stage_out::witness_from_values(&tp, &ov).unwrap();
        p.out_plane = stage_out::endpoint_plane(&tp, ov.tok as u64);
        p.out_values = ov;
        let pred = format!("block {}", fx.blocks.len() - 1);
        expect_refused("RV-08", "B_out: committed with row T-1 changed, stage OUT on it, block L-1 honest", &[pred.as_str()], forge(&fx, &tp, p));
    }
}

// ------------------------------------------------------------------ segments

/// RV-09..12: segments moved between positions of one receipt, or between two
/// honest receipts (another prompt, so other roots).
#[test]
fn review_segments_moved_between_stages_and_runs() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pa = honest(&fx, &tp);
    let a = prove_pipe(&fx, &tp, &mut pa).unwrap();
    verify_token_run(&a.st, &fx.blocks, &fx.tables, &a.segs).expect("honest run A verifies");
    let mut s = a.segs.clone();
    s.swap(1, 2);
    expect_refused("RV-09", "the two block segments swapped", &["token I/O", "wire", "private", "block", "segment"], verify_token_run(&a.st, &fx.blocks, &fx.tables, &s));
    let mut s = a.segs.clone();
    s[2] = s[1].clone();
    expect_refused("RV-10", "block 0's segment repeated as block 1's", &["token I/O", "wire", "private", "block", "segment"], verify_token_run(&a.st, &fx.blocks, &fx.tables, &s));
    let mut fx2 = fx_generic();
    fx2.tokens[7] = (fx2.tokens[7] + 1) % fx2.tables.v as u64;
    let mut pb = honest(&fx2, &tp);
    let b = prove_pipe(&fx2, &tp, &mut pb).unwrap();
    verify_token_run(&b.st, &fx2.blocks, &fx2.tables, &b.segs).expect("honest run B verifies");
    let mut s = a.segs.clone();
    let last = s.len() - 1;
    s[last] = b.segs[last].clone();
    let r = verify_token_run(&a.st, &fx.blocks, &fx.tables, &s);
    expect_refused("RV-11", "run B's stage OUT segment in run A's receipt", &["token I/O wire: this segment belongs to another run"], r);
    let r = verify_token_run(&a.st, &fx.blocks, &fx.tables, &b.segs);
    expect_refused("RV-12", "run B's whole receipt under run A's statement", &["token I/O wire: this segment belongs to another run"], r);
}

// ------------------------------------------------------------------ statement binding

fn model_with(sh: &Shape, blocks: &[BlockPublic], revision: &str) -> TrainedModelStatement {
    use super::super::super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind};
    let src = ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/token-io-r1/synthetic".into(),
        revision: revision.into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: blocks.len() as u32,
    };
    let mut prov = Provenance::recipe("token-io-r1/synthetic", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = super::super::super::shape::trained_rope_theta(sh.profile).expect("a trained profile");
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    let recs = blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    TrainedModelStatement::new(sh, RUN_PROFILE_TOKEN_IO_RUNG_TC, src, cal, recs).expect("the synthetic trained-model statement")
}

/// RV-13..21: every field of the token-I/O statement changed alone, each
/// value in its class: the honest receipt must not verify under it (refused
/// at construction or by the verifier).
#[test]
fn review_every_statement_field_is_bound() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs).expect("the honest run verifies");
    let roots = p.st.roots();
    let digests: Vec<Digest> = fx.blocks.iter().map(|b| b.digest()).collect();
    let rs = |l: usize| RunShape::new(fx.sh.clone(), l, RUN_PROFILE_TOKEN_IO_RUNG_TC).unwrap();
    let other_ctx = *blake3::hash(b"review: another context").as_bytes();
    let model2 = model_with(&fx.sh, &fx.blocks, "token-io-r1-review-other-revision");
    let n = fx.norm;
    let cases: Vec<(&str, Result<TokenRunStatement, String>)> = vec![
        ("RV-13 another context", TokenRunStatement::new(rs(2), other_ctx, digests.clone(), &fx.model, &fx.tables, fx.bos, n, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-14 another in-class BOS id (2)", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, 2, n, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-15 Ceps + 1 (same window)", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, fx.bos, FinalNorm { ceps: n.ceps + 1, ..n }, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-16 g0 = 126", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, fx.bos, FinalNorm { g0: 126, ..n }, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-17 the tier renamed, same levers", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, fx.bos, n, SelectorVariant::PublicRow, Tier { name: "review-renamed", ..Tier::R1_MVP }, roots)),
        ("RV-18 the two roots swapped", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, fx.bos, n, SelectorVariant::PublicRow, Tier::R1_MVP, (roots.1, roots.0))),
        ("RV-19 another trained-model statement (other revision)", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &model2, &fx.tables, fx.bos, n, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-20 the block digests in the other order", TokenRunStatement::new(rs(2), ctx(), digests.iter().rev().copied().collect(), &fx.model, &fx.tables, fx.bos, n, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
        ("RV-21 Cn = 2047 (in class; not refusal-free)", TokenRunStatement::new(rs(2), ctx(), digests.clone(), &fx.model, &fx.tables, fx.bos, FinalNorm { cn: n.cn - 1, ..n }, SelectorVariant::PublicRow, Tier::R1_MVP, roots)),
    ];
    for (what, st) in cases {
        match st {
            Err(e) => eprintln!("REVIEW-R1 CONTROL {what} | refused at construction | {} | AS PREDICTED", e.chars().take(150).collect::<String>()),
            Ok(st2) => {
                let blocks: Vec<BlockPublic> = if what.starts_with("RV-20") { fx.blocks.iter().rev().cloned().collect() } else { fx.blocks.clone() };
                let r = verify_token_run(&st2, &blocks, &fx.tables, &p.segs);
                expect_refused(what, "the honest receipt under a statement with this one field changed", &["token I/O"], r);
            }
        }
    }
}

// ------------------------------------------------------------------ the owner check

/// RV-22..27 and TR-owner: the owner's decommitment changed in each part it
/// carries; and what `owner_rebuild_root` does NOT check by itself.
#[test]
fn review_the_owner_check() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let want = pipe.out_values.tok;
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs).expect("the honest run verifies");
    let tag = fx.sh.hash_tag();
    let (_ir, or) = p.st.roots();
    let words = owner_rebuild_root(&p.st.out_spec, &or, &p.hand.output, &tag).expect("the honest output decommitment rebuilds its root");
    assert_eq!(words[0], Fp::new(want as u64));
    let n = 1usize << tp.tier.ep_log_n;
    let q = tp.tier.opened_cols;
    let mut cases: Vec<(&str, Decommitment, &str)> = Vec::new();
    let mut d = p.hand.output.clone();
    d.salts[5][0] ^= 1;
    cases.push(("RV-22 one salt bit flipped (same length)", d, "does not rebuild"));
    let mut d = p.hand.output.clone();
    d.salts.swap(0, 1);
    cases.push(("RV-23 two salts swapped", d, "does not rebuild"));
    let mut d = p.hand.output.clone();
    d.data[n + 3] = d.data[n + 3].add(Fp::ONE);
    cases.push(("RV-24 a word of a MASK row changed", d, "does not rebuild"));
    let mut d = p.hand.output.clone();
    d.data[0] = Fp::new(((want + 1) % tp.v) as u64);
    cases.push(("RV-25 the token word changed (another id)", d, "does not rebuild"));
    let mut d = p.hand.output.clone();
    let (a, b) = d.pads.split_at_mut(q);
    a.swap_with_slice(&mut b[..q]);
    cases.push(("RV-26 the pads of rows 0 and 1 swapped", d, "does not rebuild"));
    let mut d = p.hand.output.clone();
    d.data[7] = Fp(P);
    cases.push(("RV-27 a noncanonical word", d, "noncanonical"));
    for (what, dec, want_err) in cases {
        let e = owner_rebuild_root(&p.st.out_spec, &or, &dec, &tag).err().unwrap_or_else(|| panic!("REVIEW {what}: the owner check ACCEPTED"));
        let hit = e.contains(want_err);
        eprintln!("REVIEW-R1 CONTROL {what} | owner check | actual: {e} | {}", if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" });
        assert!(hit, "{what}: {e}");
    }
    // TR-owner: the rebuild alone checks no plane semantics (BOS at 0, zero
    // pad words, an id in [0, V)): a plane with all three wrong, sealed by
    // the same spec, rebuilds its root (no receipt could carry it; the
    // semantics are the caller's, DESIGN 3.4 / D26 C-d)
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let mut bad_in = vec![Fp::ZERO; tp.in_ep_words()];
    bad_in[0] = Fp::new(tp.bos + 1);
    bad_in[tp.tokens + 3] = Fp::new(9);
    let mut bad_out = vec![Fp::ZERO; tp.out_ep_words()];
    bad_out[0] = Fp::new(tp.v as u64 + 5);
    bad_out[1] = Fp::new(4);
    let ((r_in, r_out), owners) = seal_endpoints(&ins, &outs, &bad_in, &bad_out, &tag).unwrap();
    let di = Decommitment { data: owners.input.data.clone(), pads: owners.input.pads.clone(), salts: owners.input.salts.clone() };
    let dout = Decommitment { data: owners.output.data.clone(), pads: owners.output.pads.clone(), salts: owners.output.salts.clone() };
    let ri = owner_rebuild_root(&ins, &r_in, &di, &tag).map(|_| ()).map_err(|e| e.to_string());
    let ro = owner_rebuild_root(&outs, &r_out, &dout, &tag).map(|_| ()).map_err(|e| e.to_string());
    finding("TR-owner", "owner_rebuild_root on a plane with a non-BOS position 0 and a nonzero pad word (input) / an id >= V and a nonzero pad word (output)", &format!("input {}, output {}", outcome(&ri), outcome(&ro)));
}

// ------------------------------------------------------------------ the head class edge

/// RV-28: completeness at the multiplier class edge (every `m_j = 2^12`); and
/// TR-head: the door's class of head words (an int8 `-128` is admitted; the
/// window is derived with `127^2`), with the exact arithmetic at the three
/// registered shapes showing it never matters there.
#[test]
fn review_head_class_edges() {
    let mut fx = fx_generic();
    fx.tables.mult = vec![1i64 << MULT_BITS; fx.tables.v];
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let want = pipe.out_values.tok;
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    let r = verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs);
    eprintln!("REVIEW-R1 CONTROL RV-28 | honest run with every multiplier 2^12 (class edge) | {} | {}", outcome(&r), if r.is_ok() { "AS PREDICTED (complete)" } else { "NOT AS PREDICTED" });
    r.expect("RV-28: the honest run at the multiplier class edge did not verify");
    let tag = fx.sh.hash_tag();
    assert_eq!(owner_rebuild_root(&p.st.out_spec, &p.st.roots().1, &p.hand.output, &tag).unwrap()[0], Fp::new(want as u64));
    let mut fx2 = fx_generic();
    fx2.tables.head[0] = -128;
    let door = TokenProfile::new(&fx2.sh, &fx2.tables, fx2.bos, fx2.norm, SelectorVariant::PublicRow, Tier::R1_MVP).map(|_| ());
    finding("TR-head", "a head word -128 at the token-I/O door (DESIGN 3.1: W' clipped to [-127, 127])", &outcome(&door));
    let bits = |v: u128| 128 - v.leading_zeros();
    for (name, d, v) in [("R1", 384u128, 300u128), ("TinyLlama", 2048, 32_000), ("Llama-3-8B", 4096, 128_256)] {
        let log_v = (v.next_power_of_two()).trailing_zeros();
        let top127 = ((2 * d * 127 * 127 * 4096) << log_v) + (v - 1);
        let window = bits(top127);
        let limbs = window.div_ceil(8);
        let top128 = ((2 * d * 127 * 128 * 4096) << log_v) + (v - 1);
        let complete = top128 < 1u128 << (8 * limbs);
        let sound = (1u128 << (8 * limbs)) + top128 < u128::from(P);
        eprintln!("REVIEW-R1 ARITH | {name}: window(127^2) {window} bits, {limbs} limbs; with -128 the honest maximum is {} bits; complete {complete}, no-wrap {sound}", bits(top128));
        assert!(complete && sound, "{name}: the -128 head word breaks the derived window");
    }
}

// ------------------------------------------------------------------ the security tier (D27)

fn run_at_tier(fx: &Fx, tier: Tier) -> Result<(), String> {
    let tp = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, tier)?;
    let mut pipe = honest_pipeline(&fx.sh, &tp, &fx.tables, &fx.blocks, &fx.tokens)?;
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp)?;
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag())?;
    let digests: Vec<Digest> = fx.blocks.iter().map(|b| b.digest()).collect();
    let st = TokenRunStatement::new(RunShape::new(fx.sh.clone(), fx.blocks.len(), RUN_PROFILE_TOKEN_IO_RUNG_TC)?, ctx(), digests, &fx.model, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, tier, roots)?;
    let mut segs = Vec::new();
    prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .map_err(|e| format!("PROVE: {e}"))?;
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs).map_err(|e| format!("VERIFY: {e}"))
}

/// TR-tier: what the door admits as a tier, and what a run at it does. D27:
/// "the verifier takes a minimum tier as policy and refuses receipts below
/// it"; DESIGN B-1: token endpoints at 2^8 rate 1/8, stage commitments at row
/// width >= 2^12 (the v1 geometry, 2^8 rate 1/4, was the 2^-66.3 hole).
#[test]
fn review_the_tier_door() {
    let fx = fx_generic();
    let r1 = Tier::R1_MVP;
    let cases: Vec<(&str, Tier)> = vec![
        ("R1_MVP (control)", r1),
        ("token endpoints at 2^8 rate 1/4 (the v1 B-1 hole), name unchanged", Tier { ep_inv_rate: 4, ..r1 }),
        ("token endpoints at 2^8 rate 1/2 (zero relative distance)", Tier { ep_inv_rate: 2, ..r1 }),
        ("stage commitments at 2^9 (below the B-1 floor 2^12)", Tier { stage_log_n: 9, ..r1 }),
        ("Q = 128 (the column-check lever lowered)", Tier { opened_cols: 128, ..r1 }),
        ("Q = 1", Tier { opened_cols: 1, ..r1 }),
    ];
    for (what, t) in cases {
        let door = t.check();
        let pe = t.per_opening_log2(t.ep_log_n, t.ep_inv_rate);
        let ps = t.per_opening_log2(t.stage_log_n, t.stage_inv_rate);
        let r = if door.is_ok() {
            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| run_at_tier(&fx, t))) {
                Ok(r) => r,
                Err(e) => Err(format!("PANIC: {}", e.downcast_ref::<String>().cloned().or_else(|| e.downcast_ref::<&str>().map(|s| s.to_string())).unwrap_or_default())),
            }
        } else {
            Err(format!("door: {}", door.clone().unwrap_err()))
        };
        finding("TR-tier", what, &format!("door {} | per-opening endpoint 2^{pe:.2} stage 2^{ps:.2} | run {}", if door.is_ok() { "ADMITS" } else { "refuses" }, outcome(&r)));
    }
}

// ------------------------------------------------------------------ the selector variant (D26 C-a)

/// `prove_token_run` without its one variant refusal: a forger's prover.
fn prove_without_the_variant_check(st: &TokenRunStatement, blocks: &[BlockPublic], tables: &TokenTables, src: &mut dyn TokenRunSource, owners: TokenOwners) -> Result<Vec<Vec<u8>>, String> {
    let (sh, l, tp) = (st.sh(), st.l(), &st.tp);
    let mut rng = ZkRng::from_os(&super::super::super::hash_domain::run_seed_domain(st.rs.profile())).map_err(|e| format!("randomness: {e}"))?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();
    let TokenOwners { input: in_ep, output: out_ep } = owners;
    let mut segs = Vec::new();
    let start = position_tag(&tr);
    let (win, b_in_plane) = src.stage_in()?;
    let in_lay = stage_in::layout(sh, tp);
    let b0 = st.boundary_spec(0)?;
    let inp = stage_in::prove(&in_lay, tp, tables, win, &b0, &b_in_plane, in_ep, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    segs.push(st.in_geom(&in_lay).encode(&inp.seg, &binding, &start, &end)?);
    let mut pending: Vec<ZClaim> = inp.pending_b;
    let mut prev: (BoundarySpec, PreparedBoundary) = (b0, inp.b_owner);
    for k in 0..l {
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = std::time::Instant::now();
        let start = position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let plane = src.boundary_plane(k)?;
        let words: Vec<Fp> = plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
        let cur = boundary::prepare(&spec, &words, &ntt, &mut rng, &tag)?;
        protocol::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        let lay = st.block_layout(k)?;
        let wit = src.witness(k)?;
        let core = protocol::prove_core(sh, &lay, &blocks[k], wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
        let [ic, oc] = core.io_claims;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, powner) = prev;
        let in_open = powner.into_opening(&pspec, &claims, &mut tr)?;
        pending = oc;
        let end = position_tag(&tr);
        let seg = Segment { b_root: Some(cur.root()), a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: None };
        segs.push(wire::encode_segment(&seg, &lay, st.block_geom(k)?, &binding, &start, &end)?);
        prev = (spec, cur);
    }
    let start = position_tag(&tr);
    let wout = src.stage_out()?;
    let out_lay = stage_out::layout(sh, tp);
    let (bspec, bowner) = prev;
    let outp = stage_out::prove(&out_lay, tp, tables, wout, &bspec, bowner, pending, out_ep, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    segs.push(st.out_geom(&out_lay)?.encode(&outp.seg, &binding, &start, &end)?);
    Ok(segs)
}

/// TR-variant: a receipt built with the PUBLIC-ROW construction under a
/// statement that names variant P (or F). The prover refuses P/F at R1; does
/// the VERIFIER? (D26 C-a: the variant is fixed by the run statement; a
/// verifier that does not implement a variant can only be configured to
/// accept it by mistake.)
#[test]
fn review_an_unbuilt_variant_at_the_verifier() {
    let fx = fx_generic();
    for v in [SelectorVariant::SealedInInput, SelectorVariant::SealedInOutput] {
        let tp = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, v, Tier::R1_MVP).unwrap();
        let mut pipe = honest(&fx, &tp);
        let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
        let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
        let st = statement(&fx, roots, v).unwrap();
        let segs = prove_without_the_variant_check(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners).unwrap();
        let r = verify_token_run(&st, &fx.blocks, &fx.tables, &segs);
        finding("TR-variant", &format!("public-row receipt under a statement naming variant {}", v.tag()), &format!("verify_token_run {}; input endpoint rows {} (a one-site M-7 endpoint, not D26's two-site geometry)", outcome(&r), st.in_spec.commitment_rows()));
    }
}

// ------------------------------------------------------------------ BOS at its class edge

/// RV-29: completeness with BOS = 0 (the class edge of [0, V)).
#[test]
fn review_bos_zero_is_complete() {
    let mut fx = fx_generic();
    fx.bos = 0;
    fx.tokens[0] = 0;
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    let r = verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs);
    eprintln!("REVIEW-R1 CONTROL RV-29 | honest run with BOS = 0 | {} | {}", outcome(&r), if r.is_ok() { "AS PREDICTED (complete)" } else { "NOT AS PREDICTED" });
    r.expect("RV-29");
    // and position 0 = 0 with the statement's BOS 1 is refused (the BOS clause)
    let fx1 = fx_generic();
    let tp1 = profile(&fx1);
    let mut q = honest(&fx1, &tp1);
    let mut toks = fx1.tokens.clone();
    toks[0] = 0;
    let (w, b, plane) = {
        let _cheat = CheatingProver::on();
        stage_in::honest_inputs(&tp1, &fx1.tables, &toks).unwrap()
    };
    q.stage_in = w;
    q.in_plane = plane;
    let (wi, planes, ov, wout, out_plane) = downstream(&fx1.sh, &tp1, &fx1.tables, &fx1.blocks, &b, false).unwrap();
    q.b_in = b;
    q.witnesses = wi;
    q.planes = planes;
    q.out_values = ov;
    q.stage_out = wout;
    q.out_plane = out_plane;
    expect_refused("RV-30", "position 0 = id 0 (a real row, consistent lookup) under BOS 1", &["stage IN slot 01 "], forge(&fx1, &tp1, q));
}
