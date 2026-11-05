//! Experimental fresh FFN tied to two independently supplied hiding endpoints.
//! All three private owners are consumed once, and A is opened once with its
//! FFN and seam claims together. Endpoint roots must come from caller policy.
//! No registered private-model identity or whole-transcript privacy claim.
use super::*;
use crate::private_seam::{self, PreparedPlane, SeamSpec, Side};

#[cfg(test)]
#[path = "zk_ffn_fresh_io_tests.rs"]
mod tests;

pub const PROFILE: &[u8] = b"hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/3";
const MAGIC: &[u8; 8] = b"HFFNIO\0\x02";
const FIRST_IO_SLOT: usize = 6;
const ENDPOINT_OPEN_BYTES: usize = 2 * 512 * 16 + 256 * (8 + 7 * 8 + 32 + 11 * 32);
const ARGUMENT_BYTES: usize = 16 + 10 * 3 * 16 + 2 * 16 + 16;
const EXTRA_BYTES: usize = 8 + 32 + 2 * ARGUMENT_BYTES + 2 * ENDPOINT_OPEN_BYTES;
pub const EXPECTED_BYTES: usize = 8 + 32 + 4 + 4 + 2 * 32;

/// Trusted request/connection metadata. Scales describe the integer words;
/// calibration/model authorization is the enclosing application's obligation.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct IoSpec {
    context: Digest,
    input_scale: i32,
    output_scale: i32,
}
impl IoSpec {
    pub fn new(context: Digest, input_scale: i32, output_scale: i32) -> Result<Self, String> {
        let spec = Self {
            context,
            input_scale,
            output_scale,
        };
        spec.seams()?;
        Ok(spec)
    }
    fn seams(&self) -> Result<[SeamSpec; 2], String> {
        Ok([
            SeamSpec::new(self.context, 32, 16, self.input_scale, 1, 2)?,
            SeamSpec::new(self.context, 32, 16, self.output_scale, 3, 4)?,
        ])
    }
}

/// Public policy, constructed by the endpoint owner before FFN proving.
/// Reading this from an untrusted producer does NOT authorize those endpoints.
#[derive(Clone, Debug)]
pub struct ExpectedIo {
    spec: IoSpec,
    input: Commitment,
    output: Commitment,
}
impl ExpectedIo {
    pub fn from_roots(spec: IoSpec, input: Digest, output: Digest) -> Self {
        Self {
            spec,
            input: Commitment {
                root: input,
                rows: 7,
                log_cols: 8,
            },
            output: Commitment {
                root: output,
                rows: 7,
                log_cols: 8,
            },
        }
    }
    pub fn input_root(&self) -> Digest {
        self.input.root
    }
    pub fn output_root(&self) -> Digest {
        self.output.root
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut b = Vec::with_capacity(EXPECTED_BYTES);
        b.extend_from_slice(b"HFFNEXP1");
        b.extend_from_slice(&self.spec.context);
        b.extend_from_slice(&self.spec.input_scale.to_le_bytes());
        b.extend_from_slice(&self.spec.output_scale.to_le_bytes());
        b.extend_from_slice(&self.input.root);
        b.extend_from_slice(&self.output.root);
        b
    }
    pub fn from_bytes(b: &[u8]) -> Result<Self, String> {
        if b.len() != EXPECTED_BYTES {
            return Err("FFN IO: expected-policy length".into());
        }
        let mut r = wire::Reader { bytes: b, pos: 0 };
        if &r.take::<8>()? != b"HFFNEXP1" {
            return Err("FFN IO: expected-policy version".into());
        }
        let spec = IoSpec::new(
            r.take()?,
            i32::from_le_bytes(r.take()?),
            i32::from_le_bytes(r.take()?),
        )?;
        Ok(Self::from_roots(spec, r.take()?, r.take()?))
    }
}

/// Private endpoint owners: no Clone, serialization or value getter.
pub struct Endpoints {
    input: PreparedPlane,
    output: PreparedPlane,
}

pub fn prepare_endpoints(
    spec: IoSpec,
    input: &[Fp],
    output: &[Fp],
) -> Result<(ExpectedIo, Endpoints), String> {
    let [si, so] = spec.seams()?;
    let ntt = NttTables::new(12);
    let input = private_seam::prepare(&si, Side::Right, input, &ntt)?;
    let output = private_seam::prepare(&so, Side::Right, output, &ntt)?;
    let expected = ExpectedIo::from_roots(spec, input.commitment().root, output.commitment().root);
    Ok((expected, Endpoints { input, output }))
}

