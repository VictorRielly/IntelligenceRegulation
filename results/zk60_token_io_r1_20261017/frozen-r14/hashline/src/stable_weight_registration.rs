//! Durable local registration for the FA4 H2 storage components.
//!
//! A private directory contains immutable encrypted material, one canonical
//! slot journal and a completion marker. Creation never reuses a directory;
//! opening never creates or repairs state. The journal remains exclusively
//! locked while material is loaded and used. Access through this handle first
//! burns a durable slot, then consumes a non-Clone attempt in one callback.
//!
//! This does not authenticate approval, generate/review a mask schedule or
//! implement a stable P3 prover. The operation callback is trusted protocol
//! code: it must enforce that schedule and must not produce multiple openings.
//! Existing low-level PCS/storage APIs remain available for their consumers.
//! One canonical registry directory and trusted local Unix storage are
//! required. Each child path derives only from the commitment root so policy
//! changes cannot reset the counter there. Copied registries, path replacement
//! and rollback still need external protection.

use crate::merkle::Digest;
use crate::pcs::CommittedZk;
use crate::stable_weight_material::{
    create_material, load_material, MaterialError, MaterialKey, MaterialLimits, MaterialPolicy,
    RestoredMaterial,
};
use crate::stable_weight_slots::{ReservedSlot, SlotError, SlotJournal};
use std::fs::{self, DirBuilder, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};

const MAGIC: &[u8; 8] = b"HLWREG01";
const JOURNAL: &str = "journal";
const MATERIAL: &str = "material";
const READY: &str = "ready";
const READY_BYTES: usize = 40;

/// Opaque key-provider refusal. Provider-specific errors may contain secrets;
/// the provider handles its own diagnostics and returns this value here.
#[derive(Debug)]
pub struct KeyUnavailable;
impl std::fmt::Display for KeyUnavailable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("registration material key unavailable")
    }
}
impl std::error::Error for KeyUnavailable {}

#[derive(Debug)]
pub enum RegistrationError {
    Incomplete,
    PolicyMismatch,
    UnsupportedStorage,
    KeyUnavailable,
    Slots(SlotError),
    Material(MaterialError),
    Io(io::Error),
}
impl std::fmt::Display for RegistrationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Incomplete => f.write_str("stable-weight registration is incomplete"),
            Self::PolicyMismatch => f.write_str("stable-weight registration policy mismatch"),
            Self::UnsupportedStorage => {
                f.write_str("registration requires private files in a private local Unix directory")
            }
            Self::KeyUnavailable => KeyUnavailable.fmt(f),
            Self::Slots(e) => e.fmt(f),
            Self::Material(e) => e.fmt(f),
            Self::Io(_) => f.write_str("stable-weight registration I/O failure"),
        }
    }
}
impl std::error::Error for RegistrationError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Slots(e) => Some(e),
            Self::Material(e) => Some(e),
            Self::Io(e) => Some(e),
            _ => None,
        }
    }
}
impl From<SlotError> for RegistrationError {
    fn from(e: SlotError) -> Self {
        Self::Slots(e)
    }
}
impl From<MaterialError> for RegistrationError {
    fn from(e: MaterialError) -> Self {
        Self::Material(e)
    }
}
impl From<io::Error> for RegistrationError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}
impl From<KeyUnavailable> for RegistrationError {
    fn from(_: KeyUnavailable) -> Self {
        Self::KeyUnavailable
    }
}

/// An exclusively locked, fully validated local registration. No Debug/Clone
/// or raw-material accessor. This type does not assert model approval.
pub struct RegistrationStore {
    policy: MaterialPolicy,
    // Drop sensitive owned material before releasing the journal's OS lock.
    material: RestoredMaterial,
    journal: SlotJournal,
}

