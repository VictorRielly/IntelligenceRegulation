//! **W16 (D54) acceptance at the development rung, and the trained shapes'
//! counts.** Design: `results/zk60_limb16_20261031/DESIGN.md`.
use super::accuracy_layout::Limbs as L;
use super::layout::*;
use super::shape::{self, NormCalibration, Shape};
use super::witness::{self, Witness};
use super::*;
use crate::private_block::accuracy_groups::Group;
use crate::private_block::accuracy_public::{AccuracyPublic, Geometry, Multipliers};
use crate::private_block::accuracy_tables::silu_table;

/// `accuracy_profile_tests::calibration`, verbatim
fn calibration(width: usize) -> NormCalibration {
    NormCalibration { tn: if width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 }
}

fn built(profile: &str) -> Shape {
    let spec = shape::accuracy_spec(profile).expect("a registered accuracy profile");
    let fe = if spec.tokens == 32 { 12 } else { 9 };
    Shape::accuracy_trained(profile, &calibration(spec.width), fe, 20).expect("the shape builds")
}

/// `slot_ir_accuracy::tests::case` in substance: synthetic public data at the
/// shape's true geometry, with `ng` activation groups
fn case(mut sh: Shape, ng: usize) -> (Shape, AccuracyPublic, AttentionPublic, FeedForwardPublic) {
    let geometry = Geometry { width: sh.width, query_width: sh.q_width(), kv_width: sh.kv_heads * sh.head_dim, hidden: sh.hidden };
    let sequence = |n, max| (0..n).map(|i| 1 + (i % max) as u16).collect();
    let m = Multipliers {
        q: sequence(geometry.query_width, 32),
        k: sequence(geometry.kv_width, 32),
        v: sequence(geometry.kv_width, 64),
        o: sequence(geometry.width, 256),
        g: sequence(geometry.hidden, 64),
        u: sequence(geometry.hidden, 16),
        d: sequence(geometry.width, 64),
    };
    let groups = vec![Group { e_in: -4, e_out: -13 }, Group { e_in: -3, e_out: -12 }, Group { e_in: -2, e_out: -11 }, Group { e_in: -1, e_out: -9 }][..ng].to_vec();
    let tables = groups.iter().map(|g| silu_table(g.e_in, g.e_out, 12).unwrap()).collect();
    let data = AccuracyPublic::new_with_registry(sh.accuracy_registry(), sh.accuracy_stack(), geometry, sh.accuracy_base(), (-3, -11), m, groups, (0..geometry.hidden).map(|i| i % ng).collect(), tables).unwrap();
    sh = sh.with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
    let (public, ff, _) = crate::private_block::grow_tests::tame_case(&sh);
    (sh, data, public, ff)
}

/// the M4 byte-identity gate's own recipe at a development shape: its norm
/// calibration and its deterministic input
fn rung_case(profile: &str) -> (Shape, BlockPublic, Witness) {
    let original = built(profile);
    let cal = NormCalibration { cn_a: 4000, cn_m: 4000, ..original.norm_calibration() };
    let original = Shape::accuracy_trained(original.profile, &cal, original.f_e, 20).unwrap();
    let (sh, data, public, ff) = case(original, 3);
    let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11) % 201) as i16 - 100).collect();
    let w = witness::build_accuracy(&sh, &public, &ff, &data, &input).expect("an admissible W16 rung witness");
    let blk = BlockPublic::new(public, ff).with_accuracy(data);
    (sh, blk, w)
}

/// `(A words, H words, lookup words)` of a shape's layout
fn words(sh: &Shape) -> (usize, usize, usize) {
    let lay = Layout::for_shape(sh).unwrap();
    let lookups: usize = sh.lookup_doms().iter().map(|d| lay.lookups(*d).len() * sh.size(*d)).sum();
    (lay.a_rows * lay.n(), lay.h_rows * lay.n(), lookups)
}

#[test]
fn w16_layouts_build_and_cut_the_committed_words_against_r13() {
    for (w16, r13) in [(shape::W16_RUNG_H24, shape::R13_RUNG_H24), (shape::W16_SHIELD_T128_H24, shape::R13_SHIELD_T128_H24), (shape::W16_8B_T128_H24, shape::R13_8B_T128_H24)] {
        let (a, b) = (built(w16), built(r13));
        a.check_constructed().unwrap();
        assert!(a.range16() && !b.range16());
        let lay = Layout::for_shape(&a).expect("the W16 layout (Ids/HIds agree with the shape's lists)");
        // every lookup's width is a family; the families fill whole rows
        let fams = a.range_families();
        for d in a.lookup_doms() {
            for l in lay.lookups(d) {
                if let LkTag::Range(w) = l.tag {
                    assert!(fams.iter().any(|f| f.width == w), "{}: width {w} has no family", a.name);
                }
            }
        }
        let ((wa, wh, wl), (ra, rh, rl)) = (words(&a), words(&b));
        eprintln!(
            "W16 {}: A {wa} (R13 {ra}, {:.3}) H {wh} (R13 {rh}, {:.3}) lookups {wl} (R13 {rl}, {:.3}); families {:?}",
            a.name,
            wa as f64 / ra as f64,
            wh as f64 / rh as f64,
            wl as f64 / rl as f64,
            fams.iter().map(|f| (f.width, f.sub)).collect::<Vec<_>>()
        );
        if a.tokens == 128 {
            // the design note's counted reductions, with the int8 score's two
            // byte queries kept (one more `Dom::S` query than the note's six)
            assert!(wa * 100 < ra * 58 && wh * 100 < rh * 60 && wl * 100 < rl * 52, "{}: the W16 counts are not the designed cut", a.name);
        }
    }
}

