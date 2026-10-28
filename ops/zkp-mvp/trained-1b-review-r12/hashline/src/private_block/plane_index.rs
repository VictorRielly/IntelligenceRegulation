//! **STAGE 15: THE PLANE INDEX TABLE — the one public layout fact a run
//! capture lacked.**
//!
//! The privacy gate of ruling M-8 read the two run bundles of stage 14 and
//! reported ONE missing field: for each committed plane of `A` and of `H`, its
//! id, its name, its domain and its row range, and, per slot, the ordered list
//! of planes whose evaluations that slot's terminal vector carries. Without it
//! the per-slot terminal identity stays OPEN at the rung, because
//! `zk60_native_terminal_polys.py` is a hand-port of the TOY's plane numbering
//! and does not generalise from `run.json["shape"]` alone.
//!
//! **EVERYTHING HERE IS PUBLIC.** A plane's NAME, DOMAIN, ROW RANGE and the
//! ORDER in which a slot pushes its private tables are functions of the
//! `Shape` — of the same public words the run statement already absorbs — and
//! of nothing else. **No plane CONTENT is here**: not a witness word, not a
//! pad, not a salt, not a mask coefficient. The table says where a plane lives
//! and what it is called; it says nothing whatever about what is in it.
//!
//! **IT IS AN INDEPENDENT STATEMENT, AND IT IS CHECKED.** The plane list, the
//! name table and the per-slot push order are written here from `layout.rs`'s
//! declarations and `argument.rs`'s slot definitions, and they are compared
//! against three things that are derived separately:
//!
//! * the domain of every plane, against `Ids::dom` / `HIds::dom` (which
//!   `Ids::new` has already matched against `Shape::a_plane_doms`);
//! * the per-slot A and H counts, against `Shape::claim_sites`;
//! * the ACTUAL sequence of private tables of every slot of every stage of a
//!   captured run, in `run_capture::slot` — a capture is refused if one
//!   differs.
//!
//! The row-range statement is a refusal too: the `A` planes must tile
//! `[0, a_data_rows)` with no gap and no overlap, and each `H` plane's `re`
//! and `im` halves must tile `[0, h_data_rows)` in that order.
//!
//! **It is a RECORDER's module.** Nothing here is reachable from the prover or
//! the verifier: it is `cfg(test)` like `run_capture.rs`, it takes a `&Layout`
//! and returns data, and no branch of the protocol can observe it.

use super::layout::*;
use super::shape::Shape;
use std::io::Write;

/// One entry of a slot's terminal push order: WHICH committed plane the
/// terminal at this position is an evaluation of.
///
/// `A` and `H` carry the plane's id AT THIS SHAPE (the index into
/// `a_planes` / `h_planes` of the table, which is `Ids`' / `HIds`' own
/// numbering). `In` and `Out` are the stage's two IO commitments — the
/// external endpoints in a single block, and at a stage of a run the external
/// endpoint or the internal boundary named by the opening's
/// `commitment_kind` — which are not `A` or `H` planes and have no id.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub(super) enum Ref {
    A(usize),
    H(usize),
    In,
    Out,
}

impl Ref {
    /// the role name the capture already uses for this commitment
    fn role(self) -> &'static str {
        match self {
            Ref::A(_) => "A",
            Ref::H(_) => "H",
            Ref::In => "Input",
            Ref::Out => "Output",
        }
    }
}

/// One committed `A` plane: `Fp`-valued, one contiguous run of rows.
pub(super) struct APlane {
    pub id: usize,
    pub name: String,
    pub dom: Dom,
    pub first_row: usize,
    pub rows: usize,
    /// the element offset `first_row * cols`, which is what a slot's
    /// `slices[].offset` is measured in
    pub offset: usize,
    /// the log of the plane's OWN domain (a slot may read it on a coarser
    /// cube, and the slot's own `log_size` says so)
    pub log_size: usize,
}

/// One committed `H` plane: `Fp2`-valued, hence TWO equal runs of rows, the
/// `re` half then the `im` half.
pub(super) struct HPlane {
    pub id: usize,
    pub name: String,
    pub dom: Dom,
    pub rows: usize,
    pub re_first_row: usize,
    pub im_first_row: usize,
    pub re_offset: usize,
    pub im_offset: usize,
    pub log_size: usize,
}

/// The whole table: the two plane lists and the 23 push orders.
pub(super) struct PlaneIndex {
    pub a: Vec<APlane>,
    pub h: Vec<HPlane>,
    pub slots: Vec<Vec<Ref>>,
    pub a_data_rows: usize,
    pub h_data_rows: usize,
    pub cols: usize,
}

