use super::*;
use crate::field::Fp;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Scratch(PathBuf);
impl Scratch {
    fn new() -> Self {
        let stamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "zk60-slots-{}-{stamp}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn file(&self, name: &str) -> PathBuf {
        self.0.join(name)
    }
}
impl Drop for Scratch {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn binding() -> StableWeightBinding {
    // Public metadata fixture, not a real approved private commitment.
    StableWeightBinding {
        manifest: [1; 32],
        layer: 2,
        layout: [3; 32],
        commitment: Commitment {
            root: [4; 32],
            rows: 12,
            log_cols: 4,
        },
        params: PcsParams {
            log_cols: 4,
            inv_rate: 4,
            num_col_checks: 4,
        },
        opts: ZkOpts {
            q_pad: 12,
            coset: Fp::new(7),
        },
        budget: 3,
    }
}
fn policy() -> SlotPolicy {
    SlotPolicy::new(binding()).unwrap()
}

#[test]
fn binding_geometry_refuses_invalid_budgets_domains_and_aliases() {
    for case in 0..16 {
        let mut b = binding();
        match case {
            0 => b.budget = 0,
            1 => b.budget = MAX_SLOTS + 1,
            2 => b.params.num_col_checks = 0,
            3 => b.opts.q_pad -= 1,
            4 => {
                b.budget = 13;
                b.opts.q_pad = 52;
            } // 16 + 52 > 64
            5 => b.params.inv_rate = 3,
            6 => b.params.inv_rate = usize::MAX,
            7 => b.params.log_cols = 64,
            8 => b.commitment.log_cols = 5,
            9 => b.commitment.rows = 0,
            10 => b.opts.coset = Fp::ZERO,
            11 => b.opts.coset = Fp::ONE,
            12 => b.opts.coset = Fp(P), // don't silently canonicalize hostile words
            13 => b.opts.coset = Fp::two_adic_root(6),
            14 => b.manifest = [0; 32],
            _ => b.layout = [0; 32],
        }
        assert!(
            matches!(SlotPolicy::new(b), Err(SlotError::InvalidPolicy(_))),
            "case {case}"
        );
    }
    let mut boundary = binding();
    boundary.budget = 12;
    boundary.opts.q_pad = 48;
    // Equality fits the FA4 storage geometry; it is not positive code distance.
    SlotPolicy::new(boundary).unwrap();
    let mut bounded = binding();
    bounded.budget = MAX_SLOTS;
    bounded.opts.q_pad = MAX_SLOTS as usize * 4;
    bounded.params.inv_rate = 1 << 16;
    SlotPolicy::new(bounded).unwrap();
}

#[test]
fn spent_slots_survive_reopening_drop_unwind_and_exhaustion() {
    let scratch = Scratch::new();
    let path = scratch.file("journal");
    let mut journal = SlotJournal::create(&path, policy()).unwrap();
    let slot = journal.reserve().unwrap();
    assert_eq!(slot.index(), 0);
    assert_eq!(slot.policy_digest(), policy().digest());
    drop(slot); // abandoning the attempt consumes the slot
    drop(journal);
    let mut journal = SlotJournal::open(&path, policy()).unwrap();
    assert_eq!(journal.used(), 1);
    assert!(std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let slot = journal.reserve().unwrap();
        assert_eq!(slot.index(), 1);
        panic!("abandoned prover after durable reservation");
    }))
    .is_err());
    drop(journal);
    let mut journal = SlotJournal::open(&path, policy()).unwrap();
    assert_eq!(journal.reserve().unwrap().index(), 2);
    assert!(matches!(journal.reserve(), Err(SlotError::Exhausted)));
    drop(journal);
    let mut journal = SlotJournal::open(&path, policy()).unwrap();
    assert_eq!(journal.used(), 3);
    assert!(matches!(journal.reserve(), Err(SlotError::Exhausted)));
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        assert_eq!(
            std::fs::metadata(&path).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}

#[test]
fn every_public_binding_field_is_checked_on_reopening() {
    let scratch = Scratch::new();
    let path = scratch.file("journal");
    drop(SlotJournal::create(&path, policy()).unwrap());
    for case in 0..10 {
        let mut b = binding();
        match case {
            0 => b.manifest[0] ^= 1,
            1 => b.layout[0] ^= 1,
            2 => b.commitment.root[0] ^= 1,
            3 => b.layer += 1,
            4 => b.commitment.rows += 1,
            5 => {
                b.params.log_cols += 1;
                b.commitment.log_cols += 1;
            }
            6 => b.params.inv_rate *= 2,
            7 => {
                b.params.num_col_checks += 1;
                b.opts.q_pad += b.budget as usize;
            }
            8 => {
                b.budget += 1;
                b.opts.q_pad += b.params.num_col_checks;
            }
            _ => b.opts.coset = Fp::new(11),
        }
        let changed = SlotPolicy::new(b).unwrap();
        assert_ne!(changed.digest(), policy().digest());
        assert!(
            matches!(
                SlotJournal::open(&path, changed),
                Err(SlotError::PolicyMismatch)
            ),
            "case {case}"
        );
    }
    SlotJournal::open(&path, policy()).unwrap();
}

