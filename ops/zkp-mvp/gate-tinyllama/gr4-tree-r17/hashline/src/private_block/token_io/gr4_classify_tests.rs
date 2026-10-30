//! [PRIVACY GATE LANE, GATE ROUND 22, 2026-10-29, the gate copy
//! `ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/` of token frozen-r17] TEST-ONLY.
//! A child of `gate19` (`gate19_capture_tests.rs`, itself test-only and not a
//! capture pin), mounted by ONE `#[path]` line at the end of that file. No
//! production file and no pinned file changes.
//!
//! **Not a privacy result and not an acceptance of anything.**
//!
//! **THE STAGE-47 ROOT-REBUILD REPLAY (G-R4 BY VALUE) OF A CLASSIFIER RUN** at
//! the R13 h24 development rung, the port of gate round 10's token replay
//! (`trained-1b-gate-tk9/.../gr4_token_tests.rs`, PR4-8) to
//! `prove_classify_run_with` (`token_io/classify_run.rs:103-217`):
//!
//! 1. The run is proved with `prove_classify_run_with`'s body REPLICATED line
//!    for line on ONE SEEDED generator `ZkRng::new(SEED, DOMAIN)`: stage IN-C
//!    (`stage_in_c::prove`: B_in, A_in, M_in, H_in), each R13 block stage
//!    (B_{k+1} by `boundary::prepare`, then `protocol::prove_core` at the
//!    block's OWN stage shape, then B_k's one opening), stage OUT-C
//!    (`stage_out_c::prove`: A_out, M_out, H_out, then B_out's opening). The
//!    segments are encoded with the production encoders and VERIFIED BY THE
//!    PRODUCTION CLASSIFIER VERIFIER (`verify_classify_run`) from their bytes,
//!    which re-derives every geometry and replays the whole Fiat-Shamir chain:
//!    an inexact replication is refused. Between stages the replica reads a
//!    32-byte PROBE of its generator (the stream position; the receipt does not
//!    depend on it beyond shifting later draws).
//! 2. THE COUNT BY VALUE: for each stage the bytes the prover drew are PREDICTED
//!    by the gate's formula from the stage's geometry alone (a hiding
//!    commitment `(rows - mask_base) * n + rows * Q` field words and `nn` salts;
//!    an H also `2 (n - 1)`; a masking commitment `2 sum L_s + 2 N Q + 8 m` field
//!    words and `dom` salts; 16 bytes per field word, 32 per salt), and a FRESH
//!    seeded generator advanced by exactly the cumulative prediction must give
//!    the prover's probe (16 bytes further must not).
//! 3. THE ROOTS BY VALUE: a second generator on the same seed is cut into the
//!    predicted segments IN THE PREDICTED ORDER and every root is REBUILT from
//!    the witness, the public plane words and that stream (the H rows from the
//!    challenges replayed on the transcript), with `pcs::encode_row_zk`,
//!    `pcs::hash_columns_keyed`, `pcs::salt_leaf_keyed` and
//!    `MerkleTree::build_keyed`, never through the production commit calls:
//!    B_in, A_in, M_in, H_in; per block B_{k+1}, A, M, H; A_out, M_out, H_out.
//!    Each must equal the prover's.
//! 4. NON-VACUITY: five deliberate errors in the PREDICTION each move the
//!    named root(s) and nothing before them.
//! 5. The input endpoint (sealed on its own OS-seeded generator by
//!    `seal_input`) is checked IN SITU: no drawn word or salt repeats.
//!
//! THE CAPTURE RULE: nothing is printed but booleans, counts, labels and
//! seconds; every comparison is `assert!(a == b)`. The seeded receipt is never
//! written (under a public seed its openings are not hiding).

use super::*;
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::merkle::{Digest as MDigest, MerkleTree};
use crate::mle::eq_table_msb;
use crate::ntt::NttTables;
use crate::pcs::{self as hpcs, PcsParams, ZkOpts};
use crate::private_block::boundary::{self as bnd, BoundarySpec};
use crate::private_block::layout::{self as lyt, Dom, Layout};
use crate::private_block::protocol as proto;
use crate::private_block::timing;
use crate::private_block::token_io::stage_in::StageInWitness;
use crate::private_block::token_io::stage_in_c as sin;
use crate::private_block::token_io::stage_out_c as sout;
use crate::private_block::token_io::StageLayout;
use crate::private_block::wire as pwire;
use crate::private_block::witness::Witness;
use crate::sumcheck::CfsMask;
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::transcript::Transcript;
use crate::zk::{ZkRng, MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q};
use rayon::prelude::*;
use zkp_core::hashtag::HashTag;

/// a public TEST seed; production never uses `ZkRng::new`
const SEED: u64 = 0x4752_3443_4c41_5353;
const DOMAIN: &[u8] = b"privacy gate round 22: the seeded G-R4 replay of a classifier run at the R13 h24 rung (test fixture only)";
const BYTE: usize = lyt::U8_LEN;

/// THE REPLAY GENERATOR: the same seeded stream, counting what is drawn
struct Draws {
    rng: ZkRng,
    bytes: u64,
}

impl Draws {
    fn new() -> Draws {
        Draws { rng: ZkRng::new(SEED, DOMAIN), bytes: 0 }
    }
    fn fp(&mut self) -> Fp {
        self.bytes += 16;
        self.rng.fp()
    }
    fn fp2(&mut self) -> Fp2 {
        self.bytes += 32;
        self.rng.fp2()
    }
    fn bytes32(&mut self) -> [u8; 32] {
        self.bytes += 32;
        self.rng.bytes32()
    }
    /// the prover's 32-byte probe between stages, consumed here too
    fn skip_probe(&mut self) {
        let _ = probe(&mut self.rng);
        self.bytes += 32;
    }
}

fn probe(r: &mut ZkRng) -> [u64; 4] {
    [r.next_u64(), r.next_u64(), r.next_u64(), r.next_u64()]
}

