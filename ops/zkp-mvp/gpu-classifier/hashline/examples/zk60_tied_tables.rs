//! Public derivation bridge for the token/export lanes. Guard this command.
use hashline::private_block::tied_tables::recompute_tied_tables;

fn hex(bytes: &[u8]) -> String { bytes.iter().map(|x| format!("{x:02x}")).collect() }

fn main() {
    let result = (|| -> Result<(),String> {
        let args = std::env::args().skip(1).collect::<Vec<_>>();
        if args.len()!=1 && args.len()!=4 { return Err("usage: zk60_tied_tables EXPORT [YES_ID NO_ID SCALE]".into()); }
        let margin = if args.len()==4 { Some((args[1].parse::<u32>().map_err(|e|e.to_string())?,args[2].parse::<u32>().map_err(|e|e.to_string())?,args[3].parse::<f64>().map_err(|e|e.to_string())?)) } else {None};
        let tables = recompute_tied_tables(std::path::Path::new(&args[0]),margin)?;
        let margin_hash = tables.margin.as_ref().map(|v| {
            use sha2::{Digest,Sha256};
            let mut h=Sha256::new(); for x in v {h.update(x.to_le_bytes());} hex(&h.finalize())
        });
        println!("{{\"embedding_sha256\":\"{}\",\"head_sha256\":\"{}\",\"multipliers_sha256\":\"{}\",\"margin_sha256\":{},\"bos\":{},\"profile_sha256\":\"{}\"}}",
            hex(&tables.embedding_sha256),hex(&tables.head_sha256),hex(&tables.multipliers_sha256),margin_hash.map(|s|format!("\"{s}\"")).unwrap_or("null".into()),tables.calibration.bos,hex(&tables.calibration.profile_sha256));
        Ok(())
    })();
    if let Err(error)=result {eprintln!("tied tables: {error}");std::process::exit(1);}
}
