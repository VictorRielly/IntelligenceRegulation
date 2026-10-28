//! R13 public int12 SiLU tables, not yet imported into
//! the prover. Every output word is compared with an independent reference.

pub(crate) const SILU_MEMBERS: [(i32, i32); 9] = [
    (-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11),
    (-2, -11), (-1, -11), (-1, -10), (-1, -9),
];

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
