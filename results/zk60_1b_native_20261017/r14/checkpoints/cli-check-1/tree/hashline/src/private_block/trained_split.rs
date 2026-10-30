//! Experimental R14 trained-stack CLI. Reuses the authenticated export loader,
//! H-1 sealing and bounded one-block cache; never dispatches legacy profiles.
//! Stdout from proving is prover-private, as in the existing trained CLI.
use super::*;
use crate::private_block::{
    split_endpoint, split_geometry, split_profile::SplitProfile, split_run, wire,
};
use crate::{field::Fp, ntt::NttTables};

const SCHEMA: &str = "zk60-trained-split-stack-run/1";
const POLICY_MAGIC: &[u8; 8] = b"HLR14IO1";
const POLICY_BYTES: usize = 200;
const LABELS: [&str; 1] = ["zk60-r14-split-experimental"];
const MARKER: &[u8] = b"Experimental R14 unverified statement. Only a verifier that independently rebuilds the model and verifies every segment may publish statement/. No privacy acceptance is claimed.\n";

fn require_experimental(f: &[(String, String)]) -> Result<(), String> {
    if flag(f, "--experimental-r14").is_none() {
        return Err("--experimental-r14 is required; this profile has not received privacy/release acceptance".into());
    }
    Ok(())
}
pub fn trained_split_stack_prove_command(args: &[String]) -> i32 {
    let f = match flags(
        args,
        &[
            "--export",
            "--seq",
            "--seq-dir",
            "--out",
            "--layers",
            "--label",
            "--witness-cache-gib",
        ],
        &[
            "--experimental-r14",
            "--dd",
            "--rope-from-export",
            "--verify-in-process",
        ],
    ) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_split_stack stack-prove: {e}");
            return 2;
        }
    };
    match prove(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"refused\",\"error\":{}}}", js(&e));
            1
        }
    }
}
pub fn trained_split_stack_verify_command(args: &[String]) -> i32 {
    let f = match flags(
        args,
        &[
            "--export",
            "--artifact",
            "--layers",
            "--label",
            "--expect-statement",
            "--expect-binding",
        ],
        &["--experimental-r14", "--dd", "--rope-from-export"],
    ) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_split_stack stack-verify: {e}");
            return 2;
        }
    };
    match verify(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"rejected\",\"error\":{}}}", js(&e));
            1
        }
    }
}

