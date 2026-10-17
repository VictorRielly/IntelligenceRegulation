//! **NATIVE LANE (2026-10-17): THE TRAINED NORM CALIBRATION — T2 and T3.**
//! TEST CODE ONLY.
//!
//! What is pinned here:
//!
//! * the VALIDATOR (`NormCalibration::derive_at_width`): `D_max` uses the
//!   signed-int16 endpoint 32768 and the declared `Ceps`; the window
//!   `tn + 1 + bits(D_max)` must be exactly four byte limbs; it COMPUTES the
//!   largest admissible `tn` per width (10 at 2048, 9 at 4096) and refuses
//!   rather than hard-codes; every coefficient is inside its declared class;
//! * the FROZEN profiles do not move: no registered shape carries a trained
//!   calibration and every one prints the frozen calibration line;
//! * the BINDING: every one of `tn`, `cn_a`, `cn_m`, `ceps`, `sh_ao` moves
//!   the schedule digest (absorbed by every transcript), and a verifier whose
//!   profile carries any other value REFUSES an honest receipt;
//! * a GENERIC HONEST WITNESS (dense public weights, heads that differ, a
//!   generic hidden input, non-toy constants) is admissible, equals the
//!   independent shape-driven kernel plane for plane, proves and verifies
//!   from bytes — at a small trained rung in the ordinary filter, and at the
//!   TRUE TinyLlama T32 geometry as `#[ignore]`d heavy tests run in release;
//! * inconsistent-witness controls: a witness that is honest under OTHER
//!   constants (including `tn` halved with `Cn` halved, the same real-valued
//!   multiplier) is rejected under the declared ones.
//!
//! **Capture rule.** Everything here is public synthetic test data from
//! fixed-seed integer streams. Only counts, maxima of synthetic planes, sizes,
//! times and memory marks are printed. No privacy claim is made: D22 covers
//! only the toy.

use super::layout::*;
use super::shape::{NormCalibration, Shape, TINYLLAMA_T32_TRAINED_PROFILE, TRAINED_CALIBRATION_PROFILES, TRAINED_CALIB_RUNG_PROFILE};
use super::witness::{self, Witness};
use super::*;

// ------------------------------------------------------------- the constants

/// **T3's calibration** (orchestrator: `tn = 10`, multipliers like
/// 2672 / 4315, a large `Ceps`). `Ceps = 129,746,337` is of the order the
/// calibration measured (about 1.3e8) and deliberately not a power of two.
pub(super) fn t3_calibration() -> NormCalibration {
    NormCalibration { tn: 10, cn_a: 2672, cn_m: 4315, ceps: 129_746_337, sh_ao: 7, ..NormCalibration::FROZEN }
}

/// **ROUND 2: the pg_rot1 export's ONE profile calibration** (`export/
/// pg_rot1_export_T32/profile.json`): `Cn_a 3999`, `Cn_m 3122`, `Ceps 91255`
/// and the shifts QKV 8 / score 6 / O 9 / AO 3 / gate 8 / product 14 / down 5.
pub(super) fn pg_calibration() -> NormCalibration {
    NormCalibration { tn: 10, cn_a: 3999, cn_m: 3122, ceps: 91_255, sh_ao: 3, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 5 }
}

/// the trained-calibration development rung's calibration: `tn = 10` (window
/// 31 at width 384, so the top-limb `scaled` lookup is live, unlike
/// TinyLlama's C-6 window of 32), two different multipliers, a large `Ceps`
/// and `sh_ao = 6` (the AO remainder's `scaled` coefficient becomes 4)
pub(super) fn rung_tc_calibration() -> NormCalibration {
    // ROUND 2: every windowed shift off its frozen value (frozen 7/6/9/7/14/6)
    NormCalibration { tn: 10, cn_a: 1336, cn_m: 2158, ceps: 33_554_467, sh_ao: 6, sh_qkv: 8, sh_s: 5, sh_o: 10, sh_g: 8, sh_h: 13, sh_z: 5 }
}

/// the TinyLlama softmax table bits of T3 (two `sigma_s` limbs at T32)
pub(super) const T3_F_E: u32 = 9;

/// **The trained-dense recipe's bands.** The dense recipe of `dense_tests`
/// was sized for the frozen multiplier `1024 / 2^11 = 1/2`; at T3's 2.6 and
/// 4.2 its norm outputs are five to eight times larger, so the attention and
/// gate bands that keep every class in range are narrower. The numbers are a
/// fixed part of the recipe (chosen once by `native_probe_the_trained_dense_bands`
/// and asserted admissible by the tests that use them).
#[derive(Clone, Copy, Debug)]
pub(super) struct Bands {
    pub attn: i64,
    pub gate: i64,
    pub down: i64,
    pub gains: (i64, i64),
    pub xmag: i64,
}

/// Chosen from the probe of 2026-10-17 (`t3-probe-bands.log`): at the
/// TinyLlama trained shape attn 8 / gate 12 gives max|q8| 43, max|s8| 42,
/// max|g8| 100, max|x2| 9,374 — every class used, none saturated (attn 16
/// refuses at the score, gate 16 at the gate); at the trained rung the same
/// bands give max|s8| 8, max|g8| 43.
pub(super) const TRAINED_BANDS: Bands = Bands { attn: 8, gate: 12, down: 2, gains: (40, 127), xmag: 6_000 };

/// the trained-dense case at a shape: dense public words (every entry
/// nonzero), the generic hidden input of `dense_tests`, and the public
/// statement of those words
pub(super) fn trained_dense_words(sh: &Shape, b: Bands) -> ([Vec<i8>; 9], Vec<i16>) {
    super::dense_tests::dense_words_with(sh, b.attn, b.gate, b.down, b.gains, b.xmag)
}

pub(super) fn trained_dense_block_with(sh: &Shape, b: Bands) -> (BlockPublic, Vec<i16>) {
    let (w, input) = trained_dense_words(sh, b);
    let (public, ff) = super::dense_tests::statement_of_words(sh, &w);
    (BlockPublic::new(public, ff), input)
}

pub(super) fn trained_dense_block(sh: &Shape) -> (BlockPublic, Vec<i16>) {
    trained_dense_block_with(sh, TRAINED_BANDS)
}

fn rung_tc() -> Shape {
    Shape::rung_tc(&rung_tc_calibration()).expect("the trained-calibration rung")
}

fn tinyllama() -> Shape {
    Shape::tinyllama_t32_trained(&t3_calibration(), T3_F_E).expect("the trained TinyLlama shape")
}

/// ROUND 3 (R3-2): the trained TinyLlama shape at another registered T
pub(super) fn tinyllama_at(t: usize) -> Shape {
    Shape::tinyllama_trained(t, &t3_calibration(), T3_F_E).expect("the trained TinyLlama shape at T")
}

/// the five single-constant variations of a calibration
fn variations(c: NormCalibration) -> Vec<(&'static str, NormCalibration)> {
    vec![
        ("tn - 1", NormCalibration { tn: c.tn - 1, ..c }),
        ("cn_a + 1", NormCalibration { cn_a: c.cn_a + 1, ..c }),
        ("cn_m + 1", NormCalibration { cn_m: c.cn_m + 1, ..c }),
        ("ceps + 1", NormCalibration { ceps: c.ceps + 1, ..c }),
        ("sh_ao moved by one", NormCalibration { sh_ao: nudge(c.sh_ao, 0, 8), ..c }),
        // ROUND 2: each windowed shift moved by one, inside its window
        // (ROUND 4: toward the inside when it sits at a window edge, as the
        // 8B calibration's sh_h = 16 does)
        ("sh_qkv moved by one", NormCalibration { sh_qkv: nudge_down(c.sh_qkv, 1, 8), ..c }),
        ("sh_s moved by one", NormCalibration { sh_s: nudge(c.sh_s, 1, 8), ..c }),
        ("sh_o moved by one", NormCalibration { sh_o: nudge(c.sh_o, 9, 16), ..c }),
        ("sh_g moved by one", NormCalibration { sh_g: nudge_down(c.sh_g, 1, 8), ..c }),
        ("sh_h moved by one", NormCalibration { sh_h: nudge(c.sh_h, 9, 16), ..c }),
        ("sh_z moved by one", NormCalibration { sh_z: nudge(c.sh_z, 1, 8), ..c }),
    ]
}

