//! Bounded, canonical public token-model and private request encoding for the
//! fixed SYNTHETIC-scale token model (context 32, vocabulary 32, width 16, two
//! sequential blocks, final norm, signed head, lowest-index greedy token).
//! Context length, vocabulary, layer count, calibration and the tie rule are
//! fixed by the verifier's trusted program image, not by the model file.
//! Every value is recomputed from the raw public words and the private tokens;
//! no claimed intermediate, logit or token is consumed.
use private_model_kernel::{next_token, ModelError, PublicModel, RawBlock, RawModel,
    CTX, D, LAYERS, ROPE_LEN, TABLE_LEN, VOCAB};
use zk60_token_statement::{endpoint, model_digest, Hash, Role, Statement, INPUT_TOKENS, PROFILE};

pub const MODEL_MAGIC: [u8; 8] = *b"Z60TOK01";
/// Magic of each embedded complete legacy block-model payload.
pub const BLOCK_MAGIC: [u8; 8] = *b"Z60MDL01";
pub const BLOCK_BYTES: usize = 8 + 1568 + (ROPE_LEN * 2 + 256) * 8 + 256 * 2;
pub const MODEL_BYTES: usize = 8 + TABLE_LEN * 2 + LAYERS * BLOCK_BYTES + D + TABLE_LEN;
pub const INPUT_BYTES: usize = CTX * 4;
pub const OUTPUT_BYTES: usize = 4;
pub const REQUEST_BYTES: usize = 16 + 32 * 3 + INPUT_BYTES;

// The image fixes these; a kernel or statement change must not silently
// change the wire format of this profile.
const _: () = assert!(BLOCK_BYTES == 6184 && MODEL_BYTES == 13928 && REQUEST_BYTES == 240
    && INPUT_BYTES == 128 && CTX == INPUT_TOKENS && VOCAB == 32 && LAYERS == 2 && D == 16);

struct Reader<'a>(&'a [u8]);

impl<'a> Reader<'a> {
    // Callers check the total length first, so `split_at` cannot go out of range.
    fn bytes(&mut self, n: usize) -> &'a [u8] {
        let (head, rest) = self.0.split_at(n);
        self.0 = rest;
        head
    }
    fn i8s<const N: usize>(&mut self) -> [i8; N] {
        let b = self.bytes(N);
        core::array::from_fn(|i| b[i] as i8)
    }
    fn i16s<const N: usize>(&mut self) -> [i16; N] {
        let b = self.bytes(N * 2);
        core::array::from_fn(|i| i16::from_le_bytes(b[i*2..i*2+2].try_into().unwrap()))
    }
    fn i64s<const N: usize>(&mut self) -> [i64; N] {
        let b = self.bytes(N * 8);
        core::array::from_fn(|i| i64::from_le_bytes(b[i*8..i*8+8].try_into().unwrap()))
    }
}

/// One complete legacy `Z60MDL01` payload: nine signed-byte weight arrays in
/// kernel order, RoPE cosine/sine and exp tables as little-endian i64, SiLU
/// table as little-endian i16. Framing only; structure is checked by `build`.
fn decode_block(bytes: &[u8]) -> Result<RawBlock, &'static str> {
    if bytes.len()!=BLOCK_BYTES || bytes[..8]!=BLOCK_MAGIC { return Err("invalid public block encoding"); }
    let mut r=Reader(&bytes[8..]);
    let block=RawBlock {wq:r.i8s(),wk:r.i8s(),wv:r.i8s(),wo:r.i8s(),gamma_a:r.i8s(),gamma_m:r.i8s(),
        wg_t:r.i8s(),wu_t:r.i8s(),wd_t:r.i8s(),
        rope_cos:r.i64s(),rope_sin:r.i64s(),exp:r.i64s(),act:r.i16s()};
    if !r.0.is_empty() { return Err("invalid public block encoding"); }
    Ok(block)
}

