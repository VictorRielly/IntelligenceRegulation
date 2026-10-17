//! FA4 — independent identity review tests.
//!
//! Reviewer: Claude Fable 5.1, independent reviewer, 2026-09-07 session.
//! Baseline: branch `zk60-fable-review`, integrator HEAD 52a13d1.
//! Design note: `docs/zkmatrix-poc/ZK60_FABLE_MODEL_IDENTITY.md`.
//!
//! PUBLIC API ONLY. Tiny diagnostic shape T=2, d=f=16, log_cols=5, inverse
//! rate 4, 12 column checks: these are NOT deployment security parameters.
//! Every explicit seed is a PUBLIC fixture and provides NO privacy; `None`
//! draws OS entropy and is used only to show a finding is not a fixture
//! artefact.
//!
//! Three groups of tests:
//!
//!  (a) `gap_*` — pins of the CURRENT behaviour that record a MISSING
//!      CONSTRAINT. Each asserts today's verdict (ACCEPT where a repaired
//!      approved-P3 identity boundary must REJECT). When the P3 consistency
//!      repair lands, these assertions MUST FLIP and the tests must be
//!      rewritten against the new boundary, not deleted. A passing `gap_*`
//!      test is evidence that the constraint is still missing, never that
//!      P3 model identity is enforced.
//!  (b) `p1_*` — the independently registered P1 boundary
//!      (`hashline::model_identity::ApprovedP1Layer`) as the positive
//!      comparison at the same shape: what a registered root does enforce.
//!  (c) `matrix_*` — the adversarial matrix, one row per case, each row
//!      stating `enforced_today` and asserting the OBSERVED verdict, so any
//!      future change to enforcement fails loudly and must be reviewed.

use hashline::export::sha256_hex;
use hashline::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport, V3Witness};
use hashline::field::{Fp, Fp2};
use hashline::layer::{LayerParams, LayoutV3, StatementV3};
use hashline::model_identity::{ApprovedP1Layer, IdentityError};
use hashline::ntt::NttTables;
use hashline::pcs::{self, Commitment, PcsParams};
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use hashline::zk::{prove_layer_zk_v3, verify_layer_zk_v3, LayerProofZk, ZkConfig, ZkPrivacy, ZkStatementMode};

/// The application's fixed single-layer transcript domain (caller-chosen).
const DOMAIN: &[u8] = b"zk60-fa4-model-identity-review";
/// A second application/request domain, standing for "another request" when
/// the caller binds requests into the domain (it is NOT bound by default).
const OTHER_DOMAIN: &[u8] = b"zk60-fa4-another-request-domain";
/// Declared model identities. Under P3 these are STRINGS the prover chooses.
const MODEL_A: &str = "approved-model-A";
const MODEL_B: &str = "approved-model-B";

fn params() -> LayerParams {
    // Deliberately tiny test parameters, NOT a deployment security claim.
    LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 }
}

fn mode(privacy: ZkPrivacy, model: Option<&str>) -> ZkStatementMode {
    ZkStatementMode { privacy, model_id: model.map(|s| s.to_string()), ..Default::default() }
}

/// Which weight tensors the synthetic layer carries.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Weights {
    /// the "approved" tensors (the baseline diagnostic's fixture stream)
    Approved,
    /// one entry of Wg changed (the baseline diagnostic's substitute)
    SubstituteWg,
    /// one entry of Wd changed (a different tensor of the same layer)
    SubstituteWd,
    /// entirely different Wg/Wu/Wd from a second fixture stream, standing for
    /// the weights of ANOTHER layer of the same shape
    OtherLayer,
}

/// The fixture's export exponents. `rescaled` moves every exponent that the
/// frozen activation-table member does NOT pin (the member pins e_g and e_a16)
/// so that all four signed shifts are unchanged: a DIFFERENT real-valued
/// calibration of the same integer tensors with a byte-identical StatementV3.
fn exps(rescaled: bool) -> V3Exps {
    let k = if rescaled { 1 } else { 0 };
    V3Exps { e_x: k, e_g: -3, e_a16: -11, e_u16: k, e_h16: 3 + k, e_z16: k, e_wg: -10 - k, e_wu: 0, e_wd: -9 }
}

fn lcg(seed: &mut u64, m: i64) -> i8 {
    *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    (((*seed >> 33) as i64) % (2 * m + 1) - m) as i8
}