fn probe_at(bytes: u64) -> [u64; 4] {
    assert!(bytes % 8 == 0, "a stream position off the 8-byte grid");
    let mut r = ZkRng::new(SEED, DOMAIN);
    for _ in 0..bytes / 8 {
        r.next_u64();
    }
    probe(&mut r)
}

/// `classify_run::position_tag` (private), restated: two challenges squeezed
/// from a discarded clone
fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

// ------------------------------------------------------------------ the formula
/// THE GATE'S COUNT (the formula of `round21/classify_run_counts.py` and D36
/// section 4), from geometry alone: (field words, salts)
fn hiding_count(rows: usize, mask_base: usize, n: usize, q: usize, nn: usize) -> (u64, u64) {
    (((rows - mask_base) * n + rows * q) as u64, nn as u64)
}

fn mask_count(specs: &[(usize, usize)]) -> (u64, u64) {
    let m = 1usize << MASK_LOG_MSG;
    let sum_l: usize = specs.iter().map(|&(nv, d)| CfsMask::len(nv, d)).sum();
    ((2 * sum_l + 2 * specs.len() * MASK_Q + 8 * m) as u64, (1usize << MASK_LOG_DOM) as u64)
}

fn bytes_of(c: (u64, u64)) -> u64 {
    16 * c.0 + 32 * c.1
}

#[derive(Clone, Debug, Default)]
struct StageCount {
    label: String,
    parts: Vec<(String, u64, u64)>,
}

impl StageCount {
    fn add(&mut self, what: &str, c: (u64, u64)) {
        self.parts.push((what.to_string(), c.0, c.1));
    }
    fn bytes(&self) -> u64 {
        self.parts.iter().map(|(_, f, s)| 16 * f + 32 * s).sum()
    }
}

fn boundary_count(spec: &BoundarySpec) -> (u64, u64) {
    let p = spec.params();
    let z = ZkOpts::standard(&p);
    hiding_count(spec.commitment_rows(), spec.data_rows(), 1usize << spec.log_n(), z.q_pad, p.enc_cols())
}

fn stage_count_in(lay: &StageLayout, b0: &BoundarySpec) -> StageCount {
    let z = ZkOpts::standard(&lay.params);
    let nn = lay.params.enc_cols();
    let mut c = StageCount { label: "IN-C".into(), ..Default::default() };
    c.add("B_in", boundary_count(b0));
    c.add("A-in", hiding_count(lay.a_rows, lay.a_mask_base, lay.n, z.q_pad, nn));
    c.add("M-in", mask_count(&lay.mask_specs()));
    let h = hiding_count(lay.h_rows, lay.h_mask_base, lay.n, z.q_pad, nn);
    c.add("H-in", (h.0 + 2 * (lay.n as u64 - 1), h.1));
    c
}

fn stage_count_out(lay: &StageLayout) -> StageCount {
    let z = ZkOpts::standard(&lay.params);
    let nn = lay.params.enc_cols();
    let mut c = StageCount { label: "OUT-C".into(), ..Default::default() };
    c.add("A-out", hiding_count(lay.a_rows, lay.a_mask_base, lay.n, z.q_pad, nn));
    c.add("M-out", mask_count(&lay.mask_specs()));
    let h = hiding_count(lay.h_rows, lay.h_mask_base, lay.n, z.q_pad, nn);
    c.add("H-out", (h.0 + 2 * (lay.n as u64 - 1), h.1));
    c
}

fn stage_count_block(k: usize, ssh: &crate::private_block::shape::Shape, lay: &Layout, spec_next: &BoundarySpec) -> StageCount {
    let params = proto::pcs_params_at(ssh);
    let z = ZkOpts::standard(&params);
    let (n, nn) = (lay.n(), params.enc_cols());
    let mut c = StageCount { label: format!("block {k}"), ..Default::default() };
    c.add(&format!("B_{}", k + 1), boundary_count(spec_next));
    c.add("A", hiding_count(lay.a_rows, lay.a_mask_base, n, z.q_pad, nn));
    c.add("M", mask_count(&lay.mask_specs()));
    let h = hiding_count(lay.h_rows, lay.h_mask_base, n, z.q_pad, nn);
    c.add("H", (h.0 + 2 * (n as u64 - 1), h.1));
    c
}

// --------------------------------------------------------------- the rebuilders
/// `pcs::commit_zk_owned_with_tag`'s root, rebuilt WITHOUT calling it: pads
/// (`rows * q`) then salts (`nn`) from `rp`
fn zk_root(params: &PcsParams, data: &[Fp], rows: usize, rp: &mut Draws, ntt: &NttTables, tag: &HashTag) -> MDigest {
    let zko = ZkOpts::standard(params);
    let (n, nn, q) = (params.cols(), params.enc_cols(), zko.q_pad);
    assert!(data.len() == rows * n, "the rebuilt matrix is not rows x n");
    let pads: Vec<Fp> = (0..rows * q).map(|_| rp.fp()).collect();
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rp.bytes32()).collect();
    let pows = hpcs::coset_powers(zko.coset, nn);
    let mut enc = vec![Fp::ZERO; rows * nn];
    enc.par_chunks_mut(nn).enumerate().for_each(|(r, out)| hpcs::encode_row_zk(ntt, &data[r * n..(r + 1) * n], &pads[r * q..(r + 1) * q], &pows, out));
    let leaves = hpcs::hash_columns_keyed(&enc, rows, nn, tag.column_key());
    let salted: Vec<MDigest> = leaves.iter().zip(salts.iter()).map(|(l, s)| hpcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    MerkleTree::build_keyed(salted, tag.node_key()).root()
}

