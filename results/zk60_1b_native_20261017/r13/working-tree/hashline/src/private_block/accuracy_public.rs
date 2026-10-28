//! Typed and bound public R13 data, not yet imported
//! into the prover.
use super::accuracy_aligned::derive_aligned;
use super::accuracy_groups::{Group, GroupFolds};
use super::accuracy_precision::{BaseShifts, Precision, Stack};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Geometry {
    pub width: usize,
    pub query_width: usize,
    pub kv_width: usize,
    pub hidden: usize,
}

impl Geometry {
    pub(crate) fn check_bounds(self) -> Result<(), String> {
        if self.width == 0
            || self.width > 4096
            || self.query_width == 0
            || self.query_width > 4096
            || self.kv_width == 0
            || self.kv_width > 4096
            || self.hidden == 0
            || self.hidden > 16384
        {
            return Err("R13 public data: geometry is outside the no-wrap class".into());
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Multipliers {
    pub q: Vec<u16>,
    pub k: Vec<u16>,
    pub v: Vec<u16>,
    pub o: Vec<u16>,
    pub g: Vec<u16>,
    pub u: Vec<u16>,
    pub d: Vec<u16>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct AccuracyPublic {
    stack: Stack,
    geometry: Geometry,
    base: BaseShifts,
    member: (i32, i32),
    multipliers: Multipliers,
    groups: Vec<Group>,
    group_ids: Vec<usize>,
    tables: Vec<Vec<i16>>,
    precision: Precision,
    folds: GroupFolds,
    scaled_tables: Vec<Vec<i64>>,
}

impl AccuracyPublic {
    pub(crate) fn new(
        stack: Stack,
        geometry: Geometry,
        base: BaseShifts,
        member: (i32, i32),
        multipliers: Multipliers,
        groups: Vec<Group>,
        group_ids: Vec<usize>,
        tables: Vec<Vec<i16>>,
    ) -> Result<Self, String> {
        use super::accuracy_precision::derive;
        use super::accuracy_tables::silu_table;
        geometry.check_bounds()?;
        if stack == Stack::Legacy {
            return Err("R13 public data: an explicit LOW export stack is required".into());
        }
        let precision = derive(stack, base)?;
        let arrays: [&[u16]; 7] = [
            &multipliers.q,
            &multipliers.k,
            &multipliers.v,
            &multipliers.o,
            &multipliers.g,
            &multipliers.u,
            &multipliers.d,
        ];
        let lengths = [
            geometry.query_width,
            geometry.kv_width,
            geometry.kv_width,
            geometry.width,
            geometry.hidden,
            geometry.hidden,
            geometry.width,
        ];
        for ((words, length), bits) in arrays
            .into_iter()
            .zip(lengths)
            .zip(precision.multiplier_bits)
        {
            if words.len() != length || words.iter().any(|&m| m == 0 || m as u64 > 1u64 << bits) {
                return Err("R13 public data: multiplier shape or narrow range mismatch".into());
            }
        }
        if group_ids.len() != geometry.hidden || tables.len() != groups.len() {
            return Err("R13 public data: group/table shape mismatch".into());
        }
        let gate: Vec<u64> = multipliers.g.iter().map(|&v| v as u64).collect();
        let aligned = derive_aligned(
            stack,
            &groups,
            &group_ids,
            &gate,
            member.0,
            member.1,
            base.gate,
            base.product,
        )?;
        for (group, table) in groups.iter().zip(&tables) {
            if *table != silu_table(group.e_in, group.e_out, 12)? {
                return Err(
                    "R13 public data: SiLU table is not the declared generated member".into(),
                );
            }
        }
        Ok(Self {
            stack,
            geometry,
            base,
            member,
            multipliers,
            groups,
            group_ids,
            tables,
            precision,
            folds: aligned.folds,
            scaled_tables: aligned.tables,
        })
    }
    pub(crate) fn encode(&self) -> Vec<u8> {
        let mut out = b"zk60-low-public/v1\0".to_vec();
        let stack = self
            .stack
            .export_name()
            .expect("constructor refuses a legacy stack");
        out.extend_from_slice(&(stack.len() as u32).to_le_bytes());
        out.extend_from_slice(stack.as_bytes());
        for value in [
            self.geometry.width,
            self.geometry.query_width,
            self.geometry.kv_width,
            self.geometry.hidden,
        ] {
            out.extend_from_slice(&(value as u64).to_le_bytes());
        }
        for value in [
            self.base.norm_tn,
            self.base.qkv,
            self.base.score,
            self.base.pv,
            self.base.ao,
            self.base.gate,
            self.base.up,
            self.base.product,
            self.base.down,
        ] {
            out.extend_from_slice(&value.to_le_bytes());
        }
        out.extend_from_slice(&self.member.0.to_le_bytes());
        out.extend_from_slice(&self.member.1.to_le_bytes());
        for words in [
            &self.multipliers.q,
            &self.multipliers.k,
            &self.multipliers.v,
            &self.multipliers.o,
            &self.multipliers.g,
            &self.multipliers.u,
            &self.multipliers.d,
        ] {
            out.extend_from_slice(&(words.len() as u64).to_le_bytes());
            for value in words {
                out.extend_from_slice(&value.to_le_bytes());
            }
        }
        out.extend_from_slice(&(self.groups.len() as u64).to_le_bytes());
        for group in &self.groups {
            out.extend_from_slice(&group.e_in.to_le_bytes());
            out.extend_from_slice(&group.e_out.to_le_bytes());
        }
        out.extend_from_slice(&(self.group_ids.len() as u64).to_le_bytes());
        for &id in &self.group_ids {
            out.extend_from_slice(&(id as u64).to_le_bytes());
        }
        for table in &self.tables {
            out.extend_from_slice(&(table.len() as u64).to_le_bytes());
            for value in table {
                out.extend_from_slice(&value.to_le_bytes());
            }
        }
        out
    }
    pub(crate) fn check_for(
        &self,
        geometry: Geometry,
        base: BaseShifts,
        stack: Stack,
    ) -> Result<(), String> {
        if stack == Stack::Legacy
            || stack != self.stack
            || geometry != self.geometry
            || base != self.base
        {
            return Err(
                "R13 public data: profile, geometry or calibration context mismatch".into(),
            );
        }
        let recomputed = Self::new(
            stack,
            geometry,
            base,
            self.member,
            self.multipliers.clone(),
            self.groups.clone(),
            self.group_ids.clone(),
            self.tables.clone(),
        )?;
        if self.precision != recomputed.precision
            || self.folds != recomputed.folds
            || self.scaled_tables != recomputed.scaled_tables
        {
            return Err("R13 public data: derived precision or coefficient cache mismatch".into());
        }
        Ok(())
    }
    pub(crate) fn stack(&self) -> Stack {
        self.stack
    }
    pub(crate) fn geometry(&self) -> Geometry {
        self.geometry
    }
    pub(crate) fn base(&self) -> BaseShifts {
        self.base
    }
    pub(crate) fn precision(&self) -> &Precision {
        &self.precision
    }
    pub(crate) fn multipliers(&self) -> &Multipliers {
        &self.multipliers
    }
    pub(crate) fn folds(&self) -> &GroupFolds {
        &self.folds
    }
    pub(crate) fn groups(&self) -> &[Group] {
        &self.groups
    }
    pub(crate) fn group_ids(&self) -> &[usize] {
        &self.group_ids
    }
    pub(crate) fn scaled_tables(&self) -> &[Vec<i64>] {
        &self.scaled_tables
    }
}

#[cfg(test)]
mod tests {
    use super::super::accuracy_tables::silu_table;
    use super::*;
    const GEO: Geometry = Geometry {
        width: 4,
        query_width: 8,
        kv_width: 4,
        hidden: 6,
    };
    const BASE: BaseShifts = BaseShifts {
        norm_tn: 10,
        qkv: 8,
        score: 6,
        pv: 9,
        ao: 7,
        gate: 8,
        up: 0,
        product: 14,
        down: 6,
    };

    fn multipliers() -> Multipliers {
        Multipliers {
            q: vec![1; 8],
            k: vec![1; 4],
            v: vec![1; 4],
            o: vec![1; 4],
            g: vec![1; 6],
            u: vec![1; 6],
            d: vec![1; 4],
        }
    }
    fn rows(m: &mut Multipliers) -> [&mut Vec<u16>; 7] {
        [
            &mut m.q, &mut m.k, &mut m.v, &mut m.o, &mut m.g, &mut m.u, &mut m.d,
        ]
    }
    fn data(m: Multipliers) -> Result<AccuracyPublic, String> {
        let groups = vec![
            Group {
                e_in: -4,
                e_out: -13,
            },
            Group {
                e_in: -1,
                e_out: -11,
            },
        ];
        let tables = groups
            .iter()
            .map(|g| silu_table(g.e_in, g.e_out, 12).unwrap())
            .collect();
        AccuracyPublic::new(
            Stack::LowH24,
            GEO,
            BASE,
            (-3, -11),
            m,
            groups,
            vec![0, 1, 0, 1, 0, 1],
            tables,
        )
    }

    #[test]
    fn honest_data_has_a_canonical_binding_and_exact_context() {
        let a = data(multipliers()).unwrap();
        assert_eq!(a.encode(), data(multipliers()).unwrap().encode());
        assert!(a.encode().len() > 8192);
        a.check_for(GEO, BASE, Stack::LowH24).unwrap();
        assert!(a.check_for(GEO, BASE, Stack::Legacy).is_err());
        assert!(a
            .check_for(
                Geometry {
                    query_width: 4,
                    ..GEO
                },
                BASE,
                Stack::LowH24
            )
            .is_err());
        assert!(a
            .check_for(GEO, BaseShifts { score: 7, ..BASE }, Stack::LowH24)
            .is_err());
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
        let mut ids = a.group_ids.clone();
        ids.swap(0, 1);
        let changed = AccuracyPublic::new(
            Stack::LowH24,
            GEO,
            BASE,
            a.member,
            a.multipliers.clone(),
            a.groups.clone(),
            ids,
            a.tables.clone(),
        )
        .unwrap();
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
        let mut changed = a.clone();
        changed.scaled_tables[0][3000] ^= 1;
        assert!(changed.check_for(GEO, BASE, Stack::LowH24).is_err());
        let mut changed = a;
        changed.precision.f_p = 9;
        assert!(changed.check_for(GEO, BASE, Stack::LowH24).is_err());
    }

    #[test]
    fn the_export_stack_changes_the_binding_and_is_rechecked() {
        let h24 = data(multipliers()).unwrap();
        let low = AccuracyPublic::new(
            Stack::Low,
            GEO,
            BASE,
            h24.member,
            h24.multipliers.clone(),
            h24.groups.clone(),
            h24.group_ids.clone(),
            h24.tables.clone(),
        )
        .unwrap();
        low.check_for(GEO, BASE, Stack::Low).unwrap();
        assert!(low.check_for(GEO, BASE, Stack::LowH24).is_err());
        assert!(h24.check_for(GEO, BASE, Stack::Low).is_err());
        assert_ne!(h24.encode(), low.encode());
        assert_eq!(low.scaled_tables, h24.scaled_tables);
        assert_eq!((low.folds.product.shift, h24.folds.product.shift), (24, 16));
        assert!(AccuracyPublic::new(
            Stack::Legacy,
            GEO,
            BASE,
            h24.member,
            h24.multipliers,
            h24.groups,
            h24.group_ids,
            h24.tables
        )
        .is_err());
    }
}
