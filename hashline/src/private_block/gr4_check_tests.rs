//! **REVIEW BRANCH ONLY** (`zk60-private-block-125m-review`): the
//! independent check of the G-R4 blinding-law draft
//! (`docs/zkmatrix-poc/ZK60_BLINDING_LAW_GR4_CHECK.md`). NOT part of the
//! lane's delta and not to be integrated with it as written; it is the
//! reviewer's proposal for the value-level half of ruling R-3 (the draft's
//! §5.7 closure (b)).
//!
//! **WHY.** Stage 36's assertion 6
//! (`s36_tests::the_only_relations_imposed_on_drawn_values_are_the_three_
//! the_schedule_declares`) is a SOURCE scan that only sees `let`-bound draws.
//! It skips the `*x = rng.fp();` fill idiom (the line starts with `*`) and
//! never sees `CfsMask::random(rng, ..)`, so the reserved pairs, the
//! proximity rows and the CFS coefficients `α` are not value-checked at all.
//! The check's run of the draft's two mutations m1 and m2 against that Rust
//! test is recorded in the check document.
//!
//! **WHAT THIS MODULE ASSERTS, BY VALUE, NOT BY SOURCE TEXT.**
//!
//! 1. `prove_core` is run on a SEEDED generator `ZkRng::new(SEED, DOMAIN)`
//!    (it takes its generator from the caller) and its receipt is verified.
//! 2. A SECOND generator on the same seed is cut into the eleven predicted
//!    segments IN THE PREDICTED ORDER, and the three committed matrices are
//!    REBUILT from the witness and those segments:
//!    * `A`: the witness rows (a copy of `prove_core`'s own construction),
//!      then segment 1 row-major into rows `a_mask_base..a_rows`, then
//!      segment 2 as the pads and segment 3 as the salts;
//!    * `M`: segment 4 as the 23 `α` vectors, 5 as the per-row pads, 6 as
//!      `b` and `u` with the ONE declared relation `b[m] := -b[0]`, 7 as the
//!      salts — `M` holds no data, so this rebuild is every word of it;
//!    * `H`: the LogUp rows from the witness and the three challenges
//!      replayed on the header transcript, then segment 8 into rows
//!      `h_mask_base..h_rows`, segment 9 into the two zero-sum rows with the
//!      declared closing entry, then 10 as the pads and 11 as the salts.
//!    The encoding and hashing are rebuilt with `pcs::encode_row_zk`,
//!    `pcs::hash_columns_keyed`, `pcs::salt_leaf_keyed` and
//!    `MerkleTree::build_keyed`, NOT through `commit_zk_owned_tagged` or
//!    `zk::mask_commit_tagged`, so a relation imposed inside those two
//!    functions is caught too.
//! 3. The three rebuilt ROOTS equal the prover's, and the replay generator
//!    ends where the prover's did (`consumed_bytes`).
//!
//! Under collision resistance of the (keyed) column/leaf/node hashes, (3)
//! says every committed word of `A`, `M` and `H` — every drawn word among
//! them — sits at its predicted coordinate with its predicted value. The
//! predicted map sends each stream word to exactly one coordinate (or, for
//! `b[m]`, to the declared discard), so the committed blinding is an
//! INJECTIVE image of the stream modulo the three declared relations: a
//! copy, an overwrite, a reordering or a skipped draw anywhere in the
//! eleven segments moves a root. That is the value-level statement the
//! source scan cannot make, and it pins the ORDER inside a block (J-5's
//! assertion 2, finding S36-F3) as a by-product.
//!
//! **WHAT IT DOES NOT COVER.** (a) Uses of drawn values OUTSIDE the three
//! commitments (the slot argument's reads of `α` and of the reserved pairs):
//! those are bound to the committed values by the verifier, and the receipt
//! is verified here, but that is soundness, not this check. (b) The two
//! endpoint generators build their own `from_os` stream and cannot be
//! seeded; for them this module checks, IN SITU on the real owners, that no
//! drawn value repeats inside or across the two owners (a weaker, order-blind
//! test). (c) A run: the boundary preparer IS seeded here (it takes the
//! caller's generator); `prove_run`'s stage loop is not replayed.
//!
//! **THE CAPTURE RULE.** Nothing is printed but roots-equal booleans,
//! counts and labels: no drawn value, no seed-derived word, no key.
//!
//! Not a privacy result and not an acceptance of anything.