/// `zk::mask_commit_tagged`'s root on a caller's stream: every alpha first,
/// then per row half its pads, then b / u (b[m] := -b[0]), then the salts
fn mask_root_on(rp: &mut Draws, specs: &[(usize, usize)], ntt: &NttTables, tag: &HashTag, alpha_copy: bool) -> MDigest {
    let (m, dom) = (1usize << MASK_LOG_MSG, 1usize << MASK_LOG_DOM);
    let mut alphas: Vec<Vec<Fp2>> = specs.iter().map(|&(nv, d)| (0..CfsMask::len(nv, d)).map(|_| rp.fp2()).collect()).collect();
    if alpha_copy {
        alphas[1][0] = alphas[0][0];
    }
    let n_base = 2 * specs.len() + 4;
    let pows_m = hpcs::coset_powers(Fp::new(7), dom);
    let enc_coeffs = |c: &[Fp], out: &mut [Fp]| {
        for v in out.iter_mut() {
            *v = Fp::ZERO;
        }
        for (i, x) in c.iter().enumerate() {
            out[i] = x.mul(pows_m[i]);
        }
        ntt.forward(out);
    };
    let mut enc = vec![Fp::ZERO; n_base * dom];
    for (s, al) in alphas.iter().enumerate() {
        let re: Vec<Fp> = al.iter().map(|c| c.c0).collect();
        let im: Vec<Fp> = al.iter().map(|c| c.c1).collect();
        for (kk, part) in [re, im].iter().enumerate() {
            assert!(part.len() + MASK_Q <= m, "the prediction's mask row overflows");
            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            for j in 0..MASK_Q {
                msg[part.len() + j] = rp.fp();
            }
            ntt.inverse(&mut msg);
            enc_coeffs(&msg, &mut enc[(2 * s + kk) * dom..(2 * s + kk + 1) * dom]);
        }
    }
    let mut b_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let mut b_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    b_re[m] = b_re[0].neg();
    b_im[m] = b_im[0].neg();
    let u_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let u_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let base0 = 2 * specs.len();
    for (kk, c) in [&b_re, &b_im, &u_re, &u_im].iter().enumerate() {
        enc_coeffs(c, &mut enc[(base0 + kk) * dom..(base0 + kk + 1) * dom]);
    }
    let salts: Vec<[u8; 32]> = (0..dom).map(|_| rp.bytes32()).collect();
    let leaves = hpcs::hash_columns_keyed(&enc, n_base, dom, tag.column_key());
    let salted: Vec<MDigest> = leaves.iter().zip(salts.iter()).map(|(l, s)| hpcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    MerkleTree::build_keyed(salted, tag.node_key()).root()
}

/// `boundary::prepare`'s root on a caller's stream: the plane, then the mask
/// rows, pads and salts
fn boundary_root_on(rp: &mut Draws, spec: &BoundarySpec, vals: &[Fp], ntt: &NttTables, tag: &HashTag) -> MDigest {
    let (rows, data, n) = (spec.commitment_rows(), spec.data_rows(), 1usize << spec.log_n());
    let mut d = vec![Fp::ZERO; rows * n];
    d[..vals.len()].copy_from_slice(vals);
    for x in d[data * n..].iter_mut() {
        *x = rp.fp();
    }
    zk_root(&spec.params(), &d, rows, rp, ntt, tag)
}

fn write_h2(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

fn zero_sum_rows(h: &mut [Fp], rows: [usize; 2], n: usize, rp: &mut Draws) {
    for r in rows {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 {
            let v = rp.fp();
            h[r * n + j] = v;
            sum = sum.add(v);
        }
        h[r * n + n - 1] = sum.neg();
    }
}

fn inv(mut den: Vec<Fp2>) -> Vec<Fp2> {
    batch_inverse2_checked(&mut den).expect("an honest witness has no zero LogUp denominator");
    den
}

fn words16(v: &[i16]) -> Vec<Fp> {
    v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect()
}

/// one deliberate error in the PREDICTION
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Pert {
    None,
    /// A_in's first proximity-row word := 0
    InAProxZero,
    /// B_in predicted AFTER A_in
    BinAfterAin,
    /// block 0's H zero-sum rows from a stream reset
    Block0ZeroSumReset,
    /// M_out's slot 1 first coefficient := slot 0's
    OutAlphaCopy,
    /// the probe before stage OUT-C not skipped (a 32-byte stream offset)
    NoProbeBeforeOut,
}

/// THE STAGE IN-C PREDICTION: (B_in, A_in, M_in, H_in) on the caller's stream,
/// from the stage witness, the B_in plane and the transcript at the stage's
/// start (`stage_in_c::prove` absorbs the stage words itself)
#[allow(clippy::too_many_arguments)]
fn predict_in(rp: &mut Draws, cp: &ClassifierProfile, tables: &ClassifierTables, lay: &StageLayout, wit: &StageInWitness, b_spec: &BoundarySpec, b_plane: &[i16], stage_tr: &Transcript, ntt: &NttTables, tag: &HashTag, pert: Pert) -> [MDigest; 4] {
    let n = lay.n;
    let (ti_n, voc_n) = (1usize << cp.ti_log(), 1usize << cp.voc_log());
    let mut tr = Transcript::clone_state(stage_tr);
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &cp.emb_digest);
    let b_words = words16(b_plane);
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    a[lay.a_off[sin::A_TOK]..lay.a_off[sin::A_TOK] + ti_n].copy_from_slice(&wit.tok);
    a[lay.a_off[sin::A_MULT]..lay.a_off[sin::A_MULT] + voc_n].copy_from_slice(&wit.mult);
    let a_part = |rp: &mut Draws, a: &mut Vec<Fp>| -> MDigest {
        for x in a[lay.a_mask_base * n..].iter_mut() {
            *x = rp.fp();
        }
        if pert == Pert::InAProxZero {
            a[lay.a_prox * n] = Fp::ZERO;
        }
        zk_root(&lay.params, a, lay.a_rows, rp, ntt, tag)
    };
    let (b_root, a_root) = if pert == Pert::BinAfterAin {
        let ar = a_part(rp, &mut a);
        (boundary_root_on(rp, b_spec, &b_words, ntt, tag), ar)
    } else {
        let br = boundary_root_on(rp, b_spec, &b_words, ntt, tag);
        (br, a_part(rp, &mut a))
    };
    proto::absorb_root(&mut tr, b"B", &b_root, b_spec.commitment_rows(), b_spec.log_n());
    proto::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, lay.log_n);
    let m_root = mask_root_on(rp, &lay.mask_specs(), ntt, tag, false);
    tr.absorb(b"M", &m_root);
    // `stage_in_c::challenges` (private), restated
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let r_emb = tr.challenge_fp2_vec(cp.d_pad.trailing_zeros() as usize);
    let g_emb = gamma.mul_base(Fp::new(crate::private_block::token_io::TAG_EMB));
    let ef = tables.emb_fold(&r_emb);
    let tau = sin::tau_table(cp, &ef, beta, g_emb);
    let b2 = beta.mul(beta);
    let e_r = eq_table_msb(&r_emb);
    let mut h_q = vec![Fp2::ZERO; ti_n];
    for t in 0..cp.tokens {
        if wit.hq_zero.contains(&t) {
            continue;
        }
        let row = &b_plane[t * cp.d_pad..(t + 1) * cp.d_pad];
        let xr = row.iter().zip(e_r.iter()).fold(Fp2::ZERO, |acc, (x, e)| if *x == 0 { acc } else { acc.add(e.mul_base(Fp::from_i64(i64::from(*x)))) });
        let cq = if cp.ctl_q(t) { b2 } else { Fp2::ZERO };
        let q = Fp2::from_base(wit.tok[t]).add(beta.mul(xr)).add(cq).add(g_emb);
        h_q[t] = alpha.sub(q).inv();
    }
    let mut h_tab = vec![Fp2::ZERO; voc_n];
    for v in 0..voc_n {
        if !wit.mult[v].is_zero() {
            h_tab[v] = alpha.sub(tau[v]).inv().mul_base(wit.mult[v]);
        }
    }
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    write_h2(&mut h, lay.h_off[sin::H_Q], &h_q);
    write_h2(&mut h, lay.h_off[sin::H_TAB], &h_tab);
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    zero_sum_rows(&mut h, lay.h_u_rows(), n, rp);
    let h_root = zk_root(&lay.params, &h, lay.h_rows, rp, ntt, tag);
    [b_root, a_root, m_root, h_root]
}

