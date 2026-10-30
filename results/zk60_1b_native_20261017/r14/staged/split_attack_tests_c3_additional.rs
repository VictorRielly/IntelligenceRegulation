//! Test-only malicious provers. Each case must emit a complete canonical R14
//! frame before the native verifier refuses it. No production dispatch changes.
use super::split_run_tests::{fixture, pieces, verify};
use super::*;
use crate::ntt::NttTables;
use crate::private_block::{
    accuracy,
    accuracy_fold::{self, Site},
    accuracy_groups::Group,
    accuracy_layout::Limbs,
    accuracy_public::AccuracyPublic,
    accuracy_tables, protocol, split_endpoint,
    split_layout::Part,
    split_profile::SplitProfile,
    split_run, trained_statement, wire,
    witness::{self, Witness},
    BlockPublic,
};
use std::cell::Cell;

thread_local! { static DEFINITION_FAULT: Cell<u8> = const { Cell::new(0) }; }
struct FaultScope;
impl FaultScope {
    fn new(mode: u8) -> Self {
        DEFINITION_FAULT.with(|v| {
            assert_eq!(v.get(), 0);
            v.set(mode);
        });
        Self
    }
}
impl Drop for FaultScope {
    fn drop(&mut self) {
        DEFINITION_FAULT.with(|v| v.set(0));
    }
}

/// Called only for Side::Prove and only in cfg(test). The verifier always
/// constructs the reviewed native definition. Masks/PCS/transcript stay live.
pub(crate) fn apply_prover_definition_fault(p: &SplitProfile, def: &mut SlotDef) {
    let mode = DEFINITION_FAULT.with(Cell::get);
    let slot = &p.layout().slots[def.slot];
    match mode {
        1 if slot.base == SC_SS => {
            def.poly = Box::new(|v| v[0].mul(v[1].mul(v[1])));
        }
        2 if slot.base == SC_QMM => {
            let source = def
                .tabs
                .iter_mut()
                .filter_map(|t| match t {
                    Tab::Priv(p) => Some(p),
                    _ => None,
                })
                .nth(1)
                .unwrap();
            let first = source
                .coords
                .iter_mut()
                .find(|c| matches!(c, Coord::Rho(_)))
                .unwrap();
            assert!(matches!(first, Coord::Rho(1)));
            *first = Coord::Rho(0); // lost omitted leading feature bit
        }
        3 if slot.base == SC_QMM => {
            let Tab::Pub(fold) = &mut def.tabs[3] else {
                panic!("native narrow weight factor absent")
            };
            let n = fold.len() / 2;
            assert!(fold[n..].iter().all(|v| v.is_zero()));
            let first = fold[..n].to_vec();
            fold[n..].copy_from_slice(&first); // forgot the public zero lift
        }
        4 if slot.base == SC_QMM => {
            let source = def.tabs.iter_mut().find_map(|t| match t {
                Tab::Priv(p) => Some(p), _ => None,
            }).unwrap();
            let last = slot.main - 1;
            let mut changed = 0;
            for coord in &mut source.coords {
                if let Coord::Rho(bit) = coord {
                    if *bit == 0 { *bit = last; changed += 1; }
                    else if *bit == last { *bit = 0; changed += 1; }
                }
            }
            assert_eq!(changed, 2, "wide feature axes were not swapped");
        }
        5 if slot.base == SC_QMM => {
            let n = match &def.tabs[3] {
                Tab::Pub(fold) => fold.len() / 2,
                _ => panic!("native narrow weight factor absent"),
            };
            let wrong = match &def.tabs[1] {
                Tab::Pub(wide) => wide[..n].to_vec(),
                _ => panic!("native wide weight factor absent"),
            };
            let Tab::Pub(narrow) = &mut def.tabs[3] else { unreachable!() };
            assert!(narrow[n..].iter().all(|v| v.is_zero()));
            assert!(narrow[..n] != wrong[..], "wrong global offset fixture is degenerate");
            // Keep the B-gate and use global start 0 instead of 2048.
            narrow[..n].copy_from_slice(&wrong);
        }
        _ => {}
    }
}

