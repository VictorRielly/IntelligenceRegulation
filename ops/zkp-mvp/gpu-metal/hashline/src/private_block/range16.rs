//! **W16 (D54): 16-bit tagged range lookups for the R13 accuracy stack.**
//!
//! Design and exact counts: `results/zk60_limb16_20261031/DESIGN.md`. A W16
//! profile is opt-in by its profile string (`shape::W16_PROFILES`). No R13 or
//! legacy profile reaches this module, so no existing byte moves.
//!
//! The construction in one paragraph:
//! - A lookup carries a width `w`. It folds to `q + gamma * tag(w)`.
//! - The table holds `v + gamma * tag(w)` for every `0 <= v < 2^w` of every
//!   width the profile uses. The byte width 8 keeps the existing U8 family.
//! - A signed 16-bit word is looked up directly as `word + 32768`, with no
//!   limb plane.
//! - A remainder of `b <= 16` bits is one plane and one query. A remainder of
//!   `16 < b <= 24` bits is a low 16-bit limb and a `b - 16`-bit top limb.
//! - Every table family is laid over `Dom::Tab` sub-planes of exactly one row
//!   width, so `log(Dom::Tab) == log_cols` still holds (the S-1 lift condition
//!   of `layout::domain_log_at`).
//! - Padded positions of a sub-plane repeat an entry of the same sub-plane.
//!   Their multiplicity is held to zero by the pad rule, as P-3 does for U8.
use super::accuracy_precision::{Precision, Stack};
use super::layout::{Lk, LkTag, SH_ROPE};
use crate::field::{Fp, Fp2};
use crate::tables_attn::TAG_U8;

/// the first range-family tag; distinct mod p from every other LogUp tag
/// (1, 2, 128..=134, 141)
pub(crate) const TAG_RANGE0: u64 = 200;

/// the LogUp tag of a `width`-bit range family
pub(crate) fn tag_value(width: u32) -> u64 {
    TAG_RANGE0 + u64::from(width)
}

/// the lookup tag of a `width`-bit range check: a byte check keeps the U8
/// family (the same table, the same histogram)
pub(crate) fn lk_tag(width: u32) -> LkTag {
    if width == 8 {
        LkTag::U8
    } else {
        LkTag::Range(width)
    }
}

/// `gamma * tag_value(width)`, from `g_u8 = gamma * TAG_U8`. The prover and
/// the verifier both call this one function, so the two sides fold the same
/// element. It needs no new transcript draw and no new `Ctx` field.
pub(crate) fn g_range(g_u8: Fp2, width: u32) -> Fp2 {
    g_u8.mul_base(Fp::new(tag_value(width)).mul(Fp::new(TAG_U8).inv()))
}

/// the fold constant of one lookup's tag
pub(crate) fn g_of(tag: LkTag, g_u8: Fp2) -> Fp2 {
    match tag {
        LkTag::U8 => g_u8,
        LkTag::Range(w) => g_range(g_u8, w),
    }
}

/// limb planes of a `bits`-bit remainder at 16-bit limbs
pub(crate) fn limbs_of(bits: u32) -> usize {
    assert!((1..=24).contains(&bits), "W16: a remainder window outside 1..=24 bits");
    if bits <= 16 {
        1
    } else {
        2
    }
}

/// the lookups of a `bits`-bit remainder held in `planes` (low limb first)
pub(crate) fn rem_lookups(planes: &[usize], bits: u32) -> Vec<Lk> {
    assert_eq!(planes.len(), limbs_of(bits), "W16: a remainder's limb count");
    if bits <= 16 {
        vec![Lk::tagged(vec![(planes[0], 1)], 0, lk_tag(bits))]
    } else {
        vec![Lk::tagged(vec![(planes[0], 1)], 0, LkTag::Range(16)), Lk::tagged(vec![(planes[1], 1)], 0, lk_tag(bits - 16))]
    }
}

/// a signed 16-bit word, looked up directly: `word + bias` in `[0, 2^16)`
pub(crate) fn word16(plane: usize, bias: i64) -> Lk {
    Lk::tagged(vec![(plane, 1)], bias, LkTag::Range(16))
}

