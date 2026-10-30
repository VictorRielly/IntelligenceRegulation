//! Draft verifier-only R14 capture. This child module reuses only its
//! parent's public serializers/replay helpers. New schema, physical layout.
//! Not active until hooks, three-stage tests and the privacy adapter pass.
use super::*;
use crate::private_block::layout::{Dom, HIds, Ids};
use crate::private_block::split_endpoint::{JointSpec, Kind};
use crate::private_block::split_run;
use crate::private_block::{protocol, split_layout::Part, split_profile::SplitProfile};
pub(crate) const SCHEMA_SPLIT: &str = "hashline-native-capture/6-split-run";

pub(crate) struct Header {
    pub profiles: Vec<SplitProfile>,
    pub block_digests: Vec<Digest>,
    pub plan: Digest,
    pub model: Digest,
    pub context: Digest,
    pub binding: Digest,
    pub input: Digest,
    pub output: Digest,
    pub scales: Vec<(i32, i32)>,
}
pub(crate) struct JointPublic {
    digest: Digest,
    scale: i32,
}
struct Stage {
    k: usize,
    start_tag: Digest,
    end_tag: Option<Digest>,
    boundary: Option<Digest>,
    roots: Option<[Digest; 3]>,
    definition: Option<Transcript>,
    arguments: Vec<Vec<u8>>,
    mask: Option<Vec<u8>>,
    roles: Vec<Vec<u8>>,
    role_names: Vec<&'static str>,
    logup: Vec<Fp2>,
}
struct SplitRecorder {
    header: Header,
    own: Transcript,
    cur: Option<Stage>,
    stages: Vec<Vec<u8>>,
    closed: usize,
    accepted: bool,
    failure: Option<String>,
    store: ArrayStore,
    public_tables: bool,
    sites: Vec<Vec<u8>>,
}
thread_local! { static SPLIT_REC: RefCell<Option<SplitRecorder>> = const {RefCell::new(None)}; }
fn with(f: impl FnOnce(&mut SplitRecorder)) {
    SPLIT_REC.with(|s| {
        if let Some(r) = s.borrow_mut().as_mut() {
            f(r);
        }
    });
}
fn fail(r: &mut SplitRecorder, error: String) {
    if r.failure.is_none() {
        r.failure = Some(error);
    }
}
fn at(r: &mut SplitRecorder, site: &str, tr: &Transcript) {
    if !same_transcript(&r.own, tr) {
        fail(r, format!("R14 capture replay differs at {site}"));
    }
}
fn site(r: &mut SplitRecorder, name: &str, before: &Transcript, after: &Transcript) {
    let mut out = Vec::new();
    write!(out, "{{\"site\":{name:?},").unwrap();
    state(&mut out, "before", before);
    write!(out, ",").unwrap();
    state(&mut out, "after", after);
    write!(out, "}}").unwrap();
    r.sites.push(out);
}
fn seeded(h: &Header) -> Result<Transcript, String> {
    let p = h.profiles.first().ok_or("R14 capture empty run")?;
    let mut tr = Transcript::new_tagged(
        b"hashline/private-block/split-r14/run/v1",
        *p.tag()
            .transcript_key()
            .ok_or("R14 capture unkeyed profile")?,
    );
    tr.absorb(b"R14-run-binding", &h.binding);
    tr.absorb(b"R14-run-plan", &h.plan);
    tr.absorb(b"R14-trained-arithmetic-statement", &h.model);
    tr.absorb(b"R14-public-context", &h.context);
    tr.absorb_u64(b"R14-blocks", h.profiles.len() as u64);
    tr.absorb(b"R14-input", &h.input);
    tr.absorb(b"R14-output", &h.output);
    Ok(tr)
}
pub(crate) fn begin(header: Header) -> Result<(), String> {
    if header.profiles.is_empty()
        || header.profiles.len() > 128
        || header.profiles.len() != header.block_digests.len()
        || header.profiles.len() != header.scales.len()
    {
        return Err("R14 capture header counts".into());
    }
    let own = seeded(&header)?;
    SPLIT_REC.with(|s| {
        let mut slot = s.borrow_mut();
        if slot.is_some() {
            return Err("R14 recorder already attached".into());
        }
        *slot = Some(SplitRecorder {
            header,
            own,
            cur: None,
            stages: vec![],
            closed: 0,
            accepted: false,
            failure: None,
            store: ArrayStore::new(true),
            public_tables: true,
            sites: vec![],
        });
        Ok(())
    })
}
pub(crate) fn checkpoint(tr: &Transcript) -> Option<Transcript> {
    SPLIT_REC.with(|s| s.borrow().is_some().then(|| Transcript::clone_state(tr)))
}
pub(crate) fn seed_matches(tr: &Transcript) -> bool {
    SPLIT_REC.with(|s| {
        s.borrow()
            .as_ref()
            .is_some_and(|r| same_transcript(&r.own, tr))
    })
}
pub(crate) fn start_slot(side: &Side, tr: &Transcript) {
    if !matches!(side, Side::Verify { .. }) {
        return;
    }
    with(|r| {
        at(r, "before R14 definition", tr);
        if let Some(c) = r.cur.as_mut() {
            c.definition = Some(Transcript::clone_state(tr));
        }
    });
}
pub(crate) fn stage_begin(k: usize, boundary: Option<Digest>, before: &Transcript) {
    with(|r| {
        if r.failure.is_some() {
            return;
        }
        if r.cur.is_some()
            || k != r.closed
            || k >= r.header.profiles.len()
            || boundary.is_some() != (k + 1 < r.header.profiles.len())
        {
            fail(r, "R14 capture stage order/boundary".into());
            return;
        }
        at(r, "R14 stage start", before);
        if r.failure.is_some() {
            return;
        }
        let start_tag = split_run::position_tag(&r.own);
        let p = &r.header.profiles[k];
        r.own.absorb_u64(b"R14-stage", k as u64);
        r.own.absorb(b"R14-stage-profile", &p.digest());
        r.own.absorb(b"R14-stage-block", &r.header.block_digests[k]);
        if let Some(root) = boundary {
            let index = k + 1;
            let spec = match JointSpec::new(
                p,
                r.header.plan,
                Kind::Boundary(index as u64),
                r.header.scales[k].1,
            ) {
                Ok(spec) => spec,
                Err(error) => {
                    fail(r, format!("R14 replay joint spec: {error}"));
                    return;
                }
            };
            r.own.absorb_u64(b"R14-boundary-index", index as u64);
            r.own.absorb(b"R14-boundary-spec", &spec.digest());
            protocol::absorb_root(
                &mut r.own,
                b"R14-boundary-root",
                &root,
                spec.rows(),
                spec.params().log_cols as usize,
            );
        }
        r.cur = Some(Stage {
            k,
            start_tag,
            end_tag: None,
            boundary,
            roots: None,
            definition: None,
            arguments: vec![],
            mask: None,
            roles: vec![],
            role_names: vec![],
            logup: vec![],
        });
    });
}
pub(crate) fn core_roots(a: Digest, h: Digest, m: Digest, after: &Transcript) {
    with(|r| {
        if r.failure.is_some() {
            return;
        }
        let Some(cur) = r.cur.as_ref() else {
            fail(r, "R14 roots outside a stage".into());
            return;
        };
        if cur.roots.is_some() {
            fail(r, "R14 duplicate core roots".into());
            return;
        }
        let p = &r.header.profiles[cur.k];
        let s = p.layout();
        protocol::absorb_root(&mut r.own, b"A", &a, s.a_rows, p.base().log_cols);
        r.own.absorb(b"M", &m);
        let logup = r.own.challenge_fp2_vec(3);
        protocol::absorb_root(&mut r.own, b"H", &h, s.h_rows, p.base().log_cols);
        at(r, "R14 core roots/challenges", after);
        let cur = r.cur.as_mut().unwrap();
        cur.roots = Some([a, h, m]);
        cur.logup = logup;
    });
}
fn io_slot(p: &SplitProfile, base: usize, part: Part) -> usize {
    p.layout()
        .slots
        .iter()
        .position(|s| s.base == base && s.part == part)
        .expect("typed R14 IO slot")
}
pub(crate) fn joint_pcs(
    spec: &JointSpec,
    root: Digest,
    claims: &[ZClaim],
    opening: &OpeningZk,
    ntt: &NttTables,
    before: Option<Transcript>,
    after: &Transcript,
) {
    if before.is_none() {
        return;
    }
    let geometry = SPLIT_REC.with(|slot| {
        let r = slot.borrow();
        let r = r.as_ref()?;
        let cur = r.cur.as_ref()?;
        let p = &r.header.profiles[cur.k];
        let sources =
            match spec.kind() {
                Kind::Input => [Part::Wide, Part::Narrow]
                    .into_iter()
                    .map(|part| {
                        (
                            0,
                            io_slot(&r.header.profiles[0], super::super::layout::SC_IO_IN, part),
                            1,
                        )
                    })
                    .collect(),
                Kind::Output => [Part::Wide, Part::Narrow]
                    .into_iter()
                    .map(|part| {
                        (
                            r.header.profiles.len() - 1,
                            io_slot(p, super::super::layout::SC_IO_OUT, part),
                            1,
                        )
                    })
                    .collect(),
                Kind::Boundary(index) => {
                    let index = index as usize;
                    if index != cur.k || index == 0 || index >= r.header.profiles.len() {
                        return None;
                    }
                    [Part::Wide, Part::Narrow]
                        .into_iter()
                        .map(|part| {
                            (
                                index - 1,
                                io_slot(
                                    &r.header.profiles[index - 1],
                                    super::super::layout::SC_IO_OUT,
                                    part,
                                ),
                                1,
                            )
                        })
                        .chain([Part::Wide, Part::Narrow].into_iter().map(|part| {
                            (index, io_slot(p, super::super::layout::SC_IO_IN, part), 1)
                        }))
                        .collect()
                }
            };
        let internal = matches!(spec.kind(), Kind::Boundary(_));
        let data = p.layout().endpoint.data_rows;
        Some(Geom {
            role: if matches!(spec.kind(), Kind::Output) {
                "Output"
            } else {
                "Input"
            },
            commitment_kind: if internal {
                "internal-boundary"
            } else {
                "external-endpoint"
            },
            params: spec.params(),
            root,
            rows: spec.rows(),
            data_rows: data,
            site_rows: (data..data + if internal { 8 } else { 4 }).collect(),
            sum_rows: None,
            prox_row: spec.rows() - 2,
            boundary: if let Kind::Boundary(k) = spec.kind() {
                Some(k as usize)
            } else {
                None
            },
            claim_sources: sources,
        })
    });
    let Some(g) = geometry else {
        with(|r| fail(r, "R14 joint observation has no matching stage/spec".into()));
        return;
    };
    pcs(
        g,
        claims,
        opening,
        ntt,
        before,
        after,
        Some(JointPublic {
            digest: spec.digest(),
            scale: spec.scale(),
        }),
    );
}

