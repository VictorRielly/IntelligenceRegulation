//! [ZK60-CL9] Public weight-cache identity and lifecycle.
//!
//! CPU-only: `wcache::commit_w` falls back to `pcs::commit` without a device,
//! and every property tested here is about WHICH entry is reused, not about
//! where the encoding ran. So these run in the ordinary suite.
//!
//! The properties that matter, in the order CL9 states them:
//!   * a stale or mismatched approval must not reuse an incompatible
//!     commitment — every keyed field must change the entry
//!   * equivalent approved public state must preserve the FULL proof bytes —
//!     a hit and a miss must produce the same commitment root, and a cold and
//!     a warm PROCESS must produce byte-identical verified proofs
//!   * P3 must not be able to reach this cache at all — the driver's refusal,
//!     executed, and an uncached P3 process that accepts
//!
//! [ZK60-CL9 round 7] Codex's review (ZK60_CL5_CL9_REVIEW.md, 2026-09-06)
//! found `every_keyed_field_separates_the_entry` ORDER-DEPENDENT: it passed in
//! the serial suite only because `a_different_pcs_shape_...` had committed the
//! same base key first, and failed alone (0 hits where 1 was expected). The
//! review also listed what the first round had inferred rather than executed.
//! Each item is answered below, tagged `[round 7]`:
//!   1. the fix: an explicit prime + an own key namespace per test
//!   2. `cold_and_warm_processes_produce_the_same_verified_proof_bytes`
//!   3. `the_callers_packing_ties_the_key_to_the_committed_data` + the real
//!      layer cross-check inside test 2 (the prover's own entry HITs under a
//!      key this file rebuilds from the export planes)
//!   4. `p3_with_wcache_is_refused_by_the_driver_before_any_work` and
//!      `a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache`
//!   5. `the_shape_and_length_fields_separate_the_entry_too` and
//!      `same_key_concurrent_writers_leave_one_verifying_entry`
//! The two process tests need the 125M v3 export; without it they SKIP with
//! a message written straight to the terminal (past libtest's capture), never
//! silently.

use hashline::field::Fp;
use hashline::layer::LayoutV3;
use hashline::ntt::NttTables;
use hashline::pcs::{self, PcsParams};
use hashline::wcache::{self, WKey};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Barrier, Mutex, MutexGuard, OnceLock};

/// `wcache::configure` sets a PROCESS-GLOBAL directory and `wcache::stats` is
/// process-global too, so the in-process tests must not run concurrently with
/// each other. The process tests below take this only for their in-process
/// phase.
fn serial() -> MutexGuard<'static, ()> {
    static L: OnceLock<Mutex<()>> = OnceLock::new();
    L.get_or_init(|| Mutex::new(())).lock().unwrap_or_else(|e| e.into_inner())
}

/// THE LIFECYCLE FACT THAT SHAPES THIS WHOLE FILE: `DIR` is a `OnceLock`, so
/// `configure` may be called ONCE per process and panics on a second call —
/// it cannot be changed and it cannot be cleared. Every test therefore shares
/// ONE directory and separates its cases by KEY, which is what the cache is
/// designed around anyway (the entry filename carries the key digest).
///
/// [round 7] And that is exactly why every test must PRIME its own base entry
/// and own its key namespace: the directory outlives the test, so a key
/// another test has already committed starts WARM, and a key a test expects
/// to be warm is COLD when the test runs alone. Layer-index namespaces:
/// 101 equivalence | 200 keyed fields | 210 pcs shape | 220 shape/length |
/// 230.. packing | 300.. concurrent writers | 77 corruption | 40..44 eviction
/// | 0 the real layer-0 cross-check.
fn shared_dir() -> &'static str {
    static D: OnceLock<String> = OnceLock::new();
    D.get_or_init(|| {
        let p = std::env::temp_dir().join(format!("zk60_cl9_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&p);
        std::fs::create_dir_all(&p).expect("temp dir");
        let s = p.to_str().unwrap().to_string();
        wcache::configure(Some(&s));
        s
    })
}

fn files_with(prefix: &str, suffix: &str) -> Vec<String> {
    let mut v: Vec<String> = std::fs::read_dir(shared_dir())
        .map(|d| d.filter_map(|e| e.ok())
                  .map(|e| e.file_name().to_string_lossy().to_string())
                  .filter(|n| n.starts_with(prefix) && n.ends_with(suffix))
                  .collect())
        .unwrap_or_default();
    v.sort();
    v
}

fn entries_for(prefix: &str) -> usize {
    files_with(prefix, "").len()
}

const LOG_COLS: u32 = 8;
const INV_RATE: usize = 4;

fn params() -> PcsParams {
    PcsParams { log_cols: LOG_COLS, inv_rate: INV_RATE, num_col_checks: 16 }
}

fn tables() -> NttTables {
    NttTables::new(LOG_COLS + (INV_RATE.trailing_zeros()))
}

fn tables_for(p: &PcsParams) -> NttTables {
    NttTables::new(p.log_cols + (p.inv_rate.trailing_zeros()))
}

/// `rows` rows of `p.cols()` pseudo-random field elements (the SAME elements
/// for the same length, whatever `p.log_cols` is: that is what lets the
/// log_cols case below hold the packed length fixed while the row count moves).
fn data_for(p: &PcsParams, rows: usize) -> Vec<Fp> {
    let mut s = 0x9E37_79B9u64;
    (0..rows * p.cols())
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1);
            Fp::new(s % 0xFFFF_FFFF_0000_0001)
        })
        .collect()
}

