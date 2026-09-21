//! **STAGE 18: the PUBLIC RUN STATEMENT, retained beside the segments.**
//!
//! A run leaves `L` segment files in `HL_PB_RUN_DIR` and nothing else. The
//! segments are the PROOF; they are not the STATEMENT, and no verifier can do
//! anything with them without one. Until this module, everything the
//! statement is made of lived only inside the process that proved the run —
//! so a twelve-block 125M run left 484 MB of receipt that no later process
//! could check.
//!
//! This module writes that statement out as ONE small deterministic JSON
//! file, `<run dir>/statement/run-statement.json`, and reads it back into the
//! `RunStatement` and the `L` `BlockPublic`s a FRESH `RunVerifier` needs.
//!
//! **THE CAPTURE RULE APPLIES HERE IN FULL: a retained file beside the
//! segments is PUBLISHING.** Nothing computed from a hidden input is written
//! — no witness, no hidden plane, no salt, no pad, no blinding row, no prover
//! log, no timing. Every member of the file is a value the VERIFIER ALREADY
//! TAKES AS ITS PUBLIC STATEMENT: the run's geometry, the two external
//! endpoint commitments and their scales, the per-block public digests, the
//! calibration identity, the hash rule, the internal boundaries' public
//! statement digests, and the segment files' own lengths and SHA-256. The
//! ledger's stage 18 section traces every one of them to the line of `run.rs`
//! at which the verifier consumes it.
//!
//! **THE PUBLIC WEIGHTS ARE NOT DUMPED.** They are regenerated from a named
//! deterministic RECIPE ([`WeightsRecipe`]) and checked against the
//! `block_digests` the run header absorbs. A run whose blocks the named
//! recipe does not reproduce gets no statement file.
//!
//! **RULING D21.** The file is written only AFTER the whole run has verified
//! in this process. [`verify_then_write`] is the only writer and it verifies
//! first, so a failed run leaves no statement file and no `statement/`
//! directory.
//!
//! **What this is NOT.** It is not a privacy result, and it is not an
//! authorisation: reading a statement out of an untrusted producer's
//! directory does not make its endpoint commitments approved, exactly as
//! `ExpectedIo`'s own doc comment says. It makes a run CHECKABLE by a process
//! that did not prove it. Who may be believed about the endpoints is the same
//! question it was before.
//!
//! Test-only, like `run_capture.rs`: nothing here enters the library or the
//! binary.

use super::run::{self, RunShape, RunStatement};
use super::run_sink;
use super::shape::Shape;
use super::{BlockPublic, ExpectedIo, IoSpec};
use std::io::Write;
use std::path::{Path, PathBuf};

/// The file's schema. A reader refuses a schema it does not know rather than
/// guessing at a field.
pub(super) const SCHEMA: &str = "hashline-private-run-statement/1";
/// The file's name inside [`run_sink::STATEMENT_DIR`].
pub(super) const FILE_NAME: &str = "run-statement.json";

/// `<run dir>/statement/run-statement.json`
pub(super) fn statement_path(dir: &Path) -> PathBuf {
    dir.join(run_sink::STATEMENT_DIR).join(FILE_NAME)
}

fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

// ---------------------------------------------------------------- the weights recipe

/// **HOW THE PUBLIC WEIGHTS ARE OBTAINED, named rather than dumped.** The
/// verifier's statement holds one DIGEST per block and nothing else about the
/// weights (`BlockPublic::digest`, absorbed at `run.rs`'s
/// `tr.absorb(b"pb-run-block", ...)`), so a statement file does not need the
/// values — it needs a way back to them and a digest to check them against.
/// A recipe is a deterministic generator this crate already has.
#[derive(Clone, Copy)]
pub(super) struct WeightsRecipe {
    /// the name written into the file and matched on when reading
    pub name: &'static str,
    /// what it is, for a human
    pub description: &'static str,
}

/// The lane's public synthetic tame fixture at the run's own block shape,
/// repeated for every block — which is what every run in this lane uses
/// (`run_tests::blocks_of`).
pub(super) const TAME_FIXTURE: WeightsRecipe = WeightsRecipe {
    name: "private_block::grow_tests::tame_case(<block profile's Shape>), the same public fixture for every block",
    description: "deliberately public synthetic test weights, regenerated from the shape; no weight value is written into this file, and every regenerated block is checked against the block_digests the run header absorbs",
};

/// **STAGE 21: the FULLY DENSE run recipe.** Every entry of all nine public
/// words nonzero, at the down-projection band a CHAIN can carry, the same
/// for every block. The name carries the seed, the read order and every
/// band, so the string alone is enough for a reader to regenerate the
/// weights — which is the whole contract of this field.
pub(super) const DENSE_RUN_FIXTURE: WeightsRecipe = WeightsRecipe {
    name: super::dense_tests::DENSE_RUN_RECIPE_NAME,
    description: "deliberately public synthetic test weights, FULLY DENSE (no zero entry in any of the nine words) and regenerated from the shape by the named deterministic stream; no weight value is written into this file, and every regenerated block is checked against the block_digests the run header absorbs",
};

