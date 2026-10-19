//! [PRIVACY GATE LANE, 2026-10-19, R7 gate copy] the R5b gate copy's module
//! (with round 6's Q-6 L = 2 replay), every proved stage under
//! `RunStatement::stage_shape(k)` as NATIVE R6's `prove_run_with` does.
//! [PRIVACY GATE LANE, 2026-10-18] copied from the P-12 sub-lane's
//! `ops/zkp-mvp/trained-1b-gate-gr4/` with every `super::` path rewritten to
//! `crate::private_block::` (mounted under `run_capture_tests`, see there).
//! **PRIVACY GATE LANE, SUB-LANE P-12 (2026-10-17): the stage-47 G-R4
//! root-rebuild check (ruling LW-2), PORTED to the trained TinyLlama T32
//! tree** — finding P-12 of the independent privacy review
//! (`results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`). Source:
//! the 125M lane's `private_block/gr4_check_tests.rs` (stage 47). TEST-ONLY:
//! no prover or verifier relation, no production file and no production byte
//! changes; the only other edit is this module's `mod` line.
//!
//! **Not a privacy result and not an acceptance of anything.** It machine-
//! checks one owed condition (G-R4's value-level half) on the witnesses it
//! runs; only the security review process can accept, and rulings are
//! Victor's.
//!
//! **WHAT IS ASSERTED, BY VALUE, NOT BY SOURCE TEXT** (as at stage 47):
//!
//! 1. `protocol::prove_core` — the body every proving path shares — runs on
//!    a SEEDED generator `ZkRng::new(SEED, DOMAIN)` and its receipt is
//!    verified.
//! 2. A SECOND generator on the same seed is cut into the eleven predicted
//!    segments IN THE PREDICTED ORDER, and the three committed matrices are
//!    REBUILT from the witness and those segments: `A` (witness rows and the
//!    three histograms, segment 1 row-major into `a_mask_base..a_rows`,
//!    segment 2 pads, segment 3 salts), `M` (segment 4 the 23 `alpha`
//!    vectors, 5 the per-row pads, 6 `b` and `u` with the ONE declared
//!    relation `b[m] := -b[0]`, 7 the salts) and `H` (the LogUp rows from the
//!    witness and the challenges replayed on the transcript, segment 8 into
//!    `h_mask_base..h_rows`, segment 9 into the two zero-sum rows with the
//!    declared closing entry, 10 pads, 11 salts). Encoding and hashing are
//!    rebuilt with `pcs::encode_row_zk`, `pcs::hash_columns_keyed`,
//!    `pcs::salt_leaf_keyed` and `MerkleTree::build_keyed` — NOT through
//!    `pcs::commit_zk_owned_tagged` (whose host path in this tree is the new
//!    `encode_buffer::encode_rows`) nor `zk::mask_commit_tagged`.
//! 3. The three rebuilt ROOTS equal the prover's, and the replay generator
//!    ends where the prover's did.
//! 4. Three deliberate errors in the PREDICTION (m1's, m2's and the `alpha`
//!    analogue) each move their root (non-vacuity).
//! 5. The two endpoint owners (OS-seeded, cannot be replayed) are checked
//!    IN SITU: no drawn field value or salt repeats inside or across them.
//! 6. The internal boundary `B_0` of a two-block trained run, at the run's
//!    own `boundary_spec(0)` (22 rows = 16 data + 2x2 sites + 2, row width
//!    2^12, rate 4, the trained keyed tag), is rebuilt from a seeded stream,
//!    with one non-vacuity perturbation (site 1's first reserved word :=
//!    site 0's).
//!
//! **THE ADAPTATIONS, AND WHY (the 125M file cannot run here as written).**
//!
//! * A trained-calibration profile refuses a single-block receipt (R2-4:
//!   `protocol::single_block_profile_allowed`; `protocol::transcript` asserts
//!   it), so `verify_inner_at` and the single-block header are unavailable.
//!   The block is proved as a ONE-BLOCK BOUND RUN built through the
//!   production constructors the trained CLI and the gate capture use
//!   (`TrainedExport::load / run_constants / shape_for / load_layer /
//!   statement_of_records / load_seq`, `IoSpec::new_shaped`,
//!   `prepare_endpoints`, `RunStatement::new_bound`).
//! * `RunStatement::transcript`, `stage_layout`, `seg_geom` and
//!   `run::position_tag` are private to `run.rs`. The run header is REBUILT
//!   here from the statement's public words (`RunStatement::capture_header`,
//!   test-only, as the run capture does) and asserted equal to the binding
//!   (`RunStatement::binding`). Stage 0 of `prove_run_with` is replicated
//!   line for line (`run.rs:884-967` at L = 1: the position tag, the two
//!   locality absorbs, the stage layout `[data rows; 2]`, `prove_core`, the
//!   input then the output endpoint opening, the end tag, the segment). The
//!   segment is encoded by `wire::encode_segment` and VERIFIED BY THE
//!   PRODUCTION RUN VERIFIER `run::verify_run` from its bytes, which compares
//!   both position tags and replays the whole Fiat-Shamir chain — so an
//!   inexact replication of the run prover's transcript would be refused.
//! * This tree's `ZkRng` has no `consumed_bytes()` (the 125M lane added one
//!   to its zkp-core, a separate crate whose `cfg(test)` is off here). "Ends
//!   where the prover's did" is therefore checked by a NEXT-DRAW PROBE: the
//!   next 32 bytes of the prover's and of the replay generator must be equal;
//!   and a FRESH generator advanced by exactly the prediction's COUNTED bytes
//!   must give the prover's probe (so the prover consumed exactly that many
//!   bytes), while one advanced 16 bytes further must not (non-vacuity).
//!   Equal probes at unequal positions of a BLAKE3-XOF stream occur with
//!   negligible probability.
//!
//! **WHAT IT DOES NOT COVER.** (a) Uses of drawn values OUTSIDE the three
//! commitments (the slot argument's reads of `alpha` and of the reserved
//! pairs): bound by the verifier, which accepts here; that is soundness, not
//! this check. (b) The endpoint generators (`from_os`, unseedable): in situ
//! and order-blind only. (c) A run of L >= 2: `prove_run_with`'s stage loop
//! (B_k drawn from the run stream before A_k, the B_{k-1} opening) is NOT
//! replayed; the boundary preparer is checked alone on a seeded stream.
//! (d) The production entry `prove_run` itself (OS randomness) is not called;
//! stage 0 is replicated, and the production verifier accepting its segment
//! is the evidence that the replication is the run prover's. (e) One layer
//! (0), one sequence (ho00) and the all-zero input; the CPU host path only
//! (no `gpu-cuda` feature in this build).
//!
//! **LW-4's note, carried forward to this tree [READ]:** `CfsMask` derives
//! `Clone` (zkp-core/src/sumcheck.rs) and `CommittedZk`'s `data`, `pads` and
//! `salts` are `pub` (zkp-core/src/pcs.rs). The in-situ endpoint check below
//! reads those `pub` fields; a production path that copied a mask or owner
//! would not be visible to the source scans for the same reason.
//!
//! **THE CAPTURE RULE.** Nothing is printed but booleans, counts, labels and
//! wall-clock seconds: no drawn value, no seed-derived word, no root, no key,
//! no hidden value (every comparison is `assert!(a == b)`, never
//! `assert_eq!`, so a failure does not print a root or a probe either). The
//! seeded receipt is NEVER written anywhere: under a public seed its openings
//! are not hiding.