fn data(rows: usize) -> Vec<Fp> {
    data_for(&params(), rows)
}

fn planes(seed: i8, len: usize) -> Vec<i8> {
    (0..len).map(|i| seed.wrapping_add(i as i8)).collect()
}

/// The (hits, misses, rejected) deltas of one `commit_w` call.
fn commit_counting(p: &PcsParams, d: &[Fp], ntt: &NttTables, k: &WKey) -> (pcs::Committed, (usize, usize, usize)) {
    let s0 = wcache::stats();
    let cm = wcache::commit_w(p, d, ntt, k);
    let s1 = wcache::stats();
    (cm, (s1.hits - s0.hits, s1.misses - s0.misses, s1.rejected - s0.rejected))
}

/// A CLEAN miss: no hit, one miss, and NOTHING REJECTED. The last part is the
/// point — if a field were missing from the key digest the entry FILENAME
/// would coincide, and for a shape field `load_tree`'s own rows/log_cols/
/// inv_rate check would catch it as a REJECTION. That would be the load check
/// saving the day, not the key. A clean miss proves the KEY separated them.
const CLEAN_MISS: (usize, usize, usize) = (0, 1, 0);
const HIT: (usize, usize, usize) = (1, 0, 0);

#[test]
fn equivalent_approved_state_hits_and_preserves_the_commitment_root() {
    let _g = serial();
    let _ = shared_dir();
    // a key unique to this test: the shared directory persists across tests,
    // so a key another test has already committed would start warm and this
    // would see two hits instead of one.
    let (wg, wu, wd) = (planes(11, 64), planes(12, 64), planes(13, 64));
    let k = WKey::new("v3", 101, 8, 8, &wg, &wu, &wd);
    let (p, ntt, d) = (params(), tables(), data(4));
    let (a, first) = commit_counting(&p, &d, &ntt, &k);
    let (b, second) = commit_counting(&p, &d, &ntt, &k);
    assert_eq!(first, CLEAN_MISS, "the first commit of this test's own key is a clean miss");
    assert_eq!(second, HIT, "the second commit of identical approved state must HIT");
    assert_eq!(a.tree.root(), b.tree.root(), "a cache hit must reproduce the commitment root exactly");
}

/// Every field in the key must separate entries. A collision here would let a
/// stale approval reuse an incompatible commitment, which is the whole risk.
///
/// [round 7] THE CORRECTION. The first version took its hit baseline and
/// then committed `base` + `other`, expecting exactly one hit — which assumed
/// `base` was ALREADY in the cache. It was, in the serial suite, because
/// `a_different_pcs_shape_cannot_reuse_the_entry` used the same key (planes
/// 1/2/3, layer 0) and ran first. Alone, the first `base` commit was a miss:
/// 0 hits, assertion failed. Now: this test owns its key (planes 21/22/23,
/// layer 200), PRIMES the base entry explicitly, and asserts the base re-commit
/// and the mutated commit SEPARATELY — the base must HIT and the mutation
/// must be a CLEAN miss. The mutations and expected behaviour are unchanged.
#[test]
fn every_keyed_field_separates_the_entry() {
    let _g = serial();
    let _ = shared_dir();
    let (wg, wu, wd) = (planes(21, 64), planes(22, 64), planes(23, 64));
    let base = WKey::new("v3", 200, 8, 8, &wg, &wu, &wd);
    let (p, ntt, d) = (params(), tables(), data(4));
    let (primed, prime) = commit_counting(&p, &d, &ntt, &base);
    assert_eq!(prime, CLEAN_MISS, "the prime of this test's own base key is a clean miss (nothing else uses layer 200)");

    let wg2 = {
        let mut v = wg.clone();
        v[0] = v[0].wrapping_add(1); // ONE byte of ONE weight plane
        v
    };
    let cases: Vec<(&str, WKey)> = vec![
        ("profile", WKey::new("v2", 200, 8, 8, &wg, &wu, &wd)),
        ("layer index", WKey::new("v3", 201, 8, 8, &wg, &wu, &wd)),
        ("d", WKey::new("v3", 200, 16, 8, &wg, &wu, &wd)),
        ("f", WKey::new("v3", 200, 8, 16, &wg, &wu, &wd)),
        ("one weight byte", WKey::new("v3", 200, 8, 8, &wg2, &wu, &wd)),
        ("plane order", WKey::new("v3", 200, 8, 8, &wu, &wg, &wd)),
    ];
    for (what, other) in cases {
        let (again, b) = commit_counting(&p, &d, &ntt, &base);
        assert_eq!(b, HIT, "the repeated BASE key must HIT (before the {what} case)");
        assert_eq!(again.tree.root(), primed.tree.root(), "and reproduce the primed root");
        let (_, o) = commit_counting(&p, &d, &ntt, &other);
        assert_eq!(o, CLEAN_MISS, "changing the {what} must be a CLEAN miss (hits, misses, rejected)");
    }
}

