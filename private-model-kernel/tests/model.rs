//! Native tests. All model words here are PUBLIC SYNTHETIC test data; the
//! token sequences are test inputs. Nothing is printed. Expectations come
//! from independent i128 arithmetic (embedding gather, final norm, head,
//! argmax), from the unchanged block kernel (block computation) and from
//! hand-derived constants, never from the function under test alone.
use private_block_kernel::{run_block, Trace};
use private_model_kernel::synthetic::*;
use private_model_kernel::*;

struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 33
    }
    fn range(&mut self, amp: i64) -> i64 {
        (self.next() % (2 * amp as u64 + 1)) as i64 - amp
    }
    fn tokens(&mut self) -> [u32; CTX] {
        core::array::from_fn(|_| (self.next() % VOCAB as u64) as u32)
    }
}

/// Zeroing `wo` and `wd_t` makes the block an exact identity (AO = 0 and
/// z = 0 with residual shifts 0); checked against the kernel below.
fn identity(b: &RawBlock) -> RawBlock {
    let mut b = b.clone();
    b.wo = [0; 256];
    b.wd_t = [0; 256];
    b
}

fn with_blocks(raw: &RawModel, b0: RawBlock, b1: RawBlock) -> RawModel {
    let mut m = raw.clone();
    m.blocks = [b0, b1];
    m
}

/// Independent i128 final norm: bisection square root and the relation
/// written out directly. `None` on a range refusal.
fn ref_norm(x: &[i16], g: &[i8]) -> Option<(i128, [i128; D])> {
    let sse: i128 = x.iter().map(|v| (*v as i128) * (*v as i128)).sum::<i128>() + 1;
    let (mut d, mut hi) = (0i128, 1i128 << 20);
    while hi - d > 1 {
        let mid = (d + hi) / 2;
        if mid * mid <= sse {
            d = mid;
        } else {
            hi = mid;
        }
    }
    let den = d << 12;
    let mut y = [0i128; D];
    for i in 0..D {
        let num = 2 * x[i] as i128 * g[i] as i128 * 1024 + (d << 11);
        let q = num.div_euclid(den);
        let rho = num.rem_euclid(den);
        if !(-127..=127).contains(&q) || rho >= 1 << 29 || den - 1 - rho >= 1 << 29 {
            return None;
        }
        y[i] = q;
    }
    Some((d, y))
}

struct Reference {
    embedded: [i16; X_LEN],
    layer0: [i16; X_LEN],
    layer1: [i16; X_LEN],
    dd: i128,
    y: [i128; D],
    logits: Vec<i128>,
    token: u32,
}

/// Independent end-to-end reference: own gather, the unchanged block kernel
/// twice, i128 final norm and head, max-then-first-position argmax.
fn reference(tokens: &[u32; CTX], raw: &RawModel) -> Reference {
    let mut embedded = [0i16; X_LEN];
    for t in 0..CTX {
        for i in 0..D {
            embedded[t * D + i] = raw.embed[tokens[t] as usize * D + i];
        }
    }
    let b0 = raw.blocks[0].to_block().unwrap();
    let b1 = raw.blocks[1].to_block().unwrap();
    let layer0 = run_block(&embedded, &b0.weights, &b0.tables, None).expect("reference block 0");
    let layer1 = run_block(&layer0, &b1.weights, &b1.tables, None).expect("reference block 1");
    let (dd, y) = ref_norm(&layer1[(CTX - 1) * D..], &raw.gamma_f).expect("reference final norm");
    let logits: Vec<i128> = (0..VOCAB).map(|v| (0..D).map(|i| y[i] * raw.head[v * D + i] as i128).sum()).collect();
    let m = *logits.iter().max().unwrap();
    let token = logits.iter().position(|l| *l == m).unwrap() as u32;
    Reference { embedded, layer0, layer1, dd, y, logits, token }
}

fn run(tokens: &[u32; CTX], raw: &RawModel) -> Result<u32, ModelError> {
    next_token(tokens, &raw.build().unwrap())
}

// ------------------------------------------------------------ end to end