fn synth(which: Weights, l: usize, rescaled: bool) -> V3Witness {
    let (t, d, f) = (2usize, 16usize, 16usize);
    // The same PUBLIC fixture stream as the baseline diagnostic (seed 1).
    let mut s = 1u64;
    let x: Vec<i8> = (0..t * d).map(|_| lcg(&mut s, 127)).collect();
    let mut wg_t: Vec<i8> = (0..d * f).map(|_| lcg(&mut s, 4)).collect();
    let mut wu_t: Vec<i8> = (0..d * f).map(|_| lcg(&mut s, 4)).collect();
    let mut wd_t: Vec<i8> = (0..f * d).map(|_| lcg(&mut s, 4)).collect();
    match which {
        Weights::Approved => {}
        Weights::SubstituteWg => wg_t[0] += 1,
        Weights::SubstituteWd => wd_t[5] -= 1,
        Weights::OtherLayer => {
            let mut s2 = 2u64;
            for w in wg_t.iter_mut().chain(wu_t.iter_mut()).chain(wd_t.iter_mut()) {
                *w = lcg(&mut s2, 4);
            }
        }
    }
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let export = V3LayerExport {
        l,
        dims: V3Dims { t, d, f, layers: 2 },
        x,
        wg_t,
        wu_t,
        wd_t,
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: exps(rescaled),
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    assert_eq!(export.exps.shifts(), export.shifts, "fixture exponents must reproduce the shifts");
    let witness = derive_v3(&export, t);
    assert!(witness.range_ok, "{which:?}: fixture out of the v3 range bands");
    witness
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    }
}

fn prove(w: &V3Witness, m: &ZkStatementMode, seed: Option<u64>, ntt: &NttTables, domain: &[u8]) -> LayerProofZk {
    let cfg = ZkConfig { enabled: true, seed, mode: m.clone() };
    prove_layer_zk_v3(w, w.t_rows, &params(), ntt, &cfg, &mut Transcript::new(domain)).proof
}

/// The ORDINARY verifier, exactly as an application would call it: it is told
/// the statement and the mode, and it starts a fresh transcript in `domain`.
fn verify(st: &StatementV3, proof: &LayerProofZk, m: &ZkStatementMode, ntt: &NttTables, domain: &[u8]) -> Result<(), String> {
    verify_layer_zk_v3(st, proof, &params(), ntt, &mut Transcript::new(domain), m)
}

/// Field-by-field equality of two statements (StatementV3 derives no PartialEq).
fn same_statement(a: &StatementV3, b: &StatementV3) -> bool {
    a.l == b.l && a.t_rows == b.t_rows && a.d == b.d && a.f == b.f && a.shifts == b.shifts && a.act == b.act && a.table == b.table && a.table_digest == b.table_digest
}

fn root_hex(proof: &LayerProofZk) -> String {
    hashline::silu::hex(&proof.w_com.as_ref().expect("W commitment").root)
}

/// Independent registration from known PUBLIC weights, BEFORE any candidate
/// proof exists (mirrors the baseline diagnostic; reads no proof).
fn public_weight_commitment(w: &V3Witness, p: &LayerParams, ntt: &NttTables) -> Commitment {
    let lay = LayoutV3::new(w.t_rows, w.dims.d, w.dims.f);
    let (db, fb) = (1usize << lay.log_db, 1usize << lay.log_fb);
    let mut data = vec![Fp::ZERO; lay.w_len];
    for c in 0..lay.nb_d {
        for b in 0..lay.nb_f {
            for k in 0..db {
                for j in 0..fb {
                    let source = (c * db + k) * w.dims.f + b * fb + j;
                    let within = k * fb + j;
                    data[lay.wg[c * lay.nb_f + b] + within] = Fp::from_i64(w.wg_t[source] as i64);
                    data[lay.wu[c * lay.nb_f + b] + within] = Fp::from_i64(w.wu_t[source] as i64);
                    data[lay.wd[b * lay.nb_d + c] + j * db + k] = Fp::from_i64(w.wd_t[(b * fb + j) * w.dims.d + c * db + k] as i64);
                }
            }
        }
    }
    let pcs = PcsParams { log_cols: p.log_cols.min(lay.log_wb), inv_rate: p.inv_rate, num_col_checks: p.num_col_checks };
    pcs::commit(&pcs, &data, ntt).commitment()
}

