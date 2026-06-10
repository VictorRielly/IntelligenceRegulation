use rayon::prelude::*;
use std::env;
use std::time::Instant;

const Q: u64 = 2_305_843_009_213_688_669;

#[inline]
fn addm(a: u64, b: u64) -> u64 {
    let c = a + b;
    if c >= Q { c - Q } else { c }
}

#[inline]
fn subm(a: u64, b: u64) -> u64 {
    if a >= b { a - b } else { Q - (b - a) }
}

#[inline]
fn mulm(a: u64, b: u64) -> u64 {
    ((a as u128 * b as u128) % Q as u128) as u64
}

fn powm(mut base: u64, mut exp: u64) -> u64 {
    let mut acc = 1u64;
    while exp != 0 {
        if exp & 1 == 1 {
            acc = mulm(acc, base);
        }
        base = mulm(base, base);
        exp >>= 1;
    }
    acc
}

#[inline]
fn invm(x: u64) -> u64 {
    powm(x, Q - 2)
}

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e3779b97f4a7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
    z ^ (z >> 31)
}

fn mix_value(seed: u64, value: u64) -> u64 {
    let mut s = seed ^ value.wrapping_add(0x9e3779b97f4a7c15).wrapping_add(seed << 6).wrapping_add(seed >> 2);
    splitmix64(&mut s)
}

fn challenge6(domain: u64, round: usize, current: u64, scalar_base: u64, left: u64, right: u64) -> u64 {
    let mut s = 0xd6e8_feb8_6659_fd93u64 ^ domain;
    for value in [round as u64, current, scalar_base, left, right] {
        s = mix_value(s, value);
    }
    let x = s % Q;
    if x == 0 { 1 } else { x }
}

fn challenge_statement(domain: u64, n: usize, ca: u64, cb: u64, cc: u64) -> u64 {
    let mut s = 0xa076_1d64_78bd_642fu64 ^ domain;
    for value in [n as u64, ca, cb, cc] {
        s = mix_value(s, value);
    }
    let x = s % Q;
    if x == 0 { 1 } else { x }
}

fn challenge_commitments(domain: u64, n: usize, statement: &Statement, items: &[u64]) -> u64 {
    let mut s = 0xe703_7ed1_a0b4_28dbu64 ^ domain;
    for value in [n as u64, statement.a_commit, statement.b_commit, statement.c_commit] {
        s = mix_value(s, value);
    }
    for &item in items {
        s = mix_value(s, item);
    }
    let x = s % Q;
    if x == 0 { 1 } else { x }
}

fn rng_field(rng: &mut u64) -> u64 {
    splitmix64(rng) % Q
}

fn rng_small(rng: &mut u64, max_entry: u64) -> u64 {
    splitmix64(rng) % max_entry
}

fn next_pow2(value: usize) -> usize {
    value.next_power_of_two()
}

fn log2_pow2(value: usize) -> usize {
    value.trailing_zeros() as usize
}

fn basis_elem(label: u64, index: usize) -> u64 {
    let mut s = 0x243f_6a88_85a3_08d3u64 ^ label;
    s = mix_value(s, index as u64);
    let x = s % Q;
    if x == 0 { 1 } else { x }
}

#[derive(Clone)]
struct Bases {
    n: usize,
    nn: usize,
    a: Vec<u64>,
    b: Vec<u64>,
    c: Vec<u64>,
    ay: Vec<u64>,
    by: Vec<u64>,
    scalar: u64,
    blind: u64,
}

#[derive(Clone, Copy)]
struct Statement {
    a_commit: u64,
    b_commit: u64,
    c_commit: u64,
}

struct Witness {
    a: Vec<u64>,
    b: Vec<u64>,
    c: Vec<u64>,
    a_blind: u64,
    b_blind: u64,
    c_blind: u64,
}

#[derive(Clone)]
struct IpProof {
    n: usize,
    left: Vec<u64>,
    right: Vec<u64>,
    a_final: u64,
    b_final: u64,
}

