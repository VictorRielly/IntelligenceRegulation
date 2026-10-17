//! **REVIEWER SCRATCH, D24 review ROUND 3 (2026-10-17).** Test code only.
//!
//! * `r3_1` (fast): R2-a closed — a non-door shape under a trained string,
//!   a frozen shape edited to f_e 50 / a 25-bit window.
//! * `r3_2` (fast): two-block bound run at the trained rung: the external
//!   endpoints sealed from words OTHER than the proved chain's are rejected
//!   by the VERIFIER (input lie, output lie, a different chain under the
//!   export's endpoints).
//! * `r3_3` (fast): CS-6 at the library level — the generic run verifier
//!   given blocks whose digests are not the statement's.

use super::layout::*;
use super::shape::{Shape, TRAINED_CALIB_RUNG_PROFILE};
use super::trained_calib_tests::{run_shape_for, rung_tc_calibration, synthetic_statement, trained_dense_words, TRAINED_BANDS};
use super::witness::{self, Witness};
use super::*;

#[test]
fn r3_1_r2a_is_closed() {
    for f_e in [50u32, 12] {
        let sh = Shape::new("reviewer: non-door", TRAINED_CALIB_RUNG_PROFILE, 32, 384, 512, 12, 32, 4, 10, 4, f_e, 21, None, None, None, None).expect("Shape::new");
        let l = Layout::for_shape(&sh);
        eprintln!("REVIEW-R3-1 non-door trained-string shape f_e {f_e}: Layout {}; single-block {:?}", match &l { Ok(_) => "ACCEPTED".into(), Err(e) => format!("refused: {}", e.chars().take(100).collect::<String>()) }, super::protocol::single_block_profile_allowed(&sh).err().map(|e| e.chars().take(60).collect::<String>()));
        assert!(l.is_err());
    }
    let mut c6 = Shape::rung_c6();
    c6.f_e = 50;
    c6.wrho_s = 55;
    let e = Layout::for_shape(&c6).err().expect("a frozen shape edited to f_e 50 got a layout");
    eprintln!("REVIEW-R3-1 frozen rung-C6 edited to f_e 50: refused: {}", e.chars().take(120).collect::<String>());
}

/// block k's padded output plane
fn out_plane(sh: &Shape, w: &Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    w.planes[ids.at(A_X2)].iter().map(|v| *v as i16).collect()
}
fn in_plane(sh: &Shape, w: &Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    w.planes[ids.at(A_X)].iter().map(|v| *v as i16).collect()
}
fn true_words(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// a chained witness source: block k is built on the previous block's output
/// (block 0 on `x0`)
struct Chain<'a> {
    sh: &'a Shape,
    blocks: &'a [BlockPublic],
    x: Vec<i16>,
    cached: Option<(usize, Witness)>,
    next: usize,
}

impl<'a> Chain<'a> {
    fn advance(&mut self, k: usize) -> Result<(Witness, Vec<i16>), String> {
        assert_eq!(k, self.next);
        let w = witness::build_shaped(self.sh, self.blocks[k].attention(), self.blocks[k].feed_forward(), &self.x)?;
        let o = out_plane(self.sh, &w);
        self.x = true_words(self.sh, &o);
        self.next += 1;
        Ok((w, o))
    }
}

impl super::run::RunWitnessSource for Chain<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        match self.cached.take() {
            Some((j, w)) if j == k => Ok(w),
            _ => self.advance(k).map(|(w, _)| w),
        }
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        let (w, o) = self.advance(k)?;
        self.cached = Some((k, w));
        Ok(o)
    }
}

fn two_blocks(sh: &Shape) -> (Vec<BlockPublic>, Vec<i16>) {
    let (w0, x) = trained_dense_words(sh, TRAINED_BANDS);
    let mut blocks = Vec::new();
    for k in 0..2usize {
        let mut w = w0.clone();
        for (i, m) in w.iter_mut().enumerate() {
            let len = m.len();
            m.rotate_left((k * (7 + i)) % len);
        }
        let (public, ff) = super::dense_tests::statement_of_words(sh, &w);
        blocks.push(BlockPublic::new(public, ff));
    }
    (blocks, x)
}

