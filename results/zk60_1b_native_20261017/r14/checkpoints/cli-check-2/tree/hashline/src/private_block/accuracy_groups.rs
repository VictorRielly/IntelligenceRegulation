//! R13 group input/output scaling in public common denominators.
//! Not yet imported into the prover.
use super::accuracy_tables::Registry;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Group {
    pub e_in: i32,
    pub e_out: i32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Folded {
    pub shift: u32,
    pub multipliers: Vec<u64>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct GroupFolds {
    pub gate: Folded,
    pub product: Folded,
}

pub(crate) fn group_folds(
    groups: &[Group], ids: &[usize], gate_multipliers: &[u64],
    base_e_in: i32, base_e_out: i32, base_sh_g: u32, base_sh_h: u32,
) -> Result<GroupFolds, String> {
    group_folds_for(Registry::Standard, groups, ids, gate_multipliers, base_e_in, base_e_out, base_sh_g, base_sh_h)
}

pub(crate) fn group_folds_for(
    registry: Registry, groups: &[Group], ids: &[usize], gate_multipliers: &[u64],
    base_e_in: i32, base_e_out: i32, base_sh_g: u32, base_sh_h: u32,
) -> Result<GroupFolds, String> {
    if groups.is_empty() || groups.len() > 4 || ids.is_empty() || ids.len() != gate_multipliers.len() {
        return Err("R13 groups: one to four groups and matching nonempty channel arrays required".into());
    }
    if !registry.permits((base_e_in, base_e_out)) || !(1..=8).contains(&base_sh_g) || !(13..=16).contains(&base_sh_h) {
        return Err("R13 groups: base member or shift is outside the declared class".into());
    }
    if groups.iter().any(|g| !registry.permits((g.e_in, g.e_out)))
        || groups.windows(2).any(|pair| (pair[0].e_in, pair[0].e_out) >= (pair[1].e_in, pair[1].e_out)) {
        return Err("R13 groups: registry members must be unique and in canonical order".into());
    }
    if ids.iter().any(|&id| id >= groups.len()) || (0..groups.len()).any(|id| !ids.contains(&id))
        || gate_multipliers.iter().any(|&m| !(1..=64).contains(&m)) {
        return Err("R13 groups: invalid group id, unused group or non-narrow gate multiplier".into());
    }
    let gate_shifts: Vec<i64> = ids.iter().map(|&id| base_sh_g as i64 + 10 + (groups[id].e_in - base_e_in) as i64).collect();
    let product_shifts: Vec<i64> = ids.iter().map(|&id| base_sh_h as i64 - 8 - (groups[id].e_out - base_e_out) as i64).collect();
    let gate_shift = (*gate_shifts.iter().max().unwrap()).max(17);
    // A zero direct shift is represented exactly by multiplier 2 / 2.
    let product_shift = (*product_shifts.iter().max().unwrap()).max(1);
    if gate_shifts.iter().any(|&s| !(1..=24).contains(&s)) || gate_shift > 24
        || product_shifts.iter().any(|&s| !registry.product_shifts().contains(&s)) {
        return Err("R13 groups: effective shift is outside the counted window".into());
    }
    let mut gate = Vec::with_capacity(ids.len());
    let mut product = Vec::with_capacity(ids.len());
    for channel in 0..ids.len() {
        let g = gate_multipliers[channel].checked_shl((gate_shift - gate_shifts[channel]) as u32)
            .ok_or("R13 groups: folded gate coefficient overflow")?;
        let h = 1u64.checked_shl((product_shift - product_shifts[channel]) as u32)
            .ok_or("R13 groups: folded product coefficient overflow")?;
        if g > 1 << 14 || h > 1 << 8 {
            return Err("R13 groups: folded coefficient exceeds the no-wrap class".into());
        }
        gate.push(g);
        product.push(h);
    }
    Ok(GroupFolds {
        gate: Folded { shift: gate_shift as u32, multipliers: gate },
        product: Folded { shift: product_shift as u32, multipliers: product },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::accuracy::{product, requant};

    const GROUPS: [Group; 2] = [Group { e_in: -4, e_out: -13 }, Group { e_in: -1, e_out: -11 }];

    #[test]
    fn folding_matches_the_independent_block_fixture_constants() {
        let result = group_folds(&GROUPS, &[0, 1], &[4, 11], -3, -11, 8, 14).unwrap();
        assert_eq!(result.gate, Folded { shift: 20, multipliers: vec![32, 11] });
        assert_eq!(result.product, Folded { shift: 8, multipliers: vec![1, 4] });
    }

    #[test]
    fn common_denominators_preserve_every_rounding_and_remainder() {
        let ids = [0, 1, 0, 1];
        let multipliers = [1, 64, 63, 7];
        let result = group_folds(&GROUPS, &ids, &multipliers, -3, -11, 8, 14).unwrap();
        for (channel, &id) in ids.iter().enumerate() {
            for accumulator in [-1_000_000i128, -257, -1, 0, 1, 511, 1_000_000] {
                let original_shift = (18 + GROUPS[id].e_in + 3) as u32;
                let direct = requant(accumulator, multipliers[channel], original_shift).unwrap();
                let folded = requant(accumulator, result.gate.multipliers[channel], result.gate.shift).unwrap();
                assert_eq!(direct.word, folded.word);
                let delta = GROUPS[id].e_out + 11;
                let direct = product(accumulator as i64, 17, 6, delta).unwrap();
                let folded = requant(accumulator * 17, result.product.multipliers[channel], result.product.shift).unwrap();
                assert_eq!(direct.word, folded.word);
            }
        }
    }

    #[test]
    fn the_product_window_grows_when_exact_group_scaling_needs_it() {
        let result = group_folds(&GROUPS, &[0, 1], &[1, 1], -3, -11, 8, 16).unwrap();
        assert_eq!(result.product.shift, 10);
        assert_eq!(result.product.shift.div_ceil(8), 2);
    }

    #[test]
    fn malformed_and_noncanonical_group_data_is_refused() {
        assert!(group_folds(&[], &[0], &[1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[], &[], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[0], &[1, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[0, 2], &[1, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[0, 0], &[1, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&[GROUPS[0], GROUPS[0]], &[0, 1], &[1, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[0, 1], &[0, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&GROUPS, &[0, 1], &[65, 1], -3, -11, 8, 14).is_err());
        assert!(group_folds(&[Group { e_in: -6, e_out: -13 }], &[0], &[1], -3, -11, 8, 14).is_err());
    }
}
