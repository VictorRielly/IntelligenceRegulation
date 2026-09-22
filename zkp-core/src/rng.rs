//! Legacy hashline randomness, moved without changing stream construction.
//! Public seeds are for fixtures; use `from_os` for fresh proof randomness.

use crate::field::{Fp, Fp2};

/// A deterministic blake3 stream: the source of every pad, mask, salt
/// and masking polynomial under `--zk` (the CPU/GPU parity gate needs
/// the prover's randomness to be a function of the seed).
pub struct ZkRng {
    key: [u8; 32],
    counter: u64,
    buf: Vec<u8>,
    pos: usize,
}

const RNG_BLOCK: usize = 8192;

impl ZkRng {
    /// Legacy deterministic stream for public test fixtures ONLY.
    pub fn new(seed: u64, domain: &[u8]) -> ZkRng {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-zk-rng/");
        h.update(domain);
        h.update(&seed.to_le_bytes());
        ZkRng { key: *h.finalize().as_bytes(), counter: 0, buf: vec![0u8; RNG_BLOCK], pos: RNG_BLOCK }
    }

    /// OS entropy on the supported Linux/WSL and macOS hosts. Unsupported
    /// hosts fail closed, rather than falling back to a clock or public seed.
    pub fn from_os(domain: &[u8]) -> std::io::Result<ZkRng> {
        #[cfg(unix)]
        {
            let mut source = std::fs::File::open("/dev/urandom")?;
            Self::from_entropy_reader(domain, &mut source)
        }
        #[cfg(not(unix))]
        {
            let _ = domain;
            Err(std::io::Error::new(std::io::ErrorKind::Unsupported,
                "OS randomness backend is implemented for Linux/WSL and macOS only"))
        }
    }

    fn from_entropy_reader(domain: &[u8], source: &mut impl std::io::Read) -> std::io::Result<ZkRng> {
        let mut entropy = [0u8; 32];
        source.read_exact(&mut entropy)?;
        let mut h = blake3::Hasher::new_keyed(&entropy);
        h.update(b"hashline-zk-os-rng/v1/");
        h.update(domain);
        Ok(ZkRng { key: *h.finalize().as_bytes(), counter: 0, buf: vec![0u8; RNG_BLOCK], pos: RNG_BLOCK })
    }

    fn refill(&mut self) {
        let mut h = blake3::Hasher::new();
        h.update(&self.key);
        h.update(&self.counter.to_le_bytes());
        self.counter += 1;
        let mut out = h.finalize_xof();
        out.fill(&mut self.buf);
        self.pos = 0;
    }

    pub fn next_u64(&mut self) -> u64 {
        if self.pos + 8 > self.buf.len() {
            self.refill();
        }
        let v = u64::from_le_bytes(self.buf[self.pos..self.pos + 8].try_into().unwrap());
        self.pos += 8;
        v
    }

    /// A uniform base-field element (a 128-bit draw reduced mod p: bias 2^-64).
    pub fn fp(&mut self) -> Fp {
        let lo = self.next_u64();
        let hi = self.next_u64();
        Fp::from_u128(((hi as u128) << 64) | lo as u128)
    }

    pub fn fp2(&mut self) -> Fp2 {
        let a = self.fp();
        let b = self.fp();
        Fp2::new(a, b)
    }

    pub fn fp_vec(&mut self, n: usize) -> Vec<Fp> {
        (0..n).map(|_| self.fp()).collect()
    }

    pub fn fp2_vec(&mut self, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| self.fp2()).collect()
    }

    pub fn bytes32(&mut self) -> [u8; 32] {
        let mut out = [0u8; 32];
        for c in out.chunks_mut(8) {
            c.copy_from_slice(&self.next_u64().to_le_bytes());
        }
        out
    }
}

