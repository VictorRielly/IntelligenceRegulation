//! **D24 REVIEW ROUND 9 (independent review lane, 2026-10-20): DD, the
//! per-row division dictionary (register entry D30).** TEST CODE ONLY, in the
//! reviewer's scratch copy; public synthetic data only. Not a privacy review.
//!
//! * A: the row-Sum KEY is bound by the row-sum relation (SC_RS), not by the
//!   dictionary: a witness whose dictionary, tuple keys and quotients are all
//!   consistent with a FALSE Sum at one row (every DD relation and every
//!   lookup holds at the integer level) is rejected by the verifier;
//! * B: ruling CS-8 refuses a `dd_cap` written into a shape;
//! * C: the DD profiles' geometry is unpadded, and the dictionary's limb
//!   lookups read only dictionary planes;
//! * D: the LogUp term `(N + 2303 + 4 rows cap)/|F|` counted per block and per
//!   run at the DD profiles and their non-DD twins (from the real exports
//!   when `ZK60_REVIEW_TL_EXPORT` / `ZK60_REVIEW_8B_EXPORT` name them);
//! * E: the trained door on DD-rung exports the reviewer writes: an over-cap
//!   layer refused by name at the loader and by every CLI command that would
//!   load it, an in-cap layer range of the same export proved and verified,
//!   and a two-layer in-cap export through stack-prove / stack-verify
//!   `--controls` / single-block prove / verify `--controls`;
//! * F: `Geometry::dd` refuses every geometry with no DD profile.

use super::layout::*;
use super::shape::{Shape, DD_CAP};
use super::trained_block::*;
use super::witness;
use super::*;
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

/// the Goldilocks prime, `|F| = p^2`
const P_GOLDILOCKS: f64 = 18_446_744_069_414_584_321.0;

fn dd_rung() -> Shape {
    Shape::rung_dd(&super::trained_calib_tests::rung_tc_calibration()).expect("the DD development rung")
}

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

fn n_col(e_s: i32, head_dim: usize, f_e: u32) -> usize {
    let (t, _) = crate::tables_attn::exp_member(e_s, head_dim, f_e);
    std::iter::once(0).chain(t.iter().copied()).collect::<BTreeSet<i64>>().len()
}

fn limbs(v: i64, n: usize) -> Vec<i64> {
    (0..n).map(|k| (v >> (8 * k)) & 0xff).collect()
}

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

// ------------------------------------------------------------------ A

