//! Exact byte-aligned group scaling, with verifier-derived public tables.
use super::accuracy_groups::{Group, GroupFolds};
use super::accuracy_precision::Stack;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Aligned {
    pub folds: GroupFolds,
    pub tables: Vec<Vec<i64>>,
}

pub(crate) fn derive_aligned(
    stack: Stack, groups: &[Group], ids: &[usize], gate: &[u64],
    base_in: i32, base_out: i32, base_sh_g: u32, base_sh_h: u32,
) -> Result<Aligned, String> {
    use super::accuracy_groups::{group_folds, Folded};
    use super::accuracy_tables::silu_table;
    let shift = match stack {
        Stack::Low => 24,
        Stack::LowH24 => 16,
        Stack::Legacy => return Err("R13 aligned scaling requires an explicit LOW stack".into()),
    };
    // This validates the registry, canonical ordering, used IDs, narrow gate
    // multipliers and the base calibration before any indexed access.
    let original = group_folds(groups, ids, gate, base_in, base_out, base_sh_g, base_sh_h)?;
    let mut coefficients = Vec::with_capacity(groups.len());
    let mut tables = Vec::with_capacity(groups.len());
    for group in groups {
        // R - H + delta = 24 - base_sh_h + delta for BOTH presets.
        let exponent = 24i64 - base_sh_h as i64 + (group.e_out - base_out) as i64;
        if !(4..=15).contains(&exponent) {
            return Err("R13 derived table: scale exceeds the no-wrap class".into());
        }
        let coefficient = 1u64 << exponent;
        let raw = silu_table(group.e_in, group.e_out, 12)?;
        let table = raw.into_iter().map(|word| {
            (word as i64).checked_mul(coefficient as i64).filter(|v| v.abs() <= 32767 * (1 << 15))
                .ok_or_else(|| "R13 derived table: output exceeds signed31".to_string())
        }).collect::<Result<Vec<_>, _>>()?;
        coefficients.push(coefficient);
        tables.push(table);
    }
    let product = Folded { shift, multipliers: ids.iter().map(|&id| coefficients[id]).collect() };
    Ok(Aligned { folds: GroupFolds { gate: original.gate, product }, tables })
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::accuracy::requant;
    use super::super::accuracy_tables::{silu_table, SILU_MEMBERS};

    #[test]
    fn both_stacks_match_every_independent_rational_product_vector() {
        for (stack, text, extra, denominator) in [
            (Stack::LowH24, include_str!("r13_vectors/r13_product_vectors.tsv"), 8, 16),
            (Stack::Low, include_str!("r13_vectors/r13_product_low_vectors.tsv"), 0, 24),
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
