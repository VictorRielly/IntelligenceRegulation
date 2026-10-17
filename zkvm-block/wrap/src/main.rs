//! Local native Groth16 wrapping for the fixed complete-block experiment.
//! Intermediate seals and witness files belong in the caller's private work dir.
use bincode::Options;
use risc0_zkvm::{
    sha::Digestible, ApiClient, AssetRequest, Groth16Receipt, Groth16ReceiptVerifierParameters,
    InnerReceipt, ProverOpts, Receipt, ReceiptClaim, SuccinctReceipt, VerifierContext,
};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::{
    fs::{self, DirBuilder, File, OpenOptions},
    io::{Read, Write},
    path::Path,
    process::{Command, Stdio},
};
use zk60_block_methods::PRIVATE_BLOCK_ID;
use zk60_block_statement::{Statement, JOURNAL_BYTES};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const LIMIT: u64 = 16 * 1024 * 1024;
fn codec() -> impl Options {
    bincode::DefaultOptions::new()
        .with_fixint_encoding()
        .with_limit(LIMIT)
        .reject_trailing_bytes()
}
fn read(path: impl AsRef<Path>, max: u64) -> Result<Vec<u8>> {
    let f = File::open(path)?;
    if !f.metadata()?.is_file() || f.metadata()?.len() > max {
        return Err("file size/type refused".into());
    }
    let mut data = Vec::new();
    f.take(max + 1).read_to_end(&mut data)?;
    if data.len() as u64 > max {
        return Err("file size refused".into());
    }
    Ok(data)
}
fn write_new(path: impl AsRef<Path>, bytes: &[u8], mode: u32) -> Result<()> {
    let mut f = OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(mode)
        .open(path)?;
    f.write_all(bytes)?;
    f.sync_all()?;
    Ok(())
}
fn verify(receipt: &Receipt, policy: &Statement) -> Result<()> {
    if !matches!(receipt.inner, InnerReceipt::Groth16(_)) {
        return Err("Groth16 receipt required".into());
    }
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_BLOCK_ID,
    )?;
    Ok(())
}
fn subprocess(program: &Path, args: &[&Path], work: &Path, label: &str) -> Result<()> {
    // stdout/stderr may contain prover internals, so keep them owner-only.
    let log = OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .open(work.join(format!("{label}.log")))?;
    let error = log.try_clone()?;
    // Match the upstream witness generator's documented 16 MiB stack limit.
    let status = Command::new("/usr/bin/prlimit")
        .arg("--stack=16777216")
        .arg("--")
        .arg(program)
        .args(args)
        .current_dir(work)
        .stdin(Stdio::null())
        .stdout(Stdio::from(log))
        .stderr(Stdio::from(error))
        .env("GOMAXPROCS", "2")
        .status()?;
    if !status.success() {
        return Err(format!("{label} failed; see private work log").into());
    }
    Ok(())
}
/// Every failure after the private work directory exists keeps it: the witness,
/// the subprocess logs and the intermediate seal are the diagnostic material.
/// Say so in the error, because the caller now has to delete it by hand.
fn kept_work(e: Box<dyn std::error::Error>, work: &Path) -> Box<dyn std::error::Error> {
    format!(
        "{e}; private work directory kept for diagnosis and must be deleted by hand: {}",
        work.display()
    )
    .into()
}
/// Recursively remove the private work directory after a verified wrap, so the
/// conversion intermediates do not outlive the run by default. The caller's
/// original INNER_RECEIPT remains in its private location.
///
/// Only the exact directory this run created may be removed: `work` must equal
/// its own canonicalized parent joined with its final component (the same
/// canonicalized-parent construction used before the directory was created),
/// must be outside the public artifact directory, and must be a real directory
/// rather than a symlink. `remove_dir_all` never follows symlinks, so the
/// `stark_verify.dat` symlink into the native tool directory is unlinked and
/// the tool itself is untouched.
fn remove_work_dir(work: &Path, public_parent: &Path) -> Result<()> {
    let name = work.file_name().ok_or("work directory name required")?;
    let parent = work.parent().ok_or("work directory has no parent")?;
    if parent.canonicalize()?.as_path() != parent || parent.join(name) != work {
        return Err("refusing to remove a non-canonical work directory path".into());
    }
    if work.starts_with(public_parent) {
        return Err("refusing to remove inside the public artifact directory".into());
    }
    let meta = fs::symlink_metadata(work)?;
    if meta.file_type().is_symlink() || !meta.is_dir() {
        return Err("private work path is not a directory".into());
    }
    fs::remove_dir_all(work)?;
    Ok(())
}
/// Everything that happens inside the private work directory. Split out so the
/// caller can distinguish "failed with intermediates worth keeping" from
/// "succeeded, the work directory is now safe to delete".
#[allow(clippy::too_many_arguments)]
fn prove_in_work(
    work: &Path,
    tools: &Path,
    succinct: &SuccinctReceipt<ReceiptClaim>,
    journal: Vec<u8>,
    policy: &Statement,
    output_path: &str,
    r0vm: &str,
) -> Result<usize> {
    std::os::unix::fs::symlink(tools.join("stark_verify.dat"), work.join("stark_verify.dat"))?;
    let client = ApiClient::new_sub_process(r0vm)?;
    let ident = client.identity_p254(
        &ProverOpts::succinct().with_dev_mode(false),
        succinct.clone().try_into()?,
        AssetRequest::Inline,
    )?;
    if ident.claim.digest() != succinct.claim.digest() {
        return Err("identity conversion changed verified claim".into());
    }
    let input = risc0_groth16::prove::to_json(&ident.get_seal_bytes())?;
    let input_path = work.join("input.json");
    let witness_path = work.join("witness.wtns");
    let proof_path = work.join("proof.json");
    write_new(&input_path, input.as_bytes(), 0o600)?;
    subprocess(
        &tools.join("stark_verify"),
        &[&input_path, &witness_path],
        work,
        "witness",
    )?;
    subprocess(
        &tools.join("prover"),
        &[
            &tools.join("stark_verify.cs"),
            &tools.join("stark_verify_final.pk.dmp"),
            &witness_path,
            &proof_path,
        ],
        work,
        "groth16",
    )?;
    let proof: risc0_groth16::ProofJson = serde_json::from_slice(&read(&proof_path, 1024 * 1024)?)?;
    let seal: risc0_groth16::Seal = proof.try_into()?;
    let groth = Groth16Receipt::new(
        seal.to_vec(),
        succinct.claim.clone(),
        Groth16ReceiptVerifierParameters::default().digest(),
    );
    let outer = Receipt::new(InnerReceipt::Groth16(groth), journal);
    verify(&outer, policy)?;
    let bytes = codec().serialize(&outer)?;
    write_new(output_path, &bytes, 0o644)?;
    // Validate the actual saved bytes before removing conversion diagnostics.
    // A separate `verify` process remains the independent verification gate.
    let saved: Receipt = codec().deserialize(&read(output_path, LIMIT)?)?;
    verify(&saved, policy)?;
    Ok(bytes.len())
}
fn wrap(
    policy_path: &str,
    inner_path: &str,
    output_path: &str,
    tool_dir: &str,
    work_dir: &str,
    r0vm: &str,
    keep_work: bool,
) -> Result<()> {
    if Path::new(output_path).exists() {
        return Err("output already exists".into());
    }
    let policy = Statement::decode(&read(policy_path, JOURNAL_BYTES as u64)?)?;
    let receipt: Receipt = codec().deserialize(&read(inner_path, LIMIT)?)?;
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_BLOCK_ID,
    )?;
    let succinct = match &receipt.inner {
        InnerReceipt::Succinct(s) => s.clone(),
        _ => return Err("real succinct input required".into()),
    };
    // Pinned length and SHA-256 of each native tool, checked before the work
    // directory exists and before any tool runs. The table is compiled into
    // this binary by `zk60-native-tools`, so the pinning is a property of the
    // wrap artifact and not of whatever orchestration invoked it; the recorded
    // extraction it must match is
    // results/zk60_loop_20260918/block-integration/groth16-native-files.json
    // (asserted by `linked_pins_match_the_recorded_native_tool_hashes`).
    let tools = zk60_native_tools::validate_tool_directory(Path::new(tool_dir))?.dir;
    let work = std::path::absolute(work_dir)?;
    // A new private directory preserves intermediates for failure diagnosis;
    // never place it in the public artifact directory.
    let output = std::path::absolute(output_path)?;
    let public_parent = output
        .parent()
        .ok_or("output has no parent")?
        .canonicalize()?;
    let work_parent = work
        .parent()
        .ok_or("work directory has no parent")?
        .canonicalize()?;
    let work = work_parent.join(work.file_name().ok_or("work directory name required")?);
    if work.starts_with(&public_parent) {
        return Err("work directory must be separate from public artifact directory".into());
    }
    DirBuilder::new().mode(0o700).create(&work)?;
    let saved = prove_in_work(
        &work,
        &tools,
        &succinct,
        receipt.journal.bytes,
        &policy,
        output_path,
        r0vm,
    );
    let bytes = match saved {
        Ok(bytes) => bytes,
        Err(e) => return Err(kept_work(e, &work)),
    };
    // Saved receipt bytes have been reread and verified in this process. The
    // conversion seal/witness may now be removed; the input receipt remains.
    if !keep_work {
        remove_work_dir(&work, &public_parent).map_err(|e| {
            format!(
                "groth16 receipt saved, but the private work directory still holds the inner seal \
                 and could not be removed: {e}"
            )
        })?;
    }
    println!(
        "{{\"saved_groth16_receipt\":true,\"receipt_bytes\":{},\"work_removed\":{},\"mvp_complete\":false}}",
        bytes, !keep_work
    );
    Ok(())
}
fn run() -> Result<()> {
    let a: Vec<String> = std::env::args().collect();
    match a.get(1).map(String::as_str){
        Some("wrap") if a.len()==8=>wrap(&a[2],&a[3],&a[4],&a[5],&a[6],&a[7],false),
        Some("wrap") if a.len()==9 && a[8]=="--keep-work"=>wrap(&a[2],&a[3],&a[4],&a[5],&a[6],&a[7],true),
        Some("verify") if a.len()==4=>{
            let policy=Statement::decode(&read(&a[2],JOURNAL_BYTES as u64)?)?;
            let receipt=codec().deserialize(&read(&a[3],LIMIT)?)?;verify(&receipt,&policy)?;
            println!("{{\"verified\":true,\"kind\":\"groth16\",\"coverage\":\"one-fixed-T32-block\",\"mvp_complete\":false}}");Ok(())
        },
        // Public provenance check only: no proof, policy or private witness is read.
        Some("check-tools") if a.len()==3=>{
            zk60_native_tools::validate_tool_directory(Path::new(&a[2]))?;
            println!("{{\"native_tools_verified\":true}}");Ok(())
        },
        Some("image-id") if a.len()==2=>{println!("{}",risc0_zkvm::sha::Digest::from(PRIVATE_BLOCK_ID));Ok(())},
        _=>Err("usage: wrap POLICY INNER_RECEIPT OUTPUT_RECEIPT NATIVE_TOOLS PRIVATE_WORK R0VM [--keep-work] | verify POLICY RECEIPT | check-tools NATIVE_TOOLS | image-id".into())
    }
}
// Refuse inherited profiler, remote, fake-proof and unreviewed runtime switches.
fn refused_variable(name: &str) -> bool {
    name.starts_with("RISC0_") || name.starts_with("BONSAI_")
}
fn main() {
    // Upstream identity conversion inherits these before spawning r0vm.
    std::env::set_var("RUST_LOG", "off");
    std::env::set_var("RUST_BACKTRACE", "0");
    if std::env::vars_os().any(|(k, _)| k.to_str().is_some_and(refused_variable)) {
        eprintln!("zk60 block: RISC0_* and BONSAI_* runtime switches must be unset");
        std::process::exit(1);
    }
    if let Err(e) = run() {
        eprintln!("zk60 wrap: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use risc0_zkvm::{
        Assumption, Assumptions, Digest, ExitCode, MaybePruned, Output, ReceiptClaim,
    };
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// A scratch directory that is removed when the test ends.
    struct Scratch(PathBuf);

    impl Scratch {
        fn new() -> Self {
            static N: AtomicUsize = AtomicUsize::new(0);
            let dir = std::env::temp_dir().join(format!(
                "zk60-block-wrap-test-{}-{}",
                std::process::id(),
                N.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&dir).unwrap();
            Scratch(dir.canonicalize().unwrap())
        }
        /// A plausible private work directory: mode 0700 with intermediates.
        fn work(&self, name: &str) -> PathBuf {
            let work = self.0.join(name);
            DirBuilder::new().mode(0o700).create(&work).unwrap();
            fs::write(work.join("witness.wtns"), b"private witness").unwrap();
            fs::create_dir(work.join("nested")).unwrap();
            fs::write(work.join("nested/seal.bin"), b"inner seal").unwrap();
            work
        }
    }

    impl Drop for Scratch {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn policy() -> Statement {
        Statement {
            context: [1; 32],
            model: [2; 32],
            input: [3; 32],
            output: [4; 32],
        }
    }

    /// An outer receipt with the correct 144-byte policy journal, a 256-byte
    /// zero seal, and a caller-chosen inner claim / verifier parameters digest.
    fn forged_receipt(claim: ReceiptClaim, verifier_parameters: Digest) -> Receipt {
        Receipt::new(
            InnerReceipt::Groth16(Groth16Receipt::new(
                vec![0; 256],
                claim.into(),
                verifier_parameters,
            )),
            policy().encode().to_vec(),
        )
    }

    #[test]
    fn fake_and_empty_outer_seals_cannot_assert_an_authentic_claim() {
        let policy = policy();
        let claim = ReceiptClaim::ok(PRIVATE_BLOCK_ID, policy.encode().to_vec());
        let fake = Receipt::new(
            InnerReceipt::Fake(risc0_zkvm::FakeReceipt::new(claim.clone())),
            policy.encode().to_vec(),
        );
        assert!(verify(&fake, &policy).is_err());
        let forged = Receipt::new(
            InnerReceipt::Groth16(Groth16Receipt::new(
                vec![0; 256],
                claim.into(),
                Groth16ReceiptVerifierParameters::default().digest(),
            )),
            policy.encode().to_vec(),
        );
        assert!(verify(&forged, &policy).is_err());
        let bytes = codec().serialize(&forged).unwrap();
        assert!(codec()
            .deserialize::<Receipt>(&bytes[..bytes.len() - 1])
            .is_err());
        let mut extra = bytes;
        extra.push(0);
        assert!(codec().deserialize::<Receipt>(&extra).is_err());
    }

    /// Claim-shape regressions: the journal is the correct policy in all three
    /// cases, so `Statement::check_journal` passes and only the receipt checks
    /// can refuse them.
    ///
    /// Order of the checks, from risc0-zkvm 3.0.6 `receipt.rs:171-201` and
    /// `receipt/groth16.rs`:
    ///   1. `Receipt::verify_with_context` first compares
    ///      `inner.verifier_parameters()` with `metadata.verifier_parameters`.
    ///      `Receipt::new` copies the inner value into the metadata, so this
    ///      internal-consistency check passes in all three cases here.
    ///   2. `InnerReceipt::verify_integrity_with_context` ->
    ///      `Groth16Receipt::verify_integrity_with_context`, which compares the
    ///      context's Groth16 parameters digest with the receipt's field and
    ///      only then runs `risc0_groth16::Verifier` over the seal.
    ///   3. Last, the decoded claim digest is compared with
    ///      `ReceiptClaim::ok(image_id, Pruned(journal.digest()))`.
    ///
    /// So: (a) Paused(0) and (b) a non-empty assumptions list are both refused
    /// at step 2 on SEAL INTEGRITY (the 256 zero bytes are not a valid proof),
    /// never reaching the step-3 claim comparison that their shape violates;
    /// (c) a wrong verifier parameters digest is refused at step 2 *before* the
    /// seal is looked at, by `VerificationError::VerifierParametersMismatch`.
    /// The seal is therefore the first line of defence, and the exit code and
    /// assumptions-list checks are only reachable behind a sound seal.
    #[test]
    fn wrong_claim_shapes_are_refused_even_with_the_correct_journal() {
        let policy = policy();
        let journal = policy.encode().to_vec();
        let default_params = Groth16ReceiptVerifierParameters::default().digest();

        // `VerificationError`'s own wording, so the assertions below name the
        // check that actually fired rather than only that something failed.
        let seal_integrity = ["invalid receipt format", "verification indicates proof is invalid"];
        let refusal = |receipt: &Receipt| {
            let e = verify(receipt, &policy).unwrap_err().to_string();
            assert!(!e.contains("claim digest"), "claim check ran first: {e}");
            e
        };

        // (a) exit code Paused(0) with the same zero post state ok() uses.
        let paused = ReceiptClaim::paused(PRIVATE_BLOCK_ID, journal.clone());
        assert!(matches!(paused.exit_code, ExitCode::Paused(0)));
        let e = refusal(&forged_receipt(paused, default_params));
        assert!(seal_integrity.contains(&e.as_str()), "expected a seal failure: {e}");

        // (b) a conditional receipt: one unresolved assumption in the output.
        let mut conditional = ReceiptClaim::ok(PRIVATE_BLOCK_ID, journal.clone());
        conditional.output = Some(Output {
            journal: MaybePruned::Value(journal.clone()),
            assumptions: MaybePruned::Value(Assumptions(vec![MaybePruned::Value(Assumption {
                claim: Digest::ZERO,
                control_root: Digest::ZERO,
            })])),
        })
        .into();
        let e = refusal(&forged_receipt(conditional, default_params));
        assert!(seal_integrity.contains(&e.as_str()), "expected a seal failure: {e}");

        // (c) the correct claim, but verifier parameters this verifier does not
        // implement; `Receipt::new` mirrors it into the metadata, so the
        // mismatch is caught against the context, not against the metadata, and
        // it fires before the seal is looked at.
        let correct = ReceiptClaim::ok(PRIVATE_BLOCK_ID, journal);
        assert_ne!(Digest::ZERO, default_params);
        let e = refusal(&forged_receipt(correct, Digest::ZERO));
        assert!(
            e.contains("parameters digest") && !seal_integrity.contains(&e.as_str()),
            "expected a verifier parameters mismatch: {e}"
        );
    }

    /// The native tool pins compiled into this binary must equal the recorded
    /// extraction of the official image. Two copies of the digests would be
    /// free to drift; this makes the record and the artifact one fact.
    #[test]
    fn linked_pins_match_the_recorded_native_tool_hashes() {
        const RECORD: &str = include_str!(
            "../../../results/zk60_loop_20260918/block-integration/groth16-native-files.json"
        );
        let entries: Vec<serde_json::Value> = serde_json::from_str(RECORD).unwrap();
        assert_eq!(zk60_native_tools::PINS.len(), 5);
        for pin in zk60_native_tools::PINS {
            let entry = entries
                .iter()
                .find(|e| e["file"].as_str() == Some(pin.name))
                .unwrap_or_else(|| panic!("no record entry for {}", pin.name));
            assert_eq!(entry["bytes"].as_u64(), Some(pin.len), "{}", pin.name);
            assert_eq!(entry["sha256"].as_str(), Some(pin.sha256), "{}", pin.name);
        }
    }

    #[test]
    fn a_verified_wrap_removes_the_private_work_directory() {
        let s = Scratch::new();
        let public = s.0.join("public");
        fs::create_dir(&public).unwrap();
        let work = s.work("private-work");
        remove_work_dir(&work, &public).unwrap();
        assert!(!work.exists());
        // Only the work directory: its parent and the public directory remain.
        assert!(s.0.is_dir() && public.is_dir());
    }

    #[test]
    fn the_symlink_into_the_native_tools_is_unlinked_not_followed() {
        let s = Scratch::new();
        let tools = s.0.join("tools");
        fs::create_dir(&tools).unwrap();
        fs::write(tools.join("stark_verify.dat"), b"pinned tool").unwrap();
        let work = s.work("private-work");
        std::os::unix::fs::symlink(tools.join("stark_verify.dat"), work.join("stark_verify.dat"))
            .unwrap();
        remove_work_dir(&work, &s.0.join("public")).unwrap();
        assert!(!work.exists());
        assert!(tools.join("stark_verify.dat").is_file());
    }

    #[test]
    fn removal_refuses_anything_but_the_directory_this_run_created() {
        let s = Scratch::new();
        // Inside the public artifact directory.
        let public = s.0.join("public");
        fs::create_dir(&public).unwrap();
        let inside = public.join("work");
        fs::create_dir(&inside).unwrap();
        assert!(remove_work_dir(&inside, &public).is_err());
        assert!(inside.is_dir());

        // A symlink pointing at a real directory.
        let real = s.work("real-work");
        let link = s.0.join("link-work");
        std::os::unix::fs::symlink(&real, &link).unwrap();
        assert!(remove_work_dir(&link, &public).is_err());
        assert!(real.is_dir());

        // A path that reaches the directory through a parent traversal, so the
        // caller's canonicalized-parent construction was not what produced it.
        let traversal = public.join("..").join("real-work");
        assert!(remove_work_dir(&traversal, &public).is_err());
        assert!(real.is_dir());

        // A regular file, and a path that does not exist.
        let file = s.0.join("not-a-dir");
        fs::write(&file, b"x").unwrap();
        assert!(remove_work_dir(&file, &public).is_err());
        assert!(file.is_file());
        assert!(remove_work_dir(&s.0.join("absent"), &public).is_err());
    }

    #[test]
    fn a_failed_wrap_says_the_work_directory_was_kept() {
        let work = Path::new("/tmp/zk60-private-work-example");
        let message = kept_work("witness failed; see private work log".into(), work).to_string();
        assert!(message.contains("witness failed"));
        assert!(message.contains("kept for diagnosis"));
        assert!(message.contains("/tmp/zk60-private-work-example"));
    }
}

#[test]
fn refuses_profiler_and_unreviewed_runtime_switches() {
    for name in ["RISC0_PPROF_OUT", "RISC0_DEV_MODE", "RISC0_UNKNOWN", "BONSAI_API_KEY"] { assert!(refused_variable(name)); }
    for name in ["PATH", "RUST_LOG"] { assert!(!refused_variable(name)); }
}
