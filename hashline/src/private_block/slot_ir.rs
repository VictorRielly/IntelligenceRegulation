//! **LANE STAGE 34 — THE SLOT EXPRESSION IR, STAGE 1: the twenty-three slot
//! polynomials written down as DATA, beside the closures that stay the
//! oracle.**
//!
//! This module is ruling **I-8** of
//! `docs/zkmatrix-poc/ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md`. The prover's
//! twenty-three sub-arguments are Rust closures today
//! (`argument::define`'s sixteen arms), and the shared sumcheck loop calls
//! one of them once per cube point per evaluation point. The design memo
//! `ZK60_SLOT_EXPRESSION_IR_DESIGN.md` proposes writing each sub-argument's
//! polynomial down as a small expression graph, so that a specialised CPU
//! evaluator, a GPU kernel and a description the independent Python gate can
//! read are all derived from ONE source. Stage 1 is the source and nothing
//! else.
//!
//! **What this stage does NOT do, and the reader should hold it to:**
//!
//! * it does not change one line of any `SC_*` arm, and no `Fp2` the prover
//!   or the verifier computes moves. The whole module is `#[cfg(test)]`, like
//!   `capture`, `run_capture` and `plane_index`, so nothing here can be
//!   reached from a production build at all — the strongest available form of
//!   "the IR is never consulted by `run_slot`";
//! * it does not replace the closures. They are the ORACLE: the stage's
//!   central test evaluates the IR and the closure on the same random table
//!   values and asserts the two field elements are equal, at every registered
//!   shape, every slot and both pad branches. A drift between this file's
//!   transcription and `argument.rs` is a test failure, never a silent
//!   divergence — which is why a hand transcription is safe here and is the
//!   same device `plane_index.rs` already uses for the push order;
//!   and
//! * it does not touch a declared degree, a receipt length or a profile.
//!   [`SlotIr::max_term_degree`] is COMPUTED and may be lower than the
//!   declared one (the memo's §1.4, the check's §8); the declared degree is
//!   what everything else reads, and this stage only records the gap.
//!
//! **The one finding the design's independent check made that matters here is
//! IR-C1, and ruling I-2 is its disposition:** twelve of the memo's 143
//! "wholly base-field" tables are extension-valued, so a `FieldKind` written
//! by hand into the IR would make a later evaluator drop imaginary parts and
//! compute a different field element. In this module a `FieldKind` cannot be
//! written by hand: [`TableRef`] records a [`TableProv`] — WHAT BUILT THE
//! TABLE — and [`TableRef::field`] derives the kind from it by the rule of
//! ruling I-2, that a table is base-field only if no challenge and no
//! extension-valued input enters its construction. The filter test
//! `slot_ir_tests` then asserts the derivation against the tables the prover
//! actually builds, and a deliberately mislabelled table makes it fail.

use super::argument::Ctx;
use super::layout::*;
use crate::field::Fp2;
use crate::transcript::Transcript;

// ---------------------------------------------------------------- the grammar

/// A table's index in its slot's push order — which is also the index its
/// masked terminal arrives at in `SlotProof::terms`, so a reader of the export
/// can join the IR to a capture without a second naming scheme.
pub(super) type TableId = u16;
/// A node's index in [`SlotIr::nodes`], which is topologically ordered: a node
/// only ever refers back.
pub(super) type NodeId = u16;

/// What a table IS, in the slot's cube. The memo's §2.1 grammar.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum TableKind {
    /// `Tab::Eq`: `eq(point, x[start .. start + |point|])`, constant in the
    /// other variables
    Eq { start: usize, point_len: usize },
    /// the two bilinear slots' public group gate over the LEADING `bits`
    /// variables — the repair of finding S19-F1 stated as data
    GroupEq { bits: usize },
    /// `Tab::Pub`: a shape-driven public table
    Public,
    /// `Tab::Pub` holding `pad::indicator_table(shape, dom)`: the pad rule's
    /// support selector
    Support { dom: Dom },
    /// `Tab::Priv` in the `A` commitment: a committed witness plane
    PlaneA,
    /// `Tab::Priv` in the `H` commitment: a LogUp helper column (`re + u im`)
    HelperH,
    /// `Tab::Priv` in an endpoint commitment
    Endpoint,
}

/// **RULING I-2, THE RULE ITSELF.** Where a table comes from — and the ONLY
/// input [`TableRef::field`] reads. A table is base-field exactly when no
/// challenge and no extension-valued input enters its CONSTRUCTION; every
/// variant below records which of those two things happened, and nothing
/// records an opinion.
///
/// The three places a challenge gets into a table's words, all of them read
/// out of `argument.rs`:
///
/// * `Tab::Eq` is `eq_cube(eq_table_msb(point))` of a point of challenges;
/// * a public table can carry one: the seven folded weight matrices are
///   weighted by `eq(r_j)` (`fold_rows_i8` / `fold_cols_i8`), and the three
///   byte-table value columns carry a tag (`g_u8`, `g_exp`, `g_act`) and, for
///   two of them, `beta`. **The `g_u8` column is finding IR-C1's twelfth
///   table**: `table_values_u8_at` is `k(i % 256) + g_u8`, and the memo listed
///   it among the base-field public tables;
/// * `priv_table` builds a plane's cube as `out[x] += eqf[z] * v`, where
///   `eqf = eq_table_msb(&fixed)` is the tensor of the plane's `Coord::Fixed`
///   coordinates — CHALLENGES. **A plane read at a fixed claim point is
///   therefore extension-valued**, which is finding IR-C1's other eleven
///   tables (the seven matmuls' planes and the four bilinear factors). The
///   slice coefficients are the second way in: an `H` column is
///   `(re, 1) + (im, u)`, so it carries `Fp2::U`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum TableProv {
    /// `Tab::Eq { point, .. }` over a point of challenges
    EqOfChallenges,
    /// `Tab::Pub` built from the SHAPE and public integers alone: the causal
    /// mask, the two padded norm gains, the RoPE pair, the all-ones vector,
    /// a `pad::indicator_table`
    PublicFromShape,
    /// `Tab::Pub` with a challenge inside its words; `why` names it
    PublicWithChallenge(&'static str),
    /// `Tab::Priv`: `fixed_coords` is how many `Coord::Fixed` entries the
    /// plane's claim point has, and `extension_slice_coef` is true when any
    /// slice coefficient is outside the base field (an `H` column's `u`)
    Committed { fixed_coords: usize, extension_slice_coef: bool },
}

/// What the WORDS of a table hold, not what the Rust type is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum FieldKind {
    Base,
    Extension,
}

impl FieldKind {
    pub(super) fn label(self) -> &'static str {
        match self {
            FieldKind::Base => "base",
            FieldKind::Extension => "ext",
        }
    }
}

/// **RULING I-2 as a function, and the only way a `FieldKind` is ever
/// produced in this module.** There is deliberately no field to set and no
/// constructor that takes one.
pub(super) fn field_kind(prov: &TableProv) -> FieldKind {
    match prov {
        TableProv::EqOfChallenges | TableProv::PublicWithChallenge(_) => FieldKind::Extension,
        TableProv::PublicFromShape => FieldKind::Base,
        TableProv::Committed { fixed_coords, extension_slice_coef } => {
            if *fixed_coords == 0 && !*extension_slice_coef {
                FieldKind::Base
            } else {
                FieldKind::Extension
            }
        }
    }
}

#[derive(Clone, Debug)]
pub(super) struct TableRef {
    pub id: TableId,
    pub kind: TableKind,
    /// what built it — see [`TableProv`]. The field kind is DERIVED from this
    /// and from nothing else (ruling I-2), which is why it is not a field.
    pub prov: TableProv,
    pub label: String,
}

impl TableRef {
    pub(super) fn field(&self) -> FieldKind {
        field_kind(&self.prov)
    }
}

