//! **STAGE 0.5 OF THE DEVICE-COMMITMENT PLAN (ruling DC-G(1)) — WHERE THE
//! HIDING COMMITMENT'S CPU SECONDS ACTUALLY GO.**
//!
//! **The question.** A hiding commitment
//! (`zkp_core::pcs::commit_zk_owned_with_tag`, `pcs.rs:769`) does five things
//! in a fixed order: it draws the pad rows and the column salts, builds the
//! coset powers, **encodes** every row (`encode_row_zk`: inverse NTT, pad
//! splice, coset twist, forward NTT), **hashes** every encoded column into a
//! leaf (`hash_columns_keyed`), and salts those leaves into a keyed Merkle
//! tree. §2.2 of the device memo COUNTS the compressions and finds 112,066,560
//! of 112,590,844 in the column digests — but a compression count is not a
//! second, and nobody has ever measured the split. The disposition's ruling
//! DC-G(1) says to measure it before any kernel is written, because if the
//! ENCODE is the larger half then "encode on the device, hash on the host"
//! needs no keyed CUDA hasher at all.
//!
//! **What this module is.** A test-only harness that calls the REAL functions
//! the prover calls, with the REAL parameters of each shape
//! (`protocol::pcs_params_at`, `ZkOpts::standard`, `Shape::hash_tag`), on
//! synthetic rows, and clocks the five parts separately and then the whole
//! enclosing call on the same data. It changes no production line: nothing
//! outside this file and its `#[cfg(test)] mod` registration moves.
//!
//! **The self-check that makes the numbers believable.** The parts and the
//! whole are run from two generators seeded identically, so the parts'
//! Merkle root MUST equal the root the enclosing call returns. That is
//! asserted at every shape and every repetition: if the harness had
//! reproduced a DIFFERENT computation, the roots would differ. The parts'
//! seconds are then comparable with the whole's, and the residue (whole minus
//! the five parts) is the enclosing call's own overhead.
//!
//! **THE CAPTURE RULE.** No witness and no private value exists here. The
//! rows are drawn from a fixed-seed `splitmix64` stream; the cost of a
//! Goldilocks NTT and of a BLAKE3 pass over a byte buffer does not depend on
//! the values in it (`Fp::mul` is an unconditional 128-bit reduce; the hasher
//! sees the same number of bytes whatever they are). Uniform rows are in fact
//! the CONSERVATIVE choice for the encode: the real `A` matrix is mostly
//! small `Fp::from_i64` values, whose `Fp::new`/`add` carry branches predict
//! better, so a real matrix can only encode FASTER than this one. A control
//! at rung-W14 measures that difference directly
//! ([`stage05_rung_w14_value_control`]).
//!
//! **No GPU.** `HL_GPU` is unset and the `gpu-cuda` feature is off; and a
//! tagged profile's keyed column digest is never offered to the device hasher
//! in any case (ruling T-8, `pcs.rs:781-785`), so the path measured here IS
//! the path 125M takes today.
//!
//! **Reporting rule.** Every number these tests print is
//! `[MEASURED, 3 runs, one shared box, not quiesced]`, as min / median / max
//! over three repetitions inside one process. Nothing here extrapolates to
//! another shape or another machine, and no count is turned into a time.
//!
//! Report: `results/zk60_stage05_commit_split/LEDGER.md`.

use super::layout::Layout;
use super::protocol::{endpoint_pcs_params, ntt_log_at, pcs_params_at};
use super::run::peak_rss_mib;
use super::shape::Shape;
use crate::field::Fp;
use crate::merkle::{Digest, MerkleTree};
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, ZkOpts};
use crate::zk::ZkRng;
use rayon::prelude::*;
use std::time::Instant;
use zkp_core::hashtag::HashTag;

/// repetitions inside one process (the reporting rule above)
const REPS: usize = 3;
/// the generator domain of this harness; it is not any prover's domain
const DOM: &[u8] = b"zk60-stage05-commit-split";