/// A signed 24-bit word with one committed, SIGNED top limb
/// `t = floor((word + bias) / 2^16) - bias / 2^16`. The low limb is the
/// expression `word - 2^16 t + (bias mod 2^16)` (16 bits) and `t + bias / 2^16`
/// is a byte, so `word + bias` is proved in `[0, 2^24)` exactly as three byte
/// limbs prove it. The top is signed so that a PADDED position, where the pad
/// rule holds both the word and `t` at zero, still hits both tables
/// (`low = 0`, `t + 128 = 128` at the LowH24 bias `2^23`).
pub(crate) fn word24(word: usize, top: usize, bias: i64) -> [Lk; 2] {
    [Lk::tagged(vec![(word, 1), (top, -(1i64 << 16))], bias & 0xffff, LkTag::Range(16)), Lk::tagged(vec![(top, 1)], bias >> 16, LkTag::U8)]
}

/// the signed top limb [`word24`] commits for `word` at `bias`
pub(crate) fn word24_top(word: i64, bias: i64) -> i64 {
    ((word + bias) >> 16) - (bias >> 16)
}

/// a `bits`-bit word looked up directly (the softmax quotient `P`)
pub(crate) fn direct(plane: usize, bits: u32) -> Lk {
    assert!(bits <= 16, "W16: a direct word wider than 16 bits");
    Lk::tagged(vec![(plane, 1)], 0, lk_tag(bits))
}

/// **The range widths a W16 profile looks up**, the byte width excluded, in
/// ascending order. This is the SHAPE's independent statement of the set;
/// `AccuracyIds::new_w16` collects the same set from its lookups and refuses
/// a mismatch.
pub(crate) fn widths(stack: Stack, p: &Precision, gate_shift: u32, wrho_s: u32) -> Vec<u32> {
    let h24 = stack == Stack::LowH24;
    let mut w = vec![16u32];
    let mut rem = |bits: u32| {
        if bits <= 16 {
            w.push(bits);
        } else {
            w.push(16);
            w.push(bits - 16);
        }
    };
    // Dom::D: the four norm remainders (24 bits), the attention output's and
    // the down projection's remainders
    rem(24);
    rem(p.ao);
    rem(p.down);
    // Dom::Q and Dom::Kv
    for bits in [p.q, SH_ROPE, p.pv, p.k, p.v, SH_ROPE] {
        rem(bits);
    }
    // Dom::F: the gate, up and product remainders
    rem(gate_shift);
    rem(p.up);
    rem(if h24 { 16 } else { 24 });
    // Dom::S (or Dom::Dd): the score remainder, the quotient, the division
    rem(p.score);
    rem(p.f_p + 1);
    rem(wrho_s);
    w.retain(|&x| x != 8);
    w.sort_unstable();
    w.dedup();
    w
}

/// One range family: the values `0 .. 2^width`, laid over `sub` `Dom::Tab`
/// sub-planes of `2^log_cols` entries.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Fam {
    pub width: u32,
    pub sub: usize,
}

/// the families of a set of widths at a row width of `2^log_cols`
pub(crate) fn families(widths: &[u32], log_cols: usize) -> Vec<Fam> {
    widths.iter().map(|&width| Fam { width, sub: ((1usize << width) >> log_cols).max(1) }).collect()
}

/// every sub-plane of every family, in plane order: `(family, sub-plane)`
pub(crate) fn sub_planes(fams: &[Fam]) -> Vec<(Fam, usize)> {
    fams.iter().flat_map(|f| (0..f.sub).map(move |s| (*f, s))).collect()
}

/// the entries of one sub-plane that are true table rows
pub(crate) fn support(f: Fam, log_cols: usize) -> usize {
    (1usize << f.width).min(1usize << log_cols)
}

/// is every entry of this family's sub-planes a true row (no padded copy)?
pub(crate) fn full(f: Fam, log_cols: usize) -> bool {
    support(f, log_cols) == 1usize << log_cols
}