/// **A: the key is bound by SC_RS.** At one row (h, t), the committed Sum is
/// moved by a small delta chosen so that every dictionary quotient
/// floor(e_k 2^F_P / Sum) is unchanged; the row's dictionary remainders and
/// their limbs are rewritten for the false Sum. Then every dictionary clause
/// (c2, c3, c4, limbs and top pins) holds at every slot, every score entry's
/// tuple (false Sum, mask E, P) is a tuple of its row's dictionary, every
/// byte / exp / activation lookup hits, and the ONLY broken fact is the row
/// sum `Sum = sum_j mask E` at that one row. The verifier must reject.
#[test]
fn review_r9_a_the_sum_key_is_bound_by_the_row_sum_relation() {
    let sh = dd_rung();
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let (blk, _, _) = block_with(&sh, &w, 2, (-3, -11));
    let mut wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the honest DD witness");
    let ids = Ids::new(&sh).unwrap();
    let lay = Layout::for_shape(&sh).unwrap();
    let (tp, cap, lp, ls, wr) = (sh.t_pad, sh.dd_cap, sh.limbs_p(), sh.limbs_sigma_s(), sh.wrho_s);
    let ecol = blk.attention().dd_e_column(cap).unwrap();
    let nht = sh.size(Dom::Ht);
    let (i_sum, i_e) = (ids.at(A_SUM), ids.at(A_E));
    // the honest premises, at the index convention the prover and the
    // verifier share: S position (ht, j) = ht * t_pad + j, dictionary slot
    // (ht, k) = ht * cap + k, mask j <= ht mod t_pad
    for ht in 0..nht {
        let t = ht % tp;
        let s: i64 = (0..=t).map(|j| wit.planes[i_e][ht * tp + j]).sum();
        assert_eq!(s, wit.planes[i_sum][ht], "row {ht}: the honest Sum is not the row sum of mask E");
        for (k, ek) in ecol.iter().enumerate() {
            assert_eq!(wit.planes[ids.pdict()][ht * cap + k], (ek << F_P) / s, "slot ({ht}, {k})");
        }
    }
    // pick the row and the delta
    let mut pick = None;
    'o: for ht in 0..nht {
        let s = wit.planes[i_sum][ht];
        for d in [1i64, -1, 2, -2, 3, -3, 4, -4, 5, -5] {
            let s2 = s + d;
            if s2 < 1 {
                continue;
            }
            let ok = ecol.iter().all(|&e| {
                let n = e << F_P;
                let q = n / s;
                let r = n - q * s2;
                n / s2 == q && r >= 0 && r < (1i64 << wr) && s2 - 1 - r >= 0 && s2 - 1 - r < (1i64 << wr)
            });
            if ok {
                pick = Some((ht, s, d));
                break 'o;
            }
        }
    }
    let (ht, s, d) = pick.expect("no row admits a Sum move that keeps every quotient");
    let s2 = s + d;
    wit.planes[i_sum][ht] = s2;
    for (k, ek) in ecol.iter().enumerate() {
        let x = ht * cap + k;
        let q = wit.planes[ids.pdict()][x];
        let rho = (ek << F_P) - q * s2;
        let sigma = s2 - 1 - rho;
        for (kk, v) in limbs(rho, ls).into_iter().enumerate() {
            wit.planes[ids.sr(kk)][x] = v;
        }
        for (kk, v) in limbs(sigma, ls).into_iter().enumerate() {
            wit.planes[ids.sg(kk)][x] = v;
        }
    }
    // the integer-level audit: every DD clause holds at every slot ...
    let lb = |ix: &dyn Fn(usize) -> usize, n: usize, x: usize| -> i64 { (0..n).map(|kk| wit.planes[ix(kk)][x] << (8 * kk)).sum() };
    for hh in 0..nht {
        let sum = wit.planes[i_sum][hh];
        for (k, ek) in ecol.iter().enumerate() {
            let x = hh * cap + k;
            let pd = wit.planes[ids.pdict()][x];
            let rho = lb(&|kk| ids.sr(kk), ls, x);
            let sigma = lb(&|kk| ids.sg(kk), ls, x);
            assert_eq!((ek << F_P) - pd * sum - rho, 0, "c2 at ({hh}, {k})");
            assert_eq!(sigma + rho + 1 - sum, 0, "c3 at ({hh}, {k})");
            assert_eq!(pd, lb(&|kk| ids.pl(kk), lp, x), "c4 at ({hh}, {k})");
            assert!((0..1i64 << wr).contains(&rho) && (0..1i64 << wr).contains(&sigma) && (0..1i64 << (F_P + 1)).contains(&pd), "a pin at ({hh}, {k})");
        }
    }
    // ... every score tuple is in its row's dictionary, every lookup hits ...
    assert_eq!(super::protocol::dd_misses(&lay, &wit, &ecol), 0, "a score tuple left the dictionary");
    super::protocol::check_lookup_misses(&sh, &lay, &blk, &wit).expect("a byte / exp / activation lookup misses");
    // ... and only the row sum is off, at exactly one row
    let off: Vec<usize> = (0..nht).filter(|&hh| (0..=hh % tp).map(|j| wit.planes[i_e][hh * tp + j]).sum::<i64>() != wit.planes[i_sum][hh]).collect();
    assert_eq!(off, vec![ht]);
    eprintln!("REVIEW-R9 A: row {ht} (h-slot {}, t {}), Sum {s} -> {s2}; every DD clause, tuple and lookup holds; the row sum is off at that row only", ht / tp, ht % tp);
    let _cheat = super::protocol::CheatingProver::on();
    let one = super::trained_calib_tests::prove_one_bound(&sh, &blk, wit).unwrap_or_else(|e| panic!("A: the prover produced no receipt: {e}"));
    let r = super::trained_calib_tests::verify_one_bound(&sh, &blk, &one.expected.to_bytes(), &one.seg);
    let e = r.expect_err("A: a FALSE row Sum, consistent everywhere in the dictionary, VERIFIED");
    eprintln!("REVIEW-R9 A: rejected as built: {}", e.chars().take(200).collect::<String>());
}

