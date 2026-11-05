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

/// **[A14] How `fill_fp`'s parallel chunks make their blocks.** The bytes are
/// [`block_bytes`]'s in every form; only the code that computes them differs.
/// `refill` (the one-draw path) always calls [`block_bytes`]. (`Clone` and
/// `Copy` by hand: `s25_tests` forbids their derive anywhere in this file, so
/// that `ZkRng` can never quietly gain one.)
#[derive(Debug, PartialEq, Eq)]
pub enum XofForm {
    /// [`block_bytes`]: blake3's own XOF (one 64-byte output block at a time
    /// on aarch64, where blake3 has no many-block XOF)
    Blake3,
    /// [`lanes::block`]: eight output blocks at once in NEON lanes (aarch64
    /// only; elsewhere this form is [`XofForm::Blake3`])
    Lanes8,
}

impl Clone for XofForm {
    fn clone(&self) -> XofForm {
        *self
    }
}

impl Copy for XofForm {}

/// [A14] 0: as the environment says (`HL_RNG_XOF=lanes8` for [`XofForm::Lanes8`],
/// otherwise [`XofForm::Blake3`]); 1: Blake3; 2: Lanes8
static XOF_FORM: std::sync::atomic::AtomicU8 = std::sync::atomic::AtomicU8::new(0);

/// [A14] the form `fill_fp` uses now. **The default is [`XofForm::Blake3`]**
/// (coordinator, 2026-11-05): the eight-lane form gives the same bytes, but on
/// top of the lazy sums it moved the proof-only wall by -0.2% (noise), and it
/// is a hand-written BLAKE3 compression inside the hiding generator, which the
/// privacy gate would have to audit for no measured gain. `HL_RNG_XOF=lanes8`
/// opts in (for the RTX 5090's CPU-bound host path, to be measured there).
pub fn xof_form() -> XofForm {
    static ENV: std::sync::OnceLock<XofForm> = std::sync::OnceLock::new();
    match XOF_FORM.load(std::sync::atomic::Ordering::Relaxed) {
        1 => XofForm::Blake3,
        2 => XofForm::Lanes8,
        _ => *ENV.get_or_init(|| if std::env::var("HL_RNG_XOF").map(|v| v == "lanes8").unwrap_or(false) { XofForm::Lanes8 } else { XofForm::Blake3 }),
    }
}

/// [A14] set the form for the whole process (an in-process A/B), or `None` for
/// the environment's; returns the form in force before. Every form gives the
/// same bytes, so this moves no draw.
pub fn set_xof_form(form: Option<XofForm>) -> XofForm {
    let before = xof_form();
    let v = match form {
        None => 0,
        Some(XofForm::Blake3) => 1,
        Some(XofForm::Lanes8) => 2,
    };
    XOF_FORM.store(v, std::sync::atomic::Ordering::Relaxed);
    before
}

/// [A14] block `counter` of the stream in the given form: [`block_bytes`]'s
/// bytes, from [`lanes::block`] when the form is `Lanes8`, the target has it
/// and `out` is whole lane groups
fn block_bytes_in(form: XofForm, key: &[u8; 32], counter: u64, out: &mut [u8]) {
    #[cfg(target_arch = "aarch64")]
    if form == XofForm::Lanes8 && out.len() % lanes::GROUP == 0 && out.len() / 64 <= 1 << 32 {
        lanes::block(key, counter, out);
        return;
    }
    let _ = form;
    block_bytes(key, counter, out);
}

/// **[A14] [`block_bytes`] eight output blocks at a time, in NEON lanes.**
///
/// What [`block_bytes`] computes: the unkeyed BLAKE3 hash of the 40-byte
/// input `key || counter_le` is ONE chunk of ONE block, so every 64-byte
/// output block `t` of its XOF is the compression of the root node, under the
/// IV, of that block zero-padded to 64 bytes, with block length 40, the flags
/// CHUNK_START | CHUNK_END | ROOT and the counter `t`, output in full
/// (`state[i] ^ state[i + 8]`, then `state[i + 8] ^ IV[i]`, little-endian).
/// blake3 has no many-block XOF on aarch64 and computes these blocks one at a
/// time; here eight blocks `t .. t + 8` run in two NEON register sets of four
/// lanes, a lane per counter. The arithmetic is BLAKE3's compression (7
/// rounds of the G mixing, the message schedule of the specification), on
/// 32-bit words: wrapping adds, xors and fixed rotations, with no branch and no
/// memory access that depends on the key or the counter.
///
/// Every byte equals [`block_bytes`]' (the tests below compare them over
/// thousands of random keys and counters, every counter edge, and whole
/// streams through `fill_fp`).
#[cfg(target_arch = "aarch64")]
mod lanes {
    use core::arch::aarch64::*;

