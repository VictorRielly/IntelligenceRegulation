use super::*;
use crate::field::Fp2;
use crate::mle::eval_mle_base;
use crate::pcs::{PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use crate::stable_weight_slots::{SlotError, SlotJournal, StableWeightBinding};
use crate::transcript::Transcript;
use crate::zk::ZkRng;
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
            "zk60-material-{}-{stamp}-{}",
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
fn key() -> MaterialKey {
    // Public test fixture only. No production deterministic key/nonce generator.
    MaterialKey::from_bytes([42; 32])
}
fn fixture() -> (CommittedZk, MaterialPolicy) {
    let params = PcsParams {
        log_cols: 4,
        inv_rate: 4,
        num_col_checks: 2,
    };
    let opts = ZkOpts {
        q_pad: 6,
        coset: Fp::new(7),
    };
    let mut rng = ZkRng::new(131, b"stable-material-test-only");
    let data = rng.fp_vec(3 * params.cols());
    let mut material = pcs::commit_zk_owned(&params, data, &NttTables::new(6), &opts, &mut rng);
    material.mask_rows = vec![1];
    material.prox_mask_row = Some(2);
    let slots = SlotPolicy::new(StableWeightBinding {
        manifest: [1; 32],
        layer: 2,
        layout: [3; 32],
        commitment: material.commitment(),
        params,
        opts,
        budget: 3,
    })
    .unwrap();
    let policy = MaterialPolicy::new(slots, vec![1], Some(2)).unwrap();
    (material, policy)
}
fn create(path: &Path, material: &CommittedZk, policy: &MaterialPolicy) {
    create_material(path, &key(), policy, material, MaterialLimits::default()).unwrap();
}
fn load(path: &Path, policy: &MaterialPolicy) -> Result<RestoredMaterial, MaterialError> {
    load_material(path, &key(), policy, MaterialLimits::default())
}

#[test]
fn roundtrip_reconstructs_exact_commitment_and_ordinary_pcs_opening() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    let (original, policy) = fixture();
    create(&path, &original, &policy);
    let restored = load(&path, &policy).unwrap();
    let cm = restored.pcs();
    assert_eq!(cm.commitment().root, original.commitment().root);
    assert_eq!(cm.data, original.data);
    assert_eq!(cm.pads, original.pads);
    assert_eq!(cm.salts, original.salts);
    assert_eq!(cm.mask_rows, original.mask_rows);
    assert_eq!(cm.prox_mask_row, original.prox_mask_row);
    match (&cm.cm.store, &original.cm.store) {
        (Store::Host { encoded: a }, Store::Host { encoded: b }) => assert_eq!(a, b),
        #[cfg(feature = "gpu-cuda")]
        _ => panic!("CPU fixture required"),
    }
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
            .mul(eval_mle_base(&cm.data[..16], &point))
            .add(e.mul(eval_mle_base(&cm.data[16..32], &point))),
    }];
    let mut before = Transcript::new(b"stable-material-opening-test");
    let mut after = Transcript::new(b"stable-material-opening-test");
    let original_opening = pcs::open_zk(&original, &claims, &mut before);
    let restored_opening = pcs::open_zk(cm, &claims, &mut after);
    let mut a = Vec::new();
    let mut b = Vec::new();
    original_opening.write_bytes(&mut a);
    restored_opening.write_bytes(&mut b);
    assert_eq!(a, b);
    let mut verifier = Transcript::new(b"stable-material-opening-test");
    pcs::verify_zk(
        &cm.cm.params,
        &cm.zk,
        &cm.commitment(),
        &claims,
        &restored_opening,
        &NttTables::new(6),
        &mut verifier,
    )
    .unwrap();
}

#[test]
fn fresh_nonces_private_files_and_no_overwrite_or_missing_fallback() {
    use std::os::unix::fs::PermissionsExt;
    let scratch = Scratch::new();
    let (original, policy) = fixture();
    let a = scratch.file("a");
    let b = scratch.file("b");
    create(&a, &original, &policy);
    create(&b, &original, &policy);
    let bytes_a = std::fs::read(&a).unwrap();
    let bytes_b = std::fs::read(&b).unwrap();
    assert_ne!(&bytes_a[40..64], &bytes_b[40..64]);
    assert_ne!(&bytes_a[64..], &bytes_b[64..]);
    assert_eq!(
        std::fs::metadata(&a).unwrap().permissions().mode() & 0o777,
        0o600
    );
    let words: Vec<u8> = original
        .data
        .iter()
        .flat_map(|v| v.0.to_le_bytes())
        .collect();
    for needle in [&words[..32], &original.salts[0][..]] {
        assert!(!bytes_a.windows(32).any(|window| window == needle));
    }
    assert!(create_material(&a, &key(), &policy, &original, MaterialLimits::default()).is_err());
    assert_eq!(bytes_a, std::fs::read(&a).unwrap());
    let missing = scratch.file("missing");
    assert!(load(&missing, &policy).is_err());
    assert!(!missing.exists());
    let empty = scratch.file("empty");
    std::fs::write(&empty, []).unwrap();
    assert!(create_material(
        &empty,
        &key(),
        &policy,
        &original,
        MaterialLimits::default()
    )
    .is_err());
    assert_eq!(std::fs::metadata(&empty).unwrap().len(), 0);
    std::fs::set_permissions(&b, std::fs::Permissions::from_mode(0o644)).unwrap();
    assert!(matches!(
        load(&b, &policy),
        Err(MaterialError::UnsupportedStorage)
    ));
}

