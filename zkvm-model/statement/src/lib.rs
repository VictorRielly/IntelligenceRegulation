//! Public statement and hiding token endpoint handles for the experimental
//! zkVM TOKEN-MODEL profile. This profile is separately versioned: it does not
//! accept or replace the complete-block profile (`zk60-r0-block-v1`) or the
//! hashline PCS endpoint format, and none of its hashes can collide with theirs
//! by domain. The caller must authenticate its policy independently of the
//! candidate receipt.

use sha2::{Digest, Sha256};

pub const PROFILE: [u8; 16] = *b"zk60-r0-token-v1";
pub const JOURNAL_BYTES: usize = 16 + 4 * 32;
/// Exact number of private token IDs bound by the input endpoint.
pub const INPUT_TOKENS: usize = 32;
/// Exact number of private token IDs bound by the output endpoint.
pub const OUTPUT_TOKENS: usize = 1;
pub type Hash = [u8; 32];

const MODEL_DOMAIN: &[u8] = b"zk60-r0-token-model-v1\0";
const ENDPOINT_DOMAIN: &[u8] = b"zk60-r0-token-endpoint-v1\0";

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Role { Input, Output }

impl Role {
    /// The only token count this role's endpoint accepts.
    pub const fn count(self) -> usize {
        match self {Role::Input => INPUT_TOKENS, Role::Output => OUTPUT_TOKENS}
    }
    const fn tag(self) -> u8 {
        match self {Role::Input => 0, Role::Output => 1}
    }
}

/// Public data only. Neither the endpoint salts nor any token belong here.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Statement {
    pub context: Hash,
    pub model: Hash,
    pub input: Hash,
    pub output: Hash,
}

impl Statement {
    pub fn encode(&self) -> [u8; JOURNAL_BYTES] {
        let mut bytes = [0; JOURNAL_BYTES];
        bytes[..16].copy_from_slice(&PROFILE);
        for (chunk, value) in bytes[16..].chunks_exact_mut(32)
            .zip([self.context, self.model, self.input, self.output]) {
            chunk.copy_from_slice(&value);
        }
        bytes
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() != JOURNAL_BYTES || bytes[..16] != PROFILE {
            return Err("unsupported statement profile or length");
        }
        let hash = |at| bytes[at..at+32].try_into().unwrap();
        Ok(Self {context: hash(16), model: hash(48), input: hash(80), output: hash(112)})
    }

    pub fn check_journal(&self, journal: &[u8]) -> Result<(), &'static str> {
        // Compare the exact authenticated statement, not fields recovered from a proof.
        if journal != self.encode() { return Err("receipt differs from expected policy"); }
        Ok(())
    }
}

/// SHA-256 binding of the COMPLETE canonical public token-model payload
/// (embeddings, both block payloads with their lookup tables, final gamma and
/// head). Interpretation and shape validation are the pinned guest program's
/// responsibility; context length, vocabulary, layer count, calibration and
/// the tie rule are fixed by that image, not by this digest.
pub fn model_digest(canonical_model: &[u8]) -> Hash {
    let mut h = Sha256::new();
    h.update(MODEL_DOMAIN);
    h.update(PROFILE);
    h.update((canonical_model.len() as u64).to_le_bytes());
    h.update(canonical_model);
    h.finalize().into()
}

/// A separately versioned salted token endpoint commitment. The salt is secret
/// and MUST be independently sampled from 32 OS-random bytes during
/// preparation, separately for the input and the output endpoint. The output
/// endpoint hides one of only 32 values, so its hiding rests entirely on that
/// salt staying secret and never being reused for another value.
/// Reusing a caller-fixed endpoint binds the same value across repeated proofs;
/// it is not permission to publish the opening or to replace the expected root.
/// Token range is the model relation's rule, not this commitment's.
pub fn endpoint(role: Role, context: &Hash, model: &Hash, salt: &Hash,
                tokens: &[u32]) -> Result<Hash, &'static str> {
    if tokens.len() != role.count() { return Err("unsupported endpoint token count"); }
    let mut h = Sha256::new();
    h.update(ENDPOINT_DOMAIN);
    h.update(PROFILE);
    h.update([role.tag()]);
    h.update(context);
    h.update(model);
    h.update(salt);
    h.update((tokens.len() as u32).to_le_bytes());
    for t in tokens { h.update(t.to_le_bytes()); }
    Ok(h.finalize().into())
}

