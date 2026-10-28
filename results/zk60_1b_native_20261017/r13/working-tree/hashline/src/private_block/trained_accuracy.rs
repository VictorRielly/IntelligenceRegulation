//! Bounded R13 public-array reader. The v2 export/proof entry point is not
//! activated yet; legacy exports do not call this reader.
use super::*;
use crate::private_block::accuracy_groups::Group;
use crate::private_block::accuracy_precision::{BaseShifts, Stack};
use crate::private_block::accuracy_public::{
    AccuracyPublic, Geometry as AccuracyGeometry, Multipliers,
};

pub(super) struct Loaded {
    pub accuracy: AccuracyPublic,
    pub sha256: Vec<(&'static str, [u8; 32])>,
}

pub(super) fn load(
    dir: &Path,
    arrays: &J,
    stack: Stack,
    geometry: AccuracyGeometry,
    base: BaseShifts,
    member: (i32, i32),
) -> Result<Loaded, String> {
    geometry.check_bounds()?;
    if stack == Stack::Legacy {
        return Err("R13 arrays require an explicit LOW export stack".into());
    }
    for name in ["scaled_act", "derived_act", "folded_m_g", "folded_m_d"] {
        if arrays.opt(name).is_some() {
            return Err(format!(
                "R13 array `{name}` is derived by the verifier, not supplied in the export"
            ));
        }
    }
    let mut hashes = Vec::new();
    let mut narrow = |name: &'static str, length: usize| -> Result<Vec<u16>, String> {
        let a = load_array(dir, name, arrays.get(name)?, &[(Dtype::I64, &[length])])?;
        hashes.push((name, a.sha256));
        a.i64s()
            .into_iter()
            .map(|v| {
                u16::try_from(v)
                    .map_err(|_| format!("R13 array `{name}` contains a non-narrow multiplier"))
            })
            .collect()
    };
    let multipliers = Multipliers {
        q: narrow("m_q", geometry.query_width)?,
        k: narrow("m_k", geometry.kv_width)?,
        v: narrow("m_v", geometry.kv_width)?,
        o: narrow("m_o", geometry.width)?,
        g: narrow("m_g", geometry.hidden)?,
        u: narrow("m_u", geometry.hidden)?,
        d: narrow("m_d", geometry.width)?,
    };
    let ids = load_array(
        dir,
        "silu_group_ids",
        arrays.get("silu_group_ids")?,
        &[(Dtype::I64, &[geometry.hidden])],
    )?;
    hashes.push(("silu_group_ids", ids.sha256));
    let ids = ids
        .i64s()
        .into_iter()
        .map(|id| usize::try_from(id).map_err(|_| "R13 group ID is negative".to_string()))
        .collect::<Result<Vec<_>, _>>()?;
    let groups = load_array(
        dir,
        "silu_groups",
        arrays.get("silu_groups")?,
        &[
            (Dtype::I64, &[1, 2]),
            (Dtype::I64, &[2, 2]),
            (Dtype::I64, &[3, 2]),
            (Dtype::I64, &[4, 2]),
        ],
    )?;
    hashes.push(("silu_groups", groups.sha256));
    let ngroups = groups.shape[0];
    let groups = groups
        .i64s()
        .chunks_exact(2)
        .map(|pair| {
            Ok(Group {
                e_in: i32::try_from(pair[0]).map_err(|_| "R13 e_in exceeds int32")?,
                e_out: i32::try_from(pair[1]).map_err(|_| "R13 e_out exceeds int32")?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let table = load_array(
        dir,
        "act",
        arrays.get("act")?,
        &[(Dtype::I16, &[ngroups, 4096])],
    )?;
    hashes.push(("act", table.sha256));
    let tables = table
        .i16s()
        .chunks_exact(4096)
        .map(|words| words.to_vec())
        .collect();
    let accuracy = AccuracyPublic::new(
        stack,
        geometry,
        base,
        member,
        multipliers,
        groups,
        ids,
        tables,
    )?;
    Ok(Loaded {
        accuracy,
        sha256: hashes,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    const GEO: AccuracyGeometry = AccuracyGeometry {
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

    struct Fixture {
        dir: PathBuf,
        arrays: J,
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }
    impl Fixture {
        fn new() -> Self {
            let dir = std::env::temp_dir().join(format!(
                "zk60-r13-arrays-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            std::fs::create_dir(&dir).unwrap();
            let mut fixture = Self {
                dir,
                arrays: J::Obj(vec![]),
            };
            for (name, n) in [
                ("m_q", 8),
                ("m_k", 4),
                ("m_v", 4),
                ("m_o", 4),
                ("m_g", 6),
                ("m_u", 6),
                ("m_d", 4),
            ] {
                fixture.put(
                    name,
                    "int64",
                    &[n],
                    &vec![1i64; n]
                        .iter()
                        .flat_map(|v| v.to_le_bytes())
                        .collect::<Vec<_>>(),
                );
            }
            fixture.put(
                "silu_group_ids",
                "int64",
                &[6],
                &vec![0i64; 6]
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            fixture.put(
                "silu_groups",
                "int64",
                &[1, 2],
                &[-3i64, -11]
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            let table = crate::private_block::accuracy_tables::silu_table(-3, -11, 12).unwrap();
            fixture.put(
                "act",
                "int16",
                &[1, 4096],
                &table
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            fixture
        }
        fn put(&mut self, name: &str, dtype: &str, shape: &[usize], bytes: &[u8]) {
            let file = format!("{name}.bin");
            std::fs::write(self.dir.join(&file), bytes).unwrap();
            let spec = J::Obj(vec![
                ("file".into(), J::Str(file)),
                ("dtype".into(), J::Str(dtype.into())),
                (
                    "shape".into(),
                    J::Arr(shape.iter().map(|v| J::Num(v.to_string())).collect()),
                ),
                ("sha256".into(), J::Str(hex(&sha256(bytes)))),
            ]);
            let J::Obj(entries) = &mut self.arrays else {
                unreachable!()
            };
            entries.retain(|(key, _)| key != name);
            entries.push((name.into(), spec));
        }
        fn load(&self, stack: Stack) -> Result<Loaded, String> {
            load(&self.dir, &self.arrays, stack, GEO, BASE, (-3, -11))
        }
    }

    #[test]
    fn both_export_stacks_load_verified_arrays_and_recompute_their_tables() {
        let f = Fixture::new();
        let low = f.load(Stack::Low).unwrap();
        let h24 = f.load(Stack::LowH24).unwrap();
        assert_eq!(low.sha256, h24.sha256);
        assert_eq!(low.sha256.len(), 10);
        low.accuracy.check_for(GEO, BASE, Stack::Low).unwrap();
        h24.accuracy.check_for(GEO, BASE, Stack::LowH24).unwrap();
        assert_ne!(low.accuracy.encode(), h24.accuracy.encode());
        assert_eq!(low.accuracy.scaled_tables(), h24.accuracy.scaled_tables());
        assert!(f.load(Stack::Legacy).is_err());
    }

    #[test]
    fn changed_payloads_fail_hash_checks_and_narrow_ranges_fail_after_rehash() {
        let mut f = Fixture::new();
        std::fs::write(f.dir.join("m_q.bin"), [0u8; 64]).unwrap();
        assert!(f
            .load(Stack::Low)
            .err()
            .unwrap()
            .contains("SHA-256 mismatch"));
        for word in [-1i64, 0, 33, 65536] {
            let mut values = vec![1i64; 8];
            values[0] = word;
            f.put(
                "m_q",
                "int64",
                &[8],
                &values
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            assert!(f.load(Stack::Low).is_err(), "{word}");
        }
    }

    #[test]
    fn bad_table_shape_is_refused_before_the_missing_payload_is_read() {
        let mut f = Fixture::new();
        f.put("act", "int16", &[4, usize::MAX], &[]);
        std::fs::remove_file(f.dir.join("act.bin")).unwrap();
        let error = f.load(Stack::Low).err().unwrap();
        assert!(error.contains("refused before it is read"), "{error}");
    }

    #[test]
    fn rehashed_fake_tables_and_supplied_derived_arrays_are_refused() {
        let mut f = Fixture::new();
        f.put("act", "int16", &[1, 4096], &[0; 8192]);
        assert!(f
            .load(Stack::Low)
            .err()
            .unwrap()
            .contains("generated member"));
        let mut f = Fixture::new();
        f.put("scaled_act", "int64", &[1], &[0; 8]);
        assert!(f
            .load(Stack::Low)
            .err()
            .unwrap()
            .contains("derived by the verifier"));
    }
}