// ------------------------------------------------------------------ B

/// **B: CS-8 refuses a written `dd_cap`** (the field is derived from the
/// profile string, so a non-DD shape with a dictionary, or a DD shape without
/// one or with another cap, is not a shape `Shape::new` builds).
#[test]
fn review_r9_b_cs8_refuses_a_dd_cap_written_into_a_shape() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    let mut n = 0;
    for (plain, dd) in [
        (Shape::tinyllama_trained(128, &tl, 9).unwrap(), Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap()),
        (Shape::llama3_8b_trained(128, &l8, 9).unwrap(), Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap()),
        (Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap(), dd_rung()),
    ] {
        plain.check_constructed().unwrap();
        dd.check_constructed().unwrap();
        let mut a = plain.clone();
        a.dd_cap = DD_CAP;
        let e = a.check_constructed().expect_err("a non-DD shape carrying a dictionary passed CS-8");
        assert!(e.contains("CS-8"), "{e}");
        assert!(super::trained_calib_tests::run_shape_for_checked(&a, 1).is_err(), "{}: a run shape took the edited shape", a.profile);
        for cap in [0usize, 16, 64] {
            let mut b = dd.clone();
            b.dd_cap = cap;
            let e = b.check_constructed().expect_err("a DD shape with another cap passed CS-8");
            assert!(e.contains("CS-8"), "{e}");
            n += 1;
        }
        n += 1;
    }
    eprintln!("REVIEW-R9 B: {n} edited shapes refused by CS-8");
}

// ------------------------------------------------------------------ C

/// **C: the DD geometry.** At every DD profile the score, row and dictionary
/// domains are unpadded and unlifted (`size == true_size`), the dictionary
/// is `rows x cap` with `cap` a power of two and the row variables leading,
/// and every dictionary limb lookup reads only `Dom::Dd` planes (never a
/// stale score-domain plane); the score domain keeps exactly sym(s8) and
/// the rsl pair.
#[test]
fn review_r9_c_the_dd_geometry_is_unpadded_and_the_dictionary_lookups_read_dictionary_planes() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    for s in [dd_rung(), Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap(), Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap()] {
        assert_eq!((s.h_pad, s.t_pad), (s.q_heads, s.tokens), "{}", s.profile);
        for d in [Dom::S, Dom::Ht, Dom::Dd] {
            assert_eq!(s.size(d), s.true_size(d), "{}: {d:?} pads or is lifted", s.profile);
            assert!(!s.pads(d));
        }
        assert!(s.dd_cap.is_power_of_two() && s.dd_cap == DD_CAP);
        assert_eq!(s.size(Dom::Dd), s.size(Dom::Ht) * s.dd_cap);
        assert_eq!(s.size(Dom::S), s.size(Dom::Ht) * s.t_pad);
        assert!(s.log(Dom::Dd) >= s.log_cols && s.log(Dom::S) >= s.log_cols);
        let ids = Ids::new(&s).unwrap();
        let doms = s.a_plane_doms();
        let dd_lk = lookups_at(&s, &ids, Dom::Dd);
        assert_eq!(dd_lk.len(), (s.limbs_p() + 1) + 2 * (s.limbs_sigma_s() + 1));
        for lk in &dd_lk {
            for (p, _) in &lk.terms {
                assert_eq!(doms[*p], Dom::Dd, "{}: a dictionary lookup reads plane {p} on {:?}", s.profile, doms[*p]);
            }
        }
        let s_lk = lookups_at(&s, &ids, Dom::S);
        assert_eq!(s_lk.len(), 4);
        for lk in &s_lk {
            for (p, _) in &lk.terms {
                assert_eq!(doms[*p], Dom::S);
            }
        }
        // P_dict, its limbs, rho / sigma limbs and M_dd: all A planes on Dd,
        // none a prover-derived histogram (so all are the witness's, in A)
        for p in [ids.pdict(), ids.mdd()].into_iter().chain((0..s.limbs_p()).map(|k| ids.pl(k))).chain((0..s.limbs_sigma_s()).flat_map(|k| [ids.sr(k), ids.sg(k)])) {
            assert_eq!(doms[p], Dom::Dd);
            assert!(!ids.is_multiplicity(p));
        }
        eprintln!(
            "REVIEW-R9 C {}: log_cols {}, S 2^{}, Ht 2^{}, Dd 2^{}, cap {}, lp {}, ls {}, wrho_s {}",
            s.profile,
            s.log_cols,
            s.log(Dom::S),
            s.log(Dom::Ht),
            s.log(Dom::Dd),
            s.dd_cap,
            s.limbs_p(),
            s.limbs_sigma_s(),
            s.wrho_s
        );
    }
}