/// The PCS shape is part of the entry digest, so the same weights under a
/// different encoding cannot alias. `inv_rate` here; `log_cols`, rows and the
/// packed length in the next test.
#[test]
fn a_different_pcs_shape_cannot_reuse_the_entry() {
    let _g = serial();
    let _ = shared_dir();
    let (wg, wu, wd) = (planes(1, 64), planes(2, 64), planes(3, 64));
    let k = WKey::new("v3", 210, 8, 8, &wg, &wu, &wd); // [round 7] own layer namespace
    let d = data(4);
    let (_, prime) = commit_counting(&params(), &d, &tables(), &k);
    assert_eq!(prime, CLEAN_MISS);
    // same weights, same key fields, DIFFERENT inv_rate
    let other = PcsParams { log_cols: LOG_COLS, inv_rate: 2, num_col_checks: 16 };
    let (_, o) = commit_counting(&other, &d, &tables_for(&other), &k);
    assert_eq!(o, CLEAN_MISS, "a different inv_rate must be a clean miss, not a reuse and not a rejection");
}

/// [round 7] The remaining digested fields: `log_cols`, `rows`, the packed
/// length `len`, and a plane's LENGTH (as opposed to its content). `rows` and
/// `len` cannot move independently — `rows = len / 2^log_cols` — so they are
/// covered as the two axes that exist: the same `len` under another
/// `log_cols` (rows move alone) and more data under the same `log_cols` (rows
/// and len move together).
#[test]
fn the_shape_and_length_fields_separate_the_entry_too() {
    let _g = serial();
    let _ = shared_dir();
    let (wg, wu, wd) = (planes(31, 64), planes(32, 64), planes(33, 64));
    let base_p = params();
    let base_d = data(4);
    let base = WKey::new("v3", 220, 8, 8, &wg, &wu, &wd);
    let (primed, prime) = commit_counting(&base_p, &base_d, &tables(), &base);
    assert_eq!(prime, CLEAN_MISS);

    let p7 = PcsParams { log_cols: 7, inv_rate: INV_RATE, num_col_checks: 16 };
    let d8 = data(8);
    let wg_longer = { let mut v = wg.clone(); v.push(0); v };
    let wg_shorter = wg[..63].to_vec();
    let cases: Vec<(&str, PcsParams, &Vec<Fp>, WKey)> = vec![
        ("log_cols (7 for 8: the same 1024 elements, so rows 8 for 4 and len unchanged)", p7, &base_d, WKey::new("v3", 220, 8, 8, &wg, &wu, &wd)),
        ("rows and packed length (8 rows for 4 under the same log_cols)", base_p, &d8, WKey::new("v3", 220, 8, 8, &wg, &wu, &wd)),
        ("plane length (wg 65 B: the same 64 bytes plus one trailing zero)", base_p, &base_d, WKey::new("v3", 220, 8, 8, &wg_longer, &wu, &wd)),
        ("plane length (wg 63 B: the same bytes without the last)", base_p, &base_d, WKey::new("v3", 220, 8, 8, &wg_shorter, &wu, &wd)),
    ];
    for (what, p, d, other) in cases {
        let (again, b) = commit_counting(&base_p, &base_d, &tables(), &base);
        assert_eq!(b, HIT, "the BASE key must HIT (before the {what} case)");
        assert_eq!(again.tree.root(), primed.tree.root());
        let (_, o) = commit_counting(&p, d, &tables_for(&p), &other);
        assert_eq!(o, CLEAN_MISS, "changing the {what} must be a CLEAN miss (hits, misses, rejected)");
    }
}

// ---------------------------------------------------------------------------
// [round 7] THE CALLER'S PACKING. The first round committed synthetic data
// under a key built from unrelated planes, so it never exercised the one
// assumption the cache rests on: that the DATA a key is paired with is a
// function of the PLANES the key digests. These two functions are the
// prover's packing, copied from `layer::prove_layer_v3` (layer.rs, "W data +
// commit") — `zk::prove_layer_zk_v3`'s P1 branch is the same loop — and its
// inverse. If either prover loop changes, the real-layer cross-check inside
// `cold_and_warm_processes_...` fails (the prover's own entry stops HITting
// or stops matching the root), which is the point of running it.
// ---------------------------------------------------------------------------

/// The three int8 planes into the committed W rows: per (d-block c, f-block
/// b) one `wb = db x fb` block of Wg^T and of Wu^T (row = k within the block,
/// col = j within the block) and one block of Wd^T (row = j, col = n).
fn pack_w_v3(lay: &LayoutV3, wg_t: &[i8], wu_t: &[i8], wd_t: &[i8]) -> Vec<Fp> {
    let (d, f) = (lay.d, lay.f);
    let (nb_d, nb_f, db, fb, wb) = (lay.nb_d, lay.nb_f, 1usize << lay.log_db, 1usize << lay.log_fb, lay.wb);
    assert_eq!((wg_t.len(), wu_t.len(), wd_t.len()), (d * f, d * f, f * d));
    let mut w_data = vec![Fp::ZERO; lay.w_len];
    for c in 0..nb_d {
        for b in 0..nb_f {
            for (offs, src) in [(&lay.wg, wg_t), (&lay.wu, wu_t)] {
                let off = offs[c * nb_f + b];
                for (kp, row) in w_data[off..off + wb].chunks_mut(fb).enumerate() {
                    let k = c * db + kp;
                    for jp in 0..fb { row[jp] = Fp::from_i64(src[k * f + b * fb + jp] as i64); }
                }
            }
            let off = lay.wd[b * nb_d + c];
            for (jp, row) in w_data[off..off + wb].chunks_mut(db).enumerate() {
                let j = b * fb + jp;
                for np in 0..db { row[np] = Fp::from_i64(wd_t[j * d + c * db + np] as i64); }
            }
        }
    }
    w_data
}