/// one step up inside `lo..=hi`, or down at the top
fn nudge(v: u32, lo: u32, hi: u32) -> u32 {
    if v < hi {
        v + 1
    } else {
        assert!(v > lo);
        v - 1
    }
}

/// one step down inside `lo..=hi`, or up at the bottom
fn nudge_down(v: u32, lo: u32, hi: u32) -> u32 {
    if v > lo {
        v - 1
    } else {
        assert!(v < hi);
        v + 1
    }
}

// ------------------------------------------------------------- T2: validator

/// The validator computes the admissible `tn` per width and refuses outside
/// the class, by name.
#[test]
fn the_validator_computes_tn_from_the_width_and_refuses_outside_the_class() {
    for ceps in [1i64, 129_746_337, 1 << 40] {
        assert_eq!(NormCalibration::max_tn_at_width(2048, ceps), 10, "width 2048, ceps {ceps}");
        assert_eq!(NormCalibration::max_tn_at_width(4096, ceps), 9, "width 4096, ceps {ceps}");
    }
    assert_eq!(NormCalibration::max_tn_at_width(384, 33_554_467), 11);
    let ok = |w: usize, c: NormCalibration| c.derive_at_width(w);
    let base = t3_calibration();
    // width 2048: tn 10 is a 32-bit window, tn 11 needs a fifth limb
    let (dmax, wrho) = ok(2048, base).expect("tn 10 at width 2048");
    assert_eq!((dmax, wrho), (1_482_954, 32), "D_max = isqrt(129,746,337 + 2048 * 32768^2)");
    assert_eq!(dmax, crate::private_block::witness::isqrt(129_746_337 + 2048 * 32768 * 32768) as i128);
    assert!(ok(2048, NormCalibration { tn: 11, ..base }).unwrap_err().contains("exceeds four byte limbs"));
    // width 4096 (the later 8B): the same rule gives tn 9
    assert_eq!(ok(4096, NormCalibration { tn: 9, ..base }).expect("tn 9 at width 4096").1, 32);
    assert!(ok(4096, NormCalibration { tn: 10, ..base }).is_err(), "tn 10 at width 4096 must be refused (window 33)");
    // the signed-int16 endpoint: at width 4096 and the smallest Ceps, D_max is
    // exactly 2^21 — 22 bits — which the old 32767 formula would have missed
    assert_eq!(ok(4096, NormCalibration { tn: 9, ceps: 1, ..base }).unwrap().0, 1 << 21);
    // the class
    for (name, c) in [
        ("tn 0", NormCalibration { tn: 0, ..base }),
        ("tn 17", NormCalibration { tn: 17, ..base }),
        ("cn_a 0", NormCalibration { cn_a: 0, ..base }),
        ("cn_m 2^20 + 1", NormCalibration { cn_m: (1 << 20) + 1, ..base }),
        ("ceps 0", NormCalibration { ceps: 0, ..base }),
        ("ceps 2^40 + 1", NormCalibration { ceps: (1 << 40) + 1, ..base }),
        ("sh_ao 9", NormCalibration { sh_ao: 9, ..base }),
        ("tn 1: a three-limb window", NormCalibration { tn: 1, ..base }),
        // ROUND 2: the structure-preserving shift windows
        ("sh_qkv 0", NormCalibration { sh_qkv: 0, ..base }),
        ("sh_qkv 9", NormCalibration { sh_qkv: 9, ..base }),
        ("sh_s 9", NormCalibration { sh_s: 9, ..base }),
        ("sh_g 0", NormCalibration { sh_g: 0, ..base }),
        ("sh_z 9", NormCalibration { sh_z: 9, ..base }),
        ("sh_o 8 (one limb)", NormCalibration { sh_o: 8, ..base }),
        ("sh_o 17", NormCalibration { sh_o: 17, ..base }),
        ("sh_h 8 (one limb)", NormCalibration { sh_h: 8, ..base }),
        ("sh_h 17", NormCalibration { sh_h: 17, ..base }),
    ] {
        assert!(ok(2048, c).is_err(), "{name} was accepted");
    }
    assert!(ok(4097, NormCalibration { tn: 9, ..base }).is_err(), "width 4097 is outside the class");
    // the edges of the class are accepted
    for c in [
        NormCalibration { cn_a: 1, cn_m: 1 << 20, ceps: 1 << 40, sh_ao: 0, ..base },
        NormCalibration { sh_ao: 8, ..base },
        NormCalibration { sh_qkv: 1, sh_s: 1, sh_g: 1, sh_z: 1, sh_o: 9, sh_h: 9, ..base },
        NormCalibration { sh_qkv: 8, sh_s: 8, sh_g: 8, sh_z: 8, sh_o: 16, sh_h: 16, ..base },
        pg_calibration(),
    ] {
        ok(2048, c).expect("an edge of the class");
    }
}

/// The trained door refuses every frozen profile, a second application and a
/// window override; it accepts only the two trained-calibration profiles.
#[test]
fn the_trained_door_refuses_every_frozen_profile() {
    let c = t3_calibration();
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()] {
        let e = sh.clone().with_trained_calibration(&c).expect_err(&format!("{} accepted a trained calibration", sh.name));
        assert!(e.contains("is frozen"), "{}: {e}", sh.name);
        assert!(!sh.trained_calibration && sh.norm_calibration() == NormCalibration::FROZEN, "{}: a registered shape carries a non-frozen calibration", sh.name);
    }
    assert_eq!(TRAINED_CALIBRATION_PROFILES, [TINYLLAMA_T32_TRAINED_PROFILE, TRAINED_CALIB_RUNG_PROFILE, super::shape::TINYLLAMA_T64_TRAINED_PROFILE, super::shape::TINYLLAMA_T128_TRAINED_PROFILE, super::shape::LLAMA3_8B_T32_TRAINED_PROFILE]);
    // ROUND 3 (R3-2): one profile per context length; any other T is refused
    for t in [16usize, 48, 256, 512] {
        assert!(Shape::tinyllama_trained(t, &c, T3_F_E).unwrap_err().contains("no trained TinyLlama profile"), "T{t}");
    }
    let (s64, s128) = (tinyllama_at(64), tinyllama_at(128));
    assert_eq!((s64.log_cols, s64.endpoint_rows, s64.wrho_s), (13, 21, 15));
    assert_eq!((s128.log_cols, s128.endpoint_rows, s128.wrho_s), (14, 21, 16));
    assert_eq!(tinyllama().profile, TINYLLAMA_T32_TRAINED_PROFILE);
    let t = tinyllama();
    assert!(t.clone().with_trained_calibration(&c).unwrap_err().contains("once"), "a second application was accepted");
    // a TinyLlama-profile shape built with a window override is refused
    let over = Shape::new("override", TINYLLAMA_T32_TRAINED_PROFILE, 32, 2048, 5632, 32, 64, 4, 12, 4, 9, 21, None, None, Some(32), None).expect("constructs");
    assert!(over.with_trained_calibration(&c).unwrap_err().contains("override"));
    // and a shape whose fields were changed WITHOUT the door has no layout
    let mut sneaky = Shape::rung_c6();
    sneaky.norm_cn_a = 2048;
    assert!(Layout::for_shape(&sneaky).err().expect("refused").contains("without the trained door"));
}