/// THE R13 BLOCK PREDICTION: (A, M, H) of one block stage on the caller's
/// stream, `protocol::prove_core`'s R13 construction restated (non-DD), from
/// the witness and the transcript at the block body's start (after B_{k+1})
#[allow(clippy::too_many_arguments)]
fn predict_block(rp: &mut Draws, sh: &crate::private_block::shape::Shape, lay: &Layout, blk: &BlockPublic, stage_tr: &Transcript, wit: &Witness, ntt: &NttTables, zero_sum_reset: bool) -> [MDigest; 3] {
    assert!(sh.dd_cap == 0, "the rung replay is non-DD");
    let data = blk.accuracy().expect("an R13 block carries its accuracy data");
    let public = blk.attention();
    let (ids, hids, n) = (lay.ids(), lay.hids(), lay.n());
    let params = proto::pcs_params_at(sh);
    assert!(params.cols() == n, "the PCS row width is not the layout's");
    let tag = sh.hash_tag();
    // ---- A ----
    let committed: Vec<usize> = lay.a_planes().into_iter().filter(|p| !ids.is_multiplicity(*p)).collect();
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    for p in &committed {
        for (i, v) in wit.planes[*p].iter().enumerate() {
            a[lay.a_off[*p] + i] = Fp::from_i64(*v);
        }
    }
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, proto::lookup_values(lay, wit, *d))).collect();
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    let m_u8 = proto::byte_histogram_at(&looked, lookup_words, proto::HISTOGRAM_PAR_MIN);
    let deltas = proto::exp_deltas(lay, wit);
    let mut m_exp = vec![0u64; BYTE];
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..BYTE as i64).contains(d) && public.exp[*d as usize] == wit.planes[ids.at(lyt::A_E)][x];
        m_exp[if hit { *d as usize } else { 0 }] += 1;
    }
    let (m_act, act_missed) = crate::private_block::accuracy_act::histogram(sh, data, &wit.planes[ids.at(lyt::A_G8)], &wit.planes[ids.at(lyt::A_A16)]).expect("the ACT3 histogram");
    assert!(act_missed == 0, "an honest witness misses no ACT3 row");
    for i in 0..BYTE {
        a[lay.a_off[ids.at(lyt::A_MU8)] + i] = Fp::new(m_u8[i]);
        a[lay.a_off[ids.at(lyt::A_MEXP)] + i] = Fp::new(m_exp[i]);
    }
    for (i, &count) in m_act.iter().enumerate() {
        a[lay.a_off[ids.at(lyt::A_MACT)] + i] = Fp::new(count);
    }
    for x in a[lay.a_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    let a_root = zk_root(&params, &a, lay.a_rows, rp, ntt, &tag);
    // ---- M ----
    let m_root = mask_root_on(rp, &lay.mask_specs(), ntt, &tag, false);
    // ---- H: the LogUp rows from the challenges replayed on the transcript ----
    let mut tr = Transcript::clone_state(stage_tr);
    proto::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &m_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(TAG_ACT));
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    let u8_inv = proto::u8_denominator_inverses(alpha, g_u8);
    for (d, cols) in &looked {
        let (first, count) = lay.helpers(*d);
        for kk in 0..count {
            let col = match cols.get(2 * kk + 1) {
                Some(second) => proto::helper_pair_inverses_u8(&cols[2 * kk], second, alpha, g_u8, &u8_inv),
                None => proto::helper_inverses_u8(&cols[2 * kk], alpha, g_u8, &u8_inv),
            }
            .expect("an honest witness's helper column");
            write_h2(&mut h, lay.h_off[first + kk], &col);
        }
    }
    let exp_den: Vec<Fp2> = deltas.iter().zip(wit.planes[ids.at(lyt::A_E)].iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h2(&mut h, lay.h_off[hids.sexp()], &inv(exp_den));
    let act_den: Vec<Fp2> = crate::private_block::accuracy_act::query_values(sh, data, &wit.planes[ids.at(lyt::A_G8)], &wit.planes[ids.at(lyt::A_A16)], beta, g_act)
        .expect("the ACT3 queries")
        .into_iter()
        .map(|q| alpha.sub(q))
        .collect();
    write_h2(&mut h, lay.h_off[hids.fact()], &inv(act_den));
    let [gu8, gexp, gact] = hids.table_helpers();
    let act_table = {
        let t = crate::private_block::accuracy_act::table(data, sh.size(Dom::Tab), beta, g_act).expect("the ACT3 table");
        t.compressed[..t.entries].to_vec()
    };
    for (plane, tv, mm) in [
        (gu8, crate::private_block::argument::table_values_u8(g_u8), &m_u8),
        (gexp, crate::private_block::argument::table_values_exp(public, beta, g_exp), &m_exp),
        (gact, act_table, &m_act),
    ] {
        let iv = inv(tv.iter().map(|t| alpha.sub(*t)).collect());
        let col: Vec<Fp2> = iv.iter().zip(mm.iter()).map(|(x, c)| x.mul_base(Fp::new(*c))).collect();
        write_h2(&mut h, lay.h_off[plane], &col);
    }
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    if zero_sum_reset {
        let mut fresh = Draws::new();
        zero_sum_rows(&mut h, lay.h_u_rows(), n, &mut fresh);
        let mut sink = vec![Fp::ZERO; lay.h_rows * n];
        zero_sum_rows(&mut sink, lay.h_u_rows(), n, rp);
    } else {
        zero_sum_rows(&mut h, lay.h_u_rows(), n, rp);
    }
    let h_root = zk_root(&params, &h, lay.h_rows, rp, ntt, &tag);
    [a_root, m_root, h_root]
}

