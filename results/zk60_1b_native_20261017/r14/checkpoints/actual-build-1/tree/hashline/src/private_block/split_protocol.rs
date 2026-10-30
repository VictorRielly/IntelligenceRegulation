//! R14 core under a caller-owned, bound transcript. No CLI/codec/registry
//! dispatch selects this experimental path. Review/capture gates remain owed.
use super::{
    accuracy_act,
    argument::{self, Acc, Ctx, ProverData, Side},
    layout::*,
    protocol,
    split_endpoint::IoSources,
    split_layout::Part,
    split_profile::SplitProfile,
    split_witness::PieceWitness,
    witness::Witness,
    BlockPublic,
};
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, ZClaim, ZkOpts};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::transcript::Transcript;
use crate::zk::{self, ZkRng};

fn inverse(mut v: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    batch_inverse2_checked(&mut v)
        .map_err(|_| "zero LogUp denominator; discard attempt".to_string())?;
    Ok(v)
}
fn whole<'a>(w: &'a PieceWitness, p: &SplitProfile, parent: usize) -> Result<&'a [i64], String> {
    w.plane(p, parent, Part::Whole)
}
fn subset(w: &PieceWitness, p: &SplitProfile, roles: &[usize]) -> Result<Witness, String> {
    let ids = Ids::new(p.base())?;
    let mut planes = vec![Vec::new(); ids.n_a()];
    for &parent in roles {
        planes[parent] = whole(w, p, parent)?.to_vec();
    }
    Ok(Witness {
        planes,
        output_plane: ids.at(A_X2),
    })
}
fn write_h(
    out: &mut [Fp],
    p: &SplitProfile,
    parent: usize,
    part: Part,
    values: &[Fp2],
) -> Result<(), String> {
    let plane = p.layout().plane(true, parent, part)?;
    if values.len() > 1usize << plane.log {
        return Err("R14 H: helper length exceeds its role".into());
    }
    let im = plane.offset + plane.rows_per_component * p.layout().n;
    for (i, v) in values.iter().enumerate() {
        out[plane.offset + i] = v.c0;
        out[im + i] = v.c1;
    }
    Ok(())
}

fn histograms(
    w: &PieceWitness,
    p: &SplitProfile,
    lay: &Layout,
    blk: &BlockPublic,
) -> Result<[Vec<u64>; 3], String> {
    let ids = lay.ids();
    let m_u8 = w.byte_histogram(p)?;
    let exp_ref = subset(w, p, &[ids.at(A_S8), ids.at(A_MX)])?;
    let deltas = protocol::exp_deltas(lay, &exp_ref);
    let e = whole(w, p, ids.at(A_E))?;
    let mut m_exp = vec![0u64; 256];
    for (&delta, &word) in deltas.iter().zip(e) {
        let key = usize::try_from(delta)
            .ok()
            .filter(|&k| k < 256)
            .ok_or("R14 witness: exp input miss")?;
        if blk.attention().exp[key] != word {
            return Err("R14 witness: exp output miss".into());
        }
        m_exp[key] += 1;
    }
    let m_act = w.act_histogram(
        p,
        blk.accuracy()
            .ok_or("R14 histograms: missing bound accuracy data")?,
    )?;
    if p.base().dd_cap > 0 {
        let dd_ref = subset(w, p, &[ids.at(A_E), ids.at(A_P), ids.pdict()])?;
        if protocol::dd_misses(lay, &dd_ref, &blk.attention().dd_e_column(p.base().dd_cap)?) != 0 {
            return Err("R14 witness: dictionary tuple miss".into());
        }
    }
    Ok([m_u8, m_exp, m_act])
}