#[test]
fn wrong_key_every_corrupted_byte_truncation_and_trailing_bytes_refuse() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    let (original, policy) = fixture();
    create(&path, &original, &policy);
    let bytes = std::fs::read(&path).unwrap();
    assert!(matches!(
        load_material(
            &path,
            &MaterialKey::from_bytes([43; 32]),
            &policy,
            MaterialLimits::default()
        ),
        Err(MaterialError::AuthenticationFailed)
    ));
    // Every byte position covers version, policy, nonce, ciphertext and tag.
    for i in 0..bytes.len() {
        let mut damaged = bytes.clone();
        damaged[i] ^= 1;
        std::fs::write(&path, damaged).unwrap();
        assert!(
            load(&path, &policy).is_err(),
            "accepted corruption at byte {i}"
        );
    }
    for end in [0, 7, 8, 39, 40, 63, 64, bytes.len() - 16, bytes.len() - 1] {
        std::fs::write(&path, &bytes[..end]).unwrap();
        assert!(matches!(
            load(&path, &policy),
            Err(MaterialError::InvalidMaterial)
        ));
    }
    let mut extra = bytes.clone();
    extra.push(0);
    std::fs::write(&path, extra).unwrap();
    assert!(matches!(
        load(&path, &policy),
        Err(MaterialError::InvalidMaterial)
    ));
    std::fs::write(&path, bytes).unwrap();
    load(&path, &policy).unwrap();
}

#[test]
fn every_policy_and_role_change_is_bound() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    let (original, policy) = fixture();
    create(&path, &original, &policy);
    let original_bytes = std::fs::read(&path).unwrap();
    for case in 0..10 {
        let mut binding = policy.slots.binding().clone();
        let mut masks = policy.mask_rows.clone();
        let mut prox = policy.prox_mask_row;
        match case {
            0 => binding.manifest[0] ^= 1,
            1 => binding.layer += 1,
            2 => binding.layout[0] ^= 1,
            3 => binding.commitment.root[0] ^= 1,
            4 => binding.opts.coset = Fp::new(11),
            5 => masks = vec![0],
            6 => prox = None,
            7 => {
                binding.budget = 6;
                binding.params.num_col_checks = 1;
            }
            8 => binding.commitment.rows += 1,
            _ => binding.params.inv_rate *= 2,
        }
        let changed = MaterialPolicy::new(SlotPolicy::new(binding).unwrap(), masks, prox).unwrap();
        assert!(load(&path, &changed).is_err(), "policy case {case}");
        // Rewriting the clear header to match a different trusted policy must
        // still fail authentication (same-size cases). Header equality alone
        // must never substitute for the AEAD associated-data binding.
        if case < 8 {
            let mut substituted = original_bytes.clone();
            substituted[8..40].copy_from_slice(&changed.digest());
            std::fs::write(&path, substituted).unwrap();
            assert!(matches!(
                load(&path, &changed),
                Err(MaterialError::AuthenticationFailed)
            ));
            std::fs::write(&path, &original_bytes).unwrap();
        }
    }
    for (masks, prox) in [
        (vec![3], None),
        (vec![1, 1], None),
        (vec![1], Some(1)),
        (vec![1], Some(3)),
    ] {
        assert!(matches!(
            MaterialPolicy::new(policy.slots.clone(), masks, prox),
            Err(MaterialError::InvalidLayout)
        ));
    }
}

// Test-only writer possessing the public fixture key: bypass AEAD rejection to
// exercise canonical parsing and independently trusted root validation.
fn rewrite_authenticated(path: &Path, edit: impl FnOnce(&mut [u8])) {
    let bytes = std::fs::read(path).unwrap();
    let header = &bytes[..HEADER_BYTES];
    let mut payload = bytes[HEADER_BYTES..].to_vec();
    let key = key();
    let cipher = XChaCha20Poly1305::new((&*key.0).into());
    cipher
        .decrypt_in_place(XNonce::from_slice(&header[40..]), header, &mut payload)
        .unwrap();
    edit(&mut payload);
    // Deliberate nonce reuse ONLY in this adversarial public fixture rewrite.
    cipher
        .encrypt_in_place(XNonce::from_slice(&header[40..]), header, &mut payload)
        .unwrap();
    let mut rewritten = header.to_vec();
    rewritten.extend(payload);
    std::fs::write(path, rewritten).unwrap();
}