struct CoreProof {
    d_commit: u64,
    ay_commit: u64,
    by_commit: u64,
    c_proj: IpProof,
    a_proj: IpProof,
    b_proj: IpProof,
    product: IpProof,
}

struct ZkProjectionProof {
    mask_commit: u64,
    projected_mask_commit: u64,
    response_blind: u64,
    projected_response_blind: u64,
    proof: IpProof,
}

struct ZkProductProof {
    alpha_commit: u64,
    beta_commit: u64,
    cross_commit: u64,
    alpha_beta_commit: u64,
    left_response_blind: u64,
    right_response_blind: u64,
    output_response_blind: u64,
    proof: IpProof,
}

struct ZkProof {
    d_commit: u64,
    ay_commit: u64,
    by_commit: u64,
    c_proj: ZkProjectionProof,
    a_proj: ZkProjectionProof,
    b_proj: ZkProjectionProof,
    product: ZkProductProof,
}

fn make_bases(n: usize) -> Bases {
    let nn = n * n;
    Bases {
        n,
        nn,
        a: (0..nn).into_par_iter().map(|i| basis_elem(0xA111, i)).collect(),
        b: (0..nn).into_par_iter().map(|i| basis_elem(0xB222, i)).collect(),
        c: (0..nn).into_par_iter().map(|i| basis_elem(0xC333, i)).collect(),
        ay: (0..n).into_par_iter().map(|i| basis_elem(0xA444, i)).collect(),
        by: (0..n).into_par_iter().map(|i| basis_elem(0xB555, i)).collect(),
        scalar: basis_elem(0xD666, 0),
        blind: basis_elem(0xE777, 0),
    }
}

fn reduce_sum(values: impl ParallelIterator<Item = u64>) -> u64 {
    values.reduce(|| 0, addm)
}

fn dot(a: &[u64], b: &[u64]) -> u64 {
    if a.len() < (1 << 24) {
        let mut acc = 0;
        for i in 0..a.len() {
            acc = addm(acc, mulm(a[i], b[i]));
        }
        acc
    } else {
        reduce_sum(a.par_iter().zip(b.par_iter()).map(|(&x, &y)| mulm(x, y)))
    }
}

fn commit_vec(values: &[u64], bases: &[u64], blind_base: u64, blind: u64) -> u64 {
    let mut out = dot(values, bases);
    if blind != 0 {
        out = addm(out, mulm(blind_base, blind));
    }
    out
}

fn matmul_mod(a: &[u64], b: &[u64], c: &mut [u64], n: usize) {
    c.par_chunks_mut(n).enumerate().for_each(|(i, row)| {
        row.fill(0);
        for k in 0..n {
            let aik = a[i * n + k];
            for j in 0..n {
                row[j] = addm(row[j], mulm(aik, b[k * n + j]));
            }
        }
    });
}

fn generate_witness(n: usize, seed: u64, max_entry: u64, valid: bool) -> Witness {
    let nn = n * n;
    let mut rng = seed;
    let mut a = vec![0; nn];
    let mut b = vec![0; nn];
    let mut c = vec![0; nn];
    for i in 0..nn {
        a[i] = rng_small(&mut rng, max_entry);
        b[i] = rng_small(&mut rng, max_entry);
    }
    matmul_mod(&a, &b, &mut c, n);
    if !valid {
        c[0] = addm(c[0], 1);
    }
    Witness { a, b, c, a_blind: 0, b_blind: 0, c_blind: 0 }
}

fn commit_statement(bases: &Bases, witness: &mut Witness, blinded: bool, rng: &mut u64) -> Statement {
    if blinded {
        witness.a_blind = rng_field(rng);
        witness.b_blind = rng_field(rng);
        witness.c_blind = rng_field(rng);
    }
    Statement {
        a_commit: commit_vec(&witness.a, &bases.a, bases.blind, witness.a_blind),
        b_commit: commit_vec(&witness.b, &bases.b, bases.blind, witness.b_blind),
        c_commit: commit_vec(&witness.c, &bases.c, bases.blind, witness.c_blind),
    }
}

