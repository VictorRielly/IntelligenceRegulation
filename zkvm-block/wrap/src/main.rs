//! Local native Groth16 wrapping for the fixed complete-block experiment.
//! Intermediate seals and witness files belong in the caller's private work dir.
use bincode::Options;
use risc0_zkvm::{
    sha::Digestible, ApiClient, AssetRequest, Groth16Receipt, Groth16ReceiptVerifierParameters,
    InnerReceipt, ProverOpts, Receipt, VerifierContext,
};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::{
    fs::{DirBuilder, File, OpenOptions},
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
    let policy = Statement::decode(&read(policy_path, JOURNAL_BYTES as u64)?)?;
    let receipt: Receipt = codec().deserialize(&read(inner_path, LIMIT)?)?;
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_BLOCK_ID,
    )?;
    let succinct = match &receipt.inner {
        InnerReceipt::Succinct(s) => s,
        _ => return Err("real succinct input required".into()),
    };
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
    let groth = Groth16Receipt::new(
        seal.to_vec(),
        succinct.claim.clone(),
        Groth16ReceiptVerifierParameters::default().digest(),
    );
    let receipt = Receipt::new(InnerReceipt::Groth16(groth), receipt.journal.bytes);
    verify(&receipt, &policy)?;
    let bytes = codec().serialize(&receipt)?;
    write_new(output_path, &bytes, 0o644)?;
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
        Some("verify") if a.len()==4=>{
            let policy=Statement::decode(&read(&a[2],JOURNAL_BYTES as u64)?)?;
            let receipt=codec().deserialize(&read(&a[3],LIMIT)?)?;verify(&receipt,&policy)?;
            println!("{{\"verified\":true,\"kind\":\"groth16\",\"coverage\":\"one-fixed-T32-block\",\"mvp_complete\":false}}");Ok(())
        },
        Some("image-id") if a.len()==2=>{println!("{}",risc0_zkvm::sha::Digest::from(PRIVATE_BLOCK_ID));Ok(())},
        _=>Err("usage: wrap POLICY INNER_RECEIPT OUTPUT_RECEIPT NATIVE_TOOLS PRIVATE_WORK R0VM | verify POLICY RECEIPT | image-id".into())
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

    #[test]
    fn fake_and_empty_outer_seals_cannot_assert_an_authentic_claim() {
        let policy = Statement {
            context: [1; 32],
            model: [2; 32],
            input: [3; 32],
            output: [4; 32],
        };
        let claim = risc0_zkvm::ReceiptClaim::ok(PRIVATE_BLOCK_ID, policy.encode().to_vec());
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
}

#[test]
fn refuses_profiler_and_unreviewed_runtime_switches() {
    for name in ["RISC0_PPROF_OUT", "RISC0_DEV_MODE", "RISC0_UNKNOWN", "BONSAI_API_KEY"] { assert!(refused_variable(name)); }
    for name in ["PATH", "RUST_LOG"] { assert!(!refused_variable(name)); }
}