/// The ONE block a recipe produces at this shape. Kept separate from
/// [`blocks_of_recipe`] because the WRITER only needs a digest to compare
/// against, and `L` copies of a 125M public statement are 110 MB.
fn recipe_block(recipe: &str, sh: &Shape) -> Result<BlockPublic, String> {
    let (public, ff) = if recipe == TAME_FIXTURE.name {
        let (p, f, _) = super::grow_tests::tame_case(sh);
        (p, f)
    } else if recipe == DENSE_RUN_FIXTURE.name {
        // STAGE 21: the fully dense run recipe, regenerated from the shape
        // by exactly the stream the name describes
        let (p, f, _) = super::dense_tests::dense_run_case(sh);
        (p, f)
    } else {
        return Err(format!("run statement: this build knows two weights recipes and the file names {recipe:?}"));
    };
    Ok(BlockPublic::new(public, ff))
}

/// The blocks a recipe produces at this shape, for a run of `l` blocks: this
/// recipe's every block is the same public fixture.
fn blocks_of_recipe(recipe: &str, sh: &Shape, l: usize) -> Result<Vec<BlockPublic>, String> {
    let b = recipe_block(recipe, sh)?;
    Ok((0..l).map(|_| b.clone()).collect())
}

/// The block shapes, by profile string. A reader builds the shape from THIS
/// BUILD'S code and then compares the file's `shape` block with it field by
/// field, so a file that disagrees is refused rather than quietly re-shaping
/// the verifier.
fn shape_of_profile(profile: &str) -> Result<Shape, String> {
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::m125()] {
        if sh.profile == profile {
            return Ok(sh);
        }
    }
    Err(format!("run statement: {profile:?} is not a block profile this build has"))
}

/// The two run profiles, likewise.
fn run_profile_of(profile: &str) -> Result<&'static str, String> {
    for p in [run::RUN_PROFILE_RUNG_G, run::RUN_PROFILE_M125] {
        if p == profile {
            return Ok(p);
        }
    }
    Err(format!("run statement: {profile:?} is not a run profile this build has"))
}

// ---------------------------------------------------------------- writing

/// What [`verify_then_write`] did, for the caller's report.
#[derive(Debug)]
pub(super) struct Written {
    /// wall seconds the streaming verification took, measured around it
    pub verify_s: f64,
    pub path: PathBuf,
    pub bytes: usize,
    pub sha256: String,
}

/// Every string this writer emits is plain printable ASCII, so `{:?}`'s
/// escaping is JSON's. Rust's `Debug` renders a non-ASCII character as
/// `\u{..}`, which is NOT valid JSON, so such a string is refused rather than
/// written.
fn ascii(what: &str, s: &str) -> Result<String, String> {
    if s.bytes().any(|b| !(0x20..0x7f).contains(&b)) {
        return Err(format!("run statement: {what} is not printable ASCII and would not be valid JSON: {s:?}"));
    }
    Ok(format!("{s:?}"))
}

/// **THE ONLY WAY TO WRITE A STATEMENT FILE (ruling D21).** The whole run is
/// verified from its directory FIRST, one segment at a time; only if that
/// returns `Ok` is anything written.
///
/// The recipe is checked too: the regenerated blocks must have exactly the
/// digests this run's statement absorbs, or nothing is written — a statement
/// naming a recipe that does not reproduce its own blocks would be worse than
/// no statement at all.
pub(super) fn verify_then_write(st: &RunStatement, blocks: &[BlockPublic], dir: &Path, recipe: &WeightsRecipe) -> Result<Written, String> {
    let t0 = std::time::Instant::now();
    run::verify_run_from_dir(st, blocks, dir)?;
    let verify_s = t0.elapsed().as_secs_f64();
    let bytes = render(st, blocks, dir, recipe)?;
    let sdir = dir.join(run_sink::STATEMENT_DIR);
    std::fs::create_dir_all(&sdir).map_err(|e| format!("run statement: {}: {e}", sdir.display()))?;
    let path = statement_path(dir);
    let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).map_err(|e| format!("run statement: {}: {e}", path.display()))?;
    f.write_all(&bytes).map_err(|e| format!("run statement: {}: {e}", path.display()))?;
    f.sync_all().map_err(|e| format!("run statement: {}: {e}", path.display()))?;
    Ok(Written { verify_s, path, bytes: bytes.len(), sha256: crate::export_v3::sha256_hex(&bytes) })
}

