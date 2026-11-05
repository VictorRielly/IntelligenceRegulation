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

pub(super) fn built(profile: &str) -> Shape {
    let spec = shape::accuracy_spec(profile).expect("a registered accuracy profile");
    let fe = if spec.tokens == 32 { 12 } else { 9 };
    Shape::accuracy_trained(profile, &calibration(spec.width), fe, 20).expect("the shape builds")
}

/// `slot_ir_accuracy::tests::case` in substance: synthetic public data at the
/// shape's true geometry, with `ng` activation groups
pub(super) fn case(mut sh: Shape, ng: usize) -> (Shape, AccuracyPublic, AttentionPublic, FeedForwardPublic) {
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
pub(super) fn rung_case(profile: &str) -> (Shape, BlockPublic, Witness) {
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
            let w16 = [SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC, SC_TAB].contains(&slot);
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
    assert_eq!(transcribed, 4 * 6, "the five W16 zero-checks and the table slot at every group count");
}

/// **Efficiency plan A6 census (2026-11-05): what the device evaluates per point, by slot.**
/// For each device slot of a shape: the DECLARED degree D (the round message's length),
/// the degree the IR attains (a slot whose IR stays below D has a round polynomial of
/// lower degree, so its top point follows from the others: no evaluation needed), the
/// tables, the term degrees, and the field multiplies of one point of the later-round
/// kernel as generated (`gl_mul` 1, `f2_mulb` 2, `f2_mul` 3 base products). A census,
/// not a check: it asserts only that the IR builds and stays within D.
#[cfg(feature = "gpu-metal")]
#[test]
#[ignore = "census (efficiency plan A6): the device slots' degrees and multiplies per point"]
fn effplan_a6_census_of_the_device_slots() {
    use super::argument::{define, Ctx, Points};
    use super::slot_ir::{build_slot_ir, IrPoints};
    use crate::field::Fp2;
    use crate::transcript::Transcript;
    let k = |v: i64| Fp2::from_i64(v);
    for (profile, ng) in [(shape::W16R2_8B_T128_H24, 3usize), (shape::W16R2_RUNG_H24, 3)] {
        let (sh, data, public, ff) = case(built(profile), ng);
        let lay = Layout::for_shape(&sh).unwrap();
        let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
        let (mut pts, mut ipts) = (Points::default(), IrPoints::default());
        let mut tr = Transcript::new(sh.profile.as_bytes());
        for slot in 0..sh.n_slots() {
            let mut twin = Transcript::clone_state(&tr);
            let ir = build_slot_ir(slot, &ctx, &mut ipts, &mut twin);
            let _def = define(slot, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{profile} slot {slot}: {e}"));
            let Ok(ir) = ir else {
                eprintln!("A6-CENSUS {profile} slot {slot:02}: no IR (the CPU evaluates it)");
                continue;
            };
            let declared = sh.slots()[slot].2;
            let attained = ir.max_term_degree();
            assert!(attained <= declared, "{profile} slot {slot}: the IR exceeds the declared degree");
            let degs = ir.recompute_degrees();
            let mut hist = vec![0usize; declared + 1];
            for t in &ir.terms {
                let d = t.wrapper.len() + t.inner.iter().map(|f| match f { super::slot_ir::Factor::Table(_) => 1, super::slot_ir::Factor::Node(n) => degs[*n as usize] }).sum::<usize>();
                hist[d.min(declared)] += 1;
            }
            let (_k0, k1, _cf, base) = super::metal_slot::msl_round_kernels(&ir);
            let count = |s: &str, pat: &str| s.matches(pat).count();
            let (f2m, f2b, glm) = (count(&k1, "f2_mul("), count(&k1, "f2_mulb("), count(&k1, "gl_mul("));
            let muls = 3 * f2m + 2 * f2b + glm;
            eprintln!(
                "A6-CENSUS {profile} slot {slot:02} [{}]: 2^{} x {} tables ({} base in round 0), declared degree {declared}, attained {attained}{}; {} nodes ({} affine), {} terms by degree {:?}; one later-round point: {f2m} f2_mul + {f2b} f2_mulb + {glm} gl_mul = {muls} base products",
                ir.name,
                ir.main_rounds,
                ir.tables.len(),
                base.iter().filter(|b| **b).count(),
                if attained < declared { " (TOP POINT FOLLOWS FROM THE OTHERS)" } else { "" },
                ir.nodes.len(),
                ir.affine_forms(),
                ir.terms.len(),
                hist
            );
        }
    }
}

/// **Efficiency plan B4/B5 census (2026-11-05): what one block commits, by domain.** For each
/// shape it prints the committed A planes and H planes per domain, with their rows, and the
/// lookups per position. H holds the LogUp helpers (two words per helper: re, im), which
/// B5 (LogUp-GKR) would remove. A's limb and remainder planes are what B4 (probabilistic range
/// checks) would thin. A census, not a check: it asserts only that the per-domain rows add up
/// to the layout's own totals.
#[test]
#[ignore = "census (efficiency plan B4/B5): prints the committed rows of a block by domain"]
fn effplan_census_of_the_committed_rows_by_domain() {
    use std::collections::BTreeMap;
    for profile in [shape::W16R2_8B_T128_H24, shape::R13_8B_T128_H24, shape::W16R2_RUNG_H24] {
        let sh = built(profile);
        let lay = Layout::for_shape(&sh).unwrap();
        let count = |doms: &[layout::Dom]| -> BTreeMap<String, (usize, usize)> {
            let mut m: BTreeMap<String, (usize, usize)> = BTreeMap::new();
            for d in doms {
                let e = m.entry(format!("{d:?}")).or_insert((0, 0));
                e.0 += 1;
                e.1 += sh.rows_of(*d);
            }
            m
        };
        let (a, h) = (count(&sh.a_plane_doms()), count(&sh.h_plane_doms()));
        let rows = |m: &BTreeMap<String, (usize, usize)>| m.values().map(|v| v.1).sum::<usize>();
        eprintln!("CENSUS {} (n = 2^{}): A rows {} (data {}), H rows {} (data {})", sh.name, sh.log_cols, lay.a_rows, lay.a_data_rows, lay.h_rows, lay.h_data_rows);
        for (side, m) in [("A", &a), ("H", &h)] {
            for (dom, (planes, r)) in m {
                eprintln!("CENSUS {}   {side} {dom:<4} planes {planes:>4}  rows {r:>6}", sh.name);
            }
            eprintln!("CENSUS {}   {side} data rows by domain: {}", sh.name, rows(m));
        }
        let lk: Vec<String> = [layout::Dom::L, layout::Dom::D, layout::Dom::Q, layout::Dom::Kv, layout::Dom::F, layout::Dom::S, layout::Dom::Dd]
            .iter()
            .map(|d| format!("{d:?}={}", sh.lookups_per_position(*d)))
            .collect();
        eprintln!("CENSUS {}   lookups per position: {}", sh.name, lk.join(" "));
    }
}

/// **D63 L3 finding F1: the extension premise, checked statically.** The masked
/// sumcheck's extension round `m` publishes `s_m(1) = poly(ext)`. There, every
/// private table of round `m` holds its mask value and every other table is zero:
/// the public ones, and the other family's private ones in the bilinear slots
/// (`zk::extension`, `sumcheck::extension_round`). Soundness needs `poly(ext) = 0`
/// identically (`formal/ZK60Formal/SoundSumcheck.lean`, `extension_halves`). A
/// monomial with no public factor would let a cheating prover pick mask rows that
/// make a false claim true.
///
/// The prover already refuses a nonzero `poly(ext)` at run time (333c4ba5). This test
/// checks the premise without a proof, for every slot at five shapes: the W16 rung at
/// one and four groups, the W16R2 rung, the R13 rung DD and the 8B W16R2 block. For each
/// slot and each extension round, the polynomial is evaluated at six random points with
/// that round's private tables random and every other table zero.
#[test]
fn f1_every_slot_polynomial_vanishes_at_each_extension_round() {
    use super::argument::{define, Ctx, Points, Tab};
    use crate::field::{Fp, Fp2};
    use crate::transcript::Transcript;
    let k = |v: i64| Fp2::from_i64(v);
    let mut z = 0xF1F1_0000_9E37_79B9u64;
    let mut next = move || {
        z ^= z << 13;
        z ^= z >> 7;
        z ^= z << 17;
        Fp::new(z)
    };
    let (mut rounds_checked, mut slots_checked) = (0usize, 0usize);
    let mut skipped: Vec<String> = Vec::new();
    for (profile, ng) in [(shape::W16_RUNG_H24, 1usize), (shape::W16_RUNG_H24, 4), (shape::W16R2_RUNG_H24, 3), (shape::R13_RUNG_H24, 3), (shape::R13_RUNG_H24_DD, 3), (shape::W16R2_8B_T128_H24, 3)] {
        let (sh, data, public, ff) = case(built(profile), ng);
        let lay = Layout::for_shape(&sh).unwrap();
        let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
        let mut pts = Points::default();
        let mut tr = Transcript::new(sh.profile.as_bytes());
        for slot in 0..sh.n_slots() {
            let def = match define(slot, &ctx, &mut pts, &mut tr) {
                Ok(d) => d,
                // the synthetic fixture's exp table overflows the DD dictionary's cap at the
                // rung; the slot is refused by name, so its premise is not checked here
                Err(e) if sh.dd_cap > 0 && e.contains("D30 / B-8") => {
                    skipped.push(format!("{} slot {slot}", sh.name));
                    continue;
                }
                Err(e) => panic!("{} ng{ng} slot {slot}: {e}", sh.name),
            };
            let rounds = def.tabs.iter().filter_map(|t| match t {
                Tab::Priv(p) => Some(p.ext_round + 1),
                _ => None,
            }).max().unwrap_or(0);
            for m in 0..rounds {
                for _ in 0..6 {
                    let v: Vec<Fp2> = def.tabs.iter().map(|t| match t {
                        Tab::Priv(p) if p.ext_round == m => Fp2::new(next(), next()),
                        _ => Fp2::ZERO,
                    }).collect();
                    assert!((def.poly)(&v).is_zero(), "{} ng{ng} slot {slot}: extension round {m} is not an identity (a monomial without a public factor or a zero extension)", sh.name);
                }
                rounds_checked += 1;
            }
            slots_checked += 1;
        }
    }
    eprintln!("F1: {slots_checked} slot polynomials, {rounds_checked} extension rounds, each zero at six random extension points; skipped (refused by the fixture): {skipped:?}");
    assert!(rounds_checked > 0);
    assert!(skipped.len() <= 1, "more than the DD fixture's one refused slot was skipped: {skipped:?}");
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
pub(super) fn prove_and_verify_core(sh: &Shape, blk: &BlockPublic, w: Witness, tamper: impl FnOnce(&mut super::protocol::CoreProof)) -> Result<f64, String> {
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

#[test]
fn w16_limbs_out_of_their_range_are_rejected_by_the_verifier() {
    limbs_out_of_their_range_are_rejected_at(shape::W16_RUNG_H24);
}

/// **The range lookups are what refuse each of these.** Every mutation keeps
/// each relation true (a remainder's value, the product word's value) and
/// moves one limb out of its table; the CHEATING prover skips the miss
/// refusal, so the mutation reaches the verifier, which must reject. At the
/// rung of `profile` (W16's, or since D59 W16R2's at rate 1/2).
pub(super) fn limbs_out_of_their_range_are_rejected_at(profile: &str) {
    // a two-limb remainder: low += 2^16, top -= 1 at a true position. Its
    // value is unchanged; the low limb leaves [0, 2^16) where the top was
    // live, and the top leaves its own window (it becomes -1) where it was 0
    for role in [L::Nr, L::Ms, L::Rao, L::Rd, L::Rs, L::Rg] {
        let (sh, blk, mut w) = rung_case(profile);
        let ids = Ids::new(&sh).unwrap();
        let low = ids.accuracy().unwrap();
        assert_eq!(low.count(role), 2, "{role:?} is a two-limb remainder at this rung");
        let (lo, hi) = (low.limb(role, 0), low.limb(role, 1));
        w.planes[lo][0] += 1 << 16;
        w.planes[hi][0] -= 1;
        let _cheat = super::protocol::CheatingProver::on();
        match prove_and_verify_core(&sh, &blk, w, |_| {}) {
            Ok(_) => panic!("{role:?}: a limb outside its table was accepted"),
            Err(e) => {
                assert!(!e.starts_with("prover:"), "{role:?}: the cheating prover refused ({e}); the mutation must reach the verifier");
                // W16R2 review F4 (c): AT the LogUp sum, so a rate-1/2 PCS
                // artifact cannot pass for this rejection
                assert!(at_the_logup_sum_claim(&e), "{role:?}: rejected, but not at the H opening's LogUp sum claim ({e}); a relation the mutation keeps true failed first");
                eprintln!("W16 LIMB {} {role:?}: the verifier rejects: {e}", sh.name);
            }
        }
    }
    // the product word's signed top limb moved by one: its low expression
    // `h - 2^16 t` leaves [0, 2^16)
    let (sh, blk, mut w) = rung_case(profile);
    let ids = Ids::new(&sh).unwrap();
    let top = ids.accuracy().unwrap().limb(L::H, 0);
    w.planes[top][0] += 1;
    let _cheat = super::protocol::CheatingProver::on();
    match prove_and_verify_core(&sh, &blk, w, |_| {}) {
        Ok(_) => panic!("a moved product top limb was accepted"),
        Err(e) => {
            assert!(!e.starts_with("prover:"), "the cheating prover refused the moved top limb ({e})");
            assert!(at_the_logup_sum_claim(&e), "the moved top limb: rejected, but not at the H opening's LogUp sum claim ({e})");
            eprintln!("W16 LIMB {} H top: the verifier rejects: {e}", sh.name);
        }
    }
}

/// **W16R2 review F4 (c):** a limb outside its table, every relation kept
/// true, is refused by the LogUp sum alone: the `H` opening's value-0 sum
/// claim, `H: pcs zk: group <g>: <v, c> != combined claim`
fn at_the_logup_sum_claim(e: &str) -> bool {
    e.starts_with(&format!("{AT_THE_LOGUP_SUM}: group ")) && e.ends_with(": <v, c> != combined claim")
}

// ------------------------------------------------------------------- F3
//
// W16 REVIEW F3: the four malicious-prover controls DESIGN.md step 5 planned
// (a width confusion, a word overflow, a padded-copy multiplicity, a direct
// quotient overflow). Each mutation keeps every relation true at the rung.
// The positions are chosen so that the edited word feeds nothing else: the
// rung's tame weights are diagonal, so query slot 15 (key-value head 7, dims
// 448..511 >= width 384) reads all-zero keys and values, and a hidden channel
// whose activation is 0 contributes nothing to the product.

/// clears the F3 hooks however the test ends
struct F3Hooks;
impl Drop for F3Hooks {
    fn drop(&mut self) {
        super::protocol::set_misfiled_range(None);
        super::protocol::set_moved_multiplicity(None);
    }
}

/// a remainder's value at `x` from its 16-bit limbs (low limb first)
fn rem_value(w: &Witness, planes: &[usize], x: usize) -> i64 {
    planes.iter().rev().fold(0i64, |a, p| a * (1 << 16) + w.planes[*p][x])
}

/// write `v` into a remainder's limbs at `x`: every limb but the top in
/// `[0, 2^16)`, the top whatever is left (so the limb sum is `v`)
fn set_rem(w: &mut Witness, planes: &[usize], x: usize, v: i64) {
    let mut rest = v;
    for (k, p) in planes.iter().enumerate() {
        if k + 1 == planes.len() {
            w.planes[*p][x] = rest;
        } else {
            w.planes[*p][x] = rest.rem_euclid(1 << 16);
            rest = rest.div_euclid(1 << 16);
        }
    }
    assert_eq!(rem_value(w, planes, x), v);
}

/// the HONEST prover refuses a witness outside its tables with ruling CS-3,
/// before anything is committed
fn honest_prover_refuses(sh: &Shape, blk: &BlockPublic, w: &Witness, what: &str) {
    let copy = Witness { planes: w.planes.clone(), output_plane: w.output_plane };
    match prove_and_verify_core(sh, blk, copy, |_| {}) {
        Ok(_) => panic!("{what}: the honest prover proved a witness outside its tables"),
        Err(e) => {
            assert!(e.starts_with("prover: ") && e.contains(super::protocol::LOOKUP_MISS_REFUSAL), "{what}: not the CS-3 refusal ({e})");
            eprintln!("W16 F3 {} {what}: the honest prover refuses: {}", sh.name, &e[..e.find(';').unwrap_or(e.len())]);
        }
    }
}

/// where a cheat whose every relation holds must fail: after every slot's
/// zero-check has passed, at the `H` opening that carries the value-0 LogUp
/// sum claim
const AT_THE_LOGUP_SUM: &str = "H: pcs zk";
/// where a padded-copy multiplicity must fail: `SC_TAB`'s pad-zero term
const AT_THE_TABLE_SLOT: &str = "[TAB table helper zero-check]";

/// a CHEATING prover's proof of `w` (it skips CS-3), which the VERIFIER must
/// reject at the site `at`; returns the verifier's error
fn verifier_rejects(sh: &Shape, blk: &BlockPublic, w: Witness, what: &str, at: &str) -> String {
    let _cheat = super::protocol::CheatingProver::on();
    match prove_and_verify_core(sh, blk, w, |_| {}) {
        Ok(_) => panic!("{what}: ACCEPTED"),
        Err(e) => {
            assert!(!e.starts_with("prover:"), "{what}: the cheating prover refused ({e}); the mutation must reach the verifier");
            assert!(e.contains(at), "{what}: rejected, but not at `{at}` ({e}); a relation the mutation should keep true failed first");
            eprintln!("W16 F3 {} {what}: the verifier rejects: {e}", sh.name);
            e
        }
    }
}

/// the query slot whose key-value head is all zero at the rung, and that head
fn zero_kv_slot(sh: &Shape, w: &Witness, ids: &Ids) -> (usize, usize) {
    let slot = sh.h_pad - 1;
    let kv = sh.kv_of_slot(slot);
    assert!(sh.slot_is_true_head(slot));
    let (kr, v8) = (ids.at(A_KR8), ids.at(A_V8));
    let dh = sh.head_dim;
    let tokens = sh.size(Dom::Kv) / (sh.kv_heads * dh);
    for t in 0..tokens {
        for i in 0..dh {
            let y = (t * sh.kv_heads + kv) * dh + i;
            assert!(w.planes[kr][y] == 0 && w.planes[v8][y] == 0, "key-value head {kv} is not zero at token {t} dim {i}; the control's position is not inert");
        }
    }
    (slot, kv)
}

/// a true `Dom::F` position whose activation is 0, so `f0 = a u - 2^r h - rh
/// + 2^(r-1)` does not read `u` there
fn inert_hidden_position(sh: &Shape, w: &Witness, ids: &Ids) -> usize {
    let support = crate::private_block::pad::support_indicator(sh, Dom::F);
    let (a, u) = (ids.at(A_A16), ids.at(A_U16));
    (0..sh.size(Dom::F)).find(|&x| support[x] == 1 && w.planes[a][x] == 0 && w.planes[u][x] > -32768).expect("a true hidden position with a zero activation")
}

/// **W16 review F3 (a): the tag fold `gamma tag(w)` is what separates the
/// widths.** A one-limb remainder `r -> r + 2^s` with its word `-1` keeps the
/// rounding relation `2^s word + r = acc + 2^(s-1)` true; `r + 2^s` misses
/// its own `R_s` table but lies in R16's, and the cheating prover files its
/// count THERE. Every relation and every count then balances except the tag
/// (the query folds `gamma tag(s)`, the table entry `gamma tag(16)`), so the
/// verifier must reject — and, the positive control, with the range tags
/// collapsed to one (test-only switch on both sides) the very same cheat is
/// ACCEPTED, so the tag fold is the only term that refuses it.
#[test]
fn w16_f3_a_remainder_filed_in_a_wider_family_is_refused_by_the_tag_fold() {
    f3_a_remainder_filed_in_a_wider_family_at(shape::W16_RUNG_H24);
}

/// F3 (a) at the rung of `profile` (W16's, or since D59 W16R2's)
pub(super) fn f3_a_remainder_filed_in_a_wider_family_at(profile: &str) {
    let _hooks = F3Hooks;
    let (sh, blk, honest) = rung_case(profile);
    let ids = Ids::new(&sh).unwrap();
    let low = ids.accuracy().unwrap();
    let p = sh.accuracy_precision().unwrap();
    let mut cases: Vec<(String, u32, Witness)> = Vec::new();
    // RQL (the review's case: R15 -> R16) at token 0 of the zero-key slot.
    // At token 0 the rotation is the identity (cos 2^7, sin 0), so `QR = Q`
    // and the rope relation holds with both words moved by -1; the partner
    // dimension reads `Q` with sin 0; the score reads `QR` against an
    // all-zero key head.
    {
        let mut w = Witness { planes: honest.planes.clone(), output_plane: honest.output_plane };
        let (slot, _) = zero_kv_slot(&sh, &w, &ids);
        let at = blk.attention();
        assert!(at.rope_cos[0] == 1 << SH_ROPE && at.rope_sin[0] == 0, "the rotation at token 0 is not the identity");
        let x = slot * sh.head_dim; // token 0, dim 0 of `Dom::Q`
        let (q, qr, rq) = (ids.at(A_Q8), ids.at(A_QR8), low.planes(L::Rq));
        assert_eq!((rq.len(), p.q), (1, 15), "RQL is a one-limb 15-bit remainder at this rung");
        assert!(w.planes[q][x] > -32768 && w.planes[qr][x] > -32768);
        let r = rem_value(&w, &rq, x);
        assert!((0..1 << 15).contains(&r));
        w.planes[q][x] -= 1;
        w.planes[qr][x] -= 1;
        set_rem(&mut w, &rq, x, r + (1 << 15));
        cases.push((format!("RQL {r} -> {} (R15 miss filed in R16), Q and QR -1", r + (1 << 15)), 15, w));
    }
    // RU (R12 -> R16) at a hidden position whose activation is 0
    {
        let mut w = Witness { planes: honest.planes.clone(), output_plane: honest.output_plane };
        let x = inert_hidden_position(&sh, &w, &ids);
        let (u, ru) = (ids.at(A_U16), low.planes(L::Ru));
        assert_eq!((ru.len(), p.up), (1, 12), "RU is a one-limb 12-bit remainder at this rung");
        let r = rem_value(&w, &ru, x);
        w.planes[u][x] -= 1;
        set_rem(&mut w, &ru, x, r + (1 << 12));
        cases.push((format!("RU {r} -> {} (R12 miss filed in R16), U -1", r + (1 << 12)), 12, w));
    }
    for (what, s, w) in cases {
        let keep = Witness { planes: w.planes.clone(), output_plane: w.output_plane };
        honest_prover_refuses(&sh, &blk, &w, &what);
        super::protocol::set_misfiled_range(Some((s, 16)));
        verifier_rejects(&sh, &blk, w, &what, AT_THE_LOGUP_SUM);
        // THE POSITIVE CONTROL: one tag for every width, the same cheat
        let collapsed = super::range16::CollapsedRangeTags::on();
        let cheat = super::protocol::CheatingProver::on();
        let accepted = prove_and_verify_core(&sh, &blk, keep, |_| {});
        drop(cheat);
        drop(collapsed);
        super::protocol::set_misfiled_range(None);
        assert!(accepted.is_ok(), "{what}: with the range tags collapsed the cheat was still refused ({:?}), so the tag fold is not the only objection", accepted.err());
        eprintln!("W16 F3 {} {what}: with the range tags collapsed to one, the same cheat is ACCEPTED (positive control)", sh.name);
    }
}

/// **W16 review F3 (b): a 16-bit word one past its window.** `U = +32768`
/// (lookup value `2^16`, the first value outside R16) at a hidden position
/// whose activation is 0, with the rounding relation compensated
/// (`RU -= 2^12 (32768 - U)`). A word is the quotient of its rounding
/// relation, so no compensation keeps the remainder in its window too: RU
/// leaves R12 below zero as well.
#[test]
fn w16_f3_b_a_word_at_plus_32768_is_rejected_by_the_verifier() {
    f3_b_a_word_at_plus_32768_at(shape::W16_RUNG_H24);
}

/// F3 (b) at the rung of `profile` (W16's, or since D59 W16R2's)
pub(super) fn f3_b_a_word_at_plus_32768_at(profile: &str) {
    let (sh, blk, mut w) = rung_case(profile);
    let ids = Ids::new(&sh).unwrap();
    let low = ids.accuracy().unwrap();
    let p = sh.accuracy_precision().unwrap();
    let x = inert_hidden_position(&sh, &w, &ids);
    let (u, ru) = (ids.at(A_U16), low.planes(L::Ru));
    let (u0, r0) = (w.planes[u][x], rem_value(&w, &ru, x));
    w.planes[u][x] = 32768;
    let r1 = r0 - (1i64 << p.up) * (32768 - u0);
    set_rem(&mut w, &ru, x, r1);
    let what = format!("U {u0} -> +32768 (looked up as 65536), RU {r0} -> {r1}");
    honest_prover_refuses(&sh, &blk, &w, &what);
    verifier_rejects(&sh, &blk, w, &what, AT_THE_LOGUP_SUM);
}

/// **W16 review F3 (c): a count moved into a NARROW range family's padded
/// copy.** `moved_multiplicity` extended to the range sub-planes: one count of
/// every narrow family moves from its first counted true row to the LAST
/// padded copy of that row (the same value, the same tag), with the table
/// helper that position needs. The LogUp identity and every `SC_TAB` product
/// relation still hold, so the family's own pad-zero term under its support
/// indicator is the only thing that can object.
#[test]
fn w16_f3_c_a_count_moved_into_a_narrow_range_padded_copy_is_rejected() {
    f3_c_a_count_moved_into_a_narrow_range_padded_copy_at(shape::W16_RUNG_H24);
}

/// F3 (c) at the rung of `profile` (W16's, or since D59 W16R2's)
pub(super) fn f3_c_a_count_moved_into_a_narrow_range_padded_copy_at(profile: &str) {
    let _hooks = F3Hooks;
    let (sh, blk, w) = rung_case(profile);
    let lay = Layout::for_shape(&sh).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, super::protocol::lookup_values(&lay, &w, *d))).collect();
    let (_, m_rng, missed) = super::protocol::w16_histograms(&lay, &looked);
    assert_eq!(missed, 0, "the honest rung witness misses a range table");
    let fams = sh.range_families();
    let mut moved = Vec::new();
    for (j, (f, s, _)) in ids.accuracy().unwrap().range_planes().into_iter().enumerate() {
        if super::range16::full(f, sh.log_cols) {
            continue;
        }
        assert_eq!(s, 0, "a narrow family has one sub-plane");
        let sup = super::range16::support(f, sh.log_cols);
        let m = &m_rng[fams.iter().position(|x| *x == f).unwrap()];
        let from = (0..sup).find(|&i| m[i] > 0).expect("a narrow range family with no count");
        let to = (1usize << sh.log_cols) - sup + from;
        assert_eq!(super::range16::value(f, 0, to, sh.log_cols), super::range16::value(f, 0, from, sh.log_cols));
        let what = format!("R{} count moved from row {from} to its padded copy {to}", f.width);
        super::protocol::set_moved_multiplicity(Some((3 + j, from, to)));
        let copy = Witness { planes: w.planes.clone(), output_plane: w.output_plane };
        verifier_rejects(&sh, &blk, copy, &what, AT_THE_TABLE_SLOT);
        super::protocol::set_moved_multiplicity(None);
        moved.push(f.width);
    }
    assert!(!moved.is_empty(), "the rung has no narrow range family");
    eprintln!("W16 F3 (c) {}: narrow families exercised {moved:?}", sh.name);
    // and the hook, left clear, changes nothing: the honest proof verifies
    prove_and_verify_core(&sh, &blk, w, |_| {}).expect("the F3 hook left a trace behind it");
}

/// **W16 review F3 (d): a direct softmax quotient of `2^13`.** `P` is looked
/// up directly at width 13, so `P = 2^13` is the first value outside it. At
/// token 0 of the zero-value slot (so `P V` does not move), with the division
/// relations compensated (`SR -= dP Sum`, `SG += dP Sum`). `P` is the quotient
/// of `P Sum + SR = mask E 2^f_p`, so SR and SG leave their windows too.
#[test]
fn w16_f3_d_a_direct_quotient_of_2_13_is_rejected_by_the_verifier() {
    f3_d_a_direct_quotient_of_2_13_at(shape::W16_RUNG_H24);
}

/// F3 (d) at the rung of `profile` (W16's, or since D59 W16R2's)
pub(super) fn f3_d_a_direct_quotient_of_2_13_at(profile: &str) {
    let (sh, blk, mut w) = rung_case(profile);
    let ids = Ids::new(&sh).unwrap();
    let low = ids.accuracy().unwrap();
    let p = sh.accuracy_precision().unwrap();
    assert_eq!(p.f_p + 1, 13, "P is looked up at width 13");
    let (slot, _) = zero_kv_slot(&sh, &w, &ids);
    let tp = sh.t_pad;
    let x = (slot * tp) * tp; // query token 0, key token 0 (unmasked)
    let (pp, sum) = (ids.at(A_P), ids.at(A_SUM));
    let (sr, sg) = (low.planes(L::Sr), low.planes(L::Sg));
    let (p0, s) = (w.planes[pp][x], w.planes[sum][x / tp]);
    assert!(s > 0 && (0..1 << 13).contains(&p0));
    let dp = (1i64 << 13) - p0;
    w.planes[pp][x] = 1 << 13;
    let (sr0, sg0) = (rem_value(&w, &sr, x), rem_value(&w, &sg, x));
    set_rem(&mut w, &sr, x, sr0 - dp * s);
    set_rem(&mut w, &sg, x, sg0 + dp * s);
    let what = format!("P {p0} -> 8192 (Sum {s}), SR {sr0} -> {}, SG {sg0} -> {}", sr0 - dp * s, sg0 + dp * s);
    honest_prover_refuses(&sh, &blk, &w, &what);
    verifier_rejects(&sh, &blk, w, &what, AT_THE_LOGUP_SUM);
}

// ------------------------------------------------------- [A12] the device tables

/// [A12] dense nonzero committed data of the slot builders' sizes (`A`, `H`,
/// the two endpoints), from a fixed-seed stream: every word a canonical
/// nonzero `Fp`, so no table can hide a wrong word behind a zero
#[cfg(feature = "gpu-metal")]
fn a12_data(sh: &Shape, lay: &Layout) -> [Vec<crate::field::Fp>; 4] {
    use crate::field::{Fp, P};
    let n = lay.n();
    let mut z = 0xA12A_12A1_2A12_A12Au64 ^ (sh.tokens as u64) << 20 ^ sh.width as u64;
    let mut next = move || {
        z ^= z << 13;
        z ^= z >> 7;
        z ^= z << 17;
        Fp::new(1 + z % (P - 1))
    };
    let io = ((1usize << sh.log(Dom::D)) + 8 * n).max(sh.endpoint_rows << sh.endpoint_log_n);
    [(0..lay.a_rows * n).map(|_| next()).collect(), (0..lay.h_rows * n).map(|_| next()).collect(), (0..io).map(|_| next()).collect(), (0..io).map(|_| next()).collect()]
}

/// [A12] a table as the device kernels compute it (`gpu/metal.rs`, `TAB_SRC`),
/// evaluated on the HOST from the same plan: an eq cube as `hi * lo`, a plane
/// as `sum_z eqf[z] v(inv(x & used) | zbits[z])`; `None` for what the host
/// writes beside the device (public tables, a plane `plane_plan` declines)
#[cfg(feature = "gpu-metal")]
fn a12_kernel_formula(tab: &super::argument::Tab, n: usize, data: &[Vec<crate::field::Fp>; 4]) -> Option<Vec<crate::field::Fp2>> {
    use super::argument::{plane_plan, Tab};
    use crate::field::Fp2;
    use crate::mle::eq_table_msb;
    use rayon::prelude::*;
    match tab {
        Tab::Eq { point, start } => {
            let p = point.len();
            let p_lo = p / 2;
            let (hi, lo) = (eq_table_msb(&point[..p - p_lo]), eq_table_msb(&point[p - p_lo..]));
            let (shift, mask) = (n - start - p, (1usize << p) - 1);
            Some(
                (0..1usize << n)
                    .into_par_iter()
                    .map(|x| {
                        let y = (x >> shift) & mask;
                        hi[y >> p_lo].mul(lo[y & ((1usize << p_lo) - 1)])
                    })
                    .collect(),
            )
        }
        Tab::Pub(_) => None,
        Tab::Priv(pv) => {
            let (used, xlo, il, ih, zb, eqf) = plane_plan(pv, n)?;
            let d = &data[pv.cm as usize];
            let val = |idx: usize| -> Fp2 {
                if pv.slices.len() == 1 && pv.slices[0].1 == Fp2::ONE {
                    return Fp2::from_base(d[pv.slices[0].0 + idx]);
                }
                pv.slices.iter().fold(Fp2::ZERO, |a, (off, c)| a.add(c.mul_base(d[off + idx])))
            };
            Some(
                (0..1usize << n)
                    .into_par_iter()
                    .map(|x| {
                        let xu = x & used;
                        let im = ih[xu >> xlo] as usize | il[xu & ((1usize << xlo) - 1)] as usize;
                        if eqf.is_empty() {
                            val(im)
                        } else {
                            (0..eqf.len()).fold(Fp2::ZERO, |a, z| a.add(eqf[z].mul(val(im | zb[z] as usize))))
                        }
                    })
                    .collect(),
            )
        }
    }
}

/// [A12] a one-line label of a table, for the census (schedule facts only:
/// kind, sizes, slice and fixed-coordinate counts; never a value)
#[cfg(feature = "gpu-metal")]
fn a12_label(tab: &super::argument::Tab, n: usize) -> String {
    use super::argument::{plane_plan, Coord, Tab};
    match tab {
        Tab::Eq { point, start } => format!("eq(p{} @{start})", point.len()),
        Tab::Pub(_) => "pub".to_string(),
        Tab::Priv(p) => {
            let nf = p.coords.iter().filter(|c| matches!(c, Coord::Fixed(_))).count();
            let plan = plane_plan(p, n);
            let bcast = plan.as_ref().map(|pl| pl.0 != (1usize << n) - 1).unwrap_or(false);
            let slices = if p.slices.len() > 1 { format!("x{}", p.slices.len()) } else { String::new() };
            let fix = if nf > 0 { format!(" fix{nf}") } else { String::new() };
            format!("{:?}{slices}{fix}{}{}", p.cm, if bcast { " bcast" } else { "" }, if plan.is_none() { " HOST" } else { "" })
        }
    }
}

/// **[A12] the device kernels' formula equals the host builders, word for
/// word, at every slot of the W16R2 rung (CPU).** For every table of every
/// slot, the plan the device is given (`plane_plan` and the eq halves),
/// evaluated on the host as the kernels evaluate it, against the vectors the
/// prover builds (`build_tables_at`, the host path, and `build_tables_into`,
/// the direct path's host builder). Dense nonzero committed data, so a wrong
/// gather cannot hide behind a zero. Also counts what the host still writes.
#[cfg(feature = "gpu-metal")]
#[test]
fn a12_the_device_table_formula_equals_the_host_builders_at_every_slot_of_the_w16r2_rung() {
    use super::argument::{build_tables_at, build_tables_into, define, Ctx, Points, ProverData, TABLES_PAR_MIN};
    use crate::field::Fp2;
    use crate::transcript::Transcript;
    let k = |v: i64| Fp2::from_i64(v);
    let (sh, data, public, ff) = case(built(shape::W16R2_RUNG_H24), 3);
    let lay = Layout::for_shape(&sh).unwrap();
    let d = a12_data(&sh, &lay);
    let masks = Vec::new();
    let pd = ProverData { data: [&d[0], &d[1], &d[2], &d[3]], masks: &masks };
    let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
    let mut pts = Points::default();
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let (mut by_formula, mut by_host, mut words) = (0usize, 0usize, 0usize);
    for slot in 0..sh.n_slots() {
        let mut def = define(slot, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {slot}: {e}"));
        let n = sh.slots()[slot].0;
        let formula: Vec<Option<Vec<Fp2>>> = def.tabs.iter().map(|t| a12_kernel_formula(t, n, &d)).collect();
        let stale = Fp2::new(crate::field::Fp::new(5), crate::field::Fp::new(9));
        let mut direct: Vec<Vec<Fp2>> = vec![vec![stale; 1usize << n]; def.tabs.len()];
        build_tables_into(&def.tabs, n, &pd, direct.iter_mut().map(|v| v.as_mut_slice()).collect());
        let host = build_tables_at(&mut def.tabs, n, &pd, TABLES_PAR_MIN);
        assert_eq!(host, direct, "slot {slot}: the two host builders differ");
        for (t, f) in formula.iter().enumerate() {
            match f {
                Some(f) => {
                    let bad = f.iter().zip(host[t].iter()).position(|(a, b)| a != b);
                    assert!(bad.is_none(), "slot {slot} table {t}: the device formula differs from the host at word {}", bad.unwrap_or(0));
                    by_formula += 1;
                    words += f.len();
                }
                None => by_host += 1,
            }
        }
    }
    eprintln!("A12-FORMULA {}: {by_formula} tables ({words} words) equal by the device formula, {by_host} left to the host (public tables)", sh.name);
    assert!(by_formula > 100, "the formula covered only {by_formula} tables");
}

/// **[A12] the census, and the device tables word for word (Metal).** At W16R2
/// 8B T128 and the W16R2 rung, for EVERY slot (not only the device slots, so
/// every table shape the schedule has is built): the tables built on the
/// device (`build_tables_device`) against the host's (`build_tables_at`),
/// every word; the device's base check against the host's; a control that
/// flags every table base and must be refused where an extension word exists.
/// Prints each slot's tables by kind and the time of both builds, on the
/// global pool and in a pool of six (a fork worker's size at N = 6).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A12: builds every slot's tables on the device at W16R2 8B and the rung; run alone by name on a Mac"]
fn a12_census_and_the_device_tables_equal_the_host_tables_word_for_word() {
    use super::argument::{build_tables_at, build_tables_device, build_tables_into, define, Ctx, Points, ProverData, Tab, TABLES_PAR_MIN};
    use super::slot_ir::{build_slot_ir, IrPoints};
    use crate::field::Fp2;
    use crate::gpu::MetalTables;
    use crate::transcript::Transcript;
    let k = |v: i64| Fp2::from_i64(v);
    let six = rayon::ThreadPoolBuilder::new().num_threads(6).build().expect("a pool of six");
    for profile in [shape::W16R2_8B_T128_H24, shape::W16R2_RUNG_H24] {
        let (sh, data, public, ff) = case(built(profile), 3);
        let lay = Layout::for_shape(&sh).unwrap();
        let d = a12_data(&sh, &lay);
        let masks = Vec::new();
        let pd = ProverData { data: [&d[0], &d[1], &d[2], &d[3]], masks: &masks };
        let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
        let (mut pts, mut ipts) = (Points::default(), IrPoints::default());
        let mut tr = Transcript::new(sh.profile.as_bytes());
        let (mut sums, mut tables_checked, mut words_checked, mut deferred_slots, mut declined_slots) = ([0f64; 4], 0usize, 0usize, 0usize, 0usize);
        for slot in 0..sh.n_slots() {
            let mut twin = Transcript::clone_state(&tr);
            let ir = build_slot_ir(slot, &ctx, &mut ipts, &mut twin);
            let mut def = define(slot, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{profile} slot {slot}: {e}"));
            let n = sh.slots()[slot].0;
            let kt = def.tabs.len();
            let base: Vec<bool> = match &ir {
                Ok(ir) if ir.tables.len() == kt => super::metal_slot::msl_round_kernels(ir).3,
                _ => vec![false; kt],
            };
            let direct = ir.is_ok() && SLOT_KINDS[slot] != SlotKind::Private && (kt << n) > 1 << 18;
            // the device build (best of two: the first compiles the kernels)
            let mut dev_s = f64::INFINITY;
            let mut dev = None;
            for _ in 0..2 {
                let mut mt = MetalTables::new(kt, 1usize << n).expect("device tables");
                let t = std::time::Instant::now();
                assert!(build_tables_device(&def.tabs, n, &pd, &mut mt, &base, false, true).unwrap_or_else(|e| panic!("{profile} slot {slot}: the device build: {e}")), "{profile} slot {slot}: the device did not take the build");
                dev_s = dev_s.min(t.elapsed().as_secs_f64());
                dev = Some(mt);
            }
            let mt = dev.expect("a device build");
            let time_host = |pool: Option<&rayon::ThreadPool>| -> f64 {
                let mut best = f64::INFINITY;
                for _ in 0..2 {
                    let mut ht = MetalTables::new(kt, 1usize << n).expect("host tables");
                    let t = std::time::Instant::now();
                    match pool {
                        Some(p) => p.install(|| build_tables_into(&def.tabs, n, &pd, ht.tables_mut())),
                        None => build_tables_into(&def.tabs, n, &pd, ht.tables_mut()),
                    }
                    best = best.min(t.elapsed().as_secs_f64());
                }
                best
            };
            let (host_s, host6_s) = (time_host(None), time_host(Some(&six)));
            let mut t6 = MetalTables::new(kt, 1usize << n).expect("device tables");
            let t = std::time::Instant::now();
            assert!(six.install(|| build_tables_device(&def.tabs, n, &pd, &mut t6, &base, false, true)).expect("the device build in a pool of six"));
            let dev6_s = t.elapsed().as_secs_f64();
            // the control (before `build_tables_at`, which moves the public tables out)
            let mut ctl = MetalTables::new(kt, 1usize << n).expect("device tables");
            assert!(build_tables_device(&def.tabs, n, &pd, &mut ctl, &vec![true; kt], false, true).expect("the control build"));
            // the deferred form (as the prover runs it), run alone by `flush`
            let mut dfr = MetalTables::new(kt, 1usize << n).expect("device tables");
            assert!(build_tables_device(&def.tabs, n, &pd, &mut dfr, &base, true, true).expect("the deferred build"));
            // the prover's own rule: a 330 MB slice not resident is not mapped, the host builds
            if def.tabs.iter().any(|t| matches!(t, Tab::Priv(p) if d[p.cm as usize].len() > 1 << 22)) {
                let mut no = MetalTables::new(kt, 1usize << n).expect("device tables");
                let taken = build_tables_device(&def.tabs, n, &pd, &mut no, &base, true, false).expect("the prover's form");
                assert!(!taken && !no.deferred() && no.base_checked().is_none(), "{profile} slot {slot}: the device took a build over large rows that are not resident");
                declined_slots += 1;
            }
            let deferred = dfr.deferred();
            dfr.flush().expect("the deferred build, flushed");
            let pubs = def.tabs.iter().filter(|t| matches!(t, Tab::Pub(_))).count();
            let host = build_tables_at(&mut def.tabs, n, &pd, TABLES_PAR_MIN);
            let got = mt.to_vecs();
            for (t, (g, h)) in got.iter().zip(host.iter()).enumerate() {
                let bad = g.iter().zip(h.iter()).position(|(a, b)| a != b);
                assert!(bad.is_none(), "{profile} slot {slot} table {t}: the device table differs from the host's at word {}", bad.unwrap_or(0));
                words_checked += g.len();
            }
            assert!(t6.to_vecs() == host, "{profile} slot {slot}: the device build in a pool of six differs");
            tables_checked += kt;
            // the base check: the device's answer is the host's
            let host_typed = host.iter().zip(base.iter()).all(|(t, &b)| !b || t.iter().all(|v| v.c1.is_zero()));
            assert_eq!(mt.base_checked(), Some(host_typed), "{profile} slot {slot}: the device's base check differs from the host's");
            // the control: every table flagged base is refused wherever an extension word exists
            let any_ext = host.iter().any(|t| t.iter().any(|v| !v.c1.is_zero()));
            assert_eq!(ctl.base_checked(), Some(!any_ext), "{profile} slot {slot}: the all-base control");
            assert!(ctl.to_vecs() == host, "{profile} slot {slot}: the control build's words differ");
            assert!(dfr.to_vecs() == host, "{profile} slot {slot}: the deferred build's words differ");
            assert_eq!(dfr.base_checked(), Some(host_typed), "{profile} slot {slot}: the deferred build's base check");
            deferred_slots += usize::from(deferred);
            if direct {
                sums[0] += host_s;
                sums[1] += host6_s;
                sums[2] += dev_s;
                sums[3] += dev6_s;
            }
            let mut hist: Vec<(String, usize)> = Vec::new();
            for kd in def.tabs.iter().map(|t| a12_label(t, n)) {
                match hist.iter_mut().find(|(k, _)| *k == kd) {
                    Some(e) => e.1 += 1,
                    None => hist.push((kd, 1)),
                }
            }
            eprintln!(
                "A12-CENSUS {profile} slot {slot:02} [{}]{}: 2^{n} x {kt} tables = {:.2} M words ({:.0} MB), {pubs} public | host {:.2} ms (global pool), {:.2} ms (pool of 6) | device {:.2} ms, {:.2} ms (pool of 6) | {}",
                SLOT_NAMES[slot],
                if direct { " DEVICE SLOT" } else { "" },
                (kt << n) as f64 * 1e-6,
                (kt << n) as f64 * 16e-6,
                host_s * 1e3,
                host6_s * 1e3,
                dev_s * 1e3,
                dev6_s * 1e3,
                hist.iter().map(|(k, c)| format!("{c} {k}")).collect::<Vec<_>>().join(", ")
            );
        }
        eprintln!(
            "A12-CENSUS {profile}: every word of {tables_checked} tables ({:.1} M words) equal, and of every slot's deferred build ({deferred_slots} slots deferred); without resident rows the prover's form left {declined_slots} slots to the host; the device slots' tables: host {:.1} ms (global pool), {:.1} ms (pool of 6); device {:.1} ms, {:.1} ms (pool of 6); builds so far {:?}",
            words_checked as f64 * 1e-6,
            sums[0] * 1e3,
            sums[1] * 1e3,
            sums[2] * 1e3,
            sums[3] * 1e3,
            MetalTables::build_stats()
        );
    }
}