/// Every registered (frozen) profile prints the frozen calibration line,
/// byte for byte the literal; the trained profiles print their own.
#[test]
fn the_frozen_profiles_print_the_frozen_calibration_line() {
    let frozen = |sh: &Shape| {
        format!(
            "calibration: norm tn=11 cn=1024 ceps=1 wrho={}; shifts qkv=7 rope=7 score=6 o=9 ao=7 residual=0; fE={} fP=9 fRo=7 wrhoS={} mask=-127; classes int8=[-127,127] int16; tables U8 + exp",
            sh.norm_wrho, sh.f_e, sh.wrho_s
        )
    };
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()] {
        let lines = Layout::for_shape(&sh).unwrap().describe();
        assert_eq!(lines[4], frozen(&sh), "{}: the calibration line moved", sh.name);
    }
    let t = tinyllama();
    let line = Layout::for_shape(&t).unwrap().describe()[4].clone();
    assert_eq!(
        line,
        "calibration: trained norm tn=10 cn_a=2672 cn_m=4315 ceps=129746337 ao=7 qkv=7 score=6 o=9 gate=7 product=14 down=6 wrho=32 dmax=1482954 int16-endpoint=32768; shifts qkv=7 rope=7 score=6 o=9 ao=7 residual=0; fE=9 fP=9 fRo=7 wrhoS=14 mask=-127; classes int8=[-127,127] int16; tables U8 + exp"
    );
    // ROUND 2: the pg calibration's shifts reach both the calibration and the
    // feed-forward lines
    let p = Shape::tinyllama_t32_trained(&pg_calibration(), T3_F_E).unwrap();
    let lines = Layout::for_shape(&p).unwrap().describe();
    assert!(lines[4].contains("ao=3 qkv=8 score=6 o=9 gate=8 product=14 down=5") && lines[4].contains("shifts qkv=8 rope=7 score=6 o=9 ao=3"), "{}", lines[4]);
    assert!(lines[5].contains("shifts gate=8 up=0 product=14 down=5"), "{}", lines[5]);
    assert!(super::protocol::parameter_line(&p).contains("/sh-g8-u0-h14-z5/"));
}

/// **THE BINDING at the schedule level.** Each single-constant variation of
/// the calibration gives a different schedule digest (which every block and
/// run transcript absorbs), at both trained shapes.
#[test]
fn every_trained_constant_moves_the_schedule_digest() {
    for (base, mk) in [(t3_calibration(), (|c: &NormCalibration| Shape::tinyllama_t32_trained(c, T3_F_E)) as fn(&NormCalibration) -> Result<Shape, String>), (rung_tc_calibration(), |c: &NormCalibration| Shape::rung_tc(c))] {
        let sh = mk(&base).unwrap();
        let mut digests = vec![Layout::for_shape(&sh).unwrap().schedule_digest()];
        for (name, v) in variations(base) {
            let s2 = mk(&v).unwrap_or_else(|e| panic!("{}: variation {name} does not construct: {e}", sh.name));
            digests.push(Layout::for_shape(&s2).unwrap().schedule_digest());
        }
        let n = digests.len();
        digests.sort();
        digests.dedup();
        assert_eq!(digests.len(), n, "{}: two calibrations share a schedule digest", sh.name);
    }
}

/// The trained TinyLlama shape's counted layout equals the lane-C dev
/// shape's (same plane list: both are four norm limbs with C-6), and its
/// window is the DERIVED 32 — complete for every int16 input — where the dev
/// shape's was an override at `tn = 11` that refused honest rows above RMS
/// 23,170.
#[test]
fn the_trained_tinyllama_shape_has_the_derived_window_and_the_dev_counts() {
    let t = tinyllama();
    assert_eq!((t.norm_wrho, t.limbs_norm(), t.norm_top_is_full_byte(), t.wrho_s, t.limbs_sigma_s()), (32, 4, true, 14, 2));
    assert_eq!((t.d_pad, t.h_pad, t.f_pad, t.t_pad), (2048, 32, 8192, 32));
    let tt = t.totals();
    let lay = Layout::for_shape(&t).expect("the trained layout");
    assert_eq!((lay.a_rows, lay.h_rows), (tt.a_rows, tt.h_rows));
    let d = Shape::tinyllama_t32_dev().totals();
    assert_eq!((tt.a_rows, tt.h_rows, tt.receipt_bytes.total), (d.a_rows, d.h_rows, d.receipt_bytes.total), "the trained and dev plane lists differ");
    assert_eq!((tt.a_rows, tt.h_rows, tt.receipt_bytes.total), (1729, 1798, 11_627_208));
    assert!(!t.hashes_under_the_legacy_rule(), "a new profile is tagged (D19a)");
    eprintln!("NATIVE trained TinyLlama T32: A {} rows, H {} rows, M 50, receipt {} B, u8 lookups {}", tt.a_rows, tt.h_rows, tt.receipt_bytes.total, tt.u8_lookups);
}

/// **COUNTED LAYOUTS, T32..T512, at the trained TinyLlama geometry** (no
/// proof: rows, receipt bytes and lookups only; peak memory is NOT counted by
/// the shape code). Every admissible row width per token count is reported;
/// a token count with none is reported with the refusal.
#[test]
fn the_trained_tinyllama_counted_layout_ladder() {
    let c = t3_calibration();
    for t in [32usize, 64, 128, 256, 512] {
        let mut any = false;
        for lc in 10..=16 {
            match Shape::tinyllama_trained_ladder(t, lc, &c, T3_F_E) {
                Ok(sh) => match Layout::for_shape(&sh) {
                    Ok(lay) => {
                        let tt = sh.totals();
                        assert_eq!((lay.a_rows, lay.h_rows), (tt.a_rows, tt.h_rows));
                        any = true;
                        eprintln!(
                            "NATIVE LADDER T{t} log_cols {lc}: A {} rows, H {} rows, endpoint rows {}, receipt {} B, u8 lookups {}, wrho_s {} ({} limbs)",
                            tt.a_rows,
                            tt.h_rows,
                            sh.endpoint_rows,
                            tt.receipt_bytes.total,
                            tt.u8_lookups,
                            sh.wrho_s,
                            sh.limbs_sigma_s()
                        );
                    }
                    Err(e) => eprintln!("NATIVE LADDER T{t} log_cols {lc}: layout refused: {e}"),
                },
                Err(e) => eprintln!("NATIVE LADDER T{t} log_cols {lc}: shape refused: {}", e.chars().take(160).collect::<String>()),
            }
        }
        assert!(any || t > 32, "T32 must have a layout");
    }
    // ROUND 2 (R2-5): T512 at row width 2^14 counts over the 64 MiB ceiling
    // of the development profiles and fits the trained profiles' own
    let big = Shape::tinyllama_trained_ladder(512, 14, &c, T3_F_E).unwrap();
    let n = big.receipt_bytes().total;
    assert!(n > super::wire::MAX_WIRE_BYTES_ANY && n <= super::wire::wire_ceiling(&big), "T512 lc14: {n} B");
    assert_eq!(super::wire::wire_ceiling(&Shape::m125()), super::wire::MAX_WIRE_BYTES_ANY, "a development profile's ceiling moved");
}

// ------------------------------------------------- T3: the generic witness

fn upper_fraction(sh: &Shape, plane: &[i64]) -> f64 {
    let (d, f, fp) = (sh.width, sh.hidden, sh.f_pad);
    let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| plane[*i] != 0).count();
    live as f64 / (sh.tokens * (f - d)) as f64
}

fn max_abs(v: &[i64]) -> i64 {
    v.iter().map(|x| x.abs()).max().unwrap_or(0)
}

/// Build the trained-dense witness at `sh`, check every relation the pad
/// module can check, assert it is GENERIC (dense, heads differ, the upper
/// hidden half live, norm outputs not saturated nor trivially small) and
/// compare it plane for plane with the independent shape-driven kernel.
pub(super) fn generic_witness(sh: &Shape) -> (BlockPublic, Vec<i16>, Witness) {
    generic_witness_with(sh, TRAINED_BANDS)
}

