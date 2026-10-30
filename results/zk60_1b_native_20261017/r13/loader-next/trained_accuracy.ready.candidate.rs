//! Bounded R13 public-array reader. The v2 export/proof entry point is not
//! activated yet; legacy exports do not call this reader.
use super::*;
use crate::private_block::accuracy_groups::Group;
use crate::private_block::accuracy_precision::{BaseShifts, Stack};
use crate::private_block::accuracy_tables::Registry;
use crate::private_block::accuracy_public::{
    AccuracyPublic, Geometry as AccuracyGeometry, Multipliers,
};

/// The export chooses one approved arithmetic stack for its model.
/// The decoupled-head rung is synthetic and supports both development stacks.
pub(super) fn profile_for(geometry:super::Geometry,stack:Stack,dd:bool)->Result<&'static str,String> {
    use crate::private_block::shape::*;
    use super::Geometry as G;
    let p=match (geometry,stack,dd) {
        (G::TinyLlama(128),Stack::Low,false)=>R13_TINY_T128_LOW,
        (G::TinyLlama(128),Stack::Low,true)=>R13_TINY_T128_LOW_DD,
        (G::Llama3_8B(128),Stack::LowH24,false)=>R13_8B_T128_H24,
        (G::Llama3_8B(128),Stack::LowH24,true)=>R13_8B_T128_H24_DD,
        (G::Shieldstral(128),Stack::LowH24,false)=>R13_SHIELD_T128_H24,
        (G::Shieldstral(128),Stack::LowH24,true)=>R13_SHIELD_T128_H24_DD,
        (G::Shieldstral(256),Stack::LowH24,false)=>R13_SHIELD_T256_H24,
        (G::Shieldstral(256),Stack::LowH24,true)=>R13_SHIELD_T256_H24_DD,
        (G::RungHdDev,Stack::Low,false)=>R13_RUNG_LOW,
        (G::RungHdDev,Stack::LowH24,false)=>R13_RUNG_H24,
        (G::RungHdDev,Stack::Low,true)=>R13_RUNG_LOW_DD,
        (G::RungHdDev,Stack::LowH24,true)=>R13_RUNG_H24_DD,
        _=>return Err("R13 export: this model/context/stack has no registered arithmetic profile".into()),
    };
    Ok(p)
}

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
    load_for_registry(Registry::Standard, dir, arrays, stack, geometry, base, member)
}