// ---------------------------------------------------------------------------
// synthetic rows
// ---------------------------------------------------------------------------

#[inline]
fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

/// Uniform field elements, one independent stream per row so the fill itself
/// parallelises. `Fp::new` is exact here: every `u64` is below `2p`.
fn fill_uniform(data: &mut [Fp], n: usize, seed: u64) {
    data.par_chunks_mut(n).enumerate().for_each(|(r, row)| {
        let mut s = seed ^ (r as u64).wrapping_mul(0x2545_F491_4F6C_DD1D);
        for v in row.iter_mut() {
            *v = Fp::new(splitmix64(&mut s));
        }
    });
}

/// The value control: rows of SMALL non-negative integers, the shape a real
/// witness plane has (`Fp::from_i64` of an int8-derived word).
fn fill_bytelike(data: &mut [Fp], n: usize, seed: u64) {
    data.par_chunks_mut(n).enumerate().for_each(|(r, row)| {
        let mut s = seed ^ (r as u64).wrapping_mul(0x2545_F491_4F6C_DD1D);
        for v in row.iter_mut() {
            *v = Fp::from_i64(i64::from((splitmix64(&mut s) & 0xFF) as u8));
        }
    });
}

// ---------------------------------------------------------------------------
// one repetition
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Default)]
struct Rep {
    pads: f64,
    pows: f64,
    alloc: f64,
    encode: f64,
    hash: f64,
    tree: f64,
    whole: f64,
}

fn secs(t: Instant) -> f64 {
    t.elapsed().as_secs_f64()
}

/// The five parts, then the whole, on the same data and the same randomness.
///
/// `seed` fixes both the synthetic rows and the two generators; the parts'
/// root and the whole's root are asserted equal, which is what licenses
/// comparing their clocks.
fn one_rep(params: &PcsParams, rows: usize, ntt: &NttTables, zko: &ZkOpts, tag: &HashTag, seed: u64) -> Rep {
    let (n, nn, q) = (params.cols(), params.enc_cols(), zko.q_pad);
    let mut r = Rep::default();

    let mut data = vec![Fp::ZERO; rows * n];
    fill_uniform(&mut data, n, seed);

    // ---- 1. pads + salts, drawn exactly as `commit_zk_owned_with_tag` draws
    // them, from an OS-seeded generator exactly as the prover's is. The draw
    // is discarded: it is here for its clock only, and the parts below use
    // the deterministic generator so that the root gate can exist.
    let mut os_rng = ZkRng::from_os(DOM).expect("OS randomness on this host");
    let t = Instant::now();
    let os_pads = os_rng.fp_vec(rows * q);
    let os_salts: Vec<[u8; 32]> = (0..nn).map(|_| os_rng.bytes32()).collect();
    r.pads = secs(t);
    assert_eq!((os_pads.len(), os_salts.len()), (rows * q, nn), "the pad/salt draw is not the commitment's");
    drop(os_pads);
    drop(os_salts);

    // the same draw, deterministic, for the parts (identical per-draw cost:
    // `ZkRng::refill` is the same BLAKE3 XOF either way — only the key's
    // provenance differs)
    let mut rng = ZkRng::new(seed, DOM);
    let pads = rng.fp_vec(rows * q);
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();

    // ---- 2. coset powers
    let t = Instant::now();
    let pows = pcs::coset_powers(zko.coset, nn);
    r.pows = secs(t);

    // ---- 3. allocate and ZERO the encoded matrix. `vec![Fp::ZERO; k]` is a
    // real `memset` over `rows * nn * 8` bytes — `Fp` is a user struct, so
    // the standard library's `alloc_zeroed` specialisation does not apply and
    // `extend_with` writes every element. It is `commit_zk_owned_with_tag`'s
    // first line of work after the powers and it is NOT free at these sizes,
    // so it is timed as its own part rather than hidden in the residue.
    let t = Instant::now();
    let mut encoded = vec![Fp::ZERO; rows * nn];
    r.alloc = secs(t);

    // ---- 4. encode (the prover's own rayon loop, `pcs.rs:791-794`)
    let t = Instant::now();
    encoded
        .par_chunks_mut(nn)
        .zip(data.par_chunks(n))
        .zip(pads.par_chunks(q))
        .for_each(|((erow, drow), prow)| {
            pcs::encode_row_zk(ntt, drow, prow, &pows, erow);
        });
    r.encode = secs(t);

    // ---- 5. the column digests
    let t = Instant::now();
    let leaves = pcs::hash_columns_keyed(&encoded, rows, nn, tag.column_key());
    r.hash = secs(t);

    // ---- 6. the salted leaves and the keyed tree
    let t = Instant::now();
    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    let tree = MerkleTree::build_keyed(salted, tag.node_key());
    r.tree = secs(t);
    let parts_root = tree.root();

    // everything the parts hold goes away before the whole is timed, so the
    // two halves of this function see the same allocator state
    drop(tree);
    drop(leaves);
    drop(pads);
    drop(salts);
    drop(pows);
    drop(encoded);

    // ---- the whole, from a generator at the same seed and the same position
    let mut rng2 = ZkRng::new(seed, DOM);
    let t = Instant::now();
    let cz = pcs::commit_zk_owned_tagged(params, data, ntt, zko, &mut rng2, tag);
    r.whole = secs(t);
    let whole_root = cz.commitment().root;
    drop(cz);

    assert_eq!(parts_root, whole_root, "the parts did not reproduce the enclosing call's commitment");
    r
}