/// the same at other dense bands (ROUND 4: the 8B geometry's own bands)
pub(super) fn generic_witness_with(sh: &Shape, bands: Bands) -> (BlockPublic, Vec<i16>, Witness) {
    let (w, input) = trained_dense_words(sh, bands);
    let (public, ff) = super::dense_tests::statement_of_words(sh, &w);
    let t0 = std::time::Instant::now();
    let wit = witness::build_shaped(sh, &public, &ff, &input).unwrap_or_else(|m| panic!("{}: the trained-dense recipe is not admissible: {m}", sh.name));
    let built = t0.elapsed().as_secs_f64();
    let ids = Ids::new(sh).unwrap();
    assert!(super::pad::every_checkable_relation_holds(sh, &ids, &wit), "{}: the trained-dense witness is inconsistent", sh.name);
    // GENERIC: heads differ (query heads, and the key-value heads the S19-F1
    // repair is about), the upper hidden half is live, the norms are used
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    let k8 = &wit.planes[ids.at(A_K8)];
    let kv_head = |h: usize| -> Vec<i64> { (0..sh.tokens).flat_map(|t| (0..dh).map(move |i| t * kvw + h * dh + i)).map(|i| k8[i]).collect() };
    for h in 1..sh.kv_heads {
        assert_ne!(kv_head(0), kv_head(h), "{}: key-value heads 0 and {h} carry the same keys", sh.name);
    }
    let q8 = &wit.planes[ids.at(A_Q8)];
    let q_head = |h: usize| -> Vec<i64> { let sl = sh.head_slot(h); (0..sh.tokens).flat_map(|t| (0..dh).map(move |i| t * sh.d_pad + sl * dh + i)).map(|i| q8[i]).collect() };
    assert_ne!(q_head(0), q_head(1), "{}: query heads 0 and 1 are equal", sh.name);
    let (ya, ym) = (max_abs(&wit.planes[ids.at(A_Y)]), max_abs(&wit.planes[ids.at(A_YM)]));
    assert!(ya >= 8 && ym >= 8, "{}: the norm outputs are trivially small ({ya}, {ym})", sh.name);
    let (ug, ua) = (upper_fraction(sh, &wit.planes[ids.at(A_G8)]), upper_fraction(sh, &wit.planes[ids.at(A_A16)]));
    assert!(ug > 0.5 && ua > 0.5, "{}: the upper hidden half is not live ({ug:.2}, {ua:.2})", sh.name);
    eprintln!(
        "NATIVE generic witness at {}: built in {built:.2} s; max|y_a| {ya} max|y_m| {ym} max|q8| {} max|s8| {} max|g8| {} max|u16| {} max|z16| {} max|x2| {}; upper half gate {:.1}% act {:.1}% nonzero",
        sh.profile,
        max_abs(q8),
        max_abs(&wit.planes[ids.at(A_S8)]),
        max_abs(&wit.planes[ids.at(A_G8)]),
        max_abs(&wit.planes[ids.at(A_U16)]),
        max_abs(&wit.planes[ids.at(A_Z16)]),
        max_abs(&wit.planes[ids.at(A_X2)]),
        100.0 * ug,
        100.0 * ua
    );
    // INDEPENDENT REFERENCE: the shape-driven kernel, at the same calibration
    let case = super::parity::shaped_case_from_words(sh, w, input.clone());
    let (kres, tbuf) = super::parity::run_kernel_shaped(sh, &case);
    let kout = kres.unwrap_or_else(|e| panic!("{}: the reference kernel refuses the case the witness accepts: {e}", sh.name));
    super::parity::compare_shaped(sh, &wit, &tbuf, 0);
    let wout: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| wit.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect();
    assert_eq!(wout, kout, "{}: the block outputs of the witness and the kernel differ", sh.name);
    // and the kernel at the FROZEN calibration computes something else, so
    // the calibration is live in both implementations
    let frozen_case = super::parity::shaped_case_from_words(sh, trained_dense_words(sh, bands).0, input.clone());
    let fk = super::parity::kernel_shape(sh).with_norm_calibration(11, 1024, 1024, 1, 7);
    let mut scratch = vec![0i64; fk.scratch_len()];
    let mut out = vec![0i16; fk.x_len()];
    let fr = private_block_kernel_shaped::run_shaped(&fk, &frozen_case.input, &frozen_case.weights(), &frozen_case.tables(), &mut scratch, None, &mut out);
    assert!(fr.is_err() || out != kout, "{}: the frozen and trained calibrations compute the same block", sh.name);
    (BlockPublic::new(public, ff), input, wit)
}

fn plane16(w: &Witness, p: usize) -> Vec<i16> {
    w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect()
}

fn ctx_t3() -> Digest {
    *blake3::hash(b"native lane T3: trained calibration, dense synthetic").as_bytes()
}

// ---- ROUND 2, R2-4: a trained-calibration block proves only inside a run
// BOUND to its trained-model statement. These helpers prove and verify ONE
// block that way, with a statement that says honestly that its words are a
// public synthetic recipe (the test-only constructor waives the production
// rule that refuses a synthetic recipe at the TinyLlama trained profile).

/// the run shape of a one-block run at a trained-calibration shape
pub(super) fn run_shape_for(sh: &Shape, l: usize) -> super::run::RunShape {
    // ROUND 4: every trained-model profile (TinyLlama, Llama-3-8B) has its
    // own run profile; the development rung its own
    if sh.profile == super::shape::TRAINED_CALIB_RUNG_PROFILE {
        super::run::RunShape::rung_tc(sh.clone(), l).unwrap()
    } else {
        super::run::RunShape::tinyllama_trained(sh.clone(), l).unwrap()
    }
}

/// the synthetic-recipe trained-model statement of these blocks at `sh`
pub(super) fn synthetic_statement(sh: &Shape, blocks: &[BlockPublic]) -> super::trained_statement::TrainedModelStatement {
    use super::trained_statement::*;
    let src = ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/private-block/trained-dense".into(),
        revision: "native-round-2".into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: blocks.len() as u32,
    };
    let mut prov = Provenance::recipe("native/synthetic", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = super::shape::trained_rope_theta(sh.profile).unwrap_or(prov.rope_theta);
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    let recs = blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    let rp = run_shape_for(sh, 1).profile;
    TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, rp, src, cal, recs).expect("the synthetic trained-model statement")
}

/// One proved one-block bound run: its endpoint policy and its segment.
pub(super) struct BoundOne {
    pub expected: ExpectedIo,
    pub seg: Vec<u8>,
}

/// the run statement a verifier at `sh` builds for one block (its own
/// statement, its own expected policy rebuilt from the bytes)
pub(super) fn bound_statement(sh: &Shape, blk: &BlockPublic, expected_bytes: &[u8]) -> Result<super::run::RunStatement, String> {
    let e = ExpectedIo::from_bytes_at(sh, expected_bytes)?;
    let blocks = vec![blk.clone()];
    super::run::RunStatement::new_bound(run_shape_for(sh, 1), ctx_t3(), e, &blocks, &[(0, 0)], &synthetic_statement(sh, &blocks))
}

struct OneWitness(Option<Witness>);

impl super::run::RunWitnessSource for OneWitness {
    fn witness(&mut self, _k: usize) -> Result<Witness, String> {
        self.0.take().ok_or_else(|| "the one witness was already consumed".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("a one-block run has no internal boundary".into())
    }
}

/// prove ONE block at `sh` as a bound one-block run (the endpoint owner
/// commits the witness's own input and output planes); no verification
pub(super) fn prove_one_bound(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<BoundOne, String> {
    let ids = Ids::new(sh)?;
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).unwrap_or(0)).collect() };
    let spec = IoSpec::new_shaped(sh, ctx_t3(), 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2)))?;
    let blocks = vec![blk.clone()];
    let st = bound_statement(sh, blk, &expected.to_bytes())?;
    let mut segs: Vec<Vec<u8>> = Vec::new();
    super::run::prove_run(&st, &blocks, &mut OneWitness(Some(w)), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(BoundOne { expected, seg: segs.pop().ok_or("no segment")? })
}