fn powers(base: u64, len: usize) -> Vec<u64> {
    let mut out = vec![0; len];
    let mut cur = 1;
    for x in &mut out {
        *x = cur;
        cur = mulm(cur, base);
    }
    out
}

fn projections(bases: &Bases, statement: &Statement, witness: &Witness) -> (Vec<u64>, Vec<u64>, Vec<u64>, Vec<u64>, Vec<u64>, u64) {
    let n = bases.n;
    let y = challenge_statement(0x1001, n, statement.a_commit, statement.b_commit, statement.c_commit);
    let yvec = powers(y, bases.nn);
    let yr = powers(y, n);
    let yl: Vec<u64> = (0..n).map(|i| yvec[i * n]).collect();
    let ay: Vec<u64> = (0..n).into_par_iter().map(|j| {
        let mut acc = 0;
        for i in 0..n {
            acc = addm(acc, mulm(yl[i], witness.a[i * n + j]));
        }
        acc
    }).collect();
    let by: Vec<u64> = witness.b.par_chunks(n).map(|row| dot(row, &yr)).collect();
    let d = dot(&witness.c, &yvec);
    (yvec, yl, yr, ay, by, d)
}

fn a_projection_bases(bases: &Bases, yl: &[u64]) -> Vec<u64> {
    let n = bases.n;
    (0..bases.nn).into_par_iter().map(|idx| {
        let i = idx / n;
        let j = idx % n;
        addm(bases.a[idx], mulm(yl[i], bases.ay[j]))
    }).collect()
}

fn b_projection_bases(bases: &Bases, yr: &[u64]) -> Vec<u64> {
    let n = bases.n;
    (0..bases.nn).into_par_iter().map(|idx| {
        let i = idx / n;
        let j = idx % n;
        addm(bases.b[idx], mulm(yr[j], bases.by[i]))
    }).collect()
}

fn prove_ip(input_n: usize, commitment: u64, scalar_base: u64, g_in: &[u64], h_in: Option<&[u64]>, a_in: Option<&[u64]>, b_in: Option<&[u64]>, domain: u64) -> IpProof {
    let proof_n = next_pow2(input_n);
    let rounds = log2_pow2(proof_n);
    let mut g = vec![0; proof_n];
    let mut h = vec![0; proof_n];
    let mut a = vec![0; proof_n];
    let mut b = vec![0; proof_n];
    g[..input_n].copy_from_slice(g_in);
    if let Some(hv) = h_in { h[..input_n].copy_from_slice(hv); }
    if let Some(av) = a_in { a[..input_n].copy_from_slice(av); }
    if let Some(bv) = b_in { b[..input_n].copy_from_slice(bv); }
    let mut current = commitment;
    let mut left_messages = Vec::with_capacity(rounds);
    let mut right_messages = Vec::with_capacity(rounds);
    let mut len = proof_n;
    for round in 0..rounds {
        let half = len / 2;
        let left_cross = dot(&a[..half], &b[half..len]);
        let right_cross = dot(&a[half..len], &b[..half]);
        let left = addm(addm(dot(&a[..half], &g[half..len]), dot(&b[half..len], &h[..half])), mulm(scalar_base, left_cross));
        let right = addm(addm(dot(&a[half..len], &g[..half]), dot(&b[..half], &h[half..len])), mulm(scalar_base, right_cross));
        let x = challenge6(domain, round, current, scalar_base, left, right);
        let xi = invm(x);
        for i in 0..half {
            a[i] = addm(a[i], mulm(xi, a[half + i]));
            b[i] = addm(b[i], mulm(x, b[half + i]));
            g[i] = addm(g[i], mulm(x, g[half + i]));
            h[i] = addm(h[i], mulm(xi, h[half + i]));
        }
        current = addm(addm(mulm(x, left), current), mulm(xi, right));
        left_messages.push(left);
        right_messages.push(right);
        len = half;
    }
    IpProof { n: proof_n, left: left_messages, right: right_messages, a_final: a[0], b_final: b[0] }
}