/// A private pending FFN, usable only by consuming `finish`. It exposes no
/// partial proof, commitment internals or arbitrary-opening interface.
///
/// ```compile_fail
/// use hashline::zk::fresh_poc::io::{PendingProof, Endpoints};
/// fn twice(p: PendingProof, first: Endpoints, second: Endpoints) {
///     let _ = p.finish(first);
///     let _ = p.finish(second); // the first attempt consumed the owner
/// }
/// ```
pub struct PendingProof {
    pending: PendingV3,
    tr: Transcript,
    expected: ExpectedIo,
}

fn transcript(expected: &ExpectedIo) -> Transcript {
    let mut tr = Transcript::new(PROFILE);
    tr.absorb(b"expected-IO", &expected.to_bytes());
    tr.absorb(
        b"parameters",
        b"T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams",
    );
    tr
}

pub fn prepare(
    w: &V3Witness,
    privacy: ZkPrivacy,
    expected: &ExpectedIo,
) -> Result<PendingProof, String> {
    check_witness(w, privacy)?;
    expected.spec.seams()?;
    let cfg = ZkConfig {
        enabled: true,
        seed: None,
        mode: ZkStatementMode {
            privacy,
            ..Default::default()
        },
    };
    let mut tr = transcript(expected);
    let rng = ZkRng::from_os(PROFILE).map_err(|e| format!("FFN IO randomness: {e}"))?;
    let pending = prepare_layer_zk_v3_inner(
        w,
        32,
        &parameters(),
        &NttTables::new(16),
        &cfg,
        &mut tr,
        true,
        true,
        rng,
    )?;
    Ok(PendingProof {
        pending,
        tr,
        expected: expected.clone(),
    })
}

#[derive(Clone, Debug, Default)]
struct Argument {
    gamma: Fp2,
    sc: SumcheckProof,
    terminals: [Fp2; 2],
    mask_eval: Fp2,
}

#[derive(Debug)]
pub struct Receipt {
    ffn: LayerProofZk,
    arguments: [Argument; 2],
    endpoint_open: [OpeningZk; 2],
}

fn poly(v: &[Fp2]) -> Fp2 {
    v[0].mul(v[1].sub(v[2]))
}
fn mask_value(cm: &pcs::CommittedZk, row: usize, rho: &[Fp2]) -> Fp2 {
    MaskPoint::new(&rho[rho.len() - 8..], 256).eval2(&cm.data, (row, row + 1))
}
fn claim(offset: usize, row: usize, rho: &[Fp2], e: Fp2, value: Fp2) -> ZClaim {
    let tail = rho[rho.len() - 8..].to_vec();
    ZClaim {
        value,
        parts: vec![
            ZPart {
                slice: Slice {
                    offset,
                    log_size: 9,
                },
                coef: Fp2::ONE.sub(e),
                point: rho.to_vec(),
            },
            ZPart {
                slice: Slice {
                    offset: row * 256,
                    log_size: 8,
                },
                coef: e,
                point: tail.clone(),
            },
            ZPart {
                slice: Slice {
                    offset: (row + 1) * 256,
                    log_size: 8,
                },
                coef: e.mul(Fp2::U),
                point: tail,
            },
        ],
    }
}
fn functionals(slot: usize, rho: &[Fp2], c: Fp2, a: &Argument) -> [MaskFunctional; 2] {
    [
        MaskFunctional {
            terms: vec![(
                slot,
                CfsMask::sum_weights(10, 2)
                    .iter()
                    .map(|x| x.mul(c))
                    .collect(),
            )],
            value: a.gamma,
        },
        MaskFunctional {
            terms: vec![(slot, CfsMask::eval_weights(rho, 2))],
            value: a.mask_eval,
        },
    ]
}
fn absorb_argument(a: &Argument, tr: &mut Transcript) {
    tr.absorb_fp2(b"io-terminals", &a.terminals);
    tr.absorb_fp2(b"io-mask-eval", &[a.mask_eval]);
}
fn check_endpoints(
    expected: &ExpectedIo,
    endpoints: Endpoints,
) -> Result<[pcs::CommittedZk; 2], String> {
    let [si, so] = expected.spec.seams()?;
    let input = endpoints.input.into_ffn_endpoint(&si)?;
    let output = endpoints.output.into_ffn_endpoint(&so)?;
    if input.commitment().root != expected.input.root
        || output.commitment().root != expected.output.root
    {
        return Err("FFN IO: expected endpoint root mismatch".into());
    }
    Ok([input, output])
}

