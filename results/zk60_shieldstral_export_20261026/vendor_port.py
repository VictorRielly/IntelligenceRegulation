"""Create the isolated, reviewable calibration port; never modify upstream files.

Each replacement asserts its occurrence count. Originals, full diffs and hashes
are retained so geometry changes can be reviewed separately from calibration.
Run once; an existing vendor directory is never overwritten.
"""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CAL = ROOT/'results/zk60_1b_calibration_20260929'
FP = ROOT/'results/zk60_fidelity_parity_20261019'


def replace(s, old, new, n=1):
    if s.count(old) != n:
        raise ValueError(f'upstream changed: expected {n} occurrences of {old[:90]!r}, got {s.count(old)}')
    return s.replace(old, new)


def port(name, s):
    if name == 'tlcalib.py':
        a, b = s.index('HERE = '), s.index('TWO53 = ')
        s = s[:a] + '''HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
MODEL_NAME = "shieldstral-3b"
from shieldstral_geometry import MODEL, rope_tables
MODEL_SHA256 = MODEL['sha256']
''' + s[b:]
        s = replace(s, 'return importer.Checkpoint(MODEL_DIR, expected_shards=MODEL_SHARDS)',
                    'from shieldstral_weights import Checkpoint\n    return Checkpoint()')
        a, b = s.index('GEO = Geo()'), s.index('\n\n# ------------------------------------------------------------------ float reference')
        s = s[:a] + 'GEO = Geo(d=3072, f=9216, H=32, KV=8, dh=128, eps=1e-5, theta=1000000.0)\n' + s[b:]
        a, b = s.index('    inv = ', s.index('def rope_f32')), s.index('\n\ndef f_xhat')
        s = s[:a] + '    assert g == GEO\n    return tuple(t.astype(np.float32) for t in rope_tables(T))\n' + s[b:]
        s = replace(s, '.transpose(0, 3, 1, 2, 4).reshape(N, T, d)', '.transpose(0, 3, 1, 2, 4).reshape(N, T, g.H * g.dh)', 2)
        a, b = s.index('def rope_tables_int('), s.index('\n\ndef exp_table(')
        s = s[:a] + '''def rope_tables_int(T: int, dh: int, theta: float, f_ro: int):
    assert dh == GEO.dh and theta == GEO.theta
    return rope_tables(T, f_ro)
''' + s[b:]
    elif name == 'b3calib.py':
        s = replace(s, 'WDT = np.float32 if tc.MODEL_NAME == "llama3-8b" else np.float64', 'WDT = np.float32')
        a, b = s.index('class Rotation:'), s.index('\n\ndef rotate_layer(')
        s = s[:a] + 'from shieldstral_geometry import Rotation\n' + s[b:]
        s = replace(s, '.transpose(0, 3, 1, 2, 4).reshape(N, T, d)', '.transpose(0, 3, 1, 2, 4).reshape(N, T, g.H * g.dh)')
        a, b = s.index('    half = head_dim // 2', s.index('def rope_generate')), s.index('\n\ndef _py_float')
        s = s[:a] + '    from shieldstral_geometry import rope_tables\n    assert head_dim == GEO.dh and base == GEO.theta\n    return rope_tables(t_max, f_ro)\n' + s[b:]
        # Keep every calibration sequence. A value outside the chosen group range
        # is diagnosed later; dropping it would hide a refusal.
        a, b = s.index('    if keep is None:', s.index('def f_block_stats')), s.index('\n    return x2', s.index('def f_block_stats'))
        s = s[:a] + '''    if keep is not None and not np.all(keep):
        raise ValueError("calibration sequence exclusion is forbidden")
    st['excluded_here'] = st['excluded_total'] = 0
    _mx(st, 'gate_absmax_all_sequences', float(np.abs(parts['gt']).max()))
    _accumulate(st, x, x2, parts, g)
''' + s[b:]
    elif name == 'b3_ladder.py':
        s = replace(s, 'from corpus import sequences  # noqa: E402\nimport corpus4  # noqa: E402\nfrom spm_bpe import SpmBpe, tokenizer_selfcheck  # noqa: E402',
                    '# Shieldstral data/CLI are provided by prepare_calibration.py and build_export.py.')
        a, b = s.index('MODEL = '), s.index('\nSCHEMA = ')
        s = s[:a] + 'from shieldstral_geometry import MODEL\n' + s[b:]
        # The original CLI would load TinyLlama corpora. Disable it explicitly.
        a = s.index('def main(')
        s = s[:a] + 'if __name__ == "__main__":\n    raise SystemExit("Use Shieldstral build_export.py, not the upstream CLI")\n'
    elif name == 'fp_lib.py':
        s = replace(s, 'CAL = REPO / "results" / "zk60_1b_calibration_20260929"', 'CAL = Path(__file__).resolve().parent')
        s = replace(s, 'BOS = 128000 if IS8B else 1', 'BOS = 1')
        s = replace(s, '.transpose(0, 3, 1, 2, 4).reshape(N, T, d)', '.transpose(0, 3, 1, 2, 4).reshape(N, T, g.H * g.dh)')
        a, b = s.index('        ref = checkpoint().refs[name]', s.index('def bf16_memmap')), s.index('\n    return _MM[name]', s.index('def bf16_memmap'))
        s = s[:a] + '        _MM[name] = checkpoint().refs[name].bf16_rows()' + s[b:]
    return s


def main():
    dest = HERE/'vendor'
    if dest.exists():
        raise SystemExit('vendor exists; edit the isolated copies and refresh the manifest, never recopy over work')
    rendered = []
    for source in [CAL/'tlcalib.py', CAL/'b3calib.py', CAL/'b3_ladder.py', FP/'fp_lib.py']:
        original = source.read_text()
        rendered.append((source, original, port(source.name, original)))
    dest.mkdir()
    baseline = HERE/'upstream'
    baseline.mkdir()
    manifest = {}
    for source, original, adapted in rendered:
        (baseline/source.name).write_text(original)
        (dest/source.name).write_text(adapted)
        (dest/(source.name+'.diff')).write_text(''.join(difflib.unified_diff(
            original.splitlines(True), adapted.splitlines(True), fromfile=str(source.relative_to(ROOT)),
            tofile=str((dest/source.name).relative_to(ROOT)))))
        manifest[source.name] = {'source': str(source.relative_to(ROOT)),
            'source_sha256': hashlib.sha256(original.encode()).hexdigest(),
            'adapted_sha256': hashlib.sha256(adapted.encode()).hexdigest()}
    (dest/'PORT_MANIFEST.json').write_text(json.dumps(manifest, indent=2)+'\n')


if __name__ == '__main__':
    main()