use super::layout::*;
use super::protocol::{self, verify_inner_at};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::merkle::MerkleTree;
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, ZkOpts};
use crate::sumcheck::CfsMask;
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::zk::{ZkRng, MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q};
use zkp_core::hashtag::HashTag;

/// a public TEST seed; production never uses `ZkRng::new`
const SEED: u64 = 0x4752_3443_4845_434b;
const DOMAIN: &[u8] = b"review G-R4 check: the seeded value-level replay (test fixture only)";

/// one deliberate error in the PREDICTION, used to show the root comparison
/// is sensitive to exactly the three relations the source scan cannot see
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Pert {
    None,
    /// m1's analogue: overwrite A's first proximity-row word after the fill
    AProxZero,
    /// m2's analogue: copy A's first reserved-pair word into H's first reserved word
    CopyAIntoH,
    /// the `α` analogue: slot 1's first CFS coefficient := slot 0's
    AlphaCopy,
}

struct Parts {
    sh: Shape,
    blk: BlockPublic,
    planes: Vec<Vec<i64>>,
    expected: ExpectedIo,
    owners: Endpoints,
}

fn context() -> [u8; 32] {
    *blake3::hash(b"review G-R4 check: fixture context").as_bytes()
}

/// the whole statement of one shape: the toy's own fixture, or the dense
/// generic RUN recipe (stage 46's) at a shaped profile
fn parts(sh: Shape) -> Parts {
    if sh.is_frozen_toy() {
        let (blk, input) = BlockPublic::synthetic_fixture();
        let output = compute_output(&blk, &input).expect("the toy fixture's own output");
        let spec = IoSpec::new(context(), 0, 0).expect("the toy endpoint spec");
        let (expected, owners) = prepare_endpoints(spec, &input, &output).expect("the toy endpoint owners");
        let wit = witness::build(blk.attention(), blk.feed_forward(), &input).expect("the toy witness");
        Parts { sh, blk, planes: wit.planes, expected, owners }
    } else {
        let (public, ff, input) = super::dense_tests::dense_run_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the dense generic witness");
        let ids = Ids::new(&sh).expect("the shape's plane map");
        let spec = IoSpec::new_shaped(&sh, context(), 0, 0).expect("the shaped endpoint spec");
        let pad16 = |p: usize| -> Vec<i16> { wit.planes[p].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect() };
        let (expected, owners) = prepare_endpoints(spec, &pad16(ids.at(A_X)), &pad16(ids.at(A_X2))).expect("the shaped endpoint owners");
        Parts { sh, blk, planes: wit.planes, expected, owners }
    }
}

/// `pcs::commit_zk_owned_with_tag`'s root, rebuilt WITHOUT calling it: the
/// pads (`rows * q` field draws) then the salts (`nn` 32-byte draws) are
/// taken from `rp` here, each row is encoded with `encode_row_zk`, and the
/// salted keyed tree is built from the leaves
fn zk_root(params: &PcsParams, data: &[Fp], rows: usize, rp: &mut ZkRng, ntt: &NttTables, tag: &HashTag) -> [u8; 32] {
    let zko = ZkOpts::standard(params);
    let (n, nn, q) = (params.cols(), params.enc_cols(), zko.q_pad);
    assert_eq!(data.len(), rows * n, "the rebuilt matrix is not rows x n");
    let pads: Vec<Fp> = (0..rows * q).map(|_| rp.fp()).collect();
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rp.bytes32()).collect();
    let pows = pcs::coset_powers(zko.coset, nn);
    let mut enc = vec![Fp::ZERO; rows * nn];
    for r in 0..rows {
        pcs::encode_row_zk(ntt, &data[r * n..(r + 1) * n], &pads[r * q..(r + 1) * q], &pows, &mut enc[r * nn..(r + 1) * nn]);
    }
    let leaves = pcs::hash_columns_keyed(&enc, rows, nn, tag.column_key());
    let salted: Vec<[u8; 32]> = leaves.iter().zip(salts.iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    MerkleTree::build_keyed(salted, tag.node_key()).root()
}