/// **THE W16 IR ORACLE** (the R13 one is `slot_ir::accuracy::tests`): at the
/// W16 rung, for one to four activation groups, every slot whose IR builds
/// must have the closure's table count, equal it at random points of the
/// whole space, stay inside the declared degree and draw what `define` drew;
/// and the four transcribed W16 zero-checks must build.
#[test]
fn the_w16_ir_evaluates_to_the_w16_closure_at_every_slot() {
    use super::argument::{define, Ctx, Points};
    use super::slot_ir::{build_slot_ir, IrPoints};
    use crate::field::{Fp, Fp2};
    use crate::transcript::Transcript;
    let k = |v: i64| Fp2::from_i64(v);
    let mut z = 0x9E37_79B9_7F4A_7C15u64;
    let mut next = move || {
        z ^= z << 13;
        z ^= z >> 7;
        z ^= z << 17;
        Fp::new(z)
    };
    let mut transcribed = 0usize;
    for ng in 1..=4 {
        let (sh, data, public, ff) = case(built(shape::W16_RUNG_H24), ng);
        let lay = Layout::for_shape(&sh).unwrap();
        let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
        let (mut pts, mut ipts) = (Points::default(), IrPoints::default());
        let mut tr = Transcript::new(sh.profile.as_bytes());
        for slot in 0..sh.n_slots() {
            let mut twin = Transcript::clone_state(&tr);
            let ir = build_slot_ir(slot, &ctx, &mut ipts, &mut twin);
            let def = define(slot, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("W16 ng{ng} slot{slot}: {e}"));
            let w16 = [SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC].contains(&slot);
            match ir {
                Ok(ir) => {
                    let at = format!("W16 ng{ng} slot{slot}");
                    assert_eq!(ir.tables.len(), def.tabs.len(), "{at}: table count");
                    for _ in 0..12 {
                        let v: Vec<Fp2> = (0..ir.tables.len()).map(|_| Fp2::new(next(), next())).collect();
                        assert_eq!(ir.eval(&v), (def.poly)(&v), "{at}: the IR differs from the closure");
                    }
                    assert!(ir.max_term_degree() <= sh.slots()[slot].2, "{at}: the IR exceeds the declared degree");
                    if w16 {
                        assert_eq!(twin.state(), tr.state(), "{at}: the IR drew other challenges than define");
                        transcribed += 1;
                    }
                }
                Err(e) => assert!(!w16, "W16 ng{ng} slot{slot}: a transcribed zero-check has no IR ({e})"),
            }
        }
    }
    assert_eq!(transcribed, 4 * 5, "the five W16 zero-check slots at every group count");
}

#[test]
fn the_w16_signed_top_limb_keeps_a_padded_position_inside_both_tables() {
    // at a padded position the pad rule holds the word and its top at zero
    let [low, top] = super::range16::word24(0, 1, 1 << 23);
    assert_eq!((low.cst, top.cst), (0, 128));
    for h in [-(1i64 << 23), -1, 0, 1, (1 << 23) - 1] {
        let t = super::range16::word24_top(h, 1 << 23);
        let lo = h - (t << 16);
        assert!((0..1 << 16).contains(&lo) && (0..256).contains(&(t + 128)), "h {h}: lo {lo}, t {t}");
    }
}

