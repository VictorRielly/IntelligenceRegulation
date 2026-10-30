//! True-piece repacking of the unchanged R13 integer witness. Histograms
//! are rebuilt globally before A; no partial accumulator is introduced.
use super::accuracy_public::AccuracyPublic;
use super::layout::*;
use super::split_geometry::gather_numeric_plane;
use super::split_layout::Part;
use super::split_profile::SplitProfile;
use super::witness::Witness;
use crate::field::Fp;

pub(crate) struct PieceWitness {
    pub planes: Vec<Vec<i64>>,
}

impl PieceWitness {
    pub(crate) fn from_reference(p: &SplitProfile, witness: Witness) -> Result<Self, String> {
        let sh = p.base();
        let layout = p.layout();
        let ids = Ids::new(sh)?;
        if witness.planes.len() != ids.n_a() {
            return Err("R14 witness: logical role count differs".into());
        }
        let mut planes = vec![Vec::new(); layout.a.len()];
        // Consume reference roles in order so each padded buffer dies after
        // its true pieces are gathered. Histogram placeholders stay empty.
        for (parent, words) in witness.planes.into_iter().enumerate() {
            if ids.is_multiplicity(parent) {
                if !words.is_empty() {
                    return Err("R14 witness: caller supplied a derived histogram".into());
                }
                continue;
            }
            for (physical, data) in gather_numeric_plane(sh, layout, parent, &words)? {
                planes[physical] = data;
            }
        }
        Ok(Self { planes })
    }
    pub(crate) fn plane<'a>(
        &'a self,
        p: &SplitProfile,
        parent: usize,
        part: Part,
    ) -> Result<&'a [i64], String> {
        let physical = p
            .layout()
            .a
            .iter()
            .position(|v| v.parent == parent && v.part == part)
            .ok_or("R14 witness: undeclared source")?;
        let values = self
            .planes
            .get(physical)
            .ok_or("R14 witness: missing source role")?;
        if values.len() != 1usize << p.layout().a[physical].log {
            return Err("R14 witness: source length differs".into());
        }
        Ok(values)
    }
    pub(crate) fn lookup_column(
        &self,
        p: &SplitProfile,
        dom: Dom,
        part: Part,
        index: usize,
    ) -> Result<Vec<i64>, String> {
        let ids = Ids::new(p.base())?;
        let lookups = lookups_at(p.base(), &ids, dom);
        let lookup = lookups.get(index).ok_or("R14 lookup: undeclared column")?;
        let len = match dom {
            Dom::D => p.base().tokens * p.layout().d[usize::from(part == Part::Narrow)].width,
            Dom::F => p.base().tokens * p.layout().f[usize::from(part == Part::Narrow)].width,
            _ => p.base().size(dom),
        };
        if (matches!(dom, Dom::D | Dom::F)) == (part == Part::Whole) {
            return Err("R14 lookup: wrong piece kind for domain".into());
        }
        let terms = lookup
            .terms
            .iter()
            .map(|&(parent, coef)| self.plane(p, parent, part).map(|v| (v, coef)))
            .collect::<Result<Vec<_>, _>>()?;
        (0..len)
            .map(|i| {
                let value = terms.iter().fold(lookup.cst as i128, |a, (v, c)| {
                    a + v[i] as i128 * (*c as i128)
                });
                i64::try_from(value).map_err(|_| "R14 lookup: query integer overflow".into())
            })
            .collect()
    }
    pub(crate) fn byte_histogram(&self, p: &SplitProfile) -> Result<Vec<u64>, String> {
        let ids = Ids::new(p.base())?;
        let mut counts = vec![0u64; 256];
        for dom in p.base().lookup_doms() {
            let pieces = if matches!(dom, Dom::D | Dom::F) {
                vec![Part::Wide, Part::Narrow]
            } else {
                vec![Part::Whole]
            };
            for part in pieces {
                for column in 0..lookups_at(p.base(), &ids, dom).len() {
                    for value in self.lookup_column(p, dom, part, column)? {
                        let bucket = usize::try_from(value)
                            .ok()
                            .filter(|&v| v < 256)
                            .ok_or("R14 witness: byte lookup miss")?;
                        counts[bucket] += 1;
                    }
                }
            }
        }
        Ok(counts)
    }
    pub(crate) fn act_histogram(
        &self,
        p: &SplitProfile,
        data: &AccuracyPublic,
    ) -> Result<Vec<u64>, String> {
        let ids = Ids::new(p.base())?;
        let mut counts = vec![0u64; 4096 * data.groups().len()];
        for (piece, part) in [Part::Wide, Part::Narrow].into_iter().enumerate() {
            let e = p.layout().f[piece];
            let gates = self.plane(p, ids.at(A_G8), part)?;
            let outputs = self.plane(p, ids.at(A_A16), part)?;
            for (i, (&gate, &output)) in gates.iter().zip(outputs).enumerate() {
                let group = data.group_ids()[e.start + i % e.width];
                let key = gate
                    .checked_add(2048)
                    .filter(|&v| (0..4096).contains(&v))
                    .ok_or("R14 witness: ACT3 input miss")? as usize;
                // Match the existing R13 malicious-prover fixture: only this
                // host-side miss check can be bypassed in tests. The native
                // lookup identity, global key, commitments and verifier stay on.
                #[cfg(test)]
                let check_output = !super::protocol::cheating_prover_is_on();
                #[cfg(not(test))]
                let check_output = true;
                if check_output && data.scaled_tables()[group][key] != output {
                    return Err("R14 witness: ACT3 output miss".into());
                }
                counts[group * 4096 + key] += 1;
            }
        }
        Ok(counts)
    }
    pub(crate) fn set_histograms(
        &mut self,
        p: &SplitProfile,
        counts: [&[u64]; 3],
    ) -> Result<(), String> {
        let ids = Ids::new(p.base())?;
        let length = p.base().size(Dom::Tab);
        for (parent, count) in [ids.at(A_MU8), ids.at(A_MEXP), ids.at(A_MACT)]
            .into_iter()
            .zip(counts)
        {
            let physical = p
                .layout()
                .a
                .iter()
                .position(|v| v.parent == parent && v.part == Part::Whole)
                .ok_or("R14 histogram: absent role")?;
            if count.len() > length || !self.planes[physical].is_empty() {
                return Err("R14 histogram: oversized or already installed".into());
            }
            let mut words = count
                .iter()
                .map(|&v| i64::try_from(v).map_err(|_| "R14 histogram: count overflow".to_string()))
                .collect::<Result<Vec<_>, _>>()?;
            words.resize(length, 0);
            self.planes[physical] = words;
        }
        Ok(())
    }
    pub(crate) fn write_a_data(&self, p: &SplitProfile) -> Result<Vec<Fp>, String> {
        let s = p.layout();
        let mut words = vec![Fp::ZERO; s.a_rows * s.n];
        for (plane, values) in s.a.iter().zip(&self.planes) {
            if values.len() != 1usize << plane.log {
                return Err("R14 witness: missing or foreign physical plane".into());
            }
            for (i, &v) in values.iter().enumerate() {
                words[plane.offset + i] = Fp::from_i64(v);
            }
        }
        Ok(words)
    }
}
