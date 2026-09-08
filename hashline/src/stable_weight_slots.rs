//! Durable opening-slot accounting for the proposed stable private-weight path.
//!
//! This is the public-state part of FA4 H2. It neither constructs a commitment,
//! stores secret weights/pads/salts, authenticates approval, nor enables a P3
//! verifier. Callers must obtain the binding from authenticated configuration
//! and use one canonical journal for a commitment for its entire lifetime.
//!
//! Supported storage: a trusted local Unix filesystem implementing exclusive
//! file locks and file/directory sync. A reservation is synced BEFORE exposure;
//! cancellation and process death never refund a returned slot. Corrupt/torn
//! tails refuse to open. File replacement, deletion, copied journals, restored
//! backups and malicious storage rollback require an external monotonic store;
//! the checksum chain is corruption detection, not authentication or anti-rollback.

use crate::field::P;
use crate::merkle::Digest;
use crate::pcs::{Commitment, PcsParams, ZkOpts};
use std::fs::{File, OpenOptions, TryLockError};
use std::io::{self, Read, Write};
use std::marker::PhantomData;
use std::path::Path;

const MAGIC: &[u8; 8] = b"HLSLOT01";
const RECORD_BYTES: u64 = 36;
/// Bounded journal parsing; this is an implementation limit, not a ZK budget.
pub const MAX_SLOTS: u32 = 65_536;

/// Public registration inputs. A schedule digest identifies a reviewed layout;
/// this module does not decide whether that review or approval actually exists.
#[derive(Clone, Debug)]
pub struct StableWeightBinding {
    pub manifest: Digest,
    pub layer: u32,
    pub layout: Digest,
    pub commitment: Commitment,
    pub params: PcsParams,
    pub opts: ZkOpts,
    pub budget: u32,
}

/// Immutable, checked storage policy. Geometry checks are necessary conditions
/// only; they are not a soundness bound or a repeated-opening privacy argument.
#[derive(Clone, Debug)]
pub struct SlotPolicy {
    binding: StableWeightBinding,
    header: Vec<u8>,
    digest: Digest,
}

#[derive(Debug)]
pub enum SlotError {
    InvalidPolicy(&'static str),
    PolicyMismatch,
    CorruptJournal,
    Busy,
    Exhausted,
    Poisoned,
    UnsupportedStorage,
    Io(io::Error),
}
impl std::fmt::Display for SlotError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidPolicy(s) => write!(f, "invalid stable-weight slot policy: {s}"),
            Self::PolicyMismatch => {
                write!(f, "stable-weight journal belongs to a different policy")
            }
            Self::CorruptJournal => write!(f, "invalid or incomplete stable-weight slot journal"),
            Self::Busy => write!(f, "stable-weight slot journal is already in use"),
            Self::Exhausted => write!(f, "stable-weight opening budget exhausted"),
            Self::Poisoned => write!(f, "stable-weight slot journal requires validated reopening"),
            Self::UnsupportedStorage => write!(
                f,
                "stable-weight slot storage requires a local Unix filesystem"
            ),
            Self::Io(_) => write!(f, "stable-weight slot storage I/O failure"),
        }
    }
}
impl std::error::Error for SlotError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Io(e) => Some(e),
            _ => None,
        }
    }
}
impl From<io::Error> for SlotError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

