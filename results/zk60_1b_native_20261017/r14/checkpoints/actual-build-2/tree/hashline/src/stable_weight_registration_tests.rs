use super::*;
use crate::field::{Fp, Fp2};
use crate::mle::eval_mle_base;
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use crate::stable_weight_slots::{SlotPolicy, StableWeightBinding};
use crate::transcript::Transcript;
use crate::zk::ZkRng;
use std::cell::Cell;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Scratch(PathBuf);
impl Scratch {
    fn new() -> Self {
        let stamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "zk60-registration-{}-{stamp}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o700)).unwrap();
        Self(path)
    }
    fn store(&self) -> PathBuf {
        RegistrationStore::path_for(&self.0, &fixture().1)
    }
}
impl Drop for Scratch {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}
fn fixture() -> (CommittedZk, MaterialPolicy) {
    let params = PcsParams {
        log_cols: 4,
        inv_rate: 4,
        num_col_checks: 2,
    };
    let opts = ZkOpts {
        q_pad: 8,
        coset: Fp::new(7),
    };
    let mut rng = ZkRng::new(141, b"registration-test-only");
    let data = rng.fp_vec(3 * params.cols());
    let mut material = pcs::commit_zk_owned(&params, data, &NttTables::new(6), &opts, &mut rng);
    material.mask_rows = vec![1];
    material.prox_mask_row = Some(2);
    let slots = SlotPolicy::new(StableWeightBinding {
        manifest: [21; 32],
        layer: 4,
        layout: [23; 32],
        commitment: material.commitment(),
        params,
        opts,
        budget: 4,
    })
    .unwrap();
    (
        material,
        MaterialPolicy::new(slots, vec![1], Some(2)).unwrap(),
    )
}
fn key(_: &MaterialPolicy) -> Result<MaterialKey, KeyUnavailable> {
    // Public fixture key only; production keys come from application custody.
    Ok(MaterialKey::from_bytes([142; 32]))
}
fn create(path: &Path, material: &CommittedZk, policy: &MaterialPolicy) -> RegistrationStore {
    RegistrationStore::create(
        path.parent().unwrap(),
        policy.clone(),
        material,
        MaterialLimits::default(),
        key,
    )
    .unwrap()
}
fn open(path: &Path, policy: &MaterialPolicy) -> Result<RegistrationStore, RegistrationError> {
    RegistrationStore::open(
        path.parent().unwrap(),
        policy.clone(),
        MaterialLimits::default(),
        key,
    )
}
fn public_key_must_not_be_requested(_: &MaterialPolicy) -> Result<MaterialKey, KeyUnavailable> {
    panic!("key provider ran before invalid public state was refused")
}