use crate::private_block::layout::*;
use crate::private_block::protocol;
use crate::private_block::run::{self, RunStatement};
use crate::private_block::shape::Shape;
use crate::private_block::trained_block::TrainedExport;
use crate::private_block::wire::{self, SegGeom, Segment};
use crate::private_block::witness::{self, Witness};
use crate::private_block::{prepare_endpoints, BlockPublic, IoSpec};
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::merkle::{Digest, MerkleTree};
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, ZkOpts};
use crate::sumcheck::CfsMask;
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::transcript::Transcript;
use crate::zk::{ZkRng, MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q};
use rayon::prelude::*;
use std::path::PathBuf;
use std::time::Instant;
use zkp_core::hashtag::HashTag;

/// a public TEST seed; production never uses `ZkRng::new`
const SEED: u64 = 0x5031_3247_5234_5452;
const DOMAIN: &[u8] = b"privacy gate P-12: the seeded G-R4 value-level replay at the trained TinyLlama T32 shape (test fixture only)";
/// the export layer the block test proves (the boundary test uses 0 | 1)
const LAYER: u32 = 0;
/// the export's held-out sequence: the DENSE (generic, real) witness
const SEQ: &str = "ho00";

/// one deliberate error in the PREDICTION, used to show the root comparison
/// is sensitive to exactly the relations a source scan cannot see
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Pert {
    None,
    /// m1's analogue: overwrite A's first proximity-row word after the fill
    AProxZero,
    /// m2's analogue: copy A's first reserved-pair word into H's first reserved word
    CopyAIntoH,
    /// the `alpha` analogue: slot 1's first CFS coefficient := slot 0's
    AlphaCopy,
}

fn export_dir() -> PathBuf {
    match std::env::var("HL_PB_EXPORT") {
        Ok(v) => PathBuf::from(v),
        Err(_) => PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32"),
    }
}

