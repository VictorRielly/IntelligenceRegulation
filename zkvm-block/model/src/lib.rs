//! Bounded, canonical public model and private request encoding for a fixed block.
//! The kernel calibration is fixed by the verifier's trusted program image.
use private_block_kernel::{PublicWeights, PublicTables, run_block};
use zk60_block_statement::{endpoint, model_digest, Hash, Role, Statement, ELEMENTS, PROFILE};

pub const MODEL_MAGIC: [u8; 8] = *b"Z60MDL01";
pub const MODEL_BYTES: usize = 8 + 1568 + (128 + 128 + 256) * 8 + 256 * 2;
pub const REQUEST_BYTES: usize = 16 + 32 * 3 + ELEMENTS * 2;

pub struct Model { pub weights: PublicWeights, pub tables: PublicTables, pub digest: Hash }

impl Model {
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len()!=MODEL_BYTES || bytes[..8]!=MODEL_MAGIC { return Err("invalid public model encoding"); }
        let w: Vec<i8> = bytes[8..1576].iter().map(|b| *b as i8).collect();
        let weights=PublicWeights::from_slices(&w[0..256],&w[256..384],&w[384..512],&w[512..768],
            &w[768..784],&w[784..800],&w[800..1056],&w[1056..1312],&w[1312..1568])
            .map_err(|_|"invalid public weight shape")?;
        let words:Vec<i64>=bytes[1576..5672].chunks_exact(8)
            .map(|b|i64::from_le_bytes(b.try_into().unwrap())).collect();
        let act:Vec<i16>=bytes[5672..].chunks_exact(2)
            .map(|b|i16::from_le_bytes(b.try_into().unwrap())).collect();
        let tables=PublicTables::from_slices(&words[..128],&words[128..256],&words[256..512],&act)
            .map_err(|_|"invalid public lookup tables")?;
        Ok(Self {weights,tables,digest:model_digest(bytes)})
    }
}

// Intentionally no Debug/Serialize: all fields below are local secrets except context.
pub struct Request {
    pub context: Hash,
    pub input_salt: Hash,
    pub output_salt: Hash,
    pub input: [i16; ELEMENTS],
}

impl Request {
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len()!=REQUEST_BYTES || bytes[..16]!=PROFILE { return Err("invalid private request encoding"); }
        let hash=|at|bytes[at..at+32].try_into().unwrap();
        let mut input=[0;ELEMENTS];
        for (v,b) in input.iter_mut().zip(bytes[112..].chunks_exact(2)) { *v=i16::from_le_bytes(b.try_into().unwrap()); }
        Ok(Self {context:hash(16),input_salt:hash(48),output_salt:hash(80),input})
    }
    pub fn encode(&self) -> [u8;REQUEST_BYTES] {
        let mut bytes=[0;REQUEST_BYTES];
        bytes[..16].copy_from_slice(&PROFILE);
        bytes[16..48].copy_from_slice(&self.context);
        bytes[48..80].copy_from_slice(&self.input_salt);
        bytes[80..112].copy_from_slice(&self.output_salt);
        for (b,v) in bytes[112..].chunks_exact_mut(2).zip(self.input) { b.copy_from_slice(&v.to_le_bytes()); }
        bytes
    }
    pub fn compute(&self, model: &Model) -> Result<(Statement,[i16;ELEMENTS]), &'static str> {
        let output=run_block(&self.input,&model.weights,&model.tables,None)
            .map_err(|_|"block computation refused input")?;
        let input=endpoint(Role::Input,&self.context,&model.digest,&self.input_salt,&self.input)?;
        let out=endpoint(Role::Output,&self.context,&model.digest,&self.output_salt,&output)?;
        Ok((Statement {context:self.context,model:model.digest,input,output:out}, output))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn request_length_and_profile_are_strict() {
        let r=Request {context:[1;32],input_salt:[2;32],output_salt:[3;32],input:[-32768;ELEMENTS]};
        let b=r.encode(); let d=Request::decode(&b).unwrap();
        assert_eq!(d.context,r.context); assert_eq!(d.input_salt,r.input_salt);
        assert_eq!(d.output_salt,r.output_salt); assert_eq!(d.input,r.input);
        for n in 0..REQUEST_BYTES { assert!(Request::decode(&b[..n]).is_err()); }
        let mut extra=b.to_vec();extra.push(0);assert!(Request::decode(&extra).is_err());
        let mut wrong=b;wrong[0]^=1;assert!(Request::decode(&wrong).is_err());
    }
    #[test]
    fn model_parser_refuses_bad_lengths_and_invalid_tables() {
        for n in [0,7,8,MODEL_BYTES-1,MODEL_BYTES+1] { assert!(Model::decode(&vec![0;n]).is_err()); }
        let mut b=vec![0;MODEL_BYTES];b[..8].copy_from_slice(&MODEL_MAGIC);
        assert!(Model::decode(&b).is_err()); // RoPE and exp at zero must equal one.
    }
}