// ------------------------------------------------------------------ D

fn logup_n(sh: &Shape) -> (u64, u64, u64) {
    let lay = Layout::for_shape(sh).unwrap();
    let u8: u64 = lay.lookup_doms().iter().map(|d| (lay.lookups(*d).len() * sh.size(*d)) as u64).sum();
    assert_eq!(u8 as usize, sh.totals().u8_lookups, "{}: the built lookup list and the counter disagree", sh.profile);
    let pairs = (sh.size(Dom::S) + sh.size(Dom::F)) as u64;
    let tuples = if sh.dd_cap > 0 { sh.size(Dom::S) as u64 } else { 0 };
    let t_dd = if sh.dd_cap > 0 { sh.size(Dom::Dd) as u64 } else { 0 };
    (u8 + pairs + tuples, t_dd, u8)
}

fn bits(n: u64, t_dd: u64, blocks: usize) -> (f64, f64) {
    let f = P_GOLDILOCKS * P_GOLDILOCKS;
    let per = (n as f64 + 2303.0 + 4.0 * t_dd as f64) / f;
    (per.log2(), (per * blocks as f64).log2())
}

/// the base shape (and, under `--dd`, the DD shape) of a real export's run
fn export_shapes(dir: &Path) -> Option<(Shape, Shape, usize)> {
    let ex = TrainedExport::load(dir).ok()?;
    let c = ex.run_constants(&ex.layers).ok()?;
    let plain = ex.shape_for(&c).ok()?;
    let mut exd = TrainedExport::load(dir).ok()?;
    exd.geometry = exd.geometry.dd().ok()?;
    let dd = exd.shape_for(&c).ok()?;
    Some((plain, dd, ex.layers.len()))
}