/// Framing only: magic `Z60TOK01`, embeddings, two block payloads in execution
/// order, final gamma, head. Every fixed-width word is accepted here, so the
/// encoding of a decoded model is the original byte string.
pub fn decode_raw(bytes: &[u8]) -> Result<RawModel, &'static str> {
    if bytes.len()!=MODEL_BYTES || bytes[..8]!=MODEL_MAGIC { return Err("invalid public model encoding"); }
    let mut r=Reader(&bytes[8..]);
    let embed=r.i16s();
    let blocks=[decode_block(r.bytes(BLOCK_BYTES))?,decode_block(r.bytes(BLOCK_BYTES))?];
    let raw=RawModel {embed,blocks,gamma_f:r.i8s(),head:r.i8s()};
    if !r.0.is_empty() { return Err("invalid public model encoding"); }
    Ok(raw)
}

/// Canonical encoding of raw public words (exporters and tests).
pub fn encode_raw(raw: &RawModel) -> Vec<u8> {
    let mut b=Vec::with_capacity(MODEL_BYTES);
    let i8s=|b:&mut Vec<u8>,w:&[i8]| b.extend(w.iter().map(|v| *v as u8));
    b.extend(MODEL_MAGIC);
    for v in raw.embed { b.extend(v.to_le_bytes()); }
    for k in &raw.blocks {
        b.extend(BLOCK_MAGIC);
        for w in [&k.wq[..],&k.wk,&k.wv,&k.wo,&k.gamma_a,&k.gamma_m,&k.wg_t,&k.wu_t,&k.wd_t] { i8s(&mut b,w); }
        for t in [&k.rope_cos[..],&k.rope_sin,&k.exp] { for v in t { b.extend(v.to_le_bytes()); } }
        for v in k.act { b.extend(v.to_le_bytes()); }
    }
    i8s(&mut b,&raw.gamma_f);
    i8s(&mut b,&raw.head);
    assert_eq!(b.len(),MODEL_BYTES);
    b
}

pub struct Model { pub public: PublicModel, pub digest: Hash }

impl Model {
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        let public=decode_raw(bytes)?.build().map_err(|e| match e {
            ModelError::Layer(0,_)=>"invalid public block 0 weights or lookup tables",
            ModelError::Layer(_,_)=>"invalid public block 1 weights or lookup tables",
            _=>"invalid public model shape",
        })?;
        Ok(Self {public,digest:model_digest(bytes)})
    }
}

/// Exactly 32 little-endian u32 token IDs, each inside the fixed vocabulary.
/// Which token is invalid is not reported.
pub fn tokens_from_bytes(bytes: &[u8]) -> Result<[u32; CTX], &'static str> {
    if bytes.len()!=INPUT_BYTES { return Err("input must contain exactly 32 little-endian u32 token ids"); }
    let mut tokens=[0;CTX];
    for (t,b) in tokens.iter_mut().zip(bytes.chunks_exact(4)) { *t=u32::from_le_bytes(b.try_into().unwrap()); }
    if tokens.iter().any(|t| *t as usize>=VOCAB) { return Err("token id outside vocabulary"); }
    Ok(tokens)
}

// Intentionally no Debug/Serialize: all fields below are local secrets except context.
pub struct Request {
    pub context: Hash,
    pub input_salt: Hash,
    pub output_salt: Hash,
    pub tokens: [u32; CTX],
}