// ---------------------------------------------------------------- the names

/// A run of consecutive planes with one base name: `(name, indexed, length,
/// domain)`. An INDEXED group is written `name0, name1, …` (its length moves
/// with the shape and the toy has no constant for the members past the
/// first); a singleton keeps its own constant's name.
type Seg = (&'static str, bool, usize, Dom);

/// **THE `A` PLANE NAMES, IN PLANE ORDER.** The constants of `layout.rs`
/// §"the A planes", grouped exactly as `Ids`' segment table groups them, with
/// the three shape-driven lengths (`limbs_norm`, `limbs_p`, `limbs_sigma_s`)
/// read from the shape. `build` refuses unless this list has the length and
/// the domain sequence `Ids` computed independently.
fn a_segments(sh: &Shape) -> Vec<Seg> {
    let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());
    let one = |name: &'static str, dom: Dom| -> Seg { (name, false, 1, dom) };
    vec![
        one("A_D", Dom::T),
        one("A_DSQ", Dom::T),
        one("A_DM", Dom::T),
        one("A_DSQM", Dom::T),
        one("A_MX", Dom::Ht),
        one("A_SUM", Dom::Ht),
        one("A_LIMB", Dom::L),
        one("A_LIMBM", Dom::L),
        one("A_X", Dom::D),
        one("A_XL0", Dom::D),
        one("A_XL1", Dom::D),
        one("A_Y", Dom::D),
        ("A_NR", true, ln, Dom::D),
        ("A_NS", true, ln, Dom::D),
        one("A_AO", Dom::D),
        one("A_AL0", Dom::D),
        one("A_AL1", Dom::D),
        one("A_RAL", Dom::D),
        one("A_X1", Dom::D),
        one("A_X1L0", Dom::D),
        one("A_X1L1", Dom::D),
        one("A_YM", Dom::D),
        ("A_MR", true, ln, Dom::D),
        ("A_MS", true, ln, Dom::D),
        one("A_Z16", Dom::D),
        one("A_X2", Dom::D),
        one("A_X2L0", Dom::D),
        one("A_X2L1", Dom::D),
        one("A_ZL0", Dom::D),
        one("A_ZL1", Dom::D),
        one("A_RDL", Dom::D),
        one("A_Q8", Dom::Q),
        one("A_RQL", Dom::Q),
        one("A_QR8", Dom::Q),
        one("A_RQRL", Dom::Q),
        one("A_O8", Dom::Q),
        one("A_RO0", Dom::Q),
        one("A_RO1", Dom::Q),
        one("A_K8", Dom::Kv),
        one("A_RKL", Dom::Kv),
        one("A_V8", Dom::Kv),
        one("A_RVL", Dom::Kv),
        one("A_KR8", Dom::Kv),
        one("A_RKRL", Dom::Kv),
        one("A_S8", Dom::S),
        one("A_RSL", Dom::S),
        one("A_ZSEL", Dom::S),
        one("A_E", Dom::S),
        one("A_P", Dom::S),
        ("A_PL", true, lp, Dom::S),
        ("A_SR", true, ls, Dom::S),
        ("A_SG", true, ls, Dom::S),
        one("A_G8", Dom::F),
        one("A_RGL", Dom::F),
        one("A_A16", Dom::F),
        one("A_U16", Dom::F),
        one("A_UL0", Dom::F),
        one("A_UL1", Dom::F),
        one("A_H16", Dom::F),
        one("A_HL0", Dom::F),
        one("A_HL1", Dom::F),
        one("A_RH0", Dom::F),
        one("A_RH1", Dom::F),
        one("A_MU8", Dom::Tab),
        one("A_MEXP", Dom::Tab),
        one("A_MACT", Dom::Tab),
    ]
}

/// **THE `H` PLANE NAMES, IN PLANE ORDER**, the constants of `layout.rs`
/// §"the H planes" in `HIds::new`'s own segment order. Every LogUp helper
/// block is an indexed group whose length is `Shape::helpers(dom)`; the six
/// singletons keep their constants' names.
fn h_segments(sh: &Shape) -> Vec<Seg> {
    vec![
        ("H_L", true, sh.helpers(Dom::L), Dom::L),
        ("H_D", true, sh.helpers(Dom::D), Dom::D),
        ("H_Q", true, sh.helpers(Dom::Q), Dom::Q),
        ("H_KV", true, sh.helpers(Dom::Kv), Dom::Kv),
        ("H_S", true, sh.helpers(Dom::S), Dom::S),
        ("H_SEXP", false, 1, Dom::S),
        ("H_F", true, sh.helpers(Dom::F), Dom::F),
        ("H_FACT", false, 1, Dom::F),
        ("H_GU8", false, 1, Dom::Tab),
        ("H_GEXP", false, 1, Dom::Tab),
        ("H_GACT", false, 1, Dom::Tab),
        ("H_U", false, 1, Dom::Tab),
    ]
}