fn helpers(
    w: PieceWitness,
    p: &SplitProfile,
    lay: &Layout,
    blk: &BlockPublic,
    m: &[Vec<u64>; 3],
    alpha: Fp2,
    beta: Fp2,
    gamma: Fp2,
    rng: &mut ZkRng,
) -> Result<Vec<Fp>, String> {
    let s = p.layout();
    let sh = p.base();
    let ids = lay.ids();
    let hids = lay.hids();
    let gu8 = gamma.mul_base(Fp::new(TAG_U8));
    let gexp = gamma.mul_base(Fp::new(TAG_EXP));
    let gact = gamma.mul_base(Fp::new(TAG_ACT));
    let mut out = vec![Fp::ZERO; s.h_rows * s.n];
    let inv = protocol::u8_denominator_inverses(alpha, gu8);
    for dom in sh.lookup_doms() {
        let parts = if matches!(dom, Dom::D | Dom::F) {
            vec![Part::Wide, Part::Narrow]
        } else {
            vec![Part::Whole]
        };
        for part in parts {
            for helper in 0..sh.helpers(dom) {
                let first = w.lookup_column(p, dom, part, 2 * helper)?;
                let col = if 2 * helper + 1 < lay.lookups(dom).len() {
                    let second = w.lookup_column(p, dom, part, 2 * helper + 1)?;
                    protocol::helper_pair_inverses_u8(&first, &second, alpha, gu8, &inv)?
                } else {
                    protocol::helper_inverses_u8(&first, alpha, gu8, &inv)?
                };
                write_h(&mut out, p, hids.helper(dom, helper), part, &col)?;
            }
        }
    }
    let exp_ref = subset(&w, p, &[ids.at(A_S8), ids.at(A_MX)])?;
    let deltas = protocol::exp_deltas(lay, &exp_ref);
    let e = whole(&w, p, ids.at(A_E))?;
    let den = deltas
        .iter()
        .zip(e)
        .map(|(&d, &e)| alpha.sub(Fp2::from_i64(d).add(beta.mul(Fp2::from_i64(e))).add(gexp)))
        .collect();
    write_h(&mut out, p, hids.sexp(), Part::Whole, &inverse(den)?)?;
    let accuracy = blk.accuracy().ok_or("R14 H: missing bound accuracy data")?;
    let beta2 = beta.mul(beta);
    for (piece, part) in [Part::Wide, Part::Narrow].into_iter().enumerate() {
        let extent = s.f[piece];
        let gates = w.plane(p, ids.at(A_G8), part)?;
        let outputs = w.plane(p, ids.at(A_A16), part)?;
        let den = gates
            .iter()
            .zip(outputs)
            .enumerate()
            .map(|(i, (&gate, &output))| {
                let group = accuracy.group_ids()[extent.start + i % extent.width];
                alpha.sub(
                    Fp2::from_i64(gate)
                        .add(Fp2::from_i64(2048))
                        .add(beta.mul(Fp2::from_i64(output)))
                        .add(beta2.mul(Fp2::from_i64(group as i64)))
                        .add(gact),
                )
            })
            .collect();
        write_h(&mut out, p, hids.fact(), part, &inverse(den)?)?;
    }
    if sh.dd_cap > 0 {
        let dd_ref = subset(
            &w,
            p,
            &[ids.at(A_E), ids.at(A_P), ids.at(A_SUM), ids.pdict()],
        )?;
        let (queries, table) = protocol::dd_tuples(
            lay,
            &dd_ref,
            &blk.attention().dd_e_column(sh.dd_cap)?,
            beta,
            gamma.mul_base(Fp::new(TAG_DD)),
        );
        write_h(
            &mut out,
            p,
            hids.stuple(),
            Part::Whole,
            &inverse(queries.into_iter().map(|q| alpha.sub(q)).collect())?,
        )?;
        // Every dictionary denominator is inverted before its multiplicity,
        // including unused slots; the original D30 refusal rule is retained.
        let inv = inverse(table.into_iter().map(|q| alpha.sub(q)).collect())?;
        let counts = whole(&w, p, ids.mdd())?;
        let col = inv
            .iter()
            .zip(counts)
            .map(|(x, &c)| x.mul_base(Fp::from_i64(c)))
            .collect::<Vec<_>>();
        write_h(&mut out, p, hids.gdd(), Part::Whole, &col)?;
    }
    drop(w); // Numeric planes and query buffers are dead before H encoding.
    let act = accuracy_act::table(accuracy, sh.size(Dom::Tab), beta, gact)?;
    let values = [
        argument::table_values_u8(gu8),
        argument::table_values_exp(blk.attention(), beta, gexp),
        act.compressed[..act.entries].to_vec(),
    ];
    for ((parent, table), counts) in hids.table_helpers().into_iter().zip(values).zip(m) {
        let inv = inverse(table.into_iter().map(|x| alpha.sub(x)).collect())?;
        let col = inv
            .iter()
            .zip(counts)
            .map(|(x, &count)| x.mul_base(Fp::new(count)))
            .collect::<Vec<_>>();
        write_h(&mut out, p, parent, Part::Whole, &col)?;
    }
    for x in &mut out[s.h_data_rows * s.n..] {
        *x = rng.fp();
    }
    let u = s.plane(true, hids.u(), Part::Whole)?;
    for row in [u.offset / s.n, u.offset / s.n + u.rows_per_component] {
        let mut sum = Fp::ZERO;
        for j in 0..s.n - 1 {
            let v = rng.fp();
            out[row * s.n + j] = v;
            sum = sum.add(v);
        }
        out[(row + 1) * s.n - 1] = sum.neg();
    }
    Ok(out)
}