/// Where byte `i` of plane `plane` (0 Wg^T, 1 Wu^T, 2 Wd^T) lands in `w_data`.
fn w_offset_of(lay: &LayoutV3, plane: usize, i: usize) -> usize {
    let (db, fb) = (1usize << lay.log_db, 1usize << lay.log_fb);
    if plane < 2 {
        let (k, j) = (i / lay.f, i % lay.f);
        let (c, kp, b, jp) = (k / db, k % db, j / fb, j % fb);
        let offs = if plane == 0 { &lay.wg } else { &lay.wu };
        offs[c * lay.nb_f + b] + kp * fb + jp
    } else {
        let (j, n) = (i / lay.d, i % lay.d);
        let (b, jp, c, np) = (j / fb, j % fb, n / db, n % db);
        lay.wd[b * lay.nb_d + c] + jp * db + np
    }
}

/// The driver's PCS parameters for the W matrix: `pcs_params(params, lay.log_wb)`
/// = `log_cols.min(log_wb)` with the driver's `inv_rate` and `col_checks`.
fn w_pcs(lay: &LayoutV3, log_cols: u32, num_col_checks: usize) -> PcsParams {
    PcsParams { log_cols: log_cols.min(lay.log_wb), inv_rate: 4, num_col_checks }
}

fn lcg_planes(seed: u64, len: usize) -> Vec<i8> {
    let mut s = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15).wrapping_add(1);
    (0..len).map(|_| { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); (s >> 33) as u8 as i8 }).collect()
}

/// [round 7] Real packing, real key, small shapes: one changed plane byte
/// changes ONE committed element (at the offset the layout predicts), the
/// KEY (a clean miss) and the ROOT. Three shapes: fb > db, db > fb, and
/// d = 8192 so that `nb_d = 2` and the second d-block's offsets are exercised.
///
/// What this does NOT show, and the doc must say: the key is derived from the
/// CONTENT the prover holds. Any planes handed to the prover get a key and an
/// entry — approval is not an input to `WKey`, so a content-derived key
/// cannot authenticate that the content was approved; it only guarantees that
/// an entry is never reused for different content.
#[test]
fn the_callers_packing_ties_the_key_to_the_committed_data() {
    let _g = serial();
    let _ = shared_dir();
    for (case, (d, f)) in [(32usize, 16usize), (16, 64), (8192, 16)].into_iter().enumerate() {
        let lay = LayoutV3::new(16, d, f);
        let p = w_pcs(&lay, LOG_COLS, 16);
        let ntt = tables_for(&p);
        let (wg, wu, wd) = (lcg_planes(10 + case as u64, d * f), lcg_planes(20 + case as u64, d * f), lcg_planes(30 + case as u64, f * d));
        let l = 230 + case;
        let data = pack_w_v3(&lay, &wg, &wu, &wd);
        assert_eq!(data.len(), lay.w_len);
        assert_eq!(data.len() % p.cols(), 0, "the packed W is whole rows");
        let key = WKey::new("v3", l, d, f, &wg, &wu, &wd);
        let (base, first) = commit_counting(&p, &data, &ntt, &key);
        assert_eq!(first, CLEAN_MISS, "shape {d}x{f}: first commit");
        let (again, second) = commit_counting(&p, &data, &ntt, &key);
        assert_eq!(second, HIT, "shape {d}x{f}: the same planes, packed again, HIT");
        assert_eq!(again.tree.root(), base.tree.root());

        for (which, name) in [(0usize, "Wg^T"), (1, "Wu^T"), (2, "Wd^T")] {
            let mut pl = [wg.clone(), wu.clone(), wd.clone()];
            let len = pl[which].len();
            let i = len - 1 - len / 3; // in the last third: the second d-block when there is one
            pl[which][i] = pl[which][i].wrapping_add(1);
            let data2 = pack_w_v3(&lay, &pl[0], &pl[1], &pl[2]);
            let diffs: Vec<usize> = (0..data.len()).filter(|&j| data[j] != data2[j]).collect();
            assert_eq!(diffs, vec![w_offset_of(&lay, which, i)],
                       "shape {d}x{f} {name}[{i}]: one changed byte changes exactly ONE committed element, at the layout's offset");
            assert_eq!(data2[diffs[0]], Fp::from_i64(pl[which][i] as i64), "with the new value");
            let key2 = WKey::new("v3", l, d, f, &pl[0], &pl[1], &pl[2]);
            let (other, o) = commit_counting(&p, &data2, &ntt, &key2);
            assert_eq!(o, CLEAN_MISS, "shape {d}x{f} {name}[{i}]: the KEY changed — a clean miss");
            assert_ne!(other.tree.root(), base.tree.root(), "shape {d}x{f} {name}[{i}]: and the committed ROOT changed with the data");
        }
    }
}