impl PendingProof {
    /// Consumes all private owners on success or failure. No equality precheck:
    /// unequal committed values must fail the verifier's polynomial identity.
    pub fn finish(mut self, endpoints: Endpoints) -> Result<Receipt, String> {
        let endpoints = check_endpoints(&self.expected, endpoints)?;
        let ntt = NttTables::new(16);
        // Slots 6 and 7 already belong to the FFN M absorbed before its challenges.
        // No new randomness or commitment can be introduced during finalization.
        let mc = &self.pending.mc;
        let mut arguments: [Argument; 2] = Default::default();
        let mut right_claims = Vec::new();
        let offsets = [self.pending.zl.lay.x[0], self.pending.zl.lay.z[0]];
        let rows = self
            .pending
            .zl
            .a_io
            .ok_or("FFN IO: missing mask allocation")?;
        for i in 0..2 {
            self.tr.absorb_u64(b"io-side", i as u64);
            let tau = self.tr.challenge_fp2_vec(9);
            let c = draw_mask_challenge(|| self.tr.challenge_fp2(), true)?;
            let mut a = Argument {
                gamma: c.mul(mc.masks[FIRST_IO_SLOT + i].total()),
                ..Default::default()
            };
            self.tr.absorb_fp2(b"io-gamma", &[a.gamma]);
            let mut tables = vec![
                eq_table_msb(&tau),
                self.pending.a.data[offsets[i]..offsets[i] + 512]
                    .iter()
                    .copied()
                    .map(Fp2::from_base)
                    .collect(),
                endpoints[i].data[..512]
                    .iter()
                    .copied()
                    .map(Fp2::from_base)
                    .collect(),
            ];
            let (mut rounds, mut rho, finals) = masked_prove(
                &mut tables,
                2,
                poly,
                &mc.masks[FIRST_IO_SLOT + i],
                c,
                &mut self.tr,
            );
            let exts = [
                Fp2::ZERO,
                mask_value(&self.pending.a, rows[i], &rho),
                mask_value(&endpoints[i], 2, &rho),
            ];
            let e = extension(
                &finals,
                &exts,
                2,
                poly,
                &mc.masks[FIRST_IO_SLOT + i],
                c,
                &rho,
                &mut rounds,
                &mut self.tr,
            );
            if e.is_zero() {
                return Err("FFN IO: zero terminal mask challenge; discard attempt".into());
            }
            a.terminals = [
                masked_terminal(finals[1], exts[1], e),
                masked_terminal(finals[2], exts[2], e),
            ];
            self.pending
                .ac
                .push(claim(offsets[i], rows[i], &rho, e, a.terminals[0]));
            right_claims.push(claim(0, 2, &rho, e, a.terminals[1]));
            rho.push(e);
            a.mask_eval = mc.masks[FIRST_IO_SLOT + i].eval(&rho);
            a.sc = SumcheckProof { rounds };
            absorb_argument(&a, &mut self.tr);
            self.pending
                .fs
                .extend(functionals(FIRST_IO_SLOT + i, &rho, c, &a));
            arguments[i] = a;
        }
        let ffn = self.pending.finish(&ntt, &mut self.tr)?.proof;
        let mut endpoint_open: [OpeningZk; 2] = Default::default();
        for (i, endpoint) in endpoints.into_iter().enumerate() {
            let claims = std::slice::from_ref(&right_claims[i]);
            check_masks(claims, 7, 8, &[2, 3], 4, &self.tr)?;
            endpoint_open[i] = pcs::open_zk(&endpoint, claims, &mut self.tr);
        }
        Ok(Receipt {
            ffn,
            arguments,
            endpoint_open,
        })
    }
}