#[test]
fn end_to_end_matches_independent_reference() {
    let raw = synthetic_raw_model();
    let model = synthetic_model().unwrap();
    let mut rng = Lcg(60);
    let mut seen = [false; VOCAB];
    for case in 0..48 {
        let toks = match case {
            0 => [0; CTX],
            1 => [31; CTX],
            2 => core::array::from_fn(|t| t as u32),
            _ => rng.tokens(),
        };
        let want = reference(&toks, &raw);
        let mut tr = Box::new(ModelTrace::zeroed());
        let got = next_token_traced(&toks, &model, Some(&mut *tr)).unwrap_or_else(|e| panic!("case {case}: {e}"));
        assert_eq!(got, want.token, "case {case}");
        assert_eq!(next_token(&toks, &model), Ok(got), "case {case}: trace-independent");
        assert_eq!(next_token_slice(&toks, &model, None), Ok(got));
        assert!(tr.embedded == want.embedded && tr.layer0 == want.layer0 && tr.layer1 == want.layer1);
        assert_eq!(tr.final_dd as i128, want.dd);
        assert!(tr.final_y.iter().zip(&want.y).all(|(a, b)| *a as i128 == *b));
        assert!(tr.logits.iter().zip(&want.logits).all(|(a, b)| *a as i128 == *b));
        seen[got as usize] = true;
    }
    // Not a constant model: several distinct next tokens over the sweep.
    assert!(seen.iter().filter(|s| **s).count() >= 3);
}

#[test]
fn synthetic_model_is_deterministic() {
    let (a, b) = (synthetic_raw_model(), synthetic_raw_model());
    assert!(a.embed == b.embed && a.head == b.head && a.gamma_f == b.gamma_f);
    assert!(a.blocks[0].wq == b.blocks[0].wq && a.blocks[1].wd_t == b.blocks[1].wd_t);
    // The two blocks are independently generated, with different tables.
    assert!(a.blocks[0].wq != a.blocks[1].wq && a.blocks[0].wo != a.blocks[1].wo);
    assert!(a.blocks[0].rope_cos != a.blocks[1].rope_cos && a.blocks[0].exp != a.blocks[1].exp);
    assert!(a.blocks[0].act != a.blocks[1].act);
    assert!(a.head.contains(&-128) && a.gamma_f.iter().any(|g| *g < 0));
    assert!(SYNTHETIC_LABEL.contains("NOT trained"));
}

// ------------------------------------------------------------ embedding

#[test]
fn embedding_gather_is_exact() {
    let mut raw = synthetic_raw_model();
    // Every word distinct, recoverable from (token, d) by formula; within
    // [-8000, 7605] so two synthetic blocks (<= 8844 each) cannot overflow.
    for v in 0..VOCAB {
        for i in 0..D {
            raw.embed[v * D + i] = (v as i16) * 500 + (i as i16) * 7 - 8000;
        }
    }
    let model = raw.build().unwrap();
    let mut rng = Lcg(7);
    for case in 0..6 {
        let toks: [u32; CTX] = match case {
            0 => core::array::from_fn(|t| (CTX - 1 - t) as u32),
            1 => core::array::from_fn(|t| [0, 31, 0, 5][t % 4]),
            _ => rng.tokens(),
        };
        let mut tr = Box::new(ModelTrace::zeroed());
        next_token_traced(&toks, &model, Some(&mut *tr)).unwrap();
        for t in 0..CTX {
            for i in 0..D {
                assert_eq!(tr.embedded[t * D + i], toks[t] as i16 * 500 + i as i16 * 7 - 8000, "case {case} t {t} i {i}");
            }
        }
    }
}

// ------------------------------------------------------------ two-block seam

#[test]
fn identity_block_is_exact_identity_in_kernel() {
    let raw = synthetic_raw_model();
    let mut rng = Lcg(3);
    for b in &raw.blocks {
        let id = identity(b).to_block().unwrap();
        for amp in [400i64, 9000, 32767] {
            let x: [i16; X_LEN] = core::array::from_fn(|_| rng.range(amp).clamp(-32768, 32767) as i16);
            assert_eq!(run_block(&x, &id.weights, &id.tables, None), Ok(x));
        }
    }
}

