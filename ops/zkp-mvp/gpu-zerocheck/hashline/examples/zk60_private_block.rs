//! EXPERIMENTAL private block profile `private-block-t32-poc/1`
//! (T32 / d16 / 2 heads / 1 KV head / F16): it proves the WHOLE block -
//! attention, norm_m, the SiLU feed-forward and residual 2 - in one proof with
//! no seam, between the two external endpoints `x_in` and `xres2`.
//! Prove in one process and verify in a FRESH process from bytes only:
//!
//!   zk60_private_block prove  <dir>   writes <dir>/block_receipt.bin and
//!                                         <dir>/block_expected.bin
//!   zk60_private_block verify <dir>   reads both, rebuilds the public
//!                                         statement itself, accepts the frame
//!                                         and refuses three corrupted copies
//!
//! Every tensor here is the PUBLIC SYNTHETIC fixture; only the proof
//! randomness is secret. The verify command never builds a witness, never
//! calls the prover and never sees the input or the output. In this demo the
//! endpoint policy file is written by the proving process, as permitted by
//! D18's prover-created endpoint profile. D22's conditional privacy acceptance
//! applies only to the fixed toy block under its recorded assumptions; it
//! does not cover model-scale proofs. Shared-box timings are diagnostic only.
use hashline::private_block::{
    compute_output, encoded_len, prepare_endpoints, prove_with_stats, schedule, verify_bytes, BlockPublic, ExpectedIo, IoSpec, EXPECTED_BYTES, MAX_WIRE_BYTES,
};
use std::path::Path;

const RECEIPT: &str = "block_receipt.bin";
const EXPECTED: &str = "block_expected.bin";

fn read_bounded(path: &Path, max: usize) -> Result<Vec<u8>, String> {
    let len = std::fs::metadata(path).map_err(|e| format!("{}: {e}", path.display()))?.len();
    if len > max as u64 {
        return Err(format!("{}: larger than the {max}-byte bound", path.display()));
    }
    std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))
}

/// D21: a rejected receipt must never reach the output directory. Verify the
/// exact encoded bytes first; successful encoding alone is not acceptance.
fn write_verified_receipt(dir: &Path, public: &BlockPublic, expected: &ExpectedIo, frame: &[u8]) -> Result<(), String> {
    verify_bytes(public, expected, frame)?;
    std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    std::fs::write(dir.join(RECEIPT), frame).map_err(|e| e.to_string())?;
    std::fs::write(dir.join(EXPECTED), expected.to_bytes()).map_err(|e| e.to_string())?;
    Ok(())
}

fn prove_cmd(dir: &Path) -> Result<(), String> {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let context = *blake3::hash(b"zk60 private block example: public synthetic request").as_bytes();
    // the endpoint exponents are pinned to the approved calibration
    let spec = IoSpec::new(context, 0, 0)?;
    // the endpoint owner's step: fix both private endpoints BEFORE proving
    let output = compute_output(&blk, &input)?;
    let (expected, owners) = prepare_endpoints(spec, &input, &output)?;
    drop(output);
    let started = std::time::Instant::now();
    let (receipt, stats) = prove_with_stats(&blk, &input, &expected, owners)?;
    let seconds = started.elapsed().as_secs_f64();
    let frame = receipt.to_bytes(&blk, &expected)?;
    write_verified_receipt(dir, &blk, &expected, &frame)?;
    println!("profile: {}", String::from_utf8_lossy(hashline::private_block::PROFILE));
    for line in schedule().iter().take(6) {
        println!("  {line}");
    }
    println!("receipt frame: {} bytes (fixed by the geometry: {})", frame.len(), encoded_len());
    println!("committed rows: A {} H {} M {}; lookups: U8 {} exp {} act {}", stats.a_rows, stats.h_rows, stats.m_rows, stats.u8_lookups, stats.exp_lookups, stats.act_lookups);
    println!("prove {seconds:.3} s (shared box, diagnostic only):");
    for (name, s) in &stats.phases {
        println!("  {name}: {s:.3} s");
    }
    println!("EXPERIMENTAL: fixed synthetic toy profile; no model-scale or 5-second claim follows from this run.");
    Ok(())
}

fn verify_cmd(dir: &Path) -> Result<(), String> {
    let frame = read_bounded(&dir.join(RECEIPT), MAX_WIRE_BYTES)?;
    let policy = read_bounded(&dir.join(EXPECTED), EXPECTED_BYTES)?;
    // independent expected state: the public statement is rebuilt here, not read from the producer
    let (blk, _) = BlockPublic::synthetic_fixture();
    let expected = ExpectedIo::from_bytes(&policy)?;
    let started = std::time::Instant::now();
    verify_bytes(&blk, &expected, &frame)?;
    println!("ACCEPT: {} bytes verified in {:.3} s", frame.len(), started.elapsed().as_secs_f64());
    // negative controls in the same fresh process
    for (name, at) in [("first root", 40usize), ("an argument word", 40 + 96 + 24), ("the last path byte", frame.len() - 1)] {
        let mut bad = frame.clone();
        bad[at] ^= 1;
        if verify_bytes(&blk, &expected, &bad).is_ok() {
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
        _ => Err("usage: zk60_private_block prove|verify <dir>".into()),
    };
    if let Err(e) = result {
        eprintln!("REJECT: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_verified_encoded_receipts_reach_the_output_directory() {
        let (blk, input) = BlockPublic::synthetic_fixture();
        let spec = IoSpec::new(*blake3::hash(b"private block publication test").as_bytes(), 0, 0).unwrap();
        let output = compute_output(&blk, &input).unwrap();
        let (expected, owners) = prepare_endpoints(spec, &input, &output).unwrap();
        let (receipt, _) = prove_with_stats(&blk, &input, &expected, owners).unwrap();
        let frame = receipt.to_bytes(&blk, &expected).unwrap();
        let dir = std::env::temp_dir().join(format!("zk60-block-publication-{}", std::process::id()));
        assert!(!dir.exists(), "test output already exists");

        let mut bad = frame.clone();
        bad[40] ^= 1;
        assert!(write_verified_receipt(&dir, &blk, &expected, &bad).is_err());
        assert!(!dir.exists(), "rejected bytes created the output directory");
        let short = &frame[..frame.len() - 1];
        assert!(write_verified_receipt(&dir, &blk, &expected, short).is_err());
        assert!(!dir.exists(), "truncated bytes created the output directory");

        write_verified_receipt(&dir, &blk, &expected, &frame).unwrap();
        assert_eq!(std::fs::read(dir.join(RECEIPT)).unwrap(), frame);
        assert_eq!(std::fs::read(dir.join(EXPECTED)).unwrap(), expected.to_bytes());
        // A rejected attempt also cannot replace an existing accepted artifact.
        assert!(write_verified_receipt(&dir, &blk, &expected, &bad).is_err());
        assert_eq!(std::fs::read(dir.join(RECEIPT)).unwrap(), frame);
        verify_cmd(&dir).unwrap();
        std::fs::remove_dir_all(dir).unwrap();
    }
}
