//! Tests of the SHAPE-DRIVEN path (step S6) that need no proof system: the
//! buffer arithmetic, the construction refusals, and the grouped-query
//! structure at a shape the fixed path cannot express.
//!
//! Everything here is public synthetic test data built by a fixed integer
//! rule: no OS randomness, no real model, no real input, nothing read from or
//! written to disk, and nothing printed.

use super::shaped::*;
use super::*;
use std::vec;
use std::vec::Vec;

/// toy, the development rung's geometry, and the 125M-class geometry
fn named() -> [Shape; 3] {
    [
        Shape::toy(),
        // the rung of ruling P-7, at the toy's softmax calibration (the
        // `F_E = 12` variant is step S8's, and changes no geometry here)
        Shape::new(24, 96, 192, 6, 2, 16, 9, 9, 14, 31),
        Shape::new(512, 768, 2048, 12, 4, 64, 9, 9, 18, 32),
    ]
}

#[test]
fn the_trace_length_closed_form_equals_the_part_table() {
    for sh in named() {
        let summed: usize = PARTS.iter().map(|p| sh.part_len(*p)).sum();
        assert_eq!(sh.trace_len(), summed, "trace_len disagrees with the part table at {sh:?}");
        // the parts tile the buffer exactly, in order, with no gap or overlap
        let mut off = 0usize;
        for p in PARTS {
            let (o, n) = sh.part(p);
            assert_eq!(o, off, "part {p:?} is not contiguous at {sh:?}");
            assert_eq!(n, sh.part_len(p));
            off += n;
        }
        assert_eq!(off, sh.trace_len());
    }
}

#[test]
fn the_toy_shape_is_the_fixed_geometry() {
    let sh = Shape::toy();
    assert_eq!((sh.tokens, sh.width, sh.hidden), (T, D, F));
    assert_eq!((sh.q_heads, sh.kv_heads, sh.head_dim), (H, HKV, DH));
    assert_eq!((sh.x_len(), sh.kv_len(), sh.ff_len(), sh.score_len(), sh.rows(), sh.rope_len()), (X_LEN, KV_LEN, FF_LEN, SCORE_LEN, ROWS, ROPE_LEN));
    assert_eq!(sh.group(), H / HKV);
    assert_eq!(sh.half_dim(), HALF);
    assert_eq!((sh.f_e, sh.f_p, sh.wrho_s, sh.norm_wrho), (calib::F_E, calib::F_P, calib::WRHO_S, calib::NORM_WRHO));
    sh.check().expect("the toy shape is well formed");
}

#[test]
fn the_shape_refusals_fire_by_name() {
    let t = Shape::toy();
    let bad = |f: &dyn Fn(&mut Shape)| {
        let mut s = t;
        f(&mut s);
        s.check().expect_err("this shape must be refused")
    };
    assert_eq!(bad(&|s| s.tokens = 0), KernelError::Shape("shape: an axis is zero"));
    assert_eq!(bad(&|s| s.kv_heads = 0), KernelError::Shape("shape: an axis is zero"));
    assert_eq!(bad(&|s| s.head_dim = 7), KernelError::Shape("shape: the head dimension is odd"));
    assert_eq!(bad(&|s| s.width = 24), KernelError::Shape("shape: width differs from q_heads * head_dim"));
    assert_eq!(
        bad(&|s| {
            s.q_heads = 3;
            s.kv_heads = 2;
            s.width = 24;
        }),
        KernelError::Shape("shape: the query heads do not divide into the key-value heads")
    );
    assert_eq!(bad(&|s| s.norm_wrho = 63), KernelError::Shape("shape: a calibration window is out of range"));
}

// ------------------------------------------------------------- a tiny GQA shape

/// `T4 / d8 / f8, 4 query heads of 2 over 2 KV heads` — group 2, the smallest
/// geometry at which a query head can read the WRONG key-value head.
const GQA: Shape = Shape::new(4, 8, 8, 4, 2, 2, 9, 9, 14, 29);

fn gqa_tables() -> (Vec<i64>, Vec<i64>, Vec<i64>, Vec<i16>) {
    let one_ro = 1i64 << calib::F_RO;
    let cos = vec![one_ro; GQA.rope_len()];
    let sin = vec![0i64; GQA.rope_len()];
    let exp: Vec<i64> = (0..256).map(|d: u32| (1i64 << GQA.f_e) >> d.min(GQA.f_e)).collect();
    let act: Vec<i16> = (0..256).map(|i| i as i16 - 128).collect();
    (cos, sin, exp, act)
}

/// diagonal `(out, in)` matrix of `outer x inner`, entry 64 on the diagonal
fn diag(outer: usize, inner: usize) -> Vec<i8> {
    (0..outer * inner).map(|k| if k / inner == k % inner { 64i8 } else { 0 }).collect()
}

fn gqa_input() -> Vec<i16> {
    (0..GQA.x_len()).map(|k| ((k % 5) as i16) - 2).collect()
}