#[test]
fn both_layer_seam() {
    let raw = synthetic_raw_model();
    let model = raw.build().unwrap();
    let b0 = raw.blocks[0].to_block().unwrap();
    let b1 = raw.blocks[1].to_block().unwrap();
    let mut rng = Lcg(11);
    for _ in 0..8 {
        let toks = rng.tokens();
        let mut tr = Box::new(ModelTrace::zeroed());
        next_token_traced(&toks, &model, Some(&mut *tr)).unwrap();
        // Block 0 consumes the gather, block 1 consumes block 0's output.
        assert_eq!(run_block(&tr.embedded, &b0.weights, &b0.tables, None), Ok(tr.layer0));
        assert_eq!(run_block(&tr.layer0, &b1.weights, &b1.tables, None), Ok(tr.layer1));
        // Both blocks actually change the activation.
        assert!(tr.layer0 != tr.embedded && tr.layer1 != tr.layer0);
        // The final norm reads block 1's LAST row.
        let (dd, y) = ref_norm(&tr.layer1[(CTX - 1) * D..], &raw.gamma_f).unwrap();
        assert_eq!(tr.final_dd as i128, dd);
        assert!(tr.final_y.iter().zip(&y).all(|(a, b)| *a as i128 == *b));
    }
}

#[test]
fn both_blocks_and_their_order_affect_the_next_token() {
    let raw = synthetic_raw_model();
    let [b0, b1] = raw.blocks.clone();
    let variants = [
        with_blocks(&raw, identity(&b0), b1.clone()),
        with_blocks(&raw, b0.clone(), identity(&b1)),
        with_blocks(&raw, identity(&b0), identity(&b1)),
        with_blocks(&raw, b1.clone(), b0.clone()),
    ];
    let mut differs = [0usize; 4];
    let mut rng = Lcg(2026);
    for _ in 0..64 {
        let toks = rng.tokens();
        let full = run(&toks, &raw).unwrap();
        for (k, var) in variants.iter().enumerate() {
            let got = run(&toks, var).unwrap();
            // Every variant is itself checked against the reference.
            assert_eq!(got, reference(&toks, var).token);
            if got != full {
                differs[k] += 1;
            }
        }
    }
    // Ablating block 0, ablating block 1, ablating both, and swapping the
    // order each change the greedy token on some sequences.
    assert!(differs.iter().all(|n| *n >= 1), "variant effect counts {differs:?}");
}

#[test]
fn earlier_positions_reach_the_last_row_through_attention() {
    let raw = synthetic_raw_model();
    let model = raw.build().unwrap();
    let mut rng = Lcg(99);
    let mut changed = 0;
    for _ in 0..16 {
        let toks = rng.tokens();
        let mut alt = toks;
        for t in 0..CTX - 1 {
            alt[t] = (toks[t] + 1) % VOCAB as u32;
        }
        let mut a = Box::new(ModelTrace::zeroed());
        let mut b = Box::new(ModelTrace::zeroed());
        next_token_traced(&toks, &model, Some(&mut *a)).unwrap();
        next_token_traced(&alt, &model, Some(&mut *b)).unwrap();
        // Same last token, every earlier token different.
        assert_eq!(a.embedded[(CTX - 1) * D..], b.embedded[(CTX - 1) * D..]);
        if a.layer1[(CTX - 1) * D..] != b.layer1[(CTX - 1) * D..] {
            changed += 1;
        }
    }
    assert!(changed >= 1);
}

// ------------------------------------------------------------ final norm

