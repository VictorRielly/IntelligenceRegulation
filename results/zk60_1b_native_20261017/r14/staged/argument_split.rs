//! R14 physical argument builders. The outer protocol must bind this layout
//! and schedule in a new profile; this module does not activate one.
use super::*;
use crate::pcs::ZClaim;
use crate::private_block::accuracy_fold::{self, Axis, Site};
use crate::private_block::split_endpoint::{IoSources, Kind, Use};
use crate::private_block::split_geometry as geometry;
use crate::private_block::split_layout::{Extent, Part, SplitLayout};
use crate::private_block::split_profile::SplitProfile;

#[derive(Clone, Copy)]
pub(super) struct View<'a> {
    pub layout: &'a SplitLayout,
    pub physical: usize,
}

impl View<'_> {
    fn slot(&self) -> &crate::private_block::split_layout::Slot {
        &self.layout.slots[self.physical]
    }
    fn part(&self, dom: Dom) -> Part {
        if matches!(dom, Dom::D | Dom::F) {
            self.slot().part
        } else {
            Part::Whole
        }
    }
    pub(super) fn a_log(&self, lay: &Layout, parent: usize) -> Result<usize, String> {
        Ok(self
            .layout
            .plane(false, parent, self.part(lay.ids().dom(parent)))?
            .log)
    }
    pub(super) fn a_offset(&self, lay: &Layout, old: usize, log: usize) -> Result<usize, String> {
        let parent = lay
            .a_off
            .iter()
            .enumerate()
            .rfind(|(_, off)| **off <= old)
            .map(|(p, _)| p)
            .ok_or("R14 mapping: A source precedes all planes")?;
        let delta = old - lay.a_off[parent];
        let dom = lay.ids().dom(parent);
        let p = self.layout.plane(false, parent, self.part(dom))?;
        if (matches!(dom, Dom::D | Dom::F) && delta != 0)
            || delta
                .checked_add(1usize << log)
                .is_none_or(|end| end > 1usize << p.log)
        {
            return Err("R14 mapping: A slice crosses its physical role".into());
        }
        Ok(p.offset + delta)
    }
    pub(super) fn h_source(
        &self,
        lay: &Layout,
        parent: usize,
    ) -> Result<(usize, usize, usize), String> {
        let p = self
            .layout
            .plane(true, parent, self.part(lay.hids().dom(parent)))?;
        Ok((
            p.offset,
            p.offset + p.rows_per_component * self.layout.n,
            p.log,
        ))
    }
    pub(super) fn a_pair(&self, k: usize) -> Result<usize, String> {
        self.slot()
            .a_pairs
            .get(k)
            .copied()
            .ok_or_else(|| "R14 mapping: extra A terminal".into())
    }
    pub(super) fn h_pair(&self, k: usize) -> Result<usize, String> {
        self.slot()
            .h_pairs
            .get(k)
            .copied()
            .ok_or_else(|| "R14 mapping: extra H terminal".into())
    }
    pub(super) fn main(&self) -> usize {
        self.slot().main
    }
    pub(super) fn sites(&self) -> (usize, usize) {
        (self.slot().a_sites, self.slot().h_sites)
    }
    pub(super) fn crop(&self, lay: &Layout, values: Vec<Fp2>) -> Vec<Fp2> {
        let dom = match self.slot().base {
            SC_DZC => Dom::D,
            SC_FZC => Dom::F,
            _ => return values,
        };
        if values.len() != lay.shape().size(dom) {
            return values;
        }
        let e = self.extent(dom);
        let pad = if dom == Dom::D {
            lay.shape().d_pad
        } else {
            lay.shape().f_pad
        };
        (0..lay.shape().tokens)
            .flat_map(|t| {
                values[t * pad + e.start..t * pad + e.start + e.width]
                    .iter()
                    .copied()
            })
            .collect()
    }
    fn extent(&self, dom: Dom) -> Extent {
        let parts = if dom == Dom::D {
            self.layout.d
        } else {
            self.layout.f
        };
        parts[if self.slot().part == Part::Narrow {
            1
        } else {
            0
        }]
    }
    pub(super) fn host(&self, base: usize) -> Result<usize, String> {
        let matches = self
            .layout
            .slots
            .iter()
            .enumerate()
            .filter(|(_, s)| s.base == base)
            .collect::<Vec<_>>();
        if matches.len() == 1 {
            return Ok(matches[0].0);
        }
        matches
            .into_iter()
            .find(|(_, s)| s.part == self.slot().part)
            .map(|(i, _)| i)
            .ok_or_else(|| "R14 mapping: absent/ambiguous hosted relation".into())
    }
}

