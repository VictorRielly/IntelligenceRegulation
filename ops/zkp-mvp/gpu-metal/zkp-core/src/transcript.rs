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
        // [A14] opt-in (`HL_TRANSCRIPT_PAR=1`): a long message (an opening's
        // clear vector) hashes BLAKE3's own tree of the SAME input on rayon:
        // the same digest (`par_absorb`)
        if data.len() >= ABSORB_PAR_MIN && absorb_par_on() {
            self.state = par_absorb(self.key.as_ref(), &self.state, label, data);
            return;
        }
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
        // [A14] a long vector's bytes are written in parallel (the same bytes)
        if vals.len() * 16 >= ABSORB_PAR_MIN && absorb_par_on() {
            use rayon::prelude::*;
            bytes.resize(vals.len() * 16, 0);
            bytes.par_chunks_mut(16 * 1024).zip(vals.par_chunks(1024)).for_each(|(b, v)| {
                for (o, x) in b.chunks_exact_mut(16).zip(v.iter()) {
                    o.copy_from_slice(&x.to_bytes());
                }
            });
            self.absorb(label, &bytes);
            return;
        }
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

    /// [ZK60-METAL M6] the squeeze counter, read-only: a device that runs
    /// this transcript's next sumcheck rounds starts from it. The host then
    /// replays every such round through this transcript and checks each
    /// device challenge, so no device value reaches the proof unchecked.
    pub fn counter(&self) -> u64 {
        self.counter
    }

    /// [ZK60-METAL M6] the Fiat-Shamir key of a tagged profile (public: it is
    /// derived from the profile's tag), read-only, for the same device rounds
    pub fn fs_key(&self) -> Option<[u8; 32]> {
        self.key
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

/// [A14] the data length from which an absorb hashes its tree in parallel
/// (an opening's clear vector is 16,664 `Fp2` = 266,624 bytes at W16R2 8B)
pub const ABSORB_PAR_MIN: usize = 1 << 16;

/// [A14] the leaf size of the parallel tree walk: subtrees this long or
/// shorter are hashed by one `Hasher` (blake3's own SIMD within the subtree)
const ABSORB_PAR_LEAF: usize = 1 << 15;

/// [A14] 0: as the environment says (`HL_TRANSCRIPT_PAR=1` turns the parallel
/// absorb on; unset, every absorb is serial, the form before A14); 1: serial;
/// 2: parallel. **Off by default:** in one process, W16R2 8B T128, 32 blocks,
/// N = 6, 8 passes in both arm orders, it did not pay (the proof-only fork
/// run +1.0%, 4 of 8 pairs; system CPU +15%: the rayon wake-ups cost about
/// what the hash saves; `results/zk60_effplan_20261105/a14/README.md`).
static ABSORB_PAR: std::sync::atomic::AtomicU8 = std::sync::atomic::AtomicU8::new(0);

fn absorb_par_on() -> bool {
    static ENV: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    match ABSORB_PAR.load(std::sync::atomic::Ordering::Relaxed) {
        1 => false,
        2 => true,
        _ => *ENV.get_or_init(|| std::env::var("HL_TRANSCRIPT_PAR").map(|v| v == "1").unwrap_or(false)),
    }
}

/// [A14] the absorb form for the whole process (an in-process A/B): `Some(true)`
/// parallel, `Some(false)` serial, `None` the environment's. Both forms give
/// every transcript the same state, so this moves no byte.
pub fn set_absorb_parallel(on: Option<bool>) {
    let v = match on {
        None => 0,
        Some(false) => 1,
        Some(true) => 2,
    };
    ABSORB_PAR.store(v, std::sync::atomic::Ordering::Relaxed);
}

/// **[A14] One absorb's digest, from BLAKE3's tree hashed on rayon.**
///
/// The message is the absorb's own, `state ‖ |label| ‖ label ‖ |data| ‖ data`
/// (the lengths as 8-byte little-endian words), under the transcript's mode
/// (unkeyed, or keyed under the profile's Fiat-Shamir key). BLAKE3 hashes
/// any message longer than one 1,024-byte chunk as a binary tree whose left
/// subtree is the largest power-of-two number of chunks below the message's
/// length (`hazmat::left_subtree_len`), recursively, and the root is the
/// parent node of the top two subtrees with the ROOT flag. This walks that
/// same tree: each side of a split is hashed on its own (`rayon::join`) as a
/// subtree at its input offset, split again above [`ABSORB_PAR_LEAF`] bytes,
/// and the chaining values are merged as BLAKE3's parent nodes. The digest is
/// the serial `Hasher`'s, for every message (blake3's own documentation of
/// `hazmat`, and the tests below over every length around the chunk and
/// split boundaries, both modes). Nothing about the data decides the split:
/// only its length, which is public (a function of the shape).
fn par_absorb(key: Option<&[u8; 32]>, state: &[u8; 32], label: &[u8], data: &[u8]) -> [u8; 32] {
    use blake3::hazmat::{left_subtree_len, merge_subtrees_non_root, merge_subtrees_root, ChainingValue, HasherExt, Mode};
    let mut pre = Vec::with_capacity(48 + label.len());
    pre.extend_from_slice(state);
    pre.extend_from_slice(&(label.len() as u64).to_le_bytes());
    pre.extend_from_slice(label);
    pre.extend_from_slice(&(data.len() as u64).to_le_bytes());
    let total = pre.len() + data.len();
    assert!(total > blake3::CHUNK_LEN, "transcript: a parallel absorb is longer than one chunk");
    let mode = match key {
        None => Mode::Hash,
        Some(k) => Mode::KeyedHash(k),
    };
    // the message bytes `[from, to)`, fed to one subtree hasher
    let feed = |h: &mut blake3::Hasher, from: usize, to: usize| {
        let p = pre.len();
        if from < p {
            h.update(&pre[from..to.min(p)]);
        }
        if to > p {
            h.update(&data[from.max(p) - p..to - p]);
        }
    };
    fn subtree(from: usize, to: usize, key: Option<&[u8; 32]>, mode: Mode<'_>, feed: &(dyn Fn(&mut blake3::Hasher, usize, usize) + Sync)) -> ChainingValue {
        let len = to - from;
        if len <= ABSORB_PAR_LEAF {
            let mut h = crate::hashtag::hasher(key);
            h.set_input_offset(from as u64);
            feed(&mut h, from, to);
            return h.finalize_non_root();
        }
        let left = left_subtree_len(len as u64) as usize;
        let (l, r) = rayon::join(|| subtree(from, from + left, key, mode, feed), || subtree(from + left, to, key, mode, feed));
        merge_subtrees_non_root(&l, &r, mode)
    }
    let left = left_subtree_len(total as u64) as usize;
    let (l, r) = rayon::join(|| subtree(0, left, key, mode, &feed), || subtree(left, total, key, mode, &feed));
    *merge_subtrees_root(&l, &r, mode).as_bytes()
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

    /// [A14] **The parallel absorb gives the serial digest.** For every data
    /// length around the chunk boundaries, the parallel threshold, the leaf
    /// size and the tree's splits (and an opening's clear vector, 266,624
    /// bytes), with labels of several lengths, unkeyed and keyed: the state
    /// after a parallel absorb equals the serial `Hasher`'s, byte for byte,
    /// and so do the next challenges. Then `absorb_fp2` of long vectors, both
    /// forms, and inside rayon pools of 1, 2 and 6 threads.
    #[test]
    fn a14_the_parallel_absorb_equals_the_serial_digest() {
        let key = *crate::hashtag::HashTag::for_profile("hashline-zk-mr1/private-block-rung-g-t24-dev/1").transcript_key().expect("a tagged profile carries a transcript key");
        let mut lens: Vec<usize> = vec![1025, 1100, 2047, 2048, 2049, 4096, 4097];
        for p in [ABSORB_PAR_LEAF, ABSORB_PAR_MIN, 1 << 17, 1 << 18, 1 << 20] {
            for d in [p - 49, p - 48, p - 47, p - 1, p, p + 1, p + 1023, p + 1024, p + 1025] {
                lens.push(d);
            }
        }
        lens.extend([266_624, 266_624 * 3 + 5, 3 << 20]);
        let data: Vec<u8> = (0..*lens.iter().max().unwrap()).map(|i| (i as u32).wrapping_mul(2_654_435_761).rotate_left(7) as u8).collect();
        let mut checked = 0usize;
        for k in [None, Some(&key)] {
            for label in [&b""[..], &b"pcs-vec"[..], &b"a-label-of-some-length-0123456789"[..]] {
                let state = *blake3::hash(label).as_bytes();
                for &len in &lens {
                    let d = &data[..len];
                    let mut h = crate::hashtag::hasher(k);
                    h.update(&state);
                    h.update(&(label.len() as u64).to_le_bytes());
                    h.update(label);
                    h.update(&(d.len() as u64).to_le_bytes());
                    h.update(d);
                    let want = *h.finalize().as_bytes();
                    assert_eq!(par_absorb(k, &state, label, d), want, "keyed {} label {} len {len}: the parallel absorb differs", k.is_some(), label.len());
                    checked += 1;
                }
            }
        }
        // through the transcript, both forms, in pools of several sizes
        let vals: Vec<Fp2> = (0..16_664u64).map(|i| Fp2::new(Fp::new(i.wrapping_mul(0x9e37_79b9_7f4a_7c15)), Fp::new(i ^ 0xdead_beef))).collect();
        let run = |par: bool| {
            set_absorb_parallel(Some(par));
            let mut a = Transcript::new_tagged(b"a14", key);
            let mut b = Transcript::new(b"a14");
            for t in [&mut a, &mut b] {
                t.absorb_fp2(b"pcs-vec", &vals);
                t.absorb_fp2(b"pcs-vec", &vals[..4097]);
                t.absorb(b"x", &data[..(1 << 18) + 3]);
                t.absorb_fp2(b"pcs-prox", &vals[..3]);
            }
            set_absorb_parallel(None);
            (a.state(), b.state(), a.challenge_fp2(), b.challenge_fp2())
        };
        let serial = run(false);
        for threads in [1usize, 2, 6] {
            let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().unwrap();
            assert_eq!(pool.install(|| run(true)), serial, "{threads} threads: a transcript with parallel absorbs left another state");
        }
        assert_eq!(run(true), serial, "the global pool: a transcript with parallel absorbs left another state");
        eprintln!("A14-ABSORB: {checked} parallel absorbs equal the serial digest; transcripts equal in pools of 1, 2, 6 threads and the global pool");
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