impl SlotPolicy {
    pub fn new(binding: StableWeightBinding) -> Result<Self, SlotError> {
        let b = &binding;
        let invalid = SlotError::InvalidPolicy;
        if b.manifest == [0; 32] || b.layout == [0; 32] || b.commitment.root == [0; 32] {
            return Err(invalid("missing public identity"));
        }
        if b.budget == 0 || b.budget > MAX_SLOTS || b.params.num_col_checks == 0 {
            return Err(invalid("opening budget or query count"));
        }
        if !(1..=31).contains(&b.params.log_cols)
            || b.commitment.log_cols != b.params.log_cols
            || b.commitment.rows == 0
            || b.params.inv_rate < 2
            || !b.params.inv_rate.is_power_of_two()
        {
            return Err(invalid("commitment geometry"));
        }
        let n = 1u64 << b.params.log_cols;
        let nn = n
            .checked_mul(b.params.inv_rate as u64)
            .filter(|&nn| nn <= 1u64 << 32)
            .ok_or(invalid("NTT domain"))?;
        let q_pad = (b.budget as u64)
            .checked_mul(b.params.num_col_checks as u64)
            .ok_or(invalid("padding overflow"))?;
        if b.opts.q_pad as u64 != q_pad || n.checked_add(q_pad).is_none_or(|message| message > nn) {
            return Err(invalid(
                "q_pad must equal budget times queries and fit the code",
            ));
        }
        if b.opts.coset.0 == 0 || b.opts.coset.0 >= P || b.opts.coset.pow(nn).0 == 1 {
            return Err(invalid("canonical disjoint coset required"));
        }
        let mut header = MAGIC.to_vec();
        header.extend_from_slice(&b.manifest);
        header.extend_from_slice(&b.layout);
        header.extend_from_slice(&b.commitment.root);
        for value in [
            b.layer as u64,
            b.commitment.rows as u64,
            b.params.log_cols as u64,
            b.params.inv_rate as u64,
            b.params.num_col_checks as u64,
            b.budget as u64,
            b.opts.q_pad as u64,
            b.opts.coset.0,
        ] {
            header.extend_from_slice(&value.to_le_bytes());
        }
        let digest = *blake3::hash(&header).as_bytes();
        header.extend_from_slice(&digest);
        Ok(Self {
            binding,
            header,
            digest,
        })
    }
    pub fn binding(&self) -> &StableWeightBinding {
        &self.binding
    }
    pub fn digest(&self) -> Digest {
        self.digest
    }
}

/// Holds an exclusive OS lock for its lifetime. Deliberately not Clone.
pub struct SlotJournal {
    file: File,
    policy: SlotPolicy,
    used: u32,
    tail: Digest,
    poisoned: bool,
}

/// A spent slot, never a refundable reservation. Deliberately not Clone/Copy;
/// its borrow prevents another reservation through this handle until dropped.
/// The future prover must consume this token, not take a caller-supplied index.
///
/// ```compile_fail
/// use hashline::stable_weight_slots::SlotJournal;
/// fn overlapping(journal: &mut SlotJournal) {
///     let first = journal.reserve().unwrap();
///     let second = journal.reserve().unwrap();
///     println!("{} {}", first.index(), second.index());
/// }
/// ```
///
/// ```compile_fail
/// use hashline::stable_weight_slots::SlotJournal;
/// fn duplicate(journal: &mut SlotJournal) {
///     let slot = journal.reserve().unwrap();
///     let copy = slot.clone();
/// }
/// ```
#[must_use = "the slot has already been spent; dropping it does not refund it"]
pub struct ReservedSlot<'a> {
    index: u32,
    policy: Digest,
    _exclusive: PhantomData<&'a mut SlotJournal>,
}
impl ReservedSlot<'_> {
    pub fn index(&self) -> u32 {
        self.index
    }
    pub fn policy_digest(&self) -> Digest {
        self.policy
    }
}

fn lock(file: &File) -> Result<(), SlotError> {
    match file.try_lock() {
        Ok(()) => Ok(()),
        Err(TryLockError::WouldBlock) => Err(SlotError::Busy),
        Err(TryLockError::Error(e)) => Err(SlotError::Io(e)),
    }
}

fn storage_parent(path: &Path) -> Result<File, SlotError> {
    if !cfg!(unix) {
        return Err(SlotError::UnsupportedStorage);
    }
    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let file = File::open(parent)?;
    if !file.metadata()?.is_dir() {
        return Err(SlotError::UnsupportedStorage);
    }
    Ok(file)
}

fn record(policy: Digest, previous: Digest, slot: u32) -> [u8; 36] {
    let mut hash = blake3::Hasher::new();
    hash.update(b"hashline-stable-slot-record-v1/");
    hash.update(&policy);
    hash.update(&previous);
    hash.update(&slot.to_le_bytes());
    let mut out = [0; 36];
    out[..4].copy_from_slice(&slot.to_le_bytes());
    out[4..].copy_from_slice(hash.finalize().as_bytes());
    out
}