fn verify_ip(input_n: usize, commitment: u64, scalar_base: u64, g_in: &[u64], h_in: Option<&[u64]>, proof: &IpProof, domain: u64) -> bool {
    if proof.n != next_pow2(input_n) || proof.left.len() != log2_pow2(proof.n) {
        return false;
    }
    let mut g = vec![0; proof.n];
    let mut h = vec![0; proof.n];
    g[..input_n].copy_from_slice(g_in);
    if let Some(hv) = h_in { h[..input_n].copy_from_slice(hv); }
    let mut current = commitment;
    let mut len = proof.n;
    for round in 0..proof.left.len() {
        let half = len / 2;
        let left = proof.left[round];
        let right = proof.right[round];
        let x = challenge6(domain, round, current, scalar_base, left, right);
        let xi = invm(x);
        for i in 0..half {
            g[i] = addm(g[i], mulm(x, g[half + i]));
            h[i] = addm(h[i], mulm(xi, h[half + i]));
        }
        current = addm(addm(mulm(x, left), current), mulm(xi, right));
        len = half;
    }
    let expected = addm(addm(mulm(scalar_base, mulm(proof.a_final, proof.b_final)), mulm(g[0], proof.a_final)), mulm(h[0], proof.b_final));
    current == expected
}

fn prove_core(bases: &Bases, statement: &Statement, witness: &Witness) -> CoreProof {
    let (yvec, yl, yr, ay, by, d) = projections(bases, statement, witness);
    let d_commit = mulm(bases.scalar, d);
    let ay_commit = commit_vec(&ay, &bases.ay, 0, 0);
    let by_commit = commit_vec(&by, &bases.by, 0, 0);
    let c_proj = prove_ip(bases.nn, addm(d_commit, statement.c_commit), bases.scalar, &bases.c, None, Some(&witness.c), Some(&yvec), 0xC001);
    let apb = a_projection_bases(bases, &yl);
    let a_proj = prove_ip(bases.nn, addm(statement.a_commit, ay_commit), 0, &apb, None, Some(&witness.a), None, 0xA002);
    let bpb = b_projection_bases(bases, &yr);
    let b_proj = prove_ip(bases.nn, addm(statement.b_commit, by_commit), 0, &bpb, None, Some(&witness.b), None, 0xB003);
    let product = prove_ip(bases.n, addm(addm(d_commit, ay_commit), by_commit), bases.scalar, &bases.ay, Some(&bases.by), Some(&ay), Some(&by), 0xD004);
    CoreProof { d_commit, ay_commit, by_commit, c_proj, a_proj, b_proj, product }
}

fn verify_core(bases: &Bases, statement: &Statement, proof: &CoreProof) -> bool {
    let y = challenge_statement(0x1001, bases.n, statement.a_commit, statement.b_commit, statement.c_commit);
    let yvec = powers(y, bases.nn);
    let yr = powers(y, bases.n);
    let yl: Vec<u64> = (0..bases.n).map(|i| yvec[i * bases.n]).collect();
    if !verify_ip(bases.nn, addm(proof.d_commit, statement.c_commit), bases.scalar, &bases.c, None, &proof.c_proj, 0xC001) { return false; }
    let apb = a_projection_bases(bases, &yl);
    if !verify_ip(bases.nn, addm(statement.a_commit, proof.ay_commit), 0, &apb, None, &proof.a_proj, 0xA002) { return false; }
    let bpb = b_projection_bases(bases, &yr);
    if !verify_ip(bases.nn, addm(statement.b_commit, proof.by_commit), 0, &bpb, None, &proof.b_proj, 0xB003) { return false; }
    verify_ip(bases.n, addm(addm(proof.d_commit, proof.ay_commit), proof.by_commit), bases.scalar, &bases.ay, Some(&bases.by), &proof.product, 0xD004)
}