/// NATIVE LANE: every `A` plane's name at a shape, in plane order (the D16
/// item-5 range audit names the planes it lists with these)
pub(super) fn a_plane_names(sh: &Shape) -> Vec<String> {
    expand(&a_segments(sh)).into_iter().map(|(n, _)| n).collect()
}

fn expand(segs: &[Seg]) -> Vec<(String, Dom)> {
    let mut out = Vec::new();
    for (name, indexed, len, dom) in segs {
        for k in 0..*len {
            out.push((if *indexed { format!("{name}{k}") } else { (*name).to_string() }, *dom));
        }
    }
    out
}

// ---------------------------------------------------------------- the table

pub(super) fn build(lay: &Layout) -> Result<PlaneIndex, String> {
    let sh = lay.shape();
    let (ids, hids) = (lay.ids(), lay.hids());
    let n = lay.n();
    // ---- the A planes
    let a_names = expand(&a_segments(sh));
    if a_names.len() != ids.n_a() {
        return Err(format!("private block: the A plane name table has {} names for {} planes", a_names.len(), ids.n_a()));
    }
    let mut a: Vec<APlane> = Vec::with_capacity(a_names.len());
    for (p, (name, dom)) in a_names.into_iter().enumerate() {
        if dom != ids.dom(p) {
            return Err(format!("private block: the plane index puts {name} on {dom:?}, the layout on {:?}", ids.dom(p)));
        }
        let offset = lay.a_off[p];
        if offset % n != 0 {
            return Err(format!("private block: A plane {name} is not row aligned"));
        }
        a.push(APlane { id: p, name, dom, first_row: offset / n, rows: sh.rows_of(dom), offset, log_size: sh.log(dom) });
    }
    // ---- the H planes, each an `re` run then an `im` run of the same length
    let h_names = expand(&h_segments(sh));
    if h_names.len() != hids.n_h() {
        return Err(format!("private block: the H plane name table has {} names for {} planes", h_names.len(), hids.n_h()));
    }
    let mut h: Vec<HPlane> = Vec::with_capacity(h_names.len());
    for (p, (name, dom)) in h_names.into_iter().enumerate() {
        if dom != hids.dom(p) {
            return Err(format!("private block: the plane index puts {name} on {dom:?}, the layout on {:?}", hids.dom(p)));
        }
        let (re, im) = lay.h_off[p];
        if re % n != 0 || im % n != 0 {
            return Err(format!("private block: H plane {name} is not row aligned"));
        }
        h.push(HPlane { id: p, name, dom, rows: sh.rows_of(dom), re_first_row: re / n, im_first_row: im / n, re_offset: re, im_offset: im, log_size: sh.log(dom) });
    }
    // ---- THE TILING REFUSAL: no gap, no overlap, and the totals are the
    // layout's own counted data rows.
    let mut row = 0usize;
    for p in &a {
        if p.first_row != row {
            return Err(format!("private block: A plane {} starts at row {} and not at {row}", p.name, p.first_row));
        }
        row += p.rows;
    }
    if row != lay.a_data_rows {
        return Err(format!("private block: the A planes tile {row} rows, the layout counts {}", lay.a_data_rows));
    }
    let mut row = 0usize;
    for p in &h {
        if p.re_first_row != row || p.im_first_row != row + p.rows {
            return Err(format!("private block: H plane {}'s halves are at rows {} and {} and not at {row} and {}", p.name, p.re_first_row, p.im_first_row, row + p.rows));
        }
        row += 2 * p.rows;
    }
    if row != lay.h_data_rows {
        return Err(format!("private block: the H planes tile {row} rows, the layout counts {}", lay.h_data_rows));
    }
    // ---- the push order, and the cross-check against `Shape::claim_sites`
    let mut slots: Vec<Vec<Ref>> = Vec::with_capacity(N_SLOTS);
    for s in 0..N_SLOTS {
        slots.push(slot_planes(lay, s)?);
    }
    for (s, refs) in slots.iter().enumerate() {
        let na = refs.iter().filter(|r| matches!(r, Ref::A(_))).count();
        let nh = refs.iter().filter(|r| matches!(r, Ref::H(_))).count();
        let nio = refs.len() - na - nh;
        if na != lay.a_sites()[s] || nh != lay.h_sites()[s] || nio != usize::from(s >= SC_IO_IN) {
            return Err(format!(
                "private block: the plane index gives slot {s} [{}] {na} A / {nh} H / {nio} IO planes, the schedule declares {} / {} / {}",
                SLOT_NAMES[s],
                lay.a_sites()[s],
                lay.h_sites()[s],
                usize::from(s >= SC_IO_IN)
            ));
        }
        for r in refs {
            let bad = match r {
                Ref::A(p) => *p >= a.len(),
                Ref::H(p) => *p >= h.len(),
                _ => false,
            };
            if bad {
                return Err(format!("private block: slot {s} [{}] references {r:?}, which is not a plane of this shape", SLOT_NAMES[s]));
            }
        }
    }
    Ok(PlaneIndex { a, h, slots, a_data_rows: lay.a_data_rows, h_data_rows: lay.h_data_rows, cols: n })
}

