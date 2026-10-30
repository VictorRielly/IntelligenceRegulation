"""Read-only export disk inventory, including hard-link accounting and prune candidates."""
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026'


def main():
    inodes={};groups=defaultdict(list);incomplete=[]
    for path in EXPORT.rglob('*'):
        if path.is_symlink() or not path.is_file():continue
        stat=path.stat();key=(stat.st_dev,stat.st_ino);rel=path.relative_to(EXPORT)
        row={'path':str(rel),'bytes':stat.st_size,'allocated':stat.st_blocks*512,'links':stat.st_nlink}
        info=inodes.setdefault(key,{'bytes':stat.st_size,'allocated':stat.st_blocks*512,'links':stat.st_nlink,'paths':[]})
        info['paths'].append(str(rel));groups[rel.parts[0] if len(rel.parts)>1 else '(top-level)'].append((key,row))
        if '.incomplete' in path.name or path.name.endswith('.tmp.npy'):incomplete.append(row)
    summary={}
    for name,entries in groups.items():
        keys={key for key,row in entries}
        exclusive=[inodes[k] for k in keys if all(p.split('/')[0]==name for p in inodes[k]['paths'])
                   and len(inodes[k]['paths'])==inodes[k]['links']]
        summary[name]={'files':len(entries),'logical_path_bytes':sum(row['bytes'] for key,row in entries),
                       'unique_allocated_bytes':sum(inodes[k]['allocated'] for k in keys),
                       'exclusive_reclaimable_inode_bytes':sum(i['allocated'] for i in exclusive)}
    stats=EXPORT/'stats_t256';done=json.loads((stats/'complete.json').read_text())
    require=lambda condition: condition or (_ for _ in ()).throw(ValueError('statistics provenance changed'))
    require(hashlib.sha256((stats/'stats.pkl').read_bytes()).hexdigest()==done['stats_sha256'])
    require(hashlib.sha256((stats/'run.json').read_bytes()).hexdigest()==done['run_sha256'])
    candidates=[]
    # L24 is read by the refusal diagnostic; L25 is read by both tied-table
    # exporters' final-norm calibration. Keep those direct dependencies.
    for path in [stats/'input_rotated.npy',*[p for p in sorted(stats.glob('layer_*/residual.npy'))
                                           if p.parent.name not in ('layer_24','layer_25')]]:
        ref=json.loads((stats/'input.ready.json' if path.parent==stats else path.parent/'ready.json').read_text())
        candidates.append({'path':str(path.relative_to(EXPORT)),'bytes':path.stat().st_size,
                           'expected_sha256':ref['sha256'] if path.parent==stats else ref['residual_sha256']})
    plan=json.loads((EXPORT/'fidelity_full_fix1/run.json').read_text());per_layer=plan['tokens']*3072*2
    output={'at':datetime.now(timezone.utc).isoformat(),'read_only':True,'directories':summary,
            'root_unique_allocated_bytes':sum(i['allocated'] for i in inodes.values()),
            'statistics_aggregate_and_plan_hashes_verified':True,'float_residual_candidates':candidates,
            'float_residual_candidate_bytes':sum(row['bytes'] for row in candidates),'float_payload_hashes_rechecked':False,
            'incomplete_candidates':incomplete,'benchmark_residual_bytes_per_stage':per_layer,
            'benchmark_27_stage_residual_bytes':27*per_layer,'files_deleted':0,
            'caveat':'Directory unique sizes overlap for shared hard links. External links may prevent reclaim; no payload is deleted.'}
    (HERE/'export_storage_inventory_20261030.json').write_text(json.dumps(output,indent=2)+'\n')
    lines=['# Shieldstral storage inventory — 2026-10-30','',
           'Read-only inventory for coordinator D46. No files were removed. GiB below are allocated Linux blocks; '
           'shared hard links make directory totals overlap. Removing Linux files makes blocks reusable but does not itself shrink the WSL disk on C:.','',
           '| Directory | Unique allocated GiB | Current disposition |','|---|---:|---|']
    keep={'fidelity_full_fix1':'KEEP: live full benchmark; all past residuals required by the current final audit.',
          'calibration_full_fix1':'KEEP: accepted numerical calibration evidence; current full audit rereads all residuals.',
          's2_evaluation_t256':'KEEP: active integer replay loads these layer arrays.',
          'native_low_h24_t128':'KEEP: r16b prover profile and arrays; shared links do not imply an expendable path.',
          'native_low_h24_t128-verifier':'KEEP: independent public verifier and all published receipts rely on this path.',
          'dg_r12b_t256':'KEEP: tied integer embedding/head and final numerical scoring.',
          'dg_base_t256':'KEEP pending dependency review: base-export lineage and numerical rebuild input.',
          'layer25_fix_candidate':'KEEP: active numerical amendment and provenance pins.',
          'stats_t256':'PARTIAL PRUNE CANDIDATE: float residual caches only; retain every statistics/manifest file.',
          'fidelity_smoke8_fix1':'REGENERABLE but retain until parity/audit owners acknowledge: CPU byte-parity baseline.',
          'fidelity_smoke8_cached':'REGENERABLE but retain until parity/audit owners acknowledge: cached CPU diagnostic.',
          'fidelity_smoke8_gpu':'REGENERABLE but retain until parity/audit owners acknowledge: GPU parity gate.',
          'layer25_probe':'KEEP small failure/fix diagnosis and its source pins.'}
    for name,row in sorted(summary.items(),key=lambda item:item[1]['unique_allocated_bytes'],reverse=True):
        lines.append(f'| {name} | {row["unique_allocated_bytes"]/(1<<30):.3f} | {keep.get(name,"KEEP: small inputs, provenance, source or diagnostic records.")} |')
    lines+=['','## Concrete candidate for coordinator scheduling','',
            f'The 25 float residual caches total **{output["float_residual_candidate_bytes"]/(1<<30):.3f} GiB**: '
            '`stats_t256/input_rotated.npy` plus `stats_t256/layer_00..23/residual.npy`. The exact paths and retained '
            'expected hashes are in `export_storage_inventory_20261030.json`. They are regenerable with '
            '`collect_stats.py` and the pinned checkpoint/calibration inputs. They are not native proof receipts.',
            '', 'Code inspection: `build_export.py` reads `stats.pkl`, `complete.json` and `run.json`; '
            '`evaluation_export.py` reads that same aggregate and checks its build pin. Neither reads float residuals. '
            'The aggregate and plan hashes were freshly checked. `collect_stats.py` does read every residual when resuming, '
            'so after pruning a new float-statistics run needs a new output directory; never silently reuse missing caches. '
            '**Keep layer_24/residual.npy** for `probe_layer25.py`, and **keep layer_25/residual.npy** for '
            '`build_token_io.py` / `build_token_io_r12b.py` final-norm calibration.',
            '', 'Retain `stats.pkl`, all `statistics.pkl`, `ready.json`, `input.ready.json`, `run.json`, `complete.json`, '
            'the calibration inputs and model/source pins. Payload hashes should be checked before deleting the listed caches. '
            'Other lanes must first have the opportunity to identify a residual dependency. No deletion authorization is inferred '
            'for a native export, accepted receipt or another lane’s artifacts.',
            '', '## Remaining benchmark growth','',
            f'Each full residual stage is {per_layer:,} bytes ({per_layer/(1<<30):.3f} GiB). '
            f'Input plus 26 layers reaches {27*per_layer/(1<<30):.3f} GiB of residuals alone. '
            'Each individually guarded layer writes less than 10 GB, but the whole remaining campaign is much larger. '
            'The current final audit needs every stage’s bytes, so a rolling deletion scheme must change and validate that '
            'audit contract first. No benchmark residual pruning was performed.',
            '',f'Incomplete-name candidates found: {len(incomplete)}. These are inventory entries only; live ownership must be checked before cleanup.','']
    (HERE/'EXPORT_STORAGE_INVENTORY_20261030.md').write_text('\n'.join(lines))
    print(json.dumps({'float_residual_candidate_gib':output['float_residual_candidate_bytes']/(1<<30),
                      'benchmark_full_residual_gib':27*per_layer/(1<<30),'incomplete_candidates':len(incomplete),'deleted':0}))


if __name__=='__main__':main()