fn registered_p1(w: &V3Witness, ntt: &NttTables) -> (ApprovedP1Layer, Commitment) {
    let root = public_weight_commitment(w, &params(), ntt);
    let policy = ApprovedP1Layer::from_trusted_registration(statement(w), params(), root.clone(), mode(ZkPrivacy::P1, Some(MODEL_A)), DOMAIN).unwrap();
    (policy, root)
}

// ===========================================================================
// (a) GAP PINS — missing constraints, recorded as such.
// ===========================================================================

/// GAP (must FLIP when the P3 consistency repair lands): two DIFFERENT hidden
/// weight tensors both verify under one declared model, one statement and one
/// input, with fixed seeds AND with fresh OS entropy. The proof's W root is
/// re-randomised on every proof, so there is nothing stable in the proof for
/// a verifier to compare against an approved identity. This test reproduces
/// the baseline diagnostic independently (different seeds, different domain).
#[test]
fn gap_p3_substitute_weights_verify_under_the_same_declared_model() {
    let ntt = NttTables::new(12);
    let approved = synth(Weights::Approved, 0, false);
    let substitute = synth(Weights::SubstituteWg, 0, false);
    assert_eq!(approved.x, substitute.x);
    assert_ne!(approved.wg_t, substitute.wg_t);
    let st = statement(&approved);
    let m = mode(ZkPrivacy::P3, Some(MODEL_A));
    let a1 = prove(&approved, &m, Some(601), &ntt, DOMAIN);
    let s1 = prove(&substitute, &m, Some(602), &ntt, DOMAIN);
    let a2 = prove(&approved, &m, None, &ntt, DOMAIN);
    let s2 = prove(&substitute, &m, None, &ntt, DOMAIN);
    for (label, proof) in [("approved/601", &a1), ("substitute/602", &s1), ("approved/os", &a2), ("substitute/os", &s2)] {
        // TODAY: ACCEPT. The repaired approved-P3 boundary must REJECT the two
        // substitute rows; this assertion records the missing constraint.
        verify(&st, proof, &m, &ntt, DOMAIN).unwrap_or_else(|e| panic!("{label}: {e}"));
        println!("FA4 GAP P3: model={MODEL_A} {label} w_root={} proof_sha256={}", root_hex(proof), sha256_hex(&proof.to_bytes()));
    }
    // No stable identity is present in the proof: even the SAME approved
    // weights carry a different root on every proof.
    assert_ne!(a1.w_com.as_ref().unwrap().root, a2.w_com.as_ref().unwrap().root);
    assert_ne!(a1.w_com.as_ref().unwrap().root, s1.w_com.as_ref().unwrap().root);
}

/// GAP (must FLIP): the export exponents are NOT part of StatementV3. Two
/// calibrations that agree on the four signed shifts and the frozen table
/// member but interpret the same integer tensors at different real scales
/// produce a byte-identical statement and, at one seed, byte-identical proofs.
/// Neither the ordinary verifier nor the registered P1 boundary can tell them
/// apart; the approved manifest must pin the exponents (I1 lists this as an
/// obligation), and the verifier must be handed them.
#[test]
fn gap_calibration_exponents_are_absent_from_the_statement_and_the_proof() {
    let ntt = NttTables::new(12);
    let calibrated = synth(Weights::Approved, 0, false);
    let rescaled = synth(Weights::Approved, 0, true);
    assert_ne!(calibrated.exps.e_x, rescaled.exps.e_x, "the two calibrations differ");
    assert_eq!(calibrated.shifts, rescaled.shifts, "...but agree on every signed shift");
    assert!(same_statement(&statement(&calibrated), &statement(&rescaled)), "byte-identical statement");
    let m = mode(ZkPrivacy::P3, Some(MODEL_A));
    let p_cal = prove(&calibrated, &m, Some(701), &ntt, DOMAIN);
    let p_res = prove(&rescaled, &m, Some(701), &ntt, DOMAIN);
    assert_eq!(p_cal.to_bytes(), p_res.to_bytes(), "the proof carries no calibration beyond shifts + table");
    verify(&statement(&calibrated), &p_res, &m, &ntt, DOMAIN).unwrap();
    // The P1 boundary registers the statement only; it accepts the rescaled
    // calibration's proof too (same public weights, same statement bytes).
    let (policy, _) = registered_p1(&calibrated, &ntt);
    let m1 = mode(ZkPrivacy::P1, Some(MODEL_A));
    let p1_res = prove(&rescaled, &m1, Some(702), &ntt, DOMAIN);
    policy.verify(&statement(&rescaled), &params(), &m1, &p1_res, &ntt).unwrap();
}