/// the fixture's public context word (nonzero, as a run requires)
fn context() -> Digest {
    *blake3::hash(b"privacy gate P-12: G-R4 trained replay fixture context").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` words inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// a TRUE `(tokens, width)` plane placed into the padded `(t_pad, d_pad)` cube
fn pad_cube(sh: &Shape, x: &[i16]) -> Vec<i16> {
    let mut out = vec![0i16; sh.t_pad * sh.d_pad];
    for t in 0..sh.tokens {
        out[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&x[t * sh.width..(t + 1) * sh.width]);
    }
    out
}

fn words(v: &[i16]) -> Vec<Fp> {
    v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect()
}

/// the NTT domain a run builds (`RunShape::ntt_log`, private to run.rs)
fn run_ntt_log(sh: &Shape) -> u32 {
    protocol::ntt_log_at(sh).max((sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize) as u32)
}

/// `run::position_tag` (private to run.rs), restated: two challenges squeezed
/// from a discarded clone
fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// The run header, REBUILT from the statement's public words in the order
/// `RunStatement::transcript` absorbs them (the run capture's own recipe,
/// `run_capture::begin_run_with`). The caller compares it with the binding.
fn rebuilt_header(st: &RunStatement) -> Transcript {
    let h = st.capture_header().expect("the run's public header words");
    let mut tr = protocol::tagged_transcript(&h.sh, h.profile.as_bytes());
    let mut shape_bytes = Vec::with_capacity(8 * h.run_shape_words.len());
    for v in &h.run_shape_words {
        shape_bytes.extend_from_slice(&v.to_le_bytes());
    }
    tr.absorb(b"run-shape", &shape_bytes);
    tr.absorb(b"expected-IO", &h.expected_bytes);
    tr.absorb(b"public-statement", &h.public_statement);
    tr.absorb(b"parameters", h.parameter_line.as_bytes());
    tr.absorb(b"calibration", &h.calibration);
    tr.absorb(b"schedule", &h.schedule_digest);
    tr
}

/// THE REPLAY GENERATOR: the same seeded stream, counting what the
/// prediction draws (16 bytes per field word, 32 per extension word or salt)
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
}

/// the next 32 bytes of a generator (compared, never printed)
fn probe(r: &mut ZkRng) -> [u64; 4] {
    [r.next_u64(), r.next_u64(), r.next_u64(), r.next_u64()]
}

/// the probe of a FRESH seeded generator advanced by exactly `bytes`
fn probe_at(bytes: u64) -> [u64; 4] {
    assert!(bytes % 8 == 0, "a stream position off the 8-byte grid");
    let mut r = ZkRng::new(SEED, DOMAIN);
    for _ in 0..bytes / 8 {
        r.next_u64();
    }
    probe(&mut r)
}

/// `pcs::commit_zk_owned_with_tag`'s root, rebuilt WITHOUT calling it: the
/// pads (`rows * q` field draws) then the salts (`nn` 32-byte draws) are
/// taken from `rp`, each row is encoded with `encode_row_zk` (rows in
/// parallel: each row is independent and nothing is drawn here), and the
/// salted keyed tree is built from the leaves
fn zk_root(params: &PcsParams, data: &[Fp], rows: usize, rp: &mut Draws, ntt: &NttTables, tag: &HashTag) -> Digest {
    let zko = ZkOpts::standard(params);
    let (n, nn, q) = (params.cols(), params.enc_cols(), zko.q_pad);
    assert!(data.len() == rows * n, "the rebuilt matrix is not rows x n");
    let pads: Vec<Fp> = (0..rows * q).map(|_| rp.fp()).collect();
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rp.bytes32()).collect();
    let pows = pcs::coset_powers(zko.coset, nn);
    let mut enc = vec![Fp::ZERO; rows * nn];
    enc.par_chunks_mut(nn).enumerate().for_each(|(r, out)| pcs::encode_row_zk(ntt, &data[r * n..(r + 1) * n], &pads[r * q..(r + 1) * q], &pows, out));
    let leaves = pcs::hash_columns_keyed(&enc, rows, nn, tag.column_key());
    let salted: Vec<Digest> = leaves.iter().zip(salts.iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    MerkleTree::build_keyed(salted, tag.node_key()).root()
}

fn inv(mut den: Vec<Fp2>) -> Vec<Fp2> {
    batch_inverse2_checked(&mut den).expect("an honest witness has no zero LogUp denominator");
    den
}

fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

struct Rebuilt {
    a_root: Digest,
    m_root: Digest,
    h_root: Digest,
    /// the bytes the prediction drew, counted
    bytes: u64,
    /// the replay generator's next 32 bytes after the prediction
    probe: [u64; 4],
}

/// THE PREDICTION: the three committed matrices of one stage from (witness,
/// the eleven predicted segments of the replayed stream, in the predicted
/// order). `stage_tr` is the transcript at the stage's first commitment
/// (after the run header and the two locality words), rebuilt from public
/// words; only the three LogUp challenges are read from it.
fn rebuild(sh: &Shape, lay: &Layout, blk: &BlockPublic, stage_tr: &Transcript, wit: &Witness, ntt: &NttTables, pert: Pert) -> Rebuilt {
    let mut rp = Draws::new();
    let (a_root, m_root, h_root) = rebuild_on(&mut rp, sh, lay, blk, stage_tr, wit, ntt, pert);
    let bytes = rp.bytes;
    Rebuilt { a_root, m_root, h_root, bytes, probe: probe(&mut rp.rng) }
}

/// [ROUND 6, review round 2 Q-6] THE PREDICTION of one stage on a CALLER's
/// replay stream, so that a run's boundary and its stages are drawn from ONE
/// stream in the predicted order (`replay_trained_run_l2`). `rebuild` above is
/// this on a fresh stream; its body is unchanged apart from taking `rp`.
#[allow(clippy::too_many_arguments)]
fn rebuild_on(rp: &mut Draws, sh: &Shape, lay: &Layout, blk: &BlockPublic, stage_tr: &Transcript, wit: &Witness, ntt: &NttTables, pert: Pert) -> (Digest, Digest, Digest) {
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let (ids, hids, n) = (lay.ids(), lay.hids(), lay.n());
    let params = protocol::pcs_params_at(sh);
    assert!(params.cols() == n, "the PCS row width is not the layout's");
    let tag = sh.hash_tag();

    // ---- A's witness rows: `prove_core`'s own construction, restated ----
    let committed: Vec<usize> = lay.a_planes().into_iter().filter(|p| !ids.is_multiplicity(*p)).collect();
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    for p in &committed {
        for (i, v) in wit.planes[*p].iter().enumerate() {
            a[lay.a_off[*p] + i] = Fp::from_i64(*v);
        }
    }
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, protocol::lookup_values(lay, wit, *d))).collect();
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    let m_u8 = protocol::byte_histogram_at(&looked, lookup_words, protocol::HISTOGRAM_PAR_MIN);
    let deltas = protocol::exp_deltas(lay, wit);
    let mut m_exp = vec![0u64; U8_LEN];
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(d) && public.exp[*d as usize] == wit.planes[ids.at(A_E)][x];
        m_exp[if hit { *d as usize } else { 0 }] += 1;
    }
    let act_idx = protocol::act_indices(lay, wit);
    let mut m_act = vec![0u64; U8_LEN];
    for (x, i) in act_idx.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(i) && i64::from(ff.act[*i as usize]) == wit.planes[ids.at(A_A16)][x];
        m_act[if hit { *i as usize } else { 0 }] += 1;
    }
    for i in 0..U8_LEN {
        a[lay.a_off[ids.at(A_MU8)] + i] = Fp::new(m_u8[i]);
        a[lay.a_off[ids.at(A_MEXP)] + i] = Fp::new(m_exp[i]);
        a[lay.a_off[ids.at(A_MACT)] + i] = Fp::new(m_act[i]);
    }
    // ---- segment 1: A's reserved pairs and proximity pair, row-major ----
    for x in a[lay.a_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    if pert == Pert::AProxZero {
        a[lay.a_prox * n] = Fp::ZERO;
    }
    // ---- segments 2, 3: A's pads, then A's salts ----
    let a_root = zk_root(&params, &a, lay.a_rows, rp, ntt, &tag);

    // ---- segments 4-7: M, every word of it ----
    let specs = lay.mask_specs();
    let (m, dom) = (1usize << MASK_LOG_MSG, 1usize << MASK_LOG_DOM);
    let mut alphas: Vec<Vec<Fp2>> = specs.iter().map(|&(nv, d)| (0..CfsMask::len(nv, d)).map(|_| rp.fp2()).collect()).collect();
    if pert == Pert::AlphaCopy {
        alphas[1][0] = alphas[0][0];
    }
    let n_base = 2 * specs.len() + 4;
    let pows_m = pcs::coset_powers(Fp::new(7), dom);
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
        for (k, part) in [re, im].iter().enumerate() {
            assert!(part.len() + MASK_Q <= m, "the prediction's mask row overflows");
            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            for j in 0..MASK_Q {
                msg[part.len() + j] = rp.fp();
            }
            ntt.inverse(&mut msg);
            enc_coeffs(&msg, &mut enc[(2 * s + k) * dom..(2 * s + k + 1) * dom]);
        }
    }
    let mut b_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let mut b_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    // the ONE declared relation on M
    b_re[m] = b_re[0].neg();
    b_im[m] = b_im[0].neg();
    let u_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let u_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let base0 = 2 * specs.len();
    for (k, c) in [&b_re, &b_im, &u_re, &u_im].iter().enumerate() {
        enc_coeffs(c, &mut enc[(base0 + k) * dom..(base0 + k + 1) * dom]);
    }
    let m_salts: Vec<[u8; 32]> = (0..dom).map(|_| rp.bytes32()).collect();
    let m_leaves = pcs::hash_columns_keyed(&enc, n_base, dom, tag.column_key());
    let m_salted: Vec<Digest> = m_leaves.iter().zip(m_salts.iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    let m_root = MerkleTree::build_keyed(m_salted, tag.node_key()).root();

    // ---- H's LogUp rows: the challenges replayed on the stage transcript ----
    let mut tr = Transcript::clone_state(stage_tr);
    protocol::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &m_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(TAG_ACT));
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    let u8_inv = protocol::u8_denominator_inverses(alpha, g_u8);
    for (d, cols) in &looked {
        let (first, count) = lay.helpers(*d);
        for k in 0..count {
            let col = match cols.get(2 * k + 1) {
                Some(second) => protocol::helper_pair_inverses_u8(&cols[2 * k], second, alpha, g_u8, &u8_inv),
                None => protocol::helper_inverses_u8(&cols[2 * k], alpha, g_u8, &u8_inv),
            }
            .expect("an honest witness's helper column");
            write_h(&mut h, lay.h_off[first + k], &col);
        }
    }
    let exp_den: Vec<Fp2> = deltas.iter().zip(wit.planes[ids.at(A_E)].iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h(&mut h, lay.h_off[hids.sexp()], &inv(exp_den));
    let act_den: Vec<Fp2> = act_idx.iter().zip(wit.planes[ids.at(A_A16)].iter()).map(|(i, x)| alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*x))).add(g_act))).collect();
    write_h(&mut h, lay.h_off[hids.fact()], &inv(act_den));
    let [gu8, gexp, gact] = hids.table_helpers();
    for (plane, tv, mm) in [
        (gu8, crate::private_block::argument::table_values_u8(g_u8), &m_u8),
        (gexp, crate::private_block::argument::table_values_exp(public, beta, g_exp), &m_exp),
        (gact, crate::private_block::argument::table_values_act(ff, beta, g_act), &m_act),
    ] {
        let iv = inv(tv.iter().map(|t| alpha.sub(*t)).collect());
        let col: Vec<Fp2> = iv.iter().zip(mm.iter()).map(|(x, c)| x.mul_base(Fp::new(*c))).collect();
        write_h(&mut h, lay.h_off[plane], &col);
    }
    // ---- segment 8: H's reserved pairs and proximity pair, row-major ----
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    if pert == Pert::CopyAIntoH {
        h[lay.h_mask_base * n] = a[lay.a_mask_base * n];
    }
    // ---- segment 9: the two zero-sum rows, n - 1 draws each, declared closing entry ----
    for r in lay.h_u_rows() {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 {
            let v = rp.fp();
            h[r * n + j] = v;
            sum = sum.add(v);
        }
        h[r * n + n - 1] = sum.neg();
    }
    // ---- segments 10, 11: H's pads, then H's salts ----
    let h_root = zk_root(&params, &h, lay.h_rows, rp, ntt, &tag);
    (a_root, m_root, h_root)
}

/// every drawn field value one REAL endpoint owner holds (the mask rows above
/// the shape's data rows, then the pads), and its salts — read in situ
fn endpoint_drawn(sh: &Shape, e: &pcs::CommittedZk) -> (Vec<u64>, Vec<[u8; 32]>) {
    let (rows, data, _) = protocol::endpoint_geometry(sh).expect("the endpoint geometry");
    let n = e.data.len() / rows;
    assert!(n * rows == e.data.len(), "the endpoint owner's matrix is not rows x n");
    let mut v: Vec<u64> = e.data[data * n..].iter().map(|x| x.0).collect();
    v.extend(e.pads.iter().map(|x| x.0));
    (v, e.salts.clone())
}

fn assert_pairwise_distinct<V: Ord + Clone>(what: &str, mut v: Vec<V>) -> usize {
    let len = v.len();
    v.sort();
    let dup = v.windows(2).filter(|w| w[0] == w[1]).count();
    assert!(dup == 0, "{what}: {dup} repeated drawn value(s) among {len}: a copy or a reuse (an honest draw repeats with probability < len^2 / 2^65)");
    len
}

/// the whole check on ONE trained block: a one-block BOUND run whose stage 0
/// is proved on the seeded stream and verified by the production run
/// verifier; the in-situ endpoint check; the rebuild and comparison; the
/// three perturbations; the probe's own non-vacuity
fn replay_trained_block(dense: bool) {
    let label = if dense { "TinyLlama-trained T32 layer 0, dense ho00 (generic witness)" } else { "TinyLlama-trained T32 layer 0, all-zero input (degenerate partner)" };
    let t_all = Instant::now();
    let ex = TrainedExport::load(&export_dir()).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = [LAYER];
    let c = ex.run_constants(&layers).expect("the run-level constants");
    let sh = ex.shape_for(&c).expect("the trained shape (through the door)");
    assert!(sh.trained_calibration, "the export did not build a trained-calibration shape");
    let single_refused = protocol::single_block_profile_allowed(&sh).is_err();
    assert!(single_refused, "the trained profile no longer refuses a single-block receipt (R2-4); this port's one-block-run adaptation would be unnecessary");
    let t = ex.load_layer(&sh, &c, LAYER, false).unwrap_or_else(|e| panic!("layer {LAYER}: {e}"));
    let blocks = vec![t.blk];
    let model = ex.statement_of_records(&sh, &c, vec![t.record]).expect("the trained-model statement");

    // ---- the witness: the export's real hidden input, or the all-zero plane ----
    let x0 = if dense { ex.load_seq(&sh, SEQ, LAYER).expect("the export's hidden input").0 } else { vec![0i16; sh.tokens * sh.width] };
    let wit = witness::build_shaped(&sh, blocks[0].attention(), blocks[0].feed_forward(), &x0).expect("the honest trained witness");
    let ids = Ids::new(&sh).expect("the trained shape has a plane map");
    let (x_in, x_out) = (padded(&wit, ids.at(A_X)), padded(&wit, ids.at(A_X2)));
    let mut parity_words = 0usize;
    if dense {
        let (_, want) = ex.load_seq(&sh, SEQ, LAYER).expect("the export's reference output");
        let got = true_input(&sh, &x_out);
        let differ = got.iter().zip(want.iter()).filter(|(a, b)| a != b).count();
        assert!(got.len() == want.len() && differ == 0, "parity: layer {LAYER}'s native output differs from the export's x_out in {differ} of {} words (no value printed)", got.len());
        parity_words = got.len();
    }

    // ---- the bound ONE-BLOCK run statement, through the production constructors ----
    let spec = IoSpec::new_shaped(&sh, context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &x_in, &x_out).expect("the run's external endpoint owners");
    let rs = ex.geometry.run_shape(&sh, 1).expect("the trained run shape");
    let st = RunStatement::new_bound(rs, context(), expected.clone(), &blocks, &[(0, 0)], &model).expect("the bound run statement");
    let data_rows = st.rs().data_rows();
    // the stage layout of stage 0 of a one-block run: slot 21 and slot 22 at
    // the external endpoints' terminal pair (`in_site(0)`, `out_site(0)`)
    // [R7 gate copy] NATIVE R6: a stage is proved under `RunStatement::stage_shape(k)`
    let ssh = st.stage_shape(0).expect("stage 0's shape");
    let lay = Layout::for_shape(&ssh).expect("the shape has a layout").with_io_mask_rows([data_rows, data_rows]);

    // ---- the endpoint generators, IN SITU (they cannot be seeded) ----
    let [ein, eout] = protocol::check_endpoints(&sh, &expected, owners).expect("the endpoint owners match the statement");
    let (vi, si) = endpoint_drawn(&sh, &ein);
    let (vo, so) = endpoint_drawn(&sh, &eout);
    let fields = assert_pairwise_distinct(&format!("{label}: the two endpoint owners' drawn field values"), [vi, vo].concat());
    let salts = assert_pairwise_distinct(&format!("{label}: the two endpoint owners' salts"), [si, so].concat());

    // ---- the run header, rebuilt from public words, must be the binding ----
    let binding = st.binding().expect("the run binding");
    let mut tr = rebuilt_header(&st);
    let header_ok = tr.state() == binding;
    assert!(header_ok, "{label}: the run header rebuilt from the statement's public words is not the run's binding");

    // ---- stage 0 of `prove_run_with`, replicated, on the SEEDED stream ----
    let start_tag = position_tag(&tr);
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &st.block_digests()[0]);
    let stage_tr = Transcript::clone_state(&tr);
    let ntt = NttTables::new(run_ntt_log(&sh));
    let mut rng = ZkRng::new(SEED, DOMAIN);
    let mut ph = crate::private_block::timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = Instant::now();
    let t_prove = Instant::now();
    let core = protocol::prove_core(&ssh, &lay, &blocks[0], Witness { planes: wit.planes.clone() }, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the core prover on the seeded stream");
    let [ic, oc] = core.io_claims;
    protocol::check_endpoint_opening(&ic, &sh, &tr).expect("the input endpoint opening passes its refusal checks");
    let in_open = pcs::open_zk(&ein, &ic, &mut tr);
    drop(ein);
    protocol::check_endpoint_opening(&oc, &sh, &tr).expect("the output endpoint opening passes its refusal checks");
    let out_open = pcs::open_zk(&eout, &oc, &mut tr);
    drop(eout);
    let end_tag = position_tag(&tr);
    let prove_s = t_prove.elapsed().as_secs_f64();
    // nothing after `prove_core` draws in a one-block stage: the probe is the
    // stream position at the end of the stage
    let prover_probe = probe(&mut rng);
    let (a_root, m_root, h_root) = (core.a_root, core.mask_root, core.h_root);
    let seg = Segment { b_root: None, a_root, h_root, mask_root: m_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: Some(out_open) };
    let geom = SegGeom { l: 1, k: 0, boundary_rows: 0, sites: run::BOUNDARY_SITES };
    let bytes = wire::encode_segment(&seg, &lay, geom, &binding, &start_tag, &end_tag).expect("the seeded segment encodes");
    drop(seg);
    let seg_len = bytes.len();
    let t_verify = Instant::now();
    // THE PRODUCTION RUN VERIFIER, from the segment's bytes (in memory only:
    // the seeded receipt is never written anywhere)
    let verified = run::verify_run(&st, &blocks, std::slice::from_ref(&bytes));
    let verify_s = t_verify.elapsed().as_secs_f64();
    drop(bytes);

    // ---- the prediction ----
    let t_rebuild = Instant::now();
    let r = rebuild(&ssh, &lay, &blocks[0], &stage_tr, &wit, &ntt, Pert::None);
    let rebuild_s = t_rebuild.elapsed().as_secs_f64();
    let (a_ok, m_ok, h_ok) = (r.a_root == a_root, r.m_root == m_root, r.h_root == h_root);
    let ends_ok = r.probe == prover_probe;
    let counted_ok = probe_at(r.bytes) == prover_probe;
    let shifted_differs = probe_at(r.bytes + 16) != prover_probe;
    let u_rows_below_mask = lay.h_u_rows().iter().all(|u| *u < lay.h_mask_base);
    eprintln!(
        "GR4 trained replay [{label}]: layout A {} rows (mask region {} rows), H {} rows (mask region {} rows), M {} base rows, row width 2^{}, rate {}; H zero-sum rows below the segment-8 region = {u_rows_below_mask}; parity words {parity_words}",
        lay.a_rows,
        lay.a_rows - lay.a_mask_base,
        lay.h_rows,
        lay.h_rows - lay.h_mask_base,
        2 * lay.mask_specs().len() + 4,
        sh.log_cols,
        sh.inv_rate
    );
    eprintln!(
        "GR4 trained replay [{label}]: single-block receipt refused at this profile = {single_refused}; run header rebuilt from public words = binding: {header_ok}; one-block bound run, seeded stage 0, segment {seg_len} B, verified by the production run verifier = {}",
        verified.is_ok()
    );
    eprintln!(
        "GR4 trained replay [{label}]: A root rebuilt = {a_ok}; M root rebuilt = {m_ok}; H root rebuilt = {h_ok}; replay stream ends where the prover's did (next-draw probe) = {ends_ok}; prover consumed exactly the predicted {} bytes = {counted_ok}; probe non-vacuity (16 bytes further differs) = {shifted_differs}; endpoint owners: {fields} drawn field values and {salts} salts, all distinct",
        r.bytes
    );
    assert!(a_ok, "{label}: A's root is not the root of (witness rows, segment 1 as the reserved and proximity rows, segment 2 as pads, segment 3 as salts): a drawn A word is not where, or not what, the schedule says");
    assert!(m_ok, "{label}: M's root is not the root of segments 4-7 with b[m] := -b[0] only: a CFS coefficient, pad, b, u or salt of M is not where, or not what, the schedule says");
    assert!(h_ok, "{label}: H's root is not the root of (LogUp rows, segment 8 as the reserved and proximity rows, segment 9 as the zero-sum rows, 10 as pads, 11 as salts): a drawn H word is not where, or not what, the schedule says");
    assert!(ends_ok, "{label}: the replay did not end where the prover's generator did");
    assert!(counted_ok, "{label}: the prover's generator did not consume exactly the predicted byte count");
    assert!(shifted_differs, "{label}: the next-draw probe cannot tell a 16-byte shift; the position comparison is vacuous");
    assert!(u_rows_below_mask, "{label}: H's zero-sum rows sit inside the segment-8 fill; the prediction's discard statement no longer holds");
    verified.expect("the seeded one-block trained run verifies");

    // ---- NON-VACUITY: each deliberate error in the PREDICTION moves its root ----
    for (pert, what) in [(Pert::AProxZero, "A"), (Pert::CopyAIntoH, "H"), (Pert::AlphaCopy, "M")] {
        let p = rebuild(&ssh, &lay, &blocks[0], &stage_tr, &wit, &ntt, pert);
        let moved = match what {
            "A" => p.a_root != a_root,
            "H" => p.h_root != h_root,
            _ => p.m_root != m_root,
        };
        eprintln!("GR4 trained replay [{label}]: non-vacuity {pert:?} moves the {what} root = {moved}");
        assert!(moved, "{label}: the perturbation {pert:?} did not move the {what} root; the comparison is blind to it");
    }
    eprintln!(
        "GR4 trained replay [{label}]: PASS. seconds: seeded prove stage {prove_s:.2}, production run verify {verify_s:.2}, one rebuild {rebuild_s:.2}, whole test {:.2}; process high-water mark {:.2} GiB [MEASURED, shared box, n=1]. Not a privacy result.",
        t_all.elapsed().as_secs_f64(),
        run::peak_rss_mib() / 1024.0
    );
}

/// **THE TRAINED BLOCK, DENSE** (the export's held-out sequence ho00 entering
/// layer 0, parity bit-exact against the export): every drawn word of `A`,
/// `M` and `H` is where the schedule says, with the value it says.
#[test]
#[ignore = "P-12 G-R4 port: reads the trained export and proves one trained TinyLlama T32 block on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_trained_t32_block_dense_ho00_commits_exactly_the_predicted_stream() {
    replay_trained_block(true);
}

/// **THE TRAINED BLOCK, ALL-ZERO INPUT** (the fixed input the privacy case
/// is stated at, on the same trained public block).
#[test]
#[ignore = "P-12 G-R4 port: reads the trained export and proves one trained TinyLlama T32 block on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_trained_t32_block_zero_commits_exactly_the_predicted_stream() {
    replay_trained_block(false);
}

/// **THE INTERNAL BOUNDARY B_0 OF A TWO-BLOCK TRAINED RUN** (layers 0 | 1),
/// at the run's own `boundary_spec(0)` and the trained keyed tag. The
/// preparer takes the CALLER's generator, so it is seeded here: its root must
/// be (plane, predicted mask rows, predicted pads, predicted salts), for the
/// dense plane (block 0's native output on ho00, parity bit-exact — exactly
/// what `prove_run` commits at B_0) and for the all-zero plane.
#[test]
#[ignore = "P-12 G-R4 port: reads the trained export (two layers) and commits the trained boundary on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_trained_t32_boundary_commits_exactly_the_predicted_stream() {
    let t_all = Instant::now();
    let ex = TrainedExport::load(&export_dir()).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = [0u32, 1];
    let c = ex.run_constants(&layers).expect("the run-level constants");
    let sh = ex.shape_for(&c).expect("the trained shape (through the door)");
    let mut blocks = Vec::with_capacity(2);
    let mut records = Vec::with_capacity(2);
    for &l in &layers {
        let t = ex.load_layer(&sh, &c, l, false).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        records.push(t.record);
        blocks.push(t.blk);
    }
    let model = ex.statement_of_records(&sh, &c, records).expect("the trained-model statement");
    // the dense B_0 plane: block 0's native padded output on ho00
    let x0 = ex.load_seq(&sh, SEQ, 0).expect("the export's hidden input").0;
    let w0 = witness::build_shaped(&sh, blocks[0].attention(), blocks[0].feed_forward(), &x0).expect("block 0's honest trained witness");
    let ids = Ids::new(&sh).expect("the trained shape has a plane map");
    let (x_in, b0) = (padded(&w0, ids.at(A_X)), padded(&w0, ids.at(A_X2)));
    drop(w0);
    let (_, want) = ex.load_seq(&sh, SEQ, 0).expect("the export's reference output of layer 0");
    let got = true_input(&sh, &b0);
    let differ = got.iter().zip(want.iter()).filter(|(a, b)| a != b).count();
    assert!(got.len() == want.len() && differ == 0, "parity: block 0's native output differs from the export's x_out in {differ} words (no value printed)");
    // the two-block statement (its external output endpoint carries the
    // export's reference output of layer 1; this run is never proved here,
    // only its boundary statement is taken from it)
    let x_out = pad_cube(&sh, &ex.load_seq(&sh, SEQ, 1).expect("the export's reference output of layer 1").1);
    let spec_io = IoSpec::new_shaped(&sh, context(), 0, 0).expect("the run's endpoint spec");
    let (expected, _owners) = prepare_endpoints(spec_io, &x_in, &x_out).expect("the run's external endpoint owners");
    let rs = ex.geometry.run_shape(&sh, 2).expect("the trained run shape");
    let st = RunStatement::new_bound(rs, context(), expected, &blocks, &[(0, 0), (0, 0)], &model).expect("the bound two-block run statement");
    let spec = st.boundary_spec(0).expect("the run's boundary B_0 statement");
    let (rows, data, sites, log_n, rate) = (spec.commitment_rows(), spec.data_rows(), spec.sites(), spec.log_n(), spec.params().inv_rate);
    assert!((rows, data, sites, log_n, rate) == (22, 16, 2, 12, 4), "the trained boundary geometry is ({rows}, {data}, {sites}, 2^{log_n}, rate {rate}), not the declared (22 rows = 16 data + 2x2 sites + 2, 2^12, rate 4)");
    let tag = sh.hash_tag();
    let keyed = tag.column_key().is_some() && tag.leaf_key().is_some() && tag.node_key().is_some();
    assert!(keyed, "the trained profile does not hash under a keyed tag (D19)");
    let ntt = NttTables::new(run_ntt_log(&sh));
    let n = 1usize << log_n;
    let (s0, s1) = (spec.mask_row(0).expect("site 0"), spec.mask_row(1).expect("site 1"));
    for (label, plane) in [("dense: block 0's native output on ho00", b0), ("all-zero plane", vec![0i16; spec.len()])] {
        assert!(plane.len() == spec.len(), "{label}: the plane is not the padded boundary plane");
        let vals = words(&plane);
        let mut rng = ZkRng::new(SEED, DOMAIN);
        let p = crate::private_block::boundary::prepare(&spec, &vals, &ntt, &mut rng, &tag).expect("the boundary commits");
        let prover_probe = probe(&mut rng);
        let predict = |copy_site: bool| -> (Digest, u64, [u64; 4]) {
            let mut d = vec![Fp::ZERO; rows * n];
            d[..vals.len()].copy_from_slice(&vals);
            let mut rp = Draws::new();
            for x in d[data * n..].iter_mut() {
                *x = rp.fp();
            }
            if copy_site {
                d[s1 * n] = d[s0 * n];
            }
            let root = zk_root(&spec.params(), &d, rows, &mut rp, &ntt, &tag);
            let bytes = rp.bytes;
            (root, bytes, probe(&mut rp.rng))
        };
        let (root, bytes, replay_probe) = predict(false);
        let root_ok = p.root() == root;
        let ends_ok = replay_probe == prover_probe;
        let counted_ok = probe_at(bytes) == prover_probe;
        let shifted_differs = probe_at(bytes + 16) != prover_probe;
        let (pert_root, _, _) = predict(true);
        let moved = pert_root != p.root();
        eprintln!(
            "GR4 trained replay boundary B_0 [{label}]: root rebuilt = {root_ok}; replay stream ends where the preparer's did (next-draw probe) = {ends_ok}; preparer consumed exactly the predicted {bytes} bytes = {counted_ok}; probe non-vacuity = {shifted_differs}; non-vacuity (site 1's first reserved word := site 0's) moves the root = {moved}; geometry {rows} rows = {data} data + 2x{sites} sites + 2, row width 2^{log_n}, rate {rate}, keyed tag = {keyed}"
        );
        assert!(root_ok, "boundary [{label}]: the root is not (plane, predicted mask rows, pads, salts)");
        assert!(ends_ok, "boundary [{label}]: the replay did not end where the preparer's generator did");
        assert!(counted_ok, "boundary [{label}]: the preparer did not consume exactly the predicted byte count");
        assert!(shifted_differs, "boundary [{label}]: the next-draw probe cannot tell a 16-byte shift");
        assert!(moved, "boundary [{label}]: copying a reserved word did not move the root; the comparison is blind to it");
    }
    eprintln!(
        "GR4 trained replay boundary B_0: PASS. whole test {:.2} s; process high-water mark {:.2} GiB [MEASURED, shared box, n=1]. Not a privacy result.",
        t_all.elapsed().as_secs_f64(),
        run::peak_rss_mib() / 1024.0
    );
}

// =========================================================================
// [PRIVACY GATE LANE, ROUND 6, 2026-10-19] REVIEW ROUND 2, FINDING Q-6: the
// seeded value-level replay extended from one stage to a RUN OF L = 2.
//
// What the one-block test above does not replay (its "(c)"): `prove_run_with`'s
// stage loop -- B_k drawn from the run stream BEFORE A_k, stage k+1 drawn on
// the stream AFTER stage k, and the B_{k-1} opening. Here a two-block trained
// run (layers 0 | 1) is proved stage by stage on ONE seeded stream, with
// stage 0 and stage 1 replicated line for line from `run.rs:895-981` (R5b):
//   stage 0: position tag; locality; B_0 := boundary::prepare(spec_0, block 0's
//            padded output, the RUN stream); absorb B; prove_core(block 0,
//            [input endpoint, B_0]); open the input endpoint; slot 22's claims
//            wait for B_0; end tag; segment (b_root = B_0)
//   stage 1: position tag; locality; prove_core(block 1, [B_0, output
//            endpoint]) on the SAME stream; open B_0 with the waiting claims
//            plus slot 21's (`PreparedBoundary::into_opening`); open the
//            output endpoint; end tag; segment (no b_root)
// Both segments are encoded with `wire::encode_segment` and VERIFIED BY THE
// PRODUCTION RUN VERIFIER `run::verify_run` from their bytes, which re-derives
// the stage layouts and segment geometry from the statement and replays the
// whole two-stage Fiat-Shamir chain -- so an inexact replication (a wrong
// stage layout, a wrong order, a wrong site) would be refused.
//
// THE PREDICTION: ONE replay stream, cut in the predicted order -- B_0's mask
// rows, pads and salts; stage 0's eleven segments; stage 1's eleven segments --
// rebuilds all SEVEN roots (B_0, A_0, M_0, H_0, A_1, M_1, H_1), which must
// equal the prover's, and the replay must end where the prover's generator
// did (next-draw probe, plus the counted-bytes probe and its 16-byte
// non-vacuity, as above).
//
// NON-VACUITY OF THE CROSS-STAGE CLAIMS (each must move the named root):
//   * stage 1 predicted on a FRESH stream (a stream reset between stages, the
//     cross-stage reuse the review names): A_1 moves;
//   * B_0 predicted AFTER stage 0's block draws (the B-before-A order
//     reversed): B_0 and A_0 move;
//   * the per-commitment perturbations m1 / m2 / alpha applied to STAGE 1:
//     A_1 / H_1 / M_1 move.
//
// The restated private items, each checked by the production verifier's
// acceptance: `RunStatement::in_site / out_site` (stage 0 = [data rows,
// B_0 site 0], stage 1 = [B_0 site 1, data rows]) and `RunStatement::seg_geom`.
//
// STILL NOT COVERED: the production entry `prove_run` on OS randomness (the
// stages are replicated, the verifier's acceptance is the evidence the
// replication is the run prover's); L >= 3 (stage k >= 2 repeats stage 1's
// pattern with B_{k-1} incoming and B_k outgoing -- the code path is the
// same loop body, but it is not replayed here); the endpoint generators
// (in situ only, as above); the GPU path.
//
// THE CAPTURE RULE of this file applies: booleans, counts, labels, seconds.
// =========================================================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum L2Pert {
    None,
    /// stage 1 predicted on a fresh stream (a stream reset between stages)
    ResetBeforeStage1,
    /// B_0 predicted after stage 0's block draws (B-before-A reversed)
    BoundaryAfterBlock,
    /// a per-commitment perturbation applied to stage 1
    Stage1(Pert),
}

/// `boundary::prepare`'s root on a CALLER's replay stream (the boundary test's
/// prediction, restated): the plane, then the mask rows, pads and salts
fn boundary_root_on(rp: &mut Draws, spec: &crate::private_block::boundary::BoundarySpec, vals: &[Fp], ntt: &NttTables, tag: &HashTag) -> Digest {
    let (rows, data, n) = (spec.commitment_rows(), spec.data_rows(), 1usize << spec.log_n());
    let mut d = vec![Fp::ZERO; rows * n];
    d[..vals.len()].copy_from_slice(vals);
    for x in d[data * n..].iter_mut() {
        *x = rp.fp();
    }
    zk_root(&spec.params(), &d, rows, rp, ntt, tag)
}

struct L2Roots {
    b0: Digest,
    a: [Digest; 2],
    m: [Digest; 2],
    h: [Digest; 2],
    bytes: u64,
    probe: [u64; 4],
}

fn replay_trained_run_l2(dense: bool) {
    let label = if dense { "TinyLlama-trained T32 run of layers 0|1, dense ho00 (generic witness)" } else { "TinyLlama-trained T32 run of layers 0|1, all-zero input (degenerate partner)" };
    let t_all = Instant::now();
    let ex = TrainedExport::load(&export_dir()).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = [0u32, 1];
    let c = ex.run_constants(&layers).expect("the run-level constants");
    let sh = ex.shape_for(&c).expect("the trained shape (through the door)");
    assert!(sh.trained_calibration, "the export did not build a trained-calibration shape");
    let mut blocks = Vec::with_capacity(2);
    let mut records = Vec::with_capacity(2);
    for &l in &layers {
        let t = ex.load_layer(&sh, &c, l, false).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        records.push(t.record);
        blocks.push(t.blk);
    }
    let model = ex.statement_of_records(&sh, &c, records).expect("the trained-model statement");
    let ids = Ids::new(&sh).expect("the trained shape has a plane map");

    // ---- the run's own chain: block 0 on x0, block 1 on block 0's output ----
    let x0 = if dense { ex.load_seq(&sh, SEQ, 0).expect("the export's hidden input").0 } else { vec![0i16; sh.tokens * sh.width] };
    let w0 = witness::build_shaped(&sh, blocks[0].attention(), blocks[0].feed_forward(), &x0).expect("block 0's honest trained witness");
    let (x_in, b0) = (padded(&w0, ids.at(A_X)), padded(&w0, ids.at(A_X2)));
    let x1 = true_input(&sh, &b0);
    let w1 = witness::build_shaped(&sh, blocks[1].attention(), blocks[1].feed_forward(), &x1).expect("block 1's honest trained witness");
    let x_out = padded(&w1, ids.at(A_X2));
    let chain_ok = padded(&w1, ids.at(A_X)) == b0;
    assert!(chain_ok, "{label}: block 1's padded input plane is not block 0's padded output plane (the B_0 plane)");
    let mut parity_words = 0usize;
    if dense {
        for (l, plane) in [(0u32, &b0), (1u32, &x_out)] {
            let (_, want) = ex.load_seq(&sh, SEQ, l).expect("the export's reference output");
            let got = true_input(&sh, plane);
            let differ = got.iter().zip(want.iter()).filter(|(a, b)| a != b).count();
            assert!(got.len() == want.len() && differ == 0, "parity: layer {l}'s native output differs from the export's x_out in {differ} of {} words (no value printed)", got.len());
            parity_words += got.len();
        }
    }

    // ---- the bound TWO-block run statement, through the production constructors ----
    let spec_io = IoSpec::new_shaped(&sh, context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec_io, &x_in, &x_out).expect("the run's external endpoint owners");
    let rs = ex.geometry.run_shape(&sh, 2).expect("the trained run shape");
    let st = RunStatement::new_bound(rs, context(), expected.clone(), &blocks, &[(0, 0), (0, 0)], &model).expect("the bound two-block run statement");
    let data_rows = st.rs().data_rows();
    let bspec = st.boundary_spec(0).expect("the run's boundary B_0 statement");
    let (s0, s1) = (bspec.mask_row(0).expect("B_0 site 0"), bspec.mask_row(1).expect("B_0 site 1"));
    // `RunStatement::in_site / out_site` (private), restated for L = 2
    // [R7 gate copy] NATIVE R6: stage k is proved under `RunStatement::stage_shape(k)`
    let (ssh0, ssh1) = (st.stage_shape(0).expect("stage 0's shape"), st.stage_shape(1).expect("stage 1's shape"));
    let lay0 = Layout::for_shape(&ssh0).expect("the shape has a layout").with_io_mask_rows([data_rows, s0]);
    let lay1 = Layout::for_shape(&ssh1).expect("the shape has a layout").with_io_mask_rows([s1, data_rows]);
    // `RunStatement::seg_geom` (private), restated
    let geom = |k: usize| SegGeom { l: 2, k, boundary_rows: bspec.commitment_rows(), sites: run::BOUNDARY_SITES };
    let [ein, eout] = protocol::check_endpoints(&sh, &expected, owners).expect("the endpoint owners match the statement");

    // ---- the run header, rebuilt from public words, must be the binding ----
    let binding = st.binding().expect("the run binding");
    let mut tr = rebuilt_header(&st);
    let header_ok = tr.state() == binding;
    assert!(header_ok, "{label}: the run header rebuilt from the statement's public words is not the run's binding");

    let tag = sh.hash_tag();
    let ntt = NttTables::new(run_ntt_log(&sh));
    let mut rng = ZkRng::new(SEED, DOMAIN);
    let mut ph = crate::private_block::timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = Instant::now();
    let t_prove = Instant::now();

    // ---- STAGE 0 (run.rs: k = 0, k + 1 < l) ----
    let start0 = position_tag(&tr);
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &st.block_digests()[0]);
    let b0_words = words(&b0);
    let pb = crate::private_block::boundary::prepare(&bspec, &b0_words, &ntt, &mut rng, &tag).expect("the boundary B_0 commits on the run stream");
    let b_root = pb.root();
    protocol::absorb_root(&mut tr, b"B", &b_root, bspec.commitment_rows(), bspec.log_n());
    let stage0_tr = Transcript::clone_state(&tr);
    let core0 = protocol::prove_core(&ssh0, &lay0, &blocks[0], Witness { planes: w0.planes.clone() }, [ein.data.as_slice(), pb.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("stage 0's core prover on the seeded run stream");
    let [ic0, oc0] = core0.io_claims;
    protocol::check_endpoint_opening(&ic0, &sh, &tr).expect("the input endpoint opening passes its refusal checks");
    let in_open0 = pcs::open_zk(&ein, &ic0, &mut tr);
    drop(ein);
    let mut pending = oc0;
    let end0 = position_tag(&tr);
    let (a0, m0, h0) = (core0.a_root, core0.mask_root, core0.h_root);
    let seg0 = Segment { b_root: Some(b_root), a_root: a0, h_root: h0, mask_root: m0, slots: core0.slots, mask_open: core0.mask_open, a_open: core0.a_open, h_open: core0.h_open, in_open: in_open0, out_open: None };
    let bytes0 = wire::encode_segment(&seg0, &lay0, geom(0), &binding, &start0, &end0).expect("stage 0's seeded segment encodes");
    drop(seg0);

    // ---- STAGE 1 (run.rs: k = 1 = l - 1) on the SAME stream ----
    let start1 = position_tag(&tr);
    tr.absorb_u64(b"pb-run-stage", 1);
    tr.absorb(b"pb-run-block", &st.block_digests()[1]);
    let stage1_tr = Transcript::clone_state(&tr);
    let core1 = protocol::prove_core(&ssh1, &lay1, &blocks[1], Witness { planes: w1.planes.clone() }, [pb.data(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("stage 1's core prover on the seeded run stream");
    let [ic1, oc1] = core1.io_claims;
    pending.extend(ic1);
    let in_open1 = pb.into_opening(&bspec, &pending, &mut tr).expect("B_0's one opening");
    protocol::check_endpoint_opening(&oc1, &sh, &tr).expect("the output endpoint opening passes its refusal checks");
    let out_open1 = pcs::open_zk(&eout, &oc1, &mut tr);
    drop(eout);
    let end1 = position_tag(&tr);
    let prove_s = t_prove.elapsed().as_secs_f64();
    // nothing after the output endpoint opening draws: the probe is the
    // stream position at the end of the run
    let prover_probe = probe(&mut rng);
    let (a1, m1, h1) = (core1.a_root, core1.mask_root, core1.h_root);
    let seg1 = Segment { b_root: None, a_root: a1, h_root: h1, mask_root: m1, slots: core1.slots, mask_open: core1.mask_open, a_open: core1.a_open, h_open: core1.h_open, in_open: in_open1, out_open: Some(out_open1) };
    let bytes1 = wire::encode_segment(&seg1, &lay1, geom(1), &binding, &start1, &end1).expect("stage 1's seeded segment encodes");
    drop(seg1);
    let seg_lens = (bytes0.len(), bytes1.len());
    let t_verify = Instant::now();
    // THE PRODUCTION RUN VERIFIER, from the two segments' bytes (in memory
    // only: the seeded receipt is never written anywhere)
    let verified = run::verify_run(&st, &blocks, &[bytes0, bytes1]);
    let verify_s = t_verify.elapsed().as_secs_f64();

    // ---- THE PREDICTION: one replay stream, the predicted order ----
    let predict = |pert: L2Pert| -> L2Roots {
        let mut rp = Draws::new();
        let (b, a0, m0, h0) = if pert == L2Pert::BoundaryAfterBlock {
            let (a, m, h) = rebuild_on(&mut rp, &ssh0, &lay0, &blocks[0], &stage0_tr, &w0, &ntt, Pert::None);
            (boundary_root_on(&mut rp, &bspec, &b0_words, &ntt, &tag), a, m, h)
        } else {
            let b = boundary_root_on(&mut rp, &bspec, &b0_words, &ntt, &tag);
            let (a, m, h) = rebuild_on(&mut rp, &ssh0, &lay0, &blocks[0], &stage0_tr, &w0, &ntt, Pert::None);
            (b, a, m, h)
        };
        if pert == L2Pert::ResetBeforeStage1 {
            rp = Draws::new();
        }
        let p1 = match pert {
            L2Pert::Stage1(p) => p,
            _ => Pert::None,
        };
        let (a1, m1, h1) = rebuild_on(&mut rp, &ssh1, &lay1, &blocks[1], &stage1_tr, &w1, &ntt, p1);
        let bytes = rp.bytes;
        L2Roots { b0: b, a: [a0, a1], m: [m0, m1], h: [h0, h1], bytes, probe: probe(&mut rp.rng) }
    };
    let t_rebuild = Instant::now();
    let r = predict(L2Pert::None);
    let rebuild_s = t_rebuild.elapsed().as_secs_f64();
    let b_ok = r.b0 == b_root;
    let (a0_ok, m0_ok, h0_ok) = (r.a[0] == a0, r.m[0] == m0, r.h[0] == h0);
    let (a1_ok, m1_ok, h1_ok) = (r.a[1] == a1, r.m[1] == m1, r.h[1] == h1);
    let ends_ok = r.probe == prover_probe;
    let counted_ok = probe_at(r.bytes) == prover_probe;
    let shifted_differs = probe_at(r.bytes + 16) != prover_probe;
    eprintln!(
        "GR4 trained run replay L=2 [{label}]: run header rebuilt from public words = binding: {header_ok}; block chain B_0 plane = block 1's input: {chain_ok}; parity words {parity_words}; stage layouts [{data_rows}, {s0}] | [{s1}, {data_rows}]; boundary {} rows; segments {} B + {} B, verified by the production run verifier = {}",
        bspec.commitment_rows(),
        seg_lens.0,
        seg_lens.1,
        verified.is_ok()
    );
    eprintln!(
        "GR4 trained run replay L=2 [{label}]: B_0 root rebuilt = {b_ok}; stage 0 A/M/H roots rebuilt = {a0_ok}/{m0_ok}/{h0_ok}; stage 1 A/M/H roots rebuilt = {a1_ok}/{m1_ok}/{h1_ok}; replay stream ends where the prover's did (next-draw probe) = {ends_ok}; prover consumed exactly the predicted {} bytes = {counted_ok}; probe non-vacuity (16 bytes further differs) = {shifted_differs}",
        r.bytes
    );
    assert!(b_ok, "{label}: B_0's root is not (block 0's output plane, then B_0's mask rows, pads and salts drawn FIRST in stage 0 from the run stream)");
    assert!(a0_ok && m0_ok && h0_ok, "{label}: a stage-0 root is not the prediction on the run stream after B_0");
    assert!(a1_ok && m1_ok && h1_ok, "{label}: a stage-1 root is not the prediction on the run stream after stage 0");
    assert!(ends_ok, "{label}: the replay did not end where the prover's generator did");
    assert!(counted_ok, "{label}: the prover's generator did not consume exactly the predicted byte count");
    assert!(shifted_differs, "{label}: the next-draw probe cannot tell a 16-byte shift; the position comparison is vacuous");
    verified.expect("the seeded two-block trained run verifies");

    // ---- NON-VACUITY of the cross-stage claims and of stage 1's comparisons ----
    let checks: [(L2Pert, &str); 5] = [
        (L2Pert::ResetBeforeStage1, "A_1"),
        (L2Pert::BoundaryAfterBlock, "B_0 and A_0"),
        (L2Pert::Stage1(Pert::AProxZero), "A_1"),
        (L2Pert::Stage1(Pert::CopyAIntoH), "H_1"),
        (L2Pert::Stage1(Pert::AlphaCopy), "M_1"),
    ];
    for (pert, what) in checks {
        let p = predict(pert);
        let moved = match pert {
            L2Pert::ResetBeforeStage1 => p.a[1] != a1,
            L2Pert::BoundaryAfterBlock => p.b0 != b_root && p.a[0] != a0,
            L2Pert::Stage1(Pert::AProxZero) => p.a[1] != a1,
            L2Pert::Stage1(Pert::CopyAIntoH) => p.h[1] != h1,
            L2Pert::Stage1(_) => p.m[1] != m1,
            L2Pert::None => false,
        };
        eprintln!("GR4 trained run replay L=2 [{label}]: non-vacuity {pert:?} moves the {what} root(s) = {moved}");
        assert!(moved, "{label}: the perturbation {pert:?} did not move the {what} root(s); the comparison is blind to it");
    }
    eprintln!(
        "GR4 trained run replay L=2 [{label}]: PASS. seconds: seeded prove of both stages {prove_s:.2}, production run verify {verify_s:.2}, one prediction {rebuild_s:.2}, whole test {:.2}; process high-water mark {:.2} GiB [MEASURED, shared box, n=1]. Not a privacy result.",
        t_all.elapsed().as_secs_f64(),
        run::peak_rss_mib() / 1024.0
    );
}

/// **[Q-6] A TWO-BLOCK TRAINED RUN, DENSE** (ho00 through layers 0 and 1,
/// parity bit-exact against the export at both layers): B_0, then stage 0,
/// then stage 1, every drawn word where the schedule says, on ONE stream.
#[test]
#[ignore = "Q-6 G-R4 run-scope replay: reads the trained export (two layers) and proves a two-block trained run on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_trained_t32_run_l2_dense_ho00_commits_exactly_the_predicted_stream() {
    replay_trained_run_l2(true);
}

/// **[Q-6] A TWO-BLOCK TRAINED RUN, ALL-ZERO INPUT** (the fixed input the
/// privacy case is stated at).
#[test]
#[ignore = "Q-6 G-R4 run-scope replay: reads the trained export (two layers) and proves a two-block trained run on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_trained_t32_run_l2_zero_commits_exactly_the_predicted_stream() {
    replay_trained_run_l2(false);
}
