//! Opt-in encrypted registration material for FA4 H2; no stable P3 proof API.
//!
//! The caller supplies an independently trusted slot policy AND mask-row roles
//! matching its reviewed layout, plus an externally protected random 256-bit
//! key. Neither the file nor this module establishes model approval or privacy.
//! Immutable material and the canonical monotonic slot journal are separate:
//! reopening material must never recreate/reset a missing or exhausted journal.
//!
//! Storage requires a trusted local Unix filesystem. Creation is exclusive and
//! synced; incomplete files fail closed and are never automatically replaced.
//! AEAD protects file contents, not journal rollback or compromise of the host.

use crate::field::{Fp, P};
use crate::merkle::{Digest, MerkleTree};
use crate::ntt::NttTables;
use crate::pcs::{self, Committed, CommittedZk, Store};
use crate::stable_weight_slots::SlotPolicy;
use chacha20poly1305::{aead::AeadInPlace, KeyInit, XChaCha20Poly1305, XNonce};
use std::fs::{File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::Path;
use zeroize::{Zeroize, Zeroizing};

const MAGIC: &[u8; 8] = b"HLWMAT01";
const HEADER_BYTES: usize = 64; // magic + material-policy digest + nonce
const TAG_BYTES: usize = 16;

/// No Debug/Clone or serialization API. The caller owns external key custody.
/// Import a uniformly random key, not a password or the proof fixture seed.
///
/// ```compile_fail
/// use hashline::stable_weight_material::MaterialKey;
/// fn log_key(key: &MaterialKey) { println!("{key:?}"); }
/// ```
pub struct MaterialKey(Zeroizing<[u8; 32]>);
impl MaterialKey {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(Zeroizing::new(bytes))
    }
}

/// Independently supplied row roles, authenticated together with SlotPolicy.
/// Geometry/uniqueness checks do not establish that these roles provide privacy.
#[derive(Clone, Debug)]
pub struct MaterialPolicy {
    slots: SlotPolicy,
    mask_rows: Vec<usize>,
    prox_mask_row: Option<usize>,
    digest: Digest,
}
impl MaterialPolicy {
    pub fn new(
        slots: SlotPolicy,
        mask_rows: Vec<usize>,
        prox_mask_row: Option<usize>,
    ) -> Result<Self, MaterialError> {
        let rows = slots.binding().commitment.rows;
        let mut unique = std::collections::BTreeSet::new();
        if mask_rows.len() > rows
            || mask_rows.iter().any(|&r| r >= rows || !unique.insert(r))
            || prox_mask_row.is_some_and(|r| r >= rows || unique.contains(&r))
        {
            return Err(MaterialError::InvalidLayout);
        }
        let mut hash = blake3::Hasher::new();
        hash.update(b"hashline-stable-material-policy-v1/");
        hash.update(&slots.digest());
        hash.update(&(mask_rows.len() as u64).to_le_bytes());
        for &row in &mask_rows {
            hash.update(&(row as u64).to_le_bytes());
        }
        hash.update(&prox_mask_row.map_or(u64::MAX, |r| r as u64).to_le_bytes());
        Ok(Self {
            slots,
            mask_rows,
            prox_mask_row,
            digest: *hash.finalize().as_bytes(),
        })
    }
    pub fn slots(&self) -> &SlotPolicy {
        &self.slots
    }
    pub fn digest(&self) -> Digest {
        self.digest
    }
}

/// Trusted allocation limits, checked before reading/decrypting or constructing
/// NTT tables. These cap file bytes and encoded field elements, not total RSS.
#[derive(Clone, Copy, Debug)]
pub struct MaterialLimits {
    pub max_file_bytes: usize,
    pub max_encoded_elements: usize,
}
impl Default for MaterialLimits {
    fn default() -> Self {
        Self {
            max_file_bytes: 64 * 1024 * 1024,
            max_encoded_elements: 16 * 1024 * 1024,
        }
    }
}