/// A damaged entry must be REJECTED and re-committed, never used.
#[test]
fn a_corrupted_entry_is_rejected_and_recommitted() {
    let _g = serial();
    let (wg, wu, wd) = (planes(9, 64), planes(8, 64), planes(7, 64));
    let k = WKey::new("v3", 77, 8, 8, &wg, &wu, &wd);
    let (p, ntt, d) = (params(), tables(), data(4));

    let _ = shared_dir();
    let good = wcache::commit_w(&p, &d, &ntt, &k);
    // flip a byte in the middle of THIS key's stored tree
    let entry = std::fs::read_dir(shared_dir()).unwrap()
        .filter_map(|e| e.ok())
        .find(|e| e.file_name().to_string_lossy().starts_with("v3-l77-"))
        .expect("this key's entry").path();
    let mut bytes = std::fs::read(&entry).unwrap();
    let mid = bytes.len() / 2;
    bytes[mid] ^= 0xFF;
    std::fs::write(&entry, &bytes).unwrap();

    let (after, o) = commit_counting(&p, &d, &ntt, &k);
    assert_eq!(o, (0, 1, 1), "a corrupted entry must be REJECTED (then a miss), not loaded");
    assert_eq!(good.tree.root(), after.tree.root(),
               "after rejecting, the re-commit must reproduce the true root");
}

/// CONFIGURE IS ONCE PER PROCESS, AND THAT HAS A DEPLOYMENT CONSEQUENCE.
///
/// `DIR` is a `OnceLock`: a second `configure` panics, and there is no way to
/// clear it. Since the P3 prover asserts `wcache::dir().is_none()`, a process
/// that has configured a cache for P1 can NEVER serve a P3 proof afterwards —
/// it would hit that assert. A server must choose cached-P1 or P3 at startup;
/// it cannot mix them in one process.
///
/// [round 7] This is the lifecycle fact only. The first round let it stand in
/// for the P3 refusal, which Codex rightly called an INFERRED refusal; the
/// executed one is `p3_with_wcache_is_refused_by_the_driver_before_any_work`.
#[test]
fn configure_is_once_per_process_so_a_cached_process_cannot_later_serve_p3() {
    let _g = serial();
    let _ = shared_dir();
    assert!(wcache::dir().is_some(), "the shared directory is configured");

    // there is no clear: a second configure of ANY value panics
    let again = std::panic::catch_unwind(|| wcache::configure(None));
    assert!(again.is_err(), "configure must be once-per-process");
    assert!(
        wcache::dir().is_some(),
        "and it is still configured afterwards — which is exactly why a P3 proof \
         in this process would trip its `wcache::dir().is_none()` assert"
    );
}

/// The entry count grows with distinct keys and nothing evicts: capacity is
/// unbounded and invalidation is by key, never by age or size.
#[test]
fn there_is_no_eviction_entries_accumulate_by_key() {
    let _g = serial();
    let _ = shared_dir();
    let (wu, wd) = (planes(2, 64), planes(3, 64));
    let (p, ntt, d) = (params(), tables(), data(4));
    let before = entries_for("v3-l4");
    for l in 40..45usize {
        let wg = planes(l as i8, 64);
        let k = WKey::new("v3", l, 8, 8, &wg, &wu, &wd);
        let _ = wcache::commit_w(&p, &d, &ntt, &k);
    }
    let after = entries_for("v3-l4");
    assert_eq!(after - before, 5, "each distinct key adds an entry; nothing is evicted");
}

/// [round 7] SAME-KEY CONCURRENT WRITERS. `save_tree` writes
/// `path.with_extension("wc.tmp")` and renames it over the entry — the SAME
/// temporary name for every writer of a key. Eight threads commit one key
/// from a barrier, twelve rounds (twelve keys). What the shared name can do:
///   * a second writer's `fs::write` opens the first writer's tmp with
///     O_TRUNC, so the inode that gets renamed into place can be partial for
///     a moment — a reader in that window is REJECTED ("truncated") and
///     re-commits (counted in `rejected`);
///   * the rename of whoever comes second fails with ENOENT (the tmp is
///     gone), logged as "cannot write ...; continuing uncached" — its commit
///     is still used in memory, only the save is lost. There is no counter
///     for that, so it is recovered here as `misses - saves`, where saves =
///     `bytes_written` growth / entry size.
/// What it CANNOT do: leave a wrong entry. Every writer of a key writes the
/// SAME bytes (same data, same tree), the last opener writes them completely
/// after the last truncation, and `load_tree` verifies every level on load.
/// The assertions are the invariants; the counts are printed so the ledger
/// can record what was actually observed.
#[test]
fn same_key_concurrent_writers_leave_one_verifying_entry() {
    let _g = serial();
    let _ = shared_dir();
    const N: usize = 8;
    const ROUNDS: usize = 12;
    let p = PcsParams { log_cols: 12, inv_rate: 4, num_col_checks: 16 }; // nn 16384: a 1 MB entry
    let ntt = tables_for(&p);
    let d = data_for(&p, 8);
    let (wu, wd) = (planes(52, 64), planes(53, 64));
    let entry_bytes = (8 + 32 + 8 + 4 + 4 + 8 + 4 + 32) + (2 * p.enc_cols() - 1) * 32;
    let (mut t_hits, mut t_misses, mut t_rejected, mut t_saves, mut t_lost) = (0, 0, 0, 0, 0);
    for r in 0..ROUNDS {
        let wg = planes(r as i8, 64);
        let l = 300 + r;
        let key = WKey::new("v3", l, 8, 8, &wg, &wu, &wd);
        let prefix = format!("v3-l{l:02}-");
        let s0 = wcache::stats();
        let barrier = Barrier::new(N);
        let roots: Vec<[u8; 32]> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..N).map(|_| {
                let (b, p, d, ntt, key) = (&barrier, &p, &d, &ntt, &key);
                s.spawn(move || { b.wait(); wcache::commit_w(p, d, ntt, key).tree.root() })
            }).collect();
            hs.into_iter().map(|h| h.join().expect("a writer thread panicked")).collect()
        });
        let s1 = wcache::stats();
        let (hits, misses, rejected) = (s1.hits - s0.hits, s1.misses - s0.misses, s1.rejected - s0.rejected);
        let written = (s1.bytes_written - s0.bytes_written) as usize;
        assert_eq!(written % entry_bytes, 0, "round {r}: bytes_written grows by whole entries");
        let saves = written / entry_bytes;
        assert!(roots.iter().all(|x| *x == roots[0]), "round {r}: every writer computed the same root");
        assert_eq!(hits + misses, N, "round {r}: every writer either hit or missed");
        assert!(saves <= misses, "round {r}: only a miss saves");
        let lost = misses - saves;
        assert_eq!(files_with(&prefix, ".wc").len(), 1, "round {r}: exactly ONE entry for the key");
        assert!(files_with(&prefix, ".tmp").is_empty(), "round {r}: no temporary file left behind");
        let entry = Path::new(shared_dir()).join(&files_with(&prefix, ".wc")[0]);
        assert_eq!(std::fs::metadata(&entry).unwrap().len() as usize, entry_bytes, "round {r}: the surviving entry is complete");
        // the entry must LOAD AND VERIFY to the writers' root
        let (after, o) = commit_counting(&p, &d, &ntt, &key);
        assert_eq!(o, HIT, "round {r}: the surviving entry loads and verifies");
        assert_eq!(after.tree.root(), roots[0], "round {r}: to the writers' root");
        t_hits += hits; t_misses += misses; t_rejected += rejected; t_saves += saves; t_lost += lost;
    }
    eprintln!("[ZK60-CL9] same-key writers: {ROUNDS} rounds x {N} threads: hits {t_hits} | misses {t_misses} | rejected {t_rejected} | saves {t_saves} | lost renames (continuing uncached) {t_lost}");
}

