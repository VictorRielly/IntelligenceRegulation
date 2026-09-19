//! Experimental local complete-block receipt CLI. Not model-scale MVP acceptance.
use bincode::Options;
use risc0_zkvm::{
    Executor, ExecutorEnv, ExternalProver, InnerReceipt, Prover, ProverOpts, Receipt,
    VerifierContext,
};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::{
    fs::{self, DirBuilder, File, OpenOptions},
    io::{Read, Write},
    path::Path,
};
use zk60_block_methods::{PRIVATE_BLOCK_ELF, PRIVATE_BLOCK_ID};
use zk60_block_model::{Model, Request, MODEL_BYTES, REQUEST_BYTES};
use zk60_block_statement::{Statement, ELEMENTS, JOURNAL_BYTES};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const MAX_RECEIPT: u64 = 16 * 1024 * 1024;
// The executor's segment size. Reported with the executor-only cycle counts so
// a constant-cycle record states the shape it was measured under.
const SEGMENT_LIMIT_PO2: u32 = 18;
fn codec() -> impl Options {
    bincode::DefaultOptions::new()
        .with_fixint_encoding()
        .with_limit(MAX_RECEIPT)
        .reject_trailing_bytes()
}
fn read_bounded(path: &str, max: usize) -> Result<Vec<u8>> {
    let f = File::open(path)?;
    if !f.metadata()?.is_file() || f.metadata()?.len() > max as u64 {
        return Err("file size/type refused".into());
    }
    let mut bytes = Vec::new();
    f.take(max as u64 + 1).read_to_end(&mut bytes)?;
    if bytes.len() > max {
        return Err("file size refused".into());
    }
    Ok(bytes)
}
fn write_new(path: impl AsRef<Path>, bytes: &[u8], private: bool) -> Result<()> {
    let mut f = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(if private { 0o600 } else { 0o644 })
        .open(path)?;
    f.write_all(bytes)?;
    f.sync_all()?;
    Ok(())
}
fn real_verify(receipt: &Receipt, policy: &Statement) -> Result<()> {
    // Fail closed on fake, composite (execution-length leakage), Groth16 and
    // future unknown variants, before consulting any environment-controlled code.
    if !matches!(receipt.inner, InnerReceipt::Succinct(_)) {
        return Err("only real succinct STARK receipts accepted".into());
    }
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_BLOCK_ID,
    )?;
    Ok(())
}
fn new_directory_path(path: &str) -> Result<std::path::PathBuf> {
    let path = std::path::absolute(path)?;
    let parent = path
        .parent()
        .ok_or("output directory needs a parent")?
        .canonicalize()?;
    Ok(parent.join(path.file_name().ok_or("output directory name required")?))
}
fn prepare(
    model_path: &str,
    public_dir: &str,
    private_dir: &str,
    input_path: Option<&str>,
) -> Result<()> {
    let model_bytes = read_bounded(model_path, MODEL_BYTES)?;
    let model = Model::decode(&model_bytes)?;
    // Both destinations must be new, disjoint directories. Never place local
    // secret artifacts below a directory intended for publication.
    let public = new_directory_path(public_dir)?;
    let private = new_directory_path(private_dir)?;
    if public.exists()
        || private.exists()
        || public.starts_with(&private)
        || private.starts_with(&public)
    {
        return Err("output directories must be new and disjoint".into());
    }
    let mut random = [0u8; 32 * 3 + ELEMENTS];
    File::open("/dev/urandom")?.read_exact(&mut random)?;
    let mut input = [0i16; ELEMENTS];
    if let Some(path) = input_path {
        let bytes = read_bounded(path, ELEMENTS * 2)?;
        if bytes.len() != ELEMENTS * 2 {
            return Err("input must contain exactly 512 little-endian i16 words".into());
        }
        for (v, b) in input.iter_mut().zip(bytes.chunks_exact(2)) {
            *v = i16::from_le_bytes(b.try_into().unwrap());
        }
    } else {
        for (v, b) in input.iter_mut().zip(&random[96..]) {
            *v = i16::from(b % 7) - 3;
        }
    }
    let request = Request {
        context: random[..32].try_into().unwrap(),
        input_salt: random[32..64].try_into().unwrap(),
        output_salt: random[64..96].try_into().unwrap(),
        input,
    };
    let (policy, output) = request.compute(&model)?;
    // No witness serialization enters the public directory or stdout.
    DirBuilder::new().mode(0o700).create(&private)?;
    fs::create_dir(&public)?;
    write_new(private.join("request.bin"), &request.encode(), true)?;
    write_new(
        private.join("output.i16"),
        &output
            .iter()
            .flat_map(|x| x.to_le_bytes())
            .collect::<Vec<_>>(),
        true,
    )?;
    write_new(public.join("policy.bin"), &policy.encode(), false)?;
    write_new(public.join("model.bin"), &model_bytes, false)?;
    println!("{{\"prepared\":true,\"coverage\":\"one-fixed-T32-block\",\"mvp_complete\":false}}");
    Ok(())
}
fn prove(
    model_path: &str,
    request_path: &str,
    policy_path: &str,
    receipt_path: &str,
    r0vm: &str,
    execute: bool,
) -> Result<()> {
    if Path::new(receipt_path).exists() {
        return Err("receipt output already exists".into());
    }
    let model_bytes = read_bounded(model_path, MODEL_BYTES)?;
    let request_bytes = read_bounded(request_path, REQUEST_BYTES)?;
    let policy_bytes = read_bounded(policy_path, JOURNAL_BYTES)?;
    let policy = Statement::decode(&policy_bytes)?;
    let model = Model::decode(&model_bytes)?;
    let request = Request::decode(&request_bytes)?;
    let (actual, _) = request.compute(&model)?;
    policy.check_journal(&actual.encode())?;
    let env = ExecutorEnv::builder()
        .write_slice(&model_bytes)
        .write_slice(&request_bytes)
        .write_slice(&policy_bytes)
        .segment_limit_po2(SEGMENT_LIMIT_PO2)
        .session_limit(Some(64 * 1024 * 1024))
        .build()?;
    let prover = ExternalProver::new("explicit-local-r0vm", r0vm);
    if execute {
        let session = prover.execute(env, PRIVATE_BLOCK_ELF)?;
        policy.check_journal(&session.journal.bytes)?;
        // Execution shape only: `SessionInfo` carries one `SegmentInfo` per
        // segment, whose `cycles` is the unpadded user count and whose `po2`
        // is the proof-system size, so the prover-side total is the sum of
        // 2^po2. These are counts, never witness values; a P3 constant-cycle
        // gate compares them across hostile inputs.
        let user_cycles = session.cycles();
        let mut total_cycles: u64 = 0;
        for segment in &session.segments {
            let padded = 1u64
                .checked_shl(segment.po2)
                .ok_or("segment po2 out of range")?;
            total_cycles = total_cycles
                .checked_add(padded)
                .ok_or("segment cycle total out of range")?;
        }
        println!(
            "{{\"execution_matches_policy\":true,\"proof_created\":false,\"total_cycles\":{},\"user_cycles\":{},\"segments\":{},\"segment_limit_po2\":{},\"mvp_complete\":false}}",
            total_cycles,
            user_cycles,
            session.segments.len(),
            SEGMENT_LIMIT_PO2
        );
        return Ok(());
    }
    let opts = ProverOpts::succinct().with_dev_mode(false);
    let ctx = VerifierContext::default().with_dev_mode(false);
    let proved = prover.prove_with_ctx(env, &ctx, PRIVATE_BLOCK_ELF, &opts)?;
    real_verify(&proved.receipt, &policy)?;
    let bytes = codec().serialize(&proved.receipt)?;
    // This is a witness to the outer proof, not the public Groth16 artifact.
    write_new(receipt_path, &bytes, true)?;
    println!("{{\"saved_receipt\":true,\"receipt_bytes\":{},\"kind\":\"succinct\",\"mvp_complete\":false}}",bytes.len());
    Ok(())
}
fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("prepare") if args.len()==5=>prepare(&args[2],&args[3],&args[4],None),
        Some("prepare-input") if args.len()==6=>prepare(&args[2],&args[4],&args[5],Some(&args[3])),
        Some("prove"|"execute") if args.len()==7=>prove(&args[2],&args[3],&args[4],&args[5],&args[6],args[1]=="execute"),
        Some("verify") if args.len()==4=>{
            let policy=Statement::decode(&read_bounded(&args[2],JOURNAL_BYTES)?)?;
            let receipt:Receipt=codec().deserialize(&read_bounded(&args[3],MAX_RECEIPT as usize)?)?;
            real_verify(&receipt,&policy)?;
            println!("{{\"verified\":true,\"coverage\":\"one-fixed-T32-block\",\"mvp_complete\":false}}");Ok(())
        },
        Some("image-id") if args.len()==2=>{println!("{}",risc0_zkvm::sha::Digest::from(PRIVATE_BLOCK_ID));Ok(())},
        _=>Err("usage: prepare MODEL PUBLIC_DIR PRIVATE_DIR | prepare-input MODEL INPUT_I16 PUBLIC_DIR PRIVATE_DIR | prove/execute MODEL REQUEST POLICY RECEIPT R0VM | verify POLICY RECEIPT | image-id".into())
    }
}
// Refuse inherited profiler, remote, fake-proof and unreviewed runtime switches.
fn refused_variable(name: &str) -> bool {
    name.starts_with("RISC0_") || name.starts_with("BONSAI_")
}
// Named switches that select a prover, enable dev/fake mode, redirect work
// directories or turn on logging. Every one is already covered by the prefix
// rule below; the list records exactly what the scrub is meant to defeat.
const SCRUBBED_NAMES: [&str; 7] = [
    "RISC0_DEV_MODE",
    "RISC0_PROVER",
    "RISC0_WORK_DIR",
    "BONSAI_API_URL",
    "BONSAI_API_KEY",
    "RISC0_INFO",
    "RISC0_PPROF_OUT",
];
fn scrubbed_variable(name: &str) -> bool {
    refused_variable(name) || name.starts_with("RUST_LOG") || SCRUBBED_NAMES.contains(&name)
}
/// Remove every prover-selection, dev-mode and logging switch from this
/// process' environment, so the binary is safe when run by hand and not only
/// under the maintained runner. Returns the removed NAMES; values are never
/// returned, logged or printed.
fn scrub_environment() -> Vec<String> {
    let mut removed = Vec::new();
    // `vars_os` is a snapshot, so removing during the walk is well defined.
    for (key, _) in std::env::vars_os() {
        let name = key.to_string_lossy().into_owned();
        if scrubbed_variable(&name) {
            std::env::remove_var(&key);
            removed.push(name);
        }
    }
    removed
}
fn main() {
    // Do this before the prover starts any threads. Upstream r0vm inherits
    // the environment and its debug logs can include private proof internals.
    // The maintained runner also scrubs the child environment; the binary
    // scrubs its own so that a hand run is equally safe. Nothing is printed:
    // the removed names are a return value for tests, not output.
    // Prover-selection and dev-mode switches are refused loudly BEFORE any
    // scrub: an operator who set RISC0_DEV_MODE or BONSAI_* by hand must learn
    // it rather than have it silently discarded. Only then does the scrub run,
    // which removes the logging switches (RUST_LOG*) that could carry prover
    // internals into a hand run's terminal.
    if std::env::vars_os().any(|(k, _)| refused_variable(&k.to_string_lossy())) {
        eprintln!("zk60 block: RISC0_* and BONSAI_* runtime switches must be unset");
        std::process::exit(1);
    }
    let _removed = scrub_environment();
    std::env::set_var("RUST_LOG", "off");
    std::env::set_var("RUST_BACKTRACE", "0");
    if let Err(err) = run() {
        eprintln!("zk60 block: {err}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Mutex;
    static NEXT: AtomicUsize = AtomicUsize::new(0);
    // Tests run in threads of one process; the environment is process-global.
    // Every test that reads or writes it takes this lock first.
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct Temp(std::path::PathBuf);
    impl Temp {
        fn new() -> Self {
            let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
            let p = std::env::temp_dir().join(format!(
                "zk60-host-test-{}-{}",
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
    // An intentionally simple PUBLIC structural model. All projections are
    // zero so both residual paths preserve the owner's input exactly. It is
    // a test of host framing/privacy, not an oracle or model-quality fixture.
    fn identity_model() -> Vec<u8> {
        let mut b = vec![0; MODEL_BYTES];
        b[..8].copy_from_slice(&zk60_block_model::MODEL_MAGIC);
        for chunk in b[1576..2600].chunks_exact_mut(8) {
            chunk.copy_from_slice(&128i64.to_le_bytes());
        }
        for chunk in b[3624..5672].chunks_exact_mut(8) {
            chunk.copy_from_slice(&512i64.to_le_bytes());
        }
        Model::decode(&b).unwrap();
        b
    }

    #[test]
    fn owner_input_is_bound_and_secrets_stay_in_private_directory() {
        let t = Temp::new();
        let model = identity_model();
        let input: Vec<u8> = (0..ELEMENTS)
            .flat_map(|i| ((i % 7) as i16 - 3).to_le_bytes())
            .collect();
        fs::write(t.path("model"), &model).unwrap();
        fs::write(t.path("input"), &input).unwrap();
        prepare(
            &t.path("model"),
            &t.path("public"),
            &t.path("private"),
            Some(&t.path("input")),
        )
        .unwrap();
        let public = t.0.join("public");
        let private = t.0.join("private");
        let mut names: Vec<_> = fs::read_dir(&public)
            .unwrap()
            .map(|e| e.unwrap().file_name())
            .collect();
        names.sort();
        assert_eq!(
            names,
            vec![
                std::ffi::OsString::from("model.bin"),
                std::ffi::OsString::from("policy.bin")
            ]
        );
        assert_eq!(
            fs::metadata(&private).unwrap().permissions().mode() & 0o777,
            0o700
        );
        for name in ["request.bin", "output.i16"] {
            assert_eq!(
                fs::metadata(private.join(name))
                    .unwrap()
                    .permissions()
                    .mode()
                    & 0o777,
                0o600
            );
        }
        assert_eq!(fs::read(private.join("output.i16")).unwrap(), input);
        let request = Request::decode(&fs::read(private.join("request.bin")).unwrap()).unwrap();
        let (policy, _) = request.compute(&Model::decode(&model).unwrap()).unwrap();
        assert_eq!(
            fs::read(public.join("policy.bin")).unwrap(),
            policy.encode()
        );
        assert!(prepare(
            &t.path("model"),
            &t.path("public"),
            &t.path("private"),
            None
        )
        .is_err());
    }

    #[test]
    fn invalid_owner_input_and_aliases_leave_no_output() {
        let t = Temp::new();
        fs::write(t.path("model"), identity_model()).unwrap();
        for size in [0, ELEMENTS * 2 - 1, ELEMENTS * 2 + 1] {
            fs::write(t.path("bad"), vec![0; size]).unwrap();
            assert!(prepare(
                &t.path("model"),
                &t.path("public"),
                &t.path("private"),
                Some(&t.path("bad"))
            )
            .is_err());
            assert!(!t.0.join("public").exists());
            assert!(!t.0.join("private").exists());
        }
        fs::create_dir(t.path("parent")).unwrap();
        std::os::unix::fs::symlink(t.0.join("parent"), t.path("alias")).unwrap();
        assert!(prepare(
            &t.path("model"),
            &t.path("parent/same"),
            &t.path("alias/same"),
            None
        )
        .is_err());
        assert!(!t.0.join("parent/same").exists());
        assert!(prepare(
            &t.path("model"),
            &t.path("parent/../same"),
            &t.path("same"),
            None
        )
        .is_err());
        assert!(!t.0.join("same").exists());
    }

    #[test]
    fn private_artifact_cannot_overwrite_or_follow_a_symlink() {
        let t = Temp::new();
        write_new(t.path("inner"), b"private", true).unwrap();
        assert_eq!(
            fs::metadata(t.path("inner")).unwrap().permissions().mode() & 0o777,
            0o600
        );
        assert!(write_new(t.path("inner"), b"overwrite", true).is_err());
        std::os::unix::fs::symlink(t.path("inner"), t.path("alias")).unwrap();
        assert!(write_new(t.path("alias"), b"overwrite", true).is_err());
        assert_eq!(fs::read(t.path("inner")).unwrap(), b"private");
    }
    #[test]
    fn scrub_removes_prover_and_logging_switches_only() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        // Start from a clean slate so the assertion is exact whatever the
        // caller's shell had set.
        scrub_environment();
        std::env::set_var("RISC0_DEV_MODE", "1");
        std::env::set_var("BONSAI_API_KEY", "x");
        std::env::set_var("RUST_LOG_STYLE", "always");
        std::env::set_var("ZK60_KEEP_ME", "1");
        let mut removed = scrub_environment();
        removed.sort();
        assert_eq!(
            removed,
            vec![
                "BONSAI_API_KEY".to_string(),
                "RISC0_DEV_MODE".to_string(),
                "RUST_LOG_STYLE".to_string()
            ]
        );
        for name in ["RISC0_DEV_MODE", "BONSAI_API_KEY", "RUST_LOG_STYLE"] {
            assert!(std::env::var_os(name).is_none(), "{name} survived the scrub");
        }
        assert_eq!(std::env::var("ZK60_KEEP_ME").unwrap(), "1");
        std::env::remove_var("ZK60_KEEP_ME");
        assert!(scrub_environment().is_empty());
    }
    #[test]
    fn fake_receipt_is_rejected_even_with_genuine_claim() {
        let p = Statement {
            context: [1; 32],
            model: [2; 32],
            input: [3; 32],
            output: [4; 32],
        };
        let claim = risc0_zkvm::ReceiptClaim::ok(PRIVATE_BLOCK_ID, p.encode().to_vec());
        let receipt = Receipt::new(
            InnerReceipt::Fake(risc0_zkvm::FakeReceipt::new(claim)),
            p.encode().to_vec(),
        );
        assert!(real_verify(&receipt, &p).is_err());
    }
}

#[test]
fn refuses_profiler_and_unreviewed_runtime_switches() {
    for name in ["RISC0_PPROF_OUT", "RISC0_DEV_MODE", "RISC0_UNKNOWN", "BONSAI_API_KEY"] { assert!(refused_variable(name)); }
    for name in ["PATH", "RUST_LOG"] { assert!(!refused_variable(name)); }
    // The scrub covers the refused set plus every logging switch.
    for name in SCRUBBED_NAMES { assert!(scrubbed_variable(name)); }
    for name in ["RUST_LOG", "RUST_LOG_STYLE", "RISC0_UNKNOWN", "BONSAI_UNKNOWN"] { assert!(scrubbed_variable(name)); }
    for name in ["PATH", "HOME", "ZK60_KEEP_ME", "RUSTUP_TOOLCHAIN"] { assert!(!scrubbed_variable(name)); }
}