struct PublicBlocks<'a>(SharedCache<'a>);
impl split_run::PublicBlockSource for PublicBlocks<'_> {
    fn count(&self) -> usize {
        self.0.borrow().layers.len()
    }
    fn block(&mut self, k: usize) -> Result<run::BlockRef<'_>, String> {
        Ok(run::BlockRef::Shared(self.0.borrow_mut().get(k)?))
    }
}
struct SplitWitness<'a>(StackSource<'a>);
impl split_run::WitnessSource for SplitWitness<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.0.witness_of(k)
    }
    fn boundary_pieces(&mut self, k: usize) -> Result<[Vec<Fp>; 2], String> {
        if k == 0 || k >= self.0.n {
            return Err("R14 CLI: undeclared boundary".into());
        }
        let plane = RunWitnessSource::boundary_plane(&mut self.0, k - 1)?;
        pieces(&self.0.chain.shapes[k - 1], A_X2, &plane)
    }
}
fn pieces(shape: &Shape, role: usize, plane: &[i16]) -> Result<[Vec<Fp>; 2], String> {
    let profile = SplitProfile::new(shape.clone())?;
    let parent = Ids::new(shape)?.at(role);
    let numeric = plane.iter().map(|&v| i64::from(v)).collect::<Vec<_>>();
    let parts = split_geometry::gather_numeric_plane(shape, profile.layout(), parent, &numeric)?;
    parts
        .into_iter()
        .map(|(_, v)| v.into_iter().map(Fp::from_i64).collect::<Vec<_>>())
        .collect::<Vec<_>>()
        .try_into()
        .map_err(|_| "R14 CLI: exactly two true-width endpoint pieces required".into())
}
fn policy(st: &split_run::Statement, model: Digest, context: Digest) -> Vec<u8> {
    let mut out = POLICY_MAGIC.to_vec();
    for word in [
        st.plan().digest(),
        model,
        context,
        st.input(),
        st.output(),
        st.binding(),
    ] {
        out.extend_from_slice(&word)
    }
    out
}
fn policy_words(bytes: &[u8]) -> Result<[Digest; 6], String> {
    if bytes.len() != POLICY_BYTES || &bytes[..8] != POLICY_MAGIC {
        return Err("R14 CLI: expected.bin is not the canonical R14 joint-endpoint policy".into());
    }
    Ok(std::array::from_fn(|i| {
        bytes[8 + 32 * i..40 + 32 * i]
            .try_into()
            .expect("fixed policy extent")
    }))
}
fn bind_policy(
    plan: split_run::Plan,
    model: Digest,
    context: Digest,
    bytes: &[u8],
) -> Result<split_run::Statement, String> {
    let words = policy_words(bytes)?;
    if words[0] != plan.digest() || words[1] != model || words[2] != context {
        return Err(
            "R14 CLI: policy plan/model/context differs from the independently rebuilt statement"
                .into(),
        );
    }
    let st = plan.bind(words[3], words[4])?;
    if st.binding() != words[5] || policy(&st, model, context) != bytes {
        return Err("R14 CLI: policy binding differs".into());
    }
    Ok(st)
}
fn render_statement(
    ex: &TrainedExport,
    model: &TrainedModelStatement,
    st: &split_run::Statement,
    context: Digest,
    layers: &[u32],
    label: &str,
    writer: StatementWriter,
    claims: &ProverClaims,
) -> String {
    let profiles=(0..st.plan().len()).map(|k|{
        let p=st.plan().stage(k).expect("declared stage");let s=p.base();let layout=p.layout();
        format!("{{\"descriptor\":{},\"arithmetic_reference\":{},\"tokens\":{},\"width\":{},\"hidden\":{},\"log_cols\":{},\"f_e\":{},\"f_p\":{},\"a_rows\":{},\"h_rows\":{},\"m_rows\":{},\"slots\":{}}}",
            js(&hex(&p.digest())),js(s.profile),s.tokens,s.width,s.hidden,s.log_cols,s.f_e,s.f_p,layout.a_rows,layout.h_rows,layout.m_rows,layout.slots.len())
    }).collect::<Vec<_>>().join(",");
    format!("{{\"schema\":{},\"experimental\":true,\"privacy_accepted\":false,\"variant\":{},\"layers\":{:?},\"blocks\":{},\"statement_identity\":{},\"plan\":{},\"binding\":{},\"context\":{},\"input_root\":{},\"output_root\":{},\"label\":{},\"profiles\":[{}],\"statement_written_by\":{},\"prover_reported\":{{\"what\":{},\"backend\":{},\"gpu_declines\":{}}}}}\n",
        js(SCHEMA),js(&ex.variant),layers,layers.len(),js(&hex(&model.identity())),js(&hex(&st.plan().digest())),js(&hex(&st.binding())),js(&hex(&context)),js(&hex(&st.input())),js(&hex(&st.output())),js(label),profiles,js(writer.text()),js(PROVER_REPORTED_WHAT),js(&claims.backend),claims.gpu_declines)
}
fn claims_of(bytes: &[u8]) -> Result<(StatementWriter, ProverClaims), String> {
    let value = parse_json(bytes)?;
    if value.get("schema")?.str()? != SCHEMA {
        return Err("R14 CLI: statement schema differs".into());
    }
    let writer = value.get("statement_written_by")?.str()?;
    let writer = StatementWriter::ALL
        .iter()
        .copied()
        .find(|w| w.text() == writer)
        .ok_or("R14 CLI: unknown statement writer")?;
    let reported = value.get("prover_reported")?;
    let backend = reported.get("backend")?.str()?.to_string();
    let declines = u64::try_from(reported.get("gpu_declines")?.i64()?)
        .map_err(|_| "R14 CLI: negative GPU decline report")?;
    check_prover_reported(&backend, declines)?;
    Ok((
        writer,
        ProverClaims {
            backend,
            gpu_declines: declines,
        },
    ))
}
fn verify_dir(
    st: &split_run::Statement,
    cache: SharedCache<'_>,
    dir: &Path,
) -> Result<Vec<(u64, String)>, String> {
    let mut verifier = split_run::Verifier::with_source(st, Box::new(PublicBlocks(cache)))?;
    let paths = super::super::run_sink::segment_paths(dir, st.plan().len())?;
    let mut seen = Vec::with_capacity(paths.len());
    for (k, path) in paths.iter().enumerate() {
        let expected =
            wire::split::Geometry::new(st.plan().stage(k)?, st.plan().len(), k)?.encoded_len();
        let bytes = read_bounded(path, expected as u64)?;
        if bytes.len() != expected {
            return Err(format!(
                "R14 CLI: segment{k} length differs from trusted geometry"
            ));
        }
        verifier.verify_next(&bytes)?;
        seen.push((bytes.len() as u64, hex(&sha256(&bytes))));
    }
    verifier.finish()?;
    Ok(seen)
}
fn present(path: &Path) -> Result<bool, String> {
    match std::fs::symlink_metadata(path) {
        Ok(_) => Ok(true),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(e.to_string()),
    }
}
fn prove(f: &[(String, String)]) -> Result<(), String> {
    require_experimental(f)?;
    let started = Instant::now();
    let export = PathBuf::from(need(f, "--export")?);
    let seq = SeqSource::of(f)?;
    let out = PathBuf::from(need(f, "--out")?);
    let unverified = unverified_statement_dir(&out)?;
    let label = label_of(f, &LABELS)?;
    if present(&out)? || present(&unverified)? {
        return Err("R14 CLI: output or unverified statement already exists".into());
    }
    let budget = flag(f, "--witness-cache-gib")
        .unwrap_or("0")
        .parse::<f64>()
        .map_err(|_| "R14 CLI: witness cache is not a number")?;
    if !budget.is_finite() || !(0.0..=64.0).contains(&budget) {
        return Err("R14 CLI: witness cache outside0..64GiB".into());
    }
    crate::gpu::require_live()?;
    let mut ex = TrainedExport::load(&export)?;
    if flag(f, "--dd").is_some() {
        ex.enable_dd()?
    }
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let rope = flag(f, "--rope-from-export").is_some();
    // The existing authenticated loader and exact witness/parity pass finish
    // before any run header or output directory is created (H-1).
    let (constants, shape, _loaded, digests, model, chain, seal) = seal_and_record(
        &ex,
        &layers,
        rope,
        &seq,
        (budget * (1u64 << 30) as f64) as u64,
    )?;
    let context = stack_context(&ex.variant, &layers, label)?;
    let scales = vec![model.calibration.block_scales; layers.len()];
    let plan = split_run::Plan::from_records(shape.clone(), context, &model, &scales)?;
    let input = pieces(&chain.shapes[0], A_X, &chain.first)?;
    let output = pieces(
        chain.shapes.last().expect("nonempty sealed chain"),
        A_X2,
        &chain.last,
    )?;
    let ntt = NttTables::new(super::super::protocol::ntt_log_at(&shape));
    let incoming = split_endpoint::prepare(&plan.endpoint(false)?, [&input[0], &input[1]], &ntt)?;
    let outgoing = split_endpoint::prepare(&plan.endpoint(true)?, [&output[0], &output[1]], &ntt)?;
    let st = plan.bind(incoming.commitment().root, outgoing.commitment().root)?;
    let expected = policy(&st, model.identity(), context);
    println!("{{\"event\":\"sealed\",\"experimental\":true,\"privacy_accepted\":false,\"blocks\":{},\"parity\":\"bit-exact at every layer\",\"checked_before_run_header\":true,\"seconds\":{:.3},\"of_which_load_seconds\":{:.3},\"of_which_witness_seconds\":{:.3},\"kept_witness_bytes\":{}}}",layers.len(),seal.wall_s,seal.load_s,seal.witness_s,chain.kept_bytes);
    let cache = BlockCache::shared(
        &ex,
        &shape,
        &constants,
        layers.clone(),
        digests.clone(),
        rope,
    );
    let mut witness = SplitWitness(StackSource::new(
        &shape,
        cache.clone(),
        layers.len(),
        chain,
        None,
    )?);
    std::fs::create_dir(&out).map_err(|e| format!("{}: {e}", out.display()))?;
    let result = (|| -> Result<(), String> {
        let mut disk = super::super::run_sink::DirSink::create(&out, layers.len())?;
        let tick = Instant::now();
        split_run::prove_with_source(
            &st,
            &mut PublicBlocks(cache.clone()),
            &mut witness,
            [incoming, outgoing],
            &mut |k, bytes| {
                let size = bytes.len();
                super::super::run_sink::SegmentSink::accept(&mut disk, k, bytes)?;
                println!("{{\"event\":\"segment\",\"index\":{k},\"layer\":{},\"bytes\":{size},\"elapsed_seconds\":{:.3}}}",layers[k],tick.elapsed().as_secs_f64());
                Ok(())
            },
        )?;
        let prove_seconds = tick.elapsed().as_secs_f64();
        drop(witness);
        drop(cache);
        let seen = disk
            .lengths()
            .iter()
            .zip(disk.digests())
            .map(|(&n, h)| (n as u64, h.clone()))
            .collect::<Vec<_>>();
        let in_process = flag(f, "--verify-in-process").is_some();
        if in_process {
            let checked = verify_dir(
                &st,
                BlockCache::shared(
                    &ex,
                    &shape,
                    &constants,
                    layers.clone(),
                    digests.clone(),
                    rope,
                ),
                &out,
            )?;
            if checked != seen {
                return Err("R14 CLI: verified segment bytes differ from the prover's sink".into());
            }
        }
        let claims = ProverClaims::of_this_process();
        check_prover_reported(&claims.backend, claims.gpu_declines)?;
        let writer = if in_process {
            StatementWriter::InProcess
        } else {
            StatementWriter::Unverified
        };
        let statement =
            render_statement(&ex, &model, &st, context, &layers, label, writer, &claims);
        let segments = render_segments_json(&seen);
        if in_process {
            publish_statement_dir(
                &out,
                &[
                    ("expected.bin", &expected),
                    ("statement.json", statement.as_bytes()),
                    ("segments.json", segments.as_bytes()),
                ],
            )?;
        } else {
            std::fs::create_dir(&unverified).map_err(|e| e.to_string())?;
            let result = (|| -> Result<(), String> {
                for (name, bytes) in [
                    (UNVERIFIED_MARKER, MARKER),
                    ("expected.bin", expected.as_slice()),
                    ("statement.json", statement.as_bytes()),
                    ("segments.json", segments.as_bytes()),
                ] {
                    write_new(&unverified.join(name), bytes)?
                }
                Ok(())
            })();
            if let Err(error) = result {
                let cleanup = std::fs::remove_dir_all(&unverified);
                return Err(format!(
                    "{error}; own unverified-directory cleanup: {cleanup:?}"
                ));
            }
        }
        println!("{{\"event\":\"proven\",\"experimental\":true,\"privacy_accepted\":false,\"verified_in_process\":{in_process},\"blocks\":{},\"statement_identity\":{},\"binding\":{},\"prove_seconds\":{prove_seconds:.3},\"total_seconds\":{:.3},\"vmhwm_mib\":{:.0},\"scope\":\"R14 split trained backend; no classifier or privacy acceptance\"}}",layers.len(),js(&hex(&model.identity())),js(&hex(&st.binding())),started.elapsed().as_secs_f64(),peak_rss_mib());
        Ok(())
    })();
    result.map_err(|e| fail_run(&out, e))
}
fn verify(f: &[(String, String)]) -> Result<(), String> {
    require_experimental(f)?;
    let export = PathBuf::from(need(f, "--export")?);
    let artifact = PathBuf::from(need(f, "--artifact")?);
    let expected_model = unhex32(need(f, "--expect-statement")?)?;
    let expected_binding = unhex32(need(f, "--expect-binding")?)?;
    let label = label_of(f, &LABELS)?;
    refuse_prover_private_entries(&export)?;
    let mut ex = TrainedExport::load(&export)?;
    if flag(f, "--dd").is_some() {
        ex.enable_dd()?
    }
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let rope = flag(f, "--rope-from-export").is_some();
    let (constants, shape, _loaded, digests, model) = stack_records(&ex, &layers, rope)?;
    if model.identity() != expected_model {
        return Err("R14 CLI: independently rebuilt model is not the expected statement".into());
    }
    let context = stack_context(&ex.variant, &layers, label)?;
    let plan = split_run::Plan::from_records(
        shape.clone(),
        context,
        &model,
        &vec![model.calibration.block_scales; layers.len()],
    )?;
    clear_stale_writing_dirs(&artifact)?;
    let verified_dir = artifact.join(super::super::run_sink::STATEMENT_DIR);
    let unverified = unverified_statement_dir(&artifact)?;
    let (found, promote) = match (present(&verified_dir)?, present(&unverified)?) {
        (true, false) => (verified_dir.clone(), false),
        (false, true) => (unverified.clone(), true),
        _ => {
            return Err(
                "R14 CLI: exactly one verified or unverified statement directory is required"
                    .into(),
            )
        }
    };
    let names: &[&str] = if promote {
        &[
            UNVERIFIED_MARKER,
            "expected.bin",
            "statement.json",
            "segments.json",
        ]
    } else {
        &["expected.bin", "statement.json", "segments.json"]
    };
    check_statement_dir(&found, names)?;
    let expected = read_bounded(&found.join("expected.bin"), POLICY_BYTES as u64)?;
    let st = bind_policy(plan, model.identity(), context, &expected)?;
    if st.binding() != expected_binding {
        return Err("R14 CLI: run binding differs from the caller's pin".into());
    }
    let seen = verify_dir(
        &st,
        BlockCache::shared(&ex, &shape, &constants, layers.clone(), digests, rope),
        &artifact,
    )?;
    #[cfg(test)]
    if let Some(h) = AFTER_VERIFY_HOOK.with(|h| h.borrow_mut().take()) {
        h()
    }
    let statement = read_bounded(&found.join("statement.json"), MAX_JSON_BYTES)?;
    let (writer, claims) = claims_of(&statement)?;
    let allowed = if promote {
        writer == StatementWriter::Unverified
    } else {
        matches!(
            writer,
            StatementWriter::InProcess | StatementWriter::FreshVerify
        )
    };
    if !allowed
        || render_statement(&ex, &model, &st, context, &layers, label, writer, &claims).as_bytes()
            != statement
    {
        return Err("R14 CLI: statement is not the verifier's canonical rendering".into());
    }
    let segments = render_segments_json(&seen);
    if read_bounded(&found.join("segments.json"), MAX_JSON_BYTES)? != segments.as_bytes() {
        return Err(
            "R14 CLI: segment manifest does not describe the bytes consumed by verification".into(),
        );
    }
    if promote {
        if read_bounded(&found.join(UNVERIFIED_MARKER), 4096)? != MARKER {
            return Err("R14 CLI: unverified marker differs".into());
        }
        let statement = render_statement(
            &ex,
            &model,
            &st,
            context,
            &layers,
            label,
            StatementWriter::FreshVerify,
            &claims,
        );
        publish_statement_dir(
            &artifact,
            &[
                ("expected.bin", &expected),
                ("statement.json", statement.as_bytes()),
                ("segments.json", segments.as_bytes()),
            ],
        )?;
        check_statement_dir(&unverified, names)?;
        std::fs::remove_dir_all(&unverified).map_err(|e|format!("R14 CLI: verified statement published; failed to remove its old unverified directory: {e}"))?;
    }
    println!("{{\"event\":\"verified\",\"experimental\":true,\"privacy_accepted\":false,\"blocks\":{},\"statement_identity\":{},\"binding\":{},\"statement_promoted\":{promote}}}",layers.len(),js(&hex(&model.identity())),js(&hex(&st.binding())));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn split_cli_policy_is_versioned_and_exact_length() {
        let mut bytes = POLICY_MAGIC.to_vec();
        for i in 1..=6 {
            bytes.extend_from_slice(&[i; 32])
        }
        assert_eq!(
            policy_words(&bytes).unwrap(),
            std::array::from_fn(|i| [i as u8 + 1; 32])
        );
        for n in [0, 7, 8, 199] {
            assert!(policy_words(&bytes[..n]).is_err())
        }
        let mut longer = bytes.clone();
        longer.push(0);
        assert!(policy_words(&longer).is_err());
        bytes[0] ^= 1;
        assert!(policy_words(&bytes).is_err());
    }
    #[test]
    fn split_cli_requires_explicit_experimental_flag_before_io() {
        assert!(require_experimental(&[]).is_err());
        assert!(require_experimental(&[("--experimental-r14".into(), "".into())]).is_ok());
        assert_eq!(trained_split_stack_prove_command(&[]), 1);
        assert_eq!(trained_split_stack_verify_command(&[]), 1);
        assert_eq!(trained_split_stack_verify_command(&["--unknown".into()]), 2);
    }
}
