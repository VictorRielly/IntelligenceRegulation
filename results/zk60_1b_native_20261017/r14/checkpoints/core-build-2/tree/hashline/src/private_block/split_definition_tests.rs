//! Actual SlotDef census and polynomial degree checks, not a proof gate.
use super::*;
use crate::private_block::{
    accuracy_groups::Group,
    accuracy_public::{AccuracyPublic, Geometry, Multipliers},
    accuracy_tables,
    shape::{self, NormCalibration},
    split_endpoint::{IoSources, JointSpec, Kind, Use},
    split_layout::Part,
    split_profile::SplitProfile,
};

fn calibration() -> NormCalibration {
    NormCalibration {
        tn: 9,
        cn_a: 100,
        cn_m: 100,
        ceps: 1,
        sh_ao: 7,
        sh_qkv: 8,
        sh_s: 6,
        sh_o: 9,
        sh_g: 8,
        sh_h: 14,
        sh_z: 6,
    }
}
fn data(sh: &Shape) -> AccuracyPublic {
    let values = |n: usize, max: usize| (0..n).map(|j| (1 + (j * 37 + 11) % max) as u16).collect();
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
        .map(|g| {
            accuracy_tables::silu_table_for(sh.accuracy_registry(), g.e_in, g.e_out, 12).unwrap()
        })
        .collect();
    AccuracyPublic::new_with_registry(
        sh.accuracy_registry(),
        sh.accuracy_stack(),
        Geometry {
            width: sh.width,
            query_width: sh.q_width(),
            kv_width: sh.kv_heads * sh.head_dim,
            hidden: sh.hidden,
        },
        sh.accuracy_base(),
        (-3, -11),
        Multipliers {
            q: values(sh.q_width(), 32),
            k: values(sh.kv_heads * sh.head_dim, 32),
            v: values(sh.kv_heads * sh.head_dim, 64),
            o: values(sh.width, 256),
            g: values(sh.hidden, 64),
            u: values(sh.hidden, 16),
            d: values(sh.width, 64),
        },
        groups,
        (0..sh.hidden).map(|j| usize::from(j >= 8192)).collect(),
        tables,
    )
    .unwrap()
}
fn matrix(rows: usize, cols: usize, live_rows: usize, live_cols: usize) -> Vec<i8> {
    let mut v = vec![0; rows * cols];
    // Sparse but nonzero on both sides of each true piece boundary. The
    // separate geometry gate supplies dense public-fold differential cases.
    for r in [0, live_rows / 2, live_rows - 1] {
        for c in [0, live_cols / 2, live_cols - 1] {
            v[r * cols + c] = ((r + c) % 253) as i16 as i8;
            if v[r * cols + c] == -128 {
                v[r * cols + c] = 127;
            }
        }
    }
    v
}
fn public(sh: &Shape) -> (AttentionPublic, FeedForwardPublic) {
    let kv = sh.kv_heads * sh.head_dim;
    let a = AttentionPublic {
        wq: matrix(sh.q_pad(), sh.d_pad, sh.q_pad(), sh.width),
        wk: matrix(kv, sh.d_pad, kv, sh.width),
        wv: matrix(kv, sh.d_pad, kv, sh.width),
        wo: matrix(sh.d_pad, sh.q_pad(), sh.width, sh.q_pad()),
        gamma_a: (0..sh.d_pad)
            .map(|j| {
                if j < sh.width {
                    (j % 255) as i16 as i8
                } else {
                    0
                }
            })
            .collect(),
        rope_cos: vec![127; sh.tokens * sh.head_dim / 2],
        rope_sin: vec![0; sh.tokens * sh.head_dim / 2],
        exp: vec![1; 256],
    };
    let f = FeedForwardPublic {
        gamma_m: a.gamma_a.clone(),
        wg_t: matrix(sh.d_pad, sh.f_pad, sh.width, sh.hidden),
        wu_t: matrix(sh.d_pad, sh.f_pad, sh.width, sh.hidden),
        wd_t: matrix(sh.f_pad, sh.d_pad, sh.hidden, sh.width),
        act: [0; 256],
    };
    (a, f)
}
fn check_degree(def: &SlotDef, degree: usize) {
    // Every formal table is affine in a variable. The (degree+1)th finite
    // difference must vanish, including a shared extension variable.
    let mut values = (0..degree + 2)
        .map(|x| {
            let v = (0..def.tabs.len())
                .map(|i| {
                    Fp2::new(
                        Fp::new((i * 31 + 7 + x * (i * 13 + 3)) as u64),
                        Fp::new((i * 11 + 5 + x * (i * 7 + 1)) as u64),
                    )
                })
                .collect::<Vec<_>>();
            (def.poly)(&v)
        })
        .collect::<Vec<_>>();
    for _ in 0..degree + 1 {
        values = values.windows(2).map(|w| w[1].sub(w[0])).collect();
    }
    assert_eq!(
        values[0],
        Fp2::ZERO,
        "slot{} polynomial exceeds declared degree{}",
        def.slot,
        degree
    );
}