// ---------------------------------------------------------------------------
// [round 7] THE PROCESS TESTS. The prover binary, CPU, 4 threads, `--seed 1`.
// ---------------------------------------------------------------------------

const V3_EXPORT_DEFAULT: &str = "/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export";
const M125_EXPORT_DEFAULT: &str = "/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl";
/// The frozen 12x512 P1 `--zk --seed 1 --profile v3` proof (TASK_BOARD / CL5 matrix).
const FROZEN_P1_SHA: &str = "40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17";
const FROZEN_P1_LEN: u64 = 87_697_008;
/// The 12x512 P3 `--seed 1` proof: 88,189,680 B per results/cl5_matrix.log
/// (three GPU reps); the digest was established on the CPU path on
/// 2026-09-06 (this file's ground-truth run, twice) and is asserted so that
/// P3 under `--seed 1` stays deterministic.
const P3_LEN: u64 = 88_189_680;
const P3_SHA_SEED1_CPU: &str = "be8d13cc5c2d1b2d515854c30dbc8330c5e4165c0cdc4cb641472ae5744d3bea";

fn v3_export() -> Option<String> {
    let dir = std::env::var("HL_EXPORT_DIR").unwrap_or_else(|_| V3_EXPORT_DEFAULT.to_string());
    if Path::new(&dir).join("layer00_WgT.bin").is_file() { Some(dir) } else { None }
}

/// NOT silently: this writes to the process's stderr directly, which libtest
/// does not capture (it captures only the `print!`/`eprint!` macros), so the
/// line reaches the terminal even though the test then passes.
fn loud_skip(test: &str) {
    use std::io::Write;
    let mut e = std::io::stderr();
    let _ = writeln!(e, "\n[ZK60-CL9] SKIPPED {test}: the 125M v3 export is not at {} (layer00_WgT.bin missing).\n[ZK60-CL9]   Set HL_EXPORT_DIR to the export directory to run it. This test was NOT executed.\n",
                     std::env::var("HL_EXPORT_DIR").unwrap_or_else(|_| V3_EXPORT_DEFAULT.to_string()));
}

fn test_dir(tag: &str) -> PathBuf {
    let p = std::env::temp_dir().join(format!("zk60_cl9_{}_{tag}", std::process::id()));
    let _ = std::fs::remove_dir_all(&p);
    std::fs::create_dir_all(&p).unwrap();
    p
}

/// One prover PROCESS: `pass 12 512 --threads 4 --profile v3 --seed 1 --export <v3> <extra>`,
/// HL_GPU unset (the binary is built without the GPU feature anyway), the
/// cache verbose so MISS/HIT lines can be counted.
fn prover(export: &str, extra: &[&str]) -> std::process::Output {
    let mut c = Command::new(env!("CARGO_BIN_EXE_hashline"));
    c.args(["pass", "12", "512", "--threads", "4", "--profile", "v3", "--seed", "1", "--export", export])
        .args(extra)
        .env_remove("HL_GPU")
        .env("HL_WCACHE_VERBOSE", "1")
        .env("M125_EXPORT_DIR", std::env::var("M125_EXPORT_DIR").unwrap_or_else(|_| M125_EXPORT_DEFAULT.to_string()));
    c.output().expect("spawn the prover binary")
}