#[derive(Default)]
pub(crate) struct SplitPoints {
    common: Points,
    ao: [Vec<Fp2>; 2],
    down: [Vec<Fp2>; 2],
    gate: [Vec<Fp2>; 2],
    up: [Vec<Fp2>; 2],
    down_token: Vec<Fp2>,
}

pub(crate) fn schedule(layout: &SplitLayout) -> Vec<SlotSchedule> {
    layout
        .slots
        .iter()
        .map(|s| SlotSchedule {
            main: s.main,
            ext: s.ext,
            degree: s.degree,
            terminals: s.a_sites + s.h_sites + s.endpoint_sites,
            kind: SLOT_KINDS[s.base],
            name: format!("R14 {} {:?}", SLOT_NAMES[s.base], s.part),
        })
        .collect()
}

pub(crate) fn sum_claim(profile: &SplitProfile) -> Result<ZClaim, String> {
    let lay = Layout::for_shape(profile.base())?;
    let mut parts = Vec::new();
    for p in &profile.layout().h {
        let sign = if lay.hids().is_table(p.parent) {
            Fp2::ONE.neg()
        } else {
            Fp2::ONE
        };
        for (offset, coef) in [
            (p.offset, sign),
            (
                p.offset + p.rows_per_component * profile.layout().n,
                sign.mul(Fp2::U),
            ),
        ] {
            parts.push(ZPart {
                slice: Slice {
                    offset,
                    log_size: p.log as u32,
                },
                coef,
                point: vec![],
            });
        }
    }
    Ok(ZClaim {
        parts,
        value: Fp2::ZERO,
    })
}

fn finish(view: View<'_>, sh: &Shape, tabs: Vec<Tab>, poly: Poly) -> Result<SlotDef, String> {
    let declared = &view.layout.slots[view.physical];
    let count = |cm| {
        tabs.iter()
            .filter(|t| matches!(t,Tab::Priv(p) if p.cm==cm))
            .count()
    };
    if count(Cm::A) != declared.a_sites
        || count(Cm::H) != declared.h_sites
        || count(Cm::In) + count(Cm::Out) != declared.endpoint_sites
    {
        return Err("R14 builder: terminal census differs from physical schedule".into());
    }
    Ok(SlotDef {
        slot: view.physical,
        tabs,
        poly,
        groups: None,
        hosted: vec![],
        sh: sh.clone(),
    })
}

fn private(
    p: &crate::private_block::split_layout::Plane,
    coords: Vec<Coord>,
    mask_row: usize,
) -> Tab {
    Tab::Priv(Priv {
        cm: Cm::A,
        slices: vec![(p.offset, Fp2::ONE)],
        log: p.log,
        coords,
        mask_row,
        ext_round: 0,
    })
}