#[test]
fn split_actual_definitions_match_all_physical_sites_sources_hosts_and_degrees() {
    for base in [
        shape::R13_SHIELD_T128_H24,
        shape::R13_SHIELD_T128_H24_DD,
        shape::R13_SHIELD_T256_H24,
        shape::R13_SHIELD_T256_H24_DD,
    ] {
        let profile =
            SplitProfile::new(Shape::accuracy_trained(base, &calibration(), 9, 20).unwrap())
                .unwrap();
        let sh = profile.base();
        let s = profile.layout();
        let lay = Layout::for_shape(sh).unwrap();
        let a = data(sh);
        let (public, ff) = public(sh);
        let ctx = Ctx {
            accuracy: Some(&a),
            lay: &lay,
            public: &public,
            ff: &ff,
            alpha: k(1000003),
            beta: k(23),
            g_u8: k(31),
            g_exp: k(37),
            g_act: k(41),
            g_dd: k(43),
        };
        let input = JointSpec::new(&profile, [17; 32], Kind::Input, 0).unwrap();
        let output = JointSpec::new(&profile, [17; 32], Kind::Output, 0).unwrap();
        let sources = IoSources {
            input: (&input, Use::External),
            output: (&output, Use::External),
        };
        let mut points = split::SplitPoints::default();
        let mut tr = Transcript::new_tagged(
            b"R14 definition census fixture",
            *profile.tag().transcript_key().unwrap(),
        );
        let mut seen = [Vec::new(), Vec::new(), Vec::new(), Vec::new()];
        let mut claims: [Vec<crate::pcs::ZClaim>; 4] = Default::default();
        let plan = split::schedule(s);
        for (physical, slot) in s.slots.iter().enumerate() {
            let def =
                split::define(physical, &profile, &ctx, &mut points, &sources, &mut tr).unwrap();
            let rho = (0..slot.main)
                .map(|j| {
                    Fp2::new(
                        Fp::new((physical * 101 + j * 31 + 17) as u64),
                        Fp::new((physical * 37 + j * 13 + 23) as u64),
                    )
                })
                .collect::<Vec<_>>();
            assert_eq!(def.slot, physical);
            assert_eq!(
                def.tabs
                    .iter()
                    .filter(|t| matches!(t, Tab::Priv(_)))
                    .count(),
                plan[physical].terminals
            );
            for t in &def.tabs {
                match t {
                    Tab::Eq { point, start } => assert!(start + point.len() <= slot.main),
                    Tab::Pub(v) => assert_eq!(v.len(), 1usize << slot.main),
                    Tab::Priv(p) => {
                        let point = claim_point(p, &rho);
                        claims[p.cm as usize].push(build_claim(
                            sh,
                            p,
                            &point,
                            k(3),
                            k(5),
                            Fp2::ZERO,
                        ));
                        assert_eq!(p.coords.len(), p.log);
                        assert!(p.ext_round < slot.ext);
                        for c in &p.coords {
                            if let Coord::Rho(k) | Coord::Flip(k) = c {
                                assert!(*k < slot.main);
                            }
                        }
                        assert!(!seen[p.cm as usize].contains(&p.mask_row));
                        seen[p.cm as usize].push(p.mask_row);
                        let rows = match p.cm {
                            Cm::A => s.a_data_rows,
                            Cm::H => s.h_data_rows,
                            Cm::In | Cm::Out => s.endpoint.data_rows,
                        };
                        assert!(p
                            .slices
                            .iter()
                            .all(|(off, _)| off + (1usize << p.log) <= rows * s.n));
                    }
                }
            }
            for &(host, _) in &def.hosted {
                assert!(host < physical);
                assert_eq!(plan[host].kind, SlotKind::Private);
            }
            if matches!(slot.base, SC_DZC | SC_FZC) {
                assert_eq!(def.hosted.len(), 2);
            }
            check_degree(&def, slot.degree);
            if slot.base == SC_DZC {
                let e = s.d[usize::from(slot.part == Part::Narrow)];
                let public_factors = def
                    .tabs
                    .iter()
                    .filter_map(|t| if let Tab::Pub(v) = t { Some(v) } else { None })
                    .collect::<Vec<_>>();
                let expected = (0..sh.tokens * e.width)
                    .map(|i| k(public.gamma_a[e.start + i % e.width] as i64))
                    .collect::<Vec<_>>();
                assert_eq!(
                    public_factors[0], &expected,
                    "D-piece norm_a gain must use global features and true token stride"
                );
                let expected = (0..sh.tokens * e.width)
                    .map(|i| k(ff.gamma_m[e.start + i % e.width] as i64))
                    .collect::<Vec<_>>();
                assert_eq!(
                    public_factors[1], &expected,
                    "D-piece norm_m gain must use global features and true token stride"
                );
            }
            if slot.base == SC_FZC && slot.part == Part::Narrow {
                assert!(def.tabs.iter().any(|t|matches!(t,Tab::Pub(v) if v.len()==sh.tokens*1024&&v.iter().all(|&x|x==Fp2::ONE))),"ACT3 narrow group column lost global offset8192");
            }
            eprintln!("R14_ACTUAL_SLOT {{\"base\":{:?},\"physical\":{},\"logical\":{},\"part\":{:?},\"main\":{},\"ext\":{},\"degree\":{},\"terminals\":{},\"hosted\":{},\"scope\":\"native SlotDef source/site/degree census; not a full proof or privacy gate\"}}",base,physical,slot.base,format!("{:?}",slot.part),slot.main,slot.ext,slot.degree,plan[physical].terminals,def.hosted.len());
        }
        assert_eq!(
            seen[Cm::A as usize].len(),
            s.slots.iter().map(|s| s.a_sites).sum::<usize>()
        );
        assert_eq!(
            seen[Cm::H as usize].len(),
            s.slots.iter().map(|s| s.h_sites).sum::<usize>()
        );
        assert_eq!(seen[Cm::In as usize].len(), 2);
        assert_eq!(seen[Cm::Out as usize].len(), 2);
        claims[Cm::H as usize].push(split::sum_claim(&profile).unwrap());
        let a_rows = s
            .slots
            .iter()
            .flat_map(|slot| slot.a_pairs.iter().flat_map(|&r| [r, r + 1]))
            .collect::<Vec<_>>();
        let h_rows = s
            .slots
            .iter()
            .flat_map(|slot| slot.h_pairs.iter().flat_map(|&r| [r, r + 1]))
            .collect::<Vec<_>>();
        let u = s.plane(true, lay.hids().u(), Part::Whole).unwrap();
        let urows = [u.offset / s.n, u.offset / s.n + u.rows_per_component];
        crate::private_block::protocol::audit_claims(
            &claims[0],
            s.n,
            s.a_rows,
            &a_rows,
            None,
            s.a_rows - 2,
        )
        .unwrap();
        crate::private_block::protocol::audit_claims(
            &claims[1],
            s.n,
            s.h_rows,
            &h_rows,
            Some(urows),
            s.h_rows - 2,
        )
        .unwrap();
        let groups = claims
            .iter()
            .map(|v| {
                crate::private_block::protocol::opening_groups_at(v, sh.log_cols)
                    .unwrap()
                    .len()
            })
            .collect::<Vec<_>>();
        eprintln!("R14_NATIVE_GROUPS {{\"base\":{:?},\"f_e\":{},\"a_groups\":{},\"h_groups\":{},\"input_groups\":{},\"output_groups\":{},\"functionals\":{},\"sc_round_degree_sum\":{},\"scope\":\"native claim construction at public generic points; fixed geometry census, not a proof\"}}",base,sh.f_e,groups[0],groups[1],groups[2],groups[3],plan.len()+plan.iter().filter(|m|m.kind!=SlotKind::Private).count(),plan.iter().map(|m|(m.main+m.ext)*m.degree).sum::<usize>());
    }
}