fn argument(
    side: &mut Side,
    p: &SplitProfile,
    ctx: &Ctx,
    sources: &IoSources<'_>,
    tr: &mut Transcript,
) -> Result<Acc, String> {
    let plan = argument::split::schedule(p.layout());
    let mut points = argument::split::SplitPoints::default();
    let mut acc = Acc::default();
    for slot in 0..plan.len() {
        let mut def = argument::split::define(slot, p, ctx, &mut points, sources, tr)?;
        #[cfg(test)]
        if matches!(side, Side::Prove { .. }) {
            argument::split_attack_tests::apply_prover_definition_fault(p, &mut def);
        }
        argument::run_slot_scheduled(side, &mut acc, def, tr, &plan)?;
    }
    acc.fs.append(&mut acc.host_fs);
    let count = plan.len() + plan.iter().filter(|m| m.kind != SlotKind::Private).count();
    if acc.fs.len() != count {
        return Err("R14 argument: M functional census mismatch".into());
    }
    Ok(acc)
}

fn site_rows(p: &SplitProfile, h: bool) -> Vec<usize> {
    p.layout()
        .slots
        .iter()
        .flat_map(|s| if h { &s.h_pairs } else { &s.a_pairs })
        .flat_map(|&r| [r, r + 1])
        .collect()
}
fn u_rows(p: &SplitProfile, lay: &Layout) -> Result<[usize; 2], String> {
    let u = p.layout().plane(true, lay.hids().u(), Part::Whole)?;
    Ok([
        u.offset / p.layout().n,
        u.offset / p.layout().n + u.rows_per_component,
    ])
}
fn check_ntt(p: &SplitProfile, ntt: &NttTables) -> Result<(), String> {
    protocol::fits_the_ntt_tables(p.base())?;
    let need = protocol::ntt_log_at(p.base())
        .max(p.base().endpoint_log_n as u32 + p.base().endpoint_inv_rate.trailing_zeros());
    if ntt.max_log < need || ntt.max_log > 20 {
        return Err("R14 core: NTT does not cover the declared domains".into());
    }
    let half = (1usize << ntt.max_log) / 2;
    if ntt.roots.len() != ntt.max_log as usize + 1
        || ntt.inv_roots.len() != ntt.max_log as usize + 1
        || ntt.twiddle_tables().0.len() != half.max(1)
        || ntt.twiddle_tables().1.len() != half.max(1)
        || (0..=ntt.max_log).any(|k| {
            ntt.roots[k as usize] != Fp::two_adic_root(k)
                || ntt.inv_roots[k as usize] != Fp::two_adic_root(k).inv()
        })
    {
        return Err("R14 core: noncanonical NTT".into());
    }
    Ok(())
}
fn ctx<'a>(lay: &'a Layout, blk: &'a BlockPublic, alpha: Fp2, beta: Fp2, gamma: Fp2) -> Ctx<'a> {
    Ctx {
        accuracy: blk.accuracy(),
        lay,
        public: blk.attention(),
        ff: blk.feed_forward(),
        alpha,
        beta,
        g_u8: gamma.mul_base(Fp::new(TAG_U8)),
        g_exp: gamma.mul_base(Fp::new(TAG_EXP)),
        g_act: gamma.mul_base(Fp::new(TAG_ACT)),
        g_dd: gamma.mul_base(Fp::new(TAG_DD)),
    }
}
/// Fixed geometry counts reproduced by native claim construction at all four
/// variants. Unexpected challenge collisions are public-rule refusals.
fn groups(p: &SplitProfile) -> (usize, usize) {
    let dd = usize::from(p.base().dd_cap > 0);
    (56 + 2 * dd, 11 + dd)
}