/// Run the GQA shape with `wk`/`wv` rows of key-value head `kill` zeroed, and
/// return the score cube and the attention output.
fn gqa_run(kill: Option<usize>) -> (Vec<i64>, Vec<i64>) {
    let (cos, sin, exp, act) = gqa_tables();
    let (d, kvw, dh) = (GQA.width, GQA.kv_width(), GQA.head_dim);
    let mut wk = diag(kvw, d);
    let mut wv = diag(kvw, d);
    if let Some(h) = kill {
        for j in h * dh..(h + 1) * dh {
            for i in 0..d {
                wk[j * d + i] = 0;
                wv[j * d + i] = 0;
            }
        }
    }
    let (wq, wo) = (diag(d, d), diag(d, d));
    let gamma = vec![64i8; d];
    let (wg, wu, wd) = (diag(d, GQA.hidden), diag(d, GQA.hidden), diag(GQA.hidden, d));
    let w = WeightsRef { wq: &wq, wk: &wk, wv: &wv, wo: &wo, gamma_a: &gamma, gamma_m: &gamma, wg_t: &wg, wu_t: &wu, wd_t: &wd };
    let tab = TablesRef { rope_cos: &cos, rope_sin: &sin, exp: &exp, act: &act };
    let mut scratch = vec![0i64; GQA.scratch_len()];
    let mut tbuf = vec![0i64; GQA.trace_len()];
    let mut out = vec![0i16; GQA.x_len()];
    run_shaped(&GQA, &gqa_input(), &w, &tab, &mut scratch, Some(&mut tbuf), &mut out).expect("the tiny grouped-query block computes");
    let part = |p: Part| {
        let (o, n) = GQA.part(p);
        tbuf[o..o + n].to_vec()
    };
    (part(Part::S8), part(Part::O8))
}

/// THE GROUP STRUCTURE, as a property of the computation and not of a
/// literal: query head `h` reads key-value head `h / group` and NO OTHER.
/// Zeroing one key-value head's projection rows must move exactly the query
/// heads of that group and leave the others bit for bit unchanged.
#[test]
fn a_query_head_reads_only_its_own_key_value_head() {
    assert_eq!(GQA.group(), 2);
    let (s_all, o_all) = gqa_run(None);
    let n = GQA.tokens;
    for kill in 0..GQA.kv_heads {
        let (s, o) = gqa_run(Some(kill));
        for h in 0..GQA.q_heads {
            let rows = h * n * n..(h + 1) * n * n;
            let same = s[rows.clone()] == s_all[rows.clone()];
            assert_eq!(
                same,
                h / GQA.group() != kill,
                "killing key-value head {kill} {} query head {h}'s scores",
                if same { "left unchanged" } else { "changed" }
            );
        }
        // the value mixing follows the same grouping, on the (t, h, i') plane
        for h in 0..GQA.q_heads {
            let mut same = true;
            for t in 0..n {
                for i in 0..GQA.head_dim {
                    let k = t * GQA.width + h * GQA.head_dim + i;
                    same &= o[k] == o_all[k];
                }
            }
            assert_eq!(same, h / GQA.group() != kill, "killing key-value head {kill}: query head {h}'s output grouping is wrong");
        }
    }
}

#[test]
fn the_buffer_lengths_are_checked() {
    let (cos, sin, exp, act) = gqa_tables();
    let (d, kvw) = (GQA.width, GQA.kv_width());
    let (wq, wo) = (diag(d, d), diag(d, d));
    let (wk, wv) = (diag(kvw, d), diag(kvw, d));
    let gamma = vec![64i8; d];
    let (wg, wu, wd) = (diag(d, GQA.hidden), diag(d, GQA.hidden), diag(GQA.hidden, d));
    let w = WeightsRef { wq: &wq, wk: &wk, wv: &wv, wo: &wo, gamma_a: &gamma, gamma_m: &gamma, wg_t: &wg, wu_t: &wu, wd_t: &wd };
    let tab = TablesRef { rope_cos: &cos, rope_sin: &sin, exp: &exp, act: &act };
    let input = gqa_input();
    let mut out = vec![0i16; GQA.x_len()];
    let mut short = vec![0i64; GQA.scratch_len() - 1];
    let mut long = vec![0i64; GQA.scratch_len() + 1];
    assert_eq!(run_shaped(&GQA, &input, &w, &tab, &mut short, None, &mut out).err(), Some(KernelError::Shape("scratch")));
    assert_eq!(run_shaped(&GQA, &input, &w, &tab, &mut long, None, &mut out).err(), Some(KernelError::Shape("scratch")));
    let mut ok = vec![0i64; GQA.scratch_len()];
    assert_eq!(run_shaped(&GQA, &input[1..], &w, &tab, &mut ok, None, &mut out).err(), Some(KernelError::Shape("input")));
    let mut wrong_out = vec![0i16; GQA.x_len() + 1];
    assert_eq!(run_shaped(&GQA, &input, &w, &tab, &mut ok, None, &mut wrong_out).err(), Some(KernelError::Shape("output")));
    let mut tshort = vec![0i64; GQA.trace_len() - 1];
    assert_eq!(run_shaped(&GQA, &input, &w, &tab, &mut ok, Some(&mut tshort), &mut out).err(), Some(KernelError::Shape("trace")));
    // the weight and table shape refusals name their own word
    let bad = WeightsRef { wk: &wk[1..], ..w };
    assert_eq!(run_shaped(&GQA, &input, &bad, &tab, &mut ok, None, &mut out).err(), Some(KernelError::Shape("wk")));
    let badt = TablesRef { rope_cos: &cos[1..], ..tab };
    assert_eq!(run_shaped(&GQA, &input, &w, &badt, &mut ok, None, &mut out).err(), Some(KernelError::Shape("rope_cos")));
}