/// `stage_out_c`'s private `looked` / `byte_columns` / `helper_col`, restated
fn looked_cols(planes: &[Vec<Fp>], lks: &[sout::Lk], n: usize) -> Vec<Vec<Fp>> {
    lks.iter().map(|lk| (0..n).map(|x| lk.terms.iter().fold(Fp::from_i64(lk.cst), |a, (p, c)| a.add(Fp::from_i64(*c).mul(planes[*p][x])))).collect()).collect()
}

fn helper_col2(a: &[Fp], b: Option<&[Fp]>, alpha: Fp2, g: Fp2) -> Vec<Fp2> {
    let iv = |x: Fp| alpha.sub(Fp2::from_base(x).add(g)).inv();
    (0..a.len()).map(|i| match b {
        Some(bb) => iv(a[i]).add(iv(bb[i])),
        None => iv(a[i]),
    }).collect()
}

/// THE STAGE OUT-C PREDICTION: (A_out, M_out, H_out) on the caller's stream
#[allow(clippy::too_many_arguments)]
fn predict_out(rp: &mut Draws, cp: &ClassifierProfile, lay: &StageLayout, wit: &sout::StageOutCWitness, stage_index: u64, stage_tr: &Transcript, ntt: &NttTables, tag: &HashTag, alpha_copy: bool) -> [MDigest; 3] {
    let n = lay.n;
    let mut tr = Transcript::clone_state(stage_tr);
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &cp.w_digest);
    let cols: Vec<Vec<Fp>> = [(sout::lookups_lo(), cp.lo_log()), (sout::lookups_do(), cp.do_log())].iter().flat_map(|(lks, lg)| looked_cols(&wit.planes, lks, 1usize << lg)).collect();
    let mut hist = vec![0u64; BYTE];
    for c in &cols {
        for v in c {
            assert!((v.0 as usize) < BYTE, "an honest stage-OUT-C witness looks up a byte");
            hist[v.0 as usize] += 1;
        }
    }
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    for p in 0..sout::C_MULT {
        a[lay.a_off[p]..lay.a_off[p] + wit.planes[p].len()].copy_from_slice(&wit.planes[p]);
    }
    for (i, c) in hist.iter().enumerate() {
        a[lay.a_off[sout::C_MULT] + i] = Fp::new(*c);
    }
    for x in a[lay.a_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    let a_root = zk_root(&lay.params, &a, lay.a_rows, rp, ntt, tag);
    proto::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, lay.log_n);
    let m_root = mask_root_on(rp, &lay.mask_specs(), ntt, tag, alpha_copy);
    tr.absorb(b"M", &m_root);
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    let mut ci = 0usize;
    for (first, count) in [(sout::H_LO, 1usize), (sout::H_D0, sout::H_DO_HELPERS)] {
        let dom_cols = if first == sout::H_LO { 1 } else { sout::lookups_do().len() };
        for kk in 0..count {
            let a_col = &cols[ci + 2 * kk];
            let b_col = if 2 * kk + 1 < dom_cols { Some(cols[ci + 2 * kk + 1].as_slice()) } else { None };
            write_h2(&mut h, lay.h_off[first + kk], &helper_col2(a_col, b_col, alpha, g_u8));
        }
        ci += dom_cols;
    }
    let tcol: Vec<Fp2> = (0..1usize << cp.tab_log())
        .map(|z| {
            let m = if z < BYTE { hist[z] } else { 0 };
            if m == 0 {
                Fp2::ZERO
            } else {
                alpha.sub(Fp2::from_i64((z % BYTE) as i64).add(g_u8)).inv().mul_base(Fp::new(m))
            }
        })
        .collect();
    write_h2(&mut h, lay.h_off[sout::H_GU8], &tcol);
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    zero_sum_rows(&mut h, lay.h_u_rows(), n, rp);
    let h_root = zk_root(&lay.params, &h, lay.h_rows, rp, ntt, tag);
    [a_root, m_root, h_root]
}

// ------------------------------------------------------------------ the replica
struct Seeded {
    segs: Vec<Vec<u8>>,
    /// the prover's roots: IN-C [B_in, A, M, H], per block [B_{k+1}, A, M, H], OUT-C [A, M, H]
    roots_in: [MDigest; 4],
    roots_blocks: Vec<[MDigest; 4]>,
    roots_out: [MDigest; 3],
    /// the prover's probe after each stage (IN-C, blocks, OUT-C)
    probes: Vec<[u64; 4]>,
    /// the transcript at each stage's start (IN-C, OUT-C) and at each block body's start
    tr_in: Transcript,
    tr_blocks: Vec<Transcript>,
    tr_out: Transcript,
    win: StageInWitness,
    b_in_plane: Vec<i16>,
    planes: Vec<Vec<i16>>,
    wits: Vec<Witness>,
    wout: sout::StageOutCWitness,
}

