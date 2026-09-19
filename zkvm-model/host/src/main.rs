//! Experimental local token-model receipt CLI (profile zk60-r0-token-v1).
//! Synthetic functional intermediate; not the model-scale MVP or a trained model.
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
use zk60_token_methods::{PRIVATE_TOKEN_ELF, PRIVATE_TOKEN_ID};
use zk60_token_model::{tokens_from_bytes, Model, Request, INPUT_BYTES, MODEL_BYTES, REQUEST_BYTES};
use zk60_token_statement::{Statement, JOURNAL_BYTES};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const MAX_RECEIPT: u64 = 16 * 1024 * 1024;
const COVERAGE: &str = "synthetic-T32-V32-two-block-greedy-token";
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
fn real_verify(receipt: &Receipt, policy: &Statement) -> Result<()> {
    // Fail closed on fake, composite (execution-length leakage), Groth16 and
    // future unknown variants, before consulting any environment-controlled code.
    if !matches!(receipt.inner, InnerReceipt::Succinct(_)) {
        return Err("only real succinct STARK receipts accepted".into());
    }
    policy.check_journal(&receipt.journal.bytes)?;
    receipt.verify_with_context(
        &VerifierContext::default().with_dev_mode(false),
        PRIVATE_TOKEN_ID,
    )?;
    Ok(())
}
/// Verifies the exact saved bytes: strict bounded decoding, no trailing data.
fn verify_saved(policy: &Statement, receipt_path: &str) -> Result<Vec<u8>> {
    let bytes = read_bounded(receipt_path, MAX_RECEIPT as usize)?;
    let receipt: Receipt = codec().deserialize(&bytes)?;
    real_verify(&receipt, policy)?;
    Ok(bytes)
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
    // One OS draw; context, input salt and output salt are disjoint slices.
    let mut random = [0u8; 32 * 3 + INPUT_BYTES / 4];
    File::open("/dev/urandom")?.read_exact(&mut random)?;
    let tokens = if let Some(path) = input_path {
        tokens_from_bytes(&read_bounded(path, INPUT_BYTES)?)?
    } else {
        // 256 is a multiple of the vocabulary, so the IDs 0..31 are uniform.
        let mut tokens = [0u32; INPUT_BYTES / 4];
        for (t, b) in tokens.iter_mut().zip(&random[96..]) {
            *t = u32::from(b % 32);
        }
        tokens
    };
    let request = Request {
        context: random[..32].try_into().unwrap(),
        input_salt: random[32..64].try_into().unwrap(),
        output_salt: random[64..96].try_into().unwrap(),
        tokens,
    };
    let (policy, token) = request.compute(&model)?;
    // No token, salt or witness serialization enters the public directory or stdout.
    DirBuilder::new().mode(0o700).create(&private)?;
    fs::create_dir(&public)?;
    write_new(private.join("request.bin"), &request.encode(), true)?;
    write_new(private.join("output.u32"), &token.to_le_bytes(), true)?;
    write_new(public.join("policy.bin"), &policy.encode(), false)?;
    write_new(public.join("model.bin"), &model_bytes, false)?;
    println!("{{\"prepared\":true,\"coverage\":\"{COVERAGE}\",\"mvp_complete\":false}}");
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
    if !Path::new(r0vm).is_absolute() {
        return Err("explicit absolute r0vm path required".into());
    }
    let model_bytes = read_bounded(model_path, MODEL_BYTES)?;
    let request_bytes = read_bounded(request_path, REQUEST_BYTES)?;
    let policy_bytes = read_bounded(policy_path, JOURNAL_BYTES)?;
    // The fixed policy exists before any proof. Repeated proofs reuse the
    // same request and policy; each needs a new receipt path.
    let policy = Statement::decode(&policy_bytes)?;
    let model = Model::decode(&model_bytes)?;
    let request = Request::decode(&request_bytes)?;
    let (actual, _) = request.compute(&model)?;
    policy.check_journal(&actual.encode())?;
    let env = ExecutorEnv::builder()
        .write_slice(&model_bytes)
        .write_slice(&request_bytes)
        .write_slice(&policy_bytes)
        .segment_limit_po2(18)
        .session_limit(Some(64 * 1024 * 1024))
        .build()?;
    let prover = ExternalProver::new("explicit-local-r0vm", r0vm);
    if execute {
        let session = prover.execute(env, PRIVATE_TOKEN_ELF)?;
        policy.check_journal(&session.journal.bytes)?;
        println!(
            "{{\"execution_matches_policy\":true,\"proof_created\":false,\"mvp_complete\":false}}"
        );
        return Ok(());
    }
    let opts = ProverOpts::succinct().with_dev_mode(false);
    let ctx = VerifierContext::default().with_dev_mode(false);
    let proved = prover.prove_with_ctx(env, &ctx, PRIVATE_TOKEN_ELF, &opts)?;
    real_verify(&proved.receipt, &policy)?;
    let bytes = codec().serialize(&proved.receipt)?;
    // This is a witness to the outer proof, not the public Groth16 artifact.
    write_new(receipt_path, &bytes, true)?;
    if verify_saved(&policy, receipt_path)? != bytes {
        return Err("saved receipt differs from verified receipt".into());
    }
    println!("{{\"saved_receipt\":true,\"receipt_bytes\":{},\"kind\":\"succinct\",\"mvp_complete\":false}}",bytes.len());
    Ok(())
}
fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("prepare") if args.len()==5=>prepare(&args[2],&args[3],&args[4],None),
        Some("prepare-input") if args.len()==6=>prepare(&args[2],&args[4],&args[5],Some(&args[3])),
        Some("prove"|"execute") if args.len()==7=>prove(&args[2],&args[3],&args[4],&args[5],&args[6],args[1]=="execute"),
        Some("verify") if args.len()==5=>{
            check_image(&args[4])?;
            let policy=Statement::decode(&read_bounded(&args[2],JOURNAL_BYTES)?)?;
            verify_saved(&policy,&args[3])?;
            println!("{{\"verified\":true,\"kind\":\"succinct\",\"coverage\":\"{COVERAGE}\",\"mvp_complete\":false}}");Ok(())
        },
        Some("image-id") if args.len()==2=>{println!("{}",risc0_zkvm::sha::Digest::from(PRIVATE_TOKEN_ID));Ok(())},
        _=>Err("usage: prepare MODEL PUBLIC_DIR PRIVATE_DIR | prepare-input MODEL INPUT_U32 PUBLIC_DIR PRIVATE_DIR | prove/execute MODEL REQUEST POLICY RECEIPT R0VM | verify POLICY RECEIPT IMAGE_ID_HEX | image-id".into())
    }
}
fn main() {
    // Do this before the prover starts any threads. Upstream r0vm inherits
    // the environment and its debug logs can include private proof internals.
    // The maintained runner also captures all child output in private logs.
    std::env::set_var("RUST_LOG", "off");
    std::env::set_var("RUST_BACKTRACE", "0");
    if std::env::vars_os().any(|(k, _)| k.to_str().is_some_and(refused_variable)) {
        eprintln!("zk60 token: RISC0_* and BONSAI_* runtime switches must be unset");
        std::process::exit(1);
    }
    if let Err(err) = run() {
        eprintln!("zk60 token: {err}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use private_model_kernel::{next_token, synthetic::{synthetic_model, synthetic_raw_model}};
    use std::os::unix::fs::PermissionsExt;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static NEXT: AtomicUsize = AtomicUsize::new(0);

    struct Temp(std::path::PathBuf);
    impl Temp {
        fn new() -> Self {
            let p = std::env::temp_dir().join(format!(
                "zk60-token-host-test-{}-{}",
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
    // SYNTHETIC-ONLY public words (not trained; their noncanonical lookup
    // tables are not a registered calibration). A test of host
    // framing/privacy, not an oracle or model-quality fixture.
    fn synthetic_bytes() -> Vec<u8> {
        zk60_token_model::encode_raw(&synthetic_raw_model())
    }
    fn mode(path: impl AsRef<Path>) -> u32 {
        fs::metadata(path).unwrap().permissions().mode() & 0o777
    }
    fn names(dir: &Path) -> Vec<String> {
        let mut names: Vec<_> = fs::read_dir(dir)
            .unwrap()
            .map(|e| e.unwrap().file_name().into_string().unwrap())
            .collect();
        names.sort();
        names
    }

    #[test]
    fn owner_input_is_bound_and_secrets_stay_in_private_directory() {
        let t = Temp::new();
        let model = synthetic_bytes();
        let tokens: [u32; 32] = core::array::from_fn(|i| (i as u32 * 11 + 5) % 32);
        let input: Vec<u8> = tokens.iter().flat_map(|t| t.to_le_bytes()).collect();
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
        assert_eq!(names(&public), ["model.bin", "policy.bin"]);
        assert_eq!(names(&private), ["output.u32", "request.bin"]);
        assert_eq!(mode(&private), 0o700);
        for name in ["request.bin", "output.u32"] {
            assert_eq!(mode(private.join(name)), 0o600);
        }
        assert_eq!(fs::read(public.join("model.bin")).unwrap(), model);
        let expected = next_token(&tokens, &synthetic_model().unwrap()).unwrap();
        assert_eq!(
            fs::read(private.join("output.u32")).unwrap(),
            expected.to_le_bytes()
        );
        let request_bytes = fs::read(private.join("request.bin")).unwrap();
        assert_eq!(request_bytes.len(), 240);
        assert_eq!(request_bytes[112..], input[..]);
        let request = Request::decode(&request_bytes).unwrap();
        assert_ne!(request.input_salt, request.output_salt);
        assert_ne!(request.context, request.input_salt);
        let (policy, token) = request.compute(&Model::decode(&model).unwrap()).unwrap();
        assert_eq!(token, expected);
        let policy_bytes = fs::read(public.join("policy.bin")).unwrap();
        assert_eq!(policy_bytes.len(), 144);
        assert_eq!(policy_bytes, policy.encode());
        // The public directory holds no salt and no raw input.
        for secret in [&request.input_salt[..], &request.output_salt[..], &input[..]] {
            for name in ["model.bin", "policy.bin"] {
                let bytes = fs::read(public.join(name)).unwrap();
                assert!(!bytes.windows(secret.len()).any(|w| w == secret));
            }
        }
        assert!(prepare(
            &t.path("model"),
            &t.path("public"),
            &t.path("private"),
            None
        )
        .is_err());
    }

    #[test]
    fn fresh_requests_use_valid_tokens_and_independent_salts() {
        let t = Temp::new();
        fs::write(t.path("model"), synthetic_bytes()).unwrap();
        let mut seen = Vec::new();
        for n in 0..3 {
            prepare(
                &t.path("model"),
                &t.path(&format!("public{n}")),
                &t.path(&format!("private{n}")),
                None,
            )
            .unwrap();
            let r = Request::decode(&fs::read(t.0.join(format!("private{n}/request.bin"))).unwrap())
                .unwrap();
            assert!(r.tokens.iter().all(|t| *t < 32));
            seen.extend([r.context, r.input_salt, r.output_salt]);
        }
        for (i, a) in seen.iter().enumerate() {
            assert!(seen[i + 1..].iter().all(|b| a != b));
        }
    }

    #[test]
    fn invalid_owner_input_and_aliases_leave_no_output() {
        let t = Temp::new();
        fs::write(t.path("model"), synthetic_bytes()).unwrap();
        let mut invalid = vec![vec![0; 0], vec![0; INPUT_BYTES - 1], vec![0; INPUT_BYTES + 1]];
        for (at, value) in [(0, 32u8), (124, 32), (61, 1), (127, 0x80)] {
            let mut bad = vec![0; INPUT_BYTES];
            bad[at] = value;
            invalid.push(bad);
        }
        for bad in invalid {
            fs::write(t.path("bad"), bad).unwrap();
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
        // A legacy block model file is not a token model.
        fs::write(t.path("block"), &synthetic_bytes()[1032..7216]).unwrap();
        assert!(prepare(&t.path("block"), &t.path("public"), &t.path("private"), None).is_err());
        assert!(!t.0.join("public").exists());
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
        assert!(prepare(
            &t.path("model"),
            &t.path("outer"),
            &t.path("outer/private"),
            None
        )
        .is_err());
        assert!(!t.0.join("outer").exists());
    }

    #[test]
    fn private_artifact_cannot_overwrite_or_follow_a_symlink() {
        let t = Temp::new();
        write_new(t.path("inner"), b"private", true).unwrap();
        assert_eq!(mode(t.path("inner")), 0o600);
        assert!(write_new(t.path("inner"), b"overwrite", true).is_err());
        std::os::unix::fs::symlink(t.path("inner"), t.path("alias")).unwrap();
        assert!(write_new(t.path("alias"), b"overwrite", true).is_err());
        assert_eq!(fs::read(t.path("inner")).unwrap(), b"private");
    }

    #[test]
    fn prove_refuses_existing_receipt_relative_r0vm_and_mismatched_policy_before_any_prover() {
        let t = Temp::new();
        fs::write(t.path("model"), synthetic_bytes()).unwrap();
        prepare(&t.path("model"), &t.path("public"), &t.path("private"), None).unwrap();
        let (model, request, policy) = (
            t.path("public/model.bin"),
            t.path("private/request.bin"),
            t.path("public/policy.bin"),
        );
        // Every refusal below happens before the (nonexistent) r0vm is started.
        let missing = t.path("no-such-r0vm");
        write_new(t.path("existing"), b"kept", true).unwrap();
        assert!(prove(&model, &request, &policy, &t.path("existing"), &missing, false).is_err());
        assert_eq!(fs::read(t.path("existing")).unwrap(), b"kept");
        assert!(prove(&model, &request, &policy, &t.path("r1"), "r0vm", true).is_err());
        let mut wrong = fs::read(&policy).unwrap();
        for at in [16, 48, 80, 112, 143] {
            wrong[at] ^= 1;
            fs::write(t.path("wrong-policy"), &wrong).unwrap();
            wrong[at] ^= 1;
            let err = prove(&model, &request, &t.path("wrong-policy"), &t.path("r2"), &missing, true)
                .unwrap_err();
            assert_eq!(err.to_string(), "receipt differs from expected policy");
        }
        for (file, size) in [(&model, MODEL_BYTES), (&request, REQUEST_BYTES), (&policy, JOURNAL_BYTES)] {
            let mut long = fs::read(file).unwrap();
            assert_eq!(long.len(), size);
            long.push(0);
            fs::write(t.path("long"), &long).unwrap();
            let args: Vec<String> = [&model, &request, &policy]
                .iter()
                .map(|p| if *p == file { t.path("long") } else { (**p).clone() })
                .collect();
            assert!(prove(&args[0], &args[1], &args[2], &t.path("r3"), &missing, true).is_err());
        }
        assert!(!t.0.join("r1").exists() && !t.0.join("r2").exists() && !t.0.join("r3").exists());
    }

    #[test]
    fn fake_receipt_is_rejected_even_with_genuine_claim() {
        let p = Statement {
            context: [1; 32],
            model: [2; 32],
            input: [3; 32],
            output: [4; 32],
        };
        let claim = risc0_zkvm::ReceiptClaim::ok(PRIVATE_TOKEN_ID, p.encode().to_vec());
        let receipt = Receipt::new(
            InnerReceipt::Fake(risc0_zkvm::FakeReceipt::new(claim)),
            p.encode().to_vec(),
        );
        assert!(real_verify(&receipt, &p).is_err());
        // The same holds for the exact saved-file path, and for trailing bytes.
        let t = Temp::new();
        let bytes = codec().serialize(&receipt).unwrap();
        write_new(t.path("fake"), &bytes, true).unwrap();
        assert!(verify_saved(&p, &t.path("fake")).is_err());
        assert!(codec().deserialize::<Receipt>(&bytes).is_ok());
        assert!(codec().deserialize::<Receipt>(&bytes[..bytes.len() - 1]).is_err());
        let mut extra = bytes;
        extra.push(0);
        assert!(codec().deserialize::<Receipt>(&extra).is_err());
    }

    #[test]
    fn image_id_and_environment_checks_are_exact() {
        let id = risc0_zkvm::sha::Digest::from(PRIVATE_TOKEN_ID).to_string();
        assert_eq!(id.len(), 64);
        check_image(&id).unwrap();
        assert!(check_image(&id.to_uppercase()).is_err() || id == id.to_uppercase());
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