#[test]
fn authenticated_noncanonical_words_and_inconsistent_roots_refuse() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    let (original, policy) = fixture();
    create(&path, &original, &policy);
    let bytes = std::fs::read(&path).unwrap();
    for offset in [0, original.data.len() * 8] {
        rewrite_authenticated(&path, |plain| {
            plain[offset..offset + 8].copy_from_slice(&P.to_le_bytes())
        });
        assert!(matches!(
            load(&path, &policy),
            Err(MaterialError::InvalidMaterial)
        ));
        std::fs::write(&path, &bytes).unwrap();
    }
    for offset in [
        0,
        original.data.len() * 8,
        (original.data.len() + original.pads.len()) * 8,
    ] {
        rewrite_authenticated(&path, |plain| plain[offset] ^= 1);
        assert!(matches!(
            load(&path, &policy),
            Err(MaterialError::RootMismatch)
        ));
        std::fs::write(&path, &bytes).unwrap();
    }
}

#[test]
fn creation_checks_actual_secrets_and_roles_before_touching_path() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    for case in 0..10 {
        let (mut material, policy) = fixture();
        match case {
            0 => material.data[0] = material.data[0].add(Fp::ONE),
            1 => material.pads[0] = material.pads[0].add(Fp::ONE),
            2 => material.salts[0][0] ^= 1,
            3 => material.data[0] = Fp(P),
            4 => {
                material.data.pop();
            }
            5 => {
                material.pads.pop();
            }
            6 => {
                material.salts.pop();
            }
            7 => material.mask_rows.clear(),
            8 => material.prox_mask_row = None,
            _ => material.cm.params.num_col_checks += 1,
        }
        assert!(
            create_material(&path, &key(), &policy, &material, MaterialLimits::default()).is_err(),
            "create case {case}"
        );
        assert!(!path.exists());
    }
}

#[test]
fn trusted_resource_limits_and_overflows_refuse_before_io_or_allocation() {
    let scratch = Scratch::new();
    let path = scratch.file("not-created");
    let (material, policy) = fixture();
    let geometry = Geometry::new(&policy, MaterialLimits::default()).unwrap();
    for limits in [
        MaterialLimits {
            max_file_bytes: geometry.file_bytes - 1,
            max_encoded_elements: usize::MAX,
        },
        MaterialLimits {
            max_file_bytes: usize::MAX,
            max_encoded_elements: geometry.encoded - 1,
        },
    ] {
        assert!(matches!(
            create_material(&path, &key(), &policy, &material, limits),
            Err(MaterialError::LimitExceeded)
        ));
        assert!(matches!(
            load_material(&path, &key(), &policy, limits),
            Err(MaterialError::LimitExceeded)
        ));
        assert!(!path.exists());
    }
    let mut binding = policy.slots.binding().clone();
    binding.commitment.rows = usize::MAX;
    let huge = MaterialPolicy::new(SlotPolicy::new(binding).unwrap(), vec![], None).unwrap();
    assert!(matches!(
        load_material(
            &path,
            &key(),
            &huge,
            MaterialLimits {
                max_file_bytes: usize::MAX,
                max_encoded_elements: usize::MAX,
            }
        ),
        Err(MaterialError::LimitExceeded)
    ));
    let exact = MaterialLimits {
        max_file_bytes: geometry.file_bytes,
        max_encoded_elements: geometry.encoded,
    };
    create_material(&path, &key(), &policy, &material, exact).unwrap();
    load_material(&path, &key(), &policy, exact).unwrap();
}

#[test]
fn material_process_child() {
    let Some(directory) = std::env::var_os("HL_TEST_STABLE_MATERIAL_CHILD") else {
        return;
    };
    let path = PathBuf::from(directory);
    let (_, policy) = fixture(); // independently trusted public fixture policy
    let mut journal = SlotJournal::open(path.join("journal"), policy.slots.clone()).unwrap();
    let restored = load(&path.join("material"), &policy).unwrap();
    assert_eq!(
        restored.pcs().commitment().root,
        policy.slots.binding().commitment.root
    );
    assert_eq!(journal.reserve().unwrap().index(), 1);
}

#[test]
fn independent_process_reload_preserves_spent_and_exhausted_journal() {
    let scratch = Scratch::new();
    let path = scratch.file("material");
    let journal_path = scratch.file("journal");
    let (original, policy) = fixture();
    create(&path, &original, &policy);
    let mut journal = SlotJournal::create(&journal_path, policy.slots.clone()).unwrap();
    assert_eq!(journal.reserve().unwrap().index(), 0);
    drop(journal);
    let output = std::process::Command::new(std::env::current_exe().unwrap())
        .args([
            "--exact",
            "stable_weight_material::tests::material_process_child",
            "--nocapture",
        ])
        .env("HL_TEST_STABLE_MATERIAL_CHILD", &scratch.0)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "child failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let mut journal = SlotJournal::open(&journal_path, policy.slots.clone()).unwrap();
    assert_eq!(journal.used(), 2);
    assert_eq!(journal.reserve().unwrap().index(), 2);
    drop(journal);
    for _ in 0..2 {
        load(&path, &policy).unwrap();
        let mut journal = SlotJournal::open(&journal_path, policy.slots.clone()).unwrap();
        assert_eq!(journal.used(), 3);
        assert!(matches!(journal.reserve(), Err(SlotError::Exhausted)));
    }
}
