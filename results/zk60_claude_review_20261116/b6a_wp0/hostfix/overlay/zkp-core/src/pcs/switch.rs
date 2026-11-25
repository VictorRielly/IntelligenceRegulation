//! Generator claims for the B6a code switch at fixed, ordered PCS samples.

use std::collections::BTreeMap;

use crate::field::{batch_inverse, Fp, Fp2};
use crate::ntt::NttTables;
use rayon::prelude::*;

#[derive(Clone, Copy, Debug)]
pub(crate) struct WeightedPoint {
    pub point: Fp,
    pub weight: Fp2,
}

#[derive(Debug, PartialEq, Eq)]
pub(crate) struct GeneratorClaim {
    pub message: Vec<Fp2>,
    pub pads: Vec<Fp2>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum GeneratorError {
    MessageDomain,
    SampleOnMessageDomain,
    RowWeightsLength,
    EvaluationWeightsLength,
    SampleColumnLength,
}

fn message_root(ntt: &NttTables, n: usize) -> Result<Fp, GeneratorError> {
    if !n.is_power_of_two() || n.trailing_zeros() > ntt.max_log {
        return Err(GeneratorError::MessageDomain);
    }
    Ok(ntt.roots[n.trailing_zeros() as usize])
}

fn sample_weights(
    n: usize,
    samples: &[WeightedPoint],
) -> Result<Vec<WeightedPoint>, GeneratorError> {
    samples
        .iter()
        .map(|sample| {
            let vanishing = sample.point.pow(n as u64).sub(Fp::ONE);
            if vanishing.is_zero() {
                return Err(GeneratorError::SampleOnMessageDomain);
            }
            Ok(WeightedPoint {
                point: sample.point,
                weight: sample.weight.mul_base(vanishing),
            })
        })
        .collect()
}

fn add_powers(output: &mut [Fp2], point: Fp, weight: Fp2) {
    let mut term = weight;
    for coeff in output {
        *coeff = coeff.add(term);
        term = term.mul_base(point);
    }
}

/// The W16R2 message is in Lagrange form on the size-n subgroup. The pad
/// coordinates multiply the vanishing polynomial X^n - 1 in either basis.
#[cfg(test)]
pub(crate) fn evaluation_claim_dense(
    ntt: &NttTables,
    n: usize,
    q: usize,
    samples: &[WeightedPoint],
) -> Result<GeneratorClaim, GeneratorError> {
    let root = message_root(ntt, n)?;
    let samples = sample_weights(n, samples)?;
    let n_inverse = Fp::new(n as u64).inv();
    let subgroup: Vec<Fp> = (0..n)
        .scan(Fp::ONE, |point, _| {
            let out = *point;
            *point = point.mul(root);
            Some(out)
        })
        .collect();
    let mut claim = GeneratorClaim {
        message: vec![Fp2::ZERO; n],
        pads: vec![Fp2::ZERO; q],
    };
    let mut inverse = vec![Fp::ZERO; n];
    for sample in samples {
        for (d, y) in inverse.iter_mut().zip(&subgroup) {
            *d = sample.point.sub(*y);
        }
        batch_inverse(&mut inverse);
        let scaled = sample.weight.mul_base(n_inverse);
        for ((gamma, y), inv) in claim.message.iter_mut().zip(&subgroup).zip(&inverse) {
            *gamma = gamma.add(scaled.mul_base(y.mul(*inv)));
        }
        add_powers(&mut claim.pads, sample.point, sample.weight);
    }
    Ok(claim)
}

/// Evaluate the same Lagrange combination through its rational numerator
/// and denominator. Combine duplicate sample positions only after drawing
/// their separate coefficients. Both polynomials are evaluated on the
/// fixed message subgroup, where the denominator never vanishes.
pub(crate) fn evaluation_claim_rational(
    ntt: &NttTables,
    n: usize,
    q: usize,
    samples: &[WeightedPoint],
) -> Result<GeneratorClaim, GeneratorError> {
    let root = message_root(ntt, n)?;
    let mut by_point = BTreeMap::<u64, Fp2>::new();
    for sample in sample_weights(n, samples)? {
        let weight = by_point.entry(sample.point.0).or_insert(Fp2::ZERO);
        *weight = weight.add(sample.weight);
    }

    // Z(Y) = product (Y - x). Accumulate -a_x Z(Y)/(Y - x) by
    // synthetic division, giving sum a_x/(x - Y) after division by Z.
    let mut denominator = vec![Fp::ONE];
    for &word in by_point.keys() {
        let point = Fp(word);
        denominator.push(Fp::ZERO);
        for i in (1..denominator.len()).rev() {
            denominator[i] = denominator[i - 1].sub(point.mul(denominator[i]));
        }
        denominator[0] = denominator[0].neg().mul(point);
    }
    let degree = denominator.len() - 1;
    let mut numerator = vec![Fp2::ZERO; degree];
    let mut pads = vec![Fp2::ZERO; q];
    for (word, weight) in by_point {
        let point = Fp(word);
        let mut quotient = Fp::ZERO;
        for i in (0..degree).rev() {
            quotient = denominator[i + 1].add(point.mul(quotient));
            numerator[i] = numerator[i].sub(weight.mul_base(quotient));
        }
        add_powers(&mut pads, point, weight);
    }

    // Reduce each coefficient list modulo Y^n - 1 before the NTT. This
    // also handles a toy domain with more distinct samples than rows.
    let mut den = vec![Fp::ZERO; n];
    let mut re = vec![Fp::ZERO; n];
    let mut im = vec![Fp::ZERO; n];
    for (i, coeff) in denominator.into_iter().enumerate() {
        den[i % n] = den[i % n].add(coeff);
    }
    for (i, coeff) in numerator.into_iter().enumerate() {
        re[i % n] = re[i % n].add(coeff.c0);
        im[i % n] = im[i % n].add(coeff.c1);
    }
    ntt.forward(&mut den);
    ntt.forward(&mut re);
    ntt.forward(&mut im);
    batch_inverse(&mut den);
    let mut y_over_n = Fp::new(n as u64).inv();
    let message = re
        .into_iter()
        .zip(im)
        .zip(den)
        .map(|((a, b), inv)| {
            let value = Fp2::new(a, b).mul_base(y_over_n.mul(inv));
            y_over_n = y_over_n.mul(root);
            value
        })
        .collect();
    Ok(GeneratorClaim { message, pads })
}

/// In coefficient form the message basis is 1, X, ..., X^(n-1).
#[cfg(test)]
pub(crate) fn coefficient_claim(n: usize, q: usize, samples: &[WeightedPoint]) -> GeneratorClaim {
    let mut claim = GeneratorClaim {
        message: vec![Fp2::ZERO; n],
        pads: vec![Fp2::ZERO; q],
    };
    for sample in samples {
        add_powers(&mut claim.message, sample.point, sample.weight);
        let vanishing = sample.point.pow(n as u64).sub(Fp::ONE);
        add_powers(
            &mut claim.pads,
            sample.point,
            sample.weight.mul_base(vanishing),
        );
    }
    claim
}

#[derive(Clone, Copy)]
pub(crate) enum MessageBasis {
    Evaluations,
    #[cfg(test)]
    Coefficients,
}

pub(crate) struct EvaluationCheck<'a> {
    pub column_weights: &'a [Fp2],
    pub claimed_value: Fp2,
    pub coefficient: Fp2,
}