struct One(Option<Witness>);
impl split_run::WitnessSource for One {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("one attack stage only".into());
        }
        self.0.take().ok_or("attack witness consumed".into())
    }
    fn boundary_pieces(&mut self, _: usize) -> Result<[Vec<Fp>; 2], String> {
        Err("one-stage fixture has no internal boundary".into())
    }
}
fn write_limbs(w: &mut Witness, sh: &Shape, role: Limbs, index: usize, value: i64, bias: i64) {
    let ids = Ids::new(sh).unwrap();
    let low = ids.accuracy().unwrap();
    let n = low.count(role);
    let value = value.checked_add(bias).unwrap();
    assert!((0..1i64 << (8 * n)).contains(&value));
    for k in 0..n {
        w.planes[low.limb(role, k)][index] = (value >> (8 * k)) & 255;
    }
}
fn mutate_round_q(sh: &Shape, blk: &BlockPublic, w: &mut Witness) {
    let ids = Ids::new(sh).unwrap();
    let y = &w.planes[ids.at(A_Y)];
    let data = blk.accuracy().unwrap();
    let coeff = accuracy_fold::coefficients(sh, data, Site::Q).unwrap();
    let shift = data.precision().q;
    for (j, &m) in coeff.iter().enumerate().filter(|(_, m)| **m > 0) {
        let row = &blk.attention().wq[j * sh.d_pad..(j + 1) * sh.d_pad];
        let sums = [0..2048, 2048..sh.width]
            .map(|r| r.map(|i| y[i] as i128 * row[i] as i128).sum::<i128>());
        let full = accuracy::requant(sums[0] + sums[1], m, shift).unwrap();
        let parts = sums.map(|v| accuracy::requant(v, m, shift).unwrap().word);
        let bad = parts[0] + parts[1];
        assert_eq!(w.planes[ids.at(A_Q8)][j], full.word);
        if bad != full.word && (-32768..=32767).contains(&bad) {
            w.planes[ids.at(A_Q8)][j] = bad;
            write_limbs(w, sh, Limbs::Q, j, bad, 32768);
            eprintln!("R14_ATTACK_WITNESS per-piece-round-q global_output={j} partial_sums={sums:?} multiplier={m} shift={shift} correct={} wrong={bad}",full.word);
            return;
        }
    }
    panic!("fixture supplied no per-piece rounding counterexample");
}
fn mutate_c2_ao(sh: &Shape, blk: &BlockPublic, w: &mut Witness) {
    let ids = Ids::new(sh).unwrap();
    let data = blk.accuracy().unwrap();
    for t in 0..sh.tokens {
        for j in 2048..sh.width {
            let m = data.multipliers().o[j] as u64;
            let wrong_m = data.multipliers().o[j - 2048] as u64;
            if m == wrong_m {
                continue;
            }
            let acc = (0..sh.q_pad())
                .map(|i| {
                    w.planes[ids.at(A_O8)][t * sh.q_pad() + i] as i128
                        * blk.attention().wo[j * sh.q_pad() + i] as i128
                })
                .sum::<i128>();
            let correct = accuracy::requant(acc, m, data.precision().ao).unwrap();
            let bad = accuracy::requant(acc, wrong_m, data.precision().ao).unwrap();
            let i = t * sh.d_pad + j;
            assert_eq!(w.planes[ids.at(A_AO)][i], correct.word);
            if bad.word != correct.word && (-32768..=32767).contains(&bad.word) {
                w.planes[ids.at(A_AO)][i] = bad.word;
                write_limbs(w, sh, Limbs::Ao, i, bad.word, 32768);
                write_limbs(
                    w,
                    sh,
                    Limbs::Rao,
                    i,
                    i64::try_from(bad.remainder).unwrap(),
                    0,
                );
                eprintln!("R14_ATTACK_WITNESS local-c2-ao token={t} global_output={j} correct_c2={m} wrong_local_c2={wrong_m} correct={} wrong={}",correct.word,bad.word);
                return;
            }
        }
    }
    panic!("fixture supplied no global-c2 counterexample");
}
fn input(sh: &Shape) -> Vec<i16> {
    (0..sh.tokens * sh.width)
        .map(|i| if i % 2 == 0 { 1 } else { -1 })
        .collect()
}
fn ordinary_fixture(dd: bool) -> (Shape, BlockPublic) {
    let (sh, blocks, _) = fixture(dd);
    let b = &blocks[0];
    let a = b.accuracy().unwrap();
    let mut m = a.multipliers().clone();
    // Defeat accidental periodic aliases in the original synthetic c2 arrays.
    m.o[3071] = 1;
    m.o[1023] = 256;
    m.v[0] = 64;
    let mut attention = b.attention().clone();
    // The old sparse fixture rounded every selected V/O lane to zero, so
    // changing the AO multiplier could not change its rounded output. Create
    // one live KV value and use all its query-head copies at the narrow AO
    // output. Correct global c2=1 rounds0; wrong local c2=256 rounds1.
    attention.wv[..sh.d_pad].fill(0);
    attention.wv[0] = -127;
    let row = 3071 * sh.q_pad();
    attention.wo[row..row + sh.q_pad()].fill(0);
    for h in 0..sh.q_heads / sh.kv_heads {
        attention.wo[row + sh.head_slot(h) * sh.head_dim] = 127;
    }
    let data = AccuracyPublic::new_with_registry(
        a.registry(),
        a.stack(),
        a.geometry(),
        a.base(),
        a.member(),
        m,
        a.groups().to_vec(),
        a.group_ids().to_vec(),
        a.raw_tables().to_vec(),
    )
    .unwrap();
    (
        sh,
        BlockPublic::new(attention, b.feed_forward().clone()).with_accuracy(data),
    )
}
pub(super) fn emit(sh: Shape, blk: BlockPublic, w: Witness, fault: u8, name: &str, expect: bool) {
    let ids = Ids::new(&sh).unwrap();
    let blocks = vec![blk];
    let mut model = trained_statement::accuracy_hash_model(&sh, 1);
    model.layers[0].block_digest = blocks[0].digest();
    let scales = [model.calibration.block_scales];
    let plan = split_run::Plan::new(sh.clone(), [149; 32], &model, &blocks, &scales).unwrap();
    let profile = plan.stage(0).unwrap();
    let ins = pieces(&sh, profile, &w, ids.at(A_X));
    let outs = pieces(&sh, profile, &w, ids.at(A_X2));
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let ein =
        split_endpoint::prepare(&plan.endpoint(false).unwrap(), [&ins[0], &ins[1]], &ntt).unwrap();
    let eout =
        split_endpoint::prepare(&plan.endpoint(true).unwrap(), [&outs[0], &outs[1]], &ntt).unwrap();
    let ri = ein.commitment().root;
    let ro = eout.commitment().root;
    let st = plan.bind(ri, ro).unwrap();
    let _fault = FaultScope::new(fault);
    let mut frames = Vec::new();
    split_run::prove(&st, &blocks, &mut One(Some(w)), [ein, eout], &mut |k, b| {
        assert_eq!(k, frames.len());
        frames.push(b);
        Ok(())
    })
    .unwrap();
    assert_eq!(
        frames.len(),
        1,
        "malicious prover did not emit the whole receipt"
    );
    let geom = wire::split::Geometry::new(st.plan().stage(0).unwrap(), 1, 0).unwrap();
    let start = split_run::position_tag(&st.transcript());
    let (segment, _) = wire::split::decode(&frames[0], &geom, &st.binding(), &start).unwrap();
    assert_eq!(
        segment.slots.len(),
        st.plan().stage(0).unwrap().layout().slots.len()
    );
    let result = verify(&st, &blocks, &frames);
    if expect {
        result.unwrap();
    } else {
        let error = result.expect_err("native verifier accepted complete malicious R14 receipt");
        assert!(
            !error.contains("R14 wire") && !error.contains("R14 run"),
            "attack stopped at routing rather than native argument: {error}"
        );
        eprintln!("R14_ATTACK_REFUSAL {name}: {error}");
        if let Ok(path) = std::env::var("HL_R14_ATTACK_OUTPUT") {
            let dir = std::path::PathBuf::from(path);
            assert!(!dir.exists(), "do not overwrite retained malicious receipt");
            std::fs::create_dir_all(&dir).unwrap();
            std::fs::write(dir.join("segment0.bin"), &frames[0]).unwrap();
            let hex = |d: &[u8]| d.iter().map(|b| format!("{b:02x}")).collect::<String>();
            std::fs::write(dir.join("statement.txt"),format!("R14-public-synthetic-malicious-fixture/1\ncase={name}\ndd={}\nmodel_identity={}\ninput_root={}\noutput_root={}\nbinding={}\nerror={error}\n",usize::from(sh.dd_cap>0),hex(&model.identity()),hex(&ri),hex(&ro),hex(&st.binding()))).unwrap();
        }
    }
    eprintln!("R14_MALICIOUS_RECEIPT {{\"case\":{:?},\"dd\":{},\"bytes\":{},\"expected_accept\":{},\"canonical_frame_decoded\":true,\"native_verifier_used\":true}}",name,sh.dd_cap>0,frames[0].len(),expect);
}
fn local_group_contexts(dd: bool) -> (Shape, BlockPublic, BlockPublic, Witness, Witness) {
    let (seed, base) = ordinary_fixture(dd);
    let a = base.accuracy().unwrap();
    // Give narrow channel 8192 a live gate of 2 in both contexts. The old
    // sparse weights rounded every gate to zero, where all SiLU members agree.
    // Group 8192 % 3 = 2 differs from the incorrectly reset local group 0.
    let mut multipliers = a.multipliers().clone();
    multipliers.g[8192] = 64;
    let mut ff = base.feed_forward().clone();
    for j in 0..seed.d_pad {
        ff.wg_t[j * seed.f_pad + 8192] = 0;
    }
    ff.wg_t[8192] = -127;
    ff.wg_t[2 * seed.f_pad + 8192] = -127;
    let groups = vec![
        Group {
            e_in: -1,
            e_out: -11,
        },
        Group {
            e_in: -1,
            e_out: -10,
        },
        Group {
            e_in: -1,
            e_out: -9,
        },
    ];
    let tables = groups
        .iter()
        .map(|g| accuracy_tables::silu_table_for(a.registry(), g.e_in, g.e_out, 12).unwrap())
        .collect::<Vec<_>>();
    let make = |local: bool| {
        AccuracyPublic::new_with_registry(
            a.registry(),
            a.stack(),
            a.geometry(),
            a.base(),
            a.member(),
            multipliers.clone(),
            groups.clone(),
            (0..seed.hidden)
                .map(|j| {
                    if local && j >= 8192 {
                        (j - 8192) % 3
                    } else {
                        j % 3
                    }
                })
                .collect(),
            tables.clone(),
        )
        .unwrap()
    };
    let correct = BlockPublic::new(base.attention().clone(), ff.clone()).with_accuracy(make(false));
    let changed = BlockPublic::new(base.attention().clone(), ff).with_accuracy(make(true));
    assert_eq!(
        correct.accuracy().unwrap().folds().gate,
        changed.accuracy().unwrap().folds().gate
    );
    assert_eq!(
        correct.accuracy().unwrap().folds().product.shift,
        changed.accuracy().unwrap().folds().product.shift
    );
    let sh = trained_statement::LayerRecord::of_block(0, &correct, vec![])
        .shape_at(&seed)
        .unwrap();
    let honest = witness::build_for_block(&sh, &correct, &input(&sh)).unwrap();
    let wrong = witness::build_for_block(&sh, &changed, &input(&sh)).unwrap();
    let ids = Ids::new(&sh).unwrap();
    assert_eq!(honest.planes[ids.at(A_G8)], wrong.planes[ids.at(A_G8)]);
    assert_eq!(honest.planes[ids.at(A_G8)][8192], 2);
    let good = correct.accuracy().unwrap().scaled_tables()[2][2050];
    let bad = changed.accuracy().unwrap().scaled_tables()[0][2050];
    // Independently retained rational table vectors give 16 * 4096 and
    // 66 * 1024 here. Gate 1 would cancel after output-unit alignment.
    assert_eq!((good, bad), (65536, 67584));
    assert_ne!(good, bad, "the selected generated table words must differ");
    assert_eq!(honest.planes[ids.at(A_A16)][8192], good);
    assert_eq!(wrong.planes[ids.at(A_A16)][8192], bad);
    assert!(honest.planes[ids.at(A_A16)] != wrong.planes[ids.at(A_A16)],
        "the group-index fixture must change the activation witness");
    eprintln!("R14_GROUP_FIXTURE dd={dd} global_channel=8192 gate=2 global_group=2 local_group=0 correct={good} wrong={bad}");
    (sh, correct, changed, honest, wrong)
}