/// Where a coefficient comes from. A later evaluator types its multiplication
/// from this and from nothing else, which is the whole point of recording it;
/// the export writes the VALUE only where the provenance says it is public
/// (see [`Coef::value_is_public`]).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum CoefProv {
    One,
    NegOne,
    /// a PUBLIC BASE-FIELD constant: a power of 256 from a byte-limb
    /// decomposition, a fixed-point shift, a norm constant, an int16 bias, a
    /// lookup's integer coefficient. `why` is the shape fact or the module
    /// constant that fixes it
    Base(&'static str),
    /// a challenge, or a fixed expression of challenges, drawn in `define`
    Challenge(&'static str),
    /// `mu[k]`, a zero-check's k-th batching challenge
    Mu(usize),
    /// `nu[k]`, the k-th hosted sub-claim's batching challenge
    Nu(usize),
    /// `zeta^j`, the pad rule's batching power — present only under `pad_on`
    Zeta(u32),
    /// a product of two provenances, e.g. `nu[0] * per_row`
    Product(Box<CoefProv>, Box<CoefProv>),
}

impl CoefProv {
    /// true when the coefficient's VALUE is a public constant of the shape, so
    /// the export may carry it. A challenge-dependent value never leaves this
    /// process.
    pub(super) fn value_is_public(&self) -> bool {
        match self {
            CoefProv::One | CoefProv::NegOne | CoefProv::Base(_) => true,
            CoefProv::Product(a, b) => a.value_is_public() && b.value_is_public(),
            _ => false,
        }
    }
    pub(super) fn label(&self) -> String {
        match self {
            CoefProv::One => "one".to_string(),
            CoefProv::NegOne => "neg-one".to_string(),
            CoefProv::Base(why) => format!("kbase:{why}"),
            CoefProv::Challenge(l) => format!("chal:{l}"),
            CoefProv::Mu(k) => format!("chal:mu[{k}]"),
            CoefProv::Nu(k) => format!("chal:nu[{k}]"),
            CoefProv::Zeta(j) => format!("chal:zeta^{j}"),
            CoefProv::Product(a, b) => format!("({} * {})", a.label(), b.label()),
        }
    }
}

/// A coefficient: the field element the evaluator multiplies by, and where it
/// came from.
#[derive(Clone, Debug)]
pub(super) struct Coef {
    pub value: Fp2,
    pub prov: CoefProv,
}

impl Coef {
    pub(super) fn one() -> Coef {
        Coef { value: Fp2::ONE, prov: CoefProv::One }
    }
    pub(super) fn neg_one() -> Coef {
        Coef { value: Fp2::ONE.neg(), prov: CoefProv::NegOne }
    }
    pub(super) fn zero() -> Coef {
        Coef { value: Fp2::ZERO, prov: CoefProv::Base("0") }
    }
    /// a public base-field constant
    pub(super) fn base(v: i64, why: &'static str) -> Coef {
        Coef { value: Fp2::from_i64(v), prov: CoefProv::Base(why) }
    }
    pub(super) fn chal(v: Fp2, label: &'static str) -> Coef {
        Coef { value: v, prov: CoefProv::Challenge(label) }
    }
    pub(super) fn mu(k: usize, v: Fp2) -> Coef {
        Coef { value: v, prov: CoefProv::Mu(k) }
    }
    pub(super) fn nu(k: usize, v: Fp2) -> Coef {
        Coef { value: v, prov: CoefProv::Nu(k) }
    }
    pub(super) fn zeta(j: u32, v: Fp2) -> Coef {
        Coef { value: v, prov: CoefProv::Zeta(j) }
    }
    pub(super) fn value_is_public(&self) -> bool {
        self.prov.value_is_public()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Factor {
    Table(TableId),
    Node(NodeId),
}

/// one summand of a [`NodeBody::Sum`]: a coefficient times a product of
/// factors. An empty factor list is the coefficient alone — the inhomogeneous
/// constant of a clause.
#[derive(Clone, Debug)]
pub(super) struct SubTerm {
    pub coef: Coef,
    pub factors: Vec<Factor>,
}

#[derive(Clone, Debug)]
pub(super) enum NodeBody {
    /// degree 1 (0 with no table term): `konst + sum_i coef_i * table_i`
    Affine { konst: Coef, terms: Vec<(Coef, TableId)> },
    /// degree = max over subterms of the sum of the factors' degrees
    Sum { subterms: Vec<SubTerm> },
}

#[derive(Clone, Debug)]
pub(super) struct Node {
    pub id: NodeId,
    pub label: String,
    pub body: NodeBody,
    /// COMPUTED by [`IrB::node`] from the body and the degrees of the nodes it
    /// refers to — never written by a caller, and re-derived independently by
    /// [`SlotIr::recompute_degrees`]
    pub degree: usize,
}

/// One top-level term: `coef * prod(wrapper) * prod(inner)`. `wrapper` is what
/// the term shares with its group — the zero-check's `eq(tau, .)` and, where
/// the term carries it, the pad support gate. Grouping by wrapper is the ONLY
/// reassociation a later evaluator is allowed to invent.
#[derive(Clone, Debug)]
pub(super) struct SlotTerm {
    pub coef: Coef,
    pub wrapper: Vec<TableId>,
    pub inner: Vec<Factor>,
    pub note: String,
}

/// One slot's polynomial at ONE shape. An IR is per shape: the pad rule's
/// tables and terms exist exactly where the shape's domain pads, so a reader
/// of the export no longer decides the branch — it reads it (the repair of
/// the memo's finding M-F1).
#[derive(Clone, Debug)]
pub(super) struct SlotIr {
    pub slot: usize,
    pub name: &'static str,
    pub kind: SlotKind,
    pub profile: String,
    pub main_rounds: usize,
    pub extension_rounds: usize,
    /// the DECLARED degree (`Shape::slots`), which is what the round message
    /// length is built from. [`SlotIr::max_term_degree`] is computed and may
    /// be lower (the memo's §1.4)
    pub degree: usize,
    /// whether this slot hosts a batched pad-zero term at this shape
    pub pad_on: bool,
    /// the bilinear slots' key-value group bits, `log2(kv_heads)`; `None` for
    /// every other slot, `Some(0)` where the shape has one key-value head and
    /// the group gate is therefore absent
    pub group_bits: Option<usize>,
    pub tables: Vec<TableRef>,
    pub nodes: Vec<Node>,
    pub terms: Vec<SlotTerm>,
}

// ---------------------------------------------------------------- the evaluator

impl SlotIr {
    /// **THE INTERPRETER (test-only, by the module's `cfg`).** The simplest
    /// correct evaluation of the graph at one cube point, given that point's
    /// table values — no common-subexpression pass, no reassociation, no
    /// specialisation by field kind. It exists to be compared against the
    /// closure, and a faster one is stage 2's problem.
    pub(super) fn eval(&self, v: &[Fp2]) -> Fp2 {
        let mut nv: Vec<Fp2> = Vec::with_capacity(self.nodes.len());
        for n in &self.nodes {
            let val = match &n.body {
                NodeBody::Affine { konst, terms } => terms.iter().fold(konst.value, |a, (c, t)| a.add(c.value.mul(v[*t as usize]))),
                NodeBody::Sum { subterms } => subterms.iter().fold(Fp2::ZERO, |a, s| {
                    let p = s.factors.iter().fold(s.coef.value, |p, f| p.mul(Self::factor_value(f, v, &nv)));
                    a.add(p)
                }),
            };
            nv.push(val);
        }
        self.terms.iter().fold(Fp2::ZERO, |a, t| {
            let mut p = t.coef.value;
            for w in &t.wrapper {
                p = p.mul(v[*w as usize]);
            }
            for f in &t.inner {
                p = p.mul(Self::factor_value(f, v, &nv));
            }
            a.add(p)
        })
    }

    fn factor_value(f: &Factor, v: &[Fp2], nv: &[Fp2]) -> Fp2 {
        match f {
            Factor::Table(t) => v[*t as usize],
            Factor::Node(n) => nv[*n as usize],
        }
    }

    /// the degree the graph actually attains, recomputed from the bodies —
    /// the memo's `max_term_degree`, which at slots 14 and 15 is one below the
    /// DECLARED degree (the check's §8, ruling I-7: recorded, not proposed)
    pub(super) fn max_term_degree(&self) -> usize {
        let d = self.recompute_degrees();
        self.terms.iter().map(|t| t.wrapper.len() + t.inner.iter().map(|f| Self::factor_degree(f, &d)).sum::<usize>()).max().unwrap_or(0)
    }

    /// every node's degree, walked from the bodies, so that the stored
    /// [`Node::degree`] can be asserted against an independent walk
    pub(super) fn recompute_degrees(&self) -> Vec<usize> {
        let mut d: Vec<usize> = Vec::with_capacity(self.nodes.len());
        for n in &self.nodes {
            let deg = match &n.body {
                NodeBody::Affine { terms, .. } => usize::from(!terms.is_empty()),
                NodeBody::Sum { subterms } => subterms.iter().map(|s| s.factors.iter().map(|f| Self::factor_degree(f, &d)).sum::<usize>()).max().unwrap_or(0),
            };
            d.push(deg);
        }
        d
    }

    fn factor_degree(f: &Factor, d: &[usize]) -> usize {
        match f {
            Factor::Table(_) => 1,
            Factor::Node(n) => d[*n as usize],
        }
    }

    /// how many tables of each kind, and how many the IR calls base-field
    pub(super) fn base_field_tables(&self) -> usize {
        self.tables.iter().filter(|t| t.field() == FieldKind::Base).count()
    }

    /// the flat product list a naive kernel would iterate — the memo's
    /// "monomials", counted by expanding every node
    pub(super) fn monomials(&self) -> usize {
        let mut m: Vec<usize> = Vec::with_capacity(self.nodes.len());
        for n in &self.nodes {
            let c = match &n.body {
                NodeBody::Affine { terms, .. } => terms.len().max(1),
                NodeBody::Sum { subterms } => subterms.iter().map(|s| s.factors.iter().map(|f| Self::factor_monomials(f, &m)).product::<usize>().max(1)).sum(),
            };
            m.push(c);
        }
        self.terms.iter().map(|t| t.inner.iter().map(|f| Self::factor_monomials(f, &m)).product::<usize>().max(1)).sum()
    }

    fn factor_monomials(f: &Factor, m: &[usize]) -> usize {
        match f {
            Factor::Table(_) => 1,
            Factor::Node(n) => m[*n as usize],
        }
    }

    pub(super) fn affine_forms(&self) -> usize {
        self.nodes.iter().filter(|n| matches!(n.body, NodeBody::Affine { .. })).count()
    }
    pub(super) fn sum_nodes(&self) -> usize {
        self.nodes.iter().filter(|n| matches!(n.body, NodeBody::Sum { .. })).count()
    }

    /// every node refers only to nodes already defined, and every table id is
    /// in range — the invariant the interpreter's single forward pass needs
    pub(super) fn is_well_formed(&self) -> Result<(), String> {
        let nt = self.tables.len() as u16;
        let check = |f: &Factor, upto: usize| -> Result<(), String> {
            match f {
                Factor::Table(t) if *t >= nt => Err(format!("slot {}: table {t} out of range", self.slot)),
                Factor::Node(n) if usize::from(*n) >= upto => Err(format!("slot {}: node {n} is not defined before its use", self.slot)),
                _ => Ok(()),
            }
        };
        for (i, n) in self.nodes.iter().enumerate() {
            match &n.body {
                NodeBody::Affine { terms, .. } => {
                    for (_, t) in terms {
                        check(&Factor::Table(*t), i)?;
                    }
                }
                NodeBody::Sum { subterms } => {
                    for s in subterms {
                        for f in &s.factors {
                            check(f, i)?;
                        }
                    }
                }
            }
        }
        for t in &self.terms {
            for w in &t.wrapper {
                check(&Factor::Table(*w), self.nodes.len())?;
            }
            for f in &t.inner {
                check(f, self.nodes.len())?;
            }
        }
        for (i, n) in self.nodes.iter().enumerate() {
            if usize::from(n.id) != i {
                return Err(format!("slot {}: node {i} carries id {}", self.slot, n.id));
            }
        }
        for (i, t) in self.tables.iter().enumerate() {
            if usize::from(t.id) != i {
                return Err(format!("slot {}: table {i} carries id {}", self.slot, t.id));
            }
        }
        Ok(())
    }
}

// ---------------------------------------------------------------- the builder

/// The IR builder: [`super::argument::B`]'s push order, with a `TableRef`
/// where the real builder has a `Tab`. Every method below mirrors one method
/// of that builder, and the mirror is checked by the oracle test rather than
/// asserted here.
struct IrB<'a> {
    lay: &'a Layout,
    tables: Vec<TableRef>,
    nodes: Vec<Node>,
    /// SHAPED plane id -> table index, filled by [`IrB::a_range`], exactly as
    /// `B::shaped` is
    shaped: Vec<usize>,
}

impl<'a> IrB<'a> {
    fn new(lay: &'a Layout) -> IrB<'a> {
        IrB { lay, tables: Vec::new(), nodes: Vec::new(), shaped: Vec::new() }
    }
    fn push(&mut self, kind: TableKind, prov: TableProv, label: String) -> TableId {
        let id = self.tables.len() as TableId;
        self.tables.push(TableRef { id, kind, prov, label });
        id
    }
    fn eq(&mut self, point_len: usize, start: usize, label: &str) -> TableId {
        self.push(TableKind::Eq { start, point_len }, TableProv::EqOfChallenges, format!("eq({label})"))
    }
    /// `B::group_eq`: no table at a shape with one key-value head
    fn group_eq(&mut self, bits: usize) -> Option<TableId> {
        if bits == 0 {
            return None;
        }
        Some(self.push(TableKind::GroupEq { bits }, TableProv::EqOfChallenges, format!("eq(r_g) over the leading {bits} variables")))
    }
    fn public_shape(&mut self, label: &str) -> TableId {
        self.push(TableKind::Public, TableProv::PublicFromShape, label.to_string())
    }
    fn public_chal(&mut self, why: &'static str, label: &str) -> TableId {
        self.push(TableKind::Public, TableProv::PublicWithChallenge(why), label.to_string())
    }
    /// `B::supp`: `Ok(None)` where this profile carries no pad rule or the
    /// domain does not pad — the same predicate, read off the same shape
    fn supp(&mut self, dom: Dom) -> Option<TableId> {
        let sh = self.lay.shape();
        if !sh.carries_pad_rule() || !sh.pads(dom) {
            return None;
        }
        Some(self.push(TableKind::Support { dom }, TableProv::PublicFromShape, format!("supp({dom:?})")))
    }
    /// `B::a`: a plane on its own domain, coordinates `Coord::Rho` only
    fn a(&mut self, plane: usize) -> TableId {
        self.push(TableKind::PlaneA, TableProv::Committed { fixed_coords: 0, extension_slice_coef: false }, format!("A[{plane}] on its own domain"))
    }
    /// `B::a_slice`: a sub-slice of a plane, coordinates `Coord::Rho` only
    fn a_slice(&mut self, label: &str) -> TableId {
        self.push(TableKind::PlaneA, TableProv::Committed { fixed_coords: 0, extension_slice_coef: false }, label.to_string())
    }
    /// `B::a_at` with `fixed_coords` `Coord::Fixed` entries in the claim point
    fn a_fixed(&mut self, plane: usize, fixed_coords: usize, label: &str) -> TableId {
        self.push(TableKind::PlaneA, TableProv::Committed { fixed_coords, extension_slice_coef: false }, format!("A[{plane}] at {label}"))
    }
    /// `B::a_range`: the SHAPED planes `first ..= last` in plane order,
    /// returning the TOY plane id -> table index map and filling `shaped`
    fn a_range(&mut self, first: usize, last: usize) -> Vec<usize> {
        let ids = self.lay.ids();
        let mut shaped = vec![usize::MAX; ids.n_a()];
        for p in first..=last {
            shaped[p] = usize::from(self.a(p));
        }
        let mut idx = vec![usize::MAX; N_A];
        for (p, slot) in idx.iter_mut().enumerate() {
            let q = ids.at(p);
            if (first..=last).contains(&q) {
                *slot = shaped[q];
            }
        }
        self.shaped = shaped;
        idx
    }
    fn tab(&self, plane: usize) -> usize {
        self.shaped[plane]
    }
    /// `B::h`: two slices, `(re, 1)` and `(im, u)` — the `u` is why an `H`
    /// column is extension-valued whatever its data holds
    fn h(&mut self, plane: usize) -> TableId {
        self.push(TableKind::HelperH, TableProv::Committed { fixed_coords: 0, extension_slice_coef: true }, format!("H[{plane}]"))
    }
    fn endpoint(&mut self, which: &str) -> TableId {
        self.push(TableKind::Endpoint, TableProv::Committed { fixed_coords: 0, extension_slice_coef: false }, format!("endpoint {which}"))
    }

    /// push a node, COMPUTING its degree from its body and the nodes it refers
    /// to. There is no way to push a node with a degree of one's own choosing.
    fn node(&mut self, label: String, body: NodeBody) -> NodeId {
        let deg = match &body {
            NodeBody::Affine { terms, .. } => usize::from(!terms.is_empty()),
            NodeBody::Sum { subterms } => subterms
                .iter()
                .map(|s| {
                    s.factors
                        .iter()
                        .map(|f| match f {
                            Factor::Table(_) => 1,
                            Factor::Node(n) => self.nodes[usize::from(*n)].degree,
                        })
                        .sum::<usize>()
                })
                .max()
                .unwrap_or(0),
        };
        let id = self.nodes.len() as NodeId;
        self.nodes.push(Node { id, label, body, degree: deg });
        id
    }
    fn affine(&mut self, label: String, konst: Coef, terms: Vec<(Coef, TableId)>) -> NodeId {
        self.node(label, NodeBody::Affine { konst, terms })
    }
    fn sum(&mut self, label: String, subterms: Vec<SubTerm>) -> NodeId {
        self.node(label, NodeBody::Sum { subterms })
    }
}

fn st(coef: Coef, factors: Vec<Factor>) -> SubTerm {
    SubTerm { coef, factors }
}
fn ft(t: TableId) -> Factor {
    Factor::Table(t)
}
fn fnd(n: NodeId) -> Factor {
    Factor::Node(n)
}

/// **THE PAD RULE'S BATCHED TERM, as IR.** `argument::PadTerm` evaluates
/// `mu_pad * sum_groups (1 - supp(x)) * sum_j zeta^j * plane_j(x)`, with the
/// `zeta` powers continuing ACROSS the groups of one slot so that a plane is
/// batched at one power and one only. This builds the same thing as two
/// affine nodes per group and one subterm per group, and returns the
/// subterms to be added to the slot's zero-check node — never to the LogUp
/// arm, which is a different group (the memo's §2.2, `argument.rs` §3.7a).
struct IrPad {
    mu: Coef,
    /// (support table, [(plane table, zeta power)])
    groups: Vec<(TableId, Vec<(TableId, u32)>)>,
    zeta: Fp2,
    used: u32,
}

impl IrPad {
    fn none() -> IrPad {
        IrPad { mu: Coef::zero(), groups: Vec::new(), zeta: Fp2::ZERO, used: 0 }
    }
    fn new(mu: Coef, zeta: Fp2) -> IrPad {
        IrPad { mu, groups: Vec::new(), zeta, used: 0 }
    }
    fn add(&mut self, supp: Option<TableId>, planes: &[usize]) {
        let Some(supp) = supp else { return };
        if planes.is_empty() {
            return;
        }
        let mut g = Vec::with_capacity(planes.len());
        for t in planes {
            g.push((*t as TableId, self.used));
            self.used += 1;
        }
        self.groups.push((supp, g));
    }
    fn subterms(&self, b: &mut IrB) -> Vec<SubTerm> {
        let mut out = Vec::new();
        for (supp, planes) in &self.groups {
            let anti = b.affine(format!("1 - supp[t{supp}]"), Coef::one(), vec![(Coef::neg_one(), *supp)]);
            let mut terms = Vec::with_capacity(planes.len());
            for (t, j) in planes {
                // `zeta^j`, the power `PadTerm::add` reaches by multiplying
                // once per plane already batched, across the groups of the slot
                let mut pw = Fp2::ONE;
                for _ in 0..*j {
                    pw = pw.mul(self.zeta);
                }
                terms.push((Coef::zeta(*j, pw), *t));
            }
            let inner = b.affine(format!("pad group under supp[t{supp}]"), Coef::zero(), terms);
            out.push(st(self.mu.clone(), vec![fnd(anti), fnd(inner)]));
        }
        out
    }
}

/// The points `argument::Points` carries from one slot to the next, as the IR
/// needs them: an `eq` table needs its point's LENGTH, and `lam_z` is the one
/// point entry that is a COEFFICIENT of a slot polynomial.
#[derive(Default, Clone, Debug)]
pub(super) struct IrPoints {
    r_t: usize,
    r_t2: usize,
    p_ht: usize,
    lam_z: Fp2,
    r_q: usize,
    pq: usize,
    pk: usize,
    pv: usize,
    p_s: usize,
    p_o: usize,
    p_a: usize,
    r_tf: usize,
    p_g: usize,
    p_u: usize,
    p_z: usize,
}

fn lg(v: usize) -> usize {
    debug_assert!(v.is_power_of_two(), "an axis that is not a power of two reached the IR");
    v.trailing_zeros() as usize
}

/// the LogUp helper relations of a domain, as IR: one `Affine` denominator
/// per lookup and one `Sum` per helper. `helper_sum` in `argument.rs` pairs
/// lookups `(2k, 2k + 1)` and leaves an odd last helper single, and the
/// relation is `h d1 d2 - (d1 + d2)` or `h d1 - 1`.
#[allow(clippy::too_many_arguments)]
fn logup_subterms(b: &mut IrB, dom: Dom, h0: TableId, alpha: Fp2, g_u8: Fp2, mu: &dyn Fn(usize) -> Coef, shaped: &[usize], tag: &str) -> Vec<SubTerm> {
    let lay = b.lay;
    let lks = lay.lookups(dom);
    let mut out = Vec::new();
    for k in 0..lks.len().div_ceil(2) {
        let den = |b: &mut IrB, l: &Lk, j: usize| -> NodeId {
            // `den = alpha - (cst + sum coef * plane)`, with the U8 tag folded
            // into `cst`: the constant is challenge-valued, every table
            // coefficient is a public integer of `layout::lookups_at`
            let konst = Coef::chal(alpha.sub(Fp2::from_i64(l.cst).add(g_u8)), "alpha - (lookup cst + g_u8)");
            let terms: Vec<(Coef, TableId)> = l
                .terms
                .iter()
                .map(|(p, c)| (Coef { value: Fp2::from_i64(-*c), prov: CoefProv::Base("a lookup's integer coefficient") }, shaped[*p] as TableId))
                .collect();
            b.affine(format!("den[{tag}:{j}]"), konst, terms)
        };
        let d1 = den(b, &lks[2 * k], 2 * k);
        let h = h0 + k as TableId;
        let rel = match lks.get(2 * k + 1) {
            Some(l2) => {
                let d2 = den(b, l2, 2 * k + 1);
                b.sum(format!("logup[{tag}:{k}]"), vec![st(Coef::one(), vec![ft(h), fnd(d1), fnd(d2)]), st(Coef::neg_one(), vec![fnd(d1)]), st(Coef::neg_one(), vec![fnd(d2)])])
            }
            None => b.sum(format!("logup[{tag}:{k}] (single)"), vec![st(Coef::one(), vec![ft(h), fnd(d1)]), st(Coef::neg_one(), vec![])]),
        };
        out.push(st(mu(k), vec![fnd(rel)]));
    }
    out
}

/// `sum_k v[ix[k]] * 256^k` — `argument::limbs`, as one affine node
fn limbs_node(b: &mut IrB, label: &str, ix: &[usize]) -> NodeId {
    let terms: Vec<(Coef, TableId)> = ix
        .iter()
        .enumerate()
        .map(|(k, i)| (Coef { value: pow256(k), prov: CoefProv::Base("a power of 256 of a byte-limb decomposition") }, *i as TableId))
        .collect();
    b.affine(label.to_string(), Coef::zero(), terms)
}

/// `at(o) + at(o + 1) * 256` — the `l2` of `SC_DZC` / `SC_FZC`
fn l2_node(b: &mut IrB, label: &str, idx: &[usize], o: usize) -> NodeId {
    limbs_node(b, label, &[idx[o], idx[o + 1]])
}

/// `at(o) + at(o + 1) * 256 + at(o + 2) * 65536` — the `l3` of `SC_TZC`
fn l3_node(b: &mut IrB, label: &str, o: usize) -> NodeId {
    limbs_node(b, label, &[o, o + 1, o + 2])
}

/// **THE BUILDER, arm by arm.** `slot` selects the same arm
/// `argument::define` selects, the challenges are drawn in the SAME ORDER and
/// the same counts (so a caller that runs this against a twin transcript gets
/// the same values), and the tables are pushed in the same order, so a table
/// id here is the `v[..]` index of the closure there.
pub(super) fn build_slot_ir(slot: usize, ctx: &Ctx, pts: &mut IrPoints, tr: &mut Transcript) -> Result<SlotIr, String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let (alpha, beta, g_u8, g_exp, g_act) = (ctx.alpha, ctx.beta, ctx.g_u8, ctx.g_exp, ctx.g_act);
    let mut b = IrB::new(lay);
    let (lt, lh, ldh) = (lg(sh.t_pad), lg(sh.h_pad), lg(sh.head_dim));
    let (ld, lf, lkv) = (lg(sh.d_pad), lg(sh.f_pad), lg(sh.kv_heads));
    let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());
    let pad_doms: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| super::pad::pad_zero_host(*d) == slot && !super::pad::zero_rule_a_planes(sh, ids, *d).is_empty()).collect();
    let pad_on = !pad_doms.is_empty();
    let n_pad = usize::from(pad_on);
    let (main_rounds, extension_rounds, degree) = sh.slots()[slot];
    let mut group_bits: Option<usize> = None;
    let (tables, nodes, terms) = match slot {
        SC_SS | SC_SSM => {
            let point = tr.challenge_fp2_vec(lt);
            if slot == SC_SS {
                pts.r_t = point.len();
            } else {
                pts.r_t2 = point.len();
            }
            let i_eq = b.eq(point.len(), 0, if slot == SC_SS { "r_t" } else { "r_t2" });
            let i_a = b.a(ids.at(if slot == SC_SS { A_X } else { A_X1 }));
            let g = b.supp(Dom::D);
            let term = SlotTerm {
                coef: Coef::one(),
                wrapper: g.into_iter().collect(),
                inner: vec![ft(i_eq), ft(i_a), ft(i_a)],
                note: "supp * eq(row point) * plane * plane: the private row sum of squares".to_string(),
            };
            (b.tables, b.nodes, vec![term])
        }
        SC_TZC => {
            let tau = tr.challenge_fp2_vec(lt);
            let mu = tr.challenge_fp2_vec(6 + n_pad);
            let nu = tr.challenge_fp2_vec(2);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_rt = b.eq(pts.r_t, 0, "r_t");
            let i_rt2 = b.eq(pts.r_t2, 0, "r_t2");
            let i_d = b.a(ids.at(A_D));
            let i_dsq = b.a(ids.at(A_DSQ));
            // the nine byte-limb SUB-SLICES of each limb plane, one table
            // each, in sub-plane order: D's three, a1's three, a2's three
            let i_limb = i_dsq + 1;
            for kk in 0..N_LIMBS {
                b.a_slice(&format!("A[{}] limb sub-slice {kk}", ids.at(A_LIMB)));
            }
            let i_dm = b.a(ids.at(A_DM));
            let i_dsqm = b.a(ids.at(A_DSQM));
            let i_limbm = i_dsqm + 1;
            for kk in 0..N_LIMBS {
                b.a_slice(&format!("A[{}] limb sub-slice {kk}", ids.at(A_LIMBM)));
            }
            let gt = b.supp(Dom::T);
            let mut pz = if pad_on { IrPad::new(Coef::mu(6, mu[6]), zeta) } else { IrPad::none() };
            if pad_on {
                let planes: Result<Vec<usize>, String> = super::pad::zero_rule_a_planes(sh, ids, Dom::T)
                    .iter()
                    .map(|p| match *p {
                        q if q == ids.at(A_D) => Ok(usize::from(i_d)),
                        q if q == ids.at(A_DSQ) => Ok(usize::from(i_dsq)),
                        q if q == ids.at(A_DM) => Ok(usize::from(i_dm)),
                        q if q == ids.at(A_DSQM) => Ok(usize::from(i_dsqm)),
                        q => Err(format!("private block IR: Dom::T plane {q} is outside SC_TZC's pad-zero group")),
                    })
                    .collect();
                pz.add(gt, &planes?);
            }
            let dl = l3_node(&mut b, "dl", usize::from(i_limb));
            let a1 = l3_node(&mut b, "a1", usize::from(i_limb) + 3);
            let a2 = l3_node(&mut b, "a2", usize::from(i_limb) + 6);
            let dlm = l3_node(&mut b, "dl_m", usize::from(i_limbm));
            let a1m = l3_node(&mut b, "a1_m", usize::from(i_limbm) + 3);
            let a2m = l3_node(&mut b, "a2_m", usize::from(i_limbm) + 6);
            let c0 = b.sum("c0: dsq - d^2".into(), vec![st(Coef::one(), vec![ft(i_dsq)]), st(Coef::neg_one(), vec![ft(i_d), ft(i_d)])]);
            let c1 = b.sum("c1: d - dl".into(), vec![st(Coef::one(), vec![ft(i_d)]), st(Coef::neg_one(), vec![fnd(dl)])]);
            let c2 = b.sum("c2: 2d - a1 - a2".into(), vec![st(Coef::base(2, "the doubling of the norm clause"), vec![ft(i_d)]), st(Coef::neg_one(), vec![fnd(a1)]), st(Coef::neg_one(), vec![fnd(a2)])]);
            let c3 = b.sum("c3: dsq_m - dm^2".into(), vec![st(Coef::one(), vec![ft(i_dsqm)]), st(Coef::neg_one(), vec![ft(i_dm), ft(i_dm)])]);
            let c4 = b.sum("c4: dm - dl_m".into(), vec![st(Coef::one(), vec![ft(i_dm)]), st(Coef::neg_one(), vec![fnd(dlm)])]);
            let c5 = b.sum("c5: 2dm - a1_m - a2_m".into(), vec![st(Coef::base(2, "the doubling of the norm clause"), vec![ft(i_dm)]), st(Coef::neg_one(), vec![fnd(a1m)]), st(Coef::neg_one(), vec![fnd(a2m)])]);
            let mut zc_terms: Vec<SubTerm> = (0..6).map(|k| st(Coef::mu(k, mu[k]), vec![fnd([c0, c1, c2, c3, c4, c5][k])])).collect();
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let host = |b: &mut IrB, lab: &str, dsq: TableId, a1: NodeId| {
                b.sum(lab.to_string(), vec![st(Coef::one(), vec![ft(dsq)]), st(Coef::one(), vec![fnd(a1)]), st(Coef::base(-NORM_CEPS, "NORM_CEPS"), vec![])])
            };
            let host_t = host(&mut b, "host SC_SS: dsq + a1 - NORM_CEPS", i_dsq, a1);
            let host_tm = host(&mut b, "host SC_SSM: dsq_m + a1_m - NORM_CEPS", i_dsqm, a1m);
            let gate: Vec<TableId> = gt.into_iter().collect();
            let terms = vec![
                SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the norm-squares zero-check".to_string() },
                SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_rt], gate.clone()].concat(), inner: vec![fnd(host_t)], note: "hosted SC_SS".to_string() },
                SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_rt2], gate].concat(), inner: vec![fnd(host_tm)], note: "hosted SC_SSM".to_string() },
            ];
            (b.tables, b.nodes, terms)
        }
        SC_LZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::L));
            let mu_pad = if pad_on { tr.challenge_fp2() } else { Fp2::ZERO };
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let i_tau = b.eq(tau.len(), 0, "tau");
            b.a_range(ids.at(A_LIMB), ids.at(A_LIMBM));
            let h0 = b.h(hids.first_helper(Dom::L));
            let shaped = b.shaped.clone();
            let mut pz = if pad_on { IrPad::new(Coef::chal(mu_pad, "this slot's pad weight (it draws no mu)"), zeta) } else { IrPad::none() };
            if pad_on {
                let si = b.supp(Dom::L);
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::L).iter().map(|p| b.tab(*p)).collect();
                pz.add(si, &planes);
            }
            let mut zc_terms = logup_subterms(&mut b, Dom::L, h0, alpha, g_u8, &|_k| Coef::one(), &shaped, "L");
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let terms = vec![SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the limb LogUp, batched with the all-ones weight".to_string() }];
            (b.tables, b.nodes, terms)
        }
        SC_RS => {
            let p_ht = tr.challenge_fp2_vec(sh.log(Dom::Ht));
            pts.p_ht = p_ht.len();
            pts.lam_z = tr.challenge_fp2();
            let lam = pts.lam_z;
            let i_eq = b.eq(p_ht.len(), 0, "p_ht");
            let i_mask = b.public_shape("causal mask over the Dom::S cube");
            let i_e = b.a(ids.at(A_E));
            let i_z = b.a(ids.at(A_ZSEL));
            let g = b.supp(Dom::S);
            let inner = b.sum("mask * e + lam_z * zsel".into(), vec![st(Coef::one(), vec![ft(i_mask), ft(i_e)]), st(Coef::chal(lam, "lam_z"), vec![ft(i_z)])]);
            let term = SlotTerm {
                coef: Coef::one(),
                wrapper: [g.into_iter().collect::<Vec<TableId>>(), vec![i_eq]].concat(),
                inner: vec![fnd(inner)],
                note: "supp * eq(p_ht) * (mask * e + lam_z * zsel): the masked softmax row sums".to_string(),
            };
            (b.tables, b.nodes, vec![term])
        }
        SC_QMM | SC_KMM | SC_VMM | SC_WO => {
            if slot == SC_QMM || slot == SC_WO {
                pts.r_q = tr.challenge_fp2_vec(lt).len();
            }
            let kvw = sh.kv_heads * sh.head_dim;
            let (plane, outer) = match slot {
                SC_QMM => (ids.at(A_Y), sh.d_pad),
                SC_KMM | SC_VMM => (ids.at(A_Y), kvw),
                _ => (ids.at(A_O8), sh.d_pad),
            };
            let r_j = tr.challenge_fp2_vec(lg(outer));
            let point = pts.r_q + r_j.len();
            let i_a = b.a_fixed(plane, pts.r_q, "(r_q fixed, rho)");
            let i_w = b.public_chal("the weight matrix folded against eq(r_j)", "fold_rows_i8(W, eq(r_j))");
            match slot {
                SC_QMM => pts.pq = point,
                SC_KMM => pts.pk = point,
                SC_VMM => pts.pv = point,
                _ => pts.p_a = point,
            }
            (b.tables, b.nodes, vec![SlotTerm { coef: Coef::one(), wrapper: vec![], inner: vec![ft(i_a), ft(i_w)], note: "plane * folded weight".to_string() }])
        }
        SC_SCORE => {
            let r_h = tr.challenge_fp2_vec(lh);
            let r_t = tr.challenge_fp2_vec(lt);
            let r_j = tr.challenge_fp2_vec(lt);
            pts.p_s = r_h.len() + r_t.len() + r_j.len();
            group_bits = Some(lkv);
            let ig = b.group_eq(lkv);
            // `A_QR8` on `Dom::Q = (t, head slot, c)`: the group SUMMED, the
            // within-group head FIXED (`r_t` and `r_hj` are the fixed parts)
            let iq = b.a_fixed(ids.at(A_QR8), lt + (lh - lkv), "(r_t fixed | group summed | r_hj fixed | c)");
            // `A_KR8` on `Dom::Kv = (j, group, c)`: the SAME summed group
            let ik = b.a_fixed(ids.at(A_KR8), lt, "(r_j fixed | group summed | c)");
            let term = SlotTerm {
                coef: Coef::one(),
                wrapper: ig.into_iter().collect(),
                inner: vec![ft(iq), ft(ik)],
                note: "eq(r_g) * the two private factors (the S19-F1 repair: the group is a sumcheck variable)".to_string(),
            };
            (b.tables, b.nodes, vec![term])
        }
        SC_PV => {
            let r_h = tr.challenge_fp2_vec(lh);
            let r_t = tr.challenge_fp2_vec(lt);
            let r_i = tr.challenge_fp2_vec(ldh);
            pts.p_o = r_t.len() + r_h.len() + r_i.len();
            group_bits = Some(lkv);
            let ig = b.group_eq(lkv);
            let ip = b.a_fixed(ids.at(A_P), (lh - lkv) + lt, "(group summed | r_hj fixed | r_t fixed | s)");
            let iv = b.a_fixed(ids.at(A_V8), ldh, "(s | group summed | r_i fixed)");
            let term = SlotTerm { coef: Coef::one(), wrapper: ig.into_iter().collect(), inner: vec![ft(ip), ft(iv)], note: "eq(r_g) * the two private factors".to_string() };
            (b.tables, b.nodes, vec![term])
        }
        SC_GMM | SC_UMM | SC_DMM => {
            if slot == SC_GMM {
                pts.r_tf = tr.challenge_fp2_vec(lt).len();
            }
            let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(lt).len() } else { pts.r_tf };
            let r_j = tr.challenge_fp2_vec(if slot == SC_DMM { ld } else { lf });
            let plane = match slot {
                SC_GMM | SC_UMM => ids.at(A_YM),
                _ => ids.at(A_H16),
            };
            let i_a = b.a_fixed(plane, r_row, "(row point fixed, rho)");
            let i_w = b.public_chal("the weight matrix folded against eq(r_j)", "fold_cols_i8(W, eq(r_j))");
            let point = r_row + r_j.len();
            match slot {
                SC_GMM => pts.p_g = point,
                SC_UMM => pts.p_u = point,
                _ => pts.p_z = point,
            }
            (b.tables, b.nodes, vec![SlotTerm { coef: Coef::one(), wrapper: vec![], inner: vec![ft(i_a), ft(i_w)], note: "plane * folded weight".to_string() }])
        }
        SC_DZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::D));
            let n_help = sh.helpers(Dom::D);
            let mu = tr.challenge_fp2_vec(11 + n_help + n_pad);
            let nu = tr.challenge_fp2_vec(2);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_pa = b.eq(pts.p_a, 0, "p_a");
            let i_pz = b.eq(pts.p_z, 0, "p_z");
            let ig = b.public_shape("gamma_a on the padded width (ruling P-2)");
            let igm = b.public_shape("gamma_m on the padded width (ruling P-2)");
            let idx = b.a_range(ids.at(A_X), ids.at(A_RDL));
            let i_nr: Vec<usize> = (0..ln).map(|kk| b.tab(ids.nr(kk))).collect();
            let i_ns: Vec<usize> = (0..ln).map(|kk| b.tab(ids.ns(kk))).collect();
            let i_mr: Vec<usize> = (0..ln).map(|kk| b.tab(ids.mr(kk))).collect();
            let i_ms: Vec<usize> = (0..ln).map(|kk| b.tab(ids.ms(kk))).collect();
            let id = b.a_slice(&format!("A[{}] (Dom::T) read on the row axis", ids.at(A_D)));
            let idm = b.a_slice(&format!("A[{}] (Dom::T) read on the row axis", ids.at(A_DM)));
            let h0 = b.h(hids.first_helper(Dom::D));
            for j in 1..n_help {
                b.h(hids.helper(Dom::D, j));
            }
            let shaped = b.shaped.clone();
            let gd = b.supp(Dom::D);
            let mut pz = if pad_on { IrPad::new(Coef::mu(11 + n_help, mu[11 + n_help]), zeta) } else { IrPad::none() };
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::D).iter().map(|p| b.tab(*p)).collect();
                pz.add(gd, &planes);
            }
            let at = |p: usize| idx[p] as TableId;
            let (k_num, k_dv, k_den) = (2 * NORM_CN, 1i64 << NORM_TN, 1i64 << (NORM_TN + 1));
            let nr = limbs_node(&mut b, "nr", &i_nr);
            let ns = limbs_node(&mut b, "ns", &i_ns);
            let mr = limbs_node(&mut b, "mr", &i_mr);
            let ms = limbs_node(&mut b, "ms", &i_ms);
            let l2x = l2_node(&mut b, "l2(x)", &idx, A_XL0);
            let l2a = l2_node(&mut b, "l2(ao)", &idx, A_AL0);
            let l2x1 = l2_node(&mut b, "l2(x1)", &idx, A_X1L0);
            let l2x2 = l2_node(&mut b, "l2(x2)", &idx, A_X2L0);
            let l2z = l2_node(&mut b, "l2(z16)", &idx, A_ZL0);
            let c0 = b.sum(
                "c0: 2 cn gamma_a x + 2^tn d - 2^(tn+1) y d - nr".into(),
                vec![
                    st(Coef::base(k_num, "2 * NORM_CN"), vec![ft(ig), ft(at(A_X))]),
                    st(Coef::base(k_dv, "2^NORM_TN"), vec![ft(id)]),
                    st(Coef::base(-k_den, "2^(NORM_TN+1)"), vec![ft(at(A_Y)), ft(id)]),
                    st(Coef::neg_one(), vec![fnd(nr)]),
                ],
            );
            let c1 = b.sum(
                "c1: ns + nr + 1 - 2^(tn+1) d".into(),
                vec![st(Coef::one(), vec![fnd(ns)]), st(Coef::one(), vec![fnd(nr)]), st(Coef::one(), vec![]), st(Coef::base(-k_den, "2^(NORM_TN+1)"), vec![ft(id)])],
            );
            let int16 = |b: &mut IrB, lab: &str, plane: TableId, l2: NodeId| {
                b.sum(lab.to_string(), vec![st(Coef::one(), vec![ft(plane)]), st(Coef::base(32768, "the int16 bias"), vec![]), st(Coef::neg_one(), vec![fnd(l2)])])
            };
            let c2 = int16(&mut b, "c2: x + 32768 - l2(x)", at(A_X), l2x);
            let c3 = int16(&mut b, "c3: ao + 32768 - l2(ao)", at(A_AO), l2a);
            let c4 = int16(&mut b, "c4: x1 + 32768 - l2(x1)", at(A_X1), l2x1);
            let c5 = b.sum("c5: x1 - x - ao".into(), vec![st(Coef::one(), vec![ft(at(A_X1))]), st(Coef::neg_one(), vec![ft(at(A_X))]), st(Coef::neg_one(), vec![ft(at(A_AO))])]);
            let c6 = b.sum(
                "c6: 2 cn gamma_m x1 + 2^tn dm - 2^(tn+1) nm dm - mr".into(),
                vec![
                    st(Coef::base(k_num, "2 * NORM_CN"), vec![ft(igm), ft(at(A_X1))]),
                    st(Coef::base(k_dv, "2^NORM_TN"), vec![ft(idm)]),
                    st(Coef::base(-k_den, "2^(NORM_TN+1)"), vec![ft(at(A_YM)), ft(idm)]),
                    st(Coef::neg_one(), vec![fnd(mr)]),
                ],
            );
            let c7 = b.sum(
                "c7: ms + mr + 1 - 2^(tn+1) dm".into(),
                vec![st(Coef::one(), vec![fnd(ms)]), st(Coef::one(), vec![fnd(mr)]), st(Coef::one(), vec![]), st(Coef::base(-k_den, "2^(NORM_TN+1)"), vec![ft(idm)])],
            );
            let c8 = int16(&mut b, "c8: x2 + 32768 - l2(x2)", at(A_X2), l2x2);
            let c9 = b.sum("c9: x2 - x1 - z16".into(), vec![st(Coef::one(), vec![ft(at(A_X2))]), st(Coef::neg_one(), vec![ft(at(A_X1))]), st(Coef::neg_one(), vec![ft(at(A_Z16))])]);
            let c10 = int16(&mut b, "c10: z16 + 32768 - l2(z16)", at(A_Z16), l2z);
            let cs = [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10];
            let clauses = b.sum("the eleven inhomogeneous clauses, batched".into(), (0..11).map(|k| st(Coef::mu(k, mu[k]), vec![fnd(cs[k])])).collect());
            let gate: Vec<TableId> = gd.into_iter().collect();
            let mut zc_terms = vec![st(Coef::one(), [gate.iter().map(|t| ft(*t)).collect::<Vec<Factor>>(), vec![fnd(clauses)]].concat())];
            zc_terms.extend(logup_subterms(&mut b, Dom::D, h0, alpha, g_u8, &|k| Coef::mu(11 + k, mu[11 + k]), &shaped, "D"));
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let host_wo = b.sum(
                "host SC_WO: 2^SH_AO ao + ral - 2^(SH_AO-1)".into(),
                vec![
                    st(Coef::base(1i64 << SH_AO, "2^SH_AO"), vec![ft(at(A_AO))]),
                    st(Coef::one(), vec![ft(at(A_RAL))]),
                    st(Coef::base(-(1i64 << (SH_AO - 1)), "2^(SH_AO-1)"), vec![]),
                ],
            );
            let host_dmm = b.sum(
                "host SC_DMM: 2^SH_Z z16 + rdl - 2^(SH_Z-1)".into(),
                vec![
                    st(Coef::base(1i64 << SH_Z, "2^SH_Z"), vec![ft(at(A_Z16))]),
                    st(Coef::one(), vec![ft(at(A_RDL))]),
                    st(Coef::base(-(1i64 << (SH_Z - 1)), "2^(SH_Z-1)"), vec![]),
                ],
            );
            let terms = vec![
                SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the width zero-check".to_string() },
                SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_pa], gate.clone()].concat(), inner: vec![fnd(host_wo)], note: "hosted SC_WO".to_string() },
                SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_pz], gate].concat(), inner: vec![fnd(host_dmm)], note: "hosted SC_DMM".to_string() },
            ];
            (b.tables, b.nodes, terms)
        }
        SC_FZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::F));
            let n_help = sh.helpers(Dom::F);
            let mu = tr.challenge_fp2_vec(4 + n_help + n_pad);
            let nu = tr.challenge_fp2_vec(2);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_pg = b.eq(pts.p_g, 0, "p_g");
            let i_pu = b.eq(pts.p_u, 0, "p_u");
            let idx = b.a_range(ids.at(A_G8), ids.at(A_RH1));
            let h0 = b.h(hids.first_helper(Dom::F));
            for j in 1..n_help {
                b.h(hids.helper(Dom::F, j));
            }
            let i_fact = b.h(hids.fact());
            let shaped = b.shaped.clone();
            let gf = b.supp(Dom::F);
            let mut pz = if pad_on { IrPad::new(Coef::mu(4 + n_help, mu[4 + n_help]), zeta) } else { IrPad::none() };
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::F).iter().map(|p| b.tab(*p)).collect();
                pz.add(gf, &planes);
            }
            let at = |p: usize| idx[p] as TableId;
            let l2rh = l2_node(&mut b, "l2(rh)", &idx, A_RH0);
            let l2u = l2_node(&mut b, "l2(u16)", &idx, A_UL0);
            let l2h = l2_node(&mut b, "l2(h16)", &idx, A_HL0);
            let f0 = b.sum(
                "f0: a16 u16 - 2^SH_H_PROD h16 - l2(rh) + 2^(SH_H_PROD-1)".into(),
                vec![
                    st(Coef::one(), vec![ft(at(A_A16)), ft(at(A_U16))]),
                    st(Coef::base(-(1i64 << SH_H_PROD), "2^SH_H_PROD"), vec![ft(at(A_H16))]),
                    st(Coef::neg_one(), vec![fnd(l2rh)]),
                    st(Coef::base(1i64 << (SH_H_PROD - 1), "2^(SH_H_PROD-1)"), vec![]),
                ],
            );
            let int16 = |b: &mut IrB, lab: &str, plane: TableId, l2: NodeId| {
                b.sum(lab.to_string(), vec![st(Coef::one(), vec![ft(plane)]), st(Coef::base(32768, "the int16 bias"), vec![]), st(Coef::neg_one(), vec![fnd(l2)])])
            };
            let f1 = int16(&mut b, "f1: u16 + 32768 - l2(u16)", at(A_U16), l2u);
            let f2 = int16(&mut b, "f2: h16 + 32768 - l2(h16)", at(A_H16), l2h);
            let act_den = b.affine(
                "alpha - (g8 + 128 + beta a16 + g_act)".into(),
                Coef::chal(alpha.sub(Fp2::from_i64(128)).sub(g_act), "alpha - 128 - g_act"),
                vec![(Coef::neg_one(), at(A_G8)), (Coef { value: beta.neg(), prov: CoefProv::Challenge("-beta") }, at(A_A16))],
            );
            let f_act = b.sum("f_act: the activation PAIR lookup, ungated".into(), vec![st(Coef::one(), vec![ft(i_fact), fnd(act_den)]), st(Coef::neg_one(), vec![])]);
            let clauses = b.sum("the three gated clauses, batched".into(), (0..3).map(|k| st(Coef::mu(k, mu[k]), vec![fnd([f0, f1, f2][k])])).collect());
            let gate: Vec<TableId> = gf.into_iter().collect();
            let mut zc_terms = vec![st(Coef::one(), [gate.iter().map(|t| ft(*t)).collect::<Vec<Factor>>(), vec![fnd(clauses)]].concat()), st(Coef::mu(3, mu[3]), vec![fnd(f_act)])];
            zc_terms.extend(logup_subterms(&mut b, Dom::F, h0, alpha, g_u8, &|k| Coef::mu(4 + k, mu[4 + k]), &shaped, "F"));
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let host_g = b.sum(
                "host SC_GMM: 2^SH_G g8 + rgl - 2^(SH_G-1)".into(),
                vec![st(Coef::base(1i64 << SH_G, "2^SH_G"), vec![ft(at(A_G8))]), st(Coef::one(), vec![ft(at(A_RGL))]), st(Coef::base(-(1i64 << (SH_G - 1)), "2^(SH_G-1)"), vec![])],
            );
            let terms = vec![
                SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the hidden-cube zero-check".to_string() },
                SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_pg], gate.clone()].concat(), inner: vec![fnd(host_g)], note: "hosted SC_GMM".to_string() },
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_pu], gate].concat(), inner: vec![ft(at(A_U16))], note: "hosted SC_UMM (SH_U = 0, so the host term is the plane)".to_string() },
            ];
            (b.tables, b.nodes, terms)
        }
        SC_QZC | SC_KVZC => {
            let q = slot == SC_QZC;
            let (dom, first, last, src) = if q { (Dom::Q, A_Q8, A_RO1, A_Q8) } else { (Dom::Kv, A_K8, A_RKRL, A_K8) };
            let log = sh.log(dom);
            let tau = tr.challenge_fp2_vec(log);
            let n_help = sh.helpers(dom);
            let mu = tr.challenge_fp2_vec(1 + n_help + n_pad);
            let nu = tr.challenge_fp2_vec(2);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_h1 = b.eq(if q { pts.pq } else { pts.pk }, 0, if q { "pq" } else { "pk" });
            let i_h2 = b.eq(if q { pts.p_o } else { pts.pv }, 0, if q { "p_o" } else { "pv" });
            let ic = b.public_shape("RoPE cos on the padded domain stride");
            let is = b.public_shape("RoPE sin on the padded domain stride");
            let idx = b.a_range(ids.at(first), ids.at(last));
            let i_src = idx[src] as TableId;
            let (i_rot, i_rot_rem) = if q { (idx[A_QR8] as TableId, idx[A_RQRL] as TableId) } else { (idx[A_KR8] as TableId, idx[A_RKRL] as TableId) };
            // the partner half at the FLIPPED most significant bit of i' (trap T-8)
            let iflip = b.a_fixed(ids.at(src), 0, "the RoPE partner half (Coord::Flip at log - log2(head_dim))");
            let h0 = b.h(hids.first_helper(dom));
            for j in 1..n_help {
                b.h(hids.helper(dom, j));
            }
            let shaped = b.shaped.clone();
            let gq = b.supp(dom);
            let mut pz = if pad_on { IrPad::new(Coef::mu(1 + n_help, mu[1 + n_help]), zeta) } else { IrPad::none() };
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, dom).iter().map(|p| b.tab(*p)).collect();
                pz.add(gq, &planes);
            }
            let at = |p: usize| idx[p] as TableId;
            let rope = b.sum(
                "rope: cos src + sin partner - 2^SH_ROPE rot - rot_rem + 2^(SH_ROPE-1)".into(),
                vec![
                    st(Coef::one(), vec![ft(ic), ft(i_src)]),
                    st(Coef::one(), vec![ft(is), ft(iflip)]),
                    st(Coef::base(-(1i64 << SH_ROPE), "2^SH_ROPE"), vec![ft(i_rot)]),
                    st(Coef::neg_one(), vec![ft(i_rot_rem)]),
                    st(Coef::base(1i64 << (SH_ROPE - 1), "2^(SH_ROPE-1)"), vec![]),
                ],
            );
            let gate: Vec<TableId> = gq.into_iter().collect();
            let mut zc_terms = vec![st(Coef::mu(0, mu[0]), [gate.iter().map(|t| ft(*t)).collect::<Vec<Factor>>(), vec![fnd(rope)]].concat())];
            zc_terms.extend(logup_subterms(&mut b, dom, h0, alpha, g_u8, &|k| Coef::mu(1 + k, mu[1 + k]), &shaped, if q { "Q" } else { "Kv" }));
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let half = 1i64 << (SH_QKV - 1);
            let (host1, host2) = if q {
                (
                    b.sum(
                        "host SC_QMM: 2^SH_QKV q8 + rql - 2^(SH_QKV-1)".into(),
                        vec![st(Coef::base(1i64 << SH_QKV, "2^SH_QKV"), vec![ft(at(A_Q8))]), st(Coef::one(), vec![ft(at(A_RQL))]), st(Coef::base(-half, "2^(SH_QKV-1)"), vec![])],
                    ),
                    b.sum(
                        "host SC_PV: 2^SH_O o8 + ro0 + 256 ro1 - 2^(SH_O-1)".into(),
                        vec![
                            st(Coef::base(1i64 << SH_O, "2^SH_O"), vec![ft(at(A_O8))]),
                            st(Coef::one(), vec![ft(at(A_RO0))]),
                            st(Coef { value: pow256(1), prov: CoefProv::Base("a power of 256 of a byte-limb decomposition") }, vec![ft(at(A_RO1))]),
                            st(Coef::base(-(1i64 << (SH_O - 1)), "2^(SH_O-1)"), vec![]),
                        ],
                    ),
                )
            } else {
                (
                    b.sum(
                        "host SC_KMM: 2^SH_QKV k8 + rkl - 2^(SH_QKV-1)".into(),
                        vec![st(Coef::base(1i64 << SH_QKV, "2^SH_QKV"), vec![ft(at(A_K8))]), st(Coef::one(), vec![ft(at(A_RKL))]), st(Coef::base(-half, "2^(SH_QKV-1)"), vec![])],
                    ),
                    b.sum(
                        "host SC_VMM: 2^SH_QKV v8 + rvl - 2^(SH_QKV-1)".into(),
                        vec![st(Coef::base(1i64 << SH_QKV, "2^SH_QKV"), vec![ft(at(A_V8))]), st(Coef::one(), vec![ft(at(A_RVL))]), st(Coef::base(-half, "2^(SH_QKV-1)"), vec![])],
                    ),
                )
            };
            let terms = vec![
                SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the RoPE zero-check".to_string() },
                SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_h1], gate.clone()].concat(), inner: vec![fnd(host1)], note: "the first hosted matmul".to_string() },
                SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_h2], gate].concat(), inner: vec![fnd(host2)], note: "the second hosted matmul".to_string() },
            ];
            (b.tables, b.nodes, terms)
        }
        SC_SZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::S));
            let n_help = sh.helpers(Dom::S);
            let mu = tr.challenge_fp2_vec(5 + n_help + 1 + n_pad);
            let nu = tr.challenge_fp2_vec(2);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let lam = pts.lam_z;
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_pht = b.eq(pts.p_ht, 0, "p_ht");
            let i_ps = b.eq(pts.p_s, 0, "p_s");
            let im = b.public_shape("causal mask over the Dom::S cube");
            let idx = b.a_range(ids.at(A_S8), ids.sg(ls - 1));
            let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
            let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
            let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
            let imx = b.a_slice(&format!("A[{}] (Dom::Ht) read on the leading coordinates", ids.at(A_MX)));
            let isum = b.a_slice(&format!("A[{}] (Dom::Ht) read on the leading coordinates", ids.at(A_SUM)));
            let h0 = b.h(hids.first_helper(Dom::S));
            for j in 1..n_help {
                b.h(hids.helper(Dom::S, j));
            }
            let ihx = b.h(hids.sexp());
            let shaped = b.shaped.clone();
            let ght = b.supp(Dom::Ht);
            let gs = b.supp(Dom::S);
            let mut pz = if pad_on { IrPad::new(Coef::mu(5 + n_help + 1, mu[5 + n_help + 1]), zeta) } else { IrPad::none() };
            if pad_on {
                if super::pad::zero_rule_a_planes(sh, ids, Dom::Ht) != vec![ids.at(A_MX), ids.at(A_SUM)] {
                    return Err("private block IR: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
                }
                pz.add(ght, &[usize::from(imx), usize::from(isum)]);
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::S).iter().map(|p| b.tab(*p)).collect();
                pz.add(gs, &planes);
            }
            let at = |p: usize| idx[p] as TableId;
            let sr = limbs_node(&mut b, "sr", &i_sr);
            let sg = limbs_node(&mut b, "sg", &i_sg);
            let pl = limbs_node(&mut b, "pl", &i_pl);
            let s8p = b.affine("s8 + 127".into(), Coef::base(-MASK_SCORE, "-MASK_SCORE"), vec![(Coef::one(), at(A_S8))]);
            let delta = b.sum(
                "delta: mx - mask (s8 + 127) + 127".into(),
                vec![st(Coef::one(), vec![ft(imx)]), st(Coef::neg_one(), vec![ft(im), fnd(s8p)]), st(Coef::base(-MASK_SCORE, "-MASK_SCORE"), vec![])],
            );
            let c0 = b.sum("c0: zsel^2 - zsel".into(), vec![st(Coef::one(), vec![ft(at(A_ZSEL)), ft(at(A_ZSEL))]), st(Coef::neg_one(), vec![ft(at(A_ZSEL))])]);
            let c1 = b.sum("c1: zsel * delta".into(), vec![st(Coef::one(), vec![ft(at(A_ZSEL)), fnd(delta)])]);
            let c2 = b.sum(
                "c2: 2^F_P mask e - p sum - sr".into(),
                vec![st(Coef::base(1i64 << F_P, "2^F_P"), vec![ft(im), ft(at(A_E))]), st(Coef::neg_one(), vec![ft(at(A_P)), ft(isum)]), st(Coef::neg_one(), vec![fnd(sr)])],
            );
            let c3 = b.sum("c3: sg + sr + 1 - sum".into(), vec![st(Coef::one(), vec![fnd(sg)]), st(Coef::one(), vec![fnd(sr)]), st(Coef::one(), vec![]), st(Coef::neg_one(), vec![ft(isum)])]);
            let c4 = b.sum("c4: p - pl".into(), vec![st(Coef::one(), vec![ft(at(A_P))]), st(Coef::neg_one(), vec![fnd(pl)])]);
            let ax = b.sum(
                "alpha - (delta + beta e + g_exp)".into(),
                vec![
                    st(Coef::chal(alpha.sub(g_exp), "alpha - g_exp"), vec![]),
                    st(Coef::neg_one(), vec![fnd(delta)]),
                    st(Coef { value: beta.neg(), prov: CoefProv::Challenge("-beta") }, vec![ft(at(A_E))]),
                ],
            );
            let cx = b.sum("cx: the exponential PAIR lookup, ungated".into(), vec![st(Coef::one(), vec![ft(ihx), fnd(ax)]), st(Coef::neg_one(), vec![])]);
            let clauses = b.sum("the five gated clauses, batched".into(), (0..5).map(|k| st(Coef::mu(k, mu[k]), vec![fnd([c0, c1, c2, c3, c4][k])])).collect());
            let gate: Vec<TableId> = gs.into_iter().collect();
            let mut zc_terms = vec![
                st(Coef::one(), [gate.iter().map(|t| ft(*t)).collect::<Vec<Factor>>(), vec![fnd(clauses)]].concat()),
                st(Coef::mu(5 + n_help, mu[5 + n_help]), vec![fnd(cx)]),
            ];
            zc_terms.extend(logup_subterms(&mut b, Dom::S, h0, alpha, g_u8, &|k| Coef::mu(5 + k, mu[5 + k]), &shaped, "S"));
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let host_rs = b.affine("host SC_RS: sum + lam_z".into(), Coef::chal(lam, "lam_z"), vec![(Coef::one(), isum)]);
            let host_s = b.sum(
                "host SC_SCORE: 2^SH_S s8 + rsl - 2^(SH_S-1)".into(),
                vec![st(Coef::base(1i64 << SH_S, "2^SH_S"), vec![ft(at(A_S8))]), st(Coef::one(), vec![ft(at(A_RSL))]), st(Coef::base(-(1i64 << (SH_S - 1)), "2^(SH_S-1)"), vec![])],
            );
            let terms = vec![
                SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the softmax zero-check".to_string() },
                // the LIFTED supp(Dom::Ht), never supp(Dom::S): the row-sum host
                // is constant in j and supp_S would force a true row's maximum
                // to zero (finding S9-F7). `per_row` is the HOSTED claim's
                // coefficient and does not enter the polynomial.
                SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_pht], ght.into_iter().collect()].concat(), inner: vec![fnd(host_rs)], note: "hosted SC_RS, under the lifted supp(Dom::Ht)".to_string() },
                SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_ps], gate].concat(), inner: vec![fnd(host_s)], note: "hosted SC_SCORE".to_string() },
            ];
            (b.tables, b.nodes, terms)
        }
        SC_TAB => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::Tab));
            let mu = tr.challenge_fp2_vec(3 + n_pad);
            let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] } else { Fp2::ZERO };
            let th = hids.table_helpers();
            let i_tau = b.eq(tau.len(), 0, "tau");
            b.a(ids.at(A_MU8));
            b.h(th[0]);
            // **FINDING IR-C1's twelfth table.** `table_values_u8_at` is
            // `k(i % 256) + g_u8` and `g_u8` is a challenge tag, so the U8
            // value column is extension-valued exactly as the exp and
            // activation columns are. The memo listed it as base-field.
            b.public_chal("the U8 tag g_u8", "the U8 table's value column");
            b.a(ids.at(A_MEXP));
            b.h(th[1]);
            b.public_chal("beta and the exp tag g_exp", "the exp table's value column");
            b.a(ids.at(A_MACT));
            b.h(th[2]);
            b.public_chal("beta and the activation tag g_act", "the activation table's value column");
            let mut pz = if pad_on { IrPad::new(Coef::mu(3, mu[3]), zeta) } else { IrPad::none() };
            if pad_on {
                let si = b.supp(Dom::Tab);
                super::argument::tab_group_is_declared(sh, ids, &[ids.at(A_MU8), ids.at(A_MEXP), ids.at(A_MACT)], &th)?;
                pz.add(si, &[1, 4, 7]);
                pz.add(si, &[2, 5, 8]);
            }
            let mut zc_terms: Vec<SubTerm> = Vec::new();
            for (k, (m, h, tv)) in [(1u16, 2u16, 3u16), (4, 5, 6), (7, 8, 9)].into_iter().enumerate() {
                let den = b.affine(format!("alpha - values[{k}]"), Coef::chal(alpha, "alpha"), vec![(Coef::neg_one(), tv)]);
                let rel = b.sum(format!("r{k}: h (alpha - values) - m"), vec![st(Coef::one(), vec![ft(h), fnd(den)]), st(Coef::neg_one(), vec![ft(m)])]);
                zc_terms.push(st(Coef::mu(k, mu[k]), vec![fnd(rel)]));
            }
            zc_terms.extend(pz.subterms(&mut b));
            let zc = b.sum("zc".into(), zc_terms);
            let terms = vec![SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the three byte tables' helper relations".to_string() }];
            (b.tables, b.nodes, terms)
        }
        SC_ZS => {
            let i_ones = b.public_shape("the all-ones vector over Dom::Tab");
            let i_u = b.h(hids.u());
            (b.tables, b.nodes, vec![SlotTerm { coef: Coef::one(), wrapper: vec![], inner: vec![ft(i_ones), ft(i_u)], note: "the zero-sum row".to_string() }])
        }
        SC_IO_IN | SC_IO_OUT => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::D));
            let i_tau = b.eq(tau.len(), 0, "tau");
            let i_a = b.a(ids.at(if slot == SC_IO_IN { A_X } else { A_X2 }));
            let i_ep = b.endpoint(if slot == SC_IO_IN { "in" } else { "out" });
            let d = b.sum("plane - endpoint".into(), vec![st(Coef::one(), vec![ft(i_a)]), st(Coef::neg_one(), vec![ft(i_ep)])]);
            (b.tables, b.nodes, vec![SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(d)], note: "the endpoint equality".to_string() }])
        }
        _ => return Err("private block IR: unknown slot".into()),
    };
    let ir = SlotIr {
        slot,
        name: SLOT_NAMES[slot],
        kind: SLOT_KINDS[slot],
        profile: sh.profile.to_string(),
        main_rounds,
        extension_rounds,
        degree,
        pad_on,
        group_bits,
        tables,
        nodes,
        terms,
    };
    ir.is_well_formed()?;
    Ok(ir)
}