pub(crate) fn prove_core(
    p: &SplitProfile,
    blk: &BlockPublic,
    wit: Witness,
    sources: &IoSources<'_>,
    io_data: [&[Fp]; 2],
    ntt: &NttTables,
    rng: &mut ZkRng,
    tr: &mut Transcript,
) -> Result<protocol::CoreProof, String> {
    let sh = p.base();
    let s = p.layout();
    check_ntt(p, ntt)?;
    blk.check_for_shape(sh)?;
    let lay = Layout::for_shape(sh)?;
    for ((spec, usage), data) in [sources.input, sources.output].into_iter().zip(io_data) {
        spec.source(p, usage, 0)?;
        if data.len() != spec.rows() * (1usize << spec.params().log_cols) {
            return Err("R14 core: IO commitment buffer length differs".into());
        }
    }
    let mut wit = PieceWitness::from_reference(p, wit)?;
    let m = histograms(&wit, p, &lay, blk)?;
    wit.set_histograms(p, [&m[0], &m[1], &m[2]])?;
    let mut a_data = wit.write_a_data(p)?;
    for x in &mut a_data[s.a_data_rows * s.n..] {
        *x = rng.fp();
    }
    let params = protocol::pcs_params_at(sh);
    let zko = ZkOpts::standard(&params);
    let tag = p.tag();
    let mut a = pcs::commit_zk_owned_tagged(&params, a_data, ntt, &zko, rng, &tag);
    a.mask_rows = site_rows(p, false);
    a.prox_mask_row = Some(s.a_rows - 2);
    let a_root = a.commitment().root;
    protocol::absorb_root(tr, b"A", &a_root, s.a_rows, sh.log_cols);
    let plan = argument::split::schedule(s);
    let specs = plan
        .iter()
        .map(argument::SlotSchedule::mask_spec)
        .collect::<Vec<_>>();
    let mc = zk::mask_commit_tagged(&specs, ntt, rng, &tag);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let h_data = helpers(wit, p, &lay, blk, &m, alpha, beta, gamma, rng)?;
    let mut h = pcs::commit_zk_owned_tagged(&params, h_data, ntt, &zko, rng, &tag);
    h.mask_rows = site_rows(p, true)
        .into_iter()
        .chain(u_rows(p, &lay)?)
        .collect();
    h.prox_mask_row = Some(s.h_rows - 2);
    let h_root = h.commitment().root;
    protocol::absorb_root(tr, b"H", &h_root, s.h_rows, sh.log_cols);
    let mut side = Side::Prove {
        pd: ProverData {
            data: [&a.data, &h.data, io_data[0], io_data[1]],
            masks: &mc.masks,
        },
        out: vec![],
    };
    let acc = argument(
        &mut side,
        p,
        &ctx(&lay, blk, alpha, beta, gamma),
        sources,
        tr,
    )?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        _ => unreachable!(),
    };
    let mask_open = zk::mask_open(&mc, &acc.fs, ntt, tr);
    drop(mc);
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(argument::split::sum_claim(p)?);
    let (ag, hg) = groups(p);
    protocol::check_opening(
        &ac,
        sh.log_cols,
        s.a_rows,
        &site_rows(p, false),
        None,
        s.a_rows - 2,
        ag,
        tr,
    )?;
    let a_open = pcs::open_zk(&a, &ac, tr);
    drop(a);
    protocol::check_opening(
        &hc,
        sh.log_cols,
        s.h_rows,
        &site_rows(p, true),
        Some(u_rows(p, &lay)?),
        s.h_rows - 2,
        hg,
        tr,
    )?;
    let h_open = pcs::open_zk(&h, &hc, tr);
    drop(h);
    Ok(protocol::CoreProof {
        a_root,
        h_root,
        mask_root,
        slots,
        mask_open,
        a_open,
        h_open,
        io_claims: [ic, oc],
        order: acc.order,
        lookups: m.each_ref().map(|c| c.iter().sum::<u64>() as usize),
    })
}