fn prove_zk_public_ip(bases: &Bases, statement: &Statement, input_commit: u64, output_commit: u64, input_values: &[u64], public_values: &[u64], input_bases: &[u64], output_base: u64, input_blind: u64, output_blind: u64, domain: u64, rng: &mut u64) -> ZkProjectionProof {
    let len = input_values.len();
    let mut alpha: Vec<u64> = (0..len).map(|_| rng_field(rng)).collect();
    let projected_alpha = dot(&alpha, public_values);
    let alpha_blind = rng_field(rng);
    let projected_alpha_blind = rng_field(rng);
    let mask_commit = commit_vec(&alpha, input_bases, bases.blind, alpha_blind);
    let projected_mask_commit = addm(mulm(output_base, projected_alpha), mulm(bases.blind, projected_alpha_blind));
    let x = challenge_commitments(domain, bases.n, statement, &[input_commit, output_commit, mask_commit, projected_mask_commit]);
    let response_blind = addm(input_blind, mulm(x, alpha_blind));
    let projected_response_blind = addm(output_blind, mulm(x, projected_alpha_blind));
    alpha.par_iter_mut().zip(input_values.par_iter()).for_each(|(a, &v)| *a = addm(v, mulm(x, *a)));
    let masked_input = subm(addm(input_commit, mulm(x, mask_commit)), mulm(bases.blind, response_blind));
    let masked_output = subm(addm(output_commit, mulm(x, projected_mask_commit)), mulm(bases.blind, projected_response_blind));
    let proof = prove_ip(len, addm(masked_output, masked_input), output_base, input_bases, None, Some(&alpha), Some(public_values), domain ^ 0x9999);
    ZkProjectionProof { mask_commit, projected_mask_commit, response_blind, projected_response_blind, proof }
}

fn verify_zk_public_ip(bases: &Bases, statement: &Statement, input_commit: u64, output_commit: u64, public_values: &[u64], input_bases: &[u64], output_base: u64, proof: &ZkProjectionProof, domain: u64) -> bool {
    let x = challenge_commitments(domain, bases.n, statement, &[input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit]);
    let masked_input = subm(addm(input_commit, mulm(x, proof.mask_commit)), mulm(bases.blind, proof.response_blind));
    let masked_output = subm(addm(output_commit, mulm(x, proof.projected_mask_commit)), mulm(bases.blind, proof.projected_response_blind));
    verify_ip(public_values.len(), addm(masked_output, masked_input), output_base, input_bases, None, &proof.proof, domain ^ 0x9999)
}

fn prove_zk_projection(bases: &Bases, statement: &Statement, input_commit: u64, output_commit: u64, input_values: &[u64], coeffs: &[u64], input_bases: &[u64], output_bases: &[u64], projected_bases: &[u64], input_blind: u64, output_blind: u64, axis_rows: bool, domain: u64, rng: &mut u64) -> ZkProjectionProof {
    let n = bases.n;
    let mut alpha: Vec<u64> = (0..bases.nn).map(|_| rng_field(rng)).collect();
    let projected_alpha: Vec<u64> = if axis_rows {
        (0..n).into_par_iter().map(|col| {
            let mut acc = 0;
            for row in 0..n { acc = addm(acc, mulm(coeffs[row], alpha[row * n + col])); }
            acc
        }).collect()
    } else {
        alpha.par_chunks(n).map(|row| dot(row, coeffs)).collect()
    };
    let alpha_blind = rng_field(rng);
    let projected_alpha_blind = rng_field(rng);
    let mask_commit = commit_vec(&alpha, input_bases, bases.blind, alpha_blind);
    let projected_mask_commit = commit_vec(&projected_alpha, output_bases, bases.blind, projected_alpha_blind);
    let x = challenge_commitments(domain, n, statement, &[input_commit, output_commit, mask_commit, projected_mask_commit]);
    let response_blind = addm(input_blind, mulm(x, alpha_blind));
    let projected_response_blind = addm(output_blind, mulm(x, projected_alpha_blind));
    alpha.par_iter_mut().zip(input_values.par_iter()).for_each(|(a, &v)| *a = addm(v, mulm(x, *a)));
    let masked_input = subm(addm(input_commit, mulm(x, mask_commit)), mulm(bases.blind, response_blind));
    let masked_output = subm(addm(output_commit, mulm(x, projected_mask_commit)), mulm(bases.blind, projected_response_blind));
    let proof = prove_ip(bases.nn, addm(masked_input, masked_output), 0, projected_bases, None, Some(&alpha), None, domain ^ 0x8888);
    ZkProjectionProof { mask_commit, projected_mask_commit, response_blind, projected_response_blind, proof }
}