/// the integer table value at position `i` of sub-plane `s`. A padded
/// position repeats an entry of the SAME sub-plane, so the proved set is
/// exactly `0 .. 2^width` whatever the row width is (P-3's condition 1).
pub(crate) fn value(f: Fam, s: usize, i: usize, log_cols: usize) -> i64 {
    (s * (1usize << log_cols) + i % support(f, log_cols)) as i64
}

/// one sub-plane's public table column `value + g`
pub(crate) fn table_column(f: Fam, s: usize, log_cols: usize, g: Fp2) -> Vec<Fp2> {
    (0..1usize << log_cols).map(|i| Fp2::from_i64(value(f, s, i, log_cols)).add(g)).collect()
}

/// one sub-plane's public support indicator (1 on a true row, 0 on a padded copy)
pub(crate) fn support_column(f: Fam, log_cols: usize) -> Vec<Fp2> {
    let n = support(f, log_cols);
    (0..1usize << log_cols).map(|i| if i < n { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// `1 / (alpha - (v + g))` for every `v` in `0 .. 2^width`; `None` where the
/// denominator is zero (the prover then refuses, as the U8 table does)
pub(crate) fn denominator_inverses(width: u32, alpha: Fp2, g: Fp2) -> Vec<Option<Fp2>> {
    let n = 1usize << width;
    let den: Vec<Fp2> = (0..n).map(|v| alpha.sub(Fp2::from_i64(v as i64).add(g))).collect();
    let mut out = vec![None; n];
    let nonzero: Vec<usize> = (0..n).filter(|&v| den[v] != Fp2::ZERO).collect();
    // one batch inversion over the nonzero denominators
    let mut acc = Vec::with_capacity(nonzero.len());
    let mut run = Fp2::ONE;
    for &v in &nonzero {
        acc.push(run);
        run = run.mul(den[v]);
    }
    let mut inv = run.inv();
    for (j, &v) in nonzero.iter().enumerate().rev() {
        out[v] = Some(inv.mul(acc[j]));
        inv = inv.mul(den[v]);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn families_fill_whole_rows_and_small_widths_pad_by_repetition() {
        let f = families(&[2, 13, 15, 16], 14);
        assert_eq!(f.iter().map(|x| x.sub).collect::<Vec<_>>(), vec![1, 1, 2, 4]);
        let w16 = f[3];
        assert!(full(w16, 14));
        assert_eq!(value(w16, 3, 16383, 14), 65535);
        let w2 = f[0];
        assert!(!full(w2, 14));
        assert_eq!((value(w2, 0, 3, 14), value(w2, 0, 4, 14), value(w2, 0, 16383, 14)), (3, 0, 3));
        assert_eq!(sub_planes(&f).len(), 8);
    }

    #[test]
    fn the_range_tags_are_distinct_from_every_other_family() {
        let others = [1u64, 2, 128, 129, 130, 131, 132, 133, 134, 141];
        for w in 1..=24 {
            assert!(!others.contains(&tag_value(w)));
        }
        let g_u8 = Fp2::new(Fp::new(5), Fp::new(9));
        // gamma * TAG_U8 * (tag / TAG_U8) is gamma * tag
        let gamma = g_u8.mul_base(Fp::new(TAG_U8).inv());
        assert_eq!(g_range(g_u8, 16), gamma.mul_base(Fp::new(tag_value(16))));
        assert_eq!(g_of(LkTag::U8, g_u8), g_u8);
    }

    #[test]
    fn denominator_inverses_invert_every_nonzero_entry() {
        let (alpha, g) = (Fp2::new(Fp::new(77), Fp::new(3)), Fp2::new(Fp::new(11), Fp::new(0)));
        let inv = denominator_inverses(5, alpha, g);
        for (v, x) in inv.iter().enumerate() {
            let d = alpha.sub(Fp2::from_i64(v as i64).add(g));
            assert_eq!(x.unwrap().mul(d), Fp2::ONE);
        }
        // a zero denominator is reported, not inverted
        let alpha0 = Fp2::from_i64(3).add(g);
        assert!(denominator_inverses(3, alpha0, g)[3].is_none());
    }
}