/// The file's bytes. Deterministic: the same run written twice gives the same
/// bytes. Nothing here reads a clock or a random number, and the only
/// environment variable is the source-commit tag every artifact of this lane
/// carries.
fn render(st: &RunStatement, blocks: &[BlockPublic], dir: &Path, recipe: &WeightsRecipe) -> Result<Vec<u8>, String> {
    let h = st.capture_header()?;
    let binding = st.binding()?;
    let sh = &st.rs.sh;
    let l = st.rs.l;
    if blocks.len() != l {
        return Err(format!("run statement: {} public statements for {l} blocks", blocks.len()));
    }
    // THE RECIPE MUST REPRODUCE THIS RUN'S BLOCKS, or no file is written.
    let regenerated = blocks_of_recipe(recipe.name, sh, l)?;
    for (k, (a, b)) in regenerated.iter().zip(blocks.iter()).enumerate() {
        if a.digest() != b.digest() {
            return Err(format!("run statement: the named weights recipe does not reproduce block {k}'s public digest; no statement file is written"));
        }
    }
    // the segment files, read ONE AT A TIME so that no more than one
    // segment's bytes are ever resident — the rule the streaming verifier
    // obeys, and the reason a 484 MB receipt can be pinned inside a ceiling
    let paths = run_sink::segment_paths(dir, l)?;
    let mut segs: Vec<(String, usize, String)> = Vec::with_capacity(l);
    for (k, p) in paths.iter().enumerate() {
        let bytes = std::fs::read(p).map_err(|e| format!("run statement: segment {k} ({}) cannot be read: {e}", p.display()))?;
        segs.push((run_sink::segment_file_name(k), bytes.len(), crate::export_v3::sha256_hex(&bytes)));
    }
    let tag = sh.hash_tag();

    let mut o: Vec<u8> = Vec::new();
    write!(o, "{{").expect("write to a Vec");
    // one top-level member per line, and never a space between a key and its
    // colon, so that `run_capture::keys_of` reads this file too
    let line = |o: &mut Vec<u8>, key: &str, value: String, first: bool| {
        write!(o, "{}\n  {key:?}:{value}", if first { "" } else { "," }).expect("write to a Vec");
    };

    line(&mut o, "schema", ascii("the schema", SCHEMA)?, true);
    line(&mut o, "kind", "\"zk60-private-run-public-statement\"".into(), false);
    line(&mut o, "written_by", "\"hashline/src/private_block/run_statement_file.rs\"".into(), false);
    line(
        &mut o,
        "what_this_is",
        "\"the PUBLIC statement of one private run, retained beside its segments so that a process that did not prove the run can rebuild the verifier's statement and check it. NOT a privacy result, and NOT an authorisation of these endpoint commitments.\"".into(),
        false,
    );
    line(&mut o, "source_commit", ascii("the source commit tag", &std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into()))?, false);
    line(&mut o, "digest_encoding", "\"every digest, root, key and byte string is lower-case hex\"".into(), false);

    // ---- the run's identity and geometry
    line(&mut o, "run_profile", ascii("the run profile", h.profile)?, false);
    line(&mut o, "block_profile", ascii("the block profile", sh.profile)?, false);
    line(&mut o, "blocks", format!("{l}"), false);
    line(
        &mut o,
        "shape",
        format!(
            "{{\"name\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"t_pad\":{},\"d_pad\":{},\"endpoint_rows\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"endpoint_general\":{},\"opened_cols\":{}}}",
            sh.name, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, sh.t_pad, sh.d_pad, sh.endpoint_rows, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.endpoint_general, sh.opened_cols
        ),
        false,
    );
    line(&mut o, "run_shape_words", format!("{:?}", h.run_shape_words), false);

    // ---- the run's public statement, in absorb order
    line(&mut o, "context", format!("{:?}", hex(&h.context)), false);
    line(
        &mut o,
        "expected_io",
        format!(
            "{{\"input_root\":{:?},\"output_root\":{:?},\"input_scale\":{},\"output_scale\":{},\"rows\":{},\"data_rows\":{},\"log_n\":{},\"inv_rate\":{},\"policy_bytes\":{:?},\"policy_sha256\":{:?}}}",
            hex(&h.external_input_root),
            hex(&h.external_output_root),
            h.external_scales.0,
            h.external_scales.1,
            h.external_rows,
            h.external_data_rows,
            h.external_log_n,
            h.external_inv_rate,
            hex(&h.expected_bytes),
            crate::export_v3::sha256_hex(&h.expected_bytes)
        ),
        false,
    );
    line(&mut o, "block_digests", format!("[{}]", h.block_digests.iter().map(|d| format!("{:?}", hex(d))).collect::<Vec<_>>().join(",")), false);
    line(&mut o, "block_scales", format!("[{}]", block_scale_pairs(&h).iter().map(|(a, b)| format!("[{a},{b}]")).collect::<Vec<_>>().join(",")), false);
    line(&mut o, "boundary_scales", format!("{:?}", h.boundary_scales), false);
    line(&mut o, "calibration", format!("{:?}", hex(&h.calibration)), false);

    // ---- the weights, NAMED and not dumped
    line(
        &mut o,
        "public_weights",
        format!(
            "{{\"recipe\":{},\"description\":{},\"digest_domain\":\"hashline/private-block-public/1\",\"values_in_this_file\":false}}",
            ascii("the recipe name", recipe.name)?,
            ascii("the recipe description", recipe.description)?
        ),
        false,
    );

    // ---- what the verifier DERIVES, so that a reader can check the file
    // against itself before it opens a segment
    line(
        &mut o,
        "derived",
        format!(
            "{{\"public_statement_digest\":{:?},\"parameter_line\":{},\"schedule_digest\":{:?},\"run_binding\":{:?}}}",
            hex(&h.public_statement),
            ascii("the parameter line", &h.parameter_line)?,
            hex(&h.schedule_digest),
            hex(&binding)
        ),
        false,
    );
    let mut stages = Vec::with_capacity(l);
    for s in &h.stage_lines {
        stages.push(ascii("a stage line", s)?);
    }
    line(&mut o, "stage_lines", format!("[{}]", stages.join(",")), false);

    // ---- WHICH HASH RULE MADE EVERY BYTE OF THIS RUN
    let keys = match (tag.transcript_key(), tag.column_key(), tag.leaf_key(), tag.node_key()) {
        (Some(t), Some(c), Some(lf), Some(nd)) => format!(
            ",\"profile\":{:?},\"contexts\":{{\"transcript\":{:?},\"column\":{:?},\"leaf\":{:?},\"node\":{:?}}},\"keys_hex\":{{\"transcript\":{:?},\"column\":{:?},\"leaf\":{:?},\"node\":{:?}}}",
            sh.profile,
            zkp_core::hashtag::CTX_TRANSCRIPT,
            zkp_core::hashtag::CTX_COLUMN,
            zkp_core::hashtag::CTX_LEAF,
            zkp_core::hashtag::CTX_NODE,
            hex(t),
            hex(c),
            hex(lf),
            hex(nd)
        ),
        _ => String::new(),
    };
    line(
        &mut o,
        "hash_tag",
        format!(
            "{{\"rule\":{:?}{keys},\"re_derive_never_consume\":\"a reader derives the four keys from the contexts and the block profile and COMPARES; nothing here may select a rule or hand a key to a verifier (ruling T-7)\"}}",
            tag.rule_name()
        ),
        false,
    );

    // ---- the internal boundaries, as PUBLIC facts
    let mut bs = Vec::with_capacity(h.boundaries.len());
    for (i, b) in h.boundaries.iter().enumerate() {
        bs.push(format!(
            "{{\"boundary\":{i},\"index\":{},\"scale\":{},\"sites\":{},\"data_rows\":{},\"rows\":{},\"site_rows\":{:?},\"prox_row\":{},\"log_n\":{},\"inv_rate\":{},\"checks\":{},\"statement_digest\":{:?},\"row_rule\":\"data + 2*sites + 2\",\"committed_at_stage\":{i},\"opened_at_stage\":{}}}",
            b.index,
            b.scale,
            b.sites,
            b.data_rows,
            b.rows,
            b.site_rows,
            b.prox_row,
            b.log_n,
            b.inv_rate,
            b.checks,
            hex(&b.digest),
            i + 1
        ));
    }
    line(&mut o, "internal_boundaries", format!("[{}]", bs.join(",")), false);

    // ---- the receipt on disk
    line(
        &mut o,
        "segments",
        format!(
            "{{\"count\":{l},\"total_bytes\":{},\"directory\":\"the parent of this file's directory\",\"files\":[{}]}}",
            segs.iter().map(|(_, n, _)| n).sum::<usize>(),
            segs.iter().map(|(n, b, s)| format!("{{\"file\":{n:?},\"bytes\":{b},\"sha256\":{s:?}}}")).collect::<Vec<_>>().join(",")
        ),
        false,
    );

    // ---- the negative declaration, as a capture bundle carries one
    line(
        &mut o,
        "not_in_this_file",
        "[\"witness values\",\"hidden inputs, outputs and boundary planes\",\"pad values\",\"mask coefficients\",\"salts\",\"prover randomness\",\"public weight values (regenerated from the recipe)\",\"any timing, memory figure or prover log\"]".into(),
        false,
    );
    line(
        &mut o,
        "ruling_d21",
        "\"this file exists only because the whole run verified in the process that wrote it: verify_then_write is the only writer and it verifies first\"".into(),
        false,
    );
    writeln!(o, "\n}}").expect("write to a Vec");
    Ok(o)
}