impl Request {
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len()!=REQUEST_BYTES || bytes[..16]!=PROFILE { return Err("invalid private request encoding"); }
        let hash=|at|bytes[at..at+32].try_into().unwrap();
        let tokens=tokens_from_bytes(&bytes[112..]).map_err(|_|"invalid private request encoding")?;
        Ok(Self {context:hash(16),input_salt:hash(48),output_salt:hash(80),tokens})
    }
    pub fn encode(&self) -> [u8;REQUEST_BYTES] {
        let mut bytes=[0;REQUEST_BYTES];
        bytes[..16].copy_from_slice(&PROFILE);
        bytes[16..48].copy_from_slice(&self.context);
        bytes[48..80].copy_from_slice(&self.input_salt);
        bytes[80..112].copy_from_slice(&self.output_salt);
        for (b,t) in bytes[112..].chunks_exact_mut(4).zip(self.tokens) { b.copy_from_slice(&t.to_le_bytes()); }
        bytes
    }
    /// Recomputes the single greedy next token and both salted endpoints.
    /// The returned token is a local secret.
    pub fn compute(&self, model: &Model) -> Result<(Statement,u32), &'static str> {
        let token=next_token(&self.tokens,&model.public)
            .map_err(|_|"token model computation refused request")?;
        let input=endpoint(Role::Input,&self.context,&model.digest,&self.input_salt,&self.tokens)?;
        let output=endpoint(Role::Output,&self.context,&model.digest,&self.output_salt,&[token])?;
        Ok((Statement {context:self.context,model:model.digest,input,output}, token))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use private_model_kernel::{next_token_traced, synthetic::{synthetic_model, synthetic_raw_model}, ModelTrace, PublicBlock};

    const BLOCK0: usize = 8 + TABLE_LEN * 2;
    const BLOCK1: usize = BLOCK0 + BLOCK_BYTES;
    const GAMMA: usize = BLOCK1 + BLOCK_BYTES;
    const HEAD: usize = GAMMA + D;

    // SYNTHETIC-ONLY words; their lookup tables are not a registered calibration.
    fn synthetic_bytes() -> Vec<u8> { encode_raw(&synthetic_raw_model()) }
    fn sequence(seed: u32) -> [u32; CTX] {
        core::array::from_fn(|i| (seed.wrapping_mul(2654435761).wrapping_add(i as u32*40503)>>7)%VOCAB as u32)
    }
    fn request(seed: u32) -> Request {
        Request {context:[1;32],input_salt:[2;32],output_salt:[3;32],tokens:sequence(seed)}
    }

    #[test]
    fn layout_offsets_and_sizes_are_exact() {
        assert_eq!((BLOCK0,BLOCK1,GAMMA,HEAD,MODEL_BYTES),(1032,7216,13400,13416,13928));
        let b=synthetic_bytes();
        assert_eq!(b.len(),13928);
        assert_eq!(&b[..8],b"Z60TOK01");
        assert_eq!(&b[BLOCK0..BLOCK0+8],b"Z60MDL01");
        assert_eq!(&b[BLOCK1..BLOCK1+8],b"Z60MDL01");
        let raw=synthetic_raw_model();
        assert_eq!(b[8..10],raw.embed[0].to_le_bytes());
        assert_eq!(b[GAMMA] as i8,raw.gamma_f[0]);
        assert_eq!(b[HEAD+5] as i8,-128);
        assert_eq!(b[MODEL_BYTES-1] as i8,raw.head[TABLE_LEN-1]);
    }

    #[test]
    fn model_roundtrip_is_canonical_and_computes_like_the_kernel_model() {
        let b=synthetic_bytes();
        assert_eq!(encode_raw(&decode_raw(&b).unwrap()),b);
        let model=Model::decode(&b).unwrap();
        assert_eq!(model.digest,model_digest(&b));
        let direct=synthetic_model().unwrap();
        for seed in 0..24 {
            let t=sequence(seed);
            assert_eq!(next_token(&t,&model.public).unwrap(),next_token(&t,&direct).unwrap());
        }
        // Every full-range word survives, so there is one encoding per model.
        let mut extreme=b.clone();
        for at in (8..BLOCK0).chain(GAMMA..MODEL_BYTES) { extreme[at]=if at%3==0 {0x80} else {0xff}; }
        assert_eq!(encode_raw(&decode_raw(&extreme).unwrap()),extreme);
    }

    #[test]
    fn embedded_blocks_are_complete_legacy_payloads_with_the_same_meaning() {
        assert_eq!(zk60_block_model::MODEL_BYTES,BLOCK_BYTES);
        assert_eq!(zk60_block_model::MODEL_MAGIC,BLOCK_MAGIC);
        let b=synthetic_bytes();
        let raw=synthetic_raw_model();
        let legacy=|at:usize| {
            let m=zk60_block_model::Model::decode(&b[at..at+BLOCK_BYTES]).unwrap();
            PublicBlock {weights:m.weights,tables:m.tables}
        };
        let via_legacy=PublicModel::from_parts(&raw.embed,legacy(BLOCK0),legacy(BLOCK1),&raw.gamma_f,&raw.head).unwrap();
        let model=Model::decode(&b).unwrap();
        for seed in 0..24 {
            let t=sequence(seed);
            let (mut x,mut y)=(ModelTrace::zeroed(),ModelTrace::zeroed());
            let a=next_token_traced(&t,&model.public,Some(&mut x)).unwrap();
            assert_eq!(a,next_token_traced(&t,&via_legacy,Some(&mut y)).unwrap());
            assert!(x.layer0==y.layer0 && x.layer1==y.layer1 && x.logits==y.logits);
        }
        // The two formats refuse each other's files.
        assert!(zk60_block_model::Model::decode(&b).is_err());
        assert!(Model::decode(&b[BLOCK0..BLOCK1]).is_err());
    }

    #[test]
    fn model_parser_refuses_malformed_encodings() {
        let b=synthetic_bytes();
        for n in [0,7,8,BLOCK_BYTES,MODEL_BYTES-1] { assert!(Model::decode(&b[..n]).is_err()); }
        let mut long=b.clone();long.push(0);assert!(Model::decode(&long).is_err());
        for at in (0..8).chain(BLOCK0..BLOCK0+8).chain(BLOCK1..BLOCK1+8) {
            let mut wrong=b.clone();wrong[at]^=1;
            assert!(Model::decode(&wrong).is_err());
            assert!(decode_raw(&wrong).is_err());
        }
        let mut legacy_magic=b.clone();legacy_magic[..8].copy_from_slice(&BLOCK_MAGIC);
        assert!(Model::decode(&legacy_magic).is_err());
        // Correct framing with structurally invalid lookup tables (RoPE and exp
        // at zero must equal one) names the refusing block.
        let zeroed=|at:usize| { let mut z=b.clone(); z[at+8..at+BLOCK_BYTES].fill(0); Model::decode(&z).err() };
        assert_eq!(zeroed(BLOCK0),Some("invalid public block 0 weights or lookup tables"));
        assert_eq!(zeroed(BLOCK1),Some("invalid public block 1 weights or lookup tables"));
        let mut empty=vec![0;MODEL_BYTES];empty[..8].copy_from_slice(&MODEL_MAGIC);
        assert!(Model::decode(&empty).is_err());
    }

    #[test]
    fn digest_binds_every_region_and_block_order() {
        let b=synthetic_bytes();
        let digest=model_digest(&b);
        for at in (0..MODEL_BYTES).step_by(61).chain([8,BLOCK0-1,BLOCK0,BLOCK1-1,BLOCK1,GAMMA-1,GAMMA,HEAD-1,HEAD,MODEL_BYTES-1]) {
            let mut wrong=b.clone();wrong[at]^=0x10;
            assert_ne!(model_digest(&wrong),digest);
        }
        let mut swapped=b.clone();
        swapped[BLOCK0..BLOCK1].copy_from_slice(&b[BLOCK1..GAMMA]);
        swapped[BLOCK1..GAMMA].copy_from_slice(&b[BLOCK0..BLOCK1]);
        assert_ne!(swapped,b);
        assert_ne!(Model::decode(&swapped).unwrap().digest,digest);
        assert_ne!(model_digest(&b[..MODEL_BYTES-1]),digest);
    }

    #[test]
    fn request_length_profile_and_token_range_are_strict() {
        let mut r=request(5);
        r.tokens[0]=0;r.tokens[CTX-1]=31;
        let b=r.encode();
        assert_eq!(b.len(),240);
        assert_eq!(&b[..16],b"zk60-r0-token-v1");
        assert_eq!(b[236..],[31,0,0,0]);
        let d=Request::decode(&b).unwrap();
        assert_eq!(d.context,r.context); assert_eq!(d.input_salt,r.input_salt);
        assert_eq!(d.output_salt,r.output_salt); assert_eq!(d.tokens,r.tokens);
        assert_eq!(d.encode(),b);
        for n in 0..REQUEST_BYTES { assert!(Request::decode(&b[..n]).is_err()); }
        let mut extra=b.to_vec();extra.push(0);assert!(Request::decode(&extra).is_err());
        let mut wrong=b;wrong[0]^=1;assert!(Request::decode(&wrong).is_err());
        let mut block=b;block[..16].copy_from_slice(b"zk60-r0-block-v1");assert!(Request::decode(&block).is_err());
        let model=Model::decode(&synthetic_bytes()).unwrap();
        for at in [0,1,17,CTX-1] {
            // 256 and 2^24 have a valid low byte: all four bytes are read.
            for bad in [32,33,256,1<<24,u32::MAX] {
                let mut invalid=request(5);invalid.tokens[at]=bad;
                assert!(Request::decode(&invalid.encode()).is_err());
                assert!(invalid.compute(&model).is_err());
            }
        }
    }

    #[test]
    fn owner_input_is_exactly_128_bytes_of_valid_tokens() {
        let bytes:Vec<u8>=sequence(9).iter().flat_map(|t| t.to_le_bytes()).collect();
        assert_eq!(tokens_from_bytes(&bytes).unwrap(),sequence(9));
        for n in [0,4,127,129,256] { assert!(tokens_from_bytes(&vec![0;n]).is_err()); }
        for at in 0..INPUT_BYTES {
            let mut wrong=bytes.clone();
            wrong[at]=if at%4==0 {32} else {1};
            assert!(tokens_from_bytes(&wrong).is_err());
        }
    }

    #[test]
    fn statement_binds_context_model_salts_roles_tokens_and_output() {
        let bytes=synthetic_bytes();
        let model=Model::decode(&bytes).unwrap();
        let r=request(11);
        let (s,token)=r.compute(&model).unwrap();
        assert_eq!(token,next_token(&r.tokens,&synthetic_model().unwrap()).unwrap());
        assert!((token as usize)<VOCAB);
        assert_eq!(s.context,r.context);
        assert_eq!(s.model,model_digest(&bytes));
        assert_eq!(s.input,endpoint(Role::Input,&r.context,&s.model,&r.input_salt,&r.tokens).unwrap());
        assert_eq!(s.output,endpoint(Role::Output,&r.context,&s.model,&r.output_salt,&[token]).unwrap());
        assert_eq!(Statement::decode(&s.encode()).unwrap(),s);

        let mut c=request(11);c.context[31]^=1;
        let (sc,_)=c.compute(&model).unwrap();
        assert!(sc.context!=s.context && sc.model==s.model && sc.input!=s.input && sc.output!=s.output);
        let mut i=request(11);i.input_salt[0]^=1;
        let (si,_)=i.compute(&model).unwrap();
        assert!(si.input!=s.input && si.output==s.output);
        let mut o=request(11);o.output_salt[0]^=1;
        let (so,_)=o.compute(&model).unwrap();
        assert!(so.input==s.input && so.output!=s.output);
        // Roles are separated even under equal salts.
        let mut same=request(11);same.output_salt=same.input_salt;
        let (ss,_)=same.compute(&model).unwrap();
        assert_ne!(ss.input,ss.output);
        for at in 0..CTX {
            let mut t=request(11);t.tokens[at]=(t.tokens[at]+1)%VOCAB as u32;
            let (st,_)=t.compute(&model).unwrap();
            assert!(st.input!=s.input && st.context==s.context && st.model==s.model);
        }
        // A different public model changes the digest and therefore both endpoints.
        let mut other=bytes.clone();other[HEAD]^=1;
        let (sm,_)=r.compute(&Model::decode(&other).unwrap()).unwrap();
        assert!(sm.model!=s.model && sm.input!=s.input && sm.output!=s.output);
    }

    #[test]
    fn output_endpoint_follows_the_recomputed_token() {
        // The committed output opens to the kernel's token and to no other ID.
        let model=Model::decode(&synthetic_bytes()).unwrap();
        let direct=synthetic_model().unwrap();
        for seed in 0..64 {
            let r=request(seed);
            let (s,token)=r.compute(&model).unwrap();
            assert_eq!(token,next_token(&r.tokens,&direct).unwrap());
            for wrong in 0..VOCAB as u32 {
                let e=endpoint(Role::Output,&r.context,&s.model,&r.output_salt,&[wrong]).unwrap();
                assert_eq!(e==s.output,wrong==token);
            }
        }
    }
}
