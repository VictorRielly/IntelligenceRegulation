//! Typed and bound public R13 data. Failing-first source, not yet imported
//! into the prover.
use super::accuracy_groups::{Group, GroupFolds};
use super::accuracy_precision::{BaseShifts, Precision, Stack};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Geometry {
    pub width: usize,
    pub query_width: usize,
    pub kv_width: usize,
    pub hidden: usize,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Multipliers {
    pub q: Vec<u16>, pub k: Vec<u16>, pub v: Vec<u16>, pub o: Vec<u16>,
    pub g: Vec<u16>, pub u: Vec<u16>, pub d: Vec<u16>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct AccuracyPublic {
    geometry: Geometry,
    base: BaseShifts,
    member: (i32, i32),
    multipliers: Multipliers,
    groups: Vec<Group>,
    group_ids: Vec<usize>,
    tables: Vec<Vec<i16>>,
    precision: Precision,
    folds: GroupFolds,
}

impl AccuracyPublic {
    pub(crate) fn new(
        _geometry: Geometry, _base: BaseShifts, _member: (i32, i32),
        _multipliers: Multipliers, _groups: Vec<Group>, _group_ids: Vec<usize>, _tables: Vec<Vec<i16>>,
    ) -> Result<Self, String> {
        Err("R13 public data not implemented".into())
    }
    pub(crate) fn encode(&self) -> Vec<u8> { Vec::new() }
    pub(crate) fn check_for(&self, _geometry: Geometry, _base: BaseShifts, _stack: Stack) -> Result<(), String> {
        Err("R13 public-data context check not implemented".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::accuracy_tables::silu_table;
    const GEO: Geometry = Geometry { width: 4, query_width: 8, kv_width: 4, hidden: 6 };
    const BASE: BaseShifts = BaseShifts { norm_tn: 10, qkv: 8, score: 6, pv: 9, ao: 7, gate: 8, up: 0, product: 14, down: 6 };

    fn multipliers() -> Multipliers {
        Multipliers { q: vec![1; 8], k: vec![1; 4], v: vec![1; 4], o: vec![1; 4],
                      g: vec![1; 6], u: vec![1; 6], d: vec![1; 4] }
    }
    fn rows(m: &mut Multipliers) -> [&mut Vec<u16>; 7] {
        [&mut m.q, &mut m.k, &mut m.v, &mut m.o, &mut m.g, &mut m.u, &mut m.d]
    }
    fn data(m: Multipliers) -> Result<AccuracyPublic, String> {
        let groups = vec![Group { e_in: -4, e_out: -13 }, Group { e_in: -1, e_out: -11 }];
        let tables = groups.iter().map(|g| silu_table(g.e_in, g.e_out, 12).unwrap()).collect();
        AccuracyPublic::new(GEO, BASE, (-3, -11), m, groups, vec![0, 1, 0, 1, 0, 1], tables)
    }

    #[test]
    fn honest_data_has_a_canonical_binding_and_exact_context() {
        let a = data(multipliers()).unwrap();
        assert_eq!(a.encode(), data(multipliers()).unwrap().encode());
        assert!(a.encode().len() > 8192);
        a.check_for(GEO, BASE, Stack::LowH24).unwrap();
        assert!(a.check_for(GEO, BASE, Stack::Legacy).is_err());
        assert!(a.check_for(Geometry { query_width: 4, ..GEO }, BASE, Stack::LowH24).is_err());
        assert!(a.check_for(GEO, BaseShifts { score: 7, ..BASE }, Stack::LowH24).is_err());
    }

    #[test]
    fn every_multiplier_axis_has_its_exact_shape_and_narrow_class() {
        for (site, limit) in [32, 32, 64, 256, 64, 16, 64].into_iter().enumerate() {
            let mut valid = multipliers();
            rows(&mut valid)[site][0] = limit;
            data(valid).unwrap();
            for value in [0, limit + 1] {
                let mut bad = multipliers();
                rows(&mut bad)[site][0] = value;
                assert!(data(bad).is_err(), "site {site}, value {value}");
            }
            let mut bad = multipliers();
            rows(&mut bad)[site].pop();
            assert!(data(bad).is_err(), "site {site} shape");
        }
    }

    #[test]
    fn each_public_change_moves_the_binding() {
        let a = data(multipliers()).unwrap();
        for site in 0..7 {
            let mut changed = multipliers();
            rows(&mut changed)[site][0] = 2;
            assert_ne!(a.encode(), data(changed).unwrap().encode(), "site {site}");
        }
        let mut changed = a.clone();
        changed.group_ids.swap(0, 1);
        changed.check_for(GEO, BASE, Stack::LowH24).unwrap();
        assert_ne!(a.encode(), changed.encode());
    }

    #[test]
    fn a_tampered_table_or_derived_cache_is_refused_on_recheck() {
        let a = data(multipliers()).unwrap();
        let mut changed = a.clone();
        changed.tables[0][3000] ^= 1;
        assert!(changed.check_for(GEO, BASE, Stack::LowH24).is_err());
        let mut changed = a.clone();
        changed.folds.gate.multipliers[0] += 1;
        assert!(changed.check_for(GEO, BASE, Stack::LowH24).is_err());
        let mut changed = a;
        changed.precision.f_p = 9;
        assert!(changed.check_for(GEO, BASE, Stack::LowH24).is_err());
    }
}