/// A durably spent attempt. Dropping it, an operation error, panic or process
/// death never refunds it. Its borrow excludes another attempt on this handle.
///
/// ```compile_fail
/// use hashline::stable_weight_registration::RegistrationStore;
/// fn overlapping(store: &mut RegistrationStore) {
///     let first = store.reserve().unwrap();
///     let second = store.reserve().unwrap();
///     println!("{} {}", first.index(), second.index());
/// }
/// ```
///
/// ```compile_fail
/// use hashline::stable_weight_registration::RegistrationAttempt;
/// fn duplicate(attempt: RegistrationAttempt<'_>) { let copy = attempt.clone(); }
/// ```
#[must_use = "the slot is already spent; abandoning this attempt never refunds it"]
pub struct RegistrationAttempt<'a> {
    slot: ReservedSlot<'a>,
    material: &'a RestoredMaterial,
}
impl RegistrationAttempt<'_> {
    pub fn index(&self) -> u32 {
        self.slot.index()
    }
    pub fn policy_digest(&self) -> Digest {
        self.slot.policy_digest()
    }

    /// Consume the attempt in one synchronous operation. The callback receives
    /// the actual non-Clone slot token, not a caller-selected index. Borrowed
    /// material and the token cannot escape as the returned value. The callback
    /// must implement the reviewed protocol; FnOnce alone is not a limit on
    /// how many low-level PCS openings arbitrary callback code could perform.
    ///
    /// ```compile_fail
    /// use hashline::pcs::CommittedZk;
    /// use hashline::stable_weight_registration::RegistrationStore;
    /// fn leak(store: &mut RegistrationStore) -> &CommittedZk {
    ///     store.reserve().unwrap().consume(|_, material| material)
    /// }
    /// ```
    ///
    /// ```compile_fail
    /// use hashline::stable_weight_slots::ReservedSlot;
    /// use hashline::stable_weight_registration::RegistrationStore;
    /// fn leak_slot(store: &mut RegistrationStore) -> ReservedSlot<'_> {
    ///     store.reserve().unwrap().consume(|slot, _| slot)
    /// }
    /// ```
    ///
    /// ```compile_fail
    /// use hashline::stable_weight_registration::RegistrationAttempt;
    /// fn retry(attempt: RegistrationAttempt<'_>) {
    ///     attempt.consume(|_, _| ());
    ///     attempt.consume(|_, _| ());
    /// }
    /// ```
    pub fn consume<R>(self, operation: impl FnOnce(ReservedSlot<'_>, &CommittedZk) -> R) -> R {
        operation(self.slot, self.material.pcs())
    }
}

fn private_path(path: &Path, directory: bool) -> Result<(), RegistrationError> {
    if !cfg!(unix) {
        return Err(RegistrationError::UnsupportedStorage);
    }
    // Refuse symlinks and nonregular files before a potentially blocking open.
    // Trusted directories must exclude concurrent path replacement; these
    // checks do not provide an adversarial filesystem/openat capability boundary.
    let meta = fs::symlink_metadata(path)?;
    if if directory {
        !meta.is_dir()
    } else {
        !meta.is_file()
    } {
        return Err(RegistrationError::UnsupportedStorage);
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if meta.permissions().mode() & 0o077 != 0 {
            return Err(RegistrationError::UnsupportedStorage);
        }
    }
    Ok(())
}

fn ready_bytes(policy: &MaterialPolicy) -> [u8; READY_BYTES] {
    let mut bytes = [0; READY_BYTES];
    bytes[..8].copy_from_slice(MAGIC);
    bytes[8..].copy_from_slice(&policy.digest());
    bytes
}

fn open_ready(path: &Path, policy: &MaterialPolicy) -> Result<File, RegistrationError> {
    if let Err(error) = private_path(path, false) {
        return Err(match error {
            RegistrationError::Io(e) if e.kind() == io::ErrorKind::NotFound => {
                RegistrationError::Incomplete
            }
            other => other,
        });
    }
    let mut file = File::open(path)?;
    if file.metadata()?.len() != READY_BYTES as u64 {
        return Err(RegistrationError::Incomplete);
    }
    let mut bytes = [0; READY_BYTES];
    file.read_exact(&mut bytes)?;
    if &bytes[..8] != MAGIC {
        return Err(RegistrationError::Incomplete);
    }
    if bytes != ready_bytes(policy) {
        return Err(RegistrationError::PolicyMismatch);
    }
    if file.read(&mut [0; 1])? != 0 {
        return Err(RegistrationError::Incomplete);
    }
    Ok(file)
}

impl RegistrationStore {
    /// The one location for this commitment under the application's canonical
    /// private registry directory. Deliberately derives from the ROOT ONLY:
    /// changing a manifest, layer, layout or budget cannot allocate a new
    /// counter for the same commitment within that registry.
    pub fn path_for(registry: impl AsRef<Path>, policy: &MaterialPolicy) -> PathBuf {
        let root = policy.slots().binding().commitment.root;
        let hex: String = root.iter().map(|byte| format!("{byte:02x}")).collect();
        registry.as_ref().join(format!("weights-{hex}"))
    }