/// verify a one-block bound run's segment at `sh` (a verifier's own shape)
pub(super) fn verify_one_bound(sh: &Shape, blk: &BlockPublic, expected_bytes: &[u8], seg: &[u8]) -> Result<(), String> {
    let st = bound_statement(sh, blk, expected_bytes)?;
    super::run::verify_run(&st, &[blk.clone()], &[seg.to_vec()])
}

/// prove one block at `sh` as a bound run and verify it; returns the policy,
/// the segment and the prove seconds
pub(super) fn prove_bytes(sh: &Shape, blk: &BlockPublic, w: Witness) -> (ExpectedIo, Vec<u8>, f64) {
    let t0 = std::time::Instant::now();
    let b = prove_one_bound(sh, blk, w).expect("the honest block proves as a bound one-block run");
    let s = t0.elapsed().as_secs_f64();
    verify_one_bound(sh, blk, &b.expected.to_bytes(), &b.seg).expect("the bound one-block run verifies");
    (b.expected, b.seg, s)
}

/// The tamper controls a trained block must pass: a verifier configured
/// with any other `tn`, `Cn_a`, `Cn_m`, `Ceps`, `sh_ao` or windowed shift
/// refuses; a truncated or mutated segment refuses; and (R2-4) the
/// single-block path refuses the shape outright.
pub(super) fn coefficient_and_receipt_controls(sh: &Shape, mk: &dyn Fn(&NormCalibration) -> Result<Shape, String>, blk: &BlockPublic, expected: &ExpectedIo, bytes: &[u8]) {
    let eb = expected.to_bytes();
    verify_one_bound(sh, blk, &eb, bytes).expect("the honest segment verifies");
    for (name, v) in variations(sh.norm_calibration()) {
        let other = mk(&v).unwrap_or_else(|e| panic!("variation {name}: {e}"));
        let e = verify_one_bound(&other, blk, &eb, bytes).expect_err(&format!("{}: a verifier with {name} ACCEPTED the segment", sh.name));
        eprintln!("NATIVE control at {}: verifier with {name} refuses: {}", sh.profile, e.chars().take(100).collect::<String>());
    }
    assert!(verify_one_bound(sh, blk, &eb, &bytes[..bytes.len() - 1]).is_err(), "a truncated segment was accepted");
    for at in [bytes.len() / 3, bytes.len() / 2, bytes.len() - 9] {
        let mut bad = bytes.to_vec();
        bad[at] ^= 0x10;
        assert!(verify_one_bound(sh, blk, &eb, &bad).is_err(), "a segment mutated at byte {at} was accepted");
    }
    // R2-4: no single-block receipt at a trained profile, either direction
    let e = verify_bytes_at(sh, blk, expected, bytes).expect_err("the single-block verifier accepted a trained-profile frame");
    assert!(e.contains("R2-4"), "{e}");
}

/// An inconsistent witness: honest under OTHER constants, proved under the
/// declared ones. Includes `tn - 1` with both `Cn` halved — the same real
/// multiplier `Cn / 2^tn`, so the quotients mostly agree and only the
/// remainders and denominators differ — and (round 2) a witness honest under
/// another down shift.
pub(super) fn inconsistent_witness_controls(sh: &Shape, mk: &dyn Fn(&NormCalibration) -> Result<Shape, String>, blk: &BlockPublic, input: &[i16]) {
    let c = sh.norm_calibration();
    let others = [
        ("tn - 1 with both Cn halved", NormCalibration { tn: c.tn - 1, cn_a: c.cn_a / 2, cn_m: c.cn_m / 2, ..c }),
        ("cn_m + 7", NormCalibration { cn_m: c.cn_m + 7, ..c }),
        ("ceps x 4", NormCalibration { ceps: c.ceps * 4, ..c }),
        ("sh_z - 1", NormCalibration { sh_z: c.sh_z - 1, ..c }),
    ];
    let mut rejected = 0usize;
    for (name, v) in others {
        let other = mk(&v).unwrap();
        let w = match witness::build_shaped(&other, blk.attention(), blk.feed_forward(), input) {
            Ok(w) => w,
            Err(e) => {
                eprintln!("NATIVE inconsistent witness at {} ({name}): the other-constant witness itself refuses ({e}); skipped", sh.profile);
                continue;
            }
        };
        let verdict = prove_one_bound(sh, blk, w).and_then(|b| verify_one_bound(sh, blk, &b.expected.to_bytes(), &b.seg));
        let e = verdict.expect_err(&format!("{}: a witness honest under {name} VERIFIED under the declared constants", sh.name));
        eprintln!("NATIVE inconsistent witness at {} ({name}): rejected: {}", sh.profile, e.chars().take(100).collect::<String>());
        rejected += 1;
    }
    assert!(rejected >= 3, "{}: only {rejected} inconsistent-witness controls ran", sh.name);
}

/// **T3 at the trained-calibration rung, in the ordinary filter.** The
/// generic witness is admissible and equals the kernel; it proves, verifies
/// from bytes, and every coefficient / receipt / inconsistent-witness control
/// refuses.
#[test]
fn a_generic_trained_rung_block_proves_verifies_and_every_control_refuses() {
    let sh = rung_tc();
    let (blk, input, w) = generic_witness(&sh);
    let (expected, bytes, s) = prove_bytes(&sh, &blk, w);
    eprintln!("NATIVE rung-TC: proved in {s:.2} s, receipt {} B", bytes.len());
    let mk = |c: &NormCalibration| Shape::rung_tc(c);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
    inconsistent_witness_controls(&sh, &mk, &blk, &input);
}