#[test]
fn complete_registration_spends_before_actual_pcs_access_and_holds_lock() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (original, policy) = fixture();
    let calls = Cell::new(0);
    let mut store = RegistrationStore::create(
        path.parent().unwrap(),
        policy.clone(),
        &original,
        MaterialLimits::default(),
        |requested| {
            assert_eq!(requested.digest(), policy.digest());
            calls.set(calls.get() + 1);
            assert!(matches!(
                SlotJournal::open(path.join(JOURNAL), policy.slots().clone()),
                Err(SlotError::Busy)
            ));
            key(requested)
        },
    )
    .unwrap();
    assert_eq!(calls.get(), 1);
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o700
    );
    for file in [JOURNAL, MATERIAL, READY] {
        assert_eq!(
            fs::metadata(path.join(file)).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
    assert_eq!(fs::read(path.join(READY)).unwrap(), ready_bytes(&policy));
    assert_eq!(store.used(), 0);
    assert_eq!(store.remaining(), 4);
    let attempt = store.reserve().unwrap();
    assert_eq!(attempt.index(), 0);
    assert_eq!(attempt.policy_digest(), policy.slots().digest());
    let opening_bytes = attempt.consume(|slot, material| {
        // Observe the durable record BEFORE the callback performs PCS work.
        assert_eq!(fs::metadata(path.join(JOURNAL)).unwrap().len(), 200 + 36);
        assert_eq!(slot.index(), 0);
        assert_eq!(slot.policy_digest(), policy.slots().digest());
        assert_eq!(material.data, original.data);
        assert_eq!(material.pads, original.pads);
        assert_eq!(material.salts, original.salts);
        assert!(matches!(
            RegistrationStore::open(
                path.parent().unwrap(),
                policy.clone(),
                MaterialLimits::default(),
                public_key_must_not_be_requested
            ),
            Err(RegistrationError::Slots(SlotError::Busy))
        ));
        // A synthetic ordinary PCS parity check, not the unimplemented stable
        // P3 protocol or an assertion of repeated-opening privacy.
        let point = vec![Fp2::from_base(Fp::new(9)); 4];
        let e = Fp2::from_base(Fp::new(17));
        let claims = [ZClaim {
            parts: vec![
                ZPart {
                    slice: Slice {
                        offset: 0,
                        log_size: 4,
                    },
                    coef: Fp2::ONE.sub(e),
                    point: point.clone(),
                },
                ZPart {
                    slice: Slice {
                        offset: 16,
                        log_size: 4,
                    },
                    coef: e,
                    point: point.clone(),
                },
            ],
            value: Fp2::ONE
                .sub(e)
                .mul(eval_mle_base(&material.data[..16], &point))
                .add(e.mul(eval_mle_base(&material.data[16..32], &point))),
        }];
        let mut transcript = Transcript::new(b"registration-pcs-test");
        let opening = pcs::open_zk(material, &claims, &mut transcript);
        let mut verifier = Transcript::new(b"registration-pcs-test");
        pcs::verify_zk(
            &material.cm.params,
            &material.zk,
            &material.commitment(),
            &claims,
            &opening,
            &NttTables::new(6),
            &mut verifier,
        )
        .unwrap();
        let mut bytes = Vec::new();
        opening.write_bytes(&mut bytes);
        bytes
    });
    assert!(!opening_bytes.is_empty());
    assert_eq!(store.used(), 1);
    assert_eq!(store.remaining(), 3);
}

#[test]
fn abandonment_operation_failure_unwind_and_exhaustion_never_refund() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    let mut store = create(&path, &material, &policy);
    drop(store.reserve().unwrap());
    let outcome: Result<(), &str> = store
        .reserve()
        .unwrap()
        .consume(|_, _| Err("operation failed"));
    assert_eq!(outcome, Err("operation failed"));
    assert!(std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        store
            .reserve()
            .unwrap()
            .consume(|_, _| panic!("operation aborted"));
    }))
    .is_err());
    assert_eq!(store.used(), 3);
    drop(store);
    let mut reopened = open(&path, &policy).unwrap();
    assert_eq!(reopened.used(), 3);
    reopened
        .reserve()
        .unwrap()
        .consume(|slot, _| assert_eq!(slot.index(), 3));
    assert!(matches!(
        reopened.reserve(),
        Err(RegistrationError::Slots(SlotError::Exhausted))
    ));
    drop(reopened);
    let before = fs::read(path.join(JOURNAL)).unwrap();
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            public_key_must_not_be_requested
        ),
        Err(RegistrationError::Slots(SlotError::Exhausted))
    ));
    assert_eq!(before, fs::read(path.join(JOURNAL)).unwrap());
}