#[derive(Debug)]
pub enum MaterialError {
    InvalidLayout,
    LimitExceeded,
    InvalidMaterial,
    PolicyMismatch,
    AuthenticationFailed,
    RootMismatch,
    UnsupportedStorage,
    Io(io::Error),
}
impl std::fmt::Display for MaterialError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::InvalidLayout => "invalid stable-weight material row roles",
            Self::LimitExceeded => "stable-weight material exceeds allocation limits",
            Self::InvalidMaterial => "invalid stable-weight material encoding or geometry",
            Self::PolicyMismatch => "stable-weight material belongs to a different policy",
            Self::AuthenticationFailed => "stable-weight material authentication failed",
            Self::RootMismatch => "stable-weight material does not reconstruct the trusted root",
            Self::UnsupportedStorage => {
                "stable-weight material requires a private regular file on a local Unix filesystem"
            }
            Self::Io(_) => "stable-weight material I/O failure",
        })
    }
}
impl std::error::Error for MaterialError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Io(e) => Some(e),
            _ => None,
        }
    }
}
impl From<io::Error> for MaterialError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

struct Geometry {
    n: usize,
    nn: usize,
    data: usize,
    pads: usize,
    encoded: usize,
    file_bytes: usize,
}
impl Geometry {
    fn new(policy: &MaterialPolicy, limits: MaterialLimits) -> Result<Self, MaterialError> {
        let b = policy.slots.binding();
        let checked = || {
            let n = 1usize.checked_shl(b.params.log_cols)?;
            let nn = n.checked_mul(b.params.inv_rate)?;
            let data = b.commitment.rows.checked_mul(n)?;
            let pads = b.commitment.rows.checked_mul(b.opts.q_pad)?;
            let encoded = b.commitment.rows.checked_mul(nn)?;
            let file_bytes = data
                .checked_add(pads)?
                .checked_mul(8)?
                .checked_add(nn.checked_mul(32)?)?
                .checked_add(HEADER_BYTES + TAG_BYTES)?;
            Some(Self {
                n,
                nn,
                data,
                pads,
                encoded,
                file_bytes,
            })
        };
        let g = checked().ok_or(MaterialError::LimitExceeded)?;
        if g.file_bytes > limits.max_file_bytes
            || g.encoded > limits.max_encoded_elements
            || g.file_bytes > isize::MAX as usize
            || g.encoded > isize::MAX as usize / 8
        {
            return Err(MaterialError::LimitExceeded);
        }
        Ok(g)
    }
}

// Wipe owned field vectors, including refused reconstructions. Existing PCS
// routines have their own temporary copies; this is not whole-process erasure.
#[derive(Default)]
struct SecretFields(Vec<Fp>);
impl Drop for SecretFields {
    fn drop(&mut self) {
        wipe_fields(&mut self.0);
    }
}
fn wipe_fields(fields: &mut [Fp]) {
    for value in fields {
        value.0.zeroize();
    }
}

/// Reconstructed CPU commitment with trusted row roles. No Debug/Clone. Owned
/// weights, pads, salts and encoding are wiped on ordinary drop. PCS temporaries,
/// caller copies, process aborts, swap and core dumps are outside that guarantee.
///
/// ```compile_fail
/// use hashline::stable_weight_material::RestoredMaterial;
/// fn duplicate(material: RestoredMaterial) { let copy = material.clone(); }
/// ```
pub struct RestoredMaterial(CommittedZk);
impl RestoredMaterial {
    /// Low-level PCS material only. A future stable prover must additionally
    /// consume a durable ReservedSlot and enforce its reviewed mask schedule.
    pub fn pcs(&self) -> &CommittedZk {
        &self.0
    }
}
impl Drop for RestoredMaterial {
    fn drop(&mut self) {
        wipe_fields(&mut self.0.data);
        wipe_fields(&mut self.0.pads);
        self.0.salts.zeroize();
        match &mut self.0.cm.store {
            Store::Host { encoded } => wipe_fields(encoded),
            // The core now represents CPU-only external storage with an empty
            // type. Matching the borrowed Store still requires this arm.
            #[cfg(not(any(feature = "gpu-cuda", feature = "gpu-metal")))]
            Store::Device(never) => match *never {},
            #[cfg(any(feature = "gpu-cuda", feature = "gpu-metal"))]
            Store::Device(_) => unreachable!("material reconstruction is CPU-only"),
        }
    }
}