/// **THE STATEMENT AT A TRAINED SHAPE.** The trained-model statement reads
/// the calibration from the shape: a record declaring another `tn`, `Cn` or
/// `Ceps` is refused; one-field changes move the identity; and a bound
/// one-block run at the rung proves, verifies, and is rejected under a
/// statement whose run is the same but whose shape carries other constants.
#[test]
fn a_bound_run_at_the_trained_rung_binds_its_constants() {
    use super::run::{self, RunShape, RunStatement, RunWitnessSource};
    use super::trained_statement::*;
    let sh = rung_tc();
    let (blk, input) = trained_dense_block(&sh);
    let prov = Provenance::recipe("native/rung-tc/0", 1.0 / 512.0, [3; 32], [4; 32]);
    let src = ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/private-block/trained-dense".into(),
        revision: "native-rung-tc".into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: 1,
    };
    let stmt = |sh: &Shape| TrainedModelStatement::new(sh, run::RUN_PROFILE_RUNG_TC, src.clone(), IntegerCalibration::as_the_code_proves(sh, &prov), vec![LayerRecord::of_block(0, &blk, vec![])]);
    let model = stmt(&sh).expect("the statement");
    // a declared calibration the shape does not carry is refused
    for (name, mutate) in [
        ("tn", (|c: &mut IntegerCalibration| c.norm_tn += 1) as fn(&mut IntegerCalibration)),
        ("cn_a", |c| c.norm_cn_a += 1),
        ("cn_m", |c| c.norm_cn_m += 1),
        ("ceps", |c| c.norm_ceps += 1),
        ("sh_ao", |c| c.sh_ao += 1),
    ] {
        let mut c = IntegerCalibration::as_the_code_proves(&sh, &prov);
        mutate(&mut c);
        assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_RUNG_TC, src.clone(), c, vec![LayerRecord::of_block(0, &blk, vec![])]).is_err(), "a statement declaring another {name} was accepted");
    }
    // the identity moves with each constant (through the shape)
    let mut ids = vec![model.identity()];
    for (_, v) in variations(sh.norm_calibration()) {
        ids.push(stmt(&Shape::rung_tc(&v).unwrap()).unwrap().identity());
    }
    let n = ids.len();
    ids.sort();
    ids.dedup();
    assert_eq!(ids.len(), n, "two calibrations share a statement identity");
    // a bound one-block run proves and verifies
    struct One(Shape, BlockPublic, Vec<i16>);
    impl RunWitnessSource for One {
        fn witness(&mut self, _k: usize) -> Result<Witness, String> {
            witness::build_shaped(&self.0, self.1.attention(), self.1.feed_forward(), &self.2)
        }
        fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
            Err("a one-block run has no internal boundary".into())
        }
    }
    let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).unwrap();
    let idm = Ids::new(&sh).unwrap();
    let ctx = *blake3::hash(b"native lane: a bound trained run").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane16(&w, idm.at(A_X)), &plane16(&w, idm.at(A_X2))).unwrap();
    drop(w);
    let blocks = vec![blk.clone()];
    let st = RunStatement::new_bound(RunShape::rung_tc(sh.clone(), 1).unwrap(), ctx, expected.clone(), &blocks, &[(0, 0)], &model).expect("the bound run statement");
    let mut segs: Vec<Vec<u8>> = vec![];
    let mut src_w = One(sh.clone(), blk.clone(), input.clone());
    run::prove_run(&st, &blocks, &mut src_w, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the bound one-block run proves");
    run::verify_run(&st, &blocks, &segs).expect("the bound run verifies");
    // the same segments under a verifier whose shape (and so statement)
    // carries one other constant: refused, for each constant
    for (name, v) in variations(sh.norm_calibration()) {
        let s2 = Shape::rung_tc(&v).unwrap();
        let m2 = stmt(&s2).unwrap();
        let st2 = RunStatement::new_bound(RunShape::rung_tc(s2, 1).unwrap(), ctx, expected.clone(), &blocks, &[(0, 0)], &m2).unwrap();
        assert!(run::verify_run(&st2, &blocks, &segs).is_err(), "the bound run verified under a shape with {name}");
    }
    // an unbound run at the trained TinyLlama run profile does not construct
    let t = tinyllama();
    let tspec = IoSpec::new_shaped(&t, ctx, 0, 0).unwrap();
    let texp = ExpectedIo::from_roots(tspec, [1; 32], [2; 32]);
    let refused = RunStatement::new(RunShape::tinyllama_t32_trained(t, 1).unwrap(), ctx, texp, &[blk.clone()], &[(0, 0)]).err().expect("an unbound trained run was constructed");
    assert!(refused.contains("model statement"), "{refused}");
}

// --------------------------------------------- T3 at the TRUE geometry (heavy)

fn evidence_dir() -> Option<std::path::PathBuf> {
    std::env::var_os("ZK60_NATIVE_T3_DIR").map(std::path::PathBuf::from)
}

/// **T3: ONE GENERIC BLOCK AT THE TRUE TinyLlama T32 GEOMETRY, trained
/// calibration, proves and verifies.** Dense synthetic weights (NOT a trained
/// model). With `ZK60_NATIVE_T3_DIR` set, the receipt bytes and the expected
/// policy bytes are written there for the fresh-process verifier below.
#[test]
#[ignore = "native lane heavy: one width-2048 TinyLlama block proof"]
fn native_t3_generic_trained_tinyllama_block_proves_and_verifies() {
    let sh = tinyllama();
    let (blk, input, w) = generic_witness(&sh);
    let hwm_w = super::run::peak_rss_mib();
    let (expected, bytes, prove_s) = prove_bytes(&sh, &blk, w);
    let hwm_p = super::run::peak_rss_mib();
    let t1 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &expected.to_bytes(), &bytes).expect("verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    if let Some(dir) = evidence_dir() {
        std::fs::create_dir_all(&dir).unwrap();
        // ROUND 2 (R2-4): a bound one-block run's SEGMENT, not a single-block frame
        std::fs::write(dir.join("t3-receipt.bin"), &bytes).unwrap();
        std::fs::write(dir.join("t3-expected.bin"), expected.to_bytes()).unwrap();
        std::fs::write(dir.join("t3-block-digest.hex"), blk.digest().iter().map(|b| format!("{b:02x}")).collect::<String>()).unwrap();
    }
    eprintln!(
        "NATIVE T3 TinyLlama trained T32, ONE dense synthetic block: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, receipt {} B, peak RSS after witness {hwm_w:.0} MiB, after prove {hwm_p:.0} MiB, block digest {} (shared box, diagnostic; NOT a trained model)",
        bytes.len(),
        blk.digest().iter().take(8).map(|b| format!("{b:02x}")).collect::<String>()
    );
    let mk = |c: &NormCalibration| Shape::tinyllama_t32_trained(c, T3_F_E);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
    inconsistent_witness_controls(&sh, &mk, &blk, &input);
}

/// **T3, the FRESH-PROCESS verifier.** Run as a separate test invocation
/// after the prover above: reads the receipt and the expected policy from
/// `ZK60_NATIVE_T3_DIR`, rebuilds the shape and the public statement from the
/// public recipe ALONE (no witness, no input), and verifies; then the
/// wrong-constant verifiers refuse the same bytes.
#[test]
#[ignore = "native lane heavy: verifies a saved width-2048 receipt in a fresh process"]
fn native_t3_verify_the_saved_receipt_in_a_fresh_process() {
    let dir = evidence_dir().expect("ZK60_NATIVE_T3_DIR is set");
    let sh = tinyllama();
    let (w, _) = super::dense_tests::dense_public_words_with(&sh, TRAINED_BANDS.attn, TRAINED_BANDS.gate, TRAINED_BANDS.down, TRAINED_BANDS.gains);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public, ff);
    let want = std::fs::read_to_string(dir.join("t3-block-digest.hex")).unwrap();
    assert_eq!(blk.digest().iter().map(|b| format!("{b:02x}")).collect::<String>(), want.trim(), "the rebuilt public statement is not the prover's");
    let expected = ExpectedIo::from_bytes_at(&sh, &std::fs::read(dir.join("t3-expected.bin")).unwrap()).expect("the expected policy");
    let bytes = std::fs::read(dir.join("t3-receipt.bin")).unwrap();
    let t1 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &expected.to_bytes(), &bytes).expect("the saved segment verifies in a fresh process");
    eprintln!("NATIVE T3 fresh-process verify: {:.2} s, {} B, peak RSS {:.0} MiB", t1.elapsed().as_secs_f64(), bytes.len(), super::run::peak_rss_mib());
    let mk = |c: &NormCalibration| Shape::tinyllama_t32_trained(c, T3_F_E);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
}

/// The band probe that chose [`TRAINED_BANDS`]: witness admissibility and
/// maxima over a small grid at both trained shapes (synthetic data only).
#[test]
#[ignore = "native lane probe: many width-2048 witnesses"]
fn native_probe_the_trained_dense_bands() {
    for sh in [rung_tc(), tinyllama()] {
        for attn in [4i64, 6, 8, 12, 16] {
            for gate in [8i64, 12, 16, 24] {
                let b = Bands { attn, gate, ..TRAINED_BANDS };
                let (blk, input) = trained_dense_block_with(&sh, b);
                match witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input) {
                    Ok(w) => {
                        let ids = Ids::new(&sh).unwrap();
                        let m = |p: usize| max_abs(&w.planes[ids.at(p)]);
                        eprintln!(
                            "PROBE {} attn {attn} gate {gate}: OK y_a {} y_m {} q8 {} k8 {} s8 {} o8 {} ao {} g8 {} u16 {} h16 {} z16 {} x2 {}",
                            sh.profile,
                            m(A_Y),
                            m(A_YM),
                            m(A_Q8),
                            m(A_K8),
                            m(A_S8),
                            m(A_O8),
                            m(A_AO),
                            m(A_G8),
                            m(A_U16),
                            m(A_H16),
                            m(A_Z16),
                            m(A_X2)
                        );
                    }
                    Err(e) => eprintln!("PROBE {} attn {attn} gate {gate}: REFUSED {e}", sh.profile),
                }
            }
        }
    }
}