/// **D: the LogUp term counted** — N = the byte lookups over every position
/// of each lookup domain (the BUILT list, cross-checked against the shape's
/// counter) + |S| exp pairs + |F| activation pairs (+ |S| tuple queries on
/// DD), T_DD = rows x cap; per block (N + 2303 + 4 T_DD)/p^2, per run the
/// union over the run's blocks.
#[test]
fn review_r9_d_the_logup_term_counted_at_the_dd_profiles() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    let mut rows: Vec<(String, Shape, Shape, usize)> = vec![
        ("TinyLlama T128 (test calibration)".into(), Shape::tinyllama_trained(128, &tl, 9).unwrap(), Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap(), 22),
        ("Llama-3-8B T128 (test calibration)".into(), Shape::llama3_8b_trained(128, &l8, 9).unwrap(), Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap(), 32),
    ];
    for (var, name) in [("ZK60_REVIEW_TL_EXPORT", "TinyLlama dg_rot1 T128 (the export's run shape)"), ("ZK60_REVIEW_8B_EXPORT", "Llama-3-8B b7voc0 T128 (the export's run shape)")] {
        if let Some(d) = std::env::var_os(var) {
            let (p, q, l) = export_shapes(Path::new(&d)).unwrap_or_else(|| panic!("{var}: the export did not load"));
            rows.push((name.into(), p, q, l));
        }
    }
    for (name, plain, dd, l) in rows {
        let (n0, _, u0) = logup_n(&plain);
        let (n1, t1, u1) = logup_n(&dd);
        let (b0, r0) = bits(n0, 0, l);
        let (b1, r1) = bits(n1, t1, l);
        eprintln!(
            "REVIEW-R9 D {name}: non-DD U8 {u0} N {n0}: per block 2^{b0:.2}, per {l}-block run 2^{r0:.2} | DD U8 {u1} N {n1} T_DD {t1}: N + 2303 + 4 T_DD = {}, per block 2^{b1:.2}, per run 2^{r1:.2} ({:+.2} bits)",
            n1 + 2303 + 4 * t1,
            r0 - r1
        );
        assert!(r1 <= r0 + 0.01, "{name}: DD loosens the lookup term");
        assert!(r1 < -95.0, "{name}: the DD run's lookup term is above 2^-95");
    }
    let r = dd_rung();
    let (n, t, u) = logup_n(&r);
    let (b, _) = bits(n, t, 1);
    eprintln!("REVIEW-R9 D DD rung: U8 {u} N {n} T_DD {t}: per block 2^{b:.2}");
}

// ------------------------------------------------------------------ E

fn constants(cal: &super::shape::NormCalibration, f_e: u32, e_s: i32, silu: (i32, i32)) -> String {
    format!(
        "{{\"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_qkv\": {}, \"sh_rope\": 7, \"sh_s\": {}, \"sh_o\": {}, \"sh_ao\": {}, \"sh_g\": {}, \"sh_u\": 0, \"sh_h\": {}, \"sh_z\": {}, \"f_e\": {f_e}, \"f_p\": 9, \"f_ro\": 7, \"sh_r2\": 0, \"silu_member\": [{}, {}], \"exp_e_s\": {e_s}, \"rope_theta\": 10000.0}}",
        cal.tn, cal.cn_a, cal.cn_m, cal.ceps, cal.sh_qkv, cal.sh_s, cal.sh_o, cal.sh_ao, cal.sh_g, cal.sh_h, cal.sh_z, silu.0, silu.1
    )
}

