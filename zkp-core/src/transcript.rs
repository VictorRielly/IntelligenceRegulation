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

// ---------------------------------------------------------------------------
// TEST OBSERVER (the integrator's authorisation of 2026-09-22 07:25)
// ---------------------------------------------------------------------------
//
// **What this is for.** Finding U-3 of the lane ledger: the transcript
// published `state()` but no counter accessor, so "how many challenges did
// this proof squeeze" was unobservable and the lane had to substitute a
// 32-byte position tag for it. The draw-accounting test needs the count,
// and the count is already in the state.
//
// **Read-only, derived, and counts only.** `counter` is incremented by
// `squeeze_bytes` and by nothing else; this returns it. It is not a new
// field, no absorb or squeeze does any extra work, and no challenge value,
// no absorbed message and no Fiat-Shamir key can be reached through it.
#[cfg(any(test, feature = "test-observers"))]
impl Transcript {
    /// **How many SQUEEZES this transcript has performed** since it was
    /// constructed — the value that goes into the next squeeze's input as
    /// `le64(counter)`, which is exactly why it counts them.
    ///
    /// It is squeezes, not challenges, and the two differ in one place:
    /// `challenge_fp` and `challenge_fp2` are one squeeze each, but
    /// `challenge_indices(n, _)` squeezes `ceil(n / 4)` times because it
    /// takes four indices from each 32-byte output. A test that wants
    /// "challenges" counts the calls it made; this counts the points on the
    /// hash chain, which is the object the Fiat-Shamir argument is about.
    ///
    /// **A clone carries it.** `clone_state` copies `counter` along with
    /// `state` (ruling T-7), so a refusal replay taken off a clone starts
    /// at the live count and the live transcript's own count does not move
    /// — which is the property the draw-accounting test asserts about the
    /// replay.
    ///
    /// **Absorbs are NOT counted, and cannot be derived.** `absorb` folds
    /// its message into `state` and touches no counter, so the number of
    /// absorbs is not a function of any state this type holds. Counting
    /// them would mean a new field bumped on every absorb — work on a hot
    /// path, which the integrator's conditions forbid and which this
    /// accessor therefore does not do.
    pub fn squeezes(&self) -> u64 {
        self.counter
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

    // -----------------------------------------------------------------
    // the squeeze counter (stage 36)
    // -----------------------------------------------------------------

    /// **The counter matches a hand-counted sequence**, call kind by call
    /// kind: absorbs move it not at all, `challenge_fp` and `challenge_fp2`
    /// move it by one, `challenge_fp2_vec(n)` by `n`, and
    /// `challenge_indices(n, _)` by `ceil(n / 4)` because each squeeze
    /// yields four 8-byte indices. The last is the one place where
    /// "challenges" and "squeezes" are different numbers, and the test says
    /// so at four sizes, including the exact multiple of four and one past
    /// it.
    #[test]
    fn the_squeeze_counter_matches_a_hand_counted_sequence() {
        let mut t = Transcript::new(b"stage36");
        assert_eq!(t.squeezes(), 0, "a fresh transcript has squeezed");
        t.absorb(b"x", &[1, 2, 3]);
        t.absorb_u64(b"rows", 7);
        t.absorb_fp(b"vals", &[Fp::new(5)]);
        t.absorb_fp2(b"sc-round", &[Fp2::ONE]);
        assert_eq!(t.squeezes(), 0, "an absorb squeezed");
        t.challenge_fp();
        assert_eq!(t.squeezes(), 1);
        t.challenge_fp2();
        assert_eq!(t.squeezes(), 2);
        t.challenge_fp2_vec(5);
        assert_eq!(t.squeezes(), 7, "a vector of five challenges is not five squeezes");
        let mut want = 7u64;
        for (n, squeezes) in [(1usize, 1u64), (4, 1), (5, 2), (100, 25)] {
            t.challenge_indices(n, 1024);
            want += squeezes;
            assert_eq!(t.squeezes(), want, "{n} indices did not take {squeezes} squeezes");
        }
        // a clone starts where the original is, and the original does not
        // move while the clone draws (the refusal replay's property)
        let live = t.squeezes();
        let mut clone = Transcript::clone_state(&t);
        assert_eq!(clone.squeezes(), live, "the clone did not inherit the counter");
        for _ in 0..12 {
            clone.challenge_fp2();
        }
        assert_eq!(clone.squeezes(), live + 12);
        assert_eq!(t.squeezes(), live, "a clone's draws moved the live transcript's counter");
    }

    /// **Reading the counter changes no challenge and no state.** Two
    /// transcripts on the same domain take the same absorbs and the same
    /// challenges; one is interrogated before and after every call. The
    /// challenge values agree one by one, and so do the two states at the
    /// end.
    #[test]
    fn reading_the_squeeze_counter_changes_no_challenge() {
        let mut watched = Transcript::new(b"stage36");
        let mut untouched = Transcript::new(b"stage36");
        let mut a: Vec<Fp2> = Vec::new();
        let mut b: Vec<Fp2> = Vec::new();
        for i in 0..32u64 {
            let _ = watched.squeezes();
            watched.absorb_u64(b"i", i);
            let _ = watched.squeezes();
            a.push(watched.challenge_fp2());
            assert_eq!(watched.squeezes(), i + 1);
            untouched.absorb_u64(b"i", i);
            b.push(untouched.challenge_fp2());
        }
        assert_eq!(a, b, "interrogating the transcript moved its challenges");
        assert_eq!(watched.state(), untouched.state(), "interrogating the transcript moved its state");
        assert_eq!(watched.squeezes(), untouched.squeezes());
    }
}