pub(crate) struct SwitchedVector<'a> {
    pub row_weights: &'a [Fp2],
    pub sample_coefficient: Fp2,
    /// The proximity vector contributes only to the sampled-column check.
    pub evaluation: Option<EvaluationCheck<'a>>,
}

pub(crate) struct SampleColumn<'a> {
    pub sample: WeightedPoint,
    pub values: &'a [Fp],
}

pub(crate) struct OpeningClaim {
    pub target: Fp2,
    pub vectors: Vec<GeneratorClaim>,
}

/// Construct one opening's contribution to the BAT claim on W. Retain one
/// coefficient row per vector and batch the source row weights before the
/// sampled-column dot products. The caller supplies draws in sample order.
pub(crate) fn opening_claim(
    ntt: &NttTables,
    basis: MessageBasis,
    n: usize,
    q: usize,
    rows: usize,
    vectors: &[SwitchedVector<'_>],
    columns: &[SampleColumn<'_>],
) -> Result<OpeningClaim, GeneratorError> {
    if vectors.iter().any(|v| v.row_weights.len() != rows) {
        return Err(GeneratorError::RowWeightsLength);
    }
    if columns.iter().any(|column| column.values.len() != rows) {
        return Err(GeneratorError::SampleColumnLength);
    }
    let samples: Vec<WeightedPoint> = columns.iter().map(|column| column.sample).collect();
    let generator = match basis {
        MessageBasis::Evaluations => evaluation_claim_rational(ntt, n, q, &samples)?,
        #[cfg(test)]
        MessageBasis::Coefficients => coefficient_claim(n, q, &samples),
    };
    // [hostfix] The only error the old per-vector loop could return, checked
    // up front: it is the same value whichever vector carries it, and it
    // still follows the generator's own errors.
    if vectors.iter().any(|vector| {
        vector
            .evaluation
            .as_ref()
            .is_some_and(|eval| eval.column_weights.len() != n)
    }) {
        return Err(GeneratorError::EvaluationWeightsLength);
    }
    // [hostfix] Every sum below is an exact field sum, so its order does not
    // change the word; every vector is collected in its own order. Prover and
    // verifier both call this; its outputs are unchanged.
    let combined: Vec<Fp2> = {
        let row_sum = |r: usize| {
            vectors.iter().fold(Fp2::ZERO, |acc, vector| {
                acc.add(vector.sample_coefficient.mul(vector.row_weights[r]))
            })
        };
        if rows.saturating_mul(vectors.len()) < PAR_MIN {
            (0..rows).map(row_sum).collect()
        } else {
            (0..rows)
                .into_par_iter()
                .with_min_len(PAR_ROWS)
                .map(row_sum)
                .collect()
        }
    };
    let scale = |vector: &SwitchedVector<'_>| -> GeneratorClaim {
        let mu = vector.sample_coefficient;
        let message = match &vector.evaluation {
            None => generator.message.iter().map(|x| mu.mul(*x)).collect(),
            Some(eval) => generator
                .message
                .iter()
                .enumerate()
                .map(|(i, x)| {
                    let out = mu.mul(*x);
                    match eval.column_weights.get(i) {
                        Some(value) => out.add(eval.coefficient.mul(*value)),
                        None => out,
                    }
                })
                .collect(),
        };
        GeneratorClaim {
            message,
            pads: generator.pads.iter().map(|x| mu.mul(*x)).collect(),
        }
    };
    let coefficients: Vec<GeneratorClaim> =
        if vectors.len() < 2 || generator.message.len() < PAR_MIN {
            vectors.iter().map(scale).collect()
        } else {
            vectors.par_iter().map(scale).collect()
        };
    let evaluations = vectors
        .iter()
        .filter_map(|vector| vector.evaluation.as_ref())
        .fold(Fp2::ZERO, |acc, eval| {
            acc.add(eval.coefficient.mul(eval.claimed_value))
        });
    let column_term = |column: &SampleColumn<'_>| {
        let dot = combined
            .iter()
            .zip(column.values)
            .fold(Fp2::ZERO, |acc, (weight, value)| {
                acc.add(weight.mul_base(*value))
            });
        column.sample.weight.mul(dot)
    };
    let sampled = if rows.saturating_mul(columns.len()) < PAR_MIN {
        columns
            .iter()
            .map(column_term)
            .fold(Fp2::ZERO, |acc, term| acc.add(term))
    } else {
        columns
            .par_iter()
            .map(column_term)
            .reduce(|| Fp2::ZERO, |a, b| a.add(b))
    };
    Ok(OpeningClaim {
        target: evaluations.add(sampled),
        vectors: coefficients,
    })
}