fn i8_bytes(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}
fn i16_bytes(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}
fn i64_bytes(v: &[i64]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// a chained DD-rung export (`geometry: rung-dd-t32-dev`, synthetic source)
/// whose layer k uses exp `e_s[k]`; x_out is the independent reference
/// kernel's (cross-checked against the DD witness where the table fits)
fn write_dd_export(dir: &Path, variant: &str, e_s: &[i32]) -> PathBuf {
    let cal = super::trained_calib_tests::rung_tc_calibration();
    let sh = dd_rung();
    let ids = Ids::new(&sh).unwrap();
    let (w0, mut x) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let vdir = dir.join(variant);
    let sdir = vdir.join("seq_s0");
    std::fs::create_dir_all(&sdir).unwrap();
    let (d, f, kvw) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim);
    let (mut layer_objs, mut seq_arrays) = (Vec::new(), Vec::new());
    for (k, es) in e_s.iter().enumerate() {
        let mut w = w0.clone();
        for (i, m) in w.iter_mut().enumerate() {
            let len = m.len();
            m.rotate_left((k * (7 + i)) % len);
        }
        let silu = if k % 2 == 0 { (-3, -11) } else { (-4, -12) };
        let (blk, exp, act) = block_with(&sh, &w, *es, silu);
        let x_out = kernel_out(&sh, &w, &x, &exp, &act);
        if n_col(*es, sh.head_dim, sh.f_e) <= DD_CAP {
            let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).unwrap_or_else(|e| panic!("layer {k}: the DD witness: {e}"));
            let mine: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| wit.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect();
            assert_eq!(mine, x_out, "layer {k}: the DD witness and the reference kernel disagree");
        }
        let ldir = vdir.join(format!("layer_{k:02}"));
        std::fs::create_dir_all(&ldir).unwrap();
        let arrays: Vec<(&str, Vec<u8>, &str, String)> = vec![
            ("wq", i8_bytes(&w[0]), "int8", format!("[{d}, {d}]")),
            ("wk", i8_bytes(&w[1]), "int8", format!("[{kvw}, {d}]")),
            ("wv", i8_bytes(&w[2]), "int8", format!("[{kvw}, {d}]")),
            ("wo", i8_bytes(&w[3]), "int8", format!("[{d}, {d}]")),
            ("gamma_a", i8_bytes(&w[4]), "int8", format!("[{d}]")),
            ("gamma_m", i8_bytes(&w[5]), "int8", format!("[{d}]")),
            ("wg_t", i8_bytes(&w[6]), "int8", format!("[{d}, {f}]")),
            ("wu_t", i8_bytes(&w[7]), "int8", format!("[{d}, {f}]")),
            ("wd_t", i8_bytes(&w[8]), "int8", format!("[{f}, {d}]")),
            ("exp", i64_bytes(&exp), "int64", "[256]".into()),
            ("act", i16_bytes(&act), "int16", "[256]".into()),
        ];
        let entries: Vec<String> = arrays
            .iter()
            .map(|(name, bytes, dtype, shape)| {
                std::fs::write(ldir.join(format!("{name}.bin")), bytes).unwrap();
                format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"{dtype}\", \"shape\": {shape}, \"sha256\": \"{}\"}}", hex(&sha256(bytes)))
            })
            .collect();
        let manifest = format!("{{\"layer\": {k}, \"constants\": {}, \"arrays\": {{{}}}}}\n", constants(&cal, sh.f_e, *es, silu), entries.join(", "));
        std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
        layer_objs.push(format!("{{\"layer\": {k}, \"dir\": \"layer_{k:02}\", \"manifest_sha256\": \"{}\"}}", hex(&sha256(manifest.as_bytes()))));
        let (xi, xo) = (i16_bytes(&x), i16_bytes(&x_out));
        for (name, b) in [(format!("x_in_L{k:02}"), &xi), (format!("x_out_L{k:02}"), &xo)] {
            std::fs::write(sdir.join(format!("{name}.bin")), b).unwrap();
            seq_arrays.push(format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"int16\", \"shape\": [{}, {}], \"sha256\": \"{}\"}}", sh.tokens, sh.width, hex(&sha256(b))));
        }
        x = x_out;
    }
    std::fs::write(sdir.join("manifest.json"), format!("{{\"kind\": \"sequence\", \"id\": \"s0\", \"T\": 32, \"arrays\": {{{}}}}}\n", seq_arrays.join(", "))).unwrap();
    let pc = constants(&cal, sh.f_e, 0, (-3, -11)).replace("\"silu_member\": [-3, -11]", "\"silu_member\": null").replace("\"exp_e_s\": 0", "\"exp_e_s\": null");
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"{variant}\", \"geometry\": \"rung-dd-t32-dev\", \"model\": {{\"repo\": \"synthetic/review-r9-dd-export\", \"revision\": \"review-r9\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"review-lane\", \"sha256\": {{\"review_r9_tests.rs\": \"{}\"}}}}, \"T\": 32, \"profile_constants\": {pc}, \"per_layer_constants_differ\": [\"exp_e_s\", \"silu_member\"], \"layers\": [{}], \"sequences\": [\"seq_s0\"]}}\n",
        hex(&sha256(b"review r9 synthetic dd words")),
        hex(&sha256(b"review r9 writer")),
        layer_objs.join(", ")
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
    vdir
}

