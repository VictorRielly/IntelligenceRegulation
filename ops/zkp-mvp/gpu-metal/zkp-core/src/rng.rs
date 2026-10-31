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

/// [ZK60-METAL M4d] `fill_fp` takes the sequential loop below this many draws
const FILL_PAR_MIN: usize = 1 << 15;
/// [ZK60-METAL M4d] draws per parallel task of `fill_fp` (32 blocks)
const FILL_CHUNK: usize = 1 << 14;

/// block `counter` of the stream keyed by `key`: the first `out.len()` XOF
/// bytes of `blake3(key || counter_le)` (what `refill` has always drawn)
fn block_bytes(key: &[u8; 32], counter: u64, out: &mut [u8]) {
    let mut h = blake3::Hasher::new();
    h.update(key);
    h.update(&counter.to_le_bytes());
    h.finalize_xof().fill(out);
}

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
        block_bytes(&self.key, self.counter, &mut self.buf);
        self.counter += 1;
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
        let mut v = vec![Fp::ZERO; n];
        self.fill_fp(&mut v);
        v
    }

    /// [ZK60-METAL M4d] `out[i] = self.fp()` for every `i` in order, with the
    /// stream left in exactly the state that loop leaves it in (same `buf`,
    /// `pos`, `counter`). The stream is counter-mode — block `c` is
    /// `blake3(key || c)`'s first [`RNG_BLOCK`] XOF bytes, the u64 words of the
    /// blocks are drawn in order and a draw is two consecutive words — so word
    /// `t` of the stream from the current state is a pure function of
    /// `(key, counter, pos, buf, t)`, and long fills are cut into chunks that
    /// rebuild their own blocks in parallel. Short fills take the loop.
    pub fn fill_fp(&mut self, out: &mut [Fp]) {
        if out.len() < FILL_PAR_MIN {
            for x in out.iter_mut() {
                *x = self.fp();
            }
            return;
        }
        use rayon::prelude::*;
        const W: usize = RNG_BLOCK / 8; // u64 words per block
        // words left in the current buffer; `pos` is always a multiple of 8
        let r = (RNG_BLOCK - self.pos) / 8;
        let (key, c0, pos0) = (self.key, self.counter, self.pos);
        let cur: &[u8] = &self.buf;
        out.par_chunks_mut(FILL_CHUNK).enumerate().for_each(|(ci, dst)| {
            let t0 = 2 * ci * FILL_CHUNK;
            let mut blk = vec![0u8; RNG_BLOCK];
            let mut have: Option<usize> = None;
            let mut word = |t: usize| -> u64 {
                let (src, at): (&[u8], usize) = if t < r {
                    (cur, pos0 + 8 * t)
                } else {
                    let (b, w) = ((t - r) / W, (t - r) % W);
                    if have != Some(b) {
                        block_bytes(&key, c0 + b as u64, &mut blk);
                        have = Some(b);
                    }
                    (&blk[..], 8 * w)
                };
                u64::from_le_bytes(src[at..at + 8].try_into().unwrap())
            };
            for (j, x) in dst.iter_mut().enumerate() {
                let lo = word(t0 + 2 * j);
                let hi = word(t0 + 2 * j + 1);
                *x = Fp::from_u128(((hi as u128) << 64) | lo as u128);
            }
        });
        // the state the loop leaves: either still inside the current buffer,
        // or the last block it drew is the buffer and the counter is past it
        let total = 2 * out.len();
        if total <= r {
            self.pos += 8 * total;
        } else {
            let used = total - r;
            let nb = used.div_ceil(W);
            block_bytes(&key, c0 + nb as u64 - 1, &mut self.buf);
            self.counter = c0 + nb as u64;
            self.pos = 8 * (used - (nb - 1) * W);
        }
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

    /// [ZK60-METAL M4d] `fill_fp` equals the `fp()` loop word for word and
    /// leaves the same state, from every alignment of the current buffer
    /// (fresh, mid-block, an odd word so draws straddle blocks, one word left)
    /// and at lengths around the chunk and block edges; later draws of every
    /// kind then agree too.
    #[test]
    fn fill_fp_equals_the_draw_loop_and_leaves_the_same_state() {
        let lens = [0usize, 1, 511, 512, 513, FILL_PAR_MIN - 1, FILL_PAR_MIN, FILL_PAR_MIN + 1, FILL_CHUNK * 3 + 7, 4 * FILL_CHUNK, 100_003];
        let leads = [0usize, 1, 3, 1023, 1024, 1025, 2047];
        for &lead in &leads {
            for &len in &lens {
                let mut a = ZkRng::new(99, b"fill");
                let mut b = ZkRng::new(99, b"fill");
                for _ in 0..lead {
                    assert_eq!(a.next_u64(), b.next_u64());
                }
                let want: Vec<Fp> = (0..len).map(|_| a.fp()).collect();
                let mut got = vec![Fp::ZERO; len];
                b.fill_fp(&mut got);
                assert!(want == got, "lead {lead} len {len}: draws differ");
                assert_eq!((a.counter, a.pos), (b.counter, b.pos), "lead {lead} len {len}: state differs");
                assert!(a.buf == b.buf, "lead {lead} len {len}: buffer differs");
                for _ in 0..3000 {
                    assert_eq!(a.next_u64(), b.next_u64());
                }
                assert_eq!(a.bytes32(), b.bytes32());
                assert_eq!(a.fp_vec(70_000), b.fp_vec(70_000));
            }
        }
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
}