fn reconstruct(
    policy: &MaterialPolicy,
    g: &Geometry,
    data: &[Fp],
    pads: &[Fp],
    salts: &[[u8; 32]],
) -> Result<(SecretFields, MerkleTree), MaterialError> {
    if data.len() != g.data
        || pads.len() != g.pads
        || salts.len() != g.nn
        || data.iter().chain(pads).any(|x| x.0 >= P)
    {
        return Err(MaterialError::InvalidMaterial);
    }
    let b = policy.slots.binding();
    let ntt = NttTables::new(g.nn.trailing_zeros());
    let pows = pcs::coset_powers(b.opts.coset, g.nn);
    let mut encoded = SecretFields(vec![Fp::ZERO; g.encoded]);
    // Use the canonical CPU row encoder; no new PCS arithmetic or RNG draws.
    for ((out, row), pad) in encoded
        .0
        .chunks_mut(g.nn)
        .zip(data.chunks(g.n))
        .zip(pads.chunks(b.opts.q_pad))
    {
        pcs::encode_row_zk(&ntt, row, pad, &pows, out);
    }
    let leaves = pcs::hash_columns(&encoded.0, b.commitment.rows, g.nn);
    let tree = MerkleTree::build(
        leaves
            .iter()
            .zip(salts)
            .map(|(leaf, salt)| pcs::salt_leaf(leaf, salt))
            .collect(),
    );
    if tree.root() != b.commitment.root {
        return Err(MaterialError::RootMismatch);
    }
    Ok((encoded, tree))
}

fn parent(path: &Path) -> Result<File, MaterialError> {
    if !cfg!(unix) {
        return Err(MaterialError::UnsupportedStorage);
    }
    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let file = File::open(parent)?;
    if !file.metadata()?.is_dir() {
        return Err(MaterialError::UnsupportedStorage);
    }
    Ok(file)
}

/// First registration only. Validates/reconstructs the supplied material before
/// creating a file. Existing paths (including corrupt/empty files) are refused.
/// The key is never persisted; fresh nonce entropy is obtained from /dev/urandom
/// without a deterministic fallback. A write/sync failure may leave a file that
/// must be validated on reopening; it is never removed/reset automatically.
pub fn create_material(
    path: impl AsRef<Path>,
    key: &MaterialKey,
    policy: &MaterialPolicy,
    material: &CommittedZk,
    limits: MaterialLimits,
) -> Result<(), MaterialError> {
    let g = Geometry::new(policy, limits)?;
    let directory = parent(path.as_ref())?;
    let b = policy.slots.binding();
    if material.cm.params.log_cols != b.params.log_cols
        || material.cm.params.inv_rate != b.params.inv_rate
        || material.cm.params.num_col_checks != b.params.num_col_checks
        || material.cm.rows != b.commitment.rows
        || material.zk.q_pad != b.opts.q_pad
        || material.zk.coset != b.opts.coset
        || material.mask_rows != policy.mask_rows
        || material.prox_mask_row != policy.prox_mask_row
    {
        return Err(MaterialError::PolicyMismatch);
    }
    // Do not trust a cached tree/encoding as evidence for the persisted secrets.
    drop(reconstruct(
        policy,
        &g,
        &material.data,
        &material.pads,
        &material.salts,
    )?);
    let mut payload = Zeroizing::new(Vec::with_capacity(g.file_bytes - HEADER_BYTES));
    for value in material.data.iter().chain(&material.pads) {
        payload.extend_from_slice(&value.0.to_le_bytes());
    }
    for salt in &material.salts {
        payload.extend_from_slice(salt);
    }
    let mut header = [0u8; HEADER_BYTES];
    header[..8].copy_from_slice(MAGIC);
    header[8..40].copy_from_slice(&policy.digest);
    File::open("/dev/urandom")?.read_exact(&mut header[40..])?;
    XChaCha20Poly1305::new((&*key.0).into())
        .encrypt_in_place(XNonce::from_slice(&header[40..]), &header, &mut *payload)
        .map_err(|_| MaterialError::AuthenticationFailed)?;
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(path)?;
    file.write_all(&header)?;
    file.write_all(&payload)?;
    file.sync_all()?;
    directory.sync_all()?;
    Ok(())
}