// ------------------------------------------- D16 item 5: the range audit

/// every slot's IR at a shape (definition-time challenges fixed, as in the
/// IR tests; the audit reads only structure and public coefficients)
fn ir_walk(sh: &Shape) -> Vec<super::slot_ir::SlotIr> {
    use super::argument::Ctx;
    use super::slot_ir::{build_slot_ir, IrPoints};
    use crate::field::{Fp, Fp2};
    let lay = Layout::for_shape(sh).unwrap();
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let c = |re: u64, im: u64| Fp2::new(Fp::new(re), Fp::new(im));
    let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha: c(7, 1), beta: c(11, 2), g_u8: c(13, 3), g_exp: c(17, 5), g_act: c(19, 7) };
    let mut tr = crate::transcript::Transcript::new(sh.profile.as_bytes());
    let mut pts = IrPoints::default();
    (0..N_SLOTS).map(|s| build_slot_ir(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name))).collect()
}

/// `A[17] ...` -> 17
fn plane_of_label(label: &str) -> Option<usize> {
    let rest = label.strip_prefix("A[")?;
    rest[..rest.find(']')?].parse().ok()
}

/// **THE AUDIT.** Every committed `A` value that enters a relation under a
/// NON-UNIT public coefficient (anything but 0, +1, -1: `2 Cn`, `2^tn`,
/// `2^(tn+1)`, `2^sh_ao`, the int16 bias's partners, a lookup's `scaled`
/// factor, a power of 256), with the reason it is range-proved
/// independently of that relation. Returns `(slot, plane name, reason)`
/// sorted and deduplicated, and the planes it could not classify.
fn range_audit(sh: &Shape) -> (Vec<(usize, String, &'static str)>, Vec<(usize, String)>) {
    use super::slot_ir::{CoefProv, Factor, NodeBody, TableKind};
    use crate::field::Fp2;
    let ids = Ids::new(sh).unwrap();
    let names = super::plane_index::a_plane_names(sh);
    let byte_checked = |p: usize| -> bool { lookups_at(sh, &ids, ids.dom(p)).iter().any(|lk| lk.terms.len() == 1 && lk.terms[0].0 == p) };
    let name = |p: usize| names[p].clone();
    // the planes pinned to a byte-limb decomposition by a ±1 clause whose
    // limbs are themselves U8 lookups (checked below, not assumed)
    let limb_pinned: Vec<(usize, Vec<usize>, &'static str)> = vec![
        (ids.at(A_D), vec![ids.at(A_LIMB)], "R2: d = l0 + 256 l1 + 65536 l2 (SC_TZC), limbs in U8 (SC_LZC)"),
        (ids.at(A_DM), vec![ids.at(A_LIMBM)], "R2: dm = l3(limbs) (SC_TZC), limbs in U8 (SC_LZC)"),
        (ids.at(A_X), vec![ids.at(A_XL0), ids.at(A_XL1)], "int16: x + 32768 = l2 (SC_DZC c2), limbs in U8"),
        (ids.at(A_AO), vec![ids.at(A_AL0), ids.at(A_AL1)], "int16: ao + 32768 = l2 (SC_DZC c3), limbs in U8"),
        (ids.at(A_X1), vec![ids.at(A_X1L0), ids.at(A_X1L1)], "int16: x1 + 32768 = l2 (SC_DZC c4), limbs in U8"),
        (ids.at(A_X2), vec![ids.at(A_X2L0), ids.at(A_X2L1)], "int16: x2 + 32768 = l2 (SC_DZC c8), limbs in U8"),
        (ids.at(A_Z16), vec![ids.at(A_ZL0), ids.at(A_ZL1)], "int16: z16 + 32768 = l2 (SC_DZC c10), limbs in U8"),
        (ids.at(A_U16), vec![ids.at(A_UL0), ids.at(A_UL1)], "int16: u16 + 32768 = l2 (SC_FZC), limbs in U8"),
        (ids.at(A_H16), vec![ids.at(A_HL0), ids.at(A_HL1)], "int16: h16 + 32768 = l2 (SC_FZC), limbs in U8"),
    ];
    for (p, limbs, why) in &limb_pinned {
        for l in limbs {
            assert!(byte_checked(*l), "{}: {} is listed as limb-pinned ({why}) but its limb plane {} is not a U8 lookup", sh.name, name(*p), name(*l));
        }
    }
    // the planes range-proved by a TWO-COLUMN public-table lookup
    let pair_table: Vec<(usize, &'static str)> = vec![
        (ids.at(A_E), "exp table pair (delta, e): e is a public exp-table value"),
        (ids.at(A_A16), "activation table pair (g8 + 128, a16): a16 is a public act-table value"),
        (ids.at(A_G8), "activation table pair: g8 + 128 indexes the 256-row table"),
    ];
    let mut found: Vec<(usize, usize)> = Vec::new();
    for ir in ir_walk(sh) {
        let plane_of = |t: u16| -> Option<usize> {
            let tr = &ir.tables[t as usize];
            if tr.kind == TableKind::PlaneA {
                plane_of_label(&tr.label)
            } else {
                None
            }
        };
        let nonunit = |v: Fp2, prov: &CoefProv| matches!(prov, CoefProv::Base(_)) && v != Fp2::ONE && v != Fp2::ONE.neg() && v != Fp2::ZERO;
        // the planes reachable from a node, transitively
        fn reach(ir: &super::slot_ir::SlotIr, n: usize, out: &mut Vec<u16>) {
            match &ir.nodes[n].body {
                NodeBody::Affine { terms, .. } => out.extend(terms.iter().map(|(_, t)| *t)),
                NodeBody::Sum { subterms } => {
                    for s in subterms {
                        for f in &s.factors {
                            match f {
                                Factor::Table(t) => out.push(*t),
                                Factor::Node(m) => reach(ir, *m as usize, out),
                            }
                        }
                    }
                }
            }
        }
        for node in &ir.nodes {
            match &node.body {
                NodeBody::Affine { terms, .. } => {
                    for (c, t) in terms {
                        if nonunit(c.value, &c.prov) {
                            if let Some(p) = plane_of(*t) {
                                found.push((ir.slot, p));
                            }
                        }
                    }
                }
                NodeBody::Sum { subterms } => {
                    for s in subterms {
                        if !nonunit(s.coef.value, &s.coef.prov) {
                            continue;
                        }
                        let mut ts = Vec::new();
                        for f in &s.factors {
                            match f {
                                Factor::Table(t) => ts.push(*t),
                                Factor::Node(m) => reach(&ir, *m as usize, &mut ts),
                            }
                        }
                        found.extend(ts.into_iter().filter_map(plane_of).map(|p| (ir.slot, p)));
                    }
                }
            }
        }
        for t in &ir.terms {
            if nonunit(t.coef.value, &t.coef.prov) {
                for f in &t.inner {
                    let mut ts = Vec::new();
                    match f {
                        Factor::Table(x) => ts.push(*x),
                        Factor::Node(m) => reach(&ir, *m as usize, &mut ts),
                    }
                    found.extend(ts.into_iter().filter_map(plane_of).map(|p| (ir.slot, p)));
                }
            }
        }
    }
    found.sort();
    found.dedup();
    let mut ok = Vec::new();
    let mut unclassified = Vec::new();
    for (s, p) in found {
        let reason: Option<&'static str> = if byte_checked(p) {
            Some("U8 lookup on its own domain (byte / scaled / sym class)")
        } else if let Some((_, _, why)) = limb_pinned.iter().find(|(q, _, _)| *q == p) {
            Some(why)
        } else {
            pair_table.iter().find(|(q, _)| *q == p).map(|(_, why)| *why)
        };
        match reason {
            Some(r) => ok.push((s, name(p), r)),
            None => unclassified.push((s, name(p))),
        }
    }
    (ok, unclassified)
}