#[test]
fn incomplete_creation_states_cannot_open_or_restart_registration() {
    let (material, policy) = fixture();
    for phase in 0..5 {
        let scratch = Scratch::new();
        let path = scratch.store();
        if phase > 0 {
            let mut builder = DirBuilder::new();
            use std::os::unix::fs::DirBuilderExt;
            builder.mode(0o700).create(&path).unwrap();
        }
        if phase > 1 {
            drop(SlotJournal::create(path.join(JOURNAL), policy.slots().clone()).unwrap());
        }
        if phase > 2 {
            create_material(
                path.join(MATERIAL),
                &key(&policy).unwrap(),
                &policy,
                &material,
                MaterialLimits::default(),
            )
            .unwrap();
        }
        if phase > 3 {
            fs::write(path.join(READY), &ready_bytes(&policy)[..17]).unwrap();
            fs::set_permissions(path.join(READY), fs::Permissions::from_mode(0o600)).unwrap();
        }
        assert!(
            RegistrationStore::open(
                path.parent().unwrap(),
                policy.clone(),
                MaterialLimits::default(),
                public_key_must_not_be_requested
            )
            .is_err(),
            "phase {phase}"
        );
        if phase > 0 {
            let before: Vec<_> = [JOURNAL, MATERIAL, READY]
                .into_iter()
                .map(|name| fs::read(path.join(name)).ok())
                .collect();
            assert!(RegistrationStore::create(
                path.parent().unwrap(),
                policy.clone(),
                &material,
                MaterialLimits::default(),
                public_key_must_not_be_requested
            )
            .is_err());
            let after: Vec<_> = [JOURNAL, MATERIAL, READY]
                .into_iter()
                .map(|name| fs::read(path.join(name)).ok())
                .collect();
            assert_eq!(before, after);
        } else {
            assert!(!path.exists());
        }
    }
}

#[test]
fn marker_corruption_and_policy_substitution_refuse_before_key_lookup() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    drop(create(&path, &material, &policy));
    let marker = fs::read(path.join(READY)).unwrap();
    let journal = fs::read(path.join(JOURNAL)).unwrap();
    for i in 0..marker.len() {
        let mut changed = marker.clone();
        changed[i] ^= 1;
        fs::write(path.join(READY), changed).unwrap();
        assert!(
            RegistrationStore::open(
                path.parent().unwrap(),
                policy.clone(),
                MaterialLimits::default(),
                public_key_must_not_be_requested
            )
            .is_err(),
            "marker byte {i}"
        );
    }
    let mut trailing = marker.clone();
    trailing.push(0);
    fs::write(path.join(READY), trailing).unwrap();
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            public_key_must_not_be_requested
        ),
        Err(RegistrationError::Incomplete)
    ));
    fs::write(path.join(READY), marker).unwrap();
    let changed = MaterialPolicy::new(policy.slots().clone(), vec![0], Some(2)).unwrap();
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            changed,
            MaterialLimits::default(),
            public_key_must_not_be_requested
        ),
        Err(RegistrationError::PolicyMismatch)
    ));
    assert_eq!(journal, fs::read(path.join(JOURNAL)).unwrap());
    open(&path, &policy).unwrap();
}

#[test]
fn changed_manifest_layer_or_budget_cannot_allocate_a_second_counter() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    let mut store = create(&path, &material, &policy);
    drop(store.reserve().unwrap());
    drop(store);
    let journal = fs::read(path.join(JOURNAL)).unwrap();
    for case in 0..4 {
        let mut binding = policy.slots().binding().clone();
        match case {
            0 => binding.manifest[0] ^= 1,
            1 => binding.layer += 1,
            2 => binding.layout[0] ^= 1,
            _ => {
                binding.budget = 8;
                binding.params.num_col_checks = 1;
            }
        }
        let changed =
            MaterialPolicy::new(SlotPolicy::new(binding).unwrap(), vec![1], Some(2)).unwrap();
        assert_eq!(RegistrationStore::path_for(&scratch.0, &changed), path);
        assert!(RegistrationStore::create(
            &scratch.0,
            changed.clone(),
            &material,
            MaterialLimits::default(),
            public_key_must_not_be_requested
        )
        .is_err());
        assert!(matches!(
            RegistrationStore::open(
                &scratch.0,
                changed,
                MaterialLimits::default(),
                public_key_must_not_be_requested
            ),
            Err(RegistrationError::PolicyMismatch)
        ));
        assert_eq!(fs::read(path.join(JOURNAL)).unwrap(), journal);
    }
    assert_eq!(open(&path, &policy).unwrap().used(), 1);
}