/// GAP (must FLIP): a layer's proof accepts the weight tensors of ANOTHER
/// layer of the same shape when they are presented under this layer's
/// statement and declared model. The layer index `l` is bound (a proof made
/// at l=1 does not verify at l=0), but under P3 nothing binds WHICH tensors
/// belong at position l.
#[test]
fn gap_p3_layer_swap_other_layer_weights_prove_this_layer() {
    let ntt = NttTables::new(12);
    let this_layer = synth(Weights::Approved, 0, false);
    let other_weights_here = synth(Weights::OtherLayer, 0, false);
    let other_layer = synth(Weights::OtherLayer, 1, false);
    let st0 = statement(&this_layer);
    let m = mode(ZkPrivacy::P3, Some(MODEL_A));
    // TODAY: ACCEPT (must become REJECT at the approved-P3 boundary).
    verify(&st0, &prove(&other_weights_here, &m, Some(801), &ntt, DOMAIN), &m, &ntt, DOMAIN).unwrap();
    // The layer INDEX is bound today: a layer-1 proof under the layer-0 statement rejects.
    assert!(verify(&st0, &prove(&other_layer, &m, Some(802), &ntt, DOMAIN), &m, &ntt, DOMAIN).is_err());
}

// ===========================================================================
// (b) THE P1 POSITIVE COMPARISON — what an independently registered root buys.
// ===========================================================================

/// The registered P1 boundary at this shape: the honest proof passes; an
/// internally valid substitute-weight proof is refused at the ROOT comparison
/// (before any transcript is built); a substitute proof relabelled with the
/// approved root reaches the ordinary verifier and is rejected there (the
/// root is absorbed into the transcript, so the proof is bound to its own
/// root); a tampered claim rejects; and every changed statement field rejects.
#[test]
fn p1_registered_boundary_rejects_substitute_copied_root_and_changed_statement() {
    let ntt = NttTables::new(12);
    let w = synth(Weights::Approved, 0, false);
    let (policy, approved_root) = registered_p1(&w, &ntt);
    let st = statement(&w);
    let m = mode(ZkPrivacy::P1, Some(MODEL_A));
    let honest = prove(&w, &m, Some(901), &ntt, DOMAIN);
    policy.verify(&st, &params(), &m, &honest, &ntt).unwrap();
    assert_eq!(honest.w_com.as_ref().unwrap().root, approved_root.root, "P1: the proof's root IS the registered public root");

    for which in [Weights::SubstituteWg, Weights::SubstituteWd, Weights::OtherLayer] {
        let mut substitute = prove(&synth(which, 0, false), &m, Some(902), &ntt, DOMAIN);
        verify(&st, &substitute, &m, &ntt, DOMAIN).unwrap_or_else(|e| panic!("{which:?}: the ordinary verifier accepts an internally consistent substitute: {e}"));
        assert_eq!(policy.verify(&st, &params(), &m, &substitute, &ntt), Err(IdentityError::WeightCommitmentMismatch), "{which:?}");
        substitute.w_com = Some(approved_root.clone());
        assert!(matches!(policy.verify(&st, &params(), &m, &substitute, &ntt), Err(IdentityError::ProofRejected(_))), "{which:?}: copied root");
        assert!(verify(&st, &substitute, &m, &ntt, DOMAIN).is_err(), "{which:?}: the ordinary verifier also rejects the relabelled proof");
    }

    let mut tampered = honest.clone();
    tampered.gu_claim = tampered.gu_claim.add(Fp2::ONE);
    assert!(matches!(policy.verify(&st, &params(), &m, &tampered, &ntt), Err(IdentityError::ProofRejected(_))));

    let changed: Vec<(&str, StatementV3)> = vec![
        ("layer", StatementV3 { l: st.l + 1, ..st.clone() }),
        ("t_rows", StatementV3 { t_rows: st.t_rows * 2, ..st.clone() }),
        ("shifts", StatementV3 { shifts: (8, 0, 14, 6), ..st.clone() }),
        ("activation family", StatementV3 { act: Act16Fn::GeluTanh, ..st.clone() }),
        ("table digest", StatementV3 { table_digest: format!("{}0", st.table_digest), ..st.clone() }),
        ("table bytes", { let mut c = st.clone(); c.table[0] += 1; c }),
    ];
    for (field, claimed) in changed {
        assert_eq!(policy.verify(&claimed, &params(), &m, &honest, &ntt), Err(IdentityError::StatementMismatch(field)));
    }
    for declared in [None, Some(MODEL_B)] {
        assert_eq!(policy.verify(&st, &params(), &mode(ZkPrivacy::P1, declared), &honest, &ntt), Err(IdentityError::ModeMismatch));
    }
    // There is NO approved-P3 boundary today: registration refuses P3 outright.
    assert!(matches!(
        ApprovedP1Layer::from_trusted_registration(st.clone(), params(), approved_root, mode(ZkPrivacy::P3, Some(MODEL_A)), DOMAIN),
        Err(IdentityError::UnsupportedPolicy(_))
    ));
}