/// Prove the block's CORE (the A / M / H commitments, every slot, the A and H
/// openings) and verify it with the core verifier on a fresh transcript of
/// the same header. A trained-calibration profile refuses a single-block
/// receipt (R2-4); its run binds the endpoints, which W16 does not change.
/// `Err("prover: ..")` is a prover refusal, any other `Err` the verifier's.
/// `tamper` edits the proof before it is verified.
fn prove_and_verify_core(sh: &Shape, blk: &BlockPublic, w: Witness, tamper: impl FnOnce(&mut super::protocol::CoreProof)) -> Result<f64, String> {
    use crate::field::Fp;
    use crate::transcript::Transcript;
    let lay = Layout::for_shape(sh)?;
    let ids = Ids::new(sh)?;
    let (rows, n) = (sh.endpoint_rows, 1usize << sh.endpoint_log_n);
    let io = |p: usize| -> Vec<Fp> {
        let mut d = vec![Fp::ZERO; rows * n];
        for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
            d[i] = Fp::from_i64(*v);
        }
        d
    };
    let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
    let ntt = crate::ntt::NttTables::new(super::protocol::ntt_log_at(sh));
    let header = |tr: &mut Transcript| {
        tr.absorb(b"profile", sh.profile.as_bytes());
        tr.absorb(b"schedule", &lay.schedule_digest());
    };
    let mut rng = crate::zk::ZkRng::new(20261101, b"zk60 W16 core");
    let mut tr = Transcript::new(b"zk60 W16 core");
    header(&mut tr);
    let mut ph = super::timing::Phases::start();
    let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
    let t0 = std::time::Instant::now();
    let mut core = super::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).map_err(|e| format!("prover: {e}"))?;
    let prove_s = t0.elapsed().as_secs_f64();
    tamper(&mut core);
    let mut vt = Transcript::new(b"zk60 W16 core");
    header(&mut vt);
    let view = super::protocol::CoreView { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: &core.slots, mask_open: &core.mask_open, a_open: &core.a_open, h_open: &core.h_open };
    let mut vph = super::timing::Phases::start();
    super::protocol::verify_core(sh, &lay, blk, view, &ntt, &mut vt, &mut vph)?;
    Ok(prove_s)
}

#[test]
fn a_w16_rung_block_core_proves_and_verifies_and_a_changed_root_is_refused() {
    let (sh, blk, w) = rung_case(shape::W16_RUNG_H24);
    let keep = Witness { planes: w.planes.clone(), output_plane: w.output_plane };
    let prove_s = prove_and_verify_core(&sh, &blk, w, |_| {}).expect("the honest W16 rung core proves and verifies");
    let changed = prove_and_verify_core(&sh, &blk, keep, |c| c.h_root[7] ^= 1);
    assert!(changed.is_err() && !changed.as_ref().unwrap_err().starts_with("prover:"), "a changed H root was accepted: {changed:?}");
    let (r13, rblk, rw) = rung_case(shape::R13_RUNG_H24);
    let r13_s = prove_and_verify_core(&r13, &rblk, rw, |_| {}).expect("the R13 rung core at the same recipe");
    eprintln!("W16 rung block core: prove {prove_s:.2} s (R13 rung {r13_s:.2} s, CPU, shared Mac)");
}

/// **The range lookups are what refuse each of these.** Every mutation keeps
/// each relation true (a remainder's value, the product word's value) and
/// moves one limb out of its table; the CHEATING prover skips the miss
/// refusal, so the mutation reaches the verifier, which must reject.
#[test]
fn w16_limbs_out_of_their_range_are_rejected_by_the_verifier() {
    // a two-limb remainder: low += 2^16, top -= 1 at a true position. Its
    // value is unchanged; the low limb leaves [0, 2^16) where the top was
    // live, and the top leaves its own window (it becomes -1) where it was 0
    for role in [L::Nr, L::Ms, L::Rao, L::Rd, L::Rs, L::Rg] {
        let (sh, blk, mut w) = rung_case(shape::W16_RUNG_H24);
        let ids = Ids::new(&sh).unwrap();
        let low = ids.accuracy().unwrap();
        assert_eq!(low.count(role), 2, "{role:?} is a two-limb remainder at this rung");
        let (lo, hi) = (low.limb(role, 0), low.limb(role, 1));
        w.planes[lo][0] += 1 << 16;
        w.planes[hi][0] -= 1;
        let _cheat = super::protocol::CheatingProver::on();
        match prove_and_verify_core(&sh, &blk, w, |_| {}) {
            Ok(_) => panic!("{role:?}: a limb outside its table was accepted"),
            Err(e) => assert!(!e.starts_with("prover:"), "{role:?}: the cheating prover refused ({e}); the mutation must reach the verifier"),
        }
    }
    // the product word's signed top limb moved by one: its low expression
    // `h - 2^16 t` leaves [0, 2^16)
    let (sh, blk, mut w) = rung_case(shape::W16_RUNG_H24);
    let ids = Ids::new(&sh).unwrap();
    let top = ids.accuracy().unwrap().limb(L::H, 0);
    w.planes[top][0] += 1;
    let _cheat = super::protocol::CheatingProver::on();
    match prove_and_verify_core(&sh, &blk, w, |_| {}) {
        Ok(_) => panic!("a moved product top limb was accepted"),
        Err(e) => assert!(!e.starts_with("prover:"), "the cheating prover refused the moved top limb ({e})"),
    }
}