/// The driver's `PROOF sha256 <hex> (<n> B) ...` line.
fn proof_line(stdout: &str) -> (String, u64) {
    let l = stdout.lines().find(|l| l.starts_with("PROOF sha256 ")).expect("a PROOF sha256 line");
    let mut it = l.split_whitespace().skip(2);
    let hex = it.next().unwrap().to_string();
    let n = it.next().unwrap().trim_start_matches('(').parse().unwrap();
    (hex, n)
}

fn show(o: &std::process::Output) -> String {
    format!("exit {:?}\n--- stdout ---\n{}\n--- stderr ---\n{}", o.status.code(), String::from_utf8_lossy(&o.stdout), String::from_utf8_lossy(&o.stderr))
}

/// [round 7] "equivalent approved public state preserves the FULL proof
/// bytes", as PROOF BYTES in two configured PROCESSES: a cold run into an
/// empty cache directory (12 MISS lines) and a warm run into the same one
/// (12 HIT lines). Both must exit 0, print ACCEPT, print the frozen digest,
/// and the two `--proof-out` files must be byte-identical and hash to it —
/// the file bytes are compared and hashed HERE, not just the printed line.
/// Then the real-layer cross-check (see the packing section).
#[test]
fn cold_and_warm_processes_produce_the_same_verified_proof_bytes() {
    let Some(export) = v3_export() else { loud_skip("cold_and_warm_processes_produce_the_same_verified_proof_bytes"); return; };
    let dir = test_dir("coldwarm");
    let wc = dir.join("wcache"); // does not exist yet: the cold process creates it
    let (cold_out, warm_out) = (dir.join("cold.bin"), dir.join("warm.bin"));

    let cold = prover(&export, &["--zk", "--wcache", wc.to_str().unwrap(), "--proof-out", cold_out.to_str().unwrap()]);
    let (co, ce) = (String::from_utf8_lossy(&cold.stdout).to_string(), String::from_utf8_lossy(&cold.stderr).to_string());
    assert_eq!(cold.status.code(), Some(0), "the COLD process must exit 0\n{}", show(&cold));
    assert!(co.contains("PASS-V3 ACCEPT [ZK]"), "the COLD process must ACCEPT\n{}", show(&cold));
    assert_eq!(ce.matches("wcache MISS -> wrote").count(), 12, "cold: every layer is a MISS\n{ce}");
    assert_eq!(ce.matches("wcache HIT").count(), 0, "cold: nothing HITs\n{ce}");
    // NOTE (found writing this): `pass_zk_v3` never prints `wcache::report()`
    // (only `pass` and `pass_v3` do, hashline.rs:764/1039), so the ZK pass has
    // no "hits N | misses M" summary line to assert on — the per-layer verbose
    // lines above are the evidence. Recorded in the doc for the driver's owner.
    assert_eq!(proof_line(&co), (FROZEN_P1_SHA.to_string(), FROZEN_P1_LEN), "cold: the frozen proof");
    let entries: Vec<_> = std::fs::read_dir(&wc).unwrap().filter_map(|e| e.ok()).filter(|e| e.file_name().to_string_lossy().ends_with(".wc")).collect();
    assert_eq!(entries.len(), 12, "cold: twelve entries written");

    let warm = prover(&export, &["--zk", "--wcache", wc.to_str().unwrap(), "--proof-out", warm_out.to_str().unwrap()]);
    let (wo, we) = (String::from_utf8_lossy(&warm.stdout).to_string(), String::from_utf8_lossy(&warm.stderr).to_string());
    assert_eq!(warm.status.code(), Some(0), "the WARM process must exit 0\n{}", show(&warm));
    assert!(wo.contains("PASS-V3 ACCEPT [ZK]"), "the WARM process must ACCEPT\n{}", show(&warm));
    assert_eq!(we.matches("wcache HIT").count(), 12, "warm: every layer HITs\n{we}");
    assert_eq!(we.matches("wcache MISS").count(), 0, "warm: nothing misses\n{we}");
    assert!(!we.contains("REJECTED"), "warm: nothing is rejected\n{we}");
    assert_eq!(proof_line(&wo), (FROZEN_P1_SHA.to_string(), FROZEN_P1_LEN), "warm: the frozen proof");

    // THE BYTES
    let (cb, wb) = (std::fs::read(&cold_out).unwrap(), std::fs::read(&warm_out).unwrap());
    assert_eq!(cb.len() as u64, FROZEN_P1_LEN);
    assert!(cb == wb, "the cold and warm proof FILES must be byte-identical");
    assert_eq!(hashline::export::sha256_hex(&cb), FROZEN_P1_SHA, "and hash to the frozen digest");

    real_layer_cross_check(&export, &wc);
    let _ = std::fs::remove_dir_all(&dir);
}