fn verify_zk_projection(bases: &Bases, statement: &Statement, input_commit: u64, output_commit: u64, projected_bases: &[u64], proof: &ZkProjectionProof, domain: u64) -> bool {
    let x = challenge_commitments(domain, bases.n, statement, &[input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit]);
    let masked_input = subm(addm(input_commit, mulm(x, proof.mask_commit)), mulm(bases.blind, proof.response_blind));
    let masked_output = subm(addm(output_commit, mulm(x, proof.projected_mask_commit)), mulm(bases.blind, proof.projected_response_blind));
    verify_ip(bases.nn, addm(masked_input, masked_output), 0, projected_bases, None, &proof.proof, domain ^ 0x8888)
}

fn prove_zk_product(bases: &Bases, statement: &Statement, output_commit: u64, left_commit: u64, right_commit: u64, left_values: &[u64], right_values: &[u64], output_blind: u64, left_blind: u64, right_blind: u64, rng: &mut u64) -> ZkProductProof {
    let n = bases.n;
    let mut alpha: Vec<u64> = (0..n).map(|_| rng_field(rng)).collect();
    let mut beta: Vec<u64> = (0..n).map(|_| rng_field(rng)).collect();
    let alpha_beta = dot(&alpha, &beta);
    let cross = addm(dot(&alpha, right_values), dot(left_values, &beta));
    let alpha_blind = rng_field(rng);
    let beta_blind = rng_field(rng);
    let cross_blind = rng_field(rng);
    let alpha_beta_blind = rng_field(rng);
    let alpha_commit = commit_vec(&alpha, &bases.ay, bases.blind, alpha_blind);
    let beta_commit = commit_vec(&beta, &bases.by, bases.blind, beta_blind);
    let cross_commit = addm(mulm(bases.scalar, cross), mulm(bases.blind, cross_blind));
    let alpha_beta_commit = addm(mulm(bases.scalar, alpha_beta), mulm(bases.blind, alpha_beta_blind));
    let x = challenge_commitments(0xD0D0, n, statement, &[output_commit, left_commit, right_commit, alpha_commit, beta_commit, cross_commit, alpha_beta_commit]);
    let x2 = mulm(x, x);
    let left_response_blind = addm(left_blind, mulm(x, alpha_blind));
    let right_response_blind = addm(right_blind, mulm(x, beta_blind));
    let output_response_blind = addm(addm(output_blind, mulm(x, cross_blind)), mulm(x2, alpha_beta_blind));
    alpha.par_iter_mut().zip(left_values.par_iter()).for_each(|(a, &v)| *a = addm(v, mulm(x, *a)));
    beta.par_iter_mut().zip(right_values.par_iter()).for_each(|(b, &v)| *b = addm(v, mulm(x, *b)));
    let masked_left = subm(addm(left_commit, mulm(x, alpha_commit)), mulm(bases.blind, left_response_blind));
    let masked_right = subm(addm(right_commit, mulm(x, beta_commit)), mulm(bases.blind, right_response_blind));
    let masked_output = subm(addm(addm(output_commit, mulm(x, cross_commit)), mulm(x2, alpha_beta_commit)), mulm(bases.blind, output_response_blind));
    let proof = prove_ip(n, addm(addm(masked_output, masked_left), masked_right), bases.scalar, &bases.ay, Some(&bases.by), Some(&alpha), Some(&beta), 0xD0D1);
    ZkProductProof { alpha_commit, beta_commit, cross_commit, alpha_beta_commit, left_response_blind, right_response_blind, output_response_blind, proof }
}

