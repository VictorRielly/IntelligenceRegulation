//! Exact byte-aligned group scaling, with verifier-derived public tables.
use super::accuracy_groups::{Group, GroupFolds};
use super::accuracy_precision::Stack;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Aligned {
    pub folds: GroupFolds,
    pub tables: Vec<Vec<i64>>,
}

pub(crate) fn derive_aligned(
    _stack: Stack, _groups: &[Group], _ids: &[usize], _gate: &[u64],
    _base_in: i32, _base_out: i32, _base_sh_g: u32, _base_sh_h: u32,
) -> Result<Aligned, String> {
    Err("R13 aligned group scaling not implemented".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::accuracy::requant;
    use super::super::accuracy_tables::{silu_table, SILU_MEMBERS};

    #[test]
    fn both_stacks_match_every_independent_rational_product_vector() {
        for (stack, text, extra, denominator) in [
            (Stack::LowH24, include_str!("../working-tree/hashline/src/private_block/r13_vectors/r13_product_vectors.tsv"), 8, 16),
            (Stack::Low, include_str!("../working-tree/hashline/src/private_block/r13_vectors/r13_product_low_vectors.tsv"), 0, 24),
        ] {
            for row in text.lines() {
                let v: Vec<i64> = row.split('\t').map(|s| s.parse().unwrap()).collect();
                let (base_in, base_out) = if v[3] >= 0 { (-5, -13) } else { (-1, -9) };
                let member = SILU_MEMBERS.iter().find(|&&(_, out)| out == base_out + v[3] as i32).unwrap();
                let groups = [Group { e_in: member.0, e_out: member.1 }];
                let aligned = derive_aligned(stack, &groups, &[0], &[1], base_in, base_out, 8, v[2] as u32 + extra).unwrap();
                assert_eq!(aligned.folds.product.shift, denominator);
                let got = requant(v[0] as i128 * v[1] as i128, aligned.folds.product.multipliers[0], denominator).unwrap();
                assert_eq!(got.word, v[4], "{stack:?}: {row}");
            }
        }
    }

    #[test]
    fn tables_scale_the_quantized_words_without_another_rounding() {
        let groups = [Group { e_in: -4, e_out: -13 }, Group { e_in: -1, e_out: -11 }];
        let h24 = derive_aligned(Stack::LowH24, &groups, &[0, 1], &[4, 11], -3, -11, 8, 14).unwrap();
        let low = derive_aligned(Stack::Low, &groups, &[0, 1], &[4, 11], -3, -11, 8, 14).unwrap();
        assert_eq!(h24.tables, low.tables);
        assert_eq!(h24.folds.product.multipliers, vec![256, 1024]);
        assert_eq!(low.folds.product.multipliers, vec![256, 1024]);
        for (index, group) in groups.iter().enumerate() {
            let raw = silu_table(group.e_in, group.e_out, 12).unwrap();
            for (word, scaled) in raw.into_iter().zip(&h24.tables[index]) {
                assert_eq!(word as i64 * [256, 1024][index], *scaled);
            }
        }
    }

    #[test]
    fn every_registry_combination_respects_the_derived_31_bit_bound() {
        for &(base_in, base_out) in &SILU_MEMBERS {
            for &(e_in, e_out) in &SILU_MEMBERS {
                for h in 13..=16 {
                    let a = derive_aligned(Stack::LowH24, &[Group { e_in, e_out }], &[0], &[1], base_in, base_out, 8, h).unwrap();
                    assert!(a.folds.product.multipliers[0] <= 1 << 15);
                    assert!(a.tables[0].iter().all(|v| v.abs() <= 32767 * (1 << 15)));
                }
            }
        }
    }

    #[test]
    fn the_legacy_profile_cannot_select_this_construction() {
        assert!(derive_aligned(Stack::Legacy, &[Group { e_in: -3, e_out: -11 }], &[0], &[1], -3, -11, 8, 14).is_err());
    }
}