/// prove a 2-block bound run whose witnesses are the chain on `x_chain`,
/// with external endpoints sealed from `(seal_in, seal_out)`, statement over
/// `stmt_blocks`, prover blocks `prove_blocks`; verify with `verify_blocks`
fn attempt(sh: &Shape, stmt_blocks: &[BlockPublic], prove_blocks: &[BlockPublic], verify_blocks: &[BlockPublic], x_chain: &[i16], seal_in: &[i16], seal_out: &[i16]) -> Result<(), String> {
    let ctx = *blake3::hash(b"review r3-2").as_bytes();
    let spec = IoSpec::new_shaped(sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, seal_in, seal_out)?;
    let st = super::run::RunStatement::new_bound(run_shape_for(sh, 2), ctx, expected.clone(), stmt_blocks, &[(0, 0), (0, 0)], &synthetic_statement(sh, stmt_blocks))?;
    let mut src = Chain { sh, blocks: prove_blocks, x: x_chain.to_vec(), cached: None, next: 0 };
    let mut segs: Vec<Vec<u8>> = Vec::new();
    super::run::prove_run(&st, prove_blocks, &mut src, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .map_err(|e| format!("prover: {e}"))?;
    super::run::verify_run(&st, verify_blocks, &segs).map_err(|e| format!("verifier: {e}"))
}

/// the padded honest chain: (input plane, block-0 out, block-1 out)
fn honest_chain(sh: &Shape, blocks: &[BlockPublic], x: &[i16]) -> (Vec<i16>, Vec<i16>, Vec<i16>) {
    let w0 = witness::build_shaped(sh, blocks[0].attention(), blocks[0].feed_forward(), x).unwrap();
    let (i0, o0) = (in_plane(sh, &w0), out_plane(sh, &w0));
    let w1 = witness::build_shaped(sh, blocks[1].attention(), blocks[1].feed_forward(), &true_words(sh, &o0)).unwrap();
    (i0, o0, out_plane(sh, &w1))
}

#[test]
fn r3_2_the_verifier_binds_the_chain_to_the_sealed_endpoints() {
    let sh = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    let (blocks, x) = two_blocks(&sh);
    let (pin, _o0, pout) = honest_chain(&sh, &blocks, &x);
    attempt(&sh, &blocks, &blocks, &blocks, &x, &pin, &pout).expect("the honest two-block run verifies");
    eprintln!("REVIEW-R3-2 honest two-block bound run: verifies");
    // (a) the input endpoint sealed from other words (one word moved)
    let mut bad_in = pin.clone();
    bad_in[sh.d_pad + 5] = bad_in[sh.d_pad + 5].wrapping_add(1);
    let e = attempt(&sh, &blocks, &blocks, &blocks, &x, &bad_in, &pout).err().expect("an input endpoint that is not block 0's input VERIFIED");
    eprintln!("REVIEW-R3-2 input endpoint one word off: {}", e.chars().take(150).collect::<String>());
    // (b) the output endpoint sealed from other words
    let mut bad_out = pout.clone();
    bad_out[2 * sh.d_pad + 7] = bad_out[2 * sh.d_pad + 7].wrapping_add(1);
    let e = attempt(&sh, &blocks, &blocks, &blocks, &x, &pin, &bad_out).err().expect("an output endpoint that is not the last block's output VERIFIED");
    eprintln!("REVIEW-R3-2 output endpoint one word off: {}", e.chars().take(150).collect::<String>());
    // (c) a DIFFERENT chain (another hidden input) proved under the export's endpoints
    let mut x2 = x.clone();
    x2[3] = x2[3].wrapping_add(17);
    let e = attempt(&sh, &blocks, &blocks, &blocks, &x2, &pin, &pout).err().expect("a different chain under the export's endpoints VERIFIED");
    eprintln!("REVIEW-R3-2 a different chain under the sealed endpoints: {}", e.chars().take(150).collect::<String>());
    // (d) the different chain with ITS OWN endpoints: verifies (the prover seals; D18)
    let (pin2, _, pout2) = honest_chain(&sh, &blocks, &x2);
    attempt(&sh, &blocks, &blocks, &blocks, &x2, &pin2, &pout2).expect("the second honest chain with its own endpoints verifies");
    eprintln!("REVIEW-R3-2 a different honest chain with its own endpoints: verifies (expected: the prover seals, D18)");
}

/// **CS-6 at the library level.** The statement names blocks A; the prover
/// and the verifier are both handed blocks B (one gain word moved). Does the
/// generic run verifier check `blocks[k].digest() == statement digest`?
#[test]
fn r3_3_cs6_the_run_verifier_and_the_statements_block_digests() {
    let sh = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    let (a, x) = two_blocks(&sh);
    // B: block 1's gamma_a word 0 moved (the padded statement keeps its support)
    let mut b = a.clone();
    {
        let at = b[1].attention().clone();
        let mut gamma = at.gamma_a.clone();
        gamma[0] = if gamma[0] == 127 { 126 } else { gamma[0] + 1 };
        let pubb = AttentionPublic::new_shaped(&sh, &at.wq, &at.wk, &at.wv, &at.wo, &gamma, &at.rope_cos, &at.rope_sin, &at.exp).unwrap();
        b[1] = BlockPublic::new(pubb, b[1].feed_forward().clone());
    }
    assert_ne!(a[1].digest(), b[1].digest());
    let (pin, _, pout) = honest_chain(&sh, &b, &x);
    let r_bb = attempt(&sh, &a, &b, &b, &x, &pin, &pout);
    eprintln!(
        "REVIEW-R3-3 statement over blocks A, prover AND verifier handed blocks B (block 1 differs): {}",
        match &r_bb { Ok(()) => "ACCEPTED (the generic verifier does not check blocks[k].digest() against the statement)".to_string(), Err(e) => format!("rejected: {}", e.chars().take(150).collect::<String>()) }
    );
    let r_ba = attempt(&sh, &a, &b, &a, &x, &pin, &pout);
    eprintln!("REVIEW-R3-3 same proof, verifier handed the statement's blocks A: {}", match &r_ba { Ok(()) => "ACCEPTED".to_string(), Err(e) => format!("rejected: {}", e.chars().take(150).collect::<String>()) });
}