fn norm(
    view: View<'_>,
    ctx: &Ctx<'_>,
    pts: &mut SplitPoints,
    tr: &mut Transcript,
) -> Result<SlotDef, String> {
    let sh = ctx.lay.shape();
    let rt = tr.challenge_fp2_vec(lg(sh.t_pad));
    let base = view.slot().base;
    let parent = ctx.lay.ids().at(if base == SC_SS { A_X } else { A_X1 });
    if base == SC_SS {
        pts.common.r_t = rt.clone();
    } else {
        pts.common.r_t2 = rt.clone();
    }
    let mut tabs = Vec::new();
    for (i, part) in [Part::Wide, Part::Narrow].into_iter().enumerate() {
        let p = view.layout.plane(false, parent, part)?;
        let width = view.layout.d[i].width;
        tabs.push(Tab::Eq {
            point: geometry::norm_eq_point(&rt, view.layout.d[0].width, width)?,
            start: 0,
        });
        tabs.push(private(
            p,
            geometry::source_coords(sh, view.layout, p, view.layout.d[0].width, None)?,
            view.a_pair(i)?,
        ));
    }
    finish(
        view,
        sh,
        tabs,
        Box::new(|v| v[0].mul(v[1].mul(v[1])).add(v[2].mul(v[3].mul(v[3])))),
    )
}

fn matrix(
    view: View<'_>,
    ctx: &Ctx<'_>,
    pts: &mut SplitPoints,
    tr: &mut Transcript,
) -> Result<SlotDef, String> {
    let sh = ctx.lay.shape();
    let base = view.slot().base;
    let i = usize::from(view.slot().part == Part::Narrow);
    let lt = lg(sh.t_pad);
    let ids = ctx.lay.ids();
    match base {
        SC_QMM => pts.common.r_q = tr.challenge_fp2_vec(lt),
        SC_WO if i == 0 => pts.common.r_q = tr.challenge_fp2_vec(lt),
        SC_GMM if i == 0 => pts.common.r_tf = tr.challenge_fp2_vec(lt),
        SC_DMM if i == 0 => pts.down_token = tr.challenge_fp2_vec(lt),
        _ => {}
    }
    let token = match base {
        SC_GMM | SC_UMM => &pts.common.r_tf,
        SC_DMM => &pts.down_token,
        _ => &pts.common.r_q,
    };
    if token.len() != lt {
        return Err("R14 matrix: missing shared token point".into());
    }
    let (parent, w, rows, cols, axis, site, out, inputs): (
        usize,
        &[i8],
        usize,
        usize,
        Axis,
        Site,
        Extent,
        Vec<Part>,
    ) = match base {
        SC_QMM => (
            ids.at(A_Y),
            &ctx.public.wq,
            sh.q_pad(),
            sh.d_pad,
            Axis::Rows,
            Site::Q,
            Extent {
                start: 0,
                width: sh.q_pad(),
            },
            vec![Part::Wide, Part::Narrow],
        ),
        SC_KMM => (
            ids.at(A_Y),
            &ctx.public.wk,
            sh.kv_heads * sh.head_dim,
            sh.d_pad,
            Axis::Rows,
            Site::K,
            Extent {
                start: 0,
                width: sh.kv_heads * sh.head_dim,
            },
            vec![Part::Wide, Part::Narrow],
        ),
        SC_VMM => (
            ids.at(A_Y),
            &ctx.public.wv,
            sh.kv_heads * sh.head_dim,
            sh.d_pad,
            Axis::Rows,
            Site::V,
            Extent {
                start: 0,
                width: sh.kv_heads * sh.head_dim,
            },
            vec![Part::Wide, Part::Narrow],
        ),
        SC_WO => (
            ids.at(A_O8),
            &ctx.public.wo,
            sh.d_pad,
            sh.q_pad(),
            Axis::Rows,
            Site::O,
            view.layout.d[i],
            vec![Part::Whole],
        ),
        SC_GMM => (
            ids.at(A_YM),
            &ctx.ff.wg_t,
            sh.d_pad,
            sh.f_pad,
            Axis::Columns,
            Site::Gate,
            view.layout.f[i],
            vec![Part::Wide, Part::Narrow],
        ),
        SC_UMM => (
            ids.at(A_YM),
            &ctx.ff.wu_t,
            sh.d_pad,
            sh.f_pad,
            Axis::Columns,
            Site::Up,
            view.layout.f[i],
            vec![Part::Wide, Part::Narrow],
        ),
        SC_DMM => (
            ids.at(A_H16),
            &ctx.ff.wd_t,
            sh.f_pad,
            sh.d_pad,
            Axis::Columns,
            Site::Down,
            view.layout.d[i],
            vec![Part::Wide, Part::Narrow],
        ),
        _ => return Err("R14 matrix: undeclared relation".into()),
    };
    let rj = tr.challenge_fp2_vec(lg(out.width));
    let point = cat(&[token, &rj]);
    let coeff = accuracy_fold::coefficients(
        sh,
        ctx.accuracy
            .ok_or("R14 matrix: missing bound accuracy data")?,
        site,
    )?;
    let inner = 1usize << view.slot().main;
    let mut tabs = Vec::new();
    for (k, part) in inputs.into_iter().enumerate() {
        let p = view.layout.plane(false, parent, part)?;
        let input = match (p.domain, part) {
            (Dom::D, Part::Wide) => view.layout.d[0],
            (Dom::D, Part::Narrow) => view.layout.d[1],
            (Dom::F, Part::Wide) => view.layout.f[0],
            (Dom::F, Part::Narrow) => view.layout.f[1],
            (_, Part::Whole) => Extent {
                start: 0,
                width: sh.size(p.domain) / sh.t_pad,
            },
            _ => return Err("R14 matrix: source piece/domain mismatch".into()),
        };
        let coords = if part == Part::Whole {
            let mut c = fixed(token);
            c.extend(rho(0..lg(inner)));
            c
        } else {
            geometry::source_coords(sh, view.layout, p, inner, Some(token))?
        };
        tabs.push(private(p, coords, view.a_pair(k)?));
        let fold = geometry::public_fold_piece(w, rows, cols, axis, out, input, &coeff, &rj)?;
        tabs.push(Tab::Pub(geometry::zero_lift_public_fold(&fold, inner)?));
    }
    match base {
        SC_QMM => pts.common.pq = point,
        SC_KMM => pts.common.pk = point,
        SC_VMM => pts.common.pv = point,
        SC_WO => pts.ao[i] = point,
        SC_GMM => pts.gate[i] = point,
        SC_UMM => pts.up[i] = point,
        SC_DMM => pts.down[i] = point,
        _ => unreachable!(),
    };
    let terms = tabs.len() / 2;
    finish(
        view,
        sh,
        tabs,
        Box::new(move |v| (0..terms).fold(Fp2::ZERO, |a, k| a.add(v[2 * k].mul(v[2 * k + 1])))),
    )
}