/// Authenticate, parse and reconstruct an existing immutable file. No missing
/// file fallback and no journal access. All dimensions/roles come from the
/// independently trusted policy, never unauthenticated length fields on disk.
pub fn load_material(
    path: impl AsRef<Path>,
    key: &MaterialKey,
    policy: &MaterialPolicy,
    limits: MaterialLimits,
) -> Result<RestoredMaterial, MaterialError> {
    let g = Geometry::new(policy, limits)?;
    let directory = parent(path.as_ref())?;
    let mut file = File::open(path)?;
    let metadata = file.metadata()?;
    if !metadata.is_file() {
        return Err(MaterialError::UnsupportedStorage);
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(MaterialError::UnsupportedStorage);
        }
    }
    if metadata.len() != g.file_bytes as u64 {
        return Err(MaterialError::InvalidMaterial);
    }
    let mut header = [0u8; HEADER_BYTES];
    file.read_exact(&mut header)?;
    if &header[..8] != MAGIC {
        return Err(MaterialError::InvalidMaterial);
    }
    if header[8..40] != policy.digest {
        return Err(MaterialError::PolicyMismatch);
    }
    let mut payload = Zeroizing::new(vec![0u8; g.file_bytes - HEADER_BYTES]);
    file.read_exact(&mut payload)?;
    if file.read(&mut [0u8; 1])? != 0 {
        return Err(MaterialError::InvalidMaterial);
    }
    XChaCha20Poly1305::new((&*key.0).into())
        .decrypt_in_place(XNonce::from_slice(&header[40..]), &header, &mut *payload)
        .map_err(|_| MaterialError::AuthenticationFailed)?;
    let mut fields = payload[..(g.data + g.pads) * 8].chunks_exact(8);
    let mut read_fields = |count| -> Result<SecretFields, MaterialError> {
        let mut out = SecretFields(Vec::with_capacity(count));
        for _ in 0..count {
            let value = u64::from_le_bytes(fields.next().unwrap().try_into().unwrap());
            if value >= P {
                return Err(MaterialError::InvalidMaterial);
            }
            out.0.push(Fp(value));
        }
        Ok(out)
    };
    let mut data = read_fields(g.data)?;
    let mut pads = read_fields(g.pads)?;
    let mut salts = Zeroizing::new(
        payload[(g.data + g.pads) * 8..]
            .chunks_exact(32)
            .map(|bytes| bytes.try_into().unwrap())
            .collect::<Vec<[u8; 32]>>(),
    );
    let (mut encoded, tree) = reconstruct(policy, &g, &data.0, &pads.0, &salts)?;
    // A complete file left by an uncertain creation is durable before exposure.
    file.sync_all()?;
    directory.sync_all()?;
    let b = policy.slots.binding();
    Ok(RestoredMaterial(CommittedZk {
        cm: Committed {
            params: b.params,
            rows: b.commitment.rows,
            store: Store::Host {
                encoded: std::mem::take(&mut encoded.0),
            },
            tree,
        },
        zk: b.opts,
        data: std::mem::take(&mut data.0),
        pads: std::mem::take(&mut pads.0),
        salts: std::mem::take(&mut *salts),
        mask_rows: policy.mask_rows.clone(),
        prox_mask_row: policy.prox_mask_row,
    }))
}

#[cfg(all(test, unix))]
#[path = "stable_weight_material_tests.rs"]
mod tests;
