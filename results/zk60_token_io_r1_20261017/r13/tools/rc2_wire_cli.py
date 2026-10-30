#!/usr/bin/env python3
"""R-C2 step 2: wire the classifier CLI (prove and the verifier's door) to the tied loader,
add the D27 --min-bits floor, bump the statement schema to /2 with the margin scale and the
tied source rendered. Applied only after the failing-first run (b1) compiled the unwired tree.
Exact-match edits; refuses if any anchor is not found exactly once."""
import sys

P = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r12b/hashline/src/private_block/token_io/classify_cli.rs"
s = open(P).read()


def rep(old, new):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit(f"anchor found {n} times: {old[:80]!r}")
    s = s.replace(old, new)


# the prover: policy first, then the tables re-derived and compared
rep('''    let p = load_export(Path::new(need(f, "--export")?))?;
    let sh = &p.sh;
    let (tables, bos, norm) = load_classifier_tables(Path::new(need(f, "--tables")?), sh.width)?;
    let policy = policy_by_id(need(f, "--policy")?)?;
''', '''    let export = PathBuf::from(need(f, "--export")?);
    let p = load_export(&export)?;
    let sh = &p.sh;
    // R-C2: the policy first (its yes / no ids and public margin scale), then
    // the tables RE-DERIVED from the pinned tied tensor and compared with the
    // files; the run's margin row is the recomputed one
    let policy = policy_by_id(need(f, "--policy")?)?;
    let (tables, bos, norm) = super::classify_tied::load_tied_classifier_tables(&p, &export, Path::new(need(f, "--tables")?), &policy)?;
''')
# the verifier's door: the D27 floor, then the same tied loader
rep('''    let p = load_export(&export)?;
    let want = unhex32(need(f, "--expect-statement")?)?;
    if p.model.identity() != want {
        return Err(format!("the export's trained statement identity (classifier run profile) is {}, not the pinned one", hex(&p.model.identity())));
    }
    let (tables, bos, norm) = load_classifier_tables(Path::new(need(f, "--tables")?), p.sh.width)?;
    let policy = policy_by_id(need(f, "--policy")?)?;
''', '''    let p = load_export(&export)?;
    // D27: 93 bits only at the development rung; 95 at every other profile
    let floor = super::classify_tied::min_bits_floor(p.profile);
    if min_bits < floor {
        return Err(format!("--min-bits {min_bits} is below the floor {floor} of the run profile {} (D27: production >= 95; 93 only at the development rung)", p.profile));
    }
    let want = unhex32(need(f, "--expect-statement")?)?;
    if p.model.identity() != want {
        return Err(format!("the export's trained statement identity (classifier run profile) is {}, not the pinned one", hex(&p.model.identity())));
    }
    // R-C2: the verifier re-derives the margin row and the embedding digest
    // from the pinned tied tensor with the REGISTERED policy's ids and scale,
    // and BOS / the final norm from the export's token_io_parameters; any
    // table file that disagrees is refused (never trusted)
    let policy = policy_by_id(need(f, "--policy")?)?;
    let (tables, bos, norm) = super::classify_tied::load_tied_classifier_tables(&p, &export, Path::new(need(f, "--tables")?), &policy)?;
''')
# the statement: schema /2, the scale and the tied source rendered
rep('pub(crate) const CLASSIFY_STATEMENT_SCHEMA: &str = "zk60-classify-run/1";',
    'pub(crate) const CLASSIFY_STATEMENT_SCHEMA: &str = "zk60-classify-run/2";')
rep('''\\"margin_vector_digest\\": {},\\n \\"embedding_digest\\": {},''',
    '''\\"margin_vector_digest\\": {},\\n \\"margin_scale\\": {:e},\\n \\"tied_source\\": {},\\n \\"embedding_digest\\": {},''')
rep('''        js(&hex(&cp.w_digest)),
        js(&hex(&cp.emb_digest)),''', '''        js(&hex(&cp.w_digest)),
        cp.policy.margin_scale(),
        js(&super::classify_tied::TiedSource::of_run_profile(st.profile())?.describe()),
        js(&hex(&cp.emb_digest)),''')
rep('''js("a classifier proof (DESIGN_CLASSIFIER v2, rung R-C1): the approved integer model's verdict on hidden content under a pre-registered policy; one external endpoint; the verdict bit is public; NOT a privacy acceptance"),''',
    '''js("a classifier proof (DESIGN_CLASSIFIER v2, rung R-C2): the approved integer model's verdict on hidden content under a pre-registered policy; the margin row and the embedding re-derived from the pinned tied tensor; one external endpoint; the verdict bit is public; NOT a privacy acceptance"),''')
# the module text
rep('''//! * `verify` re-derives EVERYTHING from its own inputs (B-3: the margin
//!   vector from `--tables`, the yes / no ids, c and the template from the''',
    '''//! * **R-C2 (round 13):** prove and verify RE-DERIVE the margin row `w` and the
//!   embedding's digest from the pinned tied tensor (the registered policy's
//!   yes / no ids and public scale; `classify_tied`), and BOS / the final norm
//!   from the export's `profile.json.token_io_parameters`; a table file that
//!   disagrees is refused, never trusted. `--min-bits` below the profile's
//!   floor (D27: 93 only at the development rung, else 95) is refused.
//! * `verify` re-derives EVERYTHING from its own inputs (B-3: the margin
//!   vector from the pinned tensor, the yes / no ids, c and the template from the''')
open(P, "w").write(s)
print("wired")