/// Translate unchanged-domain legacy definitions into the new commitments.
/// A private D/F source here is an error: those relations need piece builders.
fn whole(
    view: View<'_>,
    ctx: &Ctx<'_>,
    pts: &mut Points,
    tr: &mut Transcript,
) -> Result<SlotDef, String> {
    let mut def = super::define(view.slot().base, ctx, pts, tr)?;
    let (mut ak, mut hk) = (0, 0);
    for tab in &mut def.tabs {
        if let Tab::Priv(p) = tab {
            match p.cm {
                Cm::A => {
                    for (off, _) in &mut p.slices {
                        *off = view.a_offset(ctx.lay, *off, p.log)?;
                    }
                    p.mask_row = view.a_pair(ak)?;
                    ak += 1;
                }
                Cm::H => {
                    let parent = ctx
                        .lay
                        .h_off
                        .iter()
                        .position(|&(re, im)| {
                            p.slices.iter().all(|(off, _)| *off == re || *off == im)
                        })
                        .ok_or("R14 mapping: H functional is outside a declared role")?;
                    let (re, im, log) = view.h_source(ctx.lay, parent)?;
                    let (old_re, old_im) = ctx.lay.h_off[parent];
                    for (off, _) in &mut p.slices {
                        *off = if *off == old_re {
                            re
                        } else if *off == old_im {
                            im
                        } else {
                            return Err("R14 mapping: foreign H component".into());
                        };
                    }
                    if log != p.log {
                        return Err("R14 mapping: changed H domain in whole slot".into());
                    }
                    p.mask_row = view.h_pair(hk)?;
                    hk += 1;
                }
                _ => return Err("R14 mapping: endpoint in a whole-domain builder".into()),
            }
        }
    }
    if (ak, hk) != view.sites() {
        return Err("R14 mapping: whole-slot terminal census mismatch".into());
    }
    for (host, _) in &mut def.hosted {
        *host = view.host(*host)?;
    }
    def.slot = view.physical;
    Ok(def)
}