// The generator appends the audited verifier-view slot/M/PCS serializers,
// replacing legacy slot metadata with this stage's physical schedule.
#[allow(clippy::too_many_arguments)]
pub(crate) fn slot(
    def: &SlotDef,
    acc: &Acc,
    proof: &SlotProof,
    rho: &[Fp2],
    c: Fp2,
    mask_eval: Fp2,
    before: Option<Transcript>,
    after: &Transcript,
) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
            return;
        }
        let s = def.slot;
        {
            let cur = r.cur.as_ref().expect("an open stage");
            if s != cur.arguments.len() {
                fail(r, format!("replay: slot {s} arrived out of order"));
                return;
            }
        }
        let definition = match r.cur.as_mut().expect("an open stage").definition.take() {
            Some(d) => d,
            None => {
                fail(r, format!("replay: slot {s} has no definition checkpoint"));
                return;
            }
        };
        at(r, &format!("slot {s}'s definition"), &definition);
        if r.failure.is_some() {
            return;
        }
        // The definition code only DRAWS Fp2 challenges; replay to its exact
        // endpoint. A definition that ever absorbed would run away and be
        // refused here rather than mis-recorded.
        let mut draws = Vec::new();
        while !same_transcript(&r.own, &before) {
            if draws.len() >= 256 {
                fail(
                    r,
                    format!("replay: slot {s}'s definition changed its transcript operations"),
                );
                return;
            }
            draws.push(r.own.challenge_fp2());
        }
        let (n, ext, degree, name, kind) = {
            let k = r.cur.as_ref().unwrap().k;
            let m = &r.header.profiles[k].layout().slots[s];
            (
                m.main,
                m.ext,
                m.degree,
                format!("R14 {} {:?}", SLOT_NAMES[m.base], m.part),
                SLOT_KINDS[m.base],
            )
        };
        r.own.absorb_u64(b"pb-slot", s as u64);
        let c_own = r.own.challenge_fp2();
        if c_own != c {
            fail(
                r,
                format!("replay: slot {s}'s CFS challenge is not the verifier's"),
            );
            return;
        }
        r.own.absorb_fp2(b"pb-scalar", &[proof.scalar]);
        let claimed = def.hosted.iter().fold(proof.scalar, |v, (hs, coef)| {
            v.add(coef.mul(acc.scalars[*hs]))
        });
        let (fin, replay_rho) =
            match sumcheck::verify(claimed, degree, n + ext, &proof.sc, &mut r.own) {
                Ok(v) => v,
                Err(e) => {
                    fail(
                        r,
                        format!("replay: slot {s}'s sumcheck does not replay: {e}"),
                    );
                    return;
                }
            };
        if replay_rho != rho {
            fail(
                r,
                format!("replay: slot {s}'s sumcheck challenges are not the verifier's"),
            );
            return;
        }
        r.own.absorb_fp2(b"pb-term", &proof.terms);
        at(r, &format!("the end of slot {s}"), after);
        if r.failure.is_some() {
            return;
        }
        // Physical sources are recorded verbatim below; the profile carries
        // their complete physical extent/offset/component index. Native
        // acceptance and the separate source-map tests remain prerequisites.
        let mut out = Vec::new();
        write!(
            out,
            "{{\"slot\":{s},\"name\":{:?},\"kind\":\"{:?}\",\"main\":{n},\"extension\":{ext},\"degree\":{degree},\"definition_challenges\":{:?},\"c\":{:?},\"scalar\":{:?},\"claimed_sum\":{:?},\"rho\":{:?},\"sumcheck_final\":{:?},\"mask_eval\":{:?},\"terminal_polynomial\":{:?},\"terminals\":{:?},\"rounds\":{:?},\"hosted\":[",
            name,
            kind,
            fp2s(&draws),
            fp2(c),
            fp2(proof.scalar),
            fp2(claimed),
            fp2s(rho),
            fp2(fin),
            fp2(mask_eval),
            fp2(fin.sub(c.mul(mask_eval))),
            fp2s(&proof.terms),
            proof.sc.rounds.iter().map(|x| fp2s(x)).collect::<Vec<_>>()
        )
        .expect("write to a Vec");
        for (i, (hs, coefficient)) in def.hosted.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(
                out,
                "{{\"slot\":{hs},\"coefficient\":{:?}}}",
                fp2(*coefficient)
            )
            .expect("write to a Vec");
        }
        write!(out, "],\"tables\":[").expect("write to a Vec");
        let public_tables = r.public_tables;
        let mut counts = [0usize; 4];
        for t in &def.tabs {
            if let Tab::Priv(v) = t {
                counts[v.cm as usize] += 1;
            }
        }
        let mut indices = std::array::from_fn::<_, 4, _>(|i| acc.claims[i].len() - counts[i]);
        for (i, table) in def.tabs.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            match table {
                Tab::Eq { point, start } => write!(
                    out,
                    "{{\"kind\":\"eq\",\"start\":{start},\"point\":{:?}}}",
                    fp2s(point)
                )
                .expect("write to a Vec"),
                Tab::Pub(v) => write_public_table(&mut out, &mut r.store, v, public_tables),
                Tab::Priv(v) => {
                    let role = ["A", "H", "Input", "Output"][v.cm as usize];
                    let ci = &mut indices[v.cm as usize];
                    write!(out, "{{\"kind\":\"private\",\"role\":{role:?},\"claim\":{ci},\"log_size\":{},\"mask_row\":{},\"extension_round\":{},\"slices\":[", v.log, v.mask_row, v.ext_round).expect("write to a Vec");
                    *ci += 1;
                    for (j, (offset, coefficient)) in v.slices.iter().enumerate() {
                        if j > 0 {
                            write!(out, ",").expect("write to a Vec");
                        }
                        write!(
                            out,
                            "{{\"offset\":{offset},\"coefficient\":{:?}}}",
                            fp2(*coefficient)
                        )
                        .expect("write to a Vec");
                    }
                    write!(out, "],\"coordinates\":[").expect("write to a Vec");
                    for (j, coord) in v.coords.iter().enumerate() {
                        if j > 0 {
                            write!(out, ",").expect("write to a Vec");
                        }
                        match coord {
                            Coord::Rho(k) => {
                                write!(out, "{{\"rho\":{k}}}").expect("write to a Vec")
                            }
                            Coord::Flip(k) => {
                                write!(out, "{{\"flip\":{k}}}").expect("write to a Vec")
                            }
                            Coord::Fixed(x) => {
                                write!(out, "{{\"fixed\":{:?}}}", fp2(*x)).expect("write to a Vec")
                            }
                        }
                    }
                    write!(out, "]}}").expect("write to a Vec");
                }
            }
        }
        write!(out, "],").expect("write to a Vec");
        state(&mut out, "before_definition", &definition);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "before", &before);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "after", after);
        write!(out, "}}").expect("write to a Vec");
        let k = r.cur.as_ref().expect("an open stage").k;
        site(r, &format!("slot {s:02}"), &definition, after);
        let _ = k;
        r.cur.as_mut().expect("an open stage").arguments.push(out);
    });
}