/// `(input scale, output scale)` of every block, as `RunStatement::new` takes
/// them: block 0's input and block `L-1`'s output are the endpoint policy's,
/// and every interior pair is the ONE scale its boundary carries (ruling
/// M-4).
fn block_scale_pairs(h: &super::run_capture::RunHeader) -> Vec<(i32, i32)> {
    let l = h.l;
    (0..l)
        .map(|k| {
            (
                if k == 0 { h.external_scales.0 } else { h.boundary_scales[k - 1] },
                if k + 1 == l { h.external_scales.1 } else { h.boundary_scales[k] },
            )
        })
        .collect()
}

// ---------------------------------------------------------------- reading it back

/// **THE FILE ALONE, PLUS THIS BUILD'S PUBLIC SHAPE AND WEIGHTS RECIPE,
/// REBUILDS THE VERIFIER'S STATEMENT.** Nothing else is read and nothing is
/// carried over from the process that proved the run.
///
/// Every derived quantity in the file is RECOMPUTED from the file's own
/// primary values and compared, so a file whose endpoint commitment, context,
/// scale, block digest, stage schedule or boundary geometry has been altered
/// is refused BY NAME here, before a segment is opened; and a file that
/// agrees with itself but not with the segments is refused by the verifier
/// afterwards.
pub(super) fn read(dir: &Path) -> Result<(RunStatement, Vec<BlockPublic>), String> {
    let path = statement_path(dir);
    let bytes = std::fs::read(&path).map_err(|e| format!("run statement: {}: {e}", path.display()))?;
    let j = json::parse(&bytes)?;
    let check = |what: &str, got: String, want: String| -> Result<(), String> {
        if got == want {
            Ok(())
        } else {
            Err(format!("run statement: {what}: this statement gives {got}, the file declares {want}"))
        }
    };
    check("the schema", SCHEMA.into(), j.get("schema")?.str()?.into())?;
    check("the kind", "zk60-private-run-public-statement".into(), j.get("kind")?.str()?.into())?;

    // ---- the primary values, which are all a reader may take from the file
    let l = j.get("blocks")?.int()? as usize;
    let sh = shape_of_profile(j.get("block_profile")?.str()?)?;
    let profile = run_profile_of(j.get("run_profile")?.str()?)?;
    let context = j.get("context")?.hex32()?;
    let e = j.get("expected_io")?;
    let (in_scale, out_scale) = (e.get("input_scale")?.int()? as i32, e.get("output_scale")?.int()? as i32);
    let spec = IoSpec::new_shaped(&sh, context, in_scale, out_scale)?;
    let expected = ExpectedIo::from_roots(spec, e.get("input_root")?.hex32()?, e.get("output_root")?.hex32()?);
    let mut scales: Vec<(i32, i32)> = Vec::with_capacity(l);
    for (k, p) in j.get("block_scales")?.arr()?.iter().enumerate() {
        let pair = p.arr()?;
        if pair.len() != 2 {
            return Err(format!("run statement: block {k}'s scale pair has {} entries", pair.len()));
        }
        scales.push((pair[0].int()? as i32, pair[1].int()? as i32));
    }
    // the weights, regenerated from the named recipe and checked against the
    // digests the run header absorbs
    let w = j.get("public_weights")?;
    if w.get("values_in_this_file")?.boolean()? {
        return Err("run statement: this file claims to carry weight values; it may not".into());
    }
    let blocks = blocks_of_recipe(w.get("recipe")?.str()?, &sh, l)?;
    let declared = j.get("block_digests")?.arr()?;
    if declared.len() != l {
        return Err(format!("run statement: {} block digests for {l} blocks", declared.len()));
    }
    for (k, d) in declared.iter().enumerate() {
        if d.hex32()? != blocks[k].digest() {
            return Err(format!("run statement: the recipe's block {k} is not the block digest the file declares"));
        }
    }

    // ---- THE STATEMENT, rebuilt
    let rs = RunShape::new(sh.clone(), l, profile)?;
    let st = RunStatement::new(rs, context, expected, &blocks, &scales)?;
    let h = st.capture_header()?;

    // ---- and EVERYTHING ELSE in the file recomputed and compared. This is
    // what makes the file self-checking: a one-byte change anywhere in it is
    // caught here, by the name of the member it changed.
    let fs = j.get("shape")?;
    check("the shape name", sh.name.into(), fs.get("name")?.str()?.into())?;
    for (key, got) in [
        ("tokens", sh.tokens),
        ("width", sh.width),
        ("hidden", sh.hidden),
        ("q_heads", sh.q_heads),
        ("kv_heads", sh.kv_heads),
        ("head_dim", sh.head_dim),
        ("t_pad", sh.t_pad),
        ("d_pad", sh.d_pad),
        ("endpoint_rows", sh.endpoint_rows),
        ("endpoint_log_n", sh.endpoint_log_n),
        ("endpoint_inv_rate", sh.endpoint_inv_rate),
        ("opened_cols", sh.opened_cols),
    ] {
        check(&format!("shape.{key}"), got.to_string(), fs.get(key)?.int()?.to_string())?;
    }
    check("shape.endpoint_general", sh.endpoint_general.to_string(), fs.get("endpoint_general")?.boolean()?.to_string())?;
    check("run_shape_words", format!("{:?}", h.run_shape_words), format!("{:?}", j.get("run_shape_words")?.ints()?))?;
    // THE RUN BINDING FIRST. It is the transcript state a verifier would
    // START from, and it is a function of every public word of the header, so
    // a change to any of them lands here — which is the refusal worth seeing
    // first when an endpoint commitment has been altered.
    let d = j.get("derived")?;
    for (what, got, want) in [
        ("the run binding", hex(&st.binding()?), d.get("run_binding")?.str()?.to_string()),
        ("the public statement digest", hex(&h.public_statement), d.get("public_statement_digest")?.str()?.to_string()),
        ("the schedule digest", hex(&h.schedule_digest), d.get("schedule_digest")?.str()?.to_string()),
        ("the parameter line", h.parameter_line.clone(), d.get("parameter_line")?.str()?.to_string()),
    ] {
        check(what, got, want)?;
    }
    for (what, got, want) in [
        ("the endpoint policy bytes", hex(&h.expected_bytes), e.get("policy_bytes")?.str()?.to_string()),
        ("the endpoint policy SHA-256", crate::export_v3::sha256_hex(&h.expected_bytes), e.get("policy_sha256")?.str()?.to_string()),
        ("the external endpoint rows", h.external_rows.to_string(), e.get("rows")?.int()?.to_string()),
        ("the external endpoint data rows", h.external_data_rows.to_string(), e.get("data_rows")?.int()?.to_string()),
        ("the external endpoint log_n", h.external_log_n.to_string(), e.get("log_n")?.int()?.to_string()),
        ("the external endpoint inv_rate", h.external_inv_rate.to_string(), e.get("inv_rate")?.int()?.to_string()),
        ("the boundary scales", format!("{:?}", h.boundary_scales), format!("{:?}", j.get("boundary_scales")?.ints()?)),
        ("the block scale pairs", format!("{:?}", block_scale_pairs(&h)), format!("{:?}", scales)),
        ("the calibration identity", hex(&h.calibration), j.get("calibration")?.str()?.to_string()),
    ] {
        check(what, got, want)?;
    }
    let lines = j.get("stage_lines")?.arr()?;
    if lines.len() != l {
        return Err(format!("run statement: {} stage lines for {l} stages", lines.len()));
    }
    for (k, s) in lines.iter().enumerate() {
        check(&format!("stage line {k}"), h.stage_lines[k].clone(), s.str()?.to_string())?;
    }

    // THE HASH RULE IS RE-DERIVED AND NEVER CONSUMED (ruling T-7): the tag
    // comes from the shape this build trusts, and the file's copy of it is
    // compared with that.
    let tag = sh.hash_tag();
    let ht = j.get("hash_tag")?;
    check("the hash rule", tag.rule_name().into(), ht.get("rule")?.str()?.into())?;
    if let (Some(t), Some(c), Some(lf), Some(nd)) = (tag.transcript_key(), tag.column_key(), tag.leaf_key(), tag.node_key()) {
        check("the tagged profile", sh.profile.into(), ht.get("profile")?.str()?.into())?;
        let ctx = ht.get("contexts")?;
        let ks = ht.get("keys_hex")?;
        for (role, want_ctx, want_key) in [
            ("transcript", zkp_core::hashtag::CTX_TRANSCRIPT, t),
            ("column", zkp_core::hashtag::CTX_COLUMN, c),
            ("leaf", zkp_core::hashtag::CTX_LEAF, lf),
            ("node", zkp_core::hashtag::CTX_NODE, nd),
        ] {
            check(&format!("the {role} key context"), want_ctx.into(), ctx.get(role)?.str()?.into())?;
            check(&format!("the {role} key"), hex(want_key), ks.get(role)?.str()?.into())?;
        }
    }

    let boundaries = j.get("internal_boundaries")?.arr()?;
    if boundaries.len() != h.boundaries.len() {
        return Err(format!("run statement: {} internal boundaries in the file, this run has {}", boundaries.len(), h.boundaries.len()));
    }
    for (k, b) in h.boundaries.iter().enumerate() {
        let f = &boundaries[k];
        check(&format!("boundary {k}'s statement digest"), hex(&b.digest), f.get("statement_digest")?.str()?.into())?;
        for (key, got) in [("index", b.index), ("sites", b.sites), ("data_rows", b.data_rows), ("rows", b.rows), ("prox_row", b.prox_row), ("log_n", b.log_n), ("inv_rate", b.inv_rate), ("checks", b.checks), ("opened_at_stage", k + 1)] {
            check(&format!("boundary {k}'s {key}"), got.to_string(), f.get(key)?.int()?.to_string())?;
        }
        check(&format!("boundary {k}'s scale"), b.scale.to_string(), f.get("scale")?.int()?.to_string())?;
        check(&format!("boundary {k}'s site rows"), format!("{:?}", b.site_rows), format!("{:?}", f.get("site_rows")?.ints()?))?;
    }

    // ---- and the segment files on disk ARE the ones this statement was
    // written beside, by length and SHA-256, read one at a time
    let segs = j.get("segments")?;
    check("the segment count", l.to_string(), segs.get("count")?.int()?.to_string())?;
    let files = segs.get("files")?.arr()?;
    if files.len() != l {
        return Err(format!("run statement: {} segment records for {l} segments", files.len()));
    }
    let paths = run_sink::segment_paths(dir, l)?;
    let mut total = 0i64;
    for (k, p) in paths.iter().enumerate() {
        let f = &files[k];
        check(&format!("segment record {k}'s name"), run_sink::segment_file_name(k), f.get("file")?.str()?.into())?;
        let bytes = std::fs::read(p).map_err(|e| format!("run statement: segment {k} ({}) cannot be read: {e}", p.display()))?;
        check(&format!("segment {k}'s length on disk"), bytes.len().to_string(), f.get("bytes")?.int()?.to_string())?;
        check(&format!("segment {k}'s SHA-256 on disk"), crate::export_v3::sha256_hex(&bytes), f.get("sha256")?.str()?.into())?;
        total += f.get("bytes")?.int()?;
    }
    check("the receipt's total bytes", total.to_string(), segs.get("total_bytes")?.int()?.to_string())?;

    Ok((st, blocks))
}

