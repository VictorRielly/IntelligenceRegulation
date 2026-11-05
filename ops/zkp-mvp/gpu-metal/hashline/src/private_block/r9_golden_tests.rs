//! **NATIVE R9: byte identity of the NON-DD profiles across R8 -> R9**
//! (coordinator's check (a)). TEST CODE ONLY. Public synthetic data only.
//!
//! Proof bytes come from OS randomness, so two proofs never repeat. This test
//! proves ONE block with a SEEDED generator (`ZkRng::new`, test code only —
//! the production path's census still forbids it there) through the shared
//! `protocol::prove_core`, at the TinyLlama T128 and Llama-3-8B T128 trained
//! shapes, on a generic dense witness, with a fixed transcript prefix and
//! deterministic endpoint data, and digests EVERYTHING the core produces: the
//! three roots, every slot proof, the three openings, the IO claims, the
//! absorb order and the final transcript state. The same file runs in a copy
//! of the R8 freeze (`r9/r8-golden-tree/`) to record the digests, and in the
//! R9 tree against them.
//!
//! Heavy (one width-2048 and one width-4096 T128 block): `#[ignore]`, run
//! through the guard by name.

use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::*;
use crate::field::Fp;
use crate::transcript::Transcript;

/// the R8 freeze's digests, recorded in `r9/r8-golden-tree/` (a copy of
/// `r8/frozen-tree/` with this file added) on 2026-10-19 (`782b64c9..`,
/// `05a22d72..`). D65(1), finding F12 (2026-11-04): re-pinned from this test's
/// own output under the `/2` profiles and `M` from theta^1; the digest covers
/// `M`'s opening and the final transcript state, and the profile string is
/// absorbed first, so both moved it. The R8/R9 byte identity this file was
/// written for no longer holds by design (`results/zk60_f12_fix_20261104/`).
const GOLDEN: &[(&str, &str)] = &[
    ("tinyllama-t128", "d21f06fe13ac860ecd0ebaca43537a20357642dc38c7f2a557f46448170703bd"),
    ("llama3-8b-t128", "d535bf8ae2a38cb1b56eb34719a8905a7f95e4a2be419de4ddb591b92c74ccb2"),
];

fn digest_of_seeded_block(sh: &Shape, blk: &BlockPublic, w: super::witness::Witness) -> String {
    let lay = Layout::for_shape(sh).unwrap();
    let rows = sh.endpoint_rows;
    let n = 1usize << sh.endpoint_log_n;
    let ids = Ids::new(sh).unwrap();
    // deterministic endpoint data: the padded input / output plane words in
    // the data rows, zero elsewhere (the core reads them; nothing here opens
    // an endpoint)
    let io = |p: usize| -> Vec<Fp> {
        let mut d = vec![Fp::ZERO; rows * n];
        for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
            d[i] = Fp::from_i64(*v);
        }
        d
    };
    let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
    let ntt = crate::ntt::NttTables::new(super::protocol::ntt_log_at(sh));
    let mut rng = crate::zk::ZkRng::new(20261019, b"native r9 golden");
    let mut tr = Transcript::new(b"native r9 golden");
    tr.absorb(b"profile", sh.profile.as_bytes());
    tr.absorb(b"schedule", &lay.schedule_digest());
    let mut ph = super::timing::Phases::start();
    let mut phases = Vec::new();
    let mut tick = std::time::Instant::now();
    let core = super::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the seeded core proof");
    let text = format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        core.a_root,
        core.h_root,
        core.mask_root,
        core.slots,
        core.mask_open,
        core.a_open,
        core.h_open,
        core.io_claims,
        core.order,
        core.lookups,
        tr.state()
    );
    eprintln!("R9-GOLDEN {}: {} slots, {} absorbs, debug text {} B", sh.profile, core.slots.len(), core.order.len(), text.len());
    blake3::hash(text.as_bytes()).to_hex().to_string()
}

fn check(name: &str, got: &str) {
    eprintln!("R9-GOLDEN-DIGEST {name} {got}");
    if let Some((_, want)) = GOLDEN.iter().find(|(n, _)| *n == name) {
        assert_eq!(got, *want, "{name}: the seeded core proof's bytes moved between R8 and R9");
    } else {
        assert!(GOLDEN.is_empty(), "{name} has no recorded golden");
    }
}

#[test]
#[ignore = "native lane heavy: seeded TinyLlama T128 block proof (byte identity across R8 -> R9)"]
fn r9_golden_seeded_tinyllama_t128_block_is_byte_identical() {
    let cal = super::trained_calib_tests::t3_calibration();
    let sh = Shape::tinyllama_trained(128, &cal, 9).unwrap();
    let (blk, input) = super::trained_calib_tests::trained_dense_block(&sh);
    let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the generic dense witness");
    check("tinyllama-t128", &digest_of_seeded_block(&sh, &blk, w));
}

#[test]
#[ignore = "native lane heavy: seeded Llama-3-8B T128 block proof (byte identity across R8 -> R9)"]
fn r9_golden_seeded_llama3_8b_t128_block_is_byte_identical() {
    let cal = NormCalibration { cn_a: 6380, cn_m: 6672, ..super::trained_calib_tests::llama3_8b_calibration() };
    let sh = Shape::llama3_8b_trained(128, &cal, 9).unwrap();
    // the R4-2 / ladder bands at the 8B geometry: the FIRST admissible
    use super::trained_calib_tests::{Bands, TRAINED_BANDS};
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = super::trained_calib_tests::trained_dense_block_with(&sh, b);
        if let Ok(w) = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input) {
            eprintln!("R9-GOLDEN 8B bands {b:?}");
            check("llama3-8b-t128", &digest_of_seeded_block(&sh, &blk, w));
            return;
        }
    }
    panic!("no candidate band is admissible at the 8B T128 geometry");
}