#[test]
#[ignore = "guarded bounded witness-only group fixture check, explicit HL_R14_DD"]
fn split_local_group_fixture_has_distinct_outputs() {
    let dd = match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("explicit DD0/1"),
    };
    let _ = local_group_contexts(dd);
}

fn local_group_case(dd: bool) {
    let (sh, correct, changed, honest, wrong) = local_group_contexts(dd);
    // Both arithmetic contexts must succeed before the cross-context attack.
    emit(
        sh.clone(),
        correct.clone(),
        honest,
        0,
        "global-group-honest",
        true,
    );
    emit(
        sh.clone(),
        changed,
        wrong.clone(),
        0,
        "local-group-honest",
        true,
    );
    let _cheat = protocol::CheatingProver::on(); // only pre-proof ACT output miss
    emit(sh, correct, wrong, 0, "local-group-reset", false);
}

#[test]
#[ignore = "separate guarded native R14 malicious receipt; explicit HL_R14_ATTACK / HL_R14_DD"]
fn split_run_t128_malicious_arithmetic_receipt_from_env() {
    let name = std::env::var("HL_R14_ATTACK").expect("explicit attack required");
    let dd = match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("explicit DD0/1"),
    };
    if name == "local-group-reset" {
        local_group_case(dd);
        return;
    }
    let (sh, blk) = ordinary_fixture(dd);
    let mut w = witness::build_for_block(&sh, &blk, &input(&sh)).unwrap();
    let fault = match name.as_str() {
        "per-piece-round-q" => {
            mutate_round_q(&sh, &blk, &mut w);
            0
        }
        "local-c2-ao" => {
            mutate_c2_ao(&sh, &blk, &mut w);
            0
        }
        "one-piece-norm" => 1,
        "wrong-omitted-source-bit" => 2,
        "missing-public-lift-gate" => 3,
        "wrong-feature-axis" => 4,
        "wrong-global-fold-offset" => 5,
        _ => panic!("unknown attack {name}"),
    };
    emit(sh, blk, w, fault, &name, false);
}