// ===========================================================================
// (c) THE ADVERSARIAL MATRIX.
// ===========================================================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Verdict {
    Accept,
    Reject,
}

/// Where the obligation of a row lives.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Obligation {
    /// a verifier verdict: the row is enforced when today's verdict already
    /// equals the verdict the reviewed construction requires
    Verifier,
    /// a prover-side privacy obligation that NO verifier verdict can enforce
    /// (fresh randomness); `enforced_today` is false by definition and the
    /// verifier verdict is the same before and after the repair
    Prover,
}

/// One adversarial case. `today` is the verdict this baseline gives and is
/// ASSERTED; `required` is the verdict the reviewed approved-P3 construction
/// must give (ZK60_FABLE_MODEL_IDENTITY.md, adversarial matrix). For
/// `Obligation::Verifier` rows `enforced_today == (today == required)`; a
/// row with `enforced_today: false` documents a missing constraint. Changing
/// any `today` value is a protocol change and must be reviewed, which is why
/// the assertion is loud.
struct Row {
    id: &'static str,
    case: &'static str,
    obligation: Obligation,
    today: Verdict,
    required: Verdict,
    enforced_today: bool,
    observed: Verdict,
    note: &'static str,
}

fn verdict(r: Result<(), String>) -> Verdict {
    if r.is_ok() { Verdict::Accept } else { Verdict::Reject }
}

