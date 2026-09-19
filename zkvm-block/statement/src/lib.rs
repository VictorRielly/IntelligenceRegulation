//! Public statement and hiding endpoint handles for the experimental zkVM profile.
//! This profile does not accept or replace the hashline PCS endpoint format.
//! The caller must authenticate its policy independently of the candidate receipt.

use sha2::{Digest, Sha256};

pub const PROFILE: [u8; 16] = *b"zk60-r0-block-v1";
pub const JOURNAL_BYTES: usize = 16 + 4 * 32;
pub const ELEMENTS: usize = 32 * 16;
pub type Hash = [u8; 32];

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Role { Input, Output }

/// Public data only. Neither the endpoint salts nor raw tensors belong here.
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

/// SHA-256 binding of the COMPLETE canonical public model/calibration payload.
/// Interpretation and shape validation are the pinned guest program's responsibility.
pub fn model_digest(canonical_model: &[u8]) -> Hash {
    let mut h = Sha256::new();
    h.update(b"zk60-r0-block-model-v1\0");
    h.update(PROFILE);
    h.update((canonical_model.len() as u64).to_le_bytes());
    h.update(canonical_model);
    h.finalize().into()
}

/// A separately versioned salted endpoint commitment. The salt is secret and
/// MUST be independently sampled from 32 OS-random bytes during preparation.
/// Reusing a caller-fixed endpoint binds the same value across repeated proofs;
/// it is not permission to publish the opening or to replace the expected root.
pub fn endpoint(role: Role, context: &Hash, model: &Hash, salt: &Hash,
                values: &[i16]) -> Result<Hash, &'static str> {
    if values.len() != ELEMENTS { return Err("unsupported endpoint shape"); }
    let mut h = Sha256::new();
    h.update(b"zk60-r0-block-endpoint-v1\0");
    h.update(PROFILE);
    h.update([match role {Role::Input => 0, Role::Output => 1}]);
    h.update(context);
    h.update(model);
    h.update(salt);
    h.update((ELEMENTS as u32).to_le_bytes());
    for v in values { h.update(v.to_le_bytes()); }
    Ok(h.finalize().into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn policy_is_exact_and_cannot_be_derived_from_candidate_journal() {
        let p = Statement {context:[1;32], model:[2;32], input:[3;32], output:[4;32]};
        let b = p.encode();
        assert_eq!(Statement::decode(&b).unwrap(), p);
        p.check_journal(&b).unwrap();
        for at in 0..b.len() {
            let mut wrong=b;
            wrong[at]^=1;
            assert!(p.check_journal(&wrong).is_err());
        }
        for len in 0..b.len() { assert!(Statement::decode(&b[..len]).is_err()); }
        let mut long=b.to_vec(); long.push(0);
        assert!(Statement::decode(&long).is_err());
        let mut bad=b; bad[0]^=1;
        assert!(Statement::decode(&bad).is_err());
    }

    #[test]
    fn each_endpoint_binds_role_context_model_salt_and_every_element() {
        let values=vec![-3; ELEMENTS];
        let original=endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&values).unwrap();
        assert_ne!(original,endpoint(Role::Output,&[1;32],&[2;32],&[3;32],&values).unwrap());
        for change in 0..3 {
            let mut args=[[1;32],[2;32],[3;32]];
            args[change][17]^=1;
            assert_ne!(original,endpoint(Role::Input,&args[0],&args[1],&args[2],&values).unwrap());
        }
        for i in 0..ELEMENTS {
            let mut wrong=values.clone(); wrong[i]+=1;
            assert_ne!(original,endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&wrong).unwrap());
        }
        assert!(endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&values[..ELEMENTS-1]).is_err());
    }

    #[test]
    fn encoding_is_explicit_little_endian_and_domain_separated() {
        let values:Vec<i16>=(0..ELEMENTS).map(|i| i as i16-256).collect();
        let got=endpoint(Role::Input,&[1;32],&[2;32],&[3;32],&values).unwrap();
        // Independent Python hashlib test vector for the documented byte layout.
        assert_eq!(got, [0xa6,0x27,0x70,0xdd,0xe6,0x86,0x02,0xc7,0xab,0x4a,0x89,0xa9,0xfa,0x54,0x1d,0x20,0xd8,0xff,0xa7,0x3b,0xfe,0x75,0xf8,0xd6,0xdc,0x9a,0x5c,0x14,0xaf,0xa6,0x6a,0xa6]);
        assert_ne!(got,model_digest(&values.iter().flat_map(|v|v.to_le_bytes()).collect::<Vec<_>>()));
        assert_ne!(model_digest(b"a"),model_digest(b"a\0"));
    }
}