// ---------------------------------------------------------------------------
// TEST OBSERVERS (the integrator's authorisation of 2026-09-22 07:25)
// ---------------------------------------------------------------------------
//
// **What this is for.** Assertions 1-4 of
// `docs/zkmatrix-poc/ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §3.1 — the
// draw-accounting test ruling R-3 asks for — are statements about how many
// stream bytes a proof consumes and where each role's bytes sit. From
// outside this crate none of it was observable: the four fields below are
// private and there was no accessor. These two functions are that accessor,
// and nothing else.
//
// **THE FOUR CONDITIONS THEY ARE BUILT UNDER.**
//
// 1. **Read-only and DERIVED.** Both are functions of `counter` and `pos`,
//    which `refill` and `next_u64` already maintain. No field was added, no
//    counter is bumped on a draw, and `next_u64` — the one hot path — is
//    byte for byte what it was. The cost of the accounting is paid by the
//    caller that asks, once, and never by the stream.
// 2. **Gated.** `#[cfg(any(test, feature = "test-observers"))]`: this
//    crate's own tests see it, a dependent that switches the feature on in
//    its DEV-dependency sees it, and a release build of the library sees
//    nothing at all. The feature is declared in `[features]` only — never in
//    `default`, never in a normal dependency.
// 3. **Counts, never contents.** Neither function can return, and no
//    caller can reach through them to, the key, the seed, a stream byte or
//    a drawn value. The two numbers are a byte count and a refill count.
// 4. **`ZkRng` is still not `Clone`.** Nothing here derives, implements or
//    enables a copy of the generator; the type-level fact assertion 5 of
//    §3.1 rests on is unchanged, and this file's own test asserts it.
#[cfg(any(test, feature = "test-observers"))]
impl ZkRng {
    /// One refill block, in bytes — the granularity `consumed_bytes` counts
    /// in, exposed so a test does not have to hard-code it.
    pub const OBSERVED_BLOCK_BYTES: u64 = RNG_BLOCK as u64;

    /// **The stream bytes consumed so far**, derived from `(counter, pos)`.
    ///
    /// `refill` fills the whole `RNG_BLOCK`-byte buffer and sets `pos = 0`
    /// AFTER incrementing `counter`, so after `k >= 1` refills the stream
    /// has yielded `(k - 1) * RNG_BLOCK + pos` bytes; a generator that has
    /// never refilled (`counter == 0`, `pos == RNG_BLOCK`) has yielded none.
    ///
    /// **It is exact, not an estimate, and no byte is ever skipped.** `pos`
    /// moves only in `next_u64`, in steps of 8, from 0; `RNG_BLOCK` is a
    /// multiple of 8; so `pos + 8 > buf.len()` holds exactly when
    /// `pos == RNG_BLOCK` and a draw never straddles the end of a buffer by
    /// discarding a partial word. Every consumed byte is a byte some draw
    /// returned: `fp()` is two `next_u64`s (16 bytes), `fp2()` is two
    /// `fp()`s (32), `bytes32()` is four `next_u64`s (32).
    pub fn consumed_bytes(&self) -> u64 {
        debug_assert_eq!(self.buf.len(), RNG_BLOCK, "the refill buffer changed size");
        debug_assert!(self.counter > 0 || self.pos == RNG_BLOCK, "pos moved before the first refill");
        debug_assert!(self.pos % 8 == 0 && self.pos <= RNG_BLOCK, "pos is not a whole word inside the buffer");
        if self.counter == 0 {
            0
        } else {
            (self.counter - 1) * RNG_BLOCK as u64 + self.pos as u64
        }
    }

