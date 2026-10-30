//! Opt-in metadata-only inventory of EXECUTED attention argument sites.
//! This is not a proof, privacy guarantee, or opening-group/rank analysis.
//! No field elements, evaluations, challenge coordinates, histogram entries,
//! witness values/digests, roots, or timings enter this API. A trace still
//! reveals the public execution shape; keep experimental diagnostics local.
use std::cell::RefCell;
use std::marker::PhantomData;
use std::rc::Rc;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Event {
    pub kind: &'static str,
    pub role: &'static str,
    pub site: &'static str,
    /// Fixed field names; values are public offsets, logs, lengths or indexes.
    pub fields: Vec<(&'static str, usize)>,
}
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Trace {
    pub events: Vec<Event>,
}
#[derive(Clone, Copy, Debug)]
pub enum FixedReference {
    PublicProve,
    PublicReplay,
    Shared,
}
struct State {
    role: &'static str,
    trace: Trace,
}
thread_local! { static STATE: RefCell<Option<State>> = const { RefCell::new(None) }; }

/// Calling-thread capture: Rayon workers are deliberately not aggregated.
/// Scope this around a successful operation; a partial failure is not coverage.
pub struct Capture {
    active: bool,
    _local: PhantomData<Rc<()>>,
}
impl Capture {
    pub fn begin(enabled: bool) -> Result<Self, &'static str> {
        if enabled {
            STATE.with(|s| {
                let mut s = s.borrow_mut();
                if s.is_some() {
                    return Err("attention schedule capture already active");
                }
                *s = Some(State {
                    role: "outside",
                    trace: Trace::default(),
                });
                Ok(())
            })?;
        }
        Ok(Self {
            active: enabled,
            _local: PhantomData,
        })
    }
    pub fn finish(mut self) -> Trace {
        if !self.active {
            return Trace::default();
        }
        self.active = false;
        STATE.with(|s| s.borrow_mut().take().map(|s| s.trace).unwrap_or_default())
    }
}
impl Drop for Capture {
    fn drop(&mut self) {
        if self.active {
            STATE.with(|s| {
                s.borrow_mut().take();
            });
        }
    }
}
pub(crate) fn enabled() -> bool {
    STATE.with(|s| s.borrow().is_some())
}
pub(crate) fn role(role: &'static str) {
    STATE.with(|s| {
        if let Some(s) = s.borrow_mut().as_mut() {
            s.role = role;
            s.trace.events.push(Event {
                kind: "role",
                role,
                site: role,
                fields: vec![],
            });
        }
    });
}
pub(crate) fn record(kind: &'static str, site: &'static str, fields: &[(&'static str, usize)]) {
    STATE.with(|s| {
        if let Some(s) = s.borrow_mut().as_mut() {
            s.trace.events.push(Event {
                kind,
                role: s.role,
                site,
                fields: fields.to_vec(),
            });
        }
    });
}
impl Trace {
    /// Frozen A00/B3 public T32/d16/f16 H2/KV1 reference, default folding,
    /// one internal FFN seam and B3's tiny short-W adapter. Not general A00
    /// acceptance: different calibration/limbs/branches need separate review.
    /// A matching metadata trace says nothing about proof validity or privacy.
    pub fn check_fixed_reference(&self, side: FixedReference) -> Result<(), &'static str> {
        let expected = match side {
            FixedReference::PublicProve => {
                "990fbb5a199e8e59aff18e606be729e0a8c4547fb63f9078630aa710dbd32162"
            }
            FixedReference::PublicReplay => {
                "1ce8017710e21fc9c098d0d7513aef3239d02731ab0f26d764c50ac8a4b66429"
            }
            FixedReference::Shared => {
                "2d8d3be42c90b66dfa61af40b338effad3741fd8832dc2f54274a2db4751c7ce"
            }
        };
        if self.fingerprint() == expected {
            Ok(())
        } else {
            Err("unreviewed fixed attention schedule")
        }
    }
    /// Exact ordered comparison: missing/extra/reordered hooks or changed
    /// offsets/counts fail. The expected trace must be independently reviewed,
    /// never silently regenerated from the candidate run and treated as approval.
    pub fn ensure_matches(&self, expected: &Self) -> Result<(), &'static str> {
        if self.events.is_empty() || self != expected {
            Err("attention schedule mismatch")
        } else {
            Ok(())
        }
    }
    /// Several terminal checks execute only on replay; helper construction
    /// executes only on proving. Retain both full side-specific traces too.
    pub fn shared(&self) -> Self {
        Self {
            events: self
                .events
                .iter()
                .filter(|e| e.kind != "check" && e.kind != "helper_build")
                .cloned()
                .collect(),
        }
    }
    pub fn count(&self, kind: &str) -> usize {
        self.events.iter().filter(|e| e.kind == kind).count()
    }
    /// Stable framed public-metadata encoding. Hashing this is NOT a witness
    /// digest or a substitute for the statement/transcript's own binding.
    pub fn fingerprint(&self) -> String {
        fn text(out: &mut Vec<u8>, value: &str) {
            out.extend_from_slice(&(value.len() as u64).to_le_bytes());
            out.extend_from_slice(value.as_bytes());
        }
        let mut out = b"hashline-attention-schedule-v1".to_vec();
        out.extend_from_slice(&(self.events.len() as u64).to_le_bytes());
        for e in &self.events {
            for s in [e.kind, e.role, e.site] {
                text(&mut out, s);
            }
            out.extend_from_slice(&(e.fields.len() as u64).to_le_bytes());
            for (name, value) in &e.fields {
                text(&mut out, name);
                out.extend_from_slice(&(*value as u64).to_le_bytes());
            }
        }
        blake3::hash(&out).to_hex().to_string()
    }
    /// Human-readable metadata only; field/debug formatting has no tensors.
    pub fn listing(&self) -> String {
        self.events
            .iter()
            .enumerate()
            .map(|(i, e)| {
                format!(
                    "{i:04} {} / {} / {} {:?}\n",
                    e.role, e.kind, e.site, e.fields
                )
            })
            .collect()
    }
}