// ---------------------------------------------------------------------------
// reporting
// ---------------------------------------------------------------------------

fn stat(mut v: Vec<f64>) -> (f64, f64, f64) {
    v.sort_by(|a, b| a.partial_cmp(b).expect("no NaN clock"));
    (v[0], v[v.len() / 2], v[v.len() - 1])
}

fn line(label: &str, v: Vec<f64>, whole_med: f64) {
    let (lo, md, hi) = stat(v);
    eprintln!("S05 | {label:<22} | {lo:8.3} | {md:8.3} | {hi:8.3} | {:5.1}% |", 100.0 * md / whole_med);
}

/// Clock the five parts and the whole at one commitment geometry and print
/// the table. Returns `(encode median, hash median, whole median)`.
fn report(what: &str, shape: &str, params: &PcsParams, rows: usize, ntt: &NttTables, zko: &ZkOpts, tag: &HashTag) -> (f64, f64, f64) {
    let (n, nn) = (params.cols(), params.enc_cols());
    let reps: Vec<Rep> = (0..REPS).map(|k| one_rep(params, rows, ntt, zko, tag, 0x0005_u64.wrapping_add(k as u64))).collect();
    let whole_med = stat(reps.iter().map(|r| r.whole).collect()).1;
    eprintln!(
        "S05 [{shape}] {what}: {rows} rows, n = {n} ({} B of message), encoded {nn} ({} B), Q = {}, keyed column digest: {}",
        rows * n * 8,
        rows * nn * 8,
        zko.q_pad,
        tag.column_key().is_some()
    );
    eprintln!("S05 | part                   |      min |   median |      max | share |");
    line("pads + salts", reps.iter().map(|r| r.pads).collect(), whole_med);
    line("coset powers", reps.iter().map(|r| r.pows).collect(), whole_med);
    line("alloc+zero encoded", reps.iter().map(|r| r.alloc).collect(), whole_med);
    line("ENCODE", reps.iter().map(|r| r.encode).collect(), whole_med);
    line("HASH (columns)", reps.iter().map(|r| r.hash).collect(), whole_med);
    line("leaves + tree", reps.iter().map(|r| r.tree).collect(), whole_med);
    line("WHOLE (one call)", reps.iter().map(|r| r.whole).collect(), whole_med);
    let enc = stat(reps.iter().map(|r| r.encode).collect()).1;
    let hsh = stat(reps.iter().map(|r| r.hash).collect()).1;
    let sum: f64 = [
        stat(reps.iter().map(|r| r.pads).collect()).1,
        stat(reps.iter().map(|r| r.pows).collect()).1,
        stat(reps.iter().map(|r| r.alloc).collect()).1,
        enc,
        hsh,
        stat(reps.iter().map(|r| r.tree).collect()).1,
    ]
    .iter()
    .sum();
    eprintln!(
        "S05 [{shape}] {what}: parts sum {sum:.3} s against whole {whole_med:.3} s (residue {:+.3} s, {:+.1}%); encode/hash ratio {:.2}; peak RSS so far {:.2} GiB",
        whole_med - sum,
        100.0 * (whole_med - sum) / whole_med,
        enc / hsh,
        peak_rss_mib() / 1024.0
    );
    (enc, hsh, whole_med)
}

