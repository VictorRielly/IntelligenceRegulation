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
}
