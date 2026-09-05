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
//!     a hit and a miss must produce the same commitment root
//!   * P3 must not be able to reach this cache at all

use hashline::field::Fp;
use hashline::ntt::NttTables;
use hashline::pcs::PcsParams;
use hashline::wcache::{self, WKey};
use std::sync::{Mutex, MutexGuard, OnceLock};

/// `wcache::configure` sets a PROCESS-GLOBAL directory, so these tests must
/// not run concurrently with each other.
fn serial() -> MutexGuard<'static, ()> {
    static L: OnceLock<Mutex<()>> = OnceLock::new();
    L.get_or_init(|| Mutex::new(())).lock().unwrap_or_else(|e| e.into_inner())
}

/// THE LIFECYCLE FACT THAT SHAPES THIS WHOLE FILE: `DIR` is a `OnceLock`, so
/// `configure` may be called ONCE per process and panics on a second call —
/// it cannot be changed and it cannot be cleared. Every test therefore shares
/// ONE directory and separates its cases by KEY, which is what the cache is
/// designed around anyway (the entry filename carries the key digest).
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

fn entries_for(prefix: &str) -> usize {
    std::fs::read_dir(shared_dir())
        .map(|d| d.filter_map(|e| e.ok())
                  .filter(|e| e.file_name().to_string_lossy().starts_with(prefix))
                  .count())
        .unwrap_or(0)
}

const LOG_COLS: u32 = 8;
const INV_RATE: usize = 4;

fn params() -> PcsParams {
    PcsParams { log_cols: LOG_COLS, inv_rate: INV_RATE, num_col_checks: 16 }
}

fn tables() -> NttTables {
    NttTables::new(LOG_COLS + (INV_RATE.trailing_zeros()))
}

fn data(rows: usize) -> Vec<Fp> {
    let n = 1usize << LOG_COLS;
    let mut s = 0x9E37_79B9u64;
    (0..rows * n)
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1);
            Fp::new(s % 0xFFFF_FFFF_0000_0001)
        })
        .collect()
}

fn planes(seed: i8, len: usize) -> Vec<i8> {
    (0..len).map(|i| seed.wrapping_add(i as i8)).collect()
}

/// Commit twice with the same key and return (root_first, root_second, hits).
fn commit_twice(key_a: &WKey, key_b: &WKey, rows: usize) -> ([u8; 32], [u8; 32], usize) {
    let (p, ntt, d) = (params(), tables(), data(rows));
    let _ = shared_dir();
    let before = wcache::stats().hits;
    let one = wcache::commit_w(&p, &d, &ntt, key_a);
    let two = wcache::commit_w(&p, &d, &ntt, key_b);
    let hits = wcache::stats().hits - before;
    (one.tree.root(), two.tree.root(), hits)
}

#[test]
fn equivalent_approved_state_hits_and_preserves_the_commitment_root() {
    let _g = serial();
    // a key unique to this test: the shared directory persists across tests,
    // so a key another test has already committed would start warm and this
    // would see two hits instead of one.
    let (wg, wu, wd) = (planes(11, 64), planes(12, 64), planes(13, 64));
    let k = WKey::new("v3", 101, 8, 8, &wg, &wu, &wd);
    let (a, b, hits) = commit_twice(&k, &k, 4);
    assert_eq!(hits, 1, "the second commit of identical approved state must HIT");
    assert_eq!(a, b, "a cache hit must reproduce the commitment root exactly");
}

/// Every field in the key must separate entries. A collision here would let a
/// stale approval reuse an incompatible commitment, which is the whole risk.
#[test]
fn every_keyed_field_separates_the_entry() {
    let _g = serial();
    let (wg, wu, wd) = (planes(1, 64), planes(2, 64), planes(3, 64));
    let base = WKey::new("v3", 0, 8, 8, &wg, &wu, &wd);

    let wg2 = {
        let mut v = wg.clone();
        v[0] = v[0].wrapping_add(1); // ONE byte of ONE weight plane
        v
    };
    let cases: Vec<(&str, WKey)> = vec![
        ("profile", WKey::new("v2", 0, 8, 8, &wg, &wu, &wd)),
        ("layer index", WKey::new("v3", 1, 8, 8, &wg, &wu, &wd)),
        ("d", WKey::new("v3", 0, 16, 8, &wg, &wu, &wd)),
        ("f", WKey::new("v3", 0, 8, 16, &wg, &wu, &wd)),
        ("one weight byte", WKey::new("v3", 0, 8, 8, &wg2, &wu, &wd)),
        ("plane order", WKey::new("v3", 0, 8, 8, &wu, &wg, &wd)),
    ];
    for (what, other) in cases {
        let before = wcache::stats().hits;
        let (p, ntt, d) = (params(), tables(), data(4));
        let _ = shared_dir();
        let _ = wcache::commit_w(&p, &d, &ntt, &base);
        let _ = wcache::commit_w(&p, &d, &ntt, &other);
        assert_eq!(wcache::stats().hits - before, 1,
                   "only the repeated BASE key may hit when changing the {what}");
    }
}

/// The PCS shape is part of the entry digest, so the same weights under a
/// different encoding cannot alias.
#[test]
fn a_different_pcs_shape_cannot_reuse_the_entry() {
    let _g = serial();
    let (wg, wu, wd) = (planes(1, 64), planes(2, 64), planes(3, 64));
    let k = WKey::new("v3", 0, 8, 8, &wg, &wu, &wd);
    let ntt = tables();
    let d = data(4);

    let _ = shared_dir();
    let before = wcache::stats().hits;
    let _ = wcache::commit_w(&params(), &d, &ntt, &k);
    // same weights, same key fields, DIFFERENT inv_rate
    let other = PcsParams { log_cols: LOG_COLS, inv_rate: 2, num_col_checks: 16 };
    let ntt2 = NttTables::new(LOG_COLS + 1);
    let _ = wcache::commit_w(&other, &d, &ntt2, &k);
    let hits = wcache::stats().hits - before;
    assert_eq!(hits, 0, "a different inv_rate must not reuse the entry");
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
        .find(|e| e.file_name().to_string_lossy().contains("l77"))
        .expect("this key's entry").path();
    let mut bytes = std::fs::read(&entry).unwrap();
    let mid = bytes.len() / 2;
    bytes[mid] ^= 0xFF;
    std::fs::write(&entry, &bytes).unwrap();

    let before = wcache::stats().rejected;
    let after = wcache::commit_w(&p, &d, &ntt, &k);
    let rejected = wcache::stats().rejected - before;

    assert_eq!(rejected, 1, "a corrupted entry must be REJECTED, not loaded");
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
