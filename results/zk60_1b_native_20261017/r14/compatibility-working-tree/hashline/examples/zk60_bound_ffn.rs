//! Bound FFN demonstration on PUBLIC synthetic tensors. The trusted fixture
//! caller commits both endpoints and saves public policy BEFORE FFN proving.
//! A real application must obtain that policy through its own trusted channel.
//! Verification reads only public policy and receipt bytes in a separate process.
use hashline::causal_oracle::{public_synthetic_fixture, FixedCausalOracle};
use hashline::field::Fp;
use hashline::layer::StatementV3;
use hashline::zk::{
    fresh_poc::{io, WeightStatement},
    ZkPrivacy,
};
use std::io::{Read, Write};

fn statement() -> Result<StatementV3, String> {
    use hashline::tables_v3::{int16out_member, Act16Fn};
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).ok_or("fixture table")?;
    Ok(StatementV3 {
        l: 0,
        t_rows: 32,
        d: 16,
        f: 16,
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
    })
}
fn digest(text: &str) -> Result<[u8; 32], String> {
    if text.len() != 64 || !text.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err("expected 64 hexadecimal characters".into());
    }
    let mut out = [0; 32];
    for (i, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(&text[2 * i..2 * i + 2], 16).map_err(|_| "digest")?;
    }
    Ok(out)
}
fn mode(s: &str) -> Result<ZkPrivacy, String> {
    match s {
        "p1" => Ok(ZkPrivacy::P1),
        "p3" => Ok(ZkPrivacy::P3),
        _ => Err("mode must be p1 or p3".into()),
    }
}
fn read(path: &str, max: usize) -> Result<Vec<u8>, String> {
    let mut bytes = Vec::new();
    std::fs::File::open(path)
        .map_err(|e| e.to_string())?
        .take(max as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    Ok(bytes)
}
fn create(path: &str) -> Result<std::fs::File, String> {
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|e| format!("create new artifact: {e}"))
}
fn save(file: &mut std::fs::File, bytes: &[u8]) -> Result<(), String> {
    file.write_all(bytes)
        .and_then(|_| file.sync_all())
        .map_err(|e| e.to_string())
}
fn run() -> Result<(), String> {
    if cfg!(feature = "gpu-cuda") || std::env::var_os("HL_GPU").is_some_and(|v| !v.is_empty()) {
        return Err("bound FFN demo requires the default CPU build and HL_GPU unset".into());
    }
    let a: Vec<_> = std::env::args().collect();
    match a.get(1).map(String::as_str) {
        Some("prepare") if a.len()==2 => {
            let (approved,_,_)=public_synthetic_fixture();
            println!("{{\"public_weight_root\":\"{}\",\"proving_executed\":false}}",
                hashline::silu::hex(&approved.registration().ffn_weights.root));
            Ok(())
        }
        Some("prove") if a.len()==6 => {
            let privacy=mode(&a[2])?;
            let spec=io::IoSpec::new(digest(&a[3])?,-3,0)?;
            let mut proof_file=create(&a[5])?;
            let mut policy_file=create(&a[4])?;
            let (approved,weights,input)=public_synthetic_fixture();
            let weights_policy=match privacy {
                ZkPrivacy::P1=>WeightStatement::Public(approved.registration().ffn_weights.root),
                ZkPrivacy::P3=>WeightStatement::FreshPrivate,
            };
            let w=FixedCausalOracle::new(&approved,weights).map_err(|e| e.to_string())?
                .build(&input).map_err(|e| e.to_string())?.ffn;
            let x:Vec<_>=w.x.iter().map(|&v| Fp::from_i64(v as i64)).collect();
            let z:Vec<_>=w.z16.iter().map(|&v| Fp::from_i64(v as i64)).collect();
            let (expected,endpoints)=io::prepare_endpoints(spec,&x,&z)?;
            save(&mut policy_file,&expected.to_bytes())?;
            // All endpoint commitments and public verifier policy now exist.
            // Endpoint secrets stay in RAM and are consumed by finish.
            let receipt=io::prepare(&w,privacy,&expected)?.finish(endpoints)?;
            let st=statement()?;
            let bytes=receipt.to_bytes(&st,weights_policy,&expected)?;
            io::verify_bytes(&st,weights_policy,&expected,&bytes)?;
            save(&mut proof_file,&bytes)?;
            println!("{{\"mode\":\"{privacy:?}\",\"wire_bytes\":{},\"policy_saved_before_proving\":true,\"verified_from_bytes\":true,\"input_root\":\"{}\",\"output_root\":\"{}\"}}",
                bytes.len(),hashline::silu::hex(&expected.input_root()),hashline::silu::hex(&expected.output_root()));
            Ok(())
        }
        Some("verify") if a.len()==7 => {
            let privacy=mode(&a[2])?;
            let weights=match privacy {
                ZkPrivacy::P1=>WeightStatement::Public(digest(&a[3])?),
                ZkPrivacy::P3 if a[3]=="fresh"=>WeightStatement::FreshPrivate,
                ZkPrivacy::P3=>return Err("p3 requires explicit 'fresh' policy; registered model identity is not proved".into()),
            };
            let spec=io::IoSpec::new(digest(&a[4])?,-3,0)?;
            // This path trusts the supplied policy FILE, not roots in a receipt.
            // The caller additionally supplies the expected request context.
            let policy_bytes=read(&a[5],io::EXPECTED_BYTES)?;
            let roots=io::ExpectedIo::from_bytes(&policy_bytes)?;
            let expected=io::ExpectedIo::from_roots(spec,roots.input_root(),roots.output_root());
            if expected.to_bytes()!=policy_bytes { return Err("expected request context/scales mismatch".into()); }
            let st=statement()?;
            let bytes=read(&a[6],io::encoded_len(&st,weights)?)?;
            io::verify_bytes(&st,weights,&expected,&bytes)?;
            println!("{{\"mode\":\"{privacy:?}\",\"wire_bytes\":{},\"verified_from_bytes\":true,\"proving_executed\":false}}",bytes.len());
            Ok(())
        }
        _=>Err("usage: zk60_bound_ffn prepare | prove p1|p3 CONTEXT_HEX NEW_EXPECTED NEW_RECEIPT | verify p1 EXPECTED_PUBLIC_W_ROOT CONTEXT_HEX TRUSTED_EXPECTED RECEIPT | verify p3 fresh CONTEXT_HEX TRUSTED_EXPECTED RECEIPT".into()),
    }
}
fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