fn verify_zk_product(bases: &Bases, statement: &Statement, output_commit: u64, left_commit: u64, right_commit: u64, proof: &ZkProductProof) -> bool {
    let x = challenge_commitments(0xD0D0, bases.n, statement, &[output_commit, left_commit, right_commit, proof.alpha_commit, proof.beta_commit, proof.cross_commit, proof.alpha_beta_commit]);
    let x2 = mulm(x, x);
    let masked_left = subm(addm(left_commit, mulm(x, proof.alpha_commit)), mulm(bases.blind, proof.left_response_blind));
    let masked_right = subm(addm(right_commit, mulm(x, proof.beta_commit)), mulm(bases.blind, proof.right_response_blind));
    let masked_output = subm(addm(addm(output_commit, mulm(x, proof.cross_commit)), mulm(x2, proof.alpha_beta_commit)), mulm(bases.blind, proof.output_response_blind));
    verify_ip(bases.n, addm(addm(masked_output, masked_left), masked_right), bases.scalar, &bases.ay, Some(&bases.by), &proof.proof, 0xD0D1)
}

fn prove_zk(bases: &Bases, statement: &Statement, witness: &Witness, rng: &mut u64) -> ZkProof {
    let (yvec, yl, yr, ay, by, d) = projections(bases, statement, witness);
    let d_blind = rng_field(rng);
    let ay_blind = rng_field(rng);
    let by_blind = rng_field(rng);
    let d_commit = addm(mulm(bases.scalar, d), mulm(bases.blind, d_blind));
    let ay_commit = commit_vec(&ay, &bases.ay, bases.blind, ay_blind);
    let by_commit = commit_vec(&by, &bases.by, bases.blind, by_blind);
    let c_proj = prove_zk_public_ip(bases, statement, statement.c_commit, d_commit, &witness.c, &yvec, &bases.c, bases.scalar, witness.c_blind, d_blind, 0xC101, rng);
    let apb = a_projection_bases(bases, &yl);
    let a_proj = prove_zk_projection(bases, statement, statement.a_commit, ay_commit, &witness.a, &yl, &bases.a, &bases.ay, &apb, witness.a_blind, ay_blind, true, 0xA102, rng);
    let bpb = b_projection_bases(bases, &yr);
    let b_proj = prove_zk_projection(bases, statement, statement.b_commit, by_commit, &witness.b, &yr, &bases.b, &bases.by, &bpb, witness.b_blind, by_blind, false, 0xB103, rng);
    let product = prove_zk_product(bases, statement, d_commit, ay_commit, by_commit, &ay, &by, d_blind, ay_blind, by_blind, rng);
    ZkProof { d_commit, ay_commit, by_commit, c_proj, a_proj, b_proj, product }
}

fn verify_zk(bases: &Bases, statement: &Statement, proof: &ZkProof) -> bool {
    let y = challenge_statement(0x1001, bases.n, statement.a_commit, statement.b_commit, statement.c_commit);
    let yvec = powers(y, bases.nn);
    let yr = powers(y, bases.n);
    let yl: Vec<u64> = (0..bases.n).map(|i| yvec[i * bases.n]).collect();
    if !verify_zk_public_ip(bases, statement, statement.c_commit, proof.d_commit, &yvec, &bases.c, bases.scalar, &proof.c_proj, 0xC101) { return false; }
    let apb = a_projection_bases(bases, &yl);
    if !verify_zk_projection(bases, statement, statement.a_commit, proof.ay_commit, &apb, &proof.a_proj, 0xA102) { return false; }
    let bpb = b_projection_bases(bases, &yr);
    if !verify_zk_projection(bases, statement, statement.b_commit, proof.by_commit, &bpb, &proof.b_proj, 0xB103) { return false; }
    verify_zk_product(bases, statement, proof.d_commit, proof.ay_commit, proof.by_commit, &proof.product)
}