/// Record lookup/range and histogram SHAPES from the actual argument layout.
/// This deliberately does not walk multiplicity counts or nonzero entries.
pub(crate) fn lookup_layout(
    lay: &crate::attention::AttnLayout,
    c: &crate::attention::AttnConsts,
    fc: &crate::attention::FullConsts,
) {
    if !enabled() {
        return;
    }
    use crate::attention::{d_lookups, kv_lookups, lookup_totals, q_lookups, tbl_of_tag, Tbl};
    for (site, (offsets, tables), log) in [
        ("D ranges", d_lookups(lay, c, fc), lay.log_d),
        ("Q ranges", q_lookups(lay, c), lay.log_q),
        ("KV ranges", kv_lookups(lay, c), lay.log_kv),
    ] {
        for (index, (offset, table)) in offsets.iter().zip(&tables).enumerate() {
            record(
                "lookup",
                site,
                &[
                    ("index", index),
                    ("offset", *offset),
                    ("log", log as usize),
                    ("length", 1usize << log),
                    ("tag", table.tag() as usize),
                    ("table_rows", table.rows(c.f_p)),
                ],
            );
        }
    }
    // S and packed-limb descriptors correspond to the special helper branches
    // (unlike D/Q/KV, these do not use the paired lookup-list helpers).
    for (site, offset, log, table) in [
        ("score range", lay.s8, lay.log_s, Tbl::Int8),
        ("score remainder", lay.rs, lay.log_s, Tbl::Win(c.sh_s)),
        ("exp fused relation", lay.et, lay.log_s, Tbl::Exp),
        ("probability range", lay.pp, lay.log_s, Tbl::Prob),
        (
            "softmax rho range",
            lay.rho_s,
            lay.log_s,
            Tbl::Srem(c.wrho_s),
        ),
        ("packed norm limbs", lay.lm, lay.log_lm, Tbl::U16),
    ] {
        record(
            "lookup_special",
            site,
            &[
                ("offset", offset),
                ("log", log as usize),
                ("length", 1usize << log),
                ("tag", table.tag() as usize),
            ],
        );
    }
    record(
        "lookup_derived",
        "softmax sigma=Sum-1-rho",
        &[
            ("sum_offset", lay.sm_sum()),
            ("rho_offset", lay.rho_s),
            ("log", lay.log_s as usize),
            ("tag", Tbl::Srem(c.wrho_s).tag() as usize),
        ],
    );
    for (tag, total) in lookup_totals(lay, c, fc) {
        let table = tbl_of_tag(tag, c, fc, lay).expect("layout table");
        record(
            "histogram_shape",
            "required table",
            &[
                ("tag", tag as usize),
                ("table_rows", table.rows(c.f_p)),
                ("required_total", total as usize),
            ],
        );
    }
}