#[test]
fn final_norm_hand_cases() {
    let g = |v: i8| [v; D];
    let mut row = [0i16; D];
    row[0] = 3; // D = isqrt(10) = 3, y0 = floor(g/2 + 1/2)
    assert_eq!(final_norm_row(&row, &g(64)).unwrap(), (3, { let mut y = [0; D]; y[0] = 32; y }));
    assert_eq!(final_norm_row(&row, &g(65)).unwrap().1[0], 33); // 32.5 -> 33
    assert_eq!(final_norm_row(&row, &g(-65)).unwrap().1[0], -32); // -32.5 -> -32
    row[0] = -3;
    assert_eq!(final_norm_row(&row, &g(65)).unwrap().1[0], -32);
    assert_eq!(final_norm_row(&row, &g(-65)).unwrap().1[0], 33);
    // Zero row: D = isqrt(Ceps) = 1, y = 0.
    assert_eq!(final_norm_row(&[0; D], &g(127)).unwrap(), (1, [0; D]));
    // Extremes: D = isqrt(2^34 + 1) = 2^17, y = floor(16.5) = 16.
    assert_eq!(final_norm_row(&[-32768; D], &g(-128)).unwrap(), (1 << 17, [16; D]));
    // One-hot extreme: D = 32768, y5 = floor(64 + 1/2) = 64.
    let mut spike = [0i16; D];
    spike[5] = -32768;
    let (d, y) = final_norm_row(&spike, &g(-128)).unwrap();
    assert_eq!((d, y[5], y[4]), (32768, 64, 0));
}

#[test]
fn final_norm_matches_independent_i128() {
    let mut rng = Lcg(5);
    for case in 0..4000 {
        let amp = [2i64, 60, 3000, 32768][case % 4];
        let x: [i16; D] = core::array::from_fn(|_| rng.range(amp).clamp(-32768, 32767) as i16);
        let g: [i8; D] = core::array::from_fn(|_| rng.range(128).min(127) as i8);
        let got = final_norm_row(&x, &g);
        match ref_norm(&x, &g) {
            Some((d, y)) => {
                let (gd, gy) = got.unwrap_or_else(|e| panic!("case {case}: {e}"));
                assert_eq!(gd as i128, d);
                assert!(gy.iter().zip(&y).all(|(a, b)| *a as i128 == *b), "case {case}");
            }
            None => assert_eq!(got.err(), Some(ModelError::Final(KernelError::Range("final norm quotient/remainder")))),
        }
    }
}

/// The final norm must be exactly the block kernel's norm calibration: a
/// block whose attention/FFN contribute nothing exposes its norm_a plane.
#[test]
fn final_norm_equals_block_kernel_norm_calibration() {
    let raw = synthetic_raw_model();
    let mut probe = raw.blocks[0].clone();
    probe.wq = [0; 256];
    probe.wk = [0; 128];
    probe.wv = [0; 128];
    probe.wo = [0; 256];
    probe.wg_t = [0; 256];
    probe.wu_t = [0; 256];
    probe.wd_t = [0; 256];
    let mut rng = Lcg(17);
    for case in 0..12 {
        probe.gamma_a = core::array::from_fn(|_| rng.range(128).min(127) as i8);
        let amp = [5i64, 700, 32768][case % 3];
        let x: [i16; X_LEN] = core::array::from_fn(|_| rng.range(amp).clamp(-32768, 32767) as i16);
        let blk = probe.to_block().unwrap();
        let mut tr = Box::new(Trace::zeroed());
        run_block(&x, &blk.weights, &blk.tables, Some(&mut *tr)).unwrap();
        for t in 0..CTX {
            let row: [i16; D] = x[t * D..(t + 1) * D].try_into().unwrap();
            let (d, y) = final_norm_row(&row, &probe.gamma_a).unwrap();
            assert_eq!(d, tr.na_dd[t], "case {case} row {t}");
            assert_eq!(&y[..], &tr.na_y[t * D..(t + 1) * D], "case {case} row {t}");
        }
    }
}

// ------------------------------------------------------------ head, greedy

#[test]
fn head_orientation_is_vocab_by_d_and_signed() {
    let mut y = [0i64; D];
    y[5] = -9;
    y[11] = 4;
    let mut head = [0i8; TABLE_LEN];
    head[20 * D + 5] = -3; // (vocab 20, d 5)
    head[7 * D + 11] = -128; // (vocab 7, d 11)
    let l = head_logits(&y, &head).unwrap();
    let mut want = [0i64; VOCAB];
    want[20] = 27;
    want[7] = -512;
    assert_eq!(l, want);
    // A (d, vocab) reading would have put word 20*16+5 at vocab 5.
    assert_eq!(l[5], 0);
    assert_eq!(greedy(&l), 20);
}