pub(crate) fn mask(
    specs: &[(usize, usize)],
    root: &Digest,
    fs: &[MaskFunctional],
    op: &MaskOpening,
    ntt: &NttTables,
    before: Option<Transcript>,
    after: &Transcript,
) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
            return;
        }
        at(r, "the M opening", &before);
        if r.failure.is_some() {
            return;
        }
        let theta = Transcript::clone_state(&r.own).challenge_fp2();
        let rhos = {
            let mut t = Transcript::clone_state(&r.own);
            let _ = t.challenge_fp2();
            t.absorb_fp2(b"mask-q", &op.q);
            t.challenge_fp2_vec(2 * specs.len() + 2)
        };
        let tag = r.header.profiles[r.cur.as_ref().unwrap().k].tag();
        if let Err(e) = crate::zk::mask_verify_tagged(root, specs, fs, op, ntt, &mut r.own, &tag) {
            fail(r, format!("replay: the M opening does not replay: {e}"));
            return;
        }
        at(r, "the end of the M opening", after);
        if r.failure.is_some() {
            return;
        }
        let mut out = Vec::new();
        write!(out, "{{\"root\":{root:?},\"specs\":{:?},\"rows\":{},\"theta\":{:?},\"proximity_rhos\":{:?},", specs.iter().map(|&(n, d)| [n, d]).collect::<Vec<_>>(), 2 * specs.len() + 4, fp2(theta), fp2s(&rhos)).expect("write to a Vec");
        state(&mut out, "before", &before);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "after", after);
        write!(out, ",\"functionals\":[").expect("write to a Vec");
        for (i, f) in fs.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(out, "{{\"value\":{:?},\"terms\":[", fp2(f.value)).expect("write to a Vec");
            for (j, (s, weights)) in f.terms.iter().enumerate() {
                if j > 0 {
                    write!(out, ",").expect("write to a Vec");
                }
                write!(out, "{{\"slot\":{s},\"weights\":{:?}}}", fp2s(weights))
                    .expect("write to a Vec");
            }
            write!(out, "]}}").expect("write to a Vec");
        }
        write!(out, "],\"q\":").expect("write to a Vec");
        fp2_array(&mut out, &mut r.store, &op.q);
        write!(out, ",\"prox\":").expect("write to a Vec");
        fp2_array(&mut out, &mut r.store, &op.prox);
        write!(out, ",\"columns\":").expect("write to a Vec");
        columns(&mut out, &mut r.store, &op.columns);
        write!(out, "}}").expect("write to a Vec");
        site(r, "M opening", &before, after);
        let cur = r.cur.as_mut().expect("an open stage");
        if cur.mask.replace(out).is_some() {
            fail(r, "replay: two M openings in one stage".into());
        }
    });
}

