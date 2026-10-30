//! R13 public int12 SiLU tables, not yet imported into
//! the prover. Every output word is compared with an independent reference.

pub(crate) const SILU_MEMBERS: [(i32, i32); 9] = [
    (-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11),
    (-2, -11), (-1, -11), (-1, -10), (-1, -9),
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Registry { Standard, Shieldstral }
impl Registry {
    pub(crate) fn name(self) -> &'static str { match self { Self::Standard=>"standard-int12-v1",Self::Shieldstral=>"shieldstral-int12-v1" } }
    pub(crate) fn permits(self,member:(i32,i32)) -> bool { SILU_MEMBERS.contains(&member) || (self==Self::Shieldstral && member==(0,-8)) }
    pub(crate) fn scaled_exponents(self) -> std::ops::RangeInclusive<i64> { match self {Self::Standard=>4..=15,Self::Shieldstral=>3..=16} }
    pub(crate) fn product_shifts(self) -> std::ops::RangeInclusive<i64> { match self {Self::Standard=>1..=12,Self::Shieldstral=>0..=13} }
    pub(crate) fn scaled_abs(self) -> i64 { 32767 * (1i64 << if self==Self::Shieldstral {16} else {15}) }
}

// The standard nine members retain their existing quantization exactly.
pub(crate) fn silu_table_for(registry: Registry, e_in: i32, e_out: i32, input_bits: u32) -> Result<Vec<i16>, String> {
    if input_bits != 12 || !registry.permits((e_in, e_out)) {
        return Err("R13 SiLU: int12 input and a member of the profile registry required".into());
    }
    if SILU_MEMBERS.contains(&(e_in, e_out)) {
        return silu_table(e_in, e_out, input_bits);
    }
    // Only the Shieldstral (0,-8) member reaches this path. No saturation is
    // allowed for this member; an out-of-range output is an error.
    (-2048..2048).map(|gate| {
        let x = gate as f64 / 16.0;
        let word = (256.0 * x / (1.0 + (-x).exp()) + 0.5).floor();
        if !word.is_finite() || !(-32767.0..=32767.0).contains(&word) {
            return Err("R13 Shieldstral SiLU: generated word exceeds signed16".into());
        }
        Ok(word as i16)
    }).collect()
}

pub(crate) fn silu_table(e_in: i32, e_out: i32, input_bits: u32) -> Result<Vec<i16>, String> {
    if input_bits != 12 || !SILU_MEMBERS.contains(&(e_in, e_out)) {
        return Err("R13 SiLU: int12 input and a registered member required".into());
    }
    let step = 2.0f64.powi(e_in - 4);
    let output_step = 2.0f64.powi(e_out);
    Ok((-2048..2048).map(|gate| {
        let x = gate as f64 * step;
        let value = x / (1.0 + (-x).exp());
        (value / output_step + 0.5).floor().clamp(-32767.0, 32767.0) as i16
    }).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_int12_silu_word_matches_the_independent_reference() {
        let fixtures: [&[u8]; 9] = [
            include_bytes!("r13_vectors/silu_-5_-13.bin"),
            include_bytes!("r13_vectors/silu_-4_-13.bin"),
            include_bytes!("r13_vectors/silu_-4_-12.bin"),
            include_bytes!("r13_vectors/silu_-3_-12.bin"),
            include_bytes!("r13_vectors/silu_-3_-11.bin"),
            include_bytes!("r13_vectors/silu_-2_-11.bin"),
            include_bytes!("r13_vectors/silu_-1_-11.bin"),
            include_bytes!("r13_vectors/silu_-1_-10.bin"),
            include_bytes!("r13_vectors/silu_-1_-9.bin"),
        ];
        for ((e_in, e_out), fixture) in SILU_MEMBERS.into_iter().zip(fixtures) {
            let table = silu_table(e_in, e_out, 12).unwrap();
            assert_eq!(table.len(), 4096);
            for (index, bytes) in fixture.chunks_exact(2).enumerate() {
                let expected = i16::from_le_bytes([bytes[0], bytes[1]]);
                assert_eq!(table[index], expected, "member ({e_in},{e_out}), gate {}", index as i32 - 2048);
            }
        }
    }

    #[test]
    fn zero_and_signed_index_are_unambiguous() {
        for (e_in, e_out) in SILU_MEMBERS {
            let table = silu_table(e_in, e_out, 12).unwrap();
            assert_eq!(table[2048], 0);
            assert!(table[2049] > 0);
            assert!(table.iter().all(|&v| (-32767..=32767).contains(&v)));
        }
    }

    #[test]
    fn unsupported_members_and_precisions_are_refused() {
        for (e_in, e_out) in [(-6, -13), (-5, -12), (0, -9), (-1, -8)] {
            assert!(silu_table(e_in, e_out, 12).is_err());
        }
        for bits in [0, 8, 11, 13, 32, u32::MAX] {
            assert!(silu_table(-5, -13, bits).is_err());
        }
    }
}

#[cfg(test)]
mod shieldstral_tests {
    use super::*;
    #[test]
    fn shieldstral_member_matches_all_4096_independent_words_without_clipping() {
        let raw=include_bytes!("r13_vectors/silu_0_-8.bin");
        let table=silu_table_for(Registry::Shieldstral,0,-8,12).unwrap();
        assert_eq!(table.len(),4096);
        for (i,bytes) in raw.chunks_exact(2).enumerate() {assert_eq!(table[i],i16::from_le_bytes([bytes[0],bytes[1]]),"gate {}",i as i32-2048);}
        assert_eq!((*table.iter().min().unwrap(),*table.iter().max().unwrap()),(-71,32752));
    }
    #[test]
    fn standard_registry_and_unknown_members_remain_refused() {
        assert!(silu_table(0,-8,12).is_err());
        assert!(silu_table_for(Registry::Standard,0,-8,12).is_err());
        for member in [(0,-9),(0,-7),(1,-8),(-2,-8)] {assert!(silu_table_for(Registry::Shieldstral,member.0,member.1,12).is_err());}
        assert!(silu_table_for(Registry::Shieldstral,0,-8,8).is_err());
    }
    #[test]
    fn every_existing_member_is_byte_identical_in_both_registries() {
        for (i,o) in SILU_MEMBERS {assert_eq!(silu_table_for(Registry::Shieldstral,i,o,12).unwrap(),silu_table(i,o,12).unwrap());}
    }
}