fn header(shape: &str) {
    eprintln!(
        "S05 [{shape}] rayon threads {} | MALLOC_MMAP_THRESHOLD_={} | [MEASURED, {REPS} runs, one shared box, NOT quiesced] | synthetic rows, no witness, no GPU",
        rayon::current_num_threads(),
        std::env::var("MALLOC_MMAP_THRESHOLD_").unwrap_or_else(|_| "unset".into())
    );
}

/// The fixed-shape masking commitment `M`: 50 rows over a 2^12 domain. It is
/// the one other column-hashed salted tree in the proof and it does NOT go
/// through `commit_zk_owned_with_tag` — `zk::mask_commit_tagged` has its own
/// encode (`encode_coeffs_coset`, the pads inside the message) — so it is
/// reported as a whole and never split.
fn report_mask(shape: &str, lay: &Layout, ntt: &NttTables, tag: &HashTag) {
    let specs = lay.mask_specs();
    let rows = 2 * specs.len() + 4;
    let mut v = Vec::with_capacity(REPS);
    for k in 0..REPS {
        let mut rng = ZkRng::new(0x4D_u64 + k as u64, DOM);
        let t = Instant::now();
        let mc = crate::zk::mask_commit_tagged(&specs, ntt, &mut rng, tag);
        v.push(secs(t));
        assert_eq!(mc.encoded.len(), rows * (1usize << crate::zk::MASK_LOG_DOM), "the mask commitment is not the counted geometry");
        drop(mc);
    }
    let (lo, md, hi) = stat(v);
    eprintln!("S05 [{shape}] M (zk::mask_commit_tagged, {rows} rows over 2^{}): whole {lo:.4} / {md:.4} / {hi:.4} s (min/median/max), never split", crate::zk::MASK_LOG_DOM);
}

// ---------------------------------------------------------------------------
// rung-W14 — the light shape, in the ordinary filter
// ---------------------------------------------------------------------------

#[test]
fn stage05_commit_split_rung_w14() {
    let sh = Shape::rung_w14();
    let lay = Layout::for_shape(&sh).expect("rung-W14 is well formed");
    assert_eq!((lay.a_rows, lay.h_rows), (527, 436), "rung-W14's row counts are not the memo's");
    assert_eq!(sh.endpoint_rows, 9, "rung-W14's endpoint row count is not the memo's");
    let params = pcs_params_at(&sh);
    let zko = ZkOpts::standard(&params);
    let e_params = endpoint_pcs_params(&sh);
    let e_zko = ZkOpts::standard(&e_params);
    let tag = sh.hash_tag();
    assert!(tag.column_key().is_some(), "rung-W14 is a TAGGED profile: the column digest is keyed");
    let ntt = NttTables::new(ntt_log_at(&sh));

    header("rung-W14");
    let (ea, ha, _) = report("A", "rung-W14", &params, lay.a_rows, &ntt, &zko, &tag);
    let (eh, hh, _) = report("H", "rung-W14", &params, lay.h_rows, &ntt, &zko, &tag);
    // the endpoint commitment rides the same profile tag as the block
    report("endpoint", "rung-W14", &e_params, sh.endpoint_rows, &ntt, &e_zko, &tag);
    report_mask("rung-W14", &lay, &ntt, &tag);
    eprintln!("S05 [rung-W14] ANSWER: A encode {ea:.3} s against hash {ha:.3} s; H encode {eh:.3} s against hash {hh:.3} s");
}