#[test]
fn split_witness_global_histograms_remove_only_the_old_padding_queries() {
    use crate::private_block::{split_witness::PieceWitness, witness::Witness};
    let profile = SplitProfile::new(
        Shape::accuracy_trained(shape::R13_SHIELD_T128_H24, &calibration(), 9, 20).unwrap(),
    )
    .unwrap();
    let sh = profile.base();
    let ids = Ids::new(sh).unwrap();
    let a = data(sh);
    // A public zero numeric fixture tests lookup inventory, not the integer
    // arithmetic relations. Dense indexing is exercised by split_geometry.
    let planes = sh
        .a_plane_doms()
        .iter()
        .enumerate()
        .map(|(parent, &dom)| {
            if ids.is_multiplicity(parent) {
                Vec::new()
            } else {
                vec![0; sh.size(dom)]
            }
        })
        .collect();
    let reference = Witness {
        planes,
        output_plane: ids.at(A_X2),
    };
    let mut physical = PieceWitness::from_reference(&profile, reference).unwrap();
    let histogram = physical.byte_histogram(&profile).unwrap();
    let mut expected = vec![0u64; 256];
    let mut old_count = 0u64;
    for dom in sh.lookup_doms() {
        let count = match dom {
            Dom::D => sh.tokens * sh.width,
            Dom::F => sh.tokens * sh.hidden,
            _ => sh.size(dom),
        };
        for lookup in lookups_at(sh, &ids, dom) {
            expected[lookup.cst as usize] += count as u64;
            old_count += sh.size(dom) as u64;
        }
    }
    assert_eq!(histogram, expected);
    assert!(histogram.iter().sum::<u64>() < old_count);
    let act = physical.act_histogram(&profile, &a).unwrap();
    assert_eq!(act.iter().sum::<u64>() as usize, sh.tokens * sh.hidden);
    assert_eq!(act[2048], (sh.tokens * 8192) as u64);
    assert_eq!(act[4096 + 2048], (sh.tokens * 1024) as u64);
    let exp = vec![0u64; 256];
    physical
        .set_histograms(&profile, [&histogram, &exp, &act])
        .unwrap();
    assert!(physical
        .set_histograms(&profile, [&histogram, &exp, &act])
        .is_err());
    let words = physical.write_a_data(&profile).unwrap();
    assert_eq!(words.len(), profile.layout().a_rows * profile.layout().n);
}