/// **THE PUSH ORDER OF ONE SLOT**, written from `argument::define`'s own
/// sequence of `B::a` / `B::a_at` / `B::a_slice` / `B::a_range` / `B::h` /
/// `B::endpoint` calls — the order `run_slot` filters the terminals in and the
/// order `acc.claims` is grown in. A plane read on a SUB-SLICE (`SC_TZC`'s
/// eighteen limb sub-planes) or at a flipped coordinate (`SC_QZC` /
/// `SC_KVZC`'s RoPE partner) appears AGAIN, at its own position: the terminal
/// is another evaluation of the same committed plane.
fn slot_planes(lay: &Layout, slot: usize) -> Result<Vec<Ref>, String> {
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let ls = sh.limbs_sigma_s();
    let mut v: Vec<Ref> = Vec::new();
    // `toy` is a toy plane constant, mapped to this shape by `Ids::at`
    let a = |v: &mut Vec<Ref>, toy: usize| v.push(Ref::A(ids.at(toy)));
    // a `B::a_range` sweep, in SHAPED plane ids
    let range = |v: &mut Vec<Ref>, first: usize, last: usize| {
        for p in first..=last {
            v.push(Ref::A(p));
        }
    };
    // a domain's LogUp helper block, `h0` then `1 .. helpers(dom)`
    let helpers = |v: &mut Vec<Ref>, dom: Dom| {
        for j in 0..sh.helpers(dom) {
            v.push(Ref::H(hids.helper(dom, j)));
        }
    };
    match slot {
        SC_SS => a(&mut v, A_X),
        SC_SSM => a(&mut v, A_X1),
        SC_TZC => {
            a(&mut v, A_D);
            a(&mut v, A_DSQ);
            for _ in 0..N_LIMBS {
                v.push(Ref::A(ids.at(A_LIMB)));
            }
            a(&mut v, A_DM);
            a(&mut v, A_DSQM);
            for _ in 0..N_LIMBS {
                v.push(Ref::A(ids.at(A_LIMBM)));
            }
        }
        SC_LZC => {
            range(&mut v, ids.at(A_LIMB), ids.at(A_LIMBM));
            v.push(Ref::H(hids.first_helper(Dom::L)));
        }
        SC_RS => {
            a(&mut v, A_E);
            a(&mut v, A_ZSEL);
        }
        SC_QMM | SC_KMM | SC_VMM => a(&mut v, A_Y),
        SC_WO => a(&mut v, A_O8),
        SC_SCORE => {
            a(&mut v, A_QR8);
            a(&mut v, A_KR8);
        }
        SC_PV => {
            a(&mut v, A_P);
            a(&mut v, A_V8);
        }
        SC_GMM | SC_UMM => a(&mut v, A_YM),
        SC_DMM => a(&mut v, A_H16),
        SC_DZC => {
            range(&mut v, ids.at(A_X), ids.at(A_RDL));
            a(&mut v, A_D);
            a(&mut v, A_DM);
            helpers(&mut v, Dom::D);
        }
        SC_QZC => {
            range(&mut v, ids.at(A_Q8), ids.at(A_RO1));
            a(&mut v, A_Q8);
            helpers(&mut v, Dom::Q);
        }
        SC_KVZC => {
            range(&mut v, ids.at(A_K8), ids.at(A_RKRL));
            a(&mut v, A_K8);
            helpers(&mut v, Dom::Kv);
        }
        SC_SZC => {
            if ls == 0 {
                return Err("private block: a shape with no sigma_s limb has no SC_SZC plane range".into());
            }
            range(&mut v, ids.at(A_S8), ids.sg(ls - 1));
            a(&mut v, A_MX);
            a(&mut v, A_SUM);
            helpers(&mut v, Dom::S);
            v.push(Ref::H(hids.sexp()));
        }
        SC_FZC => {
            range(&mut v, ids.at(A_G8), ids.at(A_RH1));
            helpers(&mut v, Dom::F);
            v.push(Ref::H(hids.fact()));
        }
        SC_TAB => {
            let th = hids.table_helpers();
            a(&mut v, A_MU8);
            v.push(Ref::H(th[0]));
            a(&mut v, A_MEXP);
            v.push(Ref::H(th[1]));
            a(&mut v, A_MACT);
            v.push(Ref::H(th[2]));
        }
        SC_ZS => v.push(Ref::H(hids.u())),
        SC_IO_IN => {
            a(&mut v, A_X);
            v.push(Ref::In);
        }
        SC_IO_OUT => {
            a(&mut v, A_X2);
            v.push(Ref::Out);
        }
        _ => return Err(format!("private block: the plane index has no push order for slot {slot}")),
    }
    Ok(v)
}