/// [round 7] THE CALLER-CONSISTENCY PROOF ON A REAL LAYER. The cold process's
/// layer-0 entry is copied into this process's cache directory. This test
/// then reads layer 0's three planes from the export, packs them with
/// `pack_w_v3`, builds `WKey::new("v3", 0, 768, 2048, ..)` and the driver's
/// PCS parameters, and commits. Two facts, each exact:
///   * it HITs — `load_tree` compares the file's 32-byte key digest with the
///     one computed here, so the KEY this test builds (profile, l, d, f,
///     log_cols, inv_rate, rows, len, three plane digests) IS the prover's;
///   * the loaded tree's root equals `pcs::commit` of THIS packing, so the
///     DATA the prover paired with that key IS this packing of those planes.
fn real_layer_cross_check(export: &str, cold_dir: &Path) {
    let _g = serial();
    let _ = shared_dir();
    let entry = std::fs::read_dir(cold_dir).unwrap().filter_map(|e| e.ok())
        .find(|e| { let n = e.file_name().to_string_lossy().to_string(); n.starts_with("v3-l00-") && n.ends_with(".wc") })
        .expect("the cold process's layer-0 entry");
    std::fs::copy(entry.path(), Path::new(shared_dir()).join(entry.file_name())).unwrap();

    let read = |name: &str| -> Vec<i8> { std::fs::read(Path::new(export).join(name)).unwrap().into_iter().map(|b| b as i8).collect() };
    let (wg, wu, wd) = (read("layer00_WgT.bin"), read("layer00_WuT.bin"), read("layer00_WdT.bin"));
    let (d, f) = (768usize, 2048usize);
    assert_eq!((wg.len(), wu.len(), wd.len()), (d * f, d * f, f * d), "the 125M planes");
    let lay = LayoutV3::new(512, d, f);
    let data = pack_w_v3(&lay, &wg, &wu, &wd);
    let p = w_pcs(&lay, 14, 256); // the driver's defaults: log_cols 14, inv_rate 4, col checks 256
    assert_eq!(data.len() / p.cols(), 288, "rows 288, as the prover's HIT line reports");
    let ntt = tables_for(&p);
    let key = WKey::new("v3", 0, d, f, &wg, &wu, &wd);
    let (cm, o) = commit_counting(&p, &data, &ntt, &key);
    assert_eq!(o, HIT, "the prover's layer-0 entry must HIT under the key this test rebuilt from the export planes (a rejection here = the key digest differs; a miss = the filename differs)");
    let fresh = pcs::commit(&p, &data, &ntt);
    assert_eq!(cm.tree.root(), fresh.tree.root(), "the prover's stored tree must be the tree of THIS packing of the planes");
}

/// [round 7] THE EXECUTED P3 REFUSAL. `--p3 --wcache DIR` in a real process:
/// exit 2, "REFUSED: --wcache with --p3." first on stderr, nothing on stdout,
/// and — because the refusal is in `parse_opts`, before `wcache::configure`
/// and before the export is opened — the cache directory is never created and
/// a nonexistent export is never read. Needs no fixture.
#[test]
fn p3_with_wcache_is_refused_by_the_driver_before_any_work() {
    let dir = std::env::temp_dir().join(format!("zk60_cl9_{}_p3refused", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    let wc = dir.join("wcache"); // MUST NOT come to exist
    let out = Command::new(env!("CARGO_BIN_EXE_hashline"))
        .args(["pass", "12", "512", "--threads", "4", "--profile", "v3", "--seed", "1",
               "--export", "/nonexistent/zk60-cl9-export", "--p3", "--wcache", wc.to_str().unwrap()])
        .env_remove("HL_GPU")
        .output().expect("spawn the prover binary");
    let err = String::from_utf8_lossy(&out.stderr).to_string();
    assert_eq!(out.status.code(), Some(2), "the refusal exit code\n{}", show(&out));
    assert!(err.starts_with("REFUSED: --wcache with --p3."), "the refusal is the FIRST thing said\n{}", show(&out));
    assert!(err.contains("recoverable by linear algebra"), "and says why\n{err}");
    assert!(out.stdout.is_empty(), "nothing is proved or printed\n{}", show(&out));
    assert!(!wc.exists() && !dir.exists(), "the refusal precedes `wcache::configure`: the directory is never created");
    assert!(!err.contains("nonexistent") && !err.contains("cannot read") && !err.contains("No such file"),
            "and precedes the export read: the nonexistent export is never opened\n{err}");
}

/// [round 7] THE ACCEPTING UNCACHED P3 PROCESS. `--p3 --seed 1` with no
/// `--wcache`: exit 0, ACCEPT, the P3 proof size, the recorded digest, and no
/// cache activity of any kind in the log (no MISS/HIT lines, no cache report —
/// `wcache::report()` is `None` when nothing is configured).
#[test]
fn a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache() {
    let Some(export) = v3_export() else { loud_skip("a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache"); return; };
    let dir = test_dir("p3");
    let out_p = dir.join("p3.bin");
    let out = prover(&export, &["--p3", "--proof-out", out_p.to_str().unwrap()]);
    let (so, se) = (String::from_utf8_lossy(&out.stdout).to_string(), String::from_utf8_lossy(&out.stderr).to_string());
    assert_eq!(out.status.code(), Some(0), "the uncached P3 process must exit 0\n{}", show(&out));
    assert!(so.contains("PASS-V3 ACCEPT [ZK]"), "and ACCEPT\n{}", show(&out));
    assert!(so.contains("MODE P3"), "in mode P3\n{so}");
    assert!(!so.contains("wcache") && !se.contains("wcache"), "no cache activity of any kind\n{}", show(&out));
    assert_eq!(proof_line(&so), (P3_SHA_SEED1_CPU.to_string(), P3_LEN), "the P3 proof size and digest");
    let bytes = std::fs::read(&out_p).unwrap();
    assert_eq!(bytes.len() as u64, P3_LEN);
    assert_eq!(hashline::export::sha256_hex(&bytes), P3_SHA_SEED1_CPU, "the file hashes to the recorded digest");
    let _ = std::fs::remove_dir_all(&dir);
}