fn id_of(stmt_dir: &Path) -> String {
    let s = std::fs::read_to_string(stmt_dir.join("statement.json")).unwrap();
    s.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string()
}

/// **E: the trained door and the CLI on DD-rung exports.**
#[test]
fn review_r9_e_the_trained_door_and_the_cli_on_dd_rung_exports() {
    let sh = dd_rung();
    let (hd, fe) = (sh.head_dim, sh.f_e);
    let fits: Vec<i32> = super::shape::TRAINED_EXP_E_S_RANGE.filter(|e| n_col(*e, hd, fe) <= DD_CAP).collect();
    let over: Vec<i32> = super::shape::TRAINED_EXP_E_S_RANGE.filter(|e| n_col(*e, hd, fe) > DD_CAP).collect();
    eprintln!("REVIEW-R9 E: at head_dim {hd}, f_e {fe}: e_s that fit cap {DD_CAP}: {fits:?}; over: {over:?} (n_col {:?})", super::shape::TRAINED_EXP_E_S_RANGE.map(|e| (e, n_col(e, hd, fe))).collect::<Vec<_>>());
    assert!(fits.len() >= 2 && over.contains(&0));
    let (g1, g2) = (fits[0], fits[1]);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let dir = super::trained_block_tests::base_dir("review-r9-dd");

    // (1) an over-cap layer: refused by name at the loader ...
    let vo = write_dd_export(&dir, "dd-over", &[g1, 0]);
    let ex = TrainedExport::load(&vo).expect("the over-cap export's manifests load");
    assert_eq!(ex.geometry, Geometry::RungDdDev);
    let c = ex.run_constants(&[0, 1]).unwrap();
    let shx = ex.shape_for(&c).unwrap();
    assert_eq!(shx.dd_cap, DD_CAP);
    ex.load_layer(&shx, &c, 0, false).expect("the in-cap layer loads");
    let e = ex.load_layer(&shx, &c, 1, false).err().expect("the over-cap layer was loaded");
    assert!(e.contains("layer 1 (exp_e_s 0)") && e.contains("D30 / B-8") && e.contains("cap of 32") && e.contains("before any header"), "{e}");
    eprintln!("REVIEW-R9 E loader refusal: {}", e.chars().take(260).collect::<String>());
    // ... and by every CLI command that would load it, leaving nothing behind
    let vod = vo.display().to_string();
    let voc = super::trained_block_tests::verifier_copy(&vo);
    let vocd = voc.display().to_string();
    let o = dir.join("over-run");
    let od = o.display().to_string();
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vod, "--seq", "s0", "--out", &od])), 1, "stack-prove took an over-cap layer");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vod, "--seq", "s0", "--out", &od, "--dd"])), 1, "stack-prove --dd took an over-cap layer");
    assert!(!o.exists() && !dir.join("over-run.unverified-statement").exists(), "a refused stack-prove wrote something");
    let o1 = dir.join("over-one");
    assert_eq!(trained_prove_command(&s(&["--export", &vod, "--layer", "1", "--seq", "s0", "--out", &o1.display().to_string()])), 1, "prove took an over-cap layer");
    assert!(!o1.exists());
    // the in-cap layer range of the same export proves and verifies (the door
    // is per layer)
    let o0 = dir.join("over-run-l0");
    let o0d = o0.display().to_string();
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vod, "--seq", "s0", "--out", &o0d, "--layers", "0..1"])), 0, "the in-cap layer range did not prove");
    let id0 = id_of(&dir.join("over-run-l0.unverified-statement"));
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vocd, "--artifact", &o0d, "--expect-statement", &id0, "--layers", "0..1"])), 0, "the in-cap layer range did not verify");
    // a verifier asked for every layer (the over-cap one included) refuses
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vocd, "--artifact", &o0d, "--expect-statement", &id0])), 1, "a verifier over the over-cap layer accepted");
    assert_eq!(trained_verify_command(&s(&["--export", &vocd, "--layer", "1", "--artifact", &o0d, "--expect-statement", &id0])), 1, "single-block verify loaded the over-cap layer");

    // (2) a two-layer in-cap DD export through the production CLI
    let vg = write_dd_export(&dir, "dd-good", &[g1, g2]);
    let vgd = vg.display().to_string();
    let vgc = super::trained_block_tests::verifier_copy(&vg);
    let vgcd = vgc.display().to_string();
    let r = dir.join("good-run");
    let rd = r.display().to_string();
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vgd, "--seq", "s0", "--out", &rd])), 0, "stack-prove of the in-cap DD export failed");
    let id = id_of(&dir.join("good-run.unverified-statement"));
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vgcd, "--artifact", &rd, "--expect-statement", &id, "--controls"])), 0, "stack-verify --controls failed");
    let stmt = std::fs::read_to_string(r.join("statement").join("statement.json")).unwrap();
    assert!(stmt.contains("\"run_profile\": \"hashline-zk-mr1/private-run-rung-dd-t32-dev/1\"") && stmt.contains("\"block_profile\": \"hashline-zk-mr1/private-block-rung-dd-t32-dev/1\"") && stmt.contains("\"blocks\": 2"), "{stmt}");
    // `--dd` names the same (DD-only) geometry: the byte check passes
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vgcd, "--artifact", &rd, "--expect-statement", &id, "--dd"])), 0, "stack-verify --dd on a DD-rung run failed");
    // a wrong pin refuses
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vgcd, "--artifact", &rd, "--expect-statement", &hex(&sha256(b"x"))])), 1);
    // single block, with the prover's inconsistent-witness controls and the
    // verifier's controls
    let sb = dir.join("good-one");
    let sbd = sb.display().to_string();
    assert_eq!(trained_prove_command(&s(&["--export", &vgd, "--layer", "1", "--seq", "s0", "--out", &sbd, "--controls", "--dd"])), 0, "single-block DD prove (with controls) failed");
    let sid = id_of(&sb);
    assert_eq!(trained_verify_command(&s(&["--export", &vgcd, "--layer", "1", "--artifact", &sbd, "--expect-statement", &sid, "--controls"])), 0, "single-block DD verify (with controls) failed");
    assert_eq!(trained_verify_command(&s(&["--export", &vgcd, "--layer", "0", "--artifact", &sbd, "--expect-statement", &sid])), 1, "layer 1's receipt verified as layer 0");
    eprintln!("REVIEW-R9 E: over-cap refused at the loader and by stack-prove / prove / stack-verify / verify; the in-cap range proved and verified; the in-cap DD export: stack {id}, single block {sid}");
}

