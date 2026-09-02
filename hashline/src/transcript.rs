//! Fiat-Shamir transcript over blake3: a 32-byte running state; every
//! absorbed message is domain-labelled; challenges are derived from the
//! state and a counter and fold back into the state.

use crate::field::{Fp, Fp2, P};

pub struct Transcript {
    state: [u8; 32],
    counter: u64,
}

impl Transcript {
    pub fn new(domain: &[u8]) -> Transcript {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-v1/");
        h.update(domain);
        Transcript { state: *h.finalize().as_bytes(), counter: 0 }
    }

    pub fn absorb(&mut self, label: &[u8], data: &[u8]) {
        let mut h = blake3::Hasher::new();
        h.update(&self.state);
        h.update(&(label.len() as u64).to_le_bytes());
        h.update(label);
        h.update(&(data.len() as u64).to_le_bytes());
        h.update(data);
        self.state = *h.finalize().as_bytes();
    }

    pub fn absorb_u64(&mut self, label: &[u8], v: u64) {
        self.absorb(label, &v.to_le_bytes());
    }

    pub fn absorb_fp(&mut self, label: &[u8], vals: &[Fp]) {
        let mut bytes = Vec::with_capacity(vals.len() * 8);
        for v in vals {
            bytes.extend_from_slice(&v.to_bytes());
        }
        self.absorb(label, &bytes);
    }

    pub fn absorb_fp2(&mut self, label: &[u8], vals: &[Fp2]) {
        let mut bytes = Vec::with_capacity(vals.len() * 16);
        for v in vals {
            bytes.extend_from_slice(&v.to_bytes());
        }
        self.absorb(label, &bytes);
    }

    fn squeeze_bytes(&mut self) -> [u8; 32] {
        let mut h = blake3::Hasher::new();
        h.update(&self.state);
        h.update(b"squeeze");
        h.update(&self.counter.to_le_bytes());
        self.counter += 1;
        let out = *h.finalize().as_bytes();
        self.state = out;
        out
    }

    /// A base-field challenge (128 bits reduced mod p: bias 2^-64).
    pub fn challenge_fp(&mut self) -> Fp {
        let b = self.squeeze_bytes();
        Fp::from_u128(u128::from_le_bytes(b[..16].try_into().unwrap()))
    }

    /// An extension-field challenge (two independent 128-bit draws).
    pub fn challenge_fp2(&mut self) -> Fp2 {
        let b = self.squeeze_bytes();
        let c0 = Fp::from_u128(u128::from_le_bytes(b[..16].try_into().unwrap()));
        let c1 = Fp::from_u128(u128::from_le_bytes(b[16..].try_into().unwrap()));
        Fp2::new(c0, c1)
    }

    pub fn challenge_fp2_vec(&mut self, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| self.challenge_fp2()).collect()
    }

    /// `n` indices in [0, bound), bound a power of two.
    pub fn challenge_indices(&mut self, n: usize, bound: usize) -> Vec<usize> {
        assert!(bound.is_power_of_two());
        let mut out = Vec::with_capacity(n);
        while out.len() < n {
            let b = self.squeeze_bytes();
            for chunk in b.chunks(8) {
                if out.len() == n { break; }
                let v = u64::from_le_bytes(chunk.try_into().unwrap());
                out.push((v as usize) & (bound - 1));
            }
        }
        out
    }

    pub fn state(&self) -> [u8; 32] {
        self.state
    }

    /// [UPERF3-XX] A copy of the transcript (state + counter) so a device
    /// attempt can be abandoned without disturbing the caller's transcript.
    pub fn clone_state(tr: &Transcript) -> Transcript {
        Transcript { state: tr.state, counter: tr.counter }
    }
}

#[allow(dead_code)]
const _ASSERT_P: u64 = P;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_and_sensitive() {
        let mut a = Transcript::new(b"t");
        let mut b = Transcript::new(b"t");
        a.absorb(b"x", &[1, 2, 3]);
        b.absorb(b"x", &[1, 2, 3]);
        assert_eq!(a.challenge_fp2(), b.challenge_fp2());
        let mut c = Transcript::new(b"t");
        c.absorb(b"x", &[1, 2, 4]);
        assert_ne!(a.challenge_fp2(), c.challenge_fp2());
        let mut d = Transcript::new(b"t");
        d.absorb(b"y", &[1, 2, 3]);
        let mut e = Transcript::new(b"t");
        e.absorb(b"x", &[1, 2, 3]);
        assert_ne!(d.challenge_fp(), e.challenge_fp());
        let idx = e.challenge_indices(100, 1024);
        assert_eq!(idx.len(), 100);
        assert!(idx.iter().all(|&i| i < 1024));
    }
}