/// Fixed PUBLIC layout-test cases `(input tokens, output token, model payload)`
/// shared by the unit test and `examples/zk60_token_vectors.rs`. The output
/// token is deliberately out of vocabulary to expose all four little-endian bytes.
#[doc(hidden)]
pub fn vector_cases() -> ([u32; INPUT_TOKENS], u32, [u8; 1000]) {
    (core::array::from_fn(|i| (i as u32*7+3)%32), 0x0102_0311,
     core::array::from_fn(|i| (i%251) as u8))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profile_is_new_and_sizes_are_exact() {
        assert_eq!(PROFILE.len(), 16);
        assert_ne!(&PROFILE, b"zk60-r0-block-v1");
        assert_eq!(JOURNAL_BYTES, 144);
        assert_eq!((Role::Input.count(), Role::Output.count()), (32, 1));
    }

    #[test]
    fn policy_is_exact_and_cannot_be_derived_from_candidate_journal() {
        let p = Statement {context:[1;32], model:[2;32], input:[3;32], output:[4;32]};
        let b = p.encode();
        assert_eq!(&b[..16], b"zk60-r0-token-v1");
        assert_eq!((&b[16..48], &b[48..80], &b[80..112], &b[112..]),
                   (&[1u8;32][..], &[2u8;32][..], &[3u8;32][..], &[4u8;32][..]));
        assert_eq!(Statement::decode(&b).unwrap(), p);
        p.check_journal(&b).unwrap();
        for at in 0..b.len() {
            let mut wrong=b;
            wrong[at]^=1;
            assert!(p.check_journal(&wrong).is_err());
            // Any well-formed different policy decodes to a different statement.
            if at >= 16 { assert_ne!(Statement::decode(&wrong).unwrap(), p); }
            else { assert!(Statement::decode(&wrong).is_err()); }
        }
        for len in 0..b.len() {
            assert!(Statement::decode(&b[..len]).is_err());
            assert!(p.check_journal(&b[..len]).is_err());
        }
        let mut long=b.to_vec(); long.push(0);
        assert!(Statement::decode(&long).is_err());
        assert!(p.check_journal(&long).is_err());
        // The complete-block profile's policy is refused here.
        let mut block=b; block[..16].copy_from_slice(b"zk60-r0-block-v1");
        assert!(Statement::decode(&block).is_err());
    }

    #[test]
    fn each_endpoint_binds_role_context_model_salt_and_every_token() {
        let tokens=[7u32; INPUT_TOKENS];
        let original=endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&tokens).unwrap();
        for change in 0..3 {
            for at in 0..32 {
                let mut args=[[1;32],[2;32],[3;32]];
                args[change][at]^=1;
                assert_ne!(original,endpoint(Role::Input,&args[0],&args[1],&args[2],&tokens).unwrap());
            }
        }
        for i in 0..INPUT_TOKENS {
            for bit in [0,8,16,31] {
                let mut wrong=tokens; wrong[i]^=1<<bit;
                assert_ne!(original,endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&wrong).unwrap());
            }
        }
        let out=endpoint(Role::Output,&[1;32],&[2;32],&[3;32],&[7]).unwrap();
        assert_ne!(out,original);
        assert_ne!(out,endpoint(Role::Output,&[1;32],&[2;32],&[3;32],&[8]).unwrap());
        assert_ne!(out,endpoint(Role::Output,&[1;32],&[2;32],&[4;32],&[7]).unwrap());
    }

    #[test]
    fn role_sizes_are_exact_and_separated() {
        let t=[0u32; INPUT_TOKENS+1];
        for n in 0..=INPUT_TOKENS+1 {
            assert_eq!(endpoint(Role::Input,&[0;32],&[0;32],&[0;32],&t[..n]).is_ok(), n==INPUT_TOKENS);
            assert_eq!(endpoint(Role::Output,&[0;32],&[0;32],&[0;32],&t[..n]).is_ok(), n==OUTPUT_TOKENS);
        }
    }

    #[test]
    fn encoding_is_explicit_little_endian_and_domain_separated() {
        // The documented layout written out as one explicit byte string. The
        // same three cases are printed by `examples/zk60_token_vectors.rs` and by
        // the independent hashlib script `../reference/reference_vectors.py`;
        // the parent compares those two outputs (no vector is pinned here
        // because none was computed independently when this was written).
        let (input_tokens,output_token,payload)=vector_cases();
        let input=endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&input_tokens).unwrap();
        let mut m=b"zk60-r0-token-endpoint-v1\0zk60-r0-token-v1".to_vec();
        m.push(0);
        m.extend([1u8;32]); m.extend([2u8;32]); m.extend([3u8;32]);
        m.extend([32,0,0,0]);
        for t in &input_tokens { m.extend([*t as u8,0,0,0]); }
        assert_eq!(m.len(), 26+16+1+96+4+128);
        assert_eq!(input, <Hash>::from(Sha256::digest(&m)));

        let output=endpoint(Role::Output,&[1;32],&[2;32],&[4;32],&[output_token]).unwrap();
        let mut m=b"zk60-r0-token-endpoint-v1\0zk60-r0-token-v1".to_vec();
        m.push(1);
        m.extend([1u8;32]); m.extend([2u8;32]); m.extend([4u8;32]);
        m.extend([1,0,0,0]);
        m.extend([0x11,0x03,0x02,0x01]);
        assert_eq!(output, <Hash>::from(Sha256::digest(&m)));

        let mut m=b"zk60-r0-token-model-v1\0zk60-r0-token-v1".to_vec();
        m.extend([0xe8,0x03,0,0,0,0,0,0]);
        m.extend(&payload);
        assert_eq!(model_digest(&payload), <Hash>::from(Sha256::digest(&m)));
        assert_ne!(model_digest(b"a"),model_digest(b"a\0"));
        // Domains differ from each other and from the complete-block profile.
        assert_ne!(MODEL_DOMAIN,ENDPOINT_DOMAIN);
        assert!(!MODEL_DOMAIN.starts_with(b"zk60-r0-block") && !ENDPOINT_DOMAIN.starts_with(b"zk60-r0-block"));
    }
}