/// **THE WHOLE POINT, IN ONE CALL**: rebuild the statement from the files on
/// disk and verify the run from its segments in a FRESH `RunVerifier`.
pub(super) fn verify_from_disk(dir: &Path) -> Result<(), String> {
    let (st, blocks) = read(dir)?;
    run::verify_run_from_dir(&st, &blocks, dir)
}

// ---------------------------------------------------------------- the allow list

/// **EVERY KEY THIS WRITER MAY EMIT.**
/// `every_key_of_a_run_statement_is_on_the_allow_list` fails if it ever emits
/// one that is not here. Adding a key to this list is the moment to ask
/// whether the quantity behind it is in the VERIFIER'S public statement: a
/// retained file beside the segments is publishing.
pub(super) const ALLOWED_KEYS: &[&str] = &[
    "schema",
    "kind",
    "written_by",
    "what_this_is",
    "source_commit",
    "digest_encoding",
    "run_profile",
    "block_profile",
    "blocks",
    "shape",
    "name",
    "tokens",
    "width",
    "hidden",
    "q_heads",
    "kv_heads",
    "head_dim",
    "t_pad",
    "d_pad",
    "endpoint_rows",
    "endpoint_log_n",
    "endpoint_inv_rate",
    "endpoint_general",
    "opened_cols",
    "run_shape_words",
    "context",
    "expected_io",
    "input_root",
    "output_root",
    "input_scale",
    "output_scale",
    "rows",
    "data_rows",
    "log_n",
    "inv_rate",
    "policy_bytes",
    "policy_sha256",
    "block_digests",
    "block_scales",
    "boundary_scales",
    "calibration",
    "public_weights",
    "recipe",
    "description",
    "digest_domain",
    "values_in_this_file",
    "derived",
    "public_statement_digest",
    "parameter_line",
    "schedule_digest",
    "run_binding",
    "stage_lines",
    "hash_tag",
    "rule",
    "profile",
    "contexts",
    "keys_hex",
    "transcript",
    "column",
    "leaf",
    "node",
    "re_derive_never_consume",
    "internal_boundaries",
    "boundary",
    "index",
    "scale",
    "sites",
    "site_rows",
    "prox_row",
    "checks",
    "statement_digest",
    "row_rule",
    "committed_at_stage",
    "opened_at_stage",
    "segments",
    "count",
    "total_bytes",
    "directory",
    "files",
    "file",
    "bytes",
    "sha256",
    "not_in_this_file",
    "ruling_d21",
];

