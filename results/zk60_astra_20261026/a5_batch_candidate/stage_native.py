"""Stage a reviewable native delta under Astra ownership; never edit the source lane."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BASE = REPO / 'results/zk60_token_io_r1_20261017/frozen-r16b/hashline'
PINS = {
    'src/private_block/token_io/classify_cli.rs': 'b3b661b5f609ac4195cbbbc0f56d7191458986baf7af0006c63c5aaa3d8a6e17',
    'src/private_block.rs': '2af1df7d5bc222695c1d233050ff87a5f0981a26a5df1828678b67a6fe0a1cb3',
    'examples/zk60_classify.rs': 'af8cfd0e919d6cce4a6dcb20e67f27eac390d1d0e9b4a7a34435efd1408a1282',
}


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('native source anchor is no longer unique')
    return text.replace(old, new, 1)


def stage():
    originals = {}
    for name, pin in PINS.items():
        data = (BASE / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != pin:
            raise ValueError(f'baseline source pin changed: {name}')
        originals[name] = data.decode()
    changed = dict(originals)
    name = 'src/private_block/token_io/classify_cli.rs'
    text = changed[name]
    text = once(text, 'fn prove_inner(f: &[(String, String)]) -> Result<(), String> {', '''
#[path = "classify_batch.rs"]
mod batch;
pub use batch::classify_prove_batch_command;

struct SharedProve<'a> {
    p: &'a ExportPublic,
    bound: &'a super::classify_tied::BoundClassifierTables,
    whole: &'a [u64],
}

fn prove_inner(f: &[(String, String)]) -> Result<(), String> {
    prove_with_public(f, None)
}

fn prove_with_public(f: &[(String, String)], shared: Option<SharedProve<'_>>) -> Result<(), String> {'''.lstrip())
    # Confine transformations to the prover; verification and receipt codec
    # remain byte-for-byte the frozen source.
    start = text.index('fn prove_with_public(')
    end = text.index('/// a run directory CHECKED IN FULL', start)
    body = text[start:end]
    body = once(body, '    let p = load_export(&export)?;', '''    let loaded_p;
    let p = match shared.as_ref() {
        Some(s) => s.p,
        None => { loaded_p = load_export(&export)?; &loaded_p }
    };''')
    body = once(body, '    let bound = super::classify_tied::load_tied_classifier_tables(&p, &export, Path::new(need(f, "--tables")?), &policy)?;', '''    let loaded_bound;
    let bound = match shared.as_ref() {
        Some(s) => s.bound,
        None => {
            loaded_bound = super::classify_tied::load_tied_classifier_tables(p, &export, Path::new(need(f, "--tables")?), &policy)?;
            &loaded_bound
        }
    };
    bound.check_for(sh, p.profile, &p.model, &policy)?;''')
    body = once(body, '    let whole = content_of(f)?;', '''    let loaded_whole;
    let whole: &[u64] = match shared.as_ref() {
        Some(s) => s.whole,
        None => { loaded_whole = content_of(f)?; &loaded_whole }
    };''')
    body = body.replace('ExportTokenBlocks::new(&p)', 'ExportTokenBlocks::new(p)')
    body = body.replace('seal_chain(&p,', 'seal_chain(p,').replace('CliSource { p: &p,', 'CliSource { p,')
    body = body.replace('&p.model, &bound,', '&p.model, bound,').replace('&mut blocks, &bound,', '&mut blocks, bound,')
    body = body.replace('render(&p,', 'render(p,')
    changed[name] = text[:start] + body + text[end:]
    name = 'src/private_block.rs'
    changed[name] = once(changed[name], 'classify_label_command, classify_prove_command, classify_verify_command',
                         'classify_label_command, classify_prove_batch_command, classify_prove_command, classify_verify_command')
    name = 'examples/zk60_classify.rs'
    changed[name] = once(changed[name], '        Some("prove") =>',
        '        Some("prove-batch") => hashline::private_block::classify_prove_batch_command(&args[1..]),\n        Some("prove") =>')
    changed[name] = changed[name].replace('usage: zk60_classify prove|verify|input-owner|label',
                                        'usage: zk60_classify prove|prove-batch|verify|input-owner|label')
    for name in ('classify_batch.rs', 'classify_batch_plan.rs'):
        changed['src/private_block/token_io/' + name] = (HERE / 'native' / name).read_text()
    patch = []
    manifest = {}
    for name, text in sorted(changed.items()):
        target = HERE / 'staged/hashline' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        patch.extend(difflib.unified_diff(originals.get(name, '').splitlines(True), text.splitlines(True),
                     fromfile=('a/' + name) if name in originals else '/dev/null', tofile='b/' + name))
        manifest[name] = hashlib.sha256(text.encode()).hexdigest()
    (HERE / 'native.patch').write_text(''.join(patch))
    (HERE / 'native_sources.json').write_text(json.dumps({
        'baseline': str(BASE.relative_to(REPO)), 'baseline_sha256': PINS, 'staged_sha256': manifest,
        'status': 'candidate only; full native build and integration tests pending',
        'changes_receipt_format': False, 'changes_verification': False,
        'changes_production_binary': False,
    }, indent=2) + '\n')
    print(json.dumps({'staged_files': len(changed), 'native_build_complete': False}))


if __name__ == '__main__':
    stage()
