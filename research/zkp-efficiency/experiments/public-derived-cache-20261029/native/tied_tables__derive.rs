use super::{regular, File, Path, Read, Seek, SeekFrom, Sha256, Digest};
use crate::private_block::trained_block::{J, parse_json, sha256, unhex32};
use crate::private_block::{run, trained_statement::ModelSource};

const WIDTH: usize = 3072;
const VOCAB: usize = 131072;
const TENSOR: &str = "language_model.model.embed_tokens.weight";
const NORM: &str = "language_model.model.norm.weight";
const CHECKPOINT_BYTES: u64 = 7698241104;
const DEFAULT_CHECKPOINT: &str = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors";

/// Public calibrated norm constants, read from the profile rather than a
/// classifier's copy. The calling token proof must bind its own relation.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TiedFinalNorm {
    pub g0: i64,
    pub cn: i64,
    pub tn: u32,
    pub ceps: i64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TiedTokenCalibration {
    pub bos: u32,
    pub classifier_final_norm: TiedFinalNorm,
    pub head_final_norm: TiedFinalNorm,
    /// Bind the calibration authority when incorporating this into a proof.
    pub profile_sha256: [u8; 32],
}

/// Digests derived by streaming the authenticated BF16 tensor. No exported
/// integer table is an input to these computations.
#[derive(Clone, Debug)]
pub struct RecomputedTiedTables {
    pub embedding_sha256: [u8; 32],
    pub head_sha256: [u8; 32],
    pub multipliers_sha256: [u8; 32],
    pub margin: Option<Vec<i16>>,
    pub calibration: TiedTokenCalibration,
}

