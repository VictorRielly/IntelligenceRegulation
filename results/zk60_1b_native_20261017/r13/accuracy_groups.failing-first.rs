//! R13 group input/output scaling in public common denominators.
//! Not yet imported into the prover; capture failing-first tests before use.
use super::accuracy_tables::SILU_MEMBERS;

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
    _groups: &[Group], _ids: &[usize], _gate_multipliers: &[u64],
    _base_e_in: i32, _base_e_out: i32, _base_sh_g: u32, _base_sh_h: u32,
) -> Result<GroupFolds, String> {
    Err("R13 group folds not implemented".into())
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
