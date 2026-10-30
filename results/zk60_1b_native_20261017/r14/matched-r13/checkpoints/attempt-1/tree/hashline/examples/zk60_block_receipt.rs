//! PUBLIC synthetic one-block receipt demonstration. Never use sensitive data.
//! `prepare` creates expected state BEFORE proving. `verify` uses only bytes,
//! supplied expected state and independently supplied approved W/gamma roots:
//! no weight generation, witness/oracle execution, exports or prover call.
use hashline::causal_oracle::{
    public_synthetic_fixture, public_synthetic_registration, FixedCausalOracle,
};
use hashline::pcs::Commitment;
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::public_block_receipt::{
    verify_public_receipt_bytes, ExpectedPublicBlock, PublicReceiptOracle, EXPECTED_BYTES,
    MAX_RECEIPT_BYTES,
};
use std::io::{Read, Write};

fn root(text: &str) -> Result<[u8; 32], String> {
    if text.len() != 64 || !text.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err("expected root must be 64 hexadecimal characters".into());
    }
    let mut out = [0; 32];
    for (i, x) in out.iter_mut().enumerate() {
        *x = u8::from_str_radix(&text[2 * i..2 * i + 2], 16).map_err(|_| "root")?;
    }
    Ok(out)
}
fn read_bounded(path: &str, max: usize) -> Result<Vec<u8>, String> {
    let file = std::fs::File::open(path).map_err(|e| format!("open input: {e}"))?;
    let mut out = Vec::new();
    file.take(max as u64 + 1)
        .read_to_end(&mut out)
        .map_err(|e| format!("read input: {e}"))?;
    if out.len() > max {
        return Err("input exceeds public receipt bound".into());
    }
    Ok(out)
}
fn create(path: &str) -> Result<std::fs::File, String> {
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|e| format!("create new artifact: {e}"))
}
fn save(mut out: std::fs::File, bytes: &[u8]) -> Result<(), String> {
    out.write_all(bytes)
        .and_then(|_| out.sync_all())
        .map_err(|e| format!("write artifact: {e}"))
}
fn run() -> Result<(), String> {
    // All substantive work is bounded and CPU-only, including example setup.
    if cfg!(feature = "gpu-cuda") || std::env::var_os("HL_GPU").is_some_and(|v| !v.is_empty()) {
        return Err("public demo requires CPU-only build and HL_GPU unset".into());
    }
    let args: Vec<_> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("prepare") if args.len()==3 => {
            let out=create(&args[2])?;
            let (approved,weights,input)=public_synthetic_fixture();
            let b=FixedCausalOracle::new(&approved,weights).map_err(|e|e.to_string())?.build(&input).map_err(|e|e.to_string())?;
            let output:Vec<i16>=b.residual.xres2.iter().map(|x| i16::try_from(*x)).collect::<Result<_,_>>().map_err(|_|"fixture output range")?;
            let expected=ExpectedPublicBlock::new(&approved,[47;32],&input,&output)?;
            save(out,&expected.to_bytes())?;
            let r=approved.registration();
            println!("{{\"mode\":\"P0-public-synthetic\",\"expected_bytes\":{},\"attention_root\":\"{}\",\"ffn_root\":\"{}\",\"proving_executed\":false,\"goal_met\":false}}", EXPECTED_BYTES,
                hashline::silu::hex(&r.attention_weights.root),hashline::silu::hex(&r.ffn_weights.root));
            Ok(())
        }
        Some("prove") if args.len()==4 => {
            let out=create(&args[3])?;
            let (approved,weights,_)=public_synthetic_fixture();
            let expected=ExpectedPublicBlock::from_bytes(&approved,&read_bounded(&args[2],EXPECTED_BYTES)?)?;
            let proof=PublicReceiptOracle::new(&approved,weights)?.prove(&expected)?;
            let bytes=proof.to_bytes()?;
            verify_public_receipt_bytes(&approved,&expected,&bytes)?;
            save(out,&bytes)?;
            println!("{{\"coverage\":\"one-fixed-public-block-with-external-IO\",\"bytes\":{},\"verified_from_bytes\":true,\"goal_met\":false}}",bytes.len());
            Ok(())
        }
        Some("verify") if args.len()==6 => {
            // Expected roots come from caller policy, NOT proof/header fields.
            // The helper constructs only fixed public constants/table metadata.
            let aw=Commitment{root:root(&args[4])?,rows:4,log_cols:8};
            let fw=Commitment{root:root(&args[5])?,rows:3,log_cols:8};
            let approved=ApprovedP1BlockContract::from_trusted_registration(public_synthetic_registration(aw,fw)).map_err(|e|e.to_string())?;
            let expected=ExpectedPublicBlock::from_bytes(&approved,&read_bounded(&args[2],EXPECTED_BYTES)?)?;
            let bytes=read_bounded(&args[3],MAX_RECEIPT_BYTES)?;
            verify_public_receipt_bytes(&approved,&expected,&bytes)?;
            println!("{{\"coverage\":\"one-fixed-public-block-with-external-IO\",\"verified_from_bytes\":true,\"proving_executed\":false,\"goal_met\":false}}");
            Ok(())
        }
        _=>Err("usage: zk60_block_receipt prepare NEW_EXPECTED | prove EXPECTED NEW_RECEIPT | verify EXPECTED RECEIPT EXPECTED_ATTENTION_ROOT EXPECTED_FFN_ROOT".into()),
    }
}
fn main() {
    if let Err(e) = run() {
        eprintln!("PUBLIC BLOCK RECEIPT REJECT: {e}");
        std::process::exit(1);
    }
}