#[test]
fn existing_missing_and_busy_stores_never_reset_the_counter() {
    let scratch = Scratch::new();
    let path = scratch.file("journal");
    assert!(matches!(
        SlotJournal::open(&path, policy()),
        Err(SlotError::Io(_))
    ));
    assert!(!path.exists());
    let mut journal = SlotJournal::create(&path, policy()).unwrap();
    assert_eq!(journal.reserve().unwrap().index(), 0);
    let original = std::fs::read(&path).unwrap();
    assert!(matches!(
        SlotJournal::open(&path, policy()),
        Err(SlotError::Busy)
    ));
    assert!(matches!(
        SlotJournal::create(&path, policy()),
        Err(SlotError::Io(_))
    ));
    assert_eq!(std::fs::read(&path).unwrap(), original);
    drop(journal);
    assert_eq!(SlotJournal::open(&path, policy()).unwrap().used(), 1);
    let empty = scratch.file("failed-create");
    File::create(&empty).unwrap();
    assert!(SlotJournal::create(&empty, policy()).is_err());
    assert!(matches!(
        SlotJournal::open(&empty, policy()),
        Err(SlotError::CorruptJournal)
    ));
    assert_eq!(std::fs::metadata(empty).unwrap().len(), 0);
}

#[test]
fn corrupt_torn_reordered_and_over_budget_records_fail_closed() {
    let scratch = Scratch::new();
    let path = scratch.file("journal");
    let mut journal = SlotJournal::create(&path, policy()).unwrap();
    drop(journal.reserve().unwrap());
    drop(journal.reserve().unwrap());
    drop(journal);
    let original = std::fs::read(&path).unwrap();
    let head = policy().header.len();
    for case in 0..7 {
        let mut bytes = original.clone();
        match case {
            0 => bytes[0] ^= 1,
            1 => bytes[head + 8] ^= 1,
            2 => bytes[head + 36..head + 72].copy_from_slice(&original[head..head + 36]),
            3 => {
                bytes.pop();
            }
            4 => bytes.truncate(head - 1),
            5 => bytes.extend_from_slice(&[0; 72]),
            _ => bytes.extend_from_slice(&[0]),
        }
        let bad = scratch.file(&format!("bad-{case}"));
        std::fs::write(&bad, &bytes).unwrap();
        assert!(SlotJournal::open(&bad, policy()).is_err(), "case {case}");
        assert_eq!(std::fs::read(&bad).unwrap(), bytes); // no automatic repair
    }
    assert_eq!(SlotJournal::open(&path, policy()).unwrap().used(), 2);
}

#[test]
fn failed_sync_poisoning_never_reissues_a_written_slot() {
    for torn in [false, true] {
        let scratch = Scratch::new();
        let path = scratch.file("journal");
        let mut journal = SlotJournal::create(&path, policy()).unwrap();
        let result = journal.reserve_with_sync(|file| {
            if torn {
                file.set_len(file.metadata()?.len() - 7)?;
            }
            Err(io::Error::other("injected write/sync failure"))
        });
        assert!(matches!(result, Err(SlotError::Io(_))));
        assert!(matches!(journal.reserve(), Err(SlotError::Poisoned)));
        drop(journal);
        if torn {
            assert!(matches!(
                SlotJournal::open(&path, policy()),
                Err(SlotError::CorruptJournal)
            ));
        } else {
            let mut journal = SlotJournal::open(&path, policy()).unwrap();
            assert_eq!(journal.used(), 1);
            assert_eq!(journal.reserve().unwrap().index(), 1);
        }
    }
}

#[test]
fn unexpected_file_length_poisoning_precedes_slot_exposure() {
    let scratch = Scratch::new();
    let path = scratch.file("journal");
    let mut journal = SlotJournal::create(&path, policy()).unwrap();
    OpenOptions::new()
        .append(true)
        .open(&path)
        .unwrap()
        .write_all(&[0])
        .unwrap();
    assert!(matches!(journal.reserve(), Err(SlotError::CorruptJournal)));
    assert!(matches!(journal.reserve(), Err(SlotError::Poisoned)));
    drop(journal);
    assert!(SlotJournal::open(&path, policy()).is_err());
}