/// Keyed against unkeyed column hashing at ONE shape, and the legacy
/// `hash_columns` body beside them: the keyed body cannot use BLAKE3's
/// one-shot fast path and builds a hasher per column, which is the only
/// reason the three differ.
#[test]
fn stage05_rung_w14_keyed_vs_unkeyed_hash() {
    let sh = Shape::rung_w14();
    let lay = Layout::for_shape(&sh).expect("rung-W14 is well formed");
    let params = pcs_params_at(&sh);
    let zko = ZkOpts::standard(&params);
    let tag = sh.hash_tag();
    let ntt = NttTables::new(ntt_log_at(&sh));
    let (n, nn, rows) = (params.cols(), params.enc_cols(), lay.a_rows);

    let mut data = vec![Fp::ZERO; rows * n];
    fill_uniform(&mut data, n, 0x5EED);
    let mut rng = ZkRng::new(0x5EED, DOM);
    let pads = rng.fp_vec(rows * zko.q_pad);
    let pows = pcs::coset_powers(zko.coset, nn);
    let mut encoded = vec![Fp::ZERO; rows * nn];
    encoded.par_chunks_mut(nn).zip(data.par_chunks(n)).zip(pads.par_chunks(zko.q_pad)).for_each(|((e, d), p)| pcs::encode_row_zk(&ntt, d, p, &pows, e));

    let mut keyed = Vec::new();
    let mut unkeyed = Vec::new();
    let mut legacy = Vec::new();
    for _ in 0..REPS {
        let t = Instant::now();
        let a = pcs::hash_columns_keyed(&encoded, rows, nn, tag.column_key());
        keyed.push(secs(t));
        let t = Instant::now();
        let b = pcs::hash_columns_keyed(&encoded, rows, nn, None);
        unkeyed.push(secs(t));
        let t = Instant::now();
        let c = pcs::hash_columns(&encoded, rows, nn);
        legacy.push(secs(t));
        assert_eq!(b, c, "the unkeyed keyed-body and the legacy body must agree digest for digest");
        assert_ne!(a, b, "a keyed column digest must differ from the unkeyed one");
    }
    let (kl, km, kh) = stat(keyed);
    let (ul, um, uh) = stat(unkeyed);
    let (ll, lm, lhi) = stat(legacy);
    eprintln!("S05 [rung-W14] column hashing, {rows} rows x {nn} columns, [MEASURED, {REPS} runs, shared box, not quiesced]:");
    eprintln!("S05 |   keyed (the tagged profile's path) | {kl:8.3} | {km:8.3} | {kh:8.3} |");
    eprintln!("S05 |   unkeyed, same body                | {ul:8.3} | {um:8.3} | {uh:8.3} |");
    eprintln!("S05 |   legacy hash_columns (fast path)   | {ll:8.3} | {lm:8.3} | {lhi:8.3} |");
    eprintln!("S05 [rung-W14] keying costs {:+.1}% of the column-hash phase; the legacy fast path is {:+.1}% against the keyed body", 100.0 * (km - um) / um, 100.0 * (lm - km) / km);
}