/// [hostfix] Work below this many products stays on the calling thread.
const PAR_MIN: usize = 1 << 12;
/// [hostfix] Smallest number of rows handed to one rayon task.
const PAR_ROWS: usize = 64;

/// [hostfix] The base `opening_claim` (profile-9fbc85292 `pcs/switch.rs`,
/// sha256 f0a24fbf91eaaaaec9d025f7de6db2beddcf9a8fcd19c39c4550c5e9c6b51add),
/// verbatim, as the reference for the parallel form.
#[cfg(test)]
pub(crate) fn opening_claim_reference(
    ntt: &NttTables,
    basis: MessageBasis,
    n: usize,
    q: usize,
    rows: usize,
    vectors: &[SwitchedVector<'_>],
    columns: &[SampleColumn<'_>],
) -> Result<OpeningClaim, GeneratorError> {
    if vectors.iter().any(|v| v.row_weights.len() != rows) {
        return Err(GeneratorError::RowWeightsLength);
    }
    if columns.iter().any(|column| column.values.len() != rows) {
        return Err(GeneratorError::SampleColumnLength);
    }
    let samples: Vec<WeightedPoint> = columns.iter().map(|column| column.sample).collect();
    let generator = match basis {
        MessageBasis::Evaluations => evaluation_claim_rational(ntt, n, q, &samples)?,
        MessageBasis::Coefficients => coefficient_claim(n, q, &samples),
    };
    let mut target = Fp2::ZERO;
    let mut combined = vec![Fp2::ZERO; rows];
    let mut coefficients = Vec::with_capacity(vectors.len());
    for vector in vectors {
        let mu = vector.sample_coefficient;
        for (acc, weight) in combined.iter_mut().zip(vector.row_weights) {
            *acc = acc.add(mu.mul(*weight));
        }
        let mut output = GeneratorClaim {
            message: generator.message.iter().map(|x| mu.mul(*x)).collect(),
            pads: generator.pads.iter().map(|x| mu.mul(*x)).collect(),
        };
        if let Some(eval) = &vector.evaluation {
            if eval.column_weights.len() != n {
                return Err(GeneratorError::EvaluationWeightsLength);
            }
            target = target.add(eval.coefficient.mul(eval.claimed_value));
            for (out, value) in output.message.iter_mut().zip(eval.column_weights) {
                *out = out.add(eval.coefficient.mul(*value));
            }
        }
        coefficients.push(output);
    }
    for column in columns {
        let dot = combined
            .iter()
            .zip(column.values)
            .fold(Fp2::ZERO, |acc, (weight, value)| {
                acc.add(weight.mul_base(*value))
            });
        target = target.add(column.sample.weight.mul(dot));
    }
    Ok(OpeningClaim {
        target,
        vectors: coefficients,
    })
}

/// [hostfix] The parallel `opening_claim` against the base one, output for
/// output, at small shapes, a full T128 shape and on every error path.
#[cfg(test)]
mod hostfix_tests {
    use super::*;
    use crate::rng::ZkRng;

    struct Case {
        n: usize,
        q: usize,
        row_weights: Vec<Vec<Fp2>>,
        mu: Vec<Fp2>,
        column_weights: Vec<Vec<Fp2>>,
        claimed: Vec<Fp2>,
        alpha: Vec<Fp2>,
        values: Vec<Vec<Fp>>,
        samples: Vec<WeightedPoint>,
    }

    impl Case {
        /// `vectors` row vectors, the first `evaluations` with an evaluation
        /// check; `columns` sampled positions on the size-2n coset domain.
        fn new(
            n: usize,
            q: usize,
            rows: usize,
            vectors: usize,
            evaluations: usize,
            columns: usize,
            ntt: &NttTables,
            seed: u64,
        ) -> Self {
            let mut rng = ZkRng::new(seed, b"hostfix opening claim");
            let root = ntt.roots[(2 * n).trailing_zeros() as usize];
            let samples = (0..columns)
                .map(|_| WeightedPoint {
                    point: Fp::new(7).mul(root.pow(rng.next_u64() % (2 * n as u64))),
                    weight: rng.fp2(),
                })
                .collect();
            Self {
                n,
                q,
                row_weights: (0..vectors).map(|_| rng.fp2_vec(rows)).collect(),
                mu: rng.fp2_vec(vectors),
                column_weights: (0..evaluations).map(|_| rng.fp2_vec(n)).collect(),
                claimed: rng.fp2_vec(evaluations),
                alpha: rng.fp2_vec(evaluations),
                values: (0..columns).map(|_| rng.fp_vec(rows)).collect(),
                samples,
            }
        }

        fn vectors(&self) -> Vec<SwitchedVector<'_>> {
            self.row_weights
                .iter()
                .enumerate()
                .map(|(g, weights)| SwitchedVector {
                    row_weights: weights,
                    sample_coefficient: self.mu[g],
                    evaluation: self.claimed.get(g).map(|&value| EvaluationCheck {
                        column_weights: &self.column_weights[g],
                        claimed_value: value,
                        coefficient: self.alpha[g],
                    }),
                })
                .collect()
        }

        fn columns(&self) -> Vec<SampleColumn<'_>> {
            self.values
                .iter()
                .zip(&self.samples)
                .map(|(values, &sample)| SampleColumn { sample, values })
                .collect()
        }

        fn check(&self, ntt: &NttTables, basis: MessageBasis, rows: usize) {
            let vectors = self.vectors();
            let columns = self.columns();
            let a = opening_claim_reference(ntt, basis, self.n, self.q, rows, &vectors, &columns);
            let b = opening_claim(ntt, basis, self.n, self.q, rows, &vectors, &columns);
            match (a, b) {
                (Ok(a), Ok(b)) => {
                    assert_eq!(a.target, b.target);
                    assert_eq!(a.vectors, b.vectors);
                }
                (Err(a), Err(b)) => assert_eq!(a, b),
                (a, b) => panic!("old ok={} new ok={}", a.is_ok(), b.is_ok()),
            }
        }
    }

    #[test]
    fn hostfix_opening_claim_matches_base() {
        let ntt = NttTables::new(14);
        for (seed, (n, q, rows, vectors, evaluations, columns)) in [
            (4, 3, 1, 2, 1, 3),
            (64, 3, 11, 3, 2, 7),
            (256, 20, 40, 5, 4, 30),
            (4096, 50, 200, 9, 8, 60),
            (1024, 280, 80, 1, 0, 64),
            (2048, 10, 300, 12, 12, 2),
        ]
        .into_iter()
        .enumerate()
        {
            let case = Case::new(n, q, rows, vectors, evaluations, columns, &ntt, seed as u64);
            case.check(&ntt, MessageBasis::Evaluations, rows);
            case.check(&ntt, MessageBasis::Coefficients, rows);
        }
    }

    #[test]
    fn hostfix_opening_claim_matches_base_full_shape() {
        // T128: n = 16,384, q = 280; A has 2,501 rows, 37 vectors (36 with an
        // evaluation); H has 2,602 rows, 10 vectors (9); 280 samples each.
        let ntt = NttTables::new(15);
        for (seed, (rows, vectors)) in [(2501, 37), (2602, 10)].into_iter().enumerate() {
            let case = Case::new(16384, 280, rows, vectors, vectors - 1, 280, &ntt, 90 + seed as u64);
            case.check(&ntt, MessageBasis::Evaluations, rows);
        }
    }

    #[test]
    fn hostfix_opening_claim_errors_match_base() {
        let ntt = NttTables::new(14);
        let base = Case::new(4096, 50, 200, 9, 8, 60, &ntt, 7);
        // Wrong declared row count: row weights are checked first.
        base.check(&ntt, MessageBasis::Evaluations, 199);
        // One short sampled column.
        let mut case = Case::new(4096, 50, 200, 9, 8, 60, &ntt, 7);
        case.values[41].pop();
        case.check(&ntt, MessageBasis::Evaluations, 200);
        // One short evaluation row, in a late vector.
        let mut case = Case::new(4096, 50, 200, 9, 8, 60, &ntt, 7);
        case.column_weights[6].pop();
        case.check(&ntt, MessageBasis::Evaluations, 200);
        case.check(&ntt, MessageBasis::Coefficients, 200);
        // A sample on the message domain: the generator's error comes first,
        // even with a short evaluation row present.
        let mut case = Case::new(4096, 50, 200, 9, 8, 60, &ntt, 7);
        case.samples[3].point = ntt.roots[12].pow(5);
        case.check(&ntt, MessageBasis::Evaluations, 200);
        case.column_weights[2].pop();
        case.check(&ntt, MessageBasis::Evaluations, 200);
    }
}

#[cfg(test)]
#[path = "switch_tests.rs"]
mod tests;