fn verify_arguments(
    zl: &ZkLayoutV3,
    receipt: &Receipt,
    tr: &mut Transcript,
    ac: &mut Vec<ZClaim>,
    fs: &mut Vec<MaskFunctional>,
) -> Result<Vec<ZClaim>, String> {
    let offsets = [zl.lay.x[0], zl.lay.z[0]];
    let rows = zl.a_io.ok_or("FFN IO: missing mask allocation")?;
    let mut right = Vec::new();
    for i in 0..2 {
        let a = &receipt.arguments[i];
        #[cfg(test)]
        let before = Transcript::clone_state(tr);
        tr.absorb_u64(b"io-side", i as u64);
        let tau = tr.challenge_fp2_vec(9);
        let c = draw_mask_challenge(|| tr.challenge_fp2(), true)?;
        tr.absorb_fp2(b"io-gamma", &[a.gamma]);
        let (fin, rho) = sumcheck::verify(a.gamma, 2, 10, &a.sc, tr)
            .map_err(|e| format!("IO {i} sumcheck: {e}"))?;
        let e = rho[9];
        if e.is_zero() {
            return Err("FFN IO: zero terminal mask challenge".into());
        }
        let eq = Fp2::ONE.sub(e).mul(eq_point(&tau, &rho[..9]));
        let want = eq
            .mul(a.terminals[0].sub(a.terminals[1]))
            .add(c.mul(a.mask_eval));
        if fin != want {
            return Err(format!("IO {i}: equality terminal"));
        }
        ac.push(claim(offsets[i], rows[i], &rho[..9], e, a.terminals[0]));
        right.push(claim(0, 2, &rho[..9], e, a.terminals[1]));
        absorb_argument(a, tr);
        fs.extend(functionals(FIRST_IO_SLOT + i, &rho, c, a));
        #[cfg(test)]
        mask_diagnostic::io::argument(i, &tau, c, &rho, a.gamma, &a.sc, a.terminals, a.mask_eval, &before, tr);
    }
    Ok(right)
}

pub fn verify(
    st: &StatementV3,
    weights: WeightStatement,
    expected: &ExpectedIo,
    receipt: &Receipt,
) -> Result<(), String> {
    #[cfg(test)]
    mask_diagnostic::io::begin();
    preflight(st)?;
    let privacy = match weights {
        WeightStatement::Public(root) => {
            if receipt.ffn.w_com.as_ref().ok_or("FFN IO: missing W")?.root != root {
                return Err("FFN IO: public W root mismatch".into());
            }
            ZkPrivacy::P1
        }
        WeightStatement::FreshPrivate => ZkPrivacy::P3,
    };
    // The receipt type is opaque, but validate typed shape/canonicality too.
    #[cfg(test)]
    let canonical_bytes = receipt.to_bytes(st, weights, expected)?;
    #[cfg(not(test))]
    receipt.to_bytes(st, weights, expected)?;
    let mut tr = transcript(expected);
    let ntt = NttTables::new(16);
    let mut right = Vec::new();
    let mode = ZkStatementMode {
        privacy,
        ..Default::default()
    };
    verify_layer_zk_v3_with_seams(
        st,
        &receipt.ffn,
        &parameters(),
        &ntt,
        &mut tr,
        &mode,
        true,
        true,
        |zl, ac, fs, tr| {
            right = verify_arguments(zl, receipt, tr, ac, fs)?;
            Ok(())
        },
    )?;
    let pcs = parameters().pcs_for(8);
    for (i, endpoint) in [&expected.input, &expected.output].into_iter().enumerate() {
        let claims = std::slice::from_ref(&right[i]);
        check_masks(claims, 7, 8, &[2, 3], 4, &tr)?;
        #[cfg(test)]
        let mut observed = mask_diagnostic::io::capture(mask_diagnostic::Role::A, &pcs, endpoint, claims, &receipt.endpoint_open[i], &tr);
        pcs::verify_zk(
            &pcs,
            &ZkOpts::standard(&pcs),
            endpoint,
            claims,
            &receipt.endpoint_open[i],
            &ntt,
            &mut tr,
        )
        .map_err(|e| format!("IO endpoint {i}: {e}"))?;
        #[cfg(test)]
        {
            mask_diagnostic::finish(&mut observed, &tr);
            mask_diagnostic::io::record(["Input", "Output"][i], observed);
        }
    }
    #[cfg(test)]
    mask_diagnostic::io::publish(st, privacy, expected.to_bytes(), canonical_bytes, &receipt.ffn);
    Ok(())
}