fn inv(mut den: Vec<Fp2>) -> Vec<Fp2> {
    batch_inverse2_checked(&mut den).expect("an honest fixture has no zero LogUp denominator");
    den
}

fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

struct Rebuilt {
    a_root: [u8; 32],
    m_root: [u8; 32],
    h_root: [u8; 32],
    consumed: u64,
}

/// THE PREDICTION: the three committed matrices from (witness, the eleven
/// predicted segments of the replayed stream, in the predicted order)
fn rebuild(sh: &Shape, lay: &Layout, blk: &BlockPublic, expected: &ExpectedIo, planes: &[Vec<i64>], ntt: &NttTables, pert: Pert) -> Rebuilt {
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let wit = Witness { planes: planes.to_vec() };
    let (ids, hids, n) = (lay.ids(), lay.hids(), lay.n());
    let params = protocol::pcs_params_at(sh);
    assert_eq!(params.cols(), n, "the PCS row width is not the layout's");
    let tag = sh.hash_tag();
    let mut rp = ZkRng::new(SEED, DOMAIN);

    // ---- A's witness rows: `prove_core`'s own construction, restated ----
    let committed: Vec<usize> = lay.a_planes().into_iter().filter(|p| !ids.is_multiplicity(*p)).collect();
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    for p in &committed {
        for (i, v) in wit.planes[*p].iter().enumerate() {
            a[lay.a_off[*p] + i] = Fp::from_i64(*v);
        }
    }
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, protocol::lookup_values(lay, &wit, *d))).collect();
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    let m_u8 = protocol::byte_histogram_at(&looked, lookup_words, protocol::HISTOGRAM_PAR_MIN);
    let deltas = protocol::exp_deltas(lay, &wit);
    let mut m_exp = vec![0u64; U8_LEN];
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(d) && public.exp[*d as usize] == wit.planes[ids.at(A_E)][x];
        m_exp[if hit { *d as usize } else { 0 }] += 1;
    }
    let act_idx = protocol::act_indices(lay, &wit);
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
    let a_root = zk_root(&params, &a, lay.a_rows, &mut rp, ntt, &tag);

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
    // the ONE declared relation on M (declared relations 1 and 2 of three)
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
    let m_salted: Vec<[u8; 32]> = m_leaves.iter().zip(m_salts.iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    let m_root = MerkleTree::build_keyed(m_salted, tag.node_key()).root();

    // ---- H's LogUp rows: the challenges replayed on the header transcript ----
    let mut tr = protocol::transcript(blk, expected, lay);
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
            .expect("an honest fixture's helper column");
            write_h(&mut h, lay.h_off[first + k], &col);
        }
    }
    let exp_den: Vec<Fp2> = deltas.iter().zip(wit.planes[ids.at(A_E)].iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h(&mut h, lay.h_off[hids.sexp()], &inv(exp_den));
    let act_den: Vec<Fp2> = act_idx.iter().zip(wit.planes[ids.at(A_A16)].iter()).map(|(i, x)| alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*x))).add(g_act))).collect();
    write_h(&mut h, lay.h_off[hids.fact()], &inv(act_den));
    let [gu8, gexp, gact] = hids.table_helpers();
    for (plane, tv, mm) in [
        (gu8, super::argument::table_values_u8(g_u8), &m_u8),
        (gexp, super::argument::table_values_exp(public, beta, g_exp), &m_exp),
        (gact, super::argument::table_values_act(ff, beta, g_act), &m_act),
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
    let h_root = zk_root(&params, &h, lay.h_rows, &mut rp, ntt, &tag);
    Rebuilt { a_root, m_root, h_root, consumed: rp.consumed_bytes() }
}