fn run_case(mode: &str, n: usize, seed: u64, valid: bool) -> bool {
    let bases = make_bases(n);
    let mut witness = generate_witness(n, seed, 64, valid);
    let mut rng = seed ^ 0x5151_5151_5151_5151;
    let is_zk = mode == "zk";
    let statement = commit_statement(&bases, &mut witness, is_zk, &mut rng);
    if is_zk {
        let proof = prove_zk(&bases, &statement, &witness, &mut rng);
        verify_zk(&bases, &statement, &proof)
    } else {
        let proof = prove_core(&bases, &statement, &witness);
        verify_core(&bases, &statement, &proof)
    }
}

fn self_test() {
    for mode in ["core", "zk"] {
        for n in [2usize, 4, 8, 16] {
            let valid = run_case(mode, n, 1000 + n as u64, true);
            let invalid = run_case(mode, n, 2000 + n as u64, false);
            assert!(valid, "valid case failed: mode={mode} n={n}");
            assert!(!invalid, "invalid case accepted: mode={mode} n={n}");
        }
    }
    println!("self-test ok");
}

fn bench_one(mode: &str, n: usize, seed: u64) {
    let bases = make_bases(n);
    let mut rng_gen = seed;
    let mut a = vec![0; n * n];
    let mut b = vec![0; n * n];
    let mut c = vec![0; n * n];
    for i in 0..n * n {
        a[i] = rng_small(&mut rng_gen, 64);
        b[i] = rng_small(&mut rng_gen, 64);
    }
    let start = Instant::now();
    matmul_mod(&a, &b, &mut c, n);
    let matmul_s = start.elapsed().as_secs_f64();
    let mut witness = Witness { a, b, c, a_blind: 0, b_blind: 0, c_blind: 0 };
    let mut rng = seed ^ 0x5151_5151_5151_5151;
    let is_zk = mode == "zk";
    let statement = commit_statement(&bases, &mut witness, is_zk, &mut rng);
    if is_zk {
        let start = Instant::now();
        let proof = prove_zk(&bases, &statement, &witness, &mut rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk(&bases, &statement, &proof);
        let verify_s = start.elapsed().as_secs_f64();
        println!("{mode},{n},{matmul_s:.9},{prove_s:.9},{verify_s:.9},{:.3},{verified}", prove_s / matmul_s);
    } else {
        let start = Instant::now();
        let proof = prove_core(&bases, &statement, &witness);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_core(&bases, &statement, &proof);
        let verify_s = start.elapsed().as_secs_f64();
        println!("{mode},{n},{matmul_s:.9},{prove_s:.9},{verify_s:.9},{:.3},{verified}", prove_s / matmul_s);
    }
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  zkmatrix-rs self-test");
    eprintln!("  zkmatrix-rs case <core|zk> <n> <seed> <valid|invalid>");
    eprintln!("  zkmatrix-rs bench <core|zk> <n> [n...]");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        usage();
        std::process::exit(1);
    }
    match args[1].as_str() {
        "self-test" => self_test(),
        "case" => {
            if args.len() != 6 {
                usage();
                std::process::exit(1);
            }
            let mode = &args[2];
            let n: usize = args[3].parse().unwrap();
            let seed: u64 = args[4].parse().unwrap();
            let valid = match args[5].as_str() {
                "valid" => true,
                "invalid" => false,
                _ => {
                    usage();
                    std::process::exit(1);
                }
            };
            if mode != "core" && mode != "zk" {
                usage();
                std::process::exit(1);
            }
            println!("verified={}", run_case(mode, n, seed, valid));
        }
        "bench" => {
            if args.len() < 4 {
                usage();
                std::process::exit(1);
            }
            let mode = &args[2];
            if mode != "core" && mode != "zk" {
                usage();
                std::process::exit(1);
            }
            println!("mode,n,exact_matmul_s,prove_s,verify_s,proof_over_exact_matmul,verified");
            for n_arg in &args[3..] {
                let n: usize = n_arg.parse().unwrap();
                bench_one(mode, n, 0xABC000 + n as u64);
            }
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