// ---------------------------------------------------------------- a small strict JSON reader

/// A minimal JSON reader: enough for the file this module writes, and strict
/// about everything else. There is no JSON dependency in this crate and this
/// is not the place to add one — the reader has to be small enough to read.
///
/// It accepts objects, arrays, double-quoted strings with the seven
/// two-character escapes, INTEGERS (this writer emits no float and no
/// exponent, and one here is an error rather than a silent rounding), `true`,
/// `false`, `null`, and whitespace between tokens. A `\u` escape, a repeated
/// key in one object and any trailing byte after the value are all errors.
pub(super) mod json {
    /// One JSON value.
    #[derive(Debug, Clone, PartialEq)]
    pub(in crate::private_block) enum J {
        Null,
        Bool(bool),
        Int(i64),
        Str(String),
        Arr(Vec<J>),
        Obj(Vec<(String, J)>),
    }

    impl J {
        /// the member `key` of an object, or a named error
        pub(in crate::private_block) fn get(&self, key: &str) -> Result<&J, String> {
            match self {
                J::Obj(m) => m.iter().find(|(k, _)| k == key).map(|(_, v)| v).ok_or_else(|| format!("run statement: the file has no {key:?}")),
                _ => Err(format!("run statement: {key:?} was asked of a value that is not an object")),
            }
        }
        pub(in crate::private_block) fn str(&self) -> Result<&str, String> {
            match self {
                J::Str(s) => Ok(s),
                _ => Err(format!("run statement: {self:?} is not a string")),
            }
        }
        pub(in crate::private_block) fn int(&self) -> Result<i64, String> {
            match self {
                J::Int(v) => Ok(*v),
                _ => Err(format!("run statement: {self:?} is not an integer")),
            }
        }
        pub(in crate::private_block) fn boolean(&self) -> Result<bool, String> {
            match self {
                J::Bool(v) => Ok(*v),
                _ => Err(format!("run statement: {self:?} is not a boolean")),
            }
        }
        pub(in crate::private_block) fn arr(&self) -> Result<&[J], String> {
            match self {
                J::Arr(v) => Ok(v),
                _ => Err(format!("run statement: {self:?} is not an array")),
            }
        }
        /// an array of integers
        pub(in crate::private_block) fn ints(&self) -> Result<Vec<i64>, String> {
            self.arr()?.iter().map(|v| v.int()).collect()
        }
        /// a 32-byte digest, as 64 lower-case hex characters
        pub(in crate::private_block) fn hex32(&self) -> Result<[u8; 32], String> {
            let s = self.str()?;
            if s.len() != 64 || !s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) {
                return Err(format!("run statement: {s:?} is not 64 lower-case hex characters"));
            }
            let mut out = [0u8; 32];
            for (i, o) in out.iter_mut().enumerate() {
                *o = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).map_err(|e| format!("run statement: {s:?}: {e}"))?;
            }
            Ok(out)
        }
    }

    struct P<'a> {
        b: &'a [u8],
        i: usize,
    }

    /// Parse the WHOLE input as one JSON value. A trailing byte is an error.
    pub(in crate::private_block) fn parse(bytes: &[u8]) -> Result<J, String> {
        let mut p = P { b: bytes, i: 0 };
        let v = p.value()?;
        p.ws();
        if p.i != p.b.len() {
            return Err(format!("run statement: {} trailing bytes after the JSON value", p.b.len() - p.i));
        }
        Ok(v)
    }

    impl P<'_> {
        fn ws(&mut self) {
            while self.i < self.b.len() && matches!(self.b[self.i], b' ' | b'\t' | b'\n' | b'\r') {
                self.i += 1;
            }
        }
        fn eat(&mut self, c: u8) -> Result<(), String> {
            self.ws();
            if self.i < self.b.len() && self.b[self.i] == c {
                self.i += 1;
                Ok(())
            } else {
                Err(format!("run statement: expected {:?} at byte {}", c as char, self.i))
            }
        }
        fn value(&mut self) -> Result<J, String> {
            self.ws();
            let c = *self.b.get(self.i).ok_or("run statement: the JSON value ends early")?;
            match c {
                b'{' => self.object(),
                b'[' => self.array(),
                b'"' => Ok(J::Str(self.string()?)),
                b't' => self.literal("true", J::Bool(true)),
                b'f' => self.literal("false", J::Bool(false)),
                b'n' => self.literal("null", J::Null),
                b'-' | b'0'..=b'9' => self.int(),
                _ => Err(format!("run statement: {:?} starts no JSON value, at byte {}", c as char, self.i)),
            }
        }
        fn literal(&mut self, word: &str, v: J) -> Result<J, String> {
            if self.b[self.i..].starts_with(word.as_bytes()) {
                self.i += word.len();
                Ok(v)
            } else {
                Err(format!("run statement: a malformed literal at byte {}", self.i))
            }
        }
        fn int(&mut self) -> Result<J, String> {
            let start = self.i;
            if self.b[self.i] == b'-' {
                self.i += 1;
            }
            while self.i < self.b.len() && self.b[self.i].is_ascii_digit() {
                self.i += 1;
            }
            if self.i < self.b.len() && matches!(self.b[self.i], b'.' | b'e' | b'E') {
                return Err(format!("run statement: a non-integer number at byte {start}; this writer emits none"));
            }
            std::str::from_utf8(&self.b[start..self.i])
                .ok()
                .and_then(|s| s.parse::<i64>().ok())
                .map(J::Int)
                .ok_or_else(|| format!("run statement: a malformed integer at byte {start}"))
        }
        fn string(&mut self) -> Result<String, String> {
            self.eat(b'"')?;
            let mut s = String::new();
            loop {
                let c = *self.b.get(self.i).ok_or("run statement: an unterminated string")?;
                self.i += 1;
                match c {
                    b'"' => return Ok(s),
                    b'\\' => {
                        let e = *self.b.get(self.i).ok_or("run statement: an unterminated escape")?;
                        self.i += 1;
                        s.push(match e {
                            b'"' => '"',
                            b'\\' => '\\',
                            b'/' => '/',
                            b'b' => '\u{8}',
                            b'f' => '\u{c}',
                            b'n' => '\n',
                            b'r' => '\r',
                            b't' => '\t',
                            _ => return Err(format!("run statement: the escape \\{} at byte {} is not one this reader takes", e as char, self.i - 1)),
                        });
                    }
                    0x20..=0x7e => s.push(c as char),
                    _ => return Err(format!("run statement: a non-printable or non-ASCII byte {c:#04x} inside a string at byte {}", self.i - 1)),
                }
            }
        }
        fn array(&mut self) -> Result<J, String> {
            self.eat(b'[')?;
            let mut out = Vec::new();
            self.ws();
            if self.b.get(self.i) == Some(&b']') {
                self.i += 1;
                return Ok(J::Arr(out));
            }
            loop {
                out.push(self.value()?);
                self.ws();
                match self.b.get(self.i) {
                    Some(b',') => self.i += 1,
                    Some(b']') => {
                        self.i += 1;
                        return Ok(J::Arr(out));
                    }
                    _ => return Err(format!("run statement: an unterminated array at byte {}", self.i)),
                }
            }
        }
        fn object(&mut self) -> Result<J, String> {
            self.eat(b'{')?;
            let mut out: Vec<(String, J)> = Vec::new();
            self.ws();
            if self.b.get(self.i) == Some(&b'}') {
                self.i += 1;
                return Ok(J::Obj(out));
            }
            loop {
                self.ws();
                let k = self.string()?;
                if out.iter().any(|(e, _)| *e == k) {
                    return Err(format!("run statement: the key {k:?} appears twice in one object"));
                }
                self.eat(b':')?;
                let v = self.value()?;
                out.push((k, v));
                self.ws();
                match self.b.get(self.i) {
                    Some(b',') => self.i += 1,
                    Some(b'}') => {
                        self.i += 1;
                        return Ok(J::Obj(out));
                    }
                    _ => return Err(format!("run statement: an unterminated object at byte {}", self.i)),
                }
            }
        }
    }
}
