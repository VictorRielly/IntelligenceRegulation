//! SYNTHETIC-ONLY deterministic public model words for tests and demos.
//!
//! Generated here from a fixed integer LCG and integer formulas: no floats,
//! no fitting, no training, no canonical RoPE/exp/SiLU tables. The lookup
//! tables merely pass the block kernel's structural validation; they are
//! NOT the registered fixture tables and must never be presented as such.
//! The two blocks use different seeds AND different tables, so block order
//! and each block's words matter.

use crate::{ModelError, PublicModel, RawBlock, RawModel, D, LAYERS, ROPE_LEN, TABLE_LEN};
use private_block_kernel::HALF;

/// Version label of this synthetic construction (change it with the words).
pub const SYNTHETIC_LABEL: &str = "zk60-synthetic-token-model v1 (NOT trained, NOT canonical tables)";

struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 33
    }
    /// Uniform in `[-amp, amp]`.
    fn range(&mut self, amp: i64) -> i64 {
        (self.next() % (2 * amp as u64 + 1)) as i64 - amp
    }
    fn i8s<const N: usize>(&mut self, amp: i64) -> [i8; N] {
        core::array::from_fn(|_| self.range(amp) as i8)
    }
}

/// Integer-formula tables that pass structural validation (position 0 is
/// the identity rotation, |cos|,|sin| <= 128, exp starts at 512 and is
/// non-increasing in [0, 512]); `variant` selects a different table set.
pub fn synthetic_tables(variant: u32) -> ([i64; ROPE_LEN], [i64; ROPE_LEN], [i64; 256], [i16; 256]) {
    let v = variant as usize;
    let mut c = [0i64; ROPE_LEN];
    let mut s = [0i64; ROPE_LEN];
    for t in 0..crate::CTX {
        for i in 0..HALF {
            let at = t * HALF + i;
            if t == 0 {
                c[at] = 128;
            } else {
                c[at] = 128 - 7 * ((t + i + v) % 5) as i64 - 40 * (1 + v as i64 % 2);
                s[at] = ((t * (3 + v) + i) % 9) as i64 * 13 - 52;
            }
        }
    }
    let step = 6 + 3 * (v as u32 % 2);
    let e: [i64; 256] = core::array::from_fn(|d| 512i64 >> (d as u32 / step).min(10));
    let a: [i16; 256] = core::array::from_fn(|i| {
        let g = i as i16 - 128;
        if v % 2 == 0 {
            g * 37 + 11
        } else if g < 0 {
            g * 6 - 5
        } else {
            g * 41 - 5
        }
    });
    (c, s, e, a)
}

/// Amplitudes are chosen so that NO kernel range site can refuse for any
/// block input (see README "Why the synthetic model never refuses"):
/// gamma in [16, 48], Q/K off-diagonal |w| <= 16 (diagonal 48), V
/// off-diagonal |w| <= 40 (diagonal 64), |wo| <= 90, |wg|,|wu| <= 30,
/// |wd| <= 90. A block adds at most 540 (attention) + 8304 (FFN) per word.
fn synthetic_block(seed: u64, variant: u32) -> RawBlock {
    let mut r = Lcg(seed);
    let mut wq: [i8; 256] = r.i8s(16);
    let mut wk: [i8; 128] = r.i8s(16);
    let mut wv: [i8; 128] = r.i8s(40);
    for i in 0..D {
        wq[i * D + i] = 48;
    }
    for i in 0..8 {
        wk[i * D + i] = 48;
        wv[i * D + i] = 64;
    }
    let (rope_cos, rope_sin, exp, act) = synthetic_tables(variant);
    RawBlock {
        wq,
        wk,
        wv,
        wo: r.i8s(90),
        gamma_a: core::array::from_fn(|_| (32 + r.range(16)) as i8),
        gamma_m: core::array::from_fn(|_| (32 + r.range(16)) as i8),
        wg_t: r.i8s(30),
        wu_t: r.i8s(30),
        wd_t: r.i8s(90),
        rope_cos,
        rope_sin,
        exp,
        act,
    }
}

/// The SYNTHETIC-ONLY model words (deterministic). Signed embeddings in
/// [-64, 64] (small next to the blocks' additive contributions, so both
/// blocks move the result), signed gamma_f, full signed-int8 head
/// including -128.
pub fn synthetic_raw_model() -> RawModel {
    let mut r = Lcg(0x5a60_7e57);
    let embed: [i16; TABLE_LEN] = core::array::from_fn(|_| r.range(64) as i16);
    let mut gamma_f: [i8; D] = core::array::from_fn(|_| r.range(127) as i8);
    gamma_f[0] = -97;
    let mut head: [i8; TABLE_LEN] = r.i8s(127);
    head[5] = -128;
    let blocks: [RawBlock; LAYERS] = [synthetic_block(0xb10c_0000, 0), synthetic_block(0xb10c_0001, 1)];
    RawModel { embed, blocks, gamma_f, head }
}

/// [`synthetic_raw_model`] built into a [`PublicModel`].
pub fn synthetic_model() -> Result<PublicModel, ModelError> {
    synthetic_raw_model().build()
}