#[test]
fn signed_head_end_to_end() {
    let raw = synthetic_raw_model();
    let toks = Lcg(41).tokens();
    let mut tr = Box::new(ModelTrace::zeroed());
    next_token_traced(&toks, &raw.build().unwrap(), Some(&mut *tr)).unwrap();
    let i = tr.final_y.iter().position(|v| *v != 0).expect("nonzero final activation");
    let s = tr.final_y[i].signum() as i8;
    for v in [0usize, 13, 31] {
        // A single head word opposite in sign to y_i gives a NEGATIVE logit.
        let mut m = raw.clone();
        m.head = [0; TABLE_LEN];
        m.head[v * D + i] = -5 * s;
        let mut tr2 = Box::new(ModelTrace::zeroed());
        let got = next_token_traced(&toks, &m.build().unwrap(), Some(&mut *tr2)).unwrap();
        assert_eq!(tr2.logits[v], -5 * tr.final_y[i].abs());
        // Every other logit is 0: the lowest index that is not v wins.
        assert_eq!(got, if v == 0 { 1 } else { 0 });
        // Same sign: positive logit, v wins.
        m.head[v * D + i] = 5 * s;
        assert_eq!(run(&toks, &m), Ok(v as u32));
    }
}

#[test]
fn greedy_lowest_index_tie_break() {
    assert_eq!(greedy(&[0; VOCAB]), 0);
    assert_eq!(greedy(&[i64::MIN; VOCAB]), 0);
    assert_eq!(greedy(&[-7; VOCAB]), 0);
    let mut l = [0i64; VOCAB];
    l[19] = 40;
    l[7] = 40;
    l[25] = 39;
    assert_eq!(greedy(&l), 7);
    let mut l = [-100i64; VOCAB];
    l[31] = -99;
    assert_eq!(greedy(&l), 31);
    l[30] = -99;
    assert_eq!(greedy(&l), 30);
    let mut l = [i64::MIN; VOCAB];
    l[12] = i64::MAX;
    l[13] = i64::MAX;
    assert_eq!(greedy(&l), 12);
}

#[test]
fn equal_head_rows_tie_to_lower_index_end_to_end() {
    let raw = synthetic_raw_model();
    let toks = Lcg(8).tokens();
    let mut tr = Box::new(ModelTrace::zeroed());
    next_token_traced(&toks, &raw.build().unwrap(), Some(&mut *tr)).unwrap();
    // Rows 9 and 22 aligned with sign(y): equal positive maxima.
    let mut m = raw.clone();
    m.head = [0; TABLE_LEN];
    for i in 0..D {
        let s = tr.final_y[i].signum() as i8;
        m.head[9 * D + i] = 100 * s;
        m.head[22 * D + i] = 100 * s;
    }
    assert!(tr.final_y.iter().any(|v| *v != 0));
    assert_eq!(run(&toks, &m), Ok(9));
    // All-zero head: every logit ties at 0.
    m.head = [0; TABLE_LEN];
    assert_eq!(run(&toks, &m), Ok(0));
}

// ------------------------------------------------------------ refusals

/// Attention-only block that overflows residual 1 on an all-32767 input:
/// y = 16, V = 8, O = 8, AO = 16 * 8 * 127 / 128 = 127, x1 = 32894.
fn overflowing_block(template: &RawBlock) -> RawBlock {
    let mut b = template.clone();
    b.wq = [0; 256];
    b.wk = [0; 128];
    b.wv = [0; 128];
    for i in 0..8 {
        b.wv[i * D + i] = 64;
    }
    b.wo = [127; 256];
    b.gamma_a = [127; D];
    b.wg_t = [0; 256];
    b.wu_t = [0; 256];
    b.wd_t = [0; 256];
    b
}