impl SlotJournal {
    /// Explicit first registration only. Existing files are NEVER overwritten,
    /// including empty or corrupt files left by a failed creation.
    pub fn create(path: impl AsRef<Path>, policy: SlotPolicy) -> Result<Self, SlotError> {
        let path = path.as_ref();
        let parent = storage_parent(path)?;
        let mut options = OpenOptions::new();
        options.read(true).append(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let mut file = options.open(path)?;
        lock(&file)?;
        file.write_all(&policy.header)?;
        file.sync_all()?;
        parent.sync_all()?;
        Ok(Self {
            file,
            tail: policy.digest,
            policy,
            used: 0,
            poisoned: false,
        })
    }

    /// Open existing state against independently supplied policy. Missing state
    /// is an error; reopening never creates, truncates or repairs a journal.
    pub fn open(path: impl AsRef<Path>, policy: SlotPolicy) -> Result<Self, SlotError> {
        let path = path.as_ref();
        let parent = storage_parent(path)?;
        let mut file = OpenOptions::new().read(true).append(true).open(path)?;
        lock(&file)?;
        let meta = file.metadata()?;
        let remaining = meta
            .len()
            .checked_sub(policy.header.len() as u64)
            .ok_or(SlotError::CorruptJournal)?;
        if !meta.is_file()
            || remaining % RECORD_BYTES != 0
            || remaining / RECORD_BYTES > policy.binding.budget as u64
        {
            return Err(SlotError::CorruptJournal);
        }
        let mut header = vec![0; policy.header.len()];
        file.read_exact(&mut header)?;
        if header != policy.header {
            return Err(SlotError::PolicyMismatch);
        }
        let used = (remaining / RECORD_BYTES) as u32;
        let mut tail = policy.digest;
        let mut received = [0; 36];
        for slot in 0..used {
            file.read_exact(&mut received)?;
            let expected = record(policy.digest, tail, slot);
            if received != expected {
                return Err(SlotError::CorruptJournal);
            }
            tail.copy_from_slice(&received[4..]);
        }
        // Persist a complete record left by death before its sync/return. It is
        // conservatively burned; only incomplete records refuse the whole store.
        file.sync_all()?;
        parent.sync_all()?;
        Ok(Self {
            file,
            policy,
            used,
            tail,
            poisoned: false,
        })
    }

    pub fn used(&self) -> u32 {
        self.used
    }
    pub fn policy(&self) -> &SlotPolicy {
        &self.policy
    }

    /// Append and sync before returning. After any uncertain storage failure,
    /// this handle refuses further reservations; reopen and validate on disk.
    pub fn reserve(&mut self) -> Result<ReservedSlot<'_>, SlotError> {
        self.reserve_with_sync(File::sync_all)
    }

    // The injected sync operation lets tests model failed sync and torn-tail
    // crash boundaries without process-global fault switches.
    fn reserve_with_sync(
        &mut self,
        sync: impl FnOnce(&File) -> io::Result<()>,
    ) -> Result<ReservedSlot<'_>, SlotError> {
        if self.poisoned {
            return Err(SlotError::Poisoned);
        }
        if self.used == self.policy.binding.budget {
            return Err(SlotError::Exhausted);
        }
        self.poisoned = true;
        let expected_len = self.policy.header.len() as u64 + self.used as u64 * RECORD_BYTES;
        if self.file.metadata()?.len() != expected_len {
            return Err(SlotError::CorruptJournal);
        }
        let entry = record(self.policy.digest, self.tail, self.used);
        self.file.write_all(&entry)?;
        sync(&self.file)?;
        let index = self.used;
        self.used += 1;
        self.tail.copy_from_slice(&entry[4..]);
        self.poisoned = false;
        Ok(ReservedSlot {
            index,
            policy: self.policy.digest,
            _exclusive: PhantomData,
        })
    }
}

#[cfg(test)]
#[path = "stable_weight_slots_tests.rs"]
mod tests;