/// every drawn field value one REAL endpoint owner holds (the mask rows above
/// the shape's data rows, then the pads), and its salts — read in situ
fn endpoint_drawn(sh: &Shape, e: &pcs::CommittedZk) -> (Vec<u64>, Vec<[u8; 32]>) {
    let (rows, data, _) = protocol::endpoint_geometry(sh).expect("the endpoint geometry");
    let n = e.data.len() / rows;
    assert_eq!(n * rows, e.data.len(), "the endpoint owner's matrix is not rows x n");
    let mut v: Vec<u64> = e.data[data * n..].iter().map(|x| x.0).collect();
    v.extend(e.pads.iter().map(|x| x.0));
    (v, e.salts.clone())
}

fn assert_pairwise_distinct<T: Ord + Clone>(what: &str, mut v: Vec<T>) -> usize {
    let len = v.len();
    v.sort();
    let dup = v.windows(2).filter(|w| w[0] == w[1]).count();
    assert_eq!(dup, 0, "{what}: {dup} repeated drawn value(s) among {len}: a copy or a reuse (an honest draw repeats with probability < len^2 / 2^65)");
    len
}

/// the whole check at one shape: prove on the seeded stream, verify, rebuild,
/// compare; then the in-situ endpoint check; then the three perturbations
fn replay_at(sh: Shape) {
    let Parts { sh, blk, planes, expected, owners } = parts(sh);
    let label = sh.name;
    let lay = Layout::for_shape(&sh).expect("the shape has a layout");
    let [ein, eout] = protocol::check_endpoints(&sh, &expected, owners).expect("the endpoint owners match the statement");

    // the endpoint generators, in situ (they cannot be seeded)
    let (vi, si) = endpoint_drawn(&sh, &ein);
    let (vo, so) = endpoint_drawn(&sh, &eout);
    let fields = assert_pairwise_distinct(&format!("{label}: the two endpoint owners' drawn field values"), [vi, vo].concat());
    let salts = assert_pairwise_distinct(&format!("{label}: the two endpoint owners' salts"), [si, so].concat());

    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let mut rng = ZkRng::new(SEED, DOMAIN);
    let mut tr = protocol::transcript(&blk, &expected, &lay);
    let mut ph = super::timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let core = protocol::prove_core(&sh, &lay, &blk, Witness { planes: planes.clone() }, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the core prover on the seeded stream");
    let consumed = rng.consumed_bytes();
    let [ic, oc] = core.io_claims;
    protocol::check_endpoint_opening(&ic, &sh, &tr).expect("the incoming endpoint opening passes its refusal checks");
    let in_open = pcs::open_zk(&ein, &ic, &mut tr);
    protocol::check_endpoint_opening(&oc, &sh, &tr).expect("the outgoing endpoint opening passes its refusal checks");
    let out_open = pcs::open_zk(&eout, &oc, &mut tr);
    let (a_root, m_root, h_root) = (core.a_root, core.mask_root, core.h_root);
    let receipt = Receipt { a_root, h_root, mask_root: m_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, io_open: [in_open, out_open] };
    let verified = verify_inner_at(&sh, &blk, &expected, &receipt);

    let r = rebuild(&sh, &lay, &blk, &expected, &planes, &ntt, Pert::None);
    eprintln!(
        "GR4 replay {label}: receipt verifies = {}; A root rebuilt = {}; M root rebuilt = {}; H root rebuilt = {}; replay stream bytes {} vs prover {}; endpoint owners: {fields} drawn field values and {salts} salts, all distinct",
        verified.is_ok(),
        r.a_root == a_root,
        r.m_root == m_root,
        r.h_root == h_root,
        r.consumed,
        consumed
    );
    assert_eq!(r.a_root, a_root, "{label}: A's root is not the root of (witness rows, segment 1 as the reserved and proximity rows, segment 2 as pads, segment 3 as salts): a drawn A word is not where, or not what, the schedule says");
    assert_eq!(r.m_root, m_root, "{label}: M's root is not the root of segments 4-7 with b[m] := -b[0] only: a CFS coefficient, pad, b, u or salt of M is not where, or not what, the schedule says");
    assert_eq!(r.h_root, h_root, "{label}: H's root is not the root of (LogUp rows, segment 8 as the reserved and proximity rows, segment 9 as the zero-sum rows, 10 as pads, 11 as salts): a drawn H word is not where, or not what, the schedule says");
    assert_eq!(r.consumed, consumed, "{label}: the replay did not end where the prover's generator did");
    verified.expect("the seeded receipt verifies");

    // NON-VACUITY: each deliberate error in the PREDICTION moves its root
    for (pert, what) in [(Pert::AProxZero, "A"), (Pert::CopyAIntoH, "H"), (Pert::AlphaCopy, "M")] {
        let p = rebuild(&sh, &lay, &blk, &expected, &planes, &ntt, pert);
        let moved = match what {
            "A" => p.a_root != a_root,
            "H" => p.h_root != h_root,
            _ => p.m_root != m_root,
        };
        eprintln!("GR4 replay {label}: non-vacuity {pert:?} moves the {what} root = {moved}");
        assert!(moved, "{label}: the perturbation {pert:?} did not move the {what} root; the comparison is blind to it");
    }
}

/// **THE TOY** (the frozen legacy-rule profile, the one with an accepted
/// statement): every drawn word of `A`, `M` and `H` is where the schedule
/// says, with the value the schedule says.
#[test]
fn gr4_replay_toy_block_commits_exactly_the_predicted_stream() {
    replay_at(Shape::toy());
}

/// **RUNG-G** (a TAGGED profile with the generalised endpoints): the same,
/// through the keyed column/leaf/node hashes.
#[test]
fn gr4_replay_rung_g_block_commits_exactly_the_predicted_stream() {
    replay_at(Shape::rung_g());
}

/// **THE INTERNAL BOUNDARY** (a run's `B_k`), which takes the CALLER's
/// generator and so can be seeded: its root is (plane, 6 predicted mask rows,
/// predicted pads, predicted salts), under the legacy and a tagged rule.
#[test]
fn gr4_replay_boundary_commits_exactly_the_predicted_stream() {
    let spec = super::boundary::BoundarySpec::new(context(), 32, 128, 0, 1, 2, 10, 4, 256, 10).expect("the rung-G boundary statement");
    let ntt = NttTables::new(spec.enc_log());
    let plane: Vec<Fp> = (0..spec.len()).map(|i| Fp::from_i64(((i as i64).wrapping_mul(7_919) % 4_096) - 2_048)).collect();
    for (label, tag) in [("legacy", HashTag::legacy()), ("rung-G tag", Shape::rung_g().hash_tag())] {
        let mut rng = ZkRng::new(SEED, DOMAIN);
        let p = super::boundary::prepare(&spec, &plane, &ntt, &mut rng, &tag).expect("the boundary commits");
        let consumed = rng.consumed_bytes();
        let n = 1usize << spec.log_n();
        let rows = spec.commitment_rows();
        let mut data = vec![Fp::ZERO; rows * n];
        data[..plane.len()].copy_from_slice(&plane);
        let mut rp = ZkRng::new(SEED, DOMAIN);
        for x in data[spec.data_rows() * n..].iter_mut() {
            *x = rp.fp();
        }
        let root = zk_root(&spec.params(), &data, rows, &mut rp, &ntt, &tag);
        eprintln!("GR4 replay boundary ({label}): root rebuilt = {}; {} mask rows; replay stream bytes {} vs prover {}", p.root() == root, rows - spec.data_rows(), rp.consumed_bytes(), consumed);
        assert_eq!(p.root(), root, "boundary ({label}): the root is not (plane, predicted mask rows, pads, salts)");
        assert_eq!(rp.consumed_bytes(), consumed, "boundary ({label}): the replay did not end where the preparer's generator did");
    }
}
