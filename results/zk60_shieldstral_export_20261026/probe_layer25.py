"""Locate the two reported float extrema, then replay their full integer inputs.

This is a diagnostic on calibration inputs, not held-out fidelity or a native
proof. No head/embedding tables are exported: selected embeddings use the
existing calibration quantizer while Sol's public table contract is pending.
All upstream refusals remain visible; clamped descendants are diagnostic only.
Run each mode through the resource guard. Checkpoints resume between batches
or layers and retain hashes, exact coordinates and pre-clamp gate words.
"""
import argparse
import json
from pathlib import Path
import time

import numpy as np
import calibration_port as P
from build_token_io import embedding_rows
from collect_stats import atomic_json, sha
from evaluation_export import EvaluationExport, source_pins
from shieldstral_geometry import D, LAYERS, Rotation
from signed_word_domain import S2RecPos

HERE = Path(__file__).resolve().parent
CHANNELS = (2181, 8853)
OUT = HERE / 'layer25_probe'


def plan(mode, extra):
    return {'schema': 'zk60-shieldstral-layer25-probe/1', 'mode': mode,
            'sources': {**source_pins(), 'probe_layer25.py': sha(__file__),
                        'build_token_io.py': sha(HERE / 'build_token_io.py')},
            'calibration_input_sha256': sha(HERE / 'calibration_t256/input.json'),
            'channels': CHANNELS, **extra}


def bind(path, obj):
    # Normalize tuples before comparing a persisted JSON object.
    obj = json.loads(json.dumps(obj))
    if path.exists():
        if json.loads(path.read_text()) != obj:
            raise ValueError('probe resume inputs/source changed: ' + str(path))
    else:
        atomic_json(path, obj)


def locate(deadline):
    stats = HERE / 'stats_t256'
    source = stats / 'layer_24/residual.npy'
    if sha(source) != json.loads((stats / 'layer_24/ready.json').read_text())['residual_sha256']:
        raise ValueError('float layer-24 residual changed')
    signature = json.loads((stats / 'run.json').read_text())
    for name, digest in signature['source'].items():
        if sha(HERE / name) != digest:
            raise ValueError('float calibration source changed: ' + name)
    bind(OUT / 'locate-plan.json', plan('locate', {'float_input_sha256': sha(source)}))
    x = np.load(source, mmap_mode='r', allow_pickle=False)
    ck = P.tc.open_checkpoint()
    W = P.bl.load_layer(ck, 25, Rotation())
    ropes = P.tc.rope_f32(x.shape[1])
    rows = []
    try:
        for first in range(0, len(x), 2):
            record = OUT / f'float-{first:03d}.json'
            if record.exists():
                rows.extend(json.loads(record.read_text())['rows'])
                continue
            if time.time() > deadline:
                return 3
            _, parts = P.b3._f_block_parts(np.asarray(x[first:first+2]), W, *ropes, P.tc.GEO)
            batch = []
            for local in range(len(parts['gt'])):
                for channel in CHANNELS:
                    values = parts['gt'][local, :, channel]
                    pos = int(np.argmin(values))
                    batch.append({'sequence': first + local, 'channel': channel,
                                  'position': pos, 'float_min': float(values[pos]),
                                  'float_max': float(values.max()),
                                  'outside_int12_e_minus1_positions': np.flatnonzero(
                                      (np.floor(values * 32 + .5) < -2048) |
                                      (np.floor(values * 32 + .5) > 2047)).tolist()})
            atomic_json(record, {'first': first, 'rows': batch})
            rows.extend(batch)
            del parts
            print(json.dumps({'mode': 'locate', 'end_sequence': first+2}), flush=True)
    finally:
        ck.close()
    worst = [min((r for r in rows if r['channel'] == c), key=lambda r: r['float_min']) for c in CHANNELS]
    result = {'rows': rows, 'worst': worst,
              'selected_sequences': sorted({r['sequence'] for r in worst}),
              'sequences_with_float_range_warning': sorted({r['sequence'] for r in rows if r['outside_int12_e_minus1_positions']}),
              'scope': 'MEASURED replay of all 192 float calibration inputs at layer25; two named channels only',
              'plan_sha256': sha(OUT / 'locate-plan.json'),
              'batch_hashes': {p.name: sha(p) for p in sorted(OUT.glob('float-*.json'))}}
    atomic_json(OUT / 'float-extrema.json', result)
    print(json.dumps({'worst': worst, 'selected_sequences': result['selected_sequences']}), flush=True)
    return 0