#[test]
fn unavailable_wrong_keys_and_bad_material_release_lock_without_spending() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    let mut store = create(&path, &material, &policy);
    drop(store.reserve().unwrap());
    drop(store);
    let journal = fs::read(path.join(JOURNAL)).unwrap();
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            |_| Err(KeyUnavailable)
        ),
        Err(RegistrationError::KeyUnavailable)
    ));
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            |_| Ok(MaterialKey::from_bytes([143; 32]))
        ),
        Err(RegistrationError::Material(
            MaterialError::AuthenticationFailed
        ))
    ));
    let bytes = fs::read(path.join(MATERIAL)).unwrap();
    let mut damaged = bytes.clone();
    damaged[70] ^= 1;
    fs::write(path.join(MATERIAL), damaged).unwrap();
    assert!(matches!(
        open(&path, &policy),
        Err(RegistrationError::Material(
            MaterialError::AuthenticationFailed
        ))
    ));
    fs::write(path.join(MATERIAL), bytes).unwrap();
    let calls = Cell::new(0);
    let reopened = RegistrationStore::open(
        path.parent().unwrap(),
        policy.clone(),
        MaterialLimits::default(),
        |requested| {
            calls.set(calls.get() + 1);
            assert_eq!(requested.digest(), policy.digest());
            assert!(matches!(
                SlotJournal::open(path.join(JOURNAL), policy.slots().clone()),
                Err(SlotError::Busy)
            ));
            key(requested)
        },
    )
    .unwrap();
    assert_eq!(calls.get(), 1);
    assert_eq!(reopened.used(), 1);
    assert_eq!(fs::read(path.join(JOURNAL)).unwrap(), journal);
}

#[test]
fn failed_creation_retains_claimed_directory_without_publishing_ready() {
    let (material, policy) = fixture();
    for phase in 0..3 {
        let scratch = Scratch::new();
        let path = scratch.store();
        let result = RegistrationStore::create(
            path.parent().unwrap(),
            policy.clone(),
            &material,
            if phase == 1 {
                MaterialLimits {
                    max_file_bytes: 0,
                    max_encoded_elements: 0,
                }
            } else {
                MaterialLimits::default()
            },
            |requested| {
                if phase == 0 {
                    return Err(KeyUnavailable);
                }
                if phase == 2 {
                    // Force the final exclusive marker publication to fail.
                    fs::write(path.join(READY), []).unwrap();
                    fs::set_permissions(path.join(READY), fs::Permissions::from_mode(0o600))
                        .unwrap();
                }
                key(requested)
            },
        );
        assert!(result.is_err());
        assert_eq!(
            SlotJournal::open(path.join(JOURNAL), policy.slots().clone())
                .unwrap()
                .used(),
            0
        );
        assert!(RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            public_key_must_not_be_requested
        )
        .is_err());
        assert!(RegistrationStore::create(
            path.parent().unwrap(),
            policy.clone(),
            &material,
            MaterialLimits::default(),
            public_key_must_not_be_requested
        )
        .is_err());
    }
}

#[test]
fn required_files_permissions_symlinks_and_corrupt_journal_refuse() {
    let (material, policy) = fixture();
    for case in 0..8 {
        let scratch = Scratch::new();
        let path = scratch.store();
        drop(create(&path, &material, &policy));
        match case {
            0 => fs::remove_file(path.join(JOURNAL)).unwrap(),
            1 => fs::remove_file(path.join(MATERIAL)).unwrap(),
            2 => fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap(),
            3 => {
                fs::set_permissions(path.join(JOURNAL), fs::Permissions::from_mode(0o644)).unwrap()
            }
            4 => {
                fs::set_permissions(path.join(MATERIAL), fs::Permissions::from_mode(0o644)).unwrap()
            }
            5 => fs::set_permissions(path.join(READY), fs::Permissions::from_mode(0o644)).unwrap(),
            6 => {
                fs::rename(path.join(JOURNAL), path.join("other")).unwrap();
                std::os::unix::fs::symlink("other", path.join(JOURNAL)).unwrap();
            }
            _ => {
                let mut bytes = fs::read(path.join(JOURNAL)).unwrap();
                bytes[10] ^= 1;
                fs::write(path.join(JOURNAL), bytes).unwrap();
            }
        }
        assert!(
            RegistrationStore::open(
                path.parent().unwrap(),
                policy.clone(),
                MaterialLimits::default(),
                public_key_must_not_be_requested
            )
            .is_err(),
            "case {case}"
        );
        // No open attempt silently repairs missing files or rebinds the journal.
        if case == 0 {
            assert!(!path.join(JOURNAL).exists());
        }
        if case == 1 {
            assert!(!path.join(MATERIAL).exists());
        }
    }
}