/// `prove_classify_run_with`'s body (`classify_run.rs:146-217`) REPLICATED on
/// ONE seeded generator, a 32-byte probe after each stage
fn seeded_run(st: &ClassifyRunStatement, blocks: &[BlockPublic], tables: &BoundClassifierTables, p: &mut HonestClassify, owner: hpcs::CommittedZk) -> Seeded {
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let tbl = tables.tables();
    let mut src = ClassifySource(p);
    let (win, b_in_plane) = src.stage_in().unwrap();
    let wout = src.stage_out().unwrap();
    let out_lay = sout::layout(sh, cp);
    let mut rng = ZkRng::new(SEED, DOMAIN);
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript().unwrap();
    let binding = tr.state();
    let mut segs = Vec::new();
    let mut probes = Vec::new();
    // ---- stage IN-C
    let start = position_tag(&tr);
    let in_lay = sin::layout(sh, cp);
    let b0 = st.boundary_spec(0).unwrap();
    let tr_in = Transcript::clone_state(&tr);
    let inp = sin::prove(&in_lay, cp, tbl, win.clone(), &b0, &b_in_plane, owner, &ntt, &mut rng, &mut tr, &tag).unwrap();
    let end = position_tag(&tr);
    segs.push(st.in_geom(&in_lay).encode(&inp.seg, &binding, &start, &end).unwrap());
    let roots_in = [inp.b_owner.root(), inp.seg.a_root, inp.seg.mask_root, inp.seg.h_root];
    probes.push(probe(&mut rng));
    let mut pending = inp.pending_b;
    let mut prev = (b0, inp.b_owner);
    let (mut roots_blocks, mut tr_blocks, mut planes, mut wits) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    // ---- the blocks
    for k in 0..l {
        let start = position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let blk = &blocks[k];
        let spec = st.boundary_spec(k + 1).unwrap();
        let plane = src.boundary_plane(k).unwrap();
        assert!(plane.len() == spec.len(), "boundary plane length");
        let cur = bnd::prepare(&spec, &words16(&plane), &ntt, &mut rng, &tag).unwrap();
        proto::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        let lay = st.block_layout(k).unwrap();
        let ssh = st.stage_shape(k).unwrap();
        let wit = src.witness(k, blk, &ssh).unwrap();
        wits.push(wit.clone());
        planes.push(plane);
        tr_blocks.push(Transcript::clone_state(&tr));
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = std::time::Instant::now();
        let core = proto::prove_core(&ssh, &lay, blk, wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).unwrap();
        let block_roots = [cur.root(), core.a_root, core.mask_root, core.h_root];
        let [ic, oc] = core.io_claims;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, powner) = prev;
        let in_open = powner.into_opening(&pspec, &claims, &mut tr).unwrap();
        pending = oc;
        let end = position_tag(&tr);
        let seg = pwire::Segment { b_root: Some(cur.root()), a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: None };
        segs.push(pwire::encode_segment(&seg, &lay, st.block_geom(k).unwrap(), &binding, &start, &end).unwrap());
        drop(seg);
        roots_blocks.push(block_roots);
        prev = (spec, cur);
        probes.push(probe(&mut rng));
    }
    // ---- stage OUT-C
    let start = position_tag(&tr);
    let (bspec, bowner) = prev;
    let tr_out = Transcript::clone_state(&tr);
    let outp = sout::prove(&out_lay, cp, tbl, wout.clone(), st.verdict(), &bspec, bowner, pending, (l + 1) as u64, &ntt, &mut rng, &mut tr, &tag).unwrap();
    let end = position_tag(&tr);
    segs.push(st.out_geom(&out_lay).unwrap().encode(&outp.seg, &binding, &start, &end).unwrap());
    let roots_out = [outp.seg.a_root, outp.seg.mask_root, outp.seg.h_root];
    probes.push(probe(&mut rng));
    Seeded { segs, roots_in, roots_blocks, roots_out, probes, tr_in, tr_blocks, tr_out, win, b_in_plane, planes, wits, wout }
}

/// the prediction of the whole run on ONE replay stream: per stage its roots
#[allow(clippy::type_complexity)]
fn predict_run(st: &ClassifyRunStatement, blocks: &[BlockPublic], tables: &BoundClassifierTables, s: &Seeded, pert: Pert) -> ([MDigest; 4], Vec<[MDigest; 4]>, [MDigest; 3], Vec<u64>) {
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut rp = Draws::new();
    let mut ends = Vec::new();
    let in_lay = sin::layout(sh, cp);
    let b0 = st.boundary_spec(0).unwrap();
    let r_in = predict_in(&mut rp, cp, tables.tables(), &in_lay, &s.win, &b0, &s.b_in_plane, &s.tr_in, &ntt, &tag, pert);
    ends.push(rp.bytes);
    rp.skip_probe();
    let mut r_blocks = Vec::new();
    for k in 0..l {
        let spec = st.boundary_spec(k + 1).unwrap();
        let b = boundary_root_on(&mut rp, &spec, &words16(&s.planes[k]), &ntt, &tag);
        let ssh = st.stage_shape(k).unwrap();
        let lay = st.block_layout(k).unwrap();
        let [a, m, h] = predict_block(&mut rp, &ssh, &lay, &blocks[k], &s.tr_blocks[k], &s.wits[k], &ntt, pert == Pert::Block0ZeroSumReset && k == 0);
        r_blocks.push([b, a, m, h]);
        ends.push(rp.bytes);
        if !(pert == Pert::NoProbeBeforeOut && k + 1 == l) {
            rp.skip_probe();
        }
    }
    let out_lay = sout::layout(sh, cp);
    let r_out = predict_out(&mut rp, cp, &out_lay, &s.wout, (l + 1) as u64, &s.tr_out, &ntt, &tag, pert == Pert::OutAlphaCopy);
    ends.push(rp.bytes);
    (r_in, r_blocks, r_out, ends)
}