fn binding(
    st: &StatementV3,
    weights: WeightStatement,
    expected: &ExpectedIo,
) -> Result<Digest, String> {
    let expected = ExpectedIo::from_bytes(&expected.to_bytes())?;
    super::wire::io_payload_len(st, weights)?;
    let mut tr = transcript(&expected);
    absorb_statement_v3(&mut tr, st);
    tr.absorb(
        b"actual-table",
        &st.table
            .iter()
            .flat_map(|x| x.to_le_bytes())
            .collect::<Vec<_>>(),
    );
    match weights {
        WeightStatement::Public(root) => tr.absorb(b"public-W", &root),
        WeightStatement::FreshPrivate => tr.absorb(b"private-W", b"fresh"),
    }
    Ok(tr.state())
}
pub fn encoded_len(st: &StatementV3, weights: WeightStatement) -> Result<usize, String> {
    let len = wire::io_payload_len(st, weights)? + EXTRA_BYTES;
    if len > MAX_WIRE_BYTES {
        return Err("FFN IO: frame exceeds bound".into());
    }
    Ok(len)
}

impl Receipt {
    pub fn to_bytes(
        &self,
        st: &StatementV3,
        weights: WeightStatement,
        expected: &ExpectedIo,
    ) -> Result<Vec<u8>, String> {
        let payload = wire::encode_io_payload(st, weights, &self.ffn)?;
        let mut out = Vec::with_capacity(encoded_len(st, weights)?);
        out.extend_from_slice(MAGIC);
        out.extend_from_slice(&binding(st, weights, expected)?);
        out.extend_from_slice(&payload);
        for a in &self.arguments {
            if a.sc.rounds.len() != 10 || a.sc.rounds.iter().any(|r| r.len() != 3) {
                return Err("FFN IO: sumcheck shape".into());
            }
            out.extend_from_slice(&a.gamma.to_bytes());
            a.sc.write_bytes(&mut out);
            for t in a.terminals {
                out.extend_from_slice(&t.to_bytes());
            }
            out.extend_from_slice(&a.mask_eval.to_bytes());
        }
        for o in &self.endpoint_open {
            if o.group_vecs.len() != 1
                || o.group_vecs[0].len() != 512
                || o.prox_vec.len() != 512
                || o.columns.len() != 256
                || o.columns
                    .iter()
                    .any(|(j, c, _, p)| *j >= 2048 || c.len() != 7 || p.len() != 11)
            {
                return Err("FFN IO: endpoint opening shape".into());
            }
            o.write_bytes(&mut out);
        }
        Self::from_bytes(st, weights, expected, &out)?;
        Ok(out)
    }
    pub fn from_bytes(
        st: &StatementV3,
        weights: WeightStatement,
        expected: &ExpectedIo,
        bytes: &[u8],
    ) -> Result<Self, String> {
        if bytes.len() != encoded_len(st, weights)? {
            return Err("FFN IO: frame length".into());
        }
        let mut r = wire::Reader { bytes, pos: 0 };
        if &r.take::<8>()? != MAGIC {
            return Err("FFN IO: frame profile".into());
        }
        if r.take::<32>()? != binding(st, weights, expected)? {
            return Err("FFN IO: expected statement mismatch".into());
        }
        let end = r.pos + wire::io_payload_len(st, weights)?;
        let ffn = wire::decode_io_payload(st, weights, &bytes[r.pos..end])?;
        r.pos = end;
        let mut arguments: [Argument; 2] = Default::default();
        for a in &mut arguments {
            let (gamma, sc, terms) = r.argument((10, 2), 2)?;
            *a = Argument {
                gamma,
                sc,
                terminals: [terms[0], terms[1]],
                mask_eval: r.fp2()?,
            };
        }
        let endpoint_open = [r.hiding(1, 7)?, r.hiding(1, 7)?];
        if r.pos != bytes.len() {
            return Err("FFN IO: trailing bytes".into());
        }
        Ok(Self {
            ffn,
            arguments,
            endpoint_open,
        })
    }
}

pub fn verify_bytes(
    st: &StatementV3,
    weights: WeightStatement,
    expected: &ExpectedIo,
    bytes: &[u8],
) -> Result<(), String> {
    #[cfg(test)]
    mask_diagnostic::io::begin();
    verify(
        st,
        weights,
        expected,
        &Receipt::from_bytes(st, weights, expected, bytes)?,
    )
}