    /// How many times the stream has been refilled — the number of XOF
    /// evaluations of `key ‖ le64(counter)` this generator has performed.
    /// It is the same state `consumed_bytes` reads, from the other side:
    /// at every state a caller can observe, `refills()` is
    /// `consumed_bytes()` rounded UP to whole blocks and divided by
    /// `OBSERVED_BLOCK_BYTES` — the two are one fact seen twice, which is
    /// why a test can cross-check them against each other.
    pub fn refills(&self) -> u64 {
        self.counter
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn entropy_errors_do_not_produce_a_generator() {
        let mut short = std::io::Cursor::new([0u8; 31]);
        assert!(matches!(ZkRng::from_entropy_reader(b"test", &mut short),
            Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof));
        struct Failed;
        impl std::io::Read for Failed {
            fn read(&mut self, _: &mut [u8]) -> std::io::Result<usize> {
                Err(std::io::Error::new(std::io::ErrorKind::PermissionDenied, "injected entropy failure"))
            }
        }
        assert!(matches!(ZkRng::from_entropy_reader(b"test", &mut Failed),
            Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied));
    }

    #[test]
    fn rng_is_deterministic_and_domain_separated() {
        let mut a = ZkRng::new(7, b"x");
        let mut b = ZkRng::new(7, b"x");
        let va: Vec<u64> = (0..100).map(|_| a.next_u64()).collect();
        let vb: Vec<u64> = (0..100).map(|_| b.next_u64()).collect();
        assert_eq!(va, vb);
        let mut c = ZkRng::new(8, b"x");
        assert_ne!(va[0], c.next_u64());
        let mut d = ZkRng::new(7, b"y");
        assert_ne!(va[0], d.next_u64());
        let f = a.fp();
        assert!(f.0 < crate::field::P);
    }

    // -----------------------------------------------------------------
    // the test observers (stage 36): what they count, and that counting
    // changes nothing
    // -----------------------------------------------------------------

    /// **Every draw kind, with the byte count read off the source.** A
    /// `next_u64` is 8 stream bytes, `fp()` is two of them, `fp2()` is two
    /// `fp()`s and `bytes32()` is four `next_u64`s — so a mixed sequence's
    /// consumption is a sum with no rounding anywhere in it. The count is
    /// built term by term in the test and compared with the accessor; the
    /// refill count is cross-checked against it at every step.
    #[test]
    fn the_consumption_accessor_counts_every_draw_kind_exactly() {
        let mut r = ZkRng::new(11, b"observers");
        assert_eq!(r.consumed_bytes(), 0, "a generator that has drawn nothing has consumed nothing");
        assert_eq!(r.refills(), 0, "a generator that has drawn nothing has refilled");
        let mut want = 0u64;
        let check = |r: &ZkRng, want: u64| {
            assert_eq!(r.consumed_bytes(), want, "the accessor and the hand count disagree");
            let blocks = want.div_ceil(ZkRng::OBSERVED_BLOCK_BYTES);
            assert_eq!(r.refills(), blocks, "the refill count is not the consumption in whole blocks");
        };
        r.next_u64();
        want += 8;
        check(&r, want);
        r.fp();
        want += 16;
        check(&r, want);
        r.fp2();
        want += 32;
        check(&r, want);
        r.bytes32();
        want += 32;
        check(&r, want);
        r.fp_vec(5);
        want += 5 * 16;
        check(&r, want);
        r.fp2_vec(3);
        want += 3 * 32;
        check(&r, want);
        assert_eq!(want, 8 + 16 + 32 + 32 + 80 + 96, "the mixed sequence's hand count moved");
        // and the whole sequence is 8 x (the number of `next_u64` calls it made)
        assert_eq!(want % 8, 0);
        assert_eq!(want / 8, 1 + 2 + 4 + 4 + 10 + 12, "the byte count is not eight per stream word");
    }

    /// **THE REFILL BOUNDARY**, which is the one place an accessor derived
    /// from `(counter, pos)` could be wrong.
    ///
    /// Three facts, in one generator: the buffer empties exactly at
    /// `OBSERVED_BLOCK_BYTES` with one refill behind it; the next word
    /// forces the second refill and the count goes on by 8 with no jump and
    /// no lost byte; and an `fp()` STRADDLING the boundary — its first word
    /// the last of one buffer, its second the first of the next — is
    /// counted as the 16 bytes it is. The straddle is the interesting case
    /// because `refill` resets `pos` to 0 in the middle of the draw.
    #[test]
    fn the_consumption_accessor_is_exact_across_a_refill_boundary() {
        let block = ZkRng::OBSERVED_BLOCK_BYTES;
        let words = block / 8;
        let mut r = ZkRng::new(12, b"observers");
        for _ in 0..words {
            r.next_u64();
        }
        assert_eq!(r.consumed_bytes(), block, "a full buffer is not a full block of consumption");
        assert_eq!(r.refills(), 1, "one buffer took more than one refill");
        r.next_u64();
        assert_eq!(r.consumed_bytes(), block + 8, "the first word of the second buffer lost or gained bytes");
        assert_eq!(r.refills(), 2, "the second buffer did not come from a second refill");

        // the straddling draw: stop one word short of the boundary, then fp()
        let mut s = ZkRng::new(13, b"observers");
        for _ in 0..words - 1 {
            s.next_u64();
        }
        assert_eq!(s.consumed_bytes(), block - 8);
        assert_eq!(s.refills(), 1);
        let straddling = s.fp();
        assert_eq!(s.consumed_bytes(), block + 8, "a draw straddling the refill boundary is not sixteen bytes");
        assert_eq!(s.refills(), 2, "the straddling draw did not force the refill");
        // the straddling value is a real draw, not a degenerate one: the
        // same seed replayed word by word gives the same two words
        let mut t = ZkRng::new(13, b"observers");
        for _ in 0..words - 1 {
            t.next_u64();
        }
        let (lo, hi) = (t.next_u64(), t.next_u64());
        assert_eq!(straddling, Fp::from_u128(((hi as u128) << 64) | lo as u128), "the straddling fp() is not its two stream words");
        assert_eq!(t.consumed_bytes(), s.consumed_bytes(), "two routes to the same position disagree");
    }

    /// **Reading the accessor changes no output.** Two generators on the
    /// same seed draw the same mixed sequence; one of them is interrogated
    /// between every draw and the other is never touched. The sequences are
    /// identical element for element and the two end at the same position.
    /// (`consumed_bytes` and `refills` take `&self`, so this is a
    /// belt-and-braces check of a fact the type system already carries.)
    #[test]
    fn reading_the_accessor_changes_no_drawn_value() {
        let mut watched = ZkRng::new(14, b"observers");
        let mut untouched = ZkRng::new(14, b"observers");
        let mut a: Vec<u64> = Vec::new();
        let mut b: Vec<u64> = Vec::new();
        for i in 0..64 {
            let _ = watched.consumed_bytes();
            let _ = watched.refills();
            a.push(watched.fp().0);
            let _ = watched.consumed_bytes();
            a.push(watched.bytes32()[0] as u64);
            let _ = watched.refills();
            a.push(watched.fp2().c1.0);
            assert_eq!(watched.consumed_bytes(), (i + 1) * (16 + 32 + 32), "the interrogated generator drifted");
            b.push(untouched.fp().0);
            b.push(untouched.bytes32()[0] as u64);
            b.push(untouched.fp2().c1.0);
        }
        assert_eq!(a, b, "interrogating the generator moved its output");
        assert_eq!(watched.consumed_bytes(), untouched.consumed_bytes(), "the two generators ended at different positions");
        assert_eq!(watched.refills(), untouched.refills());
    }

    /// **`ZkRng` IS STILL NOT `Clone`** — the integrator's first condition,
    /// and the type-level fact clarification 7 of the accepted toy privacy
    /// statement rests on ("The generator is not `Clone`: it cannot be
    /// forked, by the type system").
    ///
    /// The probe is the inherent-impl trick: an inherent method that exists
    /// only for `T: Clone` shadows a blanket trait method that exists for
    /// every `T`, so the answer is YES exactly when `T: Clone`. It carries
    /// its own two controls, so a probe that stopped working would fail
    /// here instead of passing vacuously.
    #[test]
    fn the_generator_is_still_not_clone() {
        use std::marker::PhantomData;
        struct Probe<T>(PhantomData<T>);
        trait NotCloneFallback {
            fn is_clone(&self) -> bool {
                false
            }
        }
        impl<T> NotCloneFallback for Probe<T> {}
        impl<T: Clone> Probe<T> {
            fn is_clone(&self) -> bool {
                true
            }
        }
        struct NeverClone;
        assert!(Probe::<u64>(PhantomData).is_clone(), "the probe cannot see Clone; it proves nothing");
        assert!(!Probe::<NeverClone>(PhantomData).is_clone(), "the probe answers yes for a non-Clone type");
        assert!(!Probe::<ZkRng>(PhantomData).is_clone(), "ZkRng became Clone: the generator can be forked and the toy statement's clarification 7 is false");
    }
}
