//! Fiat-Shamir transcript over blake3: a 32-byte running state; every
//! absorbed message is domain-labelled; challenges are derived from the
//! state and a counter and fold back into the state.

use crate::field::{Fp, Fp2, P};

/// [UPERF3-ZA] A round masker: while one is installed, every
/// `sc-round` absorb is replaced by the masker's output (the CFS-masked
/// round message) and every challenge drawn is reported back to it.
/// The masked messages are recorded so the prover can put them in the
/// proof in place of the unmasked sums. Nothing changes without one.
pub trait RoundMask {
    fn mask_round(&mut self, sums: &[Fp2]) -> Vec<Fp2>;
    fn note_challenge(&mut self, r: Fp2);
}

pub struct Transcript {
    state: [u8; 32],
    counter: u64,
    masker: Option<Box<dyn RoundMask>>,
    masked_rounds: Vec<Vec<Fp2>>,
    /// [ZK60 D19, ruling T-1] the Fiat-Shamir key of a TAGGED profile, or
    /// `None` for the legacy rule. With `None` every hasher below is the
    /// identical `blake3::Hasher::new()` call this file always made.
    key: Option<[u8; 32]>,
}

impl Transcript {
    pub fn new(domain: &[u8]) -> Transcript {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-v1/");
        h.update(domain);
        Transcript { state: *h.finalize().as_bytes(), counter: 0, masker: None, masked_rounds: Vec::new(), key: None }
    }

    /// [ZK60 D19, ruling T-1] The same transcript in BLAKE3's KEYED mode,
    /// under a tagged profile's Fiat-Shamir key. The absorbed messages and
    /// their order are unchanged; only the hash function is another member of
    /// the family. `new` is this with no key, and keeps its own body.
    pub fn new_tagged(domain: &[u8], key: [u8; 32]) -> Transcript {
        let mut h = crate::hashtag::hasher(Some(&key));
        h.update(b"hashline-v1/");
        h.update(domain);
        Transcript { state: *h.finalize().as_bytes(), counter: 0, masker: None, masked_rounds: Vec::new(), key: Some(key) }
    }

    /// [UPERF3-ZA] Install a round masker (see `RoundMask`).
    pub fn set_masker(&mut self, m: Box<dyn RoundMask>) {
        assert!(self.masker.is_none(), "transcript: a masker is already installed");
        self.masker = Some(m);
        self.masked_rounds.clear();
    }

    /// [UPERF3-ZA] Remove the masker; returns the masked round messages it produced, in order.
    pub fn take_masker(&mut self) -> (Option<Box<dyn RoundMask>>, Vec<Vec<Fp2>>) {
        (self.masker.take(), std::mem::take(&mut self.masked_rounds))
    }

    pub fn absorb(&mut self, label: &[u8], data: &[u8]) {
        // [ZK60 D19, ruling T-1] with `key: None` this IS `blake3::Hasher::new()`.
        let mut h = crate::hashtag::hasher(self.key.as_ref());
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
        // [UPERF3-ZA] a masked sumcheck round: absorb the masker's output instead
        if self.masker.is_some() && label == b"sc-round" {
            let masked = self.masker.as_mut().unwrap().mask_round(vals);
            let mut bytes = Vec::with_capacity(masked.len() * 16);
            for v in &masked {
                bytes.extend_from_slice(&v.to_bytes());
            }
            self.absorb(label, &bytes);
            self.masked_rounds.push(masked);
            return;
        }
        let mut bytes = Vec::with_capacity(vals.len() * 16);
        for v in vals {
            bytes.extend_from_slice(&v.to_bytes());
        }
        self.absorb(label, &bytes);
    }

    fn squeeze_bytes(&mut self) -> [u8; 32] {
        // [ZK60 D19, ruling T-1] with `key: None` this IS `blake3::Hasher::new()`.
        let mut h = crate::hashtag::hasher(self.key.as_ref());
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
        let r = Fp2::new(c0, c1);
        if let Some(m) = self.masker.as_mut() {
            m.note_challenge(r);
        }
        r
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
        assert!(tr.masker.is_none(), "transcript: clone_state with a masker installed");
        // [ZK60 D19, ruling T-7] the MODE travels with the clone: the run's
        // position tags are squeezed from a discarded clone, and a clone that
        // dropped the key would squeeze them under the legacy function.
        Transcript { state: tr.state, counter: tr.counter, masker: None, masked_rounds: Vec::new(), key: tr.key }
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

    /// [ZK60 D19, ruling T-6] **The transcript's isolated control.** On the
    /// same domain and the same absorbs, a KEYED transcript draws different
    /// challenges from the unkeyed one, and from one under another role's
    /// key; and a CLONE of a keyed transcript draws the SAME challenges as
    /// its original, because `clone_state` carries the key.
    #[test]
    fn a_keyed_transcript_separates_and_its_clone_does_not() {
        let tag = crate::hashtag::HashTag::for_profile("hashline-zk-mr1/private-block-rung-g-t24-dev/1");
        let k = *tag.transcript_key().expect("a tagged profile carries a transcript key");
        let other = *tag.node_key().expect("another role's key");
        let absorbs = |t: &mut Transcript| {
            t.absorb(b"x", &[1, 2, 3]);
            t.absorb_u64(b"log-cols", 10);
        };
        let mut plain = Transcript::new(b"d");
        let mut keyed = Transcript::new_tagged(b"d", k);
        let mut wrong = Transcript::new_tagged(b"d", other);
        absorbs(&mut plain);
        absorbs(&mut keyed);
        absorbs(&mut wrong);
        // the states already differ, before a single challenge is drawn
        assert_ne!(plain.state(), keyed.state(), "a keyed transcript reached the unkeyed state");
        assert_ne!(keyed.state(), wrong.state(), "two role keys gave the same transcript state");
        // the clone, taken BEFORE the challenges, must track the original
        let mut clone = Transcript::clone_state(&keyed);
        let (p, kk, w) = (plain.challenge_fp2(), keyed.challenge_fp2(), wrong.challenge_fp2());
        assert_ne!(p, kk, "the keyed transcript drew the unkeyed challenge");
        assert_ne!(kk, w, "two role keys drew the same challenge");
        assert_eq!(kk, clone.challenge_fp2(), "a clone of a keyed transcript lost the key");
        assert_eq!(keyed.challenge_fp2(), clone.challenge_fp2(), "the clone diverged on the second challenge");
    }

    /// The legacy rule is untouched: an unkeyed transcript's clone is what it
    /// always was, and no keyed transcript equals it.
    #[test]
    fn the_unkeyed_transcript_is_unchanged() {
        let mut a = Transcript::new(b"hashline-zk-mr1/private-block-t32-poc/1");
        a.absorb(b"schedule", &[7u8; 32]);
        let want = a.state();
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-v1/");
        h.update(b"hashline-zk-mr1/private-block-t32-poc/1");
        let start: [u8; 32] = *h.finalize().as_bytes();
        let mut h2 = blake3::Hasher::new();
        h2.update(&start);
        h2.update(&8u64.to_le_bytes());
        h2.update(b"schedule");
        h2.update(&32u64.to_le_bytes());
        h2.update(&[7u8; 32]);
        assert_eq!(want, *h2.finalize().as_bytes(), "the legacy transcript rule moved");
    }
}