pub(super) fn load_for_registry(
    registry: Registry,
    dir: &Path,
    arrays: &J,
    stack: Stack,
    geometry: AccuracyGeometry,
    base: BaseShifts,
    member: (i32, i32),
) -> Result<Loaded, String> {
    geometry.check_registry(registry)?;
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
    let accuracy = AccuracyPublic::new_with_registry(
        registry,
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
            // Retain public refusal fixtures under the lane results directory.
        }
    }
    impl Fixture {
        fn new() -> Self {
            let root=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../results/r13-array-tests");
            std::fs::create_dir_all(&root).unwrap();
            let dir = root.join(format!(
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
        for (shape, reason) in [([4,4097], "refused before it is read"),
                                ([4,usize::MAX], "expected an integer")] {
            let mut f = Fixture::new();
            f.put("act", "int16", &shape, &[]);
            std::fs::remove_file(f.dir.join("act.bin")).unwrap();
            let error = f.load(Stack::Low).err().unwrap();
            assert!(error.contains("array `act`") && error.contains(reason), "{error}");
        }
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

    #[test]
    fn shieldstral_four_group_arrays_are_verified_and_cannot_enter_the_standard_registry() {
        let mut f = Fixture::new();
        let geo = AccuracyGeometry { width: 3072, query_width: 4096, kv_width: 1024, hidden: 9216 };
        for (name, n) in [("m_q",4096),("m_k",1024),("m_v",1024),("m_o",3072),
            ("m_g",9216),("m_u",9216),("m_d",3072)] {
            let bytes: Vec<u8> = (0..n).flat_map(|_| 1i64.to_le_bytes()).collect();
            f.put(name,"int64",&[n],&bytes);
        }
        let ids: Vec<u8> = (0..9216).flat_map(|i| ((i%4) as i64).to_le_bytes()).collect();
        f.put("silu_group_ids","int64",&[9216],&ids);
        let groups = [(-3,-11),(-2,-11),(-1,-9),(0,-8)];
        let bytes: Vec<u8> = groups.iter().flat_map(|&(i,o)| [i as i64,o as i64]).flat_map(i64::to_le_bytes).collect();
        f.put("silu_groups","int64",&[4,2],&bytes);
        let tables: Vec<u8> = groups.iter().flat_map(|&(i,o)|
            crate::private_block::accuracy_tables::silu_table_for(Registry::Shieldstral,i,o,12).unwrap())
            .flat_map(i16::to_le_bytes).collect();
        f.put("act","int16",&[4,4096],&tables);
        let base = BaseShifts { product: 15, ..BASE };
        for stack in [Stack::Low,Stack::LowH24] {
            let loaded = load_for_registry(Registry::Shieldstral,&f.dir,&f.arrays,stack,geo,base,(-1,-9)).unwrap();
            assert_eq!(loaded.sha256.len(),10);
            assert_eq!(loaded.accuracy.registry(),Registry::Shieldstral);
            loaded.accuracy.check_for_registry(Registry::Shieldstral,geo,base,stack).unwrap();
            assert!(load(&f.dir,&f.arrays,stack,geo,base,(-1,-9)).is_err());
        }
        let mut forged = tables;
        forged[3*8192+6000] ^= 1;
        f.put("act","int16",&[4,4096],&forged);
        assert!(load_for_registry(Registry::Shieldstral,&f.dir,&f.arrays,Stack::LowH24,geo,base,(-1,-9))
            .err().unwrap().contains("generated member"));
    }

    #[test]
    fn the_shieldstral_geometry_gate_runs_before_any_array_file_is_opened() {
        let error = load_for_registry(Registry::Shieldstral,Path::new("/does-not-exist"),
            &J::Obj(vec![]),Stack::LowH24,GEO,BASE,(-1,-9)).err().unwrap();
        assert!(error.contains("pinned geometry"),"{error}");
    }

    #[test]
    #[ignore = "requires the authenticated 26-layer public-array adapter via HL_R13_SHIELDSTRAL_ARRAYS"]
    fn all_26_actual_shieldstral_layers_pass_the_native_public_array_loader() {
        let root=PathBuf::from(std::env::var("HL_R13_SHIELDSTRAL_ARRAYS").expect("explicit intake directory required"));
        let manifest=parse_json(&std::fs::read(root.join("manifest.json")).unwrap()).unwrap();
        let layers=manifest.get("layers").unwrap().arr().unwrap();
        assert_eq!(layers.len(),26);
        let geo=AccuracyGeometry{width:3072,query_width:4096,kv_width:1024,hidden:9216};
        for (i,row) in layers.iter().enumerate() {
            assert_eq!(row.get("index").unwrap().i64().unwrap(),i as i64);
            let c=row.get("constants").unwrap();
            let shift=|key|u32::try_from(c.get(key).unwrap().i64().unwrap()).unwrap();
            let base=BaseShifts{norm_tn:shift("norm_tn"),qkv:shift("sh_qkv"),score:shift("sh_s"),
                pv:shift("sh_o"),ao:shift("sh_ao"),gate:shift("sh_g"),up:shift("sh_u"),
                product:shift("sh_h"),down:shift("sh_z")};
            let member=c.get("silu").unwrap().arr().unwrap();
            let member=(i32::try_from(member[0].i64().unwrap()).unwrap(),i32::try_from(member[1].i64().unwrap()).unwrap());
            let dir=root.join(row.get("directory").unwrap().str().unwrap());
            let loaded=load_for_registry(Registry::Shieldstral,&dir,row.get("arrays").unwrap(),Stack::LowH24,geo,base,member)
                .unwrap_or_else(|e|panic!("layer {i}: {e}"));
            let a=loaded.accuracy;
            a.check_for_registry(Registry::Shieldstral,geo,base,Stack::LowH24).unwrap();
            assert_eq!(loaded.sha256.len(),10);
            assert!(a.groups().len()<=4);
            let expected=|key|row.get(key).unwrap().i64().unwrap();
            assert_eq!(a.folds().gate.shift as i64,expected("gate_common_shift"),"layer {i}");
            assert_eq!(*a.folds().gate.multipliers.iter().max().unwrap() as i64,expected("folded_gate_multiplier_max"),"layer {i}");
            assert_eq!(a.folds().product.shift as i64,expected("aligned_product_shift"),"layer {i}");
            assert_eq!(a.scaled_tables().iter().flatten().map(|v|v.abs()).max().unwrap(),expected("derived_table_max_abs"),"layer {i}");
            if i==25 {assert!(a.groups().iter().any(|g|(g.e_in,g.e_out)==(0,-8)));}
        }
    }
}

#[cfg(test)]
mod profile_tests {
    use super::*;

    fn fixture(name:&str)->PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures").join(name)
    }

    #[test]
    fn accuracy_v2_loader_imports_both_stacks_and_reconstructs_dd_records() {
        for (name,stack,ng) in [("r13-low-1g",Stack::Low,1),("r13-h24-4g",Stack::LowH24,4)] {
            for dd in [false,true] {
                let mut ex=TrainedExport::load(&fixture(name)).unwrap();
                assert_eq!(ex.accuracy_stack,stack);
                if dd {ex.enable_dd().unwrap();}
                let c=ex.run_constants(&[0]).unwrap();let seed=ex.shape_for(&c).unwrap();
                assert_eq!(seed.accuracy_stack(),stack);assert_eq!(seed.dd_cap>0,dd);
                let layer=ex.load_layer(&seed,&c,0,false).unwrap();let data=layer.blk.accuracy().unwrap();
                assert_eq!(data.groups().len(),ng);
                assert_eq!(layer.record.accuracy_gate_shift,Some(data.folds().gate.shift));
                let stage=seed.clone().with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
                layer.blk.check_accuracy_for_shape(&stage).unwrap();
                let statement=ex.statement(&seed,&c,&[&layer]).unwrap();
                assert_eq!(statement.run_profile,ex.run_profile());
                assert_eq!(statement.layers[0].accuracy_gate_shift,layer.record.accuracy_gate_shift);
                assert!(layer.blk.check_for_shape(&stage).unwrap_err().contains("R13 proof profiles remain disabled"));
            }
        }
    }

    #[test]
    fn accuracy_v2_model_stack_selection_has_no_global_fallback() {
        use crate::private_block::shape::*;
        use crate::private_block::trained_block::Geometry as G;
        let expected=[
            (G::TinyLlama(128),Stack::Low,false,R13_TINY_T128_LOW),
            (G::TinyLlama(128),Stack::Low,true,R13_TINY_T128_LOW_DD),
            (G::Llama3_8B(128),Stack::LowH24,false,R13_8B_T128_H24),
            (G::Llama3_8B(128),Stack::LowH24,true,R13_8B_T128_H24_DD),
            (G::Shieldstral(128),Stack::LowH24,false,R13_SHIELD_T128_H24),
            (G::Shieldstral(128),Stack::LowH24,true,R13_SHIELD_T128_H24_DD),
            (G::Shieldstral(256),Stack::LowH24,false,R13_SHIELD_T256_H24),
            (G::Shieldstral(256),Stack::LowH24,true,R13_SHIELD_T256_H24_DD),
            (G::RungHdDev,Stack::Low,false,R13_RUNG_LOW),
            (G::RungHdDev,Stack::Low,true,R13_RUNG_LOW_DD),
            (G::RungHdDev,Stack::LowH24,false,R13_RUNG_H24),
            (G::RungHdDev,Stack::LowH24,true,R13_RUNG_H24_DD),
        ];
        for (geometry,stack,dd,profile) in expected {assert_eq!(profile_for(geometry,stack,dd).unwrap(),profile);}
        for (geometry,stack) in [(G::TinyLlama(128),Stack::LowH24),(G::Llama3_8B(128),Stack::Low),
            (G::Shieldstral(128),Stack::Low),(G::TinyLlama(32),Stack::Low),(G::Llama3_8B(64),Stack::LowH24),
            (G::RungTcDev,Stack::Low),(G::RungHdDev,Stack::Legacy)] {
            for dd in [false,true] {assert!(profile_for(geometry,stack,dd).is_err());}
        }
    }

    #[test]
    fn accuracy_v2_schema_stack_and_fp12_are_checked_before_layer_payloads() {
        let original=std::fs::read_to_string(fixture("r13-low-1g").join("profile.json")).unwrap();
        let cases=[
            (original.replace("zk60-trained-profile-export/2","zk60-trained-profile-export/1"),"legacy export"),
            (original.replace("  \"accuracy_stack\": \"low-v1\",\n",""),"accuracy_stack"),
            (original.replace("\"accuracy_stack\": \"low-v1\"","\"accuracy_stack\": \"unknown\""),"accuracy_stack"),
            (original.replace("\"f_p\": 12","\"f_p\": 9"),"f_p"),
        ];
        for (i,(text,needle)) in cases.into_iter().enumerate() {
            assert_ne!(text,original);
            let dir=crate::private_block::trained_block_tests::base_dir(&format!("r13-schema-{i}"));
            std::fs::write(dir.join("profile.json"),text).unwrap();
            let error=match TrainedExport::load(&dir) {Err(e)=>e,Ok(_)=>panic!("malformed schema/stack was accepted")};
            assert!(error.contains(needle),"unexpected refusal: {error}");
        }
    }
}