struct Client(Child);
impl Drop for Client {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
fn child(path: &Path, mode: &str) -> Client {
    Client(
        Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "stable_weight_registration::tests::registration_process_child",
                "--nocapture",
                "--test-threads=1",
            ])
            .env("HL_TEST_REGISTRATION_CHILD", path)
            .env("HL_TEST_REGISTRATION_MODE", mode)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap(),
    )
}
fn wait_signal(child: &mut Client, path: &Path) {
    let start = Instant::now();
    while !path.exists() {
        assert!(
            child.0.try_wait().unwrap().is_none(),
            "child died before checkpoint"
        );
        assert!(
            start.elapsed() < Duration::from_secs(20),
            "child checkpoint timeout"
        );
        std::thread::sleep(Duration::from_millis(10));
    }
}
fn hold() {
    let mut buffer = String::new();
    std::io::stdin().read_to_string(&mut buffer).unwrap();
    panic!("child expected to be killed while holding registration");
}

#[test]
fn registration_process_child() {
    let Some(path) = std::env::var_os("HL_TEST_REGISTRATION_CHILD") else {
        return;
    };
    let path = PathBuf::from(path);
    let (material, policy) = fixture();
    let signal = path.with_extension("signal");
    if std::env::var("HL_TEST_REGISTRATION_MODE").unwrap() == "create" {
        let _ = RegistrationStore::create(
            path.parent().unwrap(),
            policy,
            &material,
            MaterialLimits::default(),
            |_| {
                fs::write(&signal, b"journal-durable").unwrap();
                hold();
                Err(KeyUnavailable)
            },
        );
    } else {
        let mut store = open(&path, &policy).unwrap();
        store.reserve().unwrap().consume(|slot, material| {
            assert_eq!(slot.index(), 0);
            assert_eq!(
                material.commitment().root,
                policy.slots().binding().commitment.root
            );
            fs::write(&signal, b"slot-spent").unwrap();
            hold();
        });
    }
}

#[test]
fn process_death_during_creation_cannot_publish_or_reset_partial_state() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    let mut child = child(&path, "create");
    wait_signal(&mut child, &path.with_extension("signal"));
    assert!(!path.join(READY).exists());
    child.0.kill().unwrap();
    assert!(!child.0.wait().unwrap().success());
    assert!(RegistrationStore::open(
        path.parent().unwrap(),
        policy.clone(),
        MaterialLimits::default(),
        public_key_must_not_be_requested
    )
    .is_err());
    assert_eq!(
        SlotJournal::open(path.join(JOURNAL), policy.slots().clone())
            .unwrap()
            .used(),
        0
    );
    assert!(RegistrationStore::create(
        path.parent().unwrap(),
        policy,
        &material,
        MaterialLimits::default(),
        public_key_must_not_be_requested
    )
    .is_err());
}

#[test]
fn process_death_during_material_operation_burns_slot_and_releases_lock() {
    let scratch = Scratch::new();
    let path = scratch.store();
    let (material, policy) = fixture();
    drop(create(&path, &material, &policy));
    let mut child = child(&path, "operate");
    wait_signal(&mut child, &path.with_extension("signal"));
    assert!(matches!(
        RegistrationStore::open(
            path.parent().unwrap(),
            policy.clone(),
            MaterialLimits::default(),
            public_key_must_not_be_requested
        ),
        Err(RegistrationError::Slots(SlotError::Busy))
    ));
    child.0.kill().unwrap();
    assert!(!child.0.wait().unwrap().success());
    let mut store = open(&path, &policy).unwrap();
    assert_eq!(store.used(), 1);
    store
        .reserve()
        .unwrap()
        .consume(|slot, _| assert_eq!(slot.index(), 1));
    assert_eq!(store.used(), 2);
}