/// every drawn field value of the input endpoint owner (its rows above the
/// data row, then the pads) and its salts, read in situ
fn endpoint_drawn(e: &hpcs::CommittedZk, data_rows: usize) -> (Vec<u64>, Vec<[u8; 32]>) {
    let rows = e.cm.rows;
    let n = e.data.len() / rows;
    let mut v: Vec<u64> = e.data[data_rows * n..].iter().map(|x| x.0).collect();
    v.extend(e.pads.iter().map(|x| x.0));
    (v, e.salts.clone())
}

fn distinct<V: Ord + Clone>(mut v: Vec<V>) -> bool {
    let n = v.len();
    v.sort();
    v.dedup();
    v.len() == n
}

/// ONE configuration: the R13 rung at L blocks, a verdict and a chunk
fn replay_classify(label: &str, l: usize, want: &str, chunk: Option<(usize, usize)>) {
    let t0 = std::time::Instant::now();
    let fxdir = FxDir(fixture_root().join(format!("gate22-gr4-fx-{}-{}", std::process::id(), FX_SEQ.fetch_add(1, std::sync::atomic::Ordering::SeqCst))));
    let _ = std::fs::remove_dir_all(&fxdir.0);
    std::fs::create_dir_all(&fxdir.0).unwrap();
    // ---- the fixture, as `r13_honest_run` builds it (the proving step replaced)
    let base = policy_rung_dev();
    let fx0 = r13_bind(&fxdir.0, &base, l);
    let sh = fx0.seed.clone();
    let size = sh.tokens - base.prefix.len() - base.suffix.len();
    let (total, index) = chunk.unwrap_or((size, 0));
    let mut whole = content(&base, total.min(size), 0x6361_7031);
    if total > size {
        whole.extend(content(&base, total - size, 0x6361_7032));
    }
    let ch = ChunkRef::derive(total, index, ChunkPlan { size, overlap: chunk_overlap_of(RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST).unwrap() }).expect("the chunk");
    let n = ch.b - ch.a;
    let shapes: Vec<BlockShape> = fx0.model.layers.iter().map(|r| r.shape_at(&sh).unwrap()).collect();
    let cp0 = ClassifierProfile::new(&sh, fx0.bound.tables(), fx0.bound.bos(), fx0.bound.norm(), &base, n, Tier::R1_MVP).unwrap();
    let tokens = cp0.tokens_of(&whole[ch.a..ch.b]).unwrap();
    let margin = honest_classify(&shapes, &cp0, fx0.bound.tables(), &fx0.blocks, &tokens).expect("the honest R13 pipeline").out_values.margin;
    let c = match want {
        "1" => margin - 1,
        "tie" => margin,
        _ => margin + 1,
    };
    let mut policy = base.clone();
    policy.id = format!("r13-rung-capture-test-policy/{c}");
    policy.c = c;
    register_test_policy(policy.clone());
    let fx = r13_bind(&fxdir.0, &policy, l);
    let cp = ClassifierProfile::new(&sh, fx.bound.tables(), fx.bound.bos(), fx.bound.norm(), &policy, n, Tier::R1_MVP).unwrap();
    let mut p = honest_classify(&shapes, &cp, fx.bound.tables(), &fx.blocks, &tokens).expect("the honest R13 pipeline under the placed c");
    let verdict = p.out_values.verdict;
    let spec = input_endpoint_spec(&sh, ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &p.in_plane, &sh.hash_tag()).unwrap();
    let (ep_vals, ep_salts) = endpoint_drawn(&owner, owner.cm.rows - crate::private_block::endpoint_g::MASK_ROWS);
    let digests: Vec<Digest> = fx.model.layers.iter().map(|r| r.block_digest).collect();
    let st = ClassifyRunStatement::new_chunk(RunShape::new(sh.clone(), l, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST).unwrap(), ctx(), digests, &fx.model, &fx.bound, &policy, n, Tier::R1_MVP, root, verdict, total, index).expect("the statement");
    let gates: Vec<Option<u32>> = (0..l).map(|k| st.stage_gate(k)).collect();
    // ---- 1. the seeded replica, verified by the production verifier
    let t1 = std::time::Instant::now();
    let s = seeded_run(&st, &fx.blocks, &fx.bound, &mut p, owner);
    let prove_s = t1.elapsed().as_secs_f64();
    let t2 = std::time::Instant::now();
    let verified = verify_classify_run(&st, &fx.blocks, &fx.bound, &s.segs, POLICY_93).is_ok();
    let verify_s = t2.elapsed().as_secs_f64();
    assert!(verified, "the production classifier verifier refuses the seeded replica (an inexact replication)");
    // ---- 2. the count by value, per stage
    let in_lay = sin::layout(st.sh(), &st.cp);
    let out_lay = sout::layout(st.sh(), &st.cp);
    let mut counts = vec![stage_count_in(&in_lay, &st.boundary_spec(0).unwrap())];
    for k in 0..l {
        counts.push(stage_count_block(k, &st.stage_shape(k).unwrap(), &st.block_layout(k).unwrap(), &st.boundary_spec(k + 1).unwrap()));
    }
    counts.push(stage_count_out(&out_lay));
    let mut cum = 0u64;
    let mut count_ok = Vec::new();
    for (i, c) in counts.iter().enumerate() {
        cum += c.bytes();
        let at = probe_at(cum);
        let ok = at == s.probes[i] && probe_at(cum + 16) != s.probes[i];
        count_ok.push(ok);
        cum += 32; // the probe itself
    }
    // ---- 3. the roots by value
    let (r_in, r_blocks, r_out, ends) = predict_run(&st, &fx.blocks, &fx.bound, &s, Pert::None);
    let in_eq: Vec<bool> = (0..4).map(|i| r_in[i] == s.roots_in[i]).collect();
    let blk_eq: Vec<Vec<bool>> = (0..l).map(|k| (0..4).map(|i| r_blocks[k][i] == s.roots_blocks[k][i]).collect()).collect();
    let out_eq: Vec<bool> = (0..3).map(|i| r_out[i] == s.roots_out[i]).collect();
    // the replay's own consumption equals the formula, stage by stage
    let mut cum2 = 0u64;
    let mut replay_matches_formula = Vec::new();
    for (i, c) in counts.iter().enumerate() {
        cum2 += c.bytes();
        replay_matches_formula.push(ends[i] == cum2);
        cum2 += 32;
    }
    // ---- 4. non-vacuity
    let mut nv = Vec::new();
    for (pert, what) in [
        (Pert::InAProxZero, "A_in"),
        (Pert::BinAfterAin, "B_in and A_in"),
        (Pert::Block0ZeroSumReset, "block 0's H"),
        (Pert::OutAlphaCopy, "M_out"),
        (Pert::NoProbeBeforeOut, "A_out, M_out and H_out"),
    ] {
        let (pi, pb, po, _) = predict_run(&st, &fx.blocks, &fx.bound, &s, pert);
        let moved = match pert {
            Pert::InAProxZero => pi[1] != s.roots_in[1] && pi[0] == s.roots_in[0],
            Pert::BinAfterAin => pi[0] != s.roots_in[0] && pi[1] != s.roots_in[1],
            Pert::Block0ZeroSumReset => pb[0][3] != s.roots_blocks[0][3] && pb[0][1] == s.roots_blocks[0][1] && pb[0][2] == s.roots_blocks[0][2],
            Pert::OutAlphaCopy => po[1] != s.roots_out[1] && po[0] == s.roots_out[0],
            Pert::NoProbeBeforeOut => po[0] != s.roots_out[0] && po[1] != s.roots_out[1] && po[2] != s.roots_out[2] && pb.iter().zip(s.roots_blocks.iter()).all(|(x, y)| x == y),
            Pert::None => unreachable!(),
        };
        nv.push((what, moved));
    }
    // ---- 5. the input endpoint in situ
    let ep_ok = distinct(ep_vals.clone()) && distinct(ep_salts.clone());
    // ---- report (counts, booleans, seconds only)
    let line = |c: &StageCount| c.parts.iter().map(|(w, f, sa)| format!("{w} {f} fp + {sa} salts")).collect::<Vec<_>>().join("; ");
    eprintln!("GR4 CLASSIFY replay [{label}: R13 h24 rung, L {l}, gates {gates:?}, n {n}, verdict {verdict}]: the production classifier verifier accepts the seeded replica = {verified}; {} segments", s.segs.len());
    for (i, c) in counts.iter().enumerate() {
        eprintln!("GR4 CLASSIFY replay [{label}]: stage {} ({}): predicted {} bytes = {} [{}]; prover consumed exactly that (probe) = {}; the replay stream consumed exactly that = {}", i, c.label, c.bytes(), c.parts.iter().map(|(_, f, sa)| 16 * f + 32 * sa).map(|b| b.to_string()).collect::<Vec<_>>().join(" + "), line(c), count_ok[i], replay_matches_formula[i]);
    }
    eprintln!("GR4 CLASSIFY replay [{label}]: IN-C roots rebuilt B_in/A_in/M_in/H_in = {in_eq:?}; block roots B_k+1/A/M/H = {blk_eq:?}; OUT-C roots A_out/M_out/H_out = {out_eq:?}");
    for (what, moved) in &nv {
        eprintln!("GR4 CLASSIFY replay [{label}]: non-vacuity moves {what} (and nothing earlier) = {moved}");
    }
    eprintln!("GR4 CLASSIFY replay [{label}]: the input endpoint in situ: {} drawn words and {} salts, pairwise distinct = {ep_ok}", ep_vals.len(), ep_salts.len());
    let total_bytes: u64 = counts.iter().map(|c| c.bytes()).sum();
    let total_fp: u64 = counts.iter().map(|c| c.parts.iter().map(|x| x.1).sum::<u64>()).sum();
    let total_salts: u64 = counts.iter().map(|c| c.parts.iter().map(|x| x.2).sum::<u64>()).sum();
    eprintln!("GR4 CLASSIFY replay [{label}]: run total (the run stream; the input endpoint is on its own generator): {total_fp} fp draws + {total_salts} salts = {total_bytes} bytes");
    let all = verified && count_ok.iter().all(|x| *x) && replay_matches_formula.iter().all(|x| *x) && in_eq.iter().all(|x| *x) && blk_eq.iter().flatten().all(|x| *x) && out_eq.iter().all(|x| *x) && nv.iter().all(|x| x.1) && ep_ok;
    eprintln!("GR4 CLASSIFY replay [{label}]: {}. seconds: seeded prove {prove_s:.2}, production verify {verify_s:.2}, whole test {:.2} [MEASURED, shared box, n=1]. Not a privacy result.", if all { "PASS" } else { "FAIL" }, t0.elapsed().as_secs_f64());
    assert!(all, "the G-R4 classifier replay failed (see the lines above)");
}

#[test]
#[ignore = "gate round 22: the seeded G-R4 replay of an R13-rung classifier run; set HL_R13_LOADER_FIXTURES"]
fn gr4_classify_r13_rung_l2_v1_whole_commits_exactly_the_predicted_stream() {
    replay_classify("L2 v1 whole", 2, "1", None);
}

#[test]
#[ignore = "gate round 22: the seeded G-R4 replay of an R13-rung classifier run; set HL_R13_LOADER_FIXTURES"]
fn gr4_classify_r13_rung_l2_v0_short1_commits_exactly_the_predicted_stream() {
    replay_classify("L2 v0 short n=1", 2, "0", Some((1, 0)));
}

#[test]
#[ignore = "gate round 22: the seeded G-R4 replay of an R13-rung classifier run; set HL_R13_LOADER_FIXTURES"]
fn gr4_classify_r13_rung_l1_vtie_whole_commits_exactly_the_predicted_stream() {
    replay_classify("L1 tie whole", 1, "tie", None);
}
