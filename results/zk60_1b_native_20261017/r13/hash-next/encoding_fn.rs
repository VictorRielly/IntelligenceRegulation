const ENCODING_DOMAIN:&[u8]=b"zk60-low-public/v2\0";

/// Complete bounded family of public binding lengths. Hash-class tests check
/// this against real encodings and a separately transcribed census formula.
pub(crate) fn encoded_len(geometry:Geometry,registry:Registry,stack:Stack,groups:usize)->Result<usize,String> {
    geometry.check_registry(registry)?;
    let stack=stack.export_name().ok_or("R13 encoding length requires a LOW stack")?;
    if !(1..=4).contains(&groups) {return Err("R13 encoding length requires one to four groups".into());}
    let channels=geometry.query_width+2*geometry.kv_width+2*geometry.width+2*geometry.hidden;
    Ok(ENCODING_DOMAIN.len()+4+registry.name().len()+4+stack.len()
        +4*8+9*4+2*4+7*8+2*channels+8+8*groups+8+8*geometry.hidden+groups*(8+4096*2))
}

