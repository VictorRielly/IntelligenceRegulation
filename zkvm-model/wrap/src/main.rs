//! Local native Groth16 wrapping and the public verifier for the fixed
//! token-model experiment (profile zk60-r0-token-v1). Intermediate seals and
//! witness files belong in the caller's private work dir.
use bincode::Options;
use risc0_zkvm::{
    sha::Digestible, ApiClient, AssetRequest, Groth16Receipt, Groth16ReceiptVerifierParameters,
    InnerReceipt, ProverOpts, Receipt, VerifierContext,
};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::{
    fs::{DirBuilder, File, OpenOptions},
    io::{Read, Write},
    path::Path,
    process::{Command, Stdio},
};
use zk60_token_methods::PRIVATE_TOKEN_ID;
use zk60_token_statement::{Statement, JOURNAL_BYTES};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const LIMIT: u64 = 16 * 1024 * 1024;
const COVERAGE: &str = "synthetic-T32-V32-two-block-greedy-token";
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
/// Fake-proof, remote-prover and prover-selection switches are refused, not
/// ignored: the r0vm child inherits this process's environment.
fn refused_variable(name: &str) -> bool {
    name.starts_with("RISC0_") || name.starts_with("BONSAI_")
}
/// The verifier supplies the approved image ID independently (the exact
/// lowercase hex printed by `image-id` of an approved build). A binary
/// compiled from any other guest refuses instead of verifying against its own.
fn check_image(expected_hex: &str) -> Result<()> {
    if risc0_zkvm::sha::Digest::from(PRIVATE_TOKEN_ID).to_string() != expected_hex {
        return Err("compiled image differs from expected image id".into());
    }
    Ok(())
}
/// The only public acceptance path: Groth16 kind, the caller's exact policy
/// bytes, then the seal against the compiled image with dev mode off.
fn verify(receipt: &Receipt, policy: &Statement) -> Result<()> {
    if !matches!(receipt.inner, InnerReceipt::Groth16(_)) {
        return Err("Groth16 receipt required".into());
    }
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_TOKEN_ID,
    )?;
    Ok(())
}
/// Verifies the exact saved bytes: strict bounded decoding, no trailing data.
fn verify_saved(policy: &Statement, receipt_path: impl AsRef<Path>) -> Result<Vec<u8>> {
    let bytes = read(receipt_path, LIMIT)?;
    let receipt: Receipt = codec().deserialize(&bytes)?;
    verify(&receipt, policy)?;
    Ok(bytes)
}
/// The saved inner receipt is a private witness: a regular owner-only file
/// that does not sit beside the public artifact.
fn private_inner(inner_path: &str, public_parent: &Path) -> Result<Vec<u8>> {
    let meta = std::fs::symlink_metadata(inner_path)?;
    if !meta.is_file() || meta.permissions().mode() & 0o077 != 0 {
        return Err("inner receipt must be a saved owner-only regular file".into());
    }
    if Path::new(inner_path).canonicalize()?.starts_with(public_parent) {
        return Err("inner receipt must stay outside the public artifact directory".into());
    }
    read(inner_path, LIMIT)
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
fn wrap(
    policy_path: &str,
    inner_path: &str,
    output_path: &str,
    tool_dir: &str,
    work_dir: &str,
    r0vm: &str,
) -> Result<()> {
    if Path::new(output_path).exists() {
        return Err("output already exists".into());
    }
    if !Path::new(r0vm).is_absolute() {
        return Err("explicit absolute r0vm path required".into());
    }
    let output = std::path::absolute(output_path)?;
    let public_parent = output
        .parent()
        .ok_or("output has no parent")?
        .canonicalize()?;
    // The policy comes from the caller, never from the candidate receipt.
    let policy = Statement::decode(&read(policy_path, JOURNAL_BYTES as u64)?)?;
    let receipt: Receipt = codec().deserialize(&private_inner(inner_path, &public_parent)?)?;
    // The host saved this private inner receipt before any outer proof exists.
    let succinct = match &receipt.inner {
        InnerReceipt::Succinct(s) => s,
        _ => return Err("real succinct input required".into()),
    };
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_TOKEN_ID,
    )?;
    let tools = zk60_native_tools::validate_tool_directory(Path::new(tool_dir))?.dir;
    let work = std::path::absolute(work_dir)?;
    // A new private directory preserves intermediates for failure diagnosis;
    // never place it in the public artifact directory.
    let work_parent = work
        .parent()
        .ok_or("work directory has no parent")?
        .canonicalize()?;
    let work = work_parent.join(work.file_name().ok_or("work directory name required")?);
    if work.starts_with(&public_parent) {
        return Err("work directory must be separate from public artifact directory".into());
    }
    DirBuilder::new().mode(0o700).create(&work)?;
    std::os::unix::fs::symlink(
        tools.join("stark_verify.dat"),
        work.join("stark_verify.dat"),
    )?;
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
        &work,
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
        &work,
        "groth16",
    )?;
    let proof: risc0_groth16::ProofJson = serde_json::from_slice(&read(&proof_path, 1024 * 1024)?)?;
    let seal: risc0_groth16::Seal = proof.try_into()?;
    // The outer receipt carries the verified ORIGINAL claim and journal, not
    // anything returned by the conversion or the native prover.
    let groth = Groth16Receipt::new(
        seal.to_vec(),
        succinct.claim.clone(),
        Groth16ReceiptVerifierParameters::default().digest(),
    );
    let receipt = Receipt::new(InnerReceipt::Groth16(groth), receipt.journal.bytes);
    verify(&receipt, &policy)?;
    let bytes = codec().serialize(&receipt)?;
    write_new(&output, &bytes, 0o644)?;
    if verify_saved(&policy, &output)? != bytes {
        return Err("saved receipt differs from verified receipt; do not publish it".into());
    }
    println!(
        "{{\"saved_groth16_receipt\":true,\"receipt_bytes\":{},\"mvp_complete\":false}}",
        bytes.len()
    );
    Ok(())
}
fn run() -> Result<()> {
    let a: Vec<String> = std::env::args().collect();
    match a.get(1).map(String::as_str){
        Some("wrap") if a.len()==8=>wrap(&a[2],&a[3],&a[4],&a[5],&a[6],&a[7]),
        Some("verify") if a.len()==5=>{
            check_image(&a[4])?;
            let policy=Statement::decode(&read(&a[2],JOURNAL_BYTES as u64)?)?;
            verify_saved(&policy,&a[3])?;
            println!("{{\"verified\":true,\"kind\":\"groth16\",\"coverage\":\"{COVERAGE}\",\"mvp_complete\":false}}");Ok(())
        },
        Some("image-id") if a.len()==2=>{println!("{}",risc0_zkvm::sha::Digest::from(PRIVATE_TOKEN_ID));Ok(())},
        _=>Err("usage: wrap POLICY INNER_RECEIPT OUTPUT_RECEIPT NATIVE_TOOLS PRIVATE_WORK R0VM | verify POLICY RECEIPT IMAGE_ID_HEX | image-id".into())
    }
}
fn main() {
    // Upstream identity conversion inherits these before spawning r0vm.
    std::env::set_var("RUST_LOG", "off");
    std::env::set_var("RUST_BACKTRACE", "0");
    if std::env::vars_os().any(|(k, _)| k.to_str().is_some_and(refused_variable)) {
        eprintln!("zk60 token wrap: RISC0_* and BONSAI_* runtime switches must be unset");
        std::process::exit(1);
    }
    if let Err(e) = run() {
        eprintln!("zk60 token wrap: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static NEXT: AtomicUsize = AtomicUsize::new(0);

    struct Temp(std::path::PathBuf);
    impl Temp {
        fn new() -> Self {
            let p = std::env::temp_dir().join(format!(
                "zk60-token-wrap-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            DirBuilder::new().mode(0o700).create(&p).unwrap();
            Self(p)
        }
        fn path(&self, name: &str) -> String {
            self.0.join(name).to_str().unwrap().to_owned()
        }
    }
    impl Drop for Temp {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
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
    fn fake() -> Receipt {
        let claim = risc0_zkvm::ReceiptClaim::ok(PRIVATE_TOKEN_ID, policy().encode().to_vec());
        Receipt::new(
            InnerReceipt::Fake(risc0_zkvm::FakeReceipt::new(claim)),
            policy().encode().to_vec(),
        )
    }

    #[test]
    fn fake_and_empty_outer_seals_cannot_assert_an_authentic_claim() {
        let policy = policy();
        let claim = risc0_zkvm::ReceiptClaim::ok(PRIVATE_TOKEN_ID, policy.encode().to_vec());
        assert!(verify(&fake(), &policy).is_err());
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
        let mut extra = bytes.clone();
        extra.push(0);
        assert!(codec().deserialize::<Receipt>(&extra).is_err());
        let t = Temp::new();
        write_new(t.path("forged"), &bytes, 0o644).unwrap();
        assert!(verify_saved(&policy, t.path("forged")).is_err());
    }

    #[test]
    fn wrap_refuses_before_creating_work_or_output() {
        let t = Temp::new();
        fs::create_dir(t.path("public")).unwrap();
        DirBuilder::new().mode(0o700).create(t.path("private")).unwrap();
        write_new(t.path("public/policy.bin"), &policy().encode(), 0o644).unwrap();
        let fake_bytes = codec().serialize(&fake()).unwrap();
        write_new(t.path("private/inner.bin"), &fake_bytes, 0o600).unwrap();
        write_new(t.path("private/shared.bin"), &fake_bytes, 0o644).unwrap();
        write_new(t.path("public/inner.bin"), &fake_bytes, 0o600).unwrap();
        std::os::unix::fs::symlink(t.path("private/inner.bin"), t.path("private/link.bin")).unwrap();
        let (pol, out, work, r0vm) = (
            t.path("public/policy.bin"),
            t.path("public/receipt.bin"),
            t.path("work"),
            t.path("no-such-r0vm"),
        );
        let refusal = |inner: &str, r0vm: &str| {
            wrap(&pol, &t.path(inner), &out, &t.path("tools"), &work, r0vm)
                .unwrap_err()
                .to_string()
        };
        assert_eq!(refusal("private/inner.bin", "r0vm"), "explicit absolute r0vm path required");
        assert_eq!(refusal("private/shared.bin", &r0vm), "inner receipt must be a saved owner-only regular file");
        assert_eq!(refusal("private/link.bin", &r0vm), "inner receipt must be a saved owner-only regular file");
        assert_eq!(refusal("public/inner.bin", &r0vm), "inner receipt must stay outside the public artifact directory");
        // A fake inner receipt with the genuine claim and policy is not an input.
        assert_eq!(refusal("private/inner.bin", &r0vm), "real succinct input required");
        write_new(&out, b"kept", 0o644).unwrap();
        assert_eq!(refusal("private/inner.bin", &r0vm), "output already exists");
        assert_eq!(fs::read(&out).unwrap(), b"kept");
        assert!(!t.0.join("work").exists());
    }

    #[test]
    fn image_id_and_environment_checks_are_exact() {
        let id = risc0_zkvm::sha::Digest::from(PRIVATE_TOKEN_ID).to_string();
        assert_eq!(id.len(), 64);
        check_image(&id).unwrap();
        assert!(check_image(&id[..63]).is_err());
        assert!(check_image(&format!("{id}0")).is_err());
        assert!(check_image(&"0".repeat(64)).is_err());
        for name in ["RISC0_DEV_MODE", "RISC0_PROVER", "RISC0_PPROF_OUT", "RISC0_UNKNOWN", "RISC0_DEV_MODE2", "BONSAI_API_KEY", "BONSAI_API_URL"] {
            assert!(refused_variable(name));
        }
        for name in ["RUST_LOG", "PATH", "HOME"] {
            assert!(!refused_variable(name));
        }
    }
}