fn core_case(dd: bool) {
    use crate::ntt::NttTables;
    use crate::private_block::{
        self,
        protocol::{CoreProof, CoreView},
        split_endpoint, split_protocol, witness,
    };
    use crate::zk::ZkRng;
    let base = if dd {
        shape::R13_SHIELD_T128_H24_DD
    } else {
        shape::R13_SHIELD_T128_H24
    };
    let profile =
        SplitProfile::new(Shape::accuracy_trained(base, &calibration(), 9, 20).unwrap()).unwrap();
    let sh = profile.base();
    let (mut attn, mut ff) = public(sh);
    attn.rope_cos.fill(1i64 << F_RO);
    attn.exp.fill(1i64 << sh.f_e);
    for j in 0..sh.width {
        attn.gamma_a[j] = ((j % 255) as i16 - 127) as i8;
        ff.gamma_m[j] = attn.gamma_a[j];
    }
    let block = private_block::BlockPublic::new(attn, ff).with_accuracy(data(sh));
    block.check_for_shape(sh).unwrap();
    let input = (0..sh.tokens * sh.width)
        .map(|i| if i % 2 == 0 { 1i16 } else { -1i16 })
        .collect::<Vec<_>>();
    let wit = witness::build_for_block(sh, &block, &input).unwrap();
    let ids = Ids::new(sh).unwrap();
    let pieces = |parent| {
        crate::private_block::split_geometry::gather_numeric_plane(
            sh,
            profile.layout(),
            parent,
            &wit.planes[parent],
        )
        .unwrap()
        .into_iter()
        .map(|(_, v)| v.into_iter().map(Fp::from_i64).collect::<Vec<_>>())
        .collect::<Vec<_>>()
    };
    let ins = pieces(ids.at(A_X));
    let outs = pieces(ids.at(A_X2));
    let mut h = blake3::Hasher::new();
    h.update(b"R14 native core public synthetic fixture, not trained statement");
    h.update(&profile.digest());
    h.update(&block.digest());
    let context = *h.finalize().as_bytes();
    let sin = JointSpec::new(&profile, context, Kind::Input, 0).unwrap();
    let sout = JointSpec::new(&profile, context, Kind::Output, 0).unwrap();
    let ntt = NttTables::new(crate::private_block::protocol::ntt_log_at(sh));
    let ein = split_endpoint::prepare(&sin, [&ins[0], &ins[1]], &ntt).unwrap();
    let eout = split_endpoint::prepare(&sout, [&outs[0], &outs[1]], &ntt).unwrap();
    let ri = ein.commitment();
    let ro = eout.commitment();
    let sources = IoSources {
        input: (&sin, Use::External),
        output: (&sout, Use::External),
    };
    let transcript = || {
        let mut t = Transcript::new_tagged(
            b"R14 native core component fixture",
            *profile.tag().transcript_key().unwrap(),
        );
        t.absorb(b"profile", &profile.digest());
        t.absorb(b"fixture-context", &context);
        t.absorb(b"block", &block.digest());
        t.absorb(b"input-spec", &sin.digest());
        t.absorb(b"output-spec", &sout.digest());
        t.absorb(b"input-root", &ri.root);
        t.absorb(b"output-root", &ro.root);
        t
    };
    let mut rng = ZkRng::from_os(&context).unwrap();
    let mut tp = transcript();
    let mut core = split_protocol::prove_core(
        &profile,
        &block,
        wit,
        &sources,
        [ein.data(), eout.data()],
        &ntt,
        &mut rng,
        &mut tp,
    )
    .unwrap();
    let oi = ein.into_opening(&sin, &core.io_claims[0], &mut tp).unwrap();
    let oo = eout
        .into_opening(&sout, &core.io_claims[1], &mut tp)
        .unwrap();
    fn view(c: &CoreProof) -> CoreView<'_> {
        CoreView {
            a_root: c.a_root,
            h_root: c.h_root,
            mask_root: c.mask_root,
            slots: &c.slots,
            mask_open: &c.mask_open,
            a_open: &c.a_open,
            h_open: &c.h_open,
        }
    }
    let mut tv = transcript();
    let [ic, oc] =
        split_protocol::verify_core(&profile, &block, &sources, view(&core), &ntt, &mut tv)
            .unwrap();
    split_endpoint::verify(&sin, &ri, &ic, &oi, &ntt, &mut tv).unwrap();
    split_endpoint::verify(&sout, &ro, &oc, &oo, &ntt, &mut tv).unwrap();
    core.slots[0].scalar = core.slots[0].scalar.add(Fp2::ONE);
    assert!(split_protocol::verify_core(
        &profile,
        &block,
        &sources,
        view(&core),
        &ntt,
        &mut transcript()
    )
    .is_err());
    eprintln!("R14_NATIVE_CORE {{\"tokens\":128,\"dd\":{},\"slots\":{},\"a_rows\":{},\"h_rows\":{},\"joint_endpoint_rows\":{},\"lookups\":{:?},\"status\":\"native core and both joint endpoints prove/verify; scalar tamper refuses\",\"scope\":\"public synthetic component, in-process only; no wire/CLI/trained-model/privacy acceptance\"}}",dd,core.slots.len(),profile.layout().a_rows,profile.layout().h_rows,profile.layout().endpoint.external_rows,core.lookups);
}

#[test]
#[ignore = "separate guarded T128 native R14 core, need9.5GiB; no T256 laptop proof"]
fn split_native_core_t128_non_dd_proves_verifies_and_tamper_refuses() {
    core_case(false)
}

#[test]
#[ignore = "separate guarded T128 native R14 core, need9.5GiB; no T256 laptop proof"]
fn split_native_core_t128_dd_proves_verifies_and_tamper_refuses() {
    core_case(true)
}