fn io(
    view: View<'_>,
    profile: &SplitProfile,
    ctx: &Ctx<'_>,
    sources: &IoSources<'_>,
    tr: &mut Transcript,
) -> Result<SlotDef, String> {
    let outgoing = view.slot().base == SC_IO_OUT;
    let i = usize::from(view.slot().part == Part::Narrow);
    let (spec, usage) = if outgoing {
        sources.output
    } else {
        sources.input
    };
    if !matches!(
        (outgoing, spec.kind(), usage),
        (false, Kind::Input, Use::External)
            | (true, Kind::Output, Use::External)
            | (false, Kind::Boundary(_), Use::Incoming)
            | (true, Kind::Boundary(_), Use::Outgoing)
    ) {
        return Err("R14 IO: logical endpoint/boundary role mismatch".into());
    }
    let (off, log, mask_row) = spec.source(profile, usage, i)?;
    if log != view.slot().main {
        return Err("R14 IO: endpoint piece cube differs".into());
    }
    let parent = ctx.lay.ids().at(if outgoing { A_X2 } else { A_X });
    let p = view.layout.plane(false, parent, view.slot().part)?;
    let cm = if outgoing { Cm::Out } else { Cm::In };
    let tabs = vec![
        Tab::Eq {
            point: tr.challenge_fp2_vec(log),
            start: 0,
        },
        private(p, rho(0..log), view.a_pair(0)?),
        Tab::Priv(Priv {
            cm,
            slices: vec![(off, Fp2::ONE)],
            log,
            coords: rho(0..log),
            mask_row,
            ext_round: 0,
        }),
    ];
    finish(
        view,
        ctx.lay.shape(),
        tabs,
        Box::new(|v| v[0].mul(v[1].sub(v[2]))),
    )
}

pub(crate) fn define(
    physical: usize,
    profile: &SplitProfile,
    ctx: &Ctx<'_>,
    pts: &mut SplitPoints,
    sources: &IoSources<'_>,
    tr: &mut Transcript,
) -> Result<SlotDef, String> {
    if ctx.lay.shape() != profile.base() {
        return Err("R14 builder: arithmetic reference differs from the split profile".into());
    }
    let layout = profile.layout();
    let slot = layout
        .slots
        .get(physical)
        .ok_or("R14 builder: undeclared slot")?;
    let view = View { layout, physical };
    match slot.base {
        SC_SS | SC_SSM => norm(view, ctx, pts, tr),
        SC_QMM | SC_KMM | SC_VMM | SC_WO | SC_GMM | SC_UMM | SC_DMM => matrix(view, ctx, pts, tr),
        SC_DZC | SC_FZC => {
            let i = usize::from(slot.part == Part::Narrow);
            let mut point = pts.common.clone();
            point.p_a = pts.ao[i].clone();
            point.p_z = pts.down[i].clone();
            point.p_g = pts.gate[i].clone();
            point.p_u = pts.up[i].clone();
            accuracy::define_piece(slot.base, ctx, &point, tr, view)
        }
        SC_IO_IN | SC_IO_OUT => io(view, profile, ctx, sources, tr),
        _ => whole(view, ctx, &mut pts.common, tr),
    }
}