    /// bytes per call of the eight-lane step
    pub(super) const GROUP: usize = 8 * 64;

    const IV: [u32; 8] = [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19];
    const SCHEDULE: [[usize; 16]; 7] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8],
        [3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1],
        [10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6],
        [12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4],
        [9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7],
        [11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13],
    ];
    /// CHUNK_START | CHUNK_END | ROOT
    const FLAGS: u32 = 1 | 2 | 8;
    /// the input's length within its one block
    const BLOCK_LEN: u32 = 40;
    /// a byte shuffle that rotates every 32-bit lane right by 8
    const ROT8: [u8; 16] = [1, 2, 3, 0, 5, 6, 7, 4, 9, 10, 11, 8, 13, 14, 15, 12];

    /// the 64-byte block `key || counter_le || 0^24` as sixteen little-endian words
    fn message(key: &[u8; 32], counter: u64) -> [u32; 16] {
        let mut m = [0u32; 16];
        for (i, w) in m[..8].iter_mut().enumerate() {
            *w = u32::from_le_bytes([key[4 * i], key[4 * i + 1], key[4 * i + 2], key[4 * i + 3]]);
        }
        m[8] = counter as u32;
        m[9] = (counter >> 32) as u32;
        m
    }

    #[inline(always)]
    unsafe fn rotr16(x: uint32x4_t) -> uint32x4_t {
        vreinterpretq_u32_u16(vrev32q_u16(vreinterpretq_u16_u32(x)))
    }
    #[inline(always)]
    unsafe fn rotr12(x: uint32x4_t) -> uint32x4_t {
        vsriq_n_u32::<12>(vshlq_n_u32::<20>(x), x)
    }
    #[inline(always)]
    unsafe fn rotr8(x: uint32x4_t, tbl: uint8x16_t) -> uint32x4_t {
        vreinterpretq_u32_u8(vqtbl1q_u8(vreinterpretq_u8_u32(x), tbl))
    }
    #[inline(always)]
    unsafe fn rotr7(x: uint32x4_t) -> uint32x4_t {
        vsriq_n_u32::<7>(vshlq_n_u32::<25>(x), x)
    }

    /// BLAKE3's G on the same four words of both register sets
    #[allow(clippy::too_many_arguments)]
    #[inline(always)]
    unsafe fn g(v: &mut [uint32x4_t; 16], u: &mut [uint32x4_t; 16], a: usize, b: usize, c: usize, d: usize, x: u32, y: u32, tbl: uint8x16_t) {
        let (xv, yv) = (vdupq_n_u32(x), vdupq_n_u32(y));
        v[a] = vaddq_u32(vaddq_u32(v[a], v[b]), xv);
        u[a] = vaddq_u32(vaddq_u32(u[a], u[b]), xv);
        v[d] = rotr16(veorq_u32(v[d], v[a]));
        u[d] = rotr16(veorq_u32(u[d], u[a]));
        v[c] = vaddq_u32(v[c], v[d]);
        u[c] = vaddq_u32(u[c], u[d]);
        v[b] = rotr12(veorq_u32(v[b], v[c]));
        u[b] = rotr12(veorq_u32(u[b], u[c]));
        v[a] = vaddq_u32(vaddq_u32(v[a], v[b]), yv);
        u[a] = vaddq_u32(vaddq_u32(u[a], u[b]), yv);
        v[d] = rotr8(veorq_u32(v[d], v[a]), tbl);
        u[d] = rotr8(veorq_u32(u[d], u[a]), tbl);
        v[c] = vaddq_u32(v[c], v[d]);
        u[c] = vaddq_u32(u[c], u[d]);
        v[b] = rotr7(veorq_u32(v[b], v[c]));
        u[b] = rotr7(veorq_u32(u[b], u[c]));
    }

    /// the root node's starting state for the four counters `t0 .. t0 + 4`
    #[inline(always)]
    unsafe fn start(t0: u32) -> [uint32x4_t; 16] {
        let mut v = [vdupq_n_u32(0); 16];
        for i in 0..8 {
            v[i] = vdupq_n_u32(IV[i]);
        }
        for i in 0..4 {
            v[8 + i] = vdupq_n_u32(IV[i]);
        }
        let t = [t0, t0 + 1, t0 + 2, t0 + 3];
        v[12] = vld1q_u32(t.as_ptr());
        // the counter's high word: `t` stays below 2^32 (the caller's bound)
        v[13] = vdupq_n_u32(0);
        v[14] = vdupq_n_u32(BLOCK_LEN);
        v[15] = vdupq_n_u32(FLAGS);
        v
    }

    /// the full 64-byte output of each lane, written block after block
    /// (lane `j` is block `j` of `out`)
    #[inline(always)]
    unsafe fn store(v: &[uint32x4_t; 16], out: &mut [u8]) {
        assert!(out.len() >= 256);
        let mut w = [vdupq_n_u32(0); 16];
        for i in 0..8 {
            w[i] = veorq_u32(v[i], v[i + 8]);
            w[i + 8] = veorq_u32(v[i + 8], vdupq_n_u32(IV[i]));
        }
        // four 4 x 4 transposes: words 4q .. 4q + 4 of every lane
        let p = out.as_mut_ptr();
        for q in 0..4 {
            let ab = vtrnq_u32(w[4 * q], w[4 * q + 1]);
            let cd = vtrnq_u32(w[4 * q + 2], w[4 * q + 3]);
            let rows = [
                vcombine_u32(vget_low_u32(ab.0), vget_low_u32(cd.0)),
                vcombine_u32(vget_low_u32(ab.1), vget_low_u32(cd.1)),
                vcombine_u32(vget_high_u32(ab.0), vget_high_u32(cd.0)),
                vcombine_u32(vget_high_u32(ab.1), vget_high_u32(cd.1)),
            ];
            for (j, r) in rows.iter().enumerate() {
                // little-endian lanes: the bytes of the words in order (an
                // unaligned 16-byte store inside `out`, bounds asserted above)
                vst1q_u8(p.add(64 * j + 16 * q), vreinterpretq_u8_u32(*r));
            }
        }
    }

    /// output blocks `t0 .. t0 + 8` into `out[..512]`
    #[inline(always)]
    unsafe fn eight(m: &[u32; 16], t0: u32, out: &mut [u8], tbl: uint8x16_t) {
        let mut v = start(t0);
        let mut u = start(t0 + 4);
        for s in SCHEDULE.iter() {
            g(&mut v, &mut u, 0, 4, 8, 12, m[s[0]], m[s[1]], tbl);
            g(&mut v, &mut u, 1, 5, 9, 13, m[s[2]], m[s[3]], tbl);
            g(&mut v, &mut u, 2, 6, 10, 14, m[s[4]], m[s[5]], tbl);
            g(&mut v, &mut u, 3, 7, 11, 15, m[s[6]], m[s[7]], tbl);
            g(&mut v, &mut u, 0, 5, 10, 15, m[s[8]], m[s[9]], tbl);
            g(&mut v, &mut u, 1, 6, 11, 12, m[s[10]], m[s[11]], tbl);
            g(&mut v, &mut u, 2, 7, 8, 13, m[s[12]], m[s[13]], tbl);
            g(&mut v, &mut u, 3, 4, 9, 14, m[s[14]], m[s[15]], tbl);
        }
        store(&v, &mut out[..256]);
        store(&u, &mut out[256..512]);
    }

    /// [`super::block_bytes`]`(key, counter, out)`, for `out` a whole number
    /// of [`GROUP`]s and at most 2^32 output blocks
    pub(super) fn block(key: &[u8; 32], counter: u64, out: &mut [u8]) {
        assert!(out.len() % GROUP == 0 && out.len() / 64 <= 1 << 32, "rng lanes: whole groups below 2^32 blocks");
        let m = message(key, counter);
        // SAFETY: NEON is part of the aarch64 baseline; every store is inside
        // `out` (each `eight` writes exactly its own 512-byte group)
        unsafe {
            let tbl = vld1q_u8(ROT8.as_ptr());
            for (k, group) in out.chunks_exact_mut(GROUP).enumerate() {
                eight(&m, (8 * k) as u32, group, tbl);
            }
        }
    }
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
        // [A14] the chunks' blocks in the process's XOF form (the same bytes)
        let form = xof_form();
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
                        block_bytes_in(form, &key, c0 + b as u64, &mut blk);
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
            block_bytes_in(form, &key, c0 + nb as u64 - 1, &mut self.buf);
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

    /// [A14] The eight-lane form gives `block_bytes`' bytes, word for word:
    /// 4,000 pseudo-random keys and counters, every counter edge (0, 1, the
    /// 32-bit boundary, the top), whole 8 KiB stream blocks and shorter whole
    /// groups. On a target without the lanes, `block_bytes_in` IS
    /// `block_bytes`, and the comparison still holds.
    #[test]
    fn a14_the_lane_xof_equals_block_bytes_word_for_word() {
        let mut s = 0x9e37_79b9_7f4a_7c15u64;
        let mut next = move || {
            s ^= s << 13;
            s ^= s >> 7;
            s ^= s << 17;
            s
        };
        let edges = [0u64, 1, 2, 7, 8, 255, 256, u32::MAX as u64 - 1, u32::MAX as u64, 1 << 32, (1 << 32) + 1, u64::MAX - 1, u64::MAX];
        let (mut want, mut got) = (vec![0u8; RNG_BLOCK], vec![0u8; RNG_BLOCK]);
        let mut checked = 0usize;
        for i in 0..4000 {
            let mut key = [0u8; 32];
            for c in key.chunks_mut(8) {
                c.copy_from_slice(&next().to_le_bytes());
            }
            if i == 0 {
                key = [0u8; 32];
            } else if i == 1 {
                key = [0xff; 32];
            }
            let counter = if i < edges.len() { edges[i] } else { next() };
            let len = [RNG_BLOCK, 512, 1024, 4096][i % 4];
            block_bytes(&key, counter, &mut want[..len]);
            got[..len].fill(0xa5);
            block_bytes_in(XofForm::Lanes8, &key, counter, &mut got[..len]);
            assert!(want[..len] == got[..len], "key #{i} counter {counter} len {len}: the lane XOF differs from block_bytes");
            block_bytes_in(XofForm::Blake3, &key, counter, &mut got[..len]);
            assert!(want[..len] == got[..len], "key #{i}: the blake3 form differs from block_bytes");
            checked += len;
        }
        // a length that is not whole groups takes block_bytes itself
        let mut odd = vec![0u8; 100];
        let mut odd_want = vec![0u8; 100];
        block_bytes(&[3u8; 32], 9, &mut odd_want);
        block_bytes_in(XofForm::Lanes8, &[3u8; 32], 9, &mut odd);
        assert_eq!(odd, odd_want);
        eprintln!("A14-XOF: {checked} bytes of 4000 blocks equal block_bytes in both forms (lanes on this target: {})", cfg!(target_arch = "aarch64"));
    }

    /// [A14] `fill_fp` in either XOF form equals the `fp()` loop word for word
    /// and leaves the same state (`buf`, `pos`, `counter`), from every
    /// alignment and at lengths around the chunk and block edges; later draws
    /// agree too. The process's form is restored after.
    #[test]
    fn a14_fill_fp_in_either_xof_form_equals_the_draw_loop() {
        let lens = [0usize, 1, FILL_PAR_MIN - 1, FILL_PAR_MIN, FILL_PAR_MIN + 1, FILL_CHUNK * 3 + 7, 4 * FILL_CHUNK, 100_003, 1 << 20];
        let leads = [0usize, 1, 3, 1023, 1024, 1025];
        for form in [XofForm::Blake3, XofForm::Lanes8] {
            for &lead in &leads {
                for &len in &lens {
                    let mut a = ZkRng::new(41, b"a14-fill");
                    let mut b = ZkRng::new(41, b"a14-fill");
                    for _ in 0..lead {
                        assert_eq!(a.next_u64(), b.next_u64());
                    }
                    let want: Vec<Fp> = (0..len).map(|_| a.fp()).collect();
                    let mut got = vec![Fp::ZERO; len];
                    set_xof_form(Some(form));
                    b.fill_fp(&mut got);
                    set_xof_form(None);
                    assert!(want == got, "{form:?} lead {lead} len {len}: draws differ");
                    assert_eq!((a.counter, a.pos), (b.counter, b.pos), "{form:?} lead {lead} len {len}: state differs");
                    assert!(a.buf == b.buf, "{form:?} lead {lead} len {len}: buffer differs");
                    for _ in 0..2100 {
                        assert_eq!(a.next_u64(), b.next_u64());
                    }
                    assert_eq!(a.bytes32(), b.bytes32());
                }
            }
        }
        set_xof_form(None);
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