    /// First local registration only. The registry must be an existing private
    /// directory from application configuration. Claims a NEW child, durably
    /// creates its journal, retrieves the external key, persists and reloads
    /// material, then publishes/syncs the completion marker. Never overwrites,
    /// deletes or retries an existing directory, including failed creations.
    ///
    /// `key_source` is a lookup callback given only the independently trusted
    /// policy. It must supply the registered random 256-bit key from application
    /// custody. No key generation, persistence or process-global configuration
    /// is hidden here. The returned key is dropped before this method returns.
    pub fn create(
        registry: impl AsRef<Path>,
        policy: MaterialPolicy,
        material: &CommittedZk,
        limits: MaterialLimits,
        key_source: impl FnOnce(&MaterialPolicy) -> Result<MaterialKey, KeyUnavailable>,
    ) -> Result<Self, RegistrationError> {
        if !cfg!(unix) {
            return Err(RegistrationError::UnsupportedStorage);
        }
        let registry = registry.as_ref();
        private_path(registry, true)?;
        let parent = File::open(registry)?;
        let path = Self::path_for(registry, &policy);
        let mut builder = DirBuilder::new();
        #[cfg(unix)]
        {
            use std::os::unix::fs::DirBuilderExt;
            builder.mode(0o700);
        }
        builder.create(&path)?;
        parent.sync_all()?;
        private_path(&path, true)?;
        let directory = File::open(&path)?;
        let journal = SlotJournal::create(path.join(JOURNAL), policy.slots().clone())?;
        let key = key_source(&policy)?;
        create_material(path.join(MATERIAL), &key, &policy, material, limits)?;
        let material = load_material(path.join(MATERIAL), &key, &policy, limits)?;
        drop(key);
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let mut ready = options.open(path.join(READY))?;
        ready.write_all(&ready_bytes(&policy))?;
        ready.sync_all()?;
        directory.sync_all()?;
        Ok(Self {
            policy,
            material,
            journal,
        })
    }

    /// Existing complete registration only. Checks the completion marker,
    /// required private files, journal policy/lock and budget BEFORE invoking
    /// the key provider. Encrypted-content validation additionally needs the key.
    /// The journal lock is held throughout key lookup, reconstruction and attempts.
    /// Failure releases the lock without changing the used-slot count.
    pub fn open(
        registry: impl AsRef<Path>,
        policy: MaterialPolicy,
        limits: MaterialLimits,
        key_source: impl FnOnce(&MaterialPolicy) -> Result<MaterialKey, KeyUnavailable>,
    ) -> Result<Self, RegistrationError> {
        let registry = registry.as_ref();
        private_path(registry, true)?;
        let parent = File::open(registry)?;
        let path = Self::path_for(registry, &policy);
        private_path(&path, true)?;
        let directory = File::open(&path)?;
        let ready = open_ready(&path.join(READY), &policy)?;
        private_path(&path.join(JOURNAL), false)?;
        private_path(&path.join(MATERIAL), false)?;
        let journal = SlotJournal::open(path.join(JOURNAL), policy.slots().clone())?;
        if journal.used() == policy.slots().binding().budget {
            return Err(SlotError::Exhausted.into());
        }
        let key = key_source(&policy)?;
        let material = load_material(path.join(MATERIAL), &key, &policy, limits)?;
        drop(key);
        ready.sync_all()?;
        directory.sync_all()?;
        parent.sync_all()?;
        Ok(Self {
            policy,
            material,
            journal,
        })
    }

    pub fn policy(&self) -> &MaterialPolicy {
        &self.policy
    }
    pub fn used(&self) -> u32 {
        self.journal.used()
    }
    /// Budget minus the live handle's recorded reservations. After a storage
    /// error the journal can conservatively have spent more than this handle
    /// knows; reserve refuses until validated reopening, regardless of this count.
    pub fn remaining(&self) -> u32 {
        self.policy.slots().binding().budget - self.used()
    }

    /// Durably spend the next slot before making material available. The
    /// underlying journal poisons itself after uncertain write/sync failures.
    pub fn reserve(&mut self) -> Result<RegistrationAttempt<'_>, RegistrationError> {
        Ok(RegistrationAttempt {
            slot: self.journal.reserve()?,
            material: &self.material,
        })
    }
}

#[cfg(all(test, unix))]
#[path = "stable_weight_registration_tests.rs"]
mod tests;
