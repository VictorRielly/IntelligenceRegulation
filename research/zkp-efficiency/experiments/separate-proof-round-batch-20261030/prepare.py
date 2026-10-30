from pathlib import Path
import hashlib, json, platform

D = Path(__file__).resolve().parent
P = D.parents[3]
(D / 'native').mkdir(exist_ok=True)
paths = [P/'zkp-core/src/field.rs', P/'zkp-core/src/sumcheck.rs',
         P/'zkp-core/src/transcript.rs', P/'hashline/src/gpu/cuda.rs',
         P/'hashline/src/zk.rs',
         P/'results/zk60_1b_native_20261017/r13/frozen-tree/hashline/src/private_block/argument.rs']
pins = []
for f in paths:
    b = f.read_bytes()
    name = 'argument_r13.rs' if f.name == 'argument.rs' else f.name
    (D/'native'/name).write_bytes(b)
    pins.append(dict(path=str(f), snapshot='native/'+name, bytes=len(b), sha256=hashlib.sha256(b).hexdigest()))
s = (D/'native/sumcheck.rs').read_text()
a = s.index('#[derive(Clone, Debug)]\npub struct CfsMask')
b = s.index('/// The transcript masker', a)
part = s[a:b]
ra = part.index('    pub fn random(')
rb = part.index('    fn a(', ra)
part = part[:ra] + part[rb:]
(D/'native_mask.rs').write_text('use crate::native_field::{Fp, Fp2};\n'+part)
(D/'native-pins.json').write_text(json.dumps(pins, indent=2)+'\n')
(D/'extraction.json').write_text(json.dumps(dict(source='native/sumcheck.rs',
    range_markers=['#[derive(Clone, Debug)]\\npub struct CfsMask','/// The transcript masker'],
    removal='Only CfsMask::random removed: no RNG or dependency build. Synthetic coefficients supplied by harness.',
    round_evaluator='New serial Rust evaluator follows native MSB pair/increment/fold convention; not extracted native prove.',
    transcript='Python SHA256 surrogate; not native BLAKE3 or a production privacy argument.'), indent=2)+'\n')
cpu = next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')), 'unknown')
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu, platform=platform.platform(), gpu_used=False,
    experiment_threads=1, estimated_memory_mib=64, native_build=False),indent=2)+'\n')
prior = json.loads((D.parent/'slot-batching-census-20261030/hypotheses.json').read_text())
prior[-1]['cycle0162_status'] = 'Testing separate-transcript masked-round arithmetic and ownership; zero native speed evidence.'
prior.append(dict(rank=95, title='NEW capacity-admitted ready-round cohorts instead of global independent-proof barriers',
    baseline='All proofs kept live and advanced in lockstep; ragged jobs drain at different round counts.',
    eliminated_work='Potential idle barriers/launches only; zero field arithmetic or fresh masking.',
    added_costs='Ready queue, public-shape buckets, event completion, per-proof admission and buffer generations.',
    prerequisites='Separate-state equivalence then native exclusive launch/transfer/compute clocks and actual spare capacity.',
    integration_cost='Moderate/high scheduler and completion API; no production patch.',
    exactness='Preserve every proof local masked message/challenge/fold/terminal/refusal; schedule from public metadata only.',
    privacy_soundness='Fresh per-proof masks/RNG and independent source/terminal verification; no cross-proof challenge reuse.',
    compatibility='Rust evaluator boundary before cuda.rs single-transcript loops; native global GPU mutex currently serializes calls.',
    end_to_end_ceiling='Unknown N/(T-C_launch_critical+A_dispatch+A_capacity+A_drain).',
    falsification='No feasible cohort beyond 1, scalar mismatch, unsafe completion/retagging, or measured added costs exceed saved launch overhead.'))
(D/'hypotheses.json').write_text(json.dumps(prior,indent=2)+'\n')
print(json.dumps(dict(native_pins=len(pins), hypotheses=len(prior), source_execution=False)))
