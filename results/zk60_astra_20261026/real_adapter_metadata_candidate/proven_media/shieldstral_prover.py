"""Real text classifier adapter, pinned to R16b and the T128 integer export."""
import json
from pathlib import Path
import re

from . import config, proof_plans, records, shieldstral_runtime as runtime
from .classifier_cli import ClassifierCLI, require
from .classifier_prover import deployment_json, launch_pipeline, RungClassifierProver
from .items import TextItem
from .provers import ClassifierProver, ProverError, write_private
from .shieldstral_text import ShieldstralTextEncoder, check_category_coverage, TEKKEN_SHA256


class ShieldstralProver(ClassifierProver):
    kind = 'shieldstral'
    label = 'Shieldstral-1.0-3B classifier — privacy statement pending'
    supports = frozenset({'text'})
    proves_verdict = True
    separate_categories = True

    def __init__(self):
        require(config.prover_mode() == 'shieldstral', 'select the explicit Shieldstral demo mode')
        require(config.TAU == 0.5, 'registered classifier threshold is fixed at0.5')
        self.templates = runtime.templates()
        self.encoder = ShieldstralTextEncoder(runtime.TEKKEN)
        self.clis = {}
        for template in self.templates:
            deployment = runtime.deployment(template)
            runtime.validate(deployment)
            self.clis[template.category] = ClassifierCLI(deployment)

    def describe(self):
        return {**super().describe(), 'model': config.CLASSIFIER_NAME,
                'model_digest': runtime.IDENTITY, 'token_profile_digest': runtime.PROFILE_SHA,
                'binary_sha256': runtime.BINARY_SHA, 'run_profile': runtime.RUN_PROFILE,
                'cli': 'zk60_classify r16b, native R13, T128', 'privacy_status': 'privacy statement pending',
                'policy_selection': 'moderate testnet demo; product ruling pending',
                'what_is_proved': 'The pinned integer model verdict for each category, bound to the post by input-owner verification.',
                'per_job_s': 700, 'category_geometry': {t.category: {'chunk_tokens': t.chunk_size,
                    'overlap_tokens': t.overlap, 'max_chunks': t.max_chunks} for t in self.templates}}

    def content_length(self, text):
        return len(self.encoder.content_ids(text))

    def plan_text(self, text):
        return proof_plans.category_work_plan(self.content_length(text), self.templates)

    def poll(self, job):
        return RungClassifierProver.poll(self, job)

    def _job(self, job, cli, spec):
        job = Path(job).resolve()
        job.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        job.mkdir(mode=0o700, exist_ok=False)
        write_private(job/'classifier-job.json', records.canonical({
            'schema': 'pm-classifier-job/1', 'deployment': deployment_json(cli.deployment), **spec}))
        return job

    def prepare(self, post_id, item, job, chunk=None):
        require(isinstance(item, TextItem), 'Shieldstral currently accepts text only')
        require(re.fullmatch(r'[A-Za-z0-9_-]{1,80}', post_id) is not None, 'invalid post id')
        ids = self.encoder.content_ids(item.text)
        plan = proof_plans.category_work_plan(len(ids), self.templates)
        require(isinstance(chunk, dict) and type(chunk.get('index')) is int
                and 0 <= chunk['index'] < len(plan)
                and records.canonical(chunk) == records.canonical(plan[chunk['index']]),
                'category queue slot differs from the whole post')
        category = chunk['category']; cli = self.clis[category]
        runtime.validate(cli.deployment)
        require(records.threshold()['tau'] == 0.5 and records.threshold()['c'] == 0,
                'registered threshold changed')
        policy = next(c['policy'] for c in records.categories() if c['id'] == category)
        require(policy['id'] == cli.deployment.policy, 'app policy differs from native deployment')
        job = Path(job).resolve(); artifact = config.RUNS_DIR / f'{post_id}-c{chunk["index"]}'
        previous = [ch for ch in plan if ch['category'] == category and ch['index'] < chunk['index']]
        prior_jobs = [job.parent / ('prove' if ch['index'] == 0 else f'prove-c{ch["index"]}') for ch in previous]
        for prior in prior_jobs:
            ps, _ = self._checked(prior)
            require(ps['post_id'] == post_id and self._content_ids(ps) == ids,
                    'previous category chunk belongs to another post')
        config.RUNS_DIR.mkdir(parents=True, exist_ok=True)
        content = job/'content.ids'; owner = job/'owner'
        request = job/'activation-request.json'; sequence = job/'activations/chunk'
        spec = {'mode': 'prove', 'post_id': post_id, 'category': category, 'queue_chunk': chunk,
                'artifact': str(artifact), 'total': len(ids), 'chunk': chunk['category_chunk_index'],
                'content_file': str(content), 'owner_dir': str(owner), 'sequence_dir': str(sequence),
                'activation_request': str(request), 'prior_jobs': [str(p) for p in prior_jobs],
                'last_category_chunk': chunk['category_chunk_index'] == chunk['category_chunks'] - 1}
        self._job(job, cli, spec)
        write_private(content, (','.join(map(str, ids))+'\n').encode())
        write_private(request, records.canonical([{'name': 'chunk', 'policy_id': cli.deployment.policy,
            'content_file': str(content), 'chunk_index': spec['chunk']}]))
        cli.prove_command(content, spec['chunk'], sequence, artifact, owner)
        return job

    def start(self, post_id, item, job, chunk=None):
        launch_pipeline(self.prepare(post_id, item, job, chunk))

    @staticmethod
    def _content_ids(spec):
        return tuple(int(x) for x in Path(spec['content_file']).read_text().strip().split(','))

    @staticmethod
    def _guard(job, name):
        logs = job/'logs'
        guard = json.loads((logs/f'{name}.guard.json').read_text())
        require((logs/f'{name}.exit').read_text().strip() == '0' and guard.get('exit') == 0
                and guard.get('child_rc') == 0 and not guard.get('guard_killed') and not guard.get('refused'),
                'required native step did not succeed')
        return guard

    def _checked(self, job):
        job = Path(job)
        status = self.poll(job)
        require(status['done'] and status['exit'] == 0, 'classifier pipeline has not succeeded')
        spec = json.loads((job/'classifier-job.json').read_text())
        require(spec.get('category') in self.clis, 'unknown job category')
        cli = self.clis[spec['category']]
        require(spec['deployment'] == deployment_json(cli.deployment), 'job deployment differs')
        runtime.validate(cli.deployment)
        for step in ('verify', 'inowner'):
            self._guard(job, step)
        result = cli.collect_verified(spec['artifact'], spec['total'], spec['chunk'],
            (job/'logs/verify.log').read_text(), 0, (job/'logs/inowner.log').read_text(), 0)
        require(result == json.loads((job/'checked.json').read_text()), 'verified artifact changed')
        template = next(t for t in self.templates if t.category == spec['category'])
        require(result['statement']['template_prefix_ids'] == list(template.prefix)
                and result['statement']['template_suffix_ids'] == list(template.suffix)
                and result['statement']['blocks'] == 26, 'native model/template differs')
        return spec, result

    def _aggregate(self, job, spec, current):
        self._guard(job, 'label')
        parts = []
        for previous in spec['prior_jobs']:
            ps, checked = self._checked(Path(previous))
            require(ps['post_id'] == spec['post_id'] and ps['deployment'] == spec['deployment']
                    and self._content_ids(ps) == self._content_ids(spec), 'aggregate mixes content')
            parts.append(checked)
        parts.append(current)
        cli = self.clis[spec['category']]
        result = cli.collect_label(parts, (job/'logs/label.log').read_text(), 0, spec['total'])
        aggregate = {'result': result, 'statement_sha256': [p['statement_sha256'] for p in parts],
                     'total': spec['total']}
        require(aggregate == json.loads((job/'label-checked.json').read_text()), 'native aggregate changed')
        return aggregate

    def collect(self, post_id, item, job, chunk=None):
        job = Path(job); spec, r = self._checked(job)
        require(isinstance(item, TextItem) and spec['post_id'] == post_id
                and self._content_ids(spec) == self.encoder.content_ids(item.text)
                and records.canonical(spec['queue_chunk']) == records.canonical(chunk), 'collected post or queue slot differs')
        require(chunk in self.plan_text(item.text), 'collected chunk differs from original post')
        category = spec['category']; st = r['statement']
        policy = next(c['policy'] for c in records.categories() if c['id'] == category)
        checks = {'verify': {'ok': True, 'by': 'pinned r16b fresh process'}, 'content_binding': {'ok': True}}
        if spec['last_category_chunk']:
            checks['category_aggregate'] = self._aggregate(job, spec, r)
        steps = {name: self._guard(job, name) for name in ('seqgen', 'prove', 'verify', 'inowner')}
        if spec['last_category_chunk']:
            steps['label'] = self._guard(job, 'label')
        rec = records.ProofRecord(post_id=post_id, item_kind='text', prover=self.describe(),
            labels={category: {k: r[k] for k in ('value', 'proof', 'bound_by_proof', 'policy_id', 'development_only')}},
            policies=[{**policy, 'category': category}], threshold=records.threshold(),
            content_commitment={'kind': 'sealed native input-token endpoint', 'value': st['input_token_endpoint_root']},
            statement=st, statement_sha256=r['statement_sha256'],
            receipt={'run_dir': r['run_dir'], 'files': r['files'], 'segments': len(r['files']),
                     'bytes': sum(f['bytes'] for f in r['files'])},
            timings={'work_s': sum(g['child_wall_seconds'] for g in steps.values()),
                     'steps': {k: {n: g[n] for n in ('child_wall_seconds', 'peak_rss_gib', 'enforcement', 'waited_s')}
                               for k, g in steps.items()}},
            security={'whole_run_floor_bits': st['whole_run_floor_bits'], 'min_bits_required': 95,
                      'privacy_status': 'privacy statement pending'}, checks=checks,
            content_length={'tokens': chunk['end']-chunk['start'], 'total_tokens': spec['total'],
                            'tokenizer': 'pinned Tekken', 'tokenizer_sha256': TEKKEN_SHA256},
            chunk=chunk, created_at=records.now_iso(), proved_at=records.now_iso(),
            notes=['Real classifier testnet demo; privacy statement pending. Moderate product wording remains pending.'])
        rec.labels[category]['policy_sha256'] = policy['sha256']
        proof_plans.check_category_record(rec.to_dict(), post_id, chunk, require_verdict=True)
        return rec

    def check_final_records(self, item, rows):
        require(isinstance(item, TextItem) and all(rows), 'all category proofs are required')
        grouped = {t.category: sorted([r for r in rows if r['chunk']['category'] == t.category],
                    key=lambda r: r['chunk']['category_chunk_index']) for t in self.templates}
        total = check_category_coverage(item.text, self.encoder, self.templates,
                                       {c: [r['statement'] for r in rs] for c, rs in grouped.items()})
        for category, rs in grouped.items():
            aggregate = rs[-1].get('checks', {}).get('category_aggregate')
            require(isinstance(aggregate, dict) and aggregate['total'] == total
                    and aggregate['statement_sha256'] == [r['statement_sha256'] for r in rs],
                    'whole-category native aggregate is missing or belongs to another proof set')
            expected = 'yes' if any(r['statement']['verdict_bit'] for r in rs) else 'no'
            result = aggregate['result']
            require(result['value'] == expected and result['proof'] == 'accepted'
                    and result['bound_by_proof'] is True and result['chunks'] == len(rs)
                    and result['policy_id'] == self.clis[category].deployment.policy,
                    'native category aggregate differs from the proved chunks')

    def prepare_recheck(self, record, prove_job, job):
        # Let the fresh native verifier inspect changed/missing receipt bytes.
        # Refusing here would leave no terminal recheck to withdraw the post.
        spec = json.loads((Path(prove_job)/'classifier-job.json').read_text())
        require(spec.get('category') in self.clis, 'unknown original category')
        cli = self.clis[spec['category']]
        require(spec['deployment'] == deployment_json(cli.deployment)
                and record.post_id == spec['post_id'] and record.receipt['run_dir'] == spec['artifact']
                and record.prover['kind'] == self.kind and record.prover['binary_sha256'] == runtime.BINARY_SHA
                and records.canonical(record.chunk) == records.canonical(spec['queue_chunk']),
                'original proof context differs from record')
        spec = {k: v for k, v in spec.items() if k not in ('schema', 'deployment')}
        spec['mode'] = 'recheck'
        return self._job(job, cli, spec)

    def start_recheck(self, record, prove_job, job):
        launch_pipeline(self.prepare_recheck(record, prove_job, job))

    def collect_recheck(self, record, job):
        try:
            spec, r = self._checked(Path(job))
            require(spec['post_id'] == record.post_id and r['statement_sha256'] == record.statement_sha256
                    and r['files'] == record.receipt['files'], 'rechecked receipt differs')
        except (ProverError, OSError, ValueError, KeyError):
            return records.Verdict('re-check', False, False, 'classifier recheck failed', records.now_iso(),
                                   {'rejected': True})
        return records.Verdict(r['value'], True, True, 'fresh r16b verifier and input-owner', records.now_iso(),
                               {'content_binding': True, 'privacy_status': 'privacy statement pending'})