/// **D16 ITEM 5, RE-RUN ON THE NEW LAYOUT.** At both trained shapes every
/// committed value under a non-unit coefficient of the NORM and AO slots
/// (`SC_TZC`, `SC_DZC`) is independently range-proved, and the set of
/// (slot, plane) pairs under non-unit coefficients is EXACTLY the frozen
/// structural twin's (TinyLlama trained vs the lane-C dev shape; the trained
/// rung vs rung-C6): the trained calibration changed coefficient VALUES and
/// no committed value's exposure. Planes outside the norm slots that the
/// audit cannot classify are printed for the record, and must be the
/// twin's too.
#[test]
fn every_committed_value_under_a_non_unit_coefficient_is_range_proved_at_the_trained_shapes() {
    // ROUND 2: rung-TC carries every windowed shift off its frozen value, and
    // the pg_rot1 calibration is audited at the TinyLlama geometry too
    let pg = Shape::tinyllama_t32_trained(&pg_calibration(), T3_F_E).unwrap();
    for (sh, twin) in [(rung_tc(), Shape::rung_c6()), (tinyllama(), Shape::tinyllama_t32_dev()), (pg, Shape::tinyllama_t32_dev())] {
        let (ok, un) = range_audit(&sh);
        let (tok, tun) = range_audit(&twin);
        for (s, p, r) in &ok {
            eprintln!("D16-5 AUDIT {} slot {s:02} {p}: {r}", sh.profile);
        }
        for (s, p) in &un {
            eprintln!("D16-5 AUDIT {} slot {s:02} {p}: NOT CLASSIFIED (bounded by its relation, see NOWRAP_DERIVATION.md)", sh.profile);
        }
        assert!(un.iter().all(|(s, _)| *s != SC_TZC && *s != SC_DZC), "{}: a norm/AO-slot value under a non-unit coefficient is not independently range-proved: {un:?}", sh.name);
        let pairs = |v: &Vec<(usize, String, &'static str)>| -> Vec<(usize, String)> { v.iter().map(|(s, p, _)| (*s, p.clone())).collect() };
        // ROUND 2: the exposure may only SHRINK against the frozen twin: a
        // shift at the top of its window (8, or 16) turns its top-limb pin's
        // coefficient into 1, so that remainder leaves the non-unit list
        // while still being a U8 lookup; no plane may JOIN the list
        let (mine, frozen) = (pairs(&ok), pairs(&tok));
        let new: Vec<&(usize, String)> = mine.iter().filter(|p| !frozen.contains(p)).collect();
        assert!(new.is_empty(), "{}: planes newly exposed under a non-unit coefficient against the frozen twin {}: {new:?}", sh.name, twin.name);
        let gone: Vec<&(usize, String)> = frozen.iter().filter(|p| !mine.contains(p)).collect();
        for g in &gone {
            let cal = sh.norm_calibration();
            let at_top = [cal.sh_qkv, cal.sh_s, cal.sh_g, cal.sh_z, cal.sh_ao].contains(&8) || [cal.sh_o, cal.sh_h].contains(&16);
            assert!(at_top, "{}: {g:?} left the exposure list but no shift sits at the top of its window", sh.name);
            eprintln!("D16-5 AUDIT {} slot {:02} {}: under coefficient 1 here (its shift is at the top of its window; still a U8 lookup)", sh.profile, g.0, g.1);
        }
        assert_eq!(un, tun, "{}: the unclassified exposure differs from the frozen twin {}", sh.name, twin.name);
        assert!(ok.iter().any(|(s, p, _)| *s == SC_DZC && p == "A_X") && ok.iter().any(|(s, p, _)| *s == SC_DZC && p == "A_D"), "{}: the audit did not see the norm clause", sh.name);
    }
}

// ------------------------------------------------- the profile registry

/// **THE TRAINED-CALIBRATION PROFILES, as the registry tests build them.**
/// Each block profile at its REFERENCE calibration (the hash tag and every
/// hash-input length depend on the profile string and the geometry, not on
/// the calibration values; the calibration is bound through the schedule
/// digest and the statement), and each run profile with its block shape.
pub(super) fn registered_trained_shapes() -> Vec<Shape> {
    vec![tinyllama(), rung_tc(), tinyllama_at(64), tinyllama_at(128), llama3_8b()]
}

/// ROUND 4 (R4-1): the trained Llama-3-8B shape with the B5 smoke's
/// calibration (tn 9, Cn 1595 / 834, Ceps 129,746, shifts qkv 8 / s 7 / ao 6
/// / g 8 / h 16 / z 5), f_e 9
pub(super) fn llama3_8b_calibration() -> NormCalibration {
    NormCalibration { tn: 9, cn_a: 1595, cn_m: 834, ceps: 129_746, sh_ao: 6, sh_qkv: 8, sh_s: 7, sh_o: 9, sh_g: 8, sh_h: 16, sh_z: 5 }
}

pub(super) fn llama3_8b() -> Shape {
    Shape::llama3_8b_t32_trained(&llama3_8b_calibration(), 9).expect("the trained Llama-3-8B shape")
}

pub(super) fn registered_trained_runs() -> Vec<(&'static str, Shape)> {
    vec![
        (super::run::RUN_PROFILE_TINYLLAMA_T32_TRAINED, tinyllama()),
        (super::run::RUN_PROFILE_RUNG_TC, rung_tc()),
        (super::run::RUN_PROFILE_TINYLLAMA_T64_TRAINED, tinyllama_at(64)),
        (super::run::RUN_PROFILE_TINYLLAMA_T128_TRAINED, tinyllama_at(128)),
        (super::run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED, llama3_8b()),
    ]
}

/// A REAL run statement at a trained run profile, with no commitment (the
/// registry tests' `run_statement`, for the profiles that only construct
/// bound to a trained-model statement). TinyLlama binds the pinned
/// checkpoint source; the rung a synthetic recipe.
pub(super) fn trained_run_statement(sh: &Shape, profile: &'static str, l: usize, ctx: Digest, expected: ExpectedIo) -> super::run::RunStatement {
    use super::run::{RunShape, RunStatement};
    use super::trained_statement::*;
    // ROUND 4: ONE block and its digest repeated (`new_bound_from_digests`):
    // 22 clones of a Llama-3-8B block would be 5 GB in a test
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let one = BlockPublic::new(public, ff);
    let pinned = ModelSource::pinned_for_profile(sh.profile);
    let source = if let Some(pin) = pinned {
        pin
    } else {
        ModelSource {
            kind: SourceKind::PublicSyntheticRecipe,
            repo: "hashline/private-block/tame-fixture".into(),
            revision: "registry".into(),
            weights_sha256: [0; 32],
            config_sha256: [0; 32],
            checkpoint_parameters: 0,
            checkpoint_layers: l as u32,
        }
    };
    let rec0 = LayerRecord::of_block(0, &one, vec![]);
    let recs = (0..l).map(|k| LayerRecord { index: k as u32, ..rec0.clone() }).collect();
    let mut prov = Provenance::recipe("registry", 1.0 / 1024.0, [1; 32], [2; 32]);
    prov.rope_theta = super::shape::trained_rope_theta(sh.profile).unwrap_or(prov.rope_theta);
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    let model = TrainedModelStatement::new(sh, profile, source, cal, recs).expect("the registry's trained statement");
    let rs = if sh.profile == super::shape::TRAINED_CALIB_RUNG_PROFILE { RunShape::rung_tc(sh.clone(), l) } else { RunShape::tinyllama_trained(sh.clone(), l) }.expect("the trained run shape");
    RunStatement::new_bound_from_digests(rs, ctx, expected, vec![one.digest(); l], &vec![(0, 0); l], &model).expect("the trained run statement")
}