// ------------------------------------------------------------------ F

/// **F: `Geometry::dd`** maps exactly the three DD geometries and refuses
/// every other one by name.
#[test]
fn review_r9_f_geometry_dd_refuses_every_geometry_without_a_dd_profile() {
    for g in [Geometry::TinyLlama(32), Geometry::TinyLlama(64), Geometry::Llama3_8B(32), Geometry::Llama3_8B(64), Geometry::RungTcDev] {
        let e = g.dd().expect_err("a geometry with no DD profile was mapped");
        assert!(e.contains("DD (D30) is registered only"), "{e}");
        assert!(!g.is_dd());
    }
    assert_eq!(Geometry::TinyLlama(128).dd().unwrap(), Geometry::TinyLlamaDd);
    assert_eq!(Geometry::Llama3_8B(128).dd().unwrap(), Geometry::Llama3_8BDd);
    assert_eq!(Geometry::RungDdDev.dd().unwrap(), Geometry::RungDdDev);
    for g in [Geometry::TinyLlamaDd, Geometry::Llama3_8BDd, Geometry::RungDdDev] {
        assert!(g.is_dd());
        assert_eq!(g.dd().unwrap(), g);
    }
    assert!(!Geometry::TinyLlama(128).is_dd() && !Geometry::Llama3_8B(128).is_dd());
}