pub(crate) fn verify_core(
    p: &SplitProfile,
    blk: &BlockPublic,
    sources: &IoSources<'_>,
    v: protocol::CoreView<'_>,
    ntt: &NttTables,
    tr: &mut Transcript,
) -> Result<[Vec<ZClaim>; 2], String> {
    let sh = p.base();
    let s = p.layout();
    check_ntt(p, ntt)?;
    blk.check_for_shape(sh)?;
    let lay = Layout::for_shape(sh)?;
    if v.slots.len() != s.slots.len() {
        return Err("R14 core: dropped or extra physical slot".into());
    }
    let params = protocol::pcs_params_at(sh);
    let zko = ZkOpts::standard(&params);
    let tag = p.tag();
    super::hash_domain::paths_are_the_tree_depth("R14 A", &params, v.a_open)?;
    super::hash_domain::paths_are_the_tree_depth("R14 H", &params, v.h_open)?;
    super::hash_domain::mask_paths_are_the_tree_depth(v.mask_open)?;
    protocol::absorb_root(tr, b"A", &v.a_root, s.a_rows, sh.log_cols);
    tr.absorb(b"M", &v.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    protocol::absorb_root(tr, b"H", &v.h_root, s.h_rows, sh.log_cols);
    let mut side = Side::Verify { slots: v.slots };
    let acc = argument(
        &mut side,
        p,
        &ctx(&lay, blk, alpha, beta, gamma),
        sources,
        tr,
    )?;
    let specs = argument::split::schedule(s)
        .iter()
        .map(argument::SlotSchedule::mask_spec)
        .collect::<Vec<_>>();
    zk::mask_verify_tagged(&v.mask_root, &specs, &acc.fs, v.mask_open, ntt, tr, &tag)
        .map_err(|e| format!("R14 M: {e}"))?;
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(argument::split::sum_claim(p)?);
    let (ag, hg) = groups(p);
    protocol::check_opening(
        &ac,
        sh.log_cols,
        s.a_rows,
        &site_rows(p, false),
        None,
        s.a_rows - 2,
        ag,
        tr,
    )?;
    pcs::verify_zk_tagged(
        &params,
        &zko,
        &Commitment {
            root: v.a_root,
            rows: s.a_rows,
            log_cols: sh.log_cols as u32,
        },
        &ac,
        v.a_open,
        ntt,
        tr,
        &tag,
    )
    .map_err(|e| format!("R14 A: {e}"))?;
    protocol::check_opening(
        &hc,
        sh.log_cols,
        s.h_rows,
        &site_rows(p, true),
        Some(u_rows(p, &lay)?),
        s.h_rows - 2,
        hg,
        tr,
    )?;
    pcs::verify_zk_tagged(
        &params,
        &zko,
        &Commitment {
            root: v.h_root,
            rows: s.h_rows,
            log_cols: sh.log_cols as u32,
        },
        &hc,
        v.h_open,
        ntt,
        tr,
        &tag,
    )
    .map_err(|e| format!("R14 H: {e}"))?;
    Ok([ic, oc])
}