class GateRecorder(S2RecPos):
    def __init__(self):
        super().__init__(1)
        self.gate = None

    def check(self, site, v, lo, hi, seq0, clamp, extra_bad=None):
        if site == 'FFN gate':
            self.gate = {'range': [lo, hi], 'violations_all_channels': int(((v < lo) | (v > hi)).sum()),
                         'channels': {str(c): {'min': int(v[0, :, c].min()),
                                              'max': int(v[0, :, c].max()),
                                              'words': v[0, :, c].astype(np.int64).tolist()}
                                      for c in CHANNELS}}
        return super().check(site, v, lo, hi, seq0, clamp, extra_bad=extra_bad)


def integer(deadline):
    located = json.loads((OUT / 'float-extrema.json').read_text())
    for name, digest in located['batch_hashes'].items():
        if sha(OUT / name) != digest:
            raise ValueError('float extrema batch changed')
    selected = located['selected_sequences']
    data = json.loads((HERE / 'calibration_t256/input.json').read_text())
    ids = np.load(HERE / 'calibration_t256/ids.npy', allow_pickle=False)
    import hashlib
    if hashlib.sha256(ids.astype('<i8').tobytes()).hexdigest() != data['ids_sha256']:
        raise ValueError('calibration token IDs changed')
    export = EvaluationExport(HERE / 's2_evaluation_t256')
    directory = OUT / 'integer'
    directory.mkdir(exist_ok=True)
    bind(directory / 'plan.json', plan('integer', {
        'float_extrema_sha256': sha(OUT / 'float-extrema.json'),
        'evaluation_complete_sha256': sha(export.root / 'complete.json'),
        'selected_sequences': selected, 'T': data['T'],
        'scope': 'full integer block replay on selected calibration sequences; candidate numerical input quantizer, no head tables/proof'}))
    source = directory / 'input.npy'
    ready = directory / 'input.json'
    if ready.exists():
        if sha(source) != json.loads(ready.read_text())['sha256']:
            raise ValueError('integer input checkpoint changed')
    else:
        ck = P.tc.open_checkpoint()
        raw = ck.refs['model.embed_tokens.weight'].bf16_rows()
        scale = export.profile['metadata_out_of_proof']['residual_scales_in'][0]
        values = embedding_rows(raw[ids[selected]], Rotation(), scale)
        np.save(source, values, allow_pickle=False)
        atomic_json(ready, {'sha256': sha(source), 'shape': list(values.shape),
                           'rule': 'existing dg calibration rotation/float32 boundary, floor(x/scale+0.5), refuse int16 overflow'})
        ck.close()
    summaries = []
    for layer in range(LAYERS):
        target = directory / f'layer_{layer:02d}.npy'
        record = directory / f'layer_{layer:02d}.json'
        if record.exists():
            summary = json.loads(record.read_text())
            if sha(target) != summary['output_sha256'] or sha(source) != summary['input_sha256']:
                raise ValueError('integer layer checkpoint changed')
        else:
            if time.time() > deadline:
                return 3
            started = time.time()
            model = export.layer(layer, data['T'])
            x = np.load(source, allow_pickle=False)
            outputs, diagnostics = [], []
            for index, sequence in enumerate(selected):
                rec = GateRecorder()
                y = P.fl.rx_block(x[index:index+1].astype(np.float64), model, frozenset(P.fl.SITES), rec)
                if not np.isfinite(y).all() or not np.array_equal(y, np.floor(y)) or np.any(y < -32768) or np.any(y > 32767):
                    raise ValueError('invalid diagnostic residual')
                outputs.append(y.astype('<i2'))
                diagnostic = {'sequence': sequence, 'first_refusal': rec.first[0],
                              'violations': {k: dict(v) for k,v in rec.sites.items() if v['violations']}}
                if layer == 25:
                    diagnostic['gate'] = rec.gate
                    diagnostic['group_input_exponents'] = {str(c): int(model.gate_pc[0][c]) for c in CHANNELS}
                diagnostics.append(diagnostic)
            np.save(target, np.concatenate(outputs), allow_pickle=False)
            summary = {'layer': layer, 'seconds': time.time()-started, 'diagnostics': diagnostics,
                       'input_sha256': sha(source), 'output_sha256': sha(target)}
            atomic_json(record, summary)
            del model, x, outputs
            print(json.dumps({'layer': layer, 'seconds': summary['seconds'],
                              'refused_sequences': [d['sequence'] for d in diagnostics if d['first_refusal']]}), flush=True)
        summaries.append(summary)
        source = target
    atomic_json(directory / 'complete.json', {'plan_sha256': sha(directory / 'plan.json'),
        'selected_sequences': selected, 'layers': LAYERS, 'summaries': summaries,
        'scope': 'MEASURED numerical diagnostic; any refused upstream values are clamped and descendants are diagnostic only; not a zero-refusal/fidelity or proof acceptance'})
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('locate', 'integer'))
    parser.add_argument('--max-minutes', type=float, default=25)
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    return globals()[args.mode](time.time() + args.max_minutes * 60)


if __name__ == '__main__':
    raise SystemExit(main())