impl PlaneIndex {
    /// The plane a private table of role `cm` (`0 = A`, `1 = H`, `2 = Input`,
    /// `3 = Output`) and first slice offset `offset` is an evaluation of.
    /// A sub-slice is located by CONTAINMENT in the plane's own element range,
    /// which is what `SC_TZC`'s limb sub-planes need; an `H` table names its
    /// plane's `re` offset exactly.
    pub(super) fn locate(&self, cm: usize, offset: usize) -> Option<Ref> {
        match cm {
            0 => self.a.iter().find(|p| offset >= p.offset && offset < p.offset + p.rows * self.cols).map(|p| Ref::A(p.id)),
            1 => self.h.iter().find(|p| p.re_offset == offset).map(|p| Ref::H(p.id)),
            2 => Some(Ref::In),
            3 => Some(Ref::Out),
            _ => None,
        }
    }

    /// the name of a reference, for a message and for the table's own JSON
    fn name_of(&self, r: Ref) -> &str {
        match r {
            Ref::A(p) => &self.a[p].name,
            Ref::H(p) => &self.h[p].name,
            Ref::In => "IO_IN",
            Ref::Out => "IO_OUT",
        }
    }

    /// **THE TABLE AS DATA**, the `"plane_index"` member of `run.json`. Public
    /// layout only: an id, a name, a domain, a row range, and per slot the
    /// ordered plane list. No value of any plane is written here, or anywhere
    /// else in this module.
    pub(super) fn render(&self) -> Vec<u8> {
        let mut out = Vec::new();
        write!(out, "\"plane_index\":{{\"a_data_rows\":{},\"h_data_rows\":{},\"a_planes\":[", self.a_data_rows, self.h_data_rows).expect("write to a Vec");
        for (i, p) in self.a.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(
                out,
                "{{\"id\":{},\"name\":{:?},\"domain\":{:?},\"first_row\":{},\"rows\":{},\"offset\":{},\"log_size\":{}}}",
                p.id,
                p.name,
                format!("{:?}", p.dom),
                p.first_row,
                p.rows,
                p.offset,
                p.log_size
            )
            .expect("write to a Vec");
        }
        write!(out, "],\"h_planes\":[").expect("write to a Vec");
        for (i, p) in self.h.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(
                out,
                "{{\"id\":{},\"name\":{:?},\"domain\":{:?},\"rows\":{},\"re_first_row\":{},\"im_first_row\":{},\"re_offset\":{},\"im_offset\":{},\"log_size\":{}}}",
                p.id,
                p.name,
                format!("{:?}", p.dom),
                p.rows,
                p.re_first_row,
                p.im_first_row,
                p.re_offset,
                p.im_offset,
                p.log_size
            )
            .expect("write to a Vec");
        }
        write!(out, "],\"slot_planes\":[").expect("write to a Vec");
        for (s, refs) in self.slots.iter().enumerate() {
            if s > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(out, "{{\"slot\":{s},\"name\":{:?},\"planes\":[", SLOT_NAMES[s]).expect("write to a Vec");
            for (i, r) in refs.iter().enumerate() {
                if i > 0 {
                    write!(out, ",").expect("write to a Vec");
                }
                match r {
                    Ref::A(p) | Ref::H(p) => write!(out, "{{\"role\":{:?},\"id\":{p},\"name\":{:?}}}", r.role(), self.name_of(*r)),
                    _ => write!(out, "{{\"role\":{:?},\"id\":null,\"name\":{:?}}}", r.role(), self.name_of(*r)),
                }
                .expect("write to a Vec");
            }
            write!(out, "]}}").expect("write to a Vec");
        }
        write!(out, "]}}").expect("write to a Vec");
        out
    }
}