/// The value control promised in this module's capture rule: does the encode
/// cost more on uniform rows than on the byte-like rows a real `A` carries?
#[test]
fn stage05_rung_w14_value_control() {
    let sh = Shape::rung_w14();
    let lay = Layout::for_shape(&sh).expect("rung-W14 is well formed");
    let params = pcs_params_at(&sh);
    let zko = ZkOpts::standard(&params);
    let ntt = NttTables::new(ntt_log_at(&sh));
    let (n, nn, rows) = (params.cols(), params.enc_cols(), lay.a_rows);
    let mut rng = ZkRng::new(0xC0FFEE, DOM);
    let pads = rng.fp_vec(rows * zko.q_pad);
    let pows = pcs::coset_powers(zko.coset, nn);
    let mut encoded = vec![Fp::ZERO; rows * nn];

    let mut out = [Vec::new(), Vec::new()];
    for (k, fill) in [fill_uniform as fn(&mut [Fp], usize, u64), fill_bytelike as fn(&mut [Fp], usize, u64)].into_iter().enumerate() {
        let mut data = vec![Fp::ZERO; rows * n];
        fill(&mut data, n, 0xC0FFEE);
        for _ in 0..REPS {
            let t = Instant::now();
            encoded.par_chunks_mut(nn).zip(data.par_chunks(n)).zip(pads.par_chunks(zko.q_pad)).for_each(|((e, d), p)| pcs::encode_row_zk(&ntt, d, p, &pows, e));
            out[k].push(secs(t));
        }
    }
    let (_, um, _) = stat(out[0].clone());
    let (_, bm, _) = stat(out[1].clone());
    eprintln!("S05 [rung-W14] encode value control, {rows} rows: uniform rows {um:.3} s, byte-like rows {bm:.3} s (median of {REPS}); uniform is {:+.1}% — synthetic rows are the conservative choice for the ENCODE half", 100.0 * (um - bm) / bm);
}

// ---------------------------------------------------------------------------
// 125M — the heavy shape, `#[ignore]`d
// ---------------------------------------------------------------------------

/// **HEAVY, `#[ignore]`d.** `H`'s encoded matrix alone is 7,120 x 2^16 x 8 B
/// = 3.48 GiB and `A`'s is 2.77 GiB. One commitment is held at a time —
/// encode, hash, tree, drop, then the next — so the peak is one encoded
/// matrix plus its message rows, about 4.4 GiB. Run detached under
/// `flock /tmp/zk-heavy.lock` inside a `MemoryMax=8G` scope with
/// `MALLOC_MMAP_THRESHOLD_=131072`, as the lane's other 125M tests are.
#[test]
#[ignore]
fn stage05_commit_split_m125() {
    let sh = Shape::m125();
    let lay = Layout::for_shape(&sh).expect("125M is well formed");
    assert_eq!((lay.a_rows, lay.h_rows), (5681, 7120), "125M's row counts are not the memo's");
    assert_eq!(sh.endpoint_rows, 37, "125M's endpoint row count is not the memo's");
    let params = pcs_params_at(&sh);
    let zko = ZkOpts::standard(&params);
    let e_params = endpoint_pcs_params(&sh);
    let e_zko = ZkOpts::standard(&e_params);
    let tag = sh.hash_tag();
    assert!(tag.column_key().is_some(), "125M is a TAGGED profile: the column digest is keyed");
    assert_eq!((params.cols(), params.enc_cols(), zko.q_pad), (1 << 14, 1 << 16, 256), "125M's PCS geometry is not the memo's");
    let ntt = NttTables::new(ntt_log_at(&sh));

    header("125M");
    let (ea, ha, wa) = report("A", "125M", &params, lay.a_rows, &ntt, &zko, &tag);
    let (eh, hh, wh) = report("H", "125M", &params, lay.h_rows, &ntt, &zko, &tag);
    report("endpoint", "125M", &e_params, sh.endpoint_rows, &ntt, &e_zko, &tag);
    report_mask("125M", &lay, &ntt, &tag);
    eprintln!("S05 [125M] ANSWER: A encode {ea:.3} s against hash {ha:.3} s (whole {wa:.3} s); H encode {eh:.3} s against hash {hh:.3} s (whole {wh:.3} s)");
    eprintln!("S05 [125M] the prover's own phase clock on this box: A: commit 3.076 s, H: commit 3.499 s (q28-baseline-dense.log); 3.069 / 3.431 s (q28-m125-final-dense.log)");
    eprintln!("S05 [125M] peak RSS of this process: {:.2} GiB (VmHWM)", peak_rss_mib() / 1024.0);
}