pub(crate) fn pcs(
    g: Geom,
    claims: &[ZClaim],
    opening: &OpeningZk,
    ntt: &NttTables,
    before: Option<Transcript>,
    after: &Transcript,
    joint: Option<JointPublic>,
) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
            return;
        }
        at(r, &format!("the {} opening", g.role), &before);
        if r.failure.is_some() {
            return;
        }
        let cm = Commitment {
            root: g.root,
            rows: g.rows,
            log_cols: g.params.log_cols,
        };
        let replayed = match replay(&g.params, &cm, claims, opening, &before) {
            Ok(v) => v,
            Err(e) => {
                fail(
                    r,
                    format!("replay: the {} opening does not replay: {e}", g.role),
                );
                return;
            }
        };
        let tag = r.header.profiles[r.cur.as_ref().unwrap().k].tag();
        if let Err(e) = pcs::verify_zk_tagged(
            &g.params,
            &ZkOpts::standard(&g.params),
            &cm,
            claims,
            opening,
            ntt,
            &mut r.own,
            &tag,
        ) {
            fail(
                r,
                format!(
                    "replay: the {} opening does not verify on the recorder's transcript: {e}",
                    g.role
                ),
            );
            return;
        }
        at(r, &format!("the end of the {} opening", g.role), after);
        if r.failure.is_some() {
            return;
        }
        let mut out = Vec::new();
        write_pcs(
            &mut out,
            &mut r.store,
            &g,
            claims,
            opening,
            &replayed,
            &before,
            after,
        );
        if let Some(joint) = joint {
            let mut decorated = Vec::new();
            write!(
                decorated,
                "{{\"joint_spec_digest\":{:?},\"scale\":{},",
                joint.digest, joint.scale
            )
            .unwrap();
            decorated.extend_from_slice(&out[1..]);
            out = decorated;
        }
        site(r, &format!("{} opening", g.role), &before, after);
        let cur = r.cur.as_mut().expect("an open stage");
        cur.roles.push(out);
        cur.role_names.push(g.role);
    });
}

