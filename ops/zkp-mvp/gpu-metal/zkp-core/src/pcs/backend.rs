//! The narrow seam between the CPU commitment and an accelerator.
//!
//! The core names no device. A [`Backend`] may take over the two
//! encode-and-hash steps of the commitment (`commit`, `commit_zk`) and
//! hand back the column leaves together with an [`EncodedStore`], an
//! object that can later fold rows over the systematic data and gather
//! encoded columns from wherever it keeps the encoding. Declining
//! (`None`) runs the CPU body, which is the oracle.
//!
//! Differential discipline (carried over from hashline's GPU module): an
//! implementation MUST return exactly the leaves the CPU encoder would
//! produce for the same input, and its store MUST return exactly the field
//! values the host store would; the transcript then absorbs identical
//! bytes and the proof is byte-identical to the CPU path's. The core cannot
//! check this; the consumer's device oracle and frozen proof gates do.
//!
//! The CPU-only backend [`Cpu`] never takes over. Its store type
//! [`NoExternal`] has no values, so a CPU `Committed` cannot hold an
//! external store and the external arms of the commitment are unreachable
//! in a CPU build without any feature flag.

use super::PcsParams;
use crate::field::{Fp, Fp2};
use crate::merkle::Digest;
use crate::ntt::NttTables;

/// An encoding held outside the host `Vec<Fp>` (a device buffer, a file).
/// `Sync` because the opening reads the store from rayon workers, as the
/// host store is read.
pub trait EncodedStore: Sync {
    /// `rho^T M` for several `rho` at once over the systematic data
    /// (`rhos.len()` vectors of `n = 2^log_cols` entries each), the same
    /// linear map the host fold computes.
    fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String>;
    /// The encoded columns at `idx`, each the commitment's `rows` entries,
    /// in the order of `idx` (duplicates repeated).
    fn columns(&self, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String>;
    /// [ZK60-METAL] How many rho vectors the hiding opening hands to one
    /// `fold_rows` call. 4 is what the CUDA store has always received (its
    /// fold kernel's width); a store in unified memory folds every vector in
    /// one pass over the data. Values are identical either way: only the
    /// batching of the same linear map changes.
    fn fold_batch(&self) -> usize {
        4
    }
}

/// The store type of a backend that never takes over: no value of this
/// type exists, so `Store::Device(NoExternal)` cannot be constructed.
pub enum NoExternal {}

impl EncodedStore for NoExternal {
    fn fold_rows(&self, _rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
        match *self {}
    }
    fn columns(&self, _idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
        match *self {}
    }
}

/// Where the encode-and-hash of a commitment may run. Both hooks default
/// to declining; a consumer's runtime switch (hashline's `HL_GPU=1`)
/// belongs inside its implementation, not in the core.
pub trait Backend {
    type Store: EncodedStore;

    /// Encode `data` (rows x n, systematic RS to rows x nn) and hash its
    /// columns elsewhere. `None` = decline: the CPU body runs.
    fn try_commit(&self, params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Option<(Self::Store, Vec<Digest>)> {
        let _ = (params, data, ntt);
        None
    }

    /// The tagged hiding form. A backend must override this separately to
    /// attest that it hashes UNSALTED columns under the supplied public key.
    /// The default declines rather than silently using the unkeyed hook.
    fn try_commit_zk_keyed(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Option<(Self::Store, Vec<Digest>)> {
        let _ = (params, data, pads, pows, ntt, key);
        None
    }

    /// The hiding form: encode `data` with the per-row `pads` on the coset
    /// given by `pows` (see `encode_row_zk`) and hash the UNSALTED columns;
    /// the caller salts the leaves. `None` = decline.
    fn try_commit_zk(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Option<(Self::Store, Vec<Digest>)> {
        let _ = (params, data, pads, pows, ntt);
        None
    }
}

/// The CPU: never takes over, holds nothing externally.
pub struct Cpu;

impl Backend for Cpu {
    type Store = NoExternal;
}
