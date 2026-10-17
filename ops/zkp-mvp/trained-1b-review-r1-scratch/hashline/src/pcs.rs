//! Compatibility adapter; the canonical Ligero commitment lives in
//! `zkp_core::pcs` (moved there in CL20 round 12, byte-for-byte: same
//! encoding, leaves, labels, transcript consumption, RNG draw order and
//! serialization).
//!
//! What stays here is hashline's GPU dispatch and its process-level
//! switches: the runtime toggle (`HL_GPU=1`, `gpu::enabled()`) and the
//! decline-to-CPU messages live in `gpu::backend()`, the `HL_TIMING` report
//! of `open` is printed here from the core's returned clocks, and
//! `commit_zk_device` (the hiding commitment of a buffer the device already
//! holds) keeps its `gpu::Pooled` argument. Every type below IS the core's
//! type: `Committed`, `CommittedZk` and `Store` are the core's generics
//! instantiated with the device store (`gpu::DevStore` = the CUDA
//! `DevCommit` under `--features gpu-cuda`, the uninhabited
//! `zkp_core::pcs::NoExternal` otherwise), so the `Store::Device(dc)` arms
//! in layer.rs, zk.rs and wcache.rs compile unchanged and nothing is
//! converted or copied.

pub use zkp_core::pcs::*;

use crate::field::Fp;
use crate::gpu::{backend, DevStore};
use crate::ntt::NttTables;
use crate::transcript::Transcript;
use zkp_core::rng::ZkRng;

/// The core's store, holding hashline's device form when the GPU made it.
pub type Store = zkp_core::pcs::Store<DevStore>;
/// The core's committed matrix over hashline's device store.
pub type Committed = zkp_core::pcs::Committed<DevStore>;
/// The core's hiding committed matrix over hashline's device store.
pub type CommittedZk = zkp_core::pcs::CommittedZk<DevStore>;

/// Commit to `data` (length must be a multiple of n); the device path
/// (`HL_GPU=1`) is offered first and declines to the CPU body.
pub fn commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Committed {
    zkp_core::pcs::commit_with(&backend(), params, data, ntt)
}

/// [FSP-HOST] ITEM (a) of the five-second plan's step 4: commit a v3
/// layer's W matrix with the three int8 weight planes as the SOURCE,
/// instead of the `Vec<Fp>` block tiling of them that `prove_layer_v3`
/// builds and throws away.
///
/// `None` is a DECLINE and never an error: the caller (layer.rs, through
/// `wcache::commit_w_planes`) then builds that `Vec<Fp>` exactly as before
/// and calls `commit`, so the inherited arm stays in the binary for the
/// A/B and for rollback, and every configuration this entry does not serve
/// — no `gpu-cuda` feature, `HL_GPU` unset, the device declining the
/// shape, `HL_GPU_NARROW=0`, no `k_widen`, no packing scratch — keeps the
/// behaviour it has today.
///
/// It cannot go through `zkp_core::pcs::commit_with` (the core is not this
/// lane's crate and its `Backend` seam passes `&[Fp]`), so it mirrors that
/// function's DEVICE BRANCH exactly — `try_commit`'s leaves,
/// `MerkleTree::build`, `Committed { params, rows, store: Device, tree }` —
/// the way `commit_zk_device` below already does.
#[cfg(feature = "gpu-cuda")]
pub fn commit_planes(params: &PcsParams, pt: &crate::gpu::PlaneTiling, ntt: &NttTables) -> Option<Committed> {
    use crate::merkle::MerkleTree;
    if !crate::gpu::enabled() {
        return None;
    }
    let n = params.cols();
    let len = pt.len();
    if len == 0 || len % n != 0 {
        return None;
    }
    match crate::gpu::dev_commit_planes(params, pt, ntt) {
        Ok((dc, leaves)) => {
            let tree = MerkleTree::build(leaves);
            Some(Committed { params: *params, rows: len / n, store: Store::Device(dc), tree })
        }
        Err(e) => {
            eprintln!("[FSP-HOST] plane commit declined ({e}); Vec<Fp> path");
            None
        }
    }
}

/// Without the device feature there is no plane path at all.
#[cfg(not(feature = "gpu-cuda"))]
pub fn commit_planes(_params: &PcsParams, _pt: &crate::gpu::PlaneTiling, _ntt: &NttTables) -> Option<Committed> {
    None
}

/// Prover: open `claims` on the commitment (see `zkp_core::pcs::open`);
/// `HL_TIMING=1` prints the phase clocks as before.
pub fn open(cm: &Committed, claims: &[Claim], tr: &mut Transcript) -> Opening {
    let vb = std::env::var("HL_TIMING").map(|v| v == "1").unwrap_or(false);
    let (opening, t) = zkp_core::pcs::open_timed(cm, claims, tr);
    if vb {
        eprintln!(
            "[pcs::open] rows {} n {} claims {} groups {}: group_claims {:.4} | rhos {:.4} | fold {:.4} | absorb+idx {:.4} | columns {:.4} s",
            cm.rows, cm.params.cols(), t.claims, t.groups, t.group_claims, t.rhos, t.fold, t.absorb_idx, t.columns
        );
    }
    opening
}

/// Commit in ZK mode. `rng` supplies the pads and the salts.
pub fn commit_zk(params: &PcsParams, data: &[Fp], ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk {
    commit_zk_owned(params, data.to_vec(), ntt, zk, rng)
}

/// `commit_zk` taking the data by value (no host copy: the commitment keeps it).
pub fn commit_zk_owned(params: &PcsParams, data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk {
    zkp_core::pcs::commit_zk_owned_with(&backend(), params, data, ntt, zk, rng)
}

/// Commit under the profile's keyed hash domains. The backend has a distinct
/// keyed offer; if CUDA declines, core uses the CPU oracle with the same
/// fresh pads, salts and receipt encoding.
pub fn commit_zk_owned_tagged(params: &PcsParams, data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng, tag: &zkp_core::hashtag::HashTag) -> CommittedZk {
    zkp_core::pcs::commit_zk_owned_with_tag(&backend(), params, data, ntt, zk, rng, tag)
}

/// [UPERF3-ZA] Commit a DEVICE-resident data buffer in ZK mode (the H
/// commitment on the GPU path: the helper columns were computed on the
/// device; `host_data` holds the host-known rows — the masks, the table
/// helpers — at their offsets and zeros elsewhere). Draws the pads and the
/// salts in the same order as `commit_zk`, so the bytes match the CPU path.
#[cfg(feature = "gpu-cuda")]
pub fn commit_zk_device(params: &PcsParams, d_data: crate::gpu::Pooled, rows: usize, host_data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> Result<CommittedZk, String> {
    use crate::merkle::{Digest, MerkleTree};
    use rayon::prelude::*;
    let n = params.cols();
    let nn = params.enc_cols();
    assert_eq!(host_data.len(), rows * n);
    let q = zk.q_pad;
    let pads = rng.fp_vec(rows * q);
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();
    let pows = coset_powers(zk.coset, nn);
    let (dc, leaves) = crate::gpu::dev_commit_zk_from(params, d_data, rows, &pads, &pows, ntt)?;
    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| salt_leaf(l, s)).collect();
    let tree = MerkleTree::build(salted);
    Ok(CommittedZk { cm: Committed { params: *params, rows, store: Store::Device(dc), tree }, zk: *zk, data: host_data, pads, salts, mask_rows: Vec::new(), prox_mask_row: None })
}