fn write_stage(r: &SplitRecorder, c: &Stage, receipt: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    let roots = c.roots.expect("checked accepted roots");
    write!(out,"{{\"schema\":{SCHEMA_SPLIT:?},\"stage\":{},\"start_tag\":{:?},\"end_tag\":{:?},\"boundary\":{},\"a_root\":{:?},\"h_root\":{:?},\"mask_root\":{:?},\"logup\":{:?},\"arguments\":[",c.k,c.start_tag,c.end_tag.unwrap(),c.boundary.map(|v|format!("{v:?}")).unwrap_or("null".into()),roots[0],roots[1],roots[2],fp2s(&c.logup)).unwrap();
    for (i, item) in c.arguments.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        out.extend_from_slice(item);
    }
    let digest = crate::private_block::trained_block::hex(
        &crate::private_block::trained_block::sha256(receipt),
    );
    write!(
        out,
        "],\"receipt_bytes\":{},\"receipt_sha256\":{:?},\"mask\":",
        receipt.len(),
        digest
    )
    .unwrap();
    out.extend_from_slice(c.mask.as_ref().unwrap());
    write!(out, ",\"roles\":[").unwrap();
    for (i, item) in c.roles.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        out.extend_from_slice(item);
    }
    write!(out, "]}}").unwrap();
    let _ = r;
    out
}
pub(crate) fn stage_end(k: usize, end: Digest, tr: &Transcript, receipt: &[u8]) {
    with(|r| {
        if r.failure.is_some() {
            return;
        }
        at(r, "R14 stage end", tr);
        if r.failure.is_some() {
            return;
        }
        let Some(mut cur) = r.cur.take() else {
            fail(r, "R14 stage end without stage".into());
            return;
        };
        if cur.k != k
            || cur.arguments.len() != r.header.profiles[k].layout().slots.len()
            || cur.roots.is_none()
            || cur.mask.is_none()
            || cur.definition.is_some()
            || cur.role_names
                != if k + 1 == r.header.profiles.len() {
                    vec!["A", "H", "Input", "Output"]
                } else {
                    vec!["A", "H", "Input"]
                }
            || split_run::position_tag(&r.own) != end
        {
            fail(r, "R14 incomplete/mismatched stage capture".into());
            return;
        }
        cur.end_tag = Some(end);
        let json = write_stage(r, &cur, receipt);
        r.stages.push(json);
        r.closed += 1;
    });
}
pub(crate) fn run_accepted() {
    with(|r| {
        if r.failure.is_none() && r.closed == r.header.profiles.len() && r.cur.is_none() {
            r.accepted = true;
        } else {
            fail(r, "R14 finish without complete accepted capture".into());
        }
    });
}
pub(crate) fn discard() {
    SPLIT_REC.with(|s| *s.borrow_mut() = None);
}
#[derive(Debug)]
pub(crate) struct SplitBundle {
    pub run_json: Vec<u8>,
    pub stages: Vec<Vec<u8>>,
    pub arrays: Vec<u8>,
}
pub(crate) fn take() -> Result<SplitBundle, String> {
    let mut r = SPLIT_REC
        .with(|s| s.borrow_mut().take())
        .ok_or("no R14 recorder attached")?;
    if let Some(error) = r.failure.take() {
        return Err(error);
    }
    if !r.accepted || r.cur.is_some() || r.closed != r.header.profiles.len() {
        return Err("R14 no bundle for unaccepted/incomplete run".into());
    }
    let mut out = Vec::new();
    write!(out,"{{\"schema\":{SCHEMA_SPLIT:?},\"kind\":\"R14 native verifier observations\",\"blocks\":{},\"binding\":{:?},\"plan\":{:?},\"model\":{:?},\"context\":{:?},\"input_root\":{:?},\"output_root\":{:?},\"scales\":{:?},\"profiles\":[",r.closed,r.header.binding,r.header.plan,r.header.model,r.header.context,r.header.input,r.header.output,r.header.scales.iter().map(|&(a,b)|[a,b]).collect::<Vec<_>>()).unwrap();
    // Add all public block digests explicitly; the replay consumes them.
    for (i, p) in r.header.profiles.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        write_profile(&mut out, p);
    }
    write!(
        out,
        "],\"block_digests\":{:?},\"fully_verified\":true,\"sites\":[",
        r.header.block_digests
    )
    .unwrap();
    for (i, item) in r.sites.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        out.extend_from_slice(item);
    }
    write!(out, "],\"source_pins\":[").unwrap();
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap();
    for (i, name) in SOURCE_FILES.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        let bytes = std::fs::read(root.join(name))
            .map_err(|e| format!("R14 capture source {name}: {e}"))?;
        write!(
            out,
            "{{\"file\":{name:?},\"sha256\":{:?}}}",
            crate::private_block::trained_block::hex(&crate::private_block::trained_block::sha256(
                &bytes
            ))
        )
        .unwrap();
    }
    write!(out, "]}}").unwrap();
    Ok(SplitBundle {
        run_json: out,
        stages: r.stages,
        arrays: r.store.blob().to_vec(),
    })
}
fn h_plane_name(sh: &Shape, ids: &HIds, parent: usize) -> String {
    for dom in [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Dd] {
        for k in 0..sh.helpers(dom) {
            if ids.helper(dom, k) == parent {
                return format!("H_{dom:?}{k}");
            }
        }
    }
    let table = ids.table_helpers();
    for (id, name) in [
        (ids.sexp(), "H_SEXP"),
        (ids.fact(), "H_FACT"),
        (table[0], "H_GU8"),
        (table[1], "H_GEXP"),
        (table[2], "H_GACT"),
        (ids.u(), "H_U"),
    ] {
        if parent == id {
            return name.into();
        }
    }
    if sh.dd_cap > 0 {
        if parent == ids.stuple() {
            return "H_STUPLE".into();
        }
        if parent == ids.gdd() {
            return "H_GDD".into();
        }
    }
    panic!("R14 capture unnamed H parent {parent}")
}
fn write_profile(out: &mut Vec<u8>, p: &SplitProfile) {
    let b = p.base();
    let s = p.layout();
    let ids = Ids::new(b).expect("R14 A roles");
    let names = &ids.accuracy().expect("R14 accuracy roles").names;
    let hids = HIds::new(b).expect("R14 H roles");
    write!(out,"{{\"profile\":{:?},\"descriptor\":{:?},\"arithmetic_reference\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"q_pad\":{},\"t_pad\":{},\"d_pad\":{},\"f_pad\":{},\"N\":{},\"a_rows\":{},\"h_rows\":{},\"m_rows\":{},\"external_rows\":{},\"internal_rows\":{},\"physical_planes\":[",p.name(),p.digest(),b.profile,b.tokens,b.width,b.hidden,b.q_heads,b.kv_heads,b.head_dim,b.q_pad(),b.t_pad,b.d_pad,b.f_pad,s.n,s.a_rows,s.h_rows,s.m_rows,s.endpoint.external_rows,s.endpoint.internal_rows).unwrap();
    let mut first = true;
    for (h, planes) in [(false, &s.a), (true, &s.h)] {
        for (i, v) in planes.iter().enumerate() {
            if !first {
                write!(out, ",").unwrap();
            }
            first = false;
            let name = if h {
                h_plane_name(b, &hids, v.parent)
            } else {
                format!("A_{}", names[v.parent])
            };
            let extent = match v.domain {
                Dom::D => Some(s.d),
                Dom::F => Some(s.f),
                _ => None,
            };
            let extent = extent.map(|pieces| {
                pieces[match v.part {
                    Part::Wide => 0,
                    Part::Narrow => 1,
                    Part::Whole => panic!("unsplit D/F capture plane"),
                }]
            });
            let start = extent.map(|e| e.start.to_string()).unwrap_or("null".into());
            let width = extent.map(|e| e.width.to_string()).unwrap_or("null".into());
            write!(out,"{{\"cm\":{},\"physical\":{},\"parent\":{},\"name\":{:?},\"domain\":{:?},\"part\":{:?},\"offset\":{},\"log\":{},\"rows_per_component\":{},\"components\":{},\"global_feature_start\":{},\"global_feature_width\":{}}}",usize::from(h),i,v.parent,name,format!("{:?}",v.domain),format!("{:?}",v.part),v.offset,v.log,v.rows_per_component,if h {2}else{1},start,width).unwrap();
        }
    }
    write!(out, "],\"slots\":[").unwrap();
    for (i, m) in s.slots.iter().enumerate() {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        write!(out,"{{\"slot\":{i},\"base\":{},\"part\":{:?},\"main\":{},\"extension\":{},\"degree\":{},\"a_pairs\":{:?},\"h_pairs\":{:?}}}",m.base,format!("{:?}",m.part),m.main,m.ext,m.degree,m.a_pairs,m.h_pairs).unwrap();
    }
    write!(out,"],\"joint_piece_offsets\":{:?},\"joint_piece_logs\":{:?},\"joint_data_rows\":{},\"calibration\":{{\"norm_tn\":{},\"cn_a\":{},\"cn_m\":{},\"ceps\":{},\"d_max\":{},\"f_e\":{},\"f_p\":{},\"shifts\":{:?},\"gate_shift\":{}}}}}",s.endpoint.piece_offsets,s.endpoint.piece_logs,s.endpoint.data_rows,b.norm_tn,b.norm_cn_a,b.norm_cn_m,b.norm_ceps,b.d_max,b.f_e,b.f_p(),[b.sh_ao,b.sh_qkv,b.sh_s,b.sh_o,b.sh_g,b.sh_h,b.sh_z],b.accuracy_gate_shift).unwrap();
}
const SOURCE_FILES: &[&str] = &[
    "hashline/Cargo.lock",
    "hashline/Cargo.toml",
    "hashline/examples/zk60_block_receipt.rs",
    "hashline/examples/zk60_bound_ffn.rs",
    "hashline/examples/zk60_chain_receipt.rs",
    "hashline/examples/zk60_fresh_ffn.rs",
    "hashline/examples/zk60_kernel_fixture.rs",
    "hashline/examples/zk60_private_attention.rs",
    "hashline/examples/zk60_private_block.rs",
    "hashline/examples/zk60_private_stack.rs",
    "hashline/examples/zk60_repaired_mask_probe.rs",
    "hashline/examples/zk60_seam_receipt.rs",
    "hashline/examples/zk60_split_stack.rs",
    "hashline/examples/zk60_tied_tables.rs",
    "hashline/examples/zk60_trained_block.rs",
    "hashline/examples/zk60_witness_bench.rs",
    "hashline/src/attention.rs",
    "hashline/src/attention_schedule.rs",
    "hashline/src/bin/hashline.rs",
    "hashline/src/causal_oracle.rs",
    "hashline/src/chain.rs",
    "hashline/src/export.rs",
    "hashline/src/export_v3.rs",
    "hashline/src/field.rs",
    "hashline/src/field/verifier_hardening_tests.rs",
    "hashline/src/gpu/cuda.rs",
    "hashline/src/gpu/kernels.cu",
    "hashline/src/gpu/mod.rs",
    "hashline/src/layer.rs",
    "hashline/src/lib.rs",
    "hashline/src/merkle.rs",
    "hashline/src/mle.rs",
    "hashline/src/model_identity.rs",
    "hashline/src/native_capture.rs",
    "hashline/src/norm.rs",
    "hashline/src/ntt.rs",
    "hashline/src/pcs.rs",
    "hashline/src/pcs_compact.rs",
    "hashline/src/phase_profile.rs",
    "hashline/src/private_attention.rs",
    "hashline/src/private_attention/argument.rs",
    "hashline/src/private_attention/layout.rs",
    "hashline/src/private_attention/protocol.rs",
    "hashline/src/private_attention/tests.rs",
    "hashline/src/private_attention/wire.rs",
    "hashline/src/private_attention/witness.rs",
    "hashline/src/private_block.rs",
    "hashline/src/private_block/accuracy.rs",
    "hashline/src/private_block/accuracy_act.rs",
    "hashline/src/private_block/accuracy_aligned.rs",
    "hashline/src/private_block/accuracy_binding_tests.rs",
    "hashline/src/private_block/accuracy_fold.rs",
    "hashline/src/private_block/accuracy_groups.rs",
    "hashline/src/private_block/accuracy_layout.rs",
    "hashline/src/private_block/accuracy_layout_tests.rs",
    "hashline/src/private_block/accuracy_precision.rs",
    "hashline/src/private_block/accuracy_profile_tests.rs",
    "hashline/src/private_block/accuracy_proof_tests.rs",
    "hashline/src/private_block/accuracy_public.rs",
    "hashline/src/private_block/accuracy_tables.rs",
    "hashline/src/private_block/argument.rs",
    "hashline/src/private_block/argument_accuracy.rs",
    "hashline/src/private_block/argument_split.rs",
    "hashline/src/private_block/boundary.rs",
    "hashline/src/private_block/c6_tests.rs",
    "hashline/src/private_block/cs_port_tests.rs",
    "hashline/src/private_block/dense_tests.rs",
    "hashline/src/private_block/e32_tests.rs",
    "hashline/src/private_block/endpoint_g.rs",
    "hashline/src/private_block/grow_tests.rs",
    "hashline/src/private_block/hash_domain.rs",
    "hashline/src/private_block/hash_domain_tests.rs",
    "hashline/src/private_block/hash_tag_tests.rs",
    "hashline/src/private_block/k4_tests.rs",
    "hashline/src/private_block/ladder8b_tests.rs",
    "hashline/src/private_block/lane_c_tinyllama_tests.rs",
    "hashline/src/private_block/layout.rs",
    "hashline/src/private_block/mvp_driver.rs",
    "hashline/src/private_block/norm_alias.rs",
    "hashline/src/private_block/p2_tests.rs",
    "hashline/src/private_block/pad.rs",
    "hashline/src/private_block/parity.rs",
    "hashline/src/private_block/plane_index.rs",
    "hashline/src/private_block/protocol.rs",
    "hashline/src/private_block/r12_golden_tests.rs",
    "hashline/src/private_block/r12_tests.rs",
    "hashline/src/private_block/r12b_tests.rs",
    "hashline/src/private_block/r13_vectors/block_fixture.json",
    "hashline/src/private_block/r13_vectors/block_fixture_t32.json",
    "hashline/src/private_block/r13_vectors/block_fixture_t32.tsv",
    "hashline/src/private_block/r13_vectors/block_trace_low.json",
    "hashline/src/private_block/r13_vectors/block_trace_low_h24.json",
    "hashline/src/private_block/r13_vectors/block_trace_low_h24_t32.json",
    "hashline/src/private_block/r13_vectors/block_trace_low_h24_t32.tsv",
    "hashline/src/private_block/r13_vectors/block_trace_low_t32.json",
    "hashline/src/private_block/r13_vectors/block_trace_low_t32.tsv",
    "hashline/src/private_block/r13_vectors/r13_product_low_vectors.tsv",
    "hashline/src/private_block/r13_vectors/r13_product_vectors.tsv",
    "hashline/src/private_block/r13_vectors/r13_requant_vectors.tsv",
    "hashline/src/private_block/r13_vectors/roles.tsv",
    "hashline/src/private_block/r13_vectors/shieldstral_product_vectors.tsv",
    "hashline/src/private_block/r13_vectors/silu_-1_-10.bin",
    "hashline/src/private_block/r13_vectors/silu_-1_-11.bin",
    "hashline/src/private_block/r13_vectors/silu_-1_-9.bin",
    "hashline/src/private_block/r13_vectors/silu_-2_-11.bin",
    "hashline/src/private_block/r13_vectors/silu_-3_-11.bin",
    "hashline/src/private_block/r13_vectors/silu_-3_-12.bin",
    "hashline/src/private_block/r13_vectors/silu_-4_-12.bin",
    "hashline/src/private_block/r13_vectors/silu_-4_-13.bin",
    "hashline/src/private_block/r13_vectors/silu_-5_-13.bin",
    "hashline/src/private_block/r13_vectors/silu_0_-8.bin",
    "hashline/src/private_block/r4_tests.rs",
    "hashline/src/private_block/r6_tests.rs",
    "hashline/src/private_block/r8_tests.rs",
    "hashline/src/private_block/r9_golden_tests.rs",
    "hashline/src/private_block/r9_tests.rs",
    "hashline/src/private_block/refusals.rs",
    "hashline/src/private_block/review_d24_tests.rs",
    "hashline/src/private_block/review_tests.rs",
    "hashline/src/private_block/rope.rs",
    "hashline/src/private_block/rulings_tests.rs",
    "hashline/src/private_block/run.rs",
    "hashline/src/private_block/run_capture.rs",
    "hashline/src/private_block/run_capture_tests.rs",
    "hashline/src/private_block/run_sink.rs",
    "hashline/src/private_block/run_statement_file.rs",
    "hashline/src/private_block/run_tests.rs",
    "hashline/src/private_block/rung_tests.rs",
    "hashline/src/private_block/s20_review_tests.rs",
    "hashline/src/private_block/s23_tests.rs",
    "hashline/src/private_block/s24_tests.rs",
    "hashline/src/private_block/s25_tests.rs",
    "hashline/src/private_block/s26_tests.rs",
    "hashline/src/private_block/s28_review_tests.rs",
    "hashline/src/private_block/s28_tests.rs",
    "hashline/src/private_block/s29_tests.rs",
    "hashline/src/private_block/s33_tests.rs",
    "hashline/src/private_block/s35_tests.rs",
    "hashline/src/private_block/shape.rs",
    "hashline/src/private_block/slot_ir.rs",
    "hashline/src/private_block/slot_ir_tests.rs",
    "hashline/src/private_block/source_audit.rs",
    "hashline/src/private_block/split_actual_tests.rs",
    "hashline/src/private_block/split_attack_tests.rs",
    "hashline/src/private_block/split_capture.rs",
    "hashline/src/private_block/split_capture_tests.rs",
    "hashline/src/private_block/split_cfs_tests.rs",
    "hashline/src/private_block/split_definition_tests.rs",
    "hashline/src/private_block/split_dense_tests.rs",
    "hashline/src/private_block/split_endpoint.rs",
    "hashline/src/private_block/split_geometry.rs",
    "hashline/src/private_block/split_l25_tests.rs",
    "hashline/src/private_block/split_layout.rs",
    "hashline/src/private_block/split_profile.rs",
    "hashline/src/private_block/split_protocol.rs",
    "hashline/src/private_block/split_run.rs",
    "hashline/src/private_block/split_run_tests.rs",
    "hashline/src/private_block/split_streaming_tests.rs",
    "hashline/src/private_block/split_wire.rs",
    "hashline/src/private_block/split_witness.rs",
    "hashline/src/private_block/tamper.rs",
    "hashline/src/private_block/tests.rs",
    "hashline/src/private_block/tied_tables.rs",
    "hashline/src/private_block/tied_tables/derive.rs",
    "hashline/src/private_block/timing.rs",
    "hashline/src/private_block/trained_accuracy.rs",
    "hashline/src/private_block/trained_block.rs",
    "hashline/src/private_block/trained_block_tests.rs",
    "hashline/src/private_block/trained_calib_tests.rs",
    "hashline/src/private_block/trained_split.rs",
    "hashline/src/private_block/trained_stack_tests.rs",
    "hashline/src/private_block/trained_statement.rs",
    "hashline/src/private_block/w14_tests.rs",
    "hashline/src/private_block/wire.rs",
    "hashline/src/private_block/witness.rs",
    "hashline/src/private_block/witness_accuracy.rs",
    "hashline/src/private_block/witness_speed_tests.rs",
    "hashline/src/private_block/zero_witness_tests.rs",
    "hashline/src/private_block_contract.rs",
    "hashline/src/private_seam.rs",
    "hashline/src/public_block_oracle.rs",
    "hashline/src/public_block_receipt.rs",
    "hashline/src/public_block_wire.rs",
    "hashline/src/public_chain_receipt.rs",
    "hashline/src/silu.rs",
    "hashline/src/stable_weight_material.rs",
    "hashline/src/stable_weight_material_tests.rs",
    "hashline/src/stable_weight_registration.rs",
    "hashline/src/stable_weight_registration_tests.rs",
    "hashline/src/stable_weight_slots.rs",
    "hashline/src/stable_weight_slots_tests.rs",
    "hashline/src/sumcheck.rs",
    "hashline/src/tables_attn.rs",
    "hashline/src/tables_v3.rs",
    "hashline/src/transcript.rs",
    "hashline/src/wcache.rs",
    "hashline/src/wcache_atomic_tests.rs",
    "hashline/src/zk.rs",
    "hashline/src/zk_cfs_safety_tests.rs",
    "hashline/src/zk_ffn_fresh_io.rs",
    "hashline/src/zk_ffn_fresh_io_tests.rs",
    "hashline/src/zk_ffn_fresh_poc.rs",
    "hashline/src/zk_ffn_fresh_poc_tests.rs",
    "hashline/src/zk_ffn_fresh_wire.rs",
    "hashline/src/zk_ffn_io_diagnostic.rs",
    "hashline/src/zk_ffn_mask_diagnostic.rs",
    "hashline/src/zk_ffn_observation_json.rs",
    "hashline/src/zk_mr1_probe_tests.rs",
    "hashline/src/zk_proof_size.rs",
    "hashline/src/zk_rounds_tests.rs",
    "hashline/tests/cli_claims.rs",
    "hashline/tests/zk60_attention_schedule.rs",
    "hashline/tests/zk60_block_contract.rs",
    "hashline/tests/zk60_cl20_codec.rs",
    "hashline/tests/zk60_endpoint_hash_boundary.rs",
    "hashline/tests/zk60_fable_arith.rs",
    "hashline/tests/zk60_fable_cfs_channel.rs",
    "hashline/tests/zk60_gpu_cache.rs",
    "hashline/tests/zk60_gpu_commit.rs",
    "hashline/tests/zk60_identity_gap.rs",
    "hashline/tests/zk60_mask_rank.rs",
    "hashline/tests/zk60_memory_layout.rs",
    "hashline/tests/zk60_model_identity.rs",
    "hashline/tests/zk60_pending_layout.rs",
    "hashline/tests/zk60_phase_profile.rs",
    "hashline/tests/zk60_private_attention.rs",
    "hashline/tests/zk60_private_block.rs",
    "hashline/tests/zk60_private_seam.rs",
    "hashline/tests/zk60_proof_size.rs",
    "hashline/tests/zk60_public_block.rs",
    "hashline/tests/zk60_public_chain.rs",
    "hashline/tests/zk60_public_receipt.rs",
    "hashline/tests/zk60_public_wire.rs",
    "hashline/tests/zk60_sequence_equivalence.rs",
    "hashline/tests/zk60_stable_weight_slots.rs",
    "hashline/tests/zk60_tagged_gpu_commit.rs",
    "private-block-kernel-shaped/Cargo.lock",
    "private-block-kernel-shaped/Cargo.toml",
    "private-block-kernel-shaped/src/lib.rs",
    "private-block-kernel-shaped/src/tests.rs",
    "private-block-kernel/Cargo.toml",
    "private-block-kernel/src/lib.rs",
    "private-block-kernel/src/tests.rs",
    "private-block-kernel/tests/fixture_parity.rs",
    "results/zk60_attention_integration_20260919/block_public/block_expected.bin",
    "results/zk60_attention_integration_20260919/block_public/block_receipt.bin",
    "results/zk60_block125m_lane/m125-run-l12-dense-run-statement.json",
    "results/zk60_block125m_lane/m125-run-l12-tagged-run-statement.json",
    "results/zk60_block125m_lane/x34-slot-ir/drafter_inventory.tsv",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_m125.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_c6.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_e32.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_g.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_k4.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_p2.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_rung_w14.json",
    "results/zk60_block125m_lane/x34-slot-ir/slot_ir_toy.json",
    "results/zk60_private_block_evidence/owner_run1/block_expected.bin",
    "results/zk60_private_block_evidence/owner_run1/block_receipt.bin",
    "results/zk60_rowfold_20260919/integration/native-block-0/block_expected.bin",
    "results/zk60_rowfold_20260919/integration/native-block-0/block_receipt.bin",
    "results/zk60_rowfold_20260919/integration/native-block-1/block_expected.bin",
    "results/zk60_rowfold_20260919/integration/native-block-1/block_receipt.bin",
    "zkp-core/Cargo.lock",
    "zkp-core/Cargo.toml",
    "zkp-core/examples/public_sumcheck.rs",
    "zkp-core/examples/row_fold_bench.rs",
    "zkp-core/src/ffn_v3/mod.rs",
    "zkp-core/src/ffn_v3/proof.rs",
    "zkp-core/src/ffn_v3/statement.rs",
    "zkp-core/src/field.rs",
    "zkp-core/src/hashtag.rs",
    "zkp-core/src/lib.rs",
    "zkp-core/src/merkle.rs",
    "zkp-core/src/mle.rs",
    "zkp-core/src/ntt.rs",
    "zkp-core/src/pcs.rs",
    "zkp-core/src/pcs/backend.rs",
    "zkp-core/src/pcs/encode_buffer.rs",
    "zkp-core/src/pcs/encode_buffer/tests.rs",
    "zkp-core/src/pcs/encode_conformance_tests.rs",
    "zkp-core/src/rng.rs",
    "zkp-core/src/sumcheck.rs",
    "zkp-core/src/sumcheck/grouped.rs",
    "zkp-core/src/sumcheck/grouped/tests.rs",
    "zkp-core/src/sumcheck/rounds.rs",
    "zkp-core/src/sumcheck/rounds/tests.rs",
    "zkp-core/src/tables.rs",
    "zkp-core/src/transcript.rs",
    "zkp-core/tests/endpoint_reuse.rs",
];