fn json(path: &Path) -> Result<(Vec<u8>, J), String> {
    let bytes = run::read_regular_file_bounded(path, 4 << 20, false)?;
    let value = parse_json(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
    Ok((bytes, value))
}

fn positive(value: f64, what: &str) -> Result<f64, String> {
    if !value.is_finite() || value <= 0.0 { return Err(format!("{what}: expected a finite positive scale")); }
    Ok(value)
}

fn norm(value: &J, classifier: bool) -> Result<TiedFinalNorm, String> {
    let get = |key: &str| value.get(key).and_then(J::i64);
    let out = TiedFinalNorm { g0: get("g0")?, cn: get("cn")?,
        tn: u32::try_from(get("tn")?).map_err(|_| "final norm tn out of range")?, ceps: get("ceps")? };
    if out.g0 != 127 || !(1..=crate::private_block::shape::TRAINED_CN_MAX).contains(&out.cn)
        || !crate::private_block::shape::TRAINED_TN_RANGE.contains(&out.tn)
        || !(1..=crate::private_block::shape::TRAINED_CEPS_MAX).contains(&out.ceps) {
        return Err("token_io_parameters: final norm outside its declared class".into());
    }
    if classifier && (out.tn != 10 || out.ceps >= crate::private_block::shape::TRAINED_CEPS_MAX) {
        return Err("classifier_final_norm requires tn=10 and ceps<2^40 for its 32-bit norm window".into());
    }
    Ok(out)
}

fn calibration(profile: &J, bytes: &[u8]) -> Result<TiedTokenCalibration, String> {
    let pin = ModelSource::shieldstral_1_0_3b();
    let model = profile.get("model")?;
    if model.get("repo")?.str()? != pin.repo || model.get("revision")?.str()? != pin.revision || unhex32(model.get("sha256")?.str()?)? != pin.weights_sha256 {
        return Err("tied tables: profile model is not the pinned Shieldstral checkpoint".into());
    }
    let parameters = profile.get("token_io_parameters").map_err(|_| "profile.json must supply token_io_parameters (bos, classifier_final_norm, head_final_norm)".to_string())?;
    let bos = u32::try_from(parameters.get("bos")?.i64()?).map_err(|_| "invalid bos")?;
    if bos != 1 { return Err("token_io_parameters.bos is not Shieldstral's pinned BOS 1".into()); }
    let classifier_final_norm=norm(parameters.get("classifier_final_norm")?, true)?;
    let head_final_norm=norm(parameters.get("head_final_norm")?, false)?;
    let constants=profile.get("profile_constants")?;
    if head_final_norm.tn as i64 != constants.get("norm_tn")?.i64()? || head_final_norm.ceps != constants.get("norm_ceps")?.i64()? || classifier_final_norm.ceps != head_final_norm.ceps {
        return Err("token_io_parameters: final norm tn/ceps differ from the export calibration".into());
    }
    Ok(TiedTokenCalibration { bos, classifier_final_norm, head_final_norm, profile_sha256: sha256(bytes) })
}

/// Return the export's calibrated final norm and BOS. A classifier manifest
/// must equal these values; the returned profile digest is its authority.
pub fn tied_token_calibration(export: &Path) -> Result<TiedTokenCalibration, String> {
    let (bytes, profile) = json(&export.join("profile.json"))?;
    calibration(&profile, &bytes)
}

fn extent(header: &J, name: &str, shape: &[usize], size: u64, base: u64) -> Result<(u64, u64), String> {
    let tensor = header.get(name).map_err(|e| format!("checkpoint tensor {name}: {e}"))?;
    let dims = tensor.get("shape")?.arr()?.iter().map(|v| v.i64().and_then(|n| usize::try_from(n).map_err(|_| "negative tensor dimension".into()))).collect::<Result<Vec<_>,_>>()?;
    if tensor.get("dtype")?.str()? != "BF16" || dims != shape { return Err(format!("checkpoint {name}: expected BF16 {shape:?}")); }
    let offsets = tensor.get("data_offsets")?.arr()?;
    if offsets.len() != 2 { return Err(format!("checkpoint {name}: invalid data_offsets")); }
    let start = u64::try_from(offsets[0].i64()?).map_err(|_| "negative tensor offset")?;
    let end = u64::try_from(offsets[1].i64()?).map_err(|_| "negative tensor offset")?;
    let length = shape.iter().product::<usize>() as u64 * 2;
    if end.checked_sub(start) != Some(length) || end > size.saturating_sub(base) { return Err(format!("checkpoint {name}: invalid BF16 extent")); }
    Ok((base + start, length))
}

fn read_at(file: &mut File, offset: u64, length: usize) -> Result<Vec<u8>, String> {
    file.seek(SeekFrom::Start(offset)).map_err(|e| e.to_string())?;
    let mut bytes = vec![0; length];
    file.read_exact(&mut bytes).map_err(|e| e.to_string())?;
    Ok(bytes)
}

fn bf16(bytes: &[u8]) -> Result<Vec<f64>, String> {
    let values = bytes.chunks_exact(2).map(|x| f32::from_bits(u32::from(u16::from_le_bytes([x[0], x[1]])) << 16) as f64).collect::<Vec<_>>();
    if values.iter().any(|x| !x.is_finite()) { return Err("nonfinite BF16 tensor value".into()); }
    Ok(values)
}

struct Checkpoint { file: File, tensor_offset: u64, tensor_digest: [u8;32], norm: Vec<f64> }

impl Checkpoint {
    fn open(path: &Path) -> Result<Self, String> {
        let mut file = regular(path, CHECKPOINT_BYTES, true)?;
        let size = file.metadata().map_err(|e| e.to_string())?.len();
        let prefix = read_at(&mut file, 0, 8)?;
        let len = u64::from_le_bytes(prefix.as_slice().try_into().unwrap());
        if !(2..=4<<20).contains(&len) || len > size.saturating_sub(8) { return Err("checkpoint safetensors header length out of bounds".into()); }
        let header_bytes = read_at(&mut file, 8, len as usize)?;
        let header = parse_json(&header_bytes)?;
        let base = 8 + len;
        let (tensor_offset, _) = extent(&header, TENSOR, &[VOCAB, WIDTH], size, base)?;
        let (norm_offset, norm_len) = extent(&header, NORM, &[WIDTH], size, base)?;
        if header.opt("language_model.lm_head.weight").is_some() { return Err("checkpoint has an independent LM head instead of a tied tensor".into()); }
        // Capture norm bytes from the SAME reads authenticated by the full
        // checkpoint hash. Also compare the parsed header with those reads.
        let mut norm_bytes = vec![0u8; norm_len as usize];
        let expected_header = [prefix, header_bytes].concat();
        let mut hasher = Sha256::new();
        file.seek(SeekFrom::Start(0)).map_err(|e| e.to_string())?;
        let mut buffer = vec![0; 1 << 20];
        let mut offset = 0u64;
        while offset < size {
            let count = (size-offset).min(buffer.len() as u64) as usize;
            file.read_exact(&mut buffer[..count]).map_err(|e| e.to_string())?;
            hasher.update(&buffer[..count]);
            if offset < base {
                let n = (base-offset).min(count as u64) as usize;
                if buffer[..n] != expected_header[offset as usize..offset as usize+n] { return Err("checkpoint header changed while authenticating".into()); }
            }
            let lo = offset.max(norm_offset);
            let hi = (offset+count as u64).min(norm_offset+norm_len);
            if lo < hi { norm_bytes[(lo-norm_offset) as usize..(hi-norm_offset) as usize].copy_from_slice(&buffer[(lo-offset) as usize..(hi-offset) as usize]); }
            offset += count as u64;
        }
        let pin = ModelSource::shieldstral_1_0_3b();
        if <[u8;32]>::from(hasher.finalize()) != pin.weights_sha256 { return Err("checkpoint SHA-256 differs from the pinned model".into()); }
        if file.metadata().map_err(|e| e.to_string())?.len() != size { return Err("checkpoint changed during authentication".into()); }
        let (_, tensor_digest) = crate::private_block::trained_statement::tied_tensor_for_profile(crate::private_block::shape::SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
        Ok(Self { file, tensor_offset, tensor_digest, norm: bf16(&norm_bytes)? })
    }
}

fn rotate(values: &mut [f64], signs: &[f64], block: usize) -> Result<(), String> {
    if values.len() != signs.len() || !block.is_power_of_two() || values.len() % block != 0 || signs.iter().any(|s| *s != 1.0 && *s != -1.0) { return Err("invalid signed block Hadamard geometry".into()); }
    for (x,s) in values.iter_mut().zip(signs) { *x *= s; }
    for row in values.chunks_exact_mut(block) {
        let mut step = 1;
        while step < block {
            for chunk in row.chunks_exact_mut(2*step) {
                for i in 0..step { let (a,b) = (chunk[i],chunk[i+step]); chunk[i]=a+b; chunk[i+step]=a-b; }
            }
            step *= 2;
        }
        for x in row { *x /= (block as f64).sqrt(); }
    }
    if values.iter().any(|v| !v.is_finite()) { return Err("nonfinite rotated weight".into()); }
    Ok(())
}

fn quantize(values: &[f64], scale: f64, low: i64, high: i64) -> Result<Vec<i64>, String> {
    positive(scale,"quantization")?;
    values.iter().map(|value| {
        let q = (value/scale+0.5).floor();
        if !q.is_finite() || q < low as f64 || q > high as f64 { return Err("quantization overflow (no clipping is permitted)".into()); }
        Ok(q as i64)
    }).collect()
}

fn head_row(raw: &[f64], norm: &[f64], signs: &[f64], block: usize) -> Result<(Vec<i64>,f64),String> {
    let mut folded = raw.iter().zip(norm).map(|(x,n)| x*n).collect::<Vec<_>>();
    rotate(&mut folded, signs, block)?;
    let scale = folded.iter().map(|x| x.abs()).fold(0.0,f64::max)/127.0;
    Ok((quantize(&folded,if scale>0.0 {scale} else {1.0},-127,127)?,scale))
}

/// Recompute all three tied-table digests, and optionally the classifier
/// difference row for `(yes_id, no_id, scale)`. Quantization is binary64
/// floor(x/scale + .5) with explicit endpoint refusal; negative ties round
/// toward positive infinity. Embedding rotation alone is rounded to f32
/// first, matching the residual calibration. The margin uses the difference
/// BEFORE quantization. It is never the difference of rounded head rows.
///
/// This authenticates/streams gigabytes; callers must use the resource guard.
pub fn recompute_tied_tables(export: &Path, margin: Option<(u32,u32,f64)>) -> Result<RecomputedTiedTables,String> {
    let (bytes, profile) = json(&export.join("profile.json"))?;
    recompute_profile(export, &bytes, &profile, margin)
}

/// The loader already read a profile to build its statement. Refuse a
/// replacement between that read and derivation; use the same parsed object
/// for every quantization parameter within this pass.
pub(crate) fn recompute_declared_tied_tables(export: &Path, expected: &J) -> Result<RecomputedTiedTables,String> {
    let (bytes,profile)=json(&export.join("profile.json"))?;
    if &profile != expected { return Err("profile.json changed before tied-table derivation".into()); }
    recompute_profile(export,&bytes,&profile,None)
}

fn recompute_profile(export: &Path, bytes: &[u8], profile: &J, margin: Option<(u32,u32,f64)>) -> Result<RecomputedTiedTables,String> {
    let calibration = calibration(&profile,&bytes)?;
    if let Some((yes,no,scale)) = margin {
        if yes==no || yes as usize>=VOCAB || no as usize>=VOCAB { return Err("invalid classifier yes/no token IDs".into()); }
        positive(scale,"classifier margin")?;
    }
    let metadata = profile.get("metadata_out_of_proof")?;
    let scale = positive(metadata.get("residual_scales_in")?.arr()?.first().ok_or("empty residual scales")?.f64()?,"embedding")?;
    let rotation = metadata.get("rotation")?;
    if rotation.get("kind")?.str()? != "block-hadamard" || rotation.get("width")?.i64()? != WIDTH as i64 || rotation.get("block_width")?.i64()? != 1024 || rotation.get("blocks")?.i64()? != 3 { return Err("tied tables: expected three 1024-wide Hadamard blocks".into()); }
    let sign_bytes = run::read_regular_file_bounded(&export.join("rotation_sign.bin"), (WIDTH*8) as u64,true)?;
    if sha256(&sign_bytes) != unhex32(rotation.get("sign_sha256")?.str()?)? { return Err("rotation signs SHA-256 differs from profile".into()); }
    let signs = sign_bytes.chunks_exact(8).map(|x| f64::from_le_bytes(x.try_into().unwrap())).collect::<Vec<_>>();
    if signs.iter().any(|s| *s != 1.0 && *s != -1.0) { return Err("rotation signs must be exactly +1 or -1".into()); }
    let declaration = profile.get("tied_embeddings")?;
    let (_, pin) = crate::private_block::trained_statement::tied_tensor_for_profile(crate::private_block::shape::SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
    if declaration.get("tensor")?.str()? != TENSOR || unhex32(declaration.get("sha256")?.str()?)? != pin { return Err("tied tensor declaration differs from pin".into()); }
    let checkpoint_path = declaration.opt("checkpoint_file").map(J::str).transpose()?.unwrap_or(DEFAULT_CHECKPOINT);
    let mut checkpoint = Checkpoint::open(Path::new(checkpoint_path))?;
    checkpoint.file.seek(SeekFrom::Start(checkpoint.tensor_offset)).map_err(|e| e.to_string())?;
    let mut raw_bytes = vec![0; WIDTH*2];
    let (mut tensor_hash,mut embedding_hash,mut head_hash) = (Sha256::new(),Sha256::new(),Sha256::new());
    let mut scales = Vec::with_capacity(VOCAB);
    let (mut yes_row,mut no_row) = (Vec::new(),Vec::new());
    for row in 0..VOCAB {
        checkpoint.file.read_exact(&mut raw_bytes).map_err(|e| format!("tied tensor row {row}: {e}"))?;
        tensor_hash.update(&raw_bytes);
        let raw = bf16(&raw_bytes)?;
        if let Some((yes,no,_)) = margin { if row==yes as usize {yes_row=raw.clone();} if row==no as usize {no_row=raw.clone();} }
        let mut embedding = raw.clone();
        rotate(&mut embedding,&signs,1024)?;
        for x in &mut embedding { *x=(*x as f32) as f64; }
        let encoded=quantize(&embedding,scale,-32768,32767)?.into_iter().flat_map(|word| (word as i16).to_le_bytes()).collect::<Vec<_>>();
        embedding_hash.update(&encoded);
        let (head,head_scale) = head_row(&raw,&checkpoint.norm,&signs,1024)?;
        head_hash.update(head.into_iter().map(|word| word as i8 as u8).collect::<Vec<_>>());
        scales.push(head_scale);
    }
    if <[u8;32]>::from(tensor_hash.finalize()) != checkpoint.tensor_digest { return Err("consumed tied tensor SHA-256 differs from pin".into()); }
    let maximum = positive(scales.iter().copied().fold(0.0,f64::max),"maximum head row scale")?;
    let mut multiplier_hash = Sha256::new();
    for scale in scales { let m=(4096.0*scale/maximum+0.5).floor().max(1.0) as i64; if !(1..=4096).contains(&m) {return Err("head multiplier overflow".into());} multiplier_hash.update(m.to_le_bytes()); }
    let margin = if let Some((_,_,scale)) = margin {
        let mut values = yes_row.iter().zip(&no_row).zip(&checkpoint.norm).map(|((y,n),g)| (y-n)*g).collect::<Vec<_>>();
        rotate(&mut values,&signs,1024)?;
        Some(quantize(&values,scale,-32767,32767)?.into_iter().map(|x| x as i16).collect())
    } else {None};
    Ok(RecomputedTiedTables { embedding_sha256: embedding_hash.finalize().into(), head_sha256: head_hash.finalize().into(),
        multipliers_sha256: multiplier_hash.finalize().into(), margin, calibration })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn python_rotated_quantization_reference_and_negative_ties() {
        // Independent Python reference: r12b/quantization_reference.json.
        let signs=[1.,-1.,1.,1.,-1.,1.,-1.,1.];
        let norm=[1.,0.5,1.25,-0.75,2.,0.25,1.5,1.];
        let raw=[1.,-1.,0.5,-0.5,2.,-2.,0.25,-0.25];
        let no=[-3.,1.5,-0.75,0.125,4.,-0.125,1.,-0.5];
        let mut embedding=raw;
        rotate(&mut embedding,&signs,4).unwrap();
        assert_eq!(quantize(&embedding,0.125,-32768,32767).unwrap(),[8,4,8,-4,-18,0,-14,0]);
        let (head,scale)=head_row(&raw,&norm,&signs,4).unwrap();
        assert_eq!(head,[62,19,12,6,-127,-90,-96,-84]);
        assert_eq!(scale,0.020177165354330708);
        assert_eq!(head_row(&[0.;8],&norm,&signs,4).unwrap(),(vec![0;8],0.));
        let mut difference=raw.iter().zip(no).zip(norm).map(|((a,b),n)| (a-b)*n).collect::<Vec<_>>();
        rotate(&mut difference,&signs,4).unwrap();
        assert_eq!(quantize(&difference,0.00011110644856105228,-32767,32767).unwrap(),[32767,17298,14485,7453,22079,24048,9704,16173]);
        assert_eq!(quantize(&[-2.5,-1.5,-0.5,0.5,1.5],1.,-32768,32767).unwrap(),[-2,-1,0,1,2]);
        assert!(quantize(&[32768.],1.,-32768,32767).is_err());
        assert!(quantize(&[-32768.],1.,-32767,32767).is_err());
        assert!(quantize(&[f64::NAN],1.,-32768,32767).is_err());
        assert!(quantize(&[1.],f64::INFINITY,-32768,32767).is_err());
    }

    #[test]
    fn safetensors_extents_refuse_wrong_dtype_shape_and_bounds() {
        let good=parse_json(br#"{"e":{"dtype":"BF16","shape":[2,3],"data_offsets":[4,16]}}"#).unwrap();
        assert_eq!(extent(&good,"e",&[2,3],100,20).unwrap(),(24,12));
        assert!(extent(&good,"e",&[3,2],100,20).is_err());
        assert!(extent(&good,"e",&[2,3],30,20).is_err());
        for bytes in [br#"{"e":{"dtype":"F16","shape":[2,3],"data_offsets":[4,16]}}"#.as_slice(),br#"{"e":{"dtype":"BF16","shape":[2,3],"data_offsets":[4,15]}}"#.as_slice()] {
            assert!(extent(&parse_json(bytes).unwrap(),"e",&[2,3],100,20).is_err());
        }
        assert!(bf16(&[0x80,0x7f]).is_err());
    }

    #[test]
    fn calibrated_norm_class_and_classifier_window_are_explicit() {
        let valid=parse_json(br#"{"g0":127,"cn":1024,"tn":10,"ceps":2439}"#).unwrap();
        assert_eq!(norm(&valid,true).unwrap(),TiedFinalNorm {g0:127,cn:1024,tn:10,ceps:2439});
        for bad in [br#"{"g0":126,"cn":1024,"tn":10,"ceps":2439}"#.as_slice(),
            br#"{"g0":127,"cn":0,"tn":10,"ceps":2439}"#.as_slice(),
            br#"{"g0":127,"cn":1024,"tn":9,"ceps":2439}"#.as_slice(),
            br#"{"g0":127,"cn":1024,"tn":10,"ceps":1099511627776}"#.as_slice()] {
            assert!(norm(&parse_json(bad).unwrap(),true).is_err());
        }
        // The accessor must support the prover's declared head-norm class,
        // rather than narrowing legal calibrations to tn>=8.
        for tn in [1,7,16] {
            let text=format!(r#"{{"g0":127,"cn":128,"tn":{tn},"ceps":2439}}"#);
            assert_eq!(norm(&parse_json(text.as_bytes()).unwrap(),false).unwrap().tn,tn);
        }
        for text in [r#"{"g0":127,"cn":128,"tn":17,"ceps":2439}"#,
                     r#"{"g0":127,"cn":128,"tn":7,"ceps":0}"#] {
            assert!(norm(&parse_json(text.as_bytes()).unwrap(),false).is_err());
        }
        let endpoint=parse_json(br#"{"g0":127,"cn":128,"tn":7,"ceps":1099511627776}"#).unwrap();
        assert!(norm(&endpoint,false).is_ok());
        let mut invalid=[1.,2.,3.,4.];
        assert!(rotate(&mut invalid,&[1.,1.,0.,1.],4).is_err());
    }
}