#[test]
fn invalid_tokens_refuse_before_computation() {
    let raw = synthetic_raw_model();
    let model = raw.build().unwrap();
    let base = Lcg(1).tokens();
    for bad in [32u32, 33, 1 << 16, u32::MAX] {
        for pos in [0usize, 17, CTX - 1] {
            let mut t = base;
            t[pos] = bad;
            let mut tr = Box::new(ModelTrace::zeroed());
            assert_eq!(next_token_traced(&t, &model, Some(&mut *tr)), Err(ModelError::Token));
            // Nothing was computed into the trace.
            assert!(tr.embedded.iter().all(|v| *v == 0) && tr.logits.iter().all(|v| *v == 0));
        }
    }
    // Token refusal precedes a block that would refuse.
    let mut m = raw.clone();
    m.embed = [32767; TABLE_LEN];
    m.blocks[0] = overflowing_block(&raw.blocks[0]);
    let mut t = base;
    t[3] = VOCAB as u32;
    assert_eq!(run(&t, &m), Err(ModelError::Token));
    assert_eq!(run(&base, &m), Err(ModelError::Layer(0, KernelError::Range("residual 1"))));
}

#[test]
fn fixed_context_length_only() {
    let model = synthetic_model().unwrap();
    let toks = [1u32; CTX + 1];
    for len in [0usize, 1, CTX - 1, CTX + 1] {
        assert_eq!(next_token_slice(&toks[..len], &model, None), Err(ModelError::Shape("tokens")));
    }
    assert!(next_token_slice(&toks[..CTX], &model, None).is_ok());
}

#[test]
fn block_refusals_carry_the_layer() {
    let raw = synthetic_raw_model();
    let mut m = raw.clone();
    m.embed = [32767; TABLE_LEN];
    // Identity block 0 passes 32767 through; block 1 then overflows.
    m.blocks = [identity(&raw.blocks[0]), overflowing_block(&raw.blocks[1])];
    let toks = Lcg(2).tokens();
    let mut tr = Box::new(ModelTrace::zeroed());
    assert_eq!(
        next_token_traced(&toks, &m.build().unwrap(), Some(&mut *tr)),
        Err(ModelError::Layer(1, KernelError::Range("residual 1")))
    );
    assert!(tr.layer0.iter().all(|v| *v == 32767));
    assert!(tr.logits.iter().all(|v| *v == 0));
    // Swap: block 0 refuses first.
    m.blocks.swap(0, 1);
    assert_eq!(run(&toks, &m), Err(ModelError::Layer(0, KernelError::Range("residual 1"))));
}

#[test]
fn construction_shape_and_table_refusals() {
    let raw = synthetic_raw_model();
    let blk = |i: usize| raw.blocks[i].to_block().unwrap();
    let ok = PublicModel::from_parts(&raw.embed, blk(0), blk(1), &raw.gamma_f, &raw.head);
    assert!(ok.is_ok());
    let e = |r: Result<PublicModel, ModelError>| r.err();
    assert_eq!(e(PublicModel::from_parts(&raw.embed[1..], blk(0), blk(1), &raw.gamma_f, &raw.head)), Some(ModelError::Shape("embed")));
    assert_eq!(e(PublicModel::from_parts(&raw.embed, blk(0), blk(1), &raw.gamma_f[..15], &raw.head)), Some(ModelError::Shape("gamma_f")));
    assert_eq!(e(PublicModel::from_parts(&raw.embed, blk(0), blk(1), &raw.gamma_f, &[0; 513])), Some(ModelError::Shape("head")));
    let mut bad = raw.clone();
    bad.blocks[1].exp[0] = 511;
    assert_eq!(e(bad.build()), Some(ModelError::Layer(1, KernelError::Table("exp E[0]"))));
    let mut bad = raw.clone();
    bad.blocks[0].rope_sin[1] = 1;
    assert_eq!(e(bad.build()), Some(ModelError::Layer(0, KernelError::Table("rope position 0"))));
}

#[test]
fn errors_display_without_data() {
    let s = format!("{}", ModelError::Token);
    assert!(!s.chars().any(|c| c.is_ascii_digit()));
    assert_eq!(format!("{}", ModelError::Layer(1, KernelError::Range("residual 1"))), "model block 1 refusal: fixed oracle range refusal: residual 1");
}
