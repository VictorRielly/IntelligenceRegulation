//! EXPERIMENTAL private attention (T32 / d16 / 2 heads / 1 KV head), prove in
//! one process and verify in a FRESH process from bytes only:
//!
//!   zk60_private_attention prove  <dir>   writes <dir>/attention_receipt.bin and
//!                                         <dir>/attention_expected.bin
//!   zk60_private_attention verify <dir>   reads both, rebuilds the public
//!                                         statement itself, accepts the frame
//!                                         and refuses three corrupted copies
//!
//! Every tensor here is the PUBLIC SYNTHETIC fixture; only the proof
//! randomness is secret. The verify command never builds a witness, never
//! calls the prover and never sees the input or the output. In this demo the
//! endpoint policy file is written by the proving process; in a deployment it
//! is the ENDPOINT OWNER's artifact and must reach the verifier independently
//! of the producer. Not an MVP, privacy-acceptance or speed claim: D8 / D11
//! stay open and shared-box timings are diagnostic only.
use hashline::private_attention::{
    compute_output, encoded_len, prepare_endpoints, prove_with_stats, schedule, verify_bytes, AttentionPublic, ExpectedIo, IoSpec, EXPECTED_BYTES, MAX_WIRE_BYTES,
};
use std::path::Path;

const RECEIPT: &str = "attention_receipt.bin";
const EXPECTED: &str = "attention_expected.bin";

fn read_bounded(path: &Path, max: usize) -> Result<Vec<u8>, String> {
    let len = std::fs::metadata(path).map_err(|e| format!("{}: {e}", path.display()))?.len();
    if len > max as u64 {
        return Err(format!("{}: larger than the {max}-byte bound", path.display()));
    }
    std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))
}

fn prove_cmd(dir: &Path) -> Result<(), String> {
    let (public, input) = AttentionPublic::synthetic_fixture();
    let context = *blake3::hash(b"zk60 private attention example: public synthetic request").as_bytes();
    let spec = IoSpec::new(context, -3, -3)?;
    // the endpoint owner's step: fix both private endpoints BEFORE proving
    let output = compute_output(&public, &input)?;
    let (expected, owners) = prepare_endpoints(spec, &input, &output)?;
    drop(output);
    let started = std::time::Instant::now();
    let (receipt, stats) = prove_with_stats(&public, &input, &expected, owners)?;
    let seconds = started.elapsed().as_secs_f64();
    let frame = receipt.to_bytes(&public, &expected)?;
    std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    std::fs::write(dir.join(RECEIPT), &frame).map_err(|e| e.to_string())?;
    std::fs::write(dir.join(EXPECTED), expected.to_bytes()).map_err(|e| e.to_string())?;
    println!("profile: {}", String::from_utf8_lossy(hashline::private_attention::PROFILE));
    for line in schedule().iter().take(4) {
        println!("  {line}");
    }
    println!("receipt frame: {} bytes (fixed by the geometry: {})", frame.len(), encoded_len());
    println!("committed rows: A {} H {} M {}; lookups: U8 {} exp {}", stats.a_rows, stats.h_rows, stats.m_rows, stats.u8_lookups, stats.exp_lookups);
    println!("prove {seconds:.3} s (shared box, diagnostic only):");
    for (name, s) in &stats.phases {
        println!("  {name}: {s:.3} s");
    }
    println!("EXPERIMENTAL: no whole-proof privacy, MVP or 5-second claim follows from this run.");
    Ok(())
}

fn verify_cmd(dir: &Path) -> Result<(), String> {
    let frame = read_bounded(&dir.join(RECEIPT), MAX_WIRE_BYTES)?;
    let policy = read_bounded(&dir.join(EXPECTED), EXPECTED_BYTES)?;
    // independent expected state: the public statement is rebuilt here, not read from the producer
    let (public, _) = AttentionPublic::synthetic_fixture();
    let expected = ExpectedIo::from_bytes(&policy)?;
    let started = std::time::Instant::now();
    verify_bytes(&public, &expected, &frame)?;
    println!("ACCEPT: {} bytes verified in {:.3} s", frame.len(), started.elapsed().as_secs_f64());
    // negative controls in the same fresh process
    for (name, at) in [("first root", 40usize), ("an argument word", 40 + 96 + 24), ("the last path byte", frame.len() - 1)] {
        let mut bad = frame.clone();
        bad[at] ^= 1;
        if verify_bytes(&public, &expected, &bad).is_ok() {
            return Err(format!("CONTROL FAILED: a frame with {name} corrupted verified"));
        }
        println!("refused: {name} corrupted");
    }
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let result = match (args.get(1).map(String::as_str), args.get(2)) {
        (Some("prove"), Some(dir)) => prove_cmd(Path::new(dir)),
        (Some("verify"), Some(dir)) => verify_cmd(Path::new(dir)),
        _ => Err("usage: zk60_private_attention prove|verify <dir>".into()),
    };
    if let Err(e) = result {
        eprintln!("REJECT: {e}");
        std::process::exit(1);
    }
}