#[test]
fn matrix_adversarial_cases_state_enforced_today_and_assert_the_observed_verdict() {
    let ntt = NttTables::new(12);
    let approved = synth(Weights::Approved, 0, false);
    let st = statement(&approved);
    let p3a = mode(ZkPrivacy::P3, Some(MODEL_A));
    let p3b = mode(ZkPrivacy::P3, Some(MODEL_B));
    let p3_none = mode(ZkPrivacy::P3, None);
    let p1a = mode(ZkPrivacy::P1, Some(MODEL_A));

    // Proofs used by several rows (fixed PUBLIC seeds: reproducible, not private).
    let honest = prove(&approved, &p3a, Some(1001), &ntt, DOMAIN);
    let honest_again_same_seed = prove(&approved, &p3a, Some(1001), &ntt, DOMAIN);
    let honest_fresh = prove(&approved, &p3a, Some(1002), &ntt, DOMAIN);
    let sub_wg = prove(&synth(Weights::SubstituteWg, 0, false), &p3a, Some(1003), &ntt, DOMAIN);
    let sub_wd = prove(&synth(Weights::SubstituteWd, 0, false), &p3a, Some(1004), &ntt, DOMAIN);
    let sub_wg_same_seed_as_honest = prove(&synth(Weights::SubstituteWg, 0, false), &p3a, Some(1001), &ntt, DOMAIN);
    let other_layer_weights = prove(&synth(Weights::OtherLayer, 0, false), &p3a, Some(1005), &ntt, DOMAIN);
    let layer_one = prove(&synth(Weights::OtherLayer, 1, false), &p3a, Some(1006), &ntt, DOMAIN);
    let rescaled = prove(&synth(Weights::Approved, 0, true), &p3a, Some(1007), &ntt, DOMAIN);
    let p1_honest = prove(&approved, &p1a, Some(1008), &ntt, DOMAIN);
    let (p1_policy, _) = registered_p1(&approved, &ntt);
    let p1_sub = prove(&synth(Weights::SubstituteWg, 0, false), &p1a, Some(1009), &ntt, DOMAIN);

    let mut copied_root = sub_wg.clone();
    copied_root.w_com = honest.w_com.clone();
    let mut changed_table_digest = st.clone();
    changed_table_digest.table_digest.push('0');
    let mut changed_shifts = st.clone();
    changed_shifts.shifts = (8, 0, 14, 6);

    let mut rows = vec![
        Row {
            id: "M1",
            case: "substitute W (Wg entry changed), same statement, same declared model, P3",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: verdict(verify(&st, &sub_wg, &p3a, &ntt, DOMAIN)),
            note: "the declared model is a string; the fresh W root is compared to nothing",
        },
        Row {
            id: "M2",
            case: "substitute W (Wd entry changed), same statement, same declared model, P3",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: verdict(verify(&st, &sub_wd, &p3a, &ntt, DOMAIN)),
            note: "every tensor of the layer is unbound, not only Wg",
        },
        Row {
            id: "M3",
            case: "copied candidate root: substitute proof relabelled with the honest proof's W root",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &copied_root, &p3a, &ntt, DOMAIN)),
            note: "BINDING, not identity: the root is absorbed into the transcript, so a proof is bound to its own root; the honest root is itself fresh and approves nothing",
        },
        Row {
            id: "M4",
            case: "changed calibration table: verify under a statement with another table digest",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&changed_table_digest, &honest, &p3a, &ntt, DOMAIN)),
            note: "table digest is absorbed (layer.rs absorb_statement_v3)",
        },
        Row {
            id: "M5",
            case: "changed quantization shifts: verify under a statement with sh_g 7 -> 8",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&changed_shifts, &honest, &p3a, &ntt, DOMAIN)),
            note: "signed shifts are absorbed",
        },
        Row {
            id: "M6",
            case: "changed calibration EXPONENTS with identical shifts and table (rescaled export)",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: verdict(verify(&st, &rescaled, &p3a, &ntt, DOMAIN)),
            note: "exponents are not in StatementV3 and not in the proof; the approved manifest must pin them and the verifier must be handed them",
        },
        Row {
            id: "M7",
            case: "wrong approved identity: proof declared model A, verified as model B",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &honest, &p3b, &ntt, DOMAIN)),
            note: "the header binds the DECLARATION (mode header in the transcript), not its truth",
        },
        Row {
            id: "M8",
            case: "wrong approved identity: proof declared model A, verified with no declared model",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &honest, &p3_none, &ntt, DOMAIN)),
            note: "same binding; `model=w-root` is a different header",
        },
        Row {
            id: "M9",
            case: "false declaration by the prover: substitute weights DECLARED as model A",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: verdict(verify(&st, &sub_wg, &p3a, &ntt, DOMAIN)),
            note: "identical to M1 seen from the prover's side: the declaration is free",
        },
        Row {
            id: "M10",
            case: "tier swap: a P3 proof verified as P1 (public weights claimed)",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &honest, &p1a, &ntt, DOMAIN)),
            note: "privacy tier is in the header; W row counts also differ",
        },
        Row {
            id: "M11",
            case: "layer swap (tensors): another layer's weights presented under this layer's statement",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: verdict(verify(&st, &other_layer_weights, &p3a, &ntt, DOMAIN)),
            note: "nothing binds WHICH hidden tensors belong at position l",
        },
        Row {
            id: "M12",
            case: "layer swap (index): a proof made at l=1 verified under the l=0 statement",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &layer_one, &p3a, &ntt, DOMAIN)),
            note: "the layer index is absorbed",
        },
        Row {
            id: "M13",
            case: "replay: one P3 proof presented twice for two different requests (same domain)",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Reject,
            enforced_today: false,
            observed: {
                verify(&st, &honest, &p3a, &ntt, DOMAIN).unwrap();
                verdict(verify(&st, &honest, &p3a, &ntt, DOMAIN))
            },
            note: "the verifier receives no request identity; a request nonce / I-O commitment must enter the transcript (caller obligation today)",
        },
        Row {
            id: "M14",
            case: "replay under another transcript domain (caller-bound request context)",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(verify(&st, &honest, &p3a, &ntt, OTHER_DOMAIN)),
            note: "enforced ONLY when the caller binds the request into the domain",
        },
        Row {
            id: "M15",
            case: "reused randomness: the same seed twice on the same witness",
            obligation: Obligation::Prover,
            today: Verdict::Accept,
            required: Verdict::Accept,
            enforced_today: false,
            observed: {
                assert_eq!(honest.to_bytes(), honest_again_same_seed.to_bytes(), "deterministic fixture: identical bytes");
                verdict(verify(&st, &honest_again_same_seed, &p3a, &ntt, DOMAIN))
            },
            note: "no verifier can detect reuse from one proof; a privacy failure, not a soundness one; prover-side obligation (OS entropy, `Some(seed)` only in tests)",
        },
        Row {
            id: "M16",
            case: "reused randomness across DIFFERENT witnesses: same seed, substitute weights",
            obligation: Obligation::Prover,
            today: Verdict::Accept,
            required: Verdict::Accept,
            enforced_today: false,
            observed: {
                // The randomness stream depends on the layout only, not on the
                // values: the CFS mask commitment is IDENTICAL across the two
                // witnesses, and so are the W pads and salts -- opened columns of
                // the two proofs then differ exactly by the encoding of the weight
                // difference. Visible to anyone holding both proofs.
                assert_eq!(honest.mask_root, sub_wg_same_seed_as_honest.mask_root, "identical mask commitment under a reused seed");
                assert_ne!(honest.mask_root, honest_fresh.mask_root, "a fresh seed moves it");
                verdict(verify(&st, &sub_wg_same_seed_as_honest, &p3a, &ntt, DOMAIN))
            },
            note: "reuse is invisible to the single-proof verifier and leaks across proofs",
        },
        Row {
            id: "M17",
            case: "P1 positive comparison: substitute weights at the registered P1 boundary",
            obligation: Obligation::Verifier,
            today: Verdict::Reject,
            required: Verdict::Reject,
            enforced_today: true,
            observed: verdict(p1_policy.verify(&st, &params(), &p1a, &p1_sub, &ntt).map_err(|e| e.to_string())),
            note: "the registered PUBLIC root is compared before any transcript exists",
        },
        Row {
            id: "M18",
            case: "P1 positive comparison: the honest registered proof",
            obligation: Obligation::Verifier,
            today: Verdict::Accept,
            required: Verdict::Accept,
            enforced_today: true,
            observed: verdict(p1_policy.verify(&st, &params(), &p1a, &p1_honest, &ntt).map_err(|e| e.to_string())),
            note: "the baseline the P3 boundary must reach with a HIDING stable root",
        },
    ];

    println!("FA4 adversarial matrix (tiny shape; `today` asserted, `required` = the reviewed construction):");
    println!("| id | obligation | enforced_today | today | required | case |");
    for r in rows.iter_mut() {
        println!("| {} | {:?} | {} | {:?} | {:?} | {} -- {} |", r.id, r.obligation, r.enforced_today, r.today, r.required, r.case, r.note);
        match r.obligation {
            Obligation::Verifier => assert_eq!(r.enforced_today, r.today == r.required, "{}: enforced_today must equal (today == required)", r.id),
            Obligation::Prover => assert!(!r.enforced_today && r.today == r.required, "{}: a prover-side obligation is never verifier-enforced", r.id),
        }
        assert_eq!(
            r.observed, r.today,
            "{}: the observed verdict changed ({:?} -> {:?}). This is a protocol change: review it against ZK60_FABLE_MODEL_IDENTITY.md and update `today`/`enforced_today` deliberately. Case: {}",
            r.id, r.today, r.observed, r.case
        );
    }
    let missing: Vec<&str> = rows.iter().filter(|r| !r.enforced_today).map(|r| r.id).collect();
    // The set of rows that record a MISSING constraint at this baseline. When
    // the P3 repair lands this list must SHRINK (and the rows above flip);
    // it must never grow silently.
    assert_eq!(missing, vec!["M1", "M2", "M6", "M9", "M11", "M13", "M15", "M16"]);
}
