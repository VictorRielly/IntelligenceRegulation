"""W16R2 public-content runtime with separately pinned proving and verification binaries."""
import hashlib
import json
import os
from pathlib import Path

from . import config, records, shieldstral_fast_runtime as baseline
from .classifier_cli import ClassifierCLI, Deployment, R_C3_SCHEMA, require

KIND = 'shieldstral-fast-w16r2'
FLAG = '--dev-w16r2-public-content-only'
PROFILE_SHA = '9464388091d8095f8491f2990fde54e3b1f2b06f2a5c6ad1e72eff09cd4ce20a'
INTAKE = Path(__file__).with_name('w16r2_native_intake.json')
INTAKE_SHA = 'cc937f3c69806295cc504b7f420cb8a539db2d6ecc72690ebd36377ef48dd829'
BINARY = Path('/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a30a31')
PROVER_BINARY = config.REPO / 'results/zk60_astra_20261026/app_composed_native_20261122/classify-host/bin/zk60_classify'
PROVER_BINARY_SHA = '3a540c08b3cc00d559e3cd44ed38c6ab45cdc4007087e03b3503bb08f068da8f'
COMPOSED_PROVER_SHA = '4f419a8a8a135a62c6ad2eb073dc82e989ae56992bf41eebbec3edfb0e45b9f0'
EXPORT = Path('/Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1')
COMMANDS = ['serve', 'check-serve', 'prove', 'verify', 'input-owner', 'label']
ORIGINAL_SETTINGS = dict(baseline.NATIVE_SETTINGS, HL_A26_KEPT='1', HL_A30_B3PAR='1',
                         HL_A26_VERIFY_ONCE='0', HL_A28_SEAL_AHEAD='0')
COMPOSED_SETTINGS = dict(ORIGINAL_SETTINGS, HL_METAL_FUSED_RS='1', HL_METAL_SPARSE_FOLD='1')
PROVER_ONLY_SETTINGS = {'HL_METAL_FUSED_RS':'1', 'HL_METAL_SPARSE_FOLD':'1', 'HL_METAL_SC_CHAIN_FAST':'1',
                        'HL_HOST_FAST':'1', 'HL_CLASSIFY_HOST_FAST':'1'}
NATIVE_SETTINGS = {**ORIGINAL_SETTINGS, **PROVER_ONLY_SETTINGS}


def verifier_environment(environment):
    return {key:value for key,value in environment.items() if key not in PROVER_ONLY_SETTINGS}


def authority():
    require(INTAKE.is_file() and not INTAKE.is_symlink(), 'W16R2 native intake is unavailable')
    with INTAKE.open('rb') as stream:
        raw = stream.read((1 << 20) + 1)
    require(len(raw) <= 1 << 20 and hashlib.sha256(raw).hexdigest() == INTAKE_SHA,
            'W16R2 native intake differs from its reviewed source pin')
    value = json.loads(raw)
    require(isinstance(value, dict) and value.get('schema') == 'pm-w16r2-native-intake/1',
            'unknown W16R2 native intake')
    require(value.get('status') == 'candidate_native_cli_ready',
            'W16R2 native binary and statement intake are pending')
    expected = {'kind': KIND, 'binary': str(BINARY), 'profile_sha256': PROFILE_SHA,
                'public_content_only': True, 'production': False, 'min_bits': 95,
                'native_flag': FLAG, 'commands': COMMANDS}
    require(all(records.canonical(value.get(k)) == records.canonical(v) for k, v in expected.items()),
            'W16R2 native authority or public-content restriction differs')
    for key in ('binary_sha256', 'statement_identity'):
        digest = value.get(key)
        require(type(digest) is str and len(digest) == 64 and all(c in '0123456789abcdef' for c in digest),
                'W16R2 native identity is missing')
    require(value['binary_sha256'] != baseline.BINARY_SHA and value['statement_identity'] != baseline.IDENTITY,
            'W16R2 cannot inherit the baseline binary or statement identity')
    require(type(value.get('run_profile')) is str and bool(value['run_profile'])
            and value['run_profile'] != baseline.RUN_PROFILE, 'W16R2 run profile is missing or inherited')
    return value


class PublicContentCLI(ClassifierCLI):
    def __init__(self, deployment, runtime):
        self.runtime = runtime
        super().__init__(deployment)

    def _base(self, command):
        self.runtime.validate(self.deployment)
        argv = super()._base(command) + [FLAG]
        if command == 'prove':
            argv[0] = str(self.runtime.prover_binary())
        return argv

    def collect_verified(self, *args, **kwargs):
        self.runtime.validate(self.deployment)
        result = super().collect_verified(*args, **kwargs)
        require(result['statement'].get('run_profile') == self.runtime.RUN_PROFILE,
                'W16R2 receipt belongs to another run profile')
        # development_only is the legacy synthetic-policy publication veto, not
        # a production/privacy ruling. Keep the real moderate-policy result.
        return {**result, 'development_candidate': True, 'public_content_only': True, 'production': False}

    def check_label_records(self, rows, total):
        self.runtime.validate(self.deployment)
        require(isinstance(rows, list) and all(isinstance(r, dict) and isinstance(r.get('statement'), dict)
                                             for r in rows), 'malformed W16R2 category records')
        require(all(r.get('public_content_only') is True and r.get('development_only') is False
                    and r.get('development_candidate') is True and r.get('production') is False
                    and r.get('statement', {}).get('run_profile') == self.runtime.RUN_PROFILE for r in rows),
                'W16R2 aggregate mixes another proving mode')
        return super().check_label_records(rows, total)

    def collect_label(self, *args, **kwargs):
        result = super().collect_label(*args, **kwargs)
        return {**result, 'development_candidate': True, 'public_content_only': True, 'production': False}


class Runtime:
    KIND = KIND
    LANE = 'W16R2 public-content development candidate'
    PROFILE_SHA = PROFILE_SHA
    EXPORT = EXPORT
    NATIVE_SETTINGS = NATIVE_SETTINGS
    PUBLIC_CONTENT_ONLY = True
    verifier_environment = staticmethod(verifier_environment)
    PROVER_LANE_THREADS = 8
    # These are shared execution settings, not transferred binary/model authority.
    _SHARED = frozenset(('WRITER', 'WRITER_SHA', 'WRITER_DEPENDENCIES', 'WRITER_PYTHON', 'TEKKEN',
        'PROVER_LANES', 'WITNESS_CACHE_GIB', 'CHECK_LANES', 'CHECK_LANE_THREADS',
        'WRITER_THREADS', 'WRITERS_AT_ONCE', 'JOBS_IN_FLIGHT', 'SERVICE_IDLE_SECONDS', 'STEP_TIMEOUTS'))

    def __init__(self):
        self.intake = authority()
        self.intake_sha = INTAKE_SHA
        self.BINARY = BINARY
        self.BINARY_SHA = self.intake['binary_sha256']
        self.PROVER_BINARY_SHA = PROVER_BINARY_SHA
        self.IDENTITY = self.intake['statement_identity']
        self.RUN_PROFILE = self.intake['run_profile']
        self.VERIFIER_EXPORT = config.PUBLIC_DIR / 'verifier-export-w16r2-94643880'
        self.writer_mode()

    def __getattr__(self, name):
        if name in self._SHARED:
            return getattr(baseline, name)
        raise AttributeError(name)

    def writer_mode(self):
        require(os.environ.get('PM_FAST_WRITER_MODE', 'resident') == 'resident',
                'W16R2 requires the explicitly selected resident writer')
        return 'resident'

    @staticmethod
    def categories(): return baseline.categories()

    @staticmethod
    def templates(): return baseline.templates()

    @staticmethod
    def service_resources():
        # Conservative qualified two-writer admission, pending native W16R2 measurement.
        return {'need_gib': 196, 'cap_gib': 220, 'max_seconds': baseline.SERVICE_MAX_SECONDS}

    def service_dir(self): return config.PRIVATE_DIR / 'fast-service-w16r2'

    def native_environment(self):
        return {**baseline.native_environment(), **self.NATIVE_SETTINGS}

    def ensure_verifier_export(self):
        from .w16r2_export import prepare
        prepare(self.EXPORT, self.VERIFIER_EXPORT, self.PROFILE_SHA)

    def prover_binary(self):
        require(PROVER_BINARY.is_file() and not PROVER_BINARY.is_symlink()
                and records.sha256_file(PROVER_BINARY) == self.PROVER_BINARY_SHA,
                'W16R2 prover binary differs from its merged build')
        return PROVER_BINARY

    def service_binding(self):
        from . import resident_writer
        require(authority() == self.intake and INTAKE_SHA == self.intake_sha, 'W16R2 intake changed')
        return {'schema': 'pm-fast-writer-binding/2', 'kind': self.KIND, 'mode': self.writer_mode(),
            'public_content_only': True, 'production': False, 'native_flag': FLAG,
            'intake_sha256': self.intake_sha, 'writer_sha256': self.WRITER_SHA,
            'resident_source_digest': resident_writer.identity(self), 'profile_sha256': self.PROFILE_SHA,
            'binary_sha256': self.BINARY_SHA, 'model_identity': self.IDENTITY, 'run_profile': self.RUN_PROFILE,
            'prover_binary_sha256': self.PROVER_BINARY_SHA, 'prover_lane_threads': self.PROVER_LANE_THREADS,
            'export': str(self.EXPORT.resolve()), 'verifier_export': str(self.VERIFIER_EXPORT.resolve()),
            'resources': self.service_resources(), 'native_settings': dict(self.NATIVE_SETTINGS),
            'writer_processes': self.WRITERS_AT_ONCE, 'writer_threads': self.WRITER_THREADS,
            'prover_lanes': self.PROVER_LANES, 'check_lanes': self.CHECK_LANES}

    def matches_proof_binding(self, binding, descriptor):
        current = self.service_binding()
        if 'prover_binary_sha256' in descriptor:
            producer = descriptor['prover_binary_sha256']
            if producer == self.PROVER_BINARY_SHA:
                return binding == current
            if producer == COMPOSED_PROVER_SHA:
                return binding == dict(current, prover_binary_sha256=producer, prover_lane_threads=8,
                                       native_settings=COMPOSED_SETTINGS)
            return False
        # Completed A30/A31 jobs recorded one binary for both operations.
        for field in ('prover_binary_sha256', 'prover_lane_threads'):
            del current[field]
        current['native_settings'] = ORIGINAL_SETTINGS
        return binding == current

    def descriptor(self):
        # Publication records use binary_sha256 as the verifier identity.
        # The separately built producer is recorded under prover_binary_sha256.
        return {'kind': self.KIND, 'binary_sha256': self.BINARY_SHA, 'model_digest': self.IDENTITY,
            'token_profile_digest': self.PROFILE_SHA, 'run_profile': self.RUN_PROFILE,
            'prover_binary_sha256': self.PROVER_BINARY_SHA,
            'cli': 'zk60_classify W16R2 merged prover with A30/A31 verifier',
            'device': 'metal', 'proof_mode': 'resident-server, public content only',
            'policy_ids': [c['policy_id'] for c in self.categories()], 'privacy_adapter_supported': False,
            'batch_proving': False, 'activation_writer': self.writer_mode(),
            'service_resources': self.service_resources(), 'public_content_only': True,
            'production': False, 'development_candidate': True,
            'native_cli_flags': [FLAG], 'native_intake_sha256': self.intake_sha}

    def privacy_statement(self):
        from .classifier_privacy import statement_info
        return statement_info(self.descriptor())

    def deployment(self, template):
        # Deployment.development is the legacy synthetic-policy exception. This real
        # moderate-policy candidate keeps the 95-bit checks; its public dev scope is
        # separately explicit in its CLI, records, descriptor and service binding.
        return Deployment(self.BINARY, self.BINARY_SHA, self.EXPORT, self.VERIFIER_EXPORT,
            self.VERIFIER_EXPORT / 'token_io', self.IDENTITY, template.policy_id, template.chunk_size,
            8, 95, False, R_C3_SCHEMA)

    def validate(self, deploy):
        from . import resident_writer
        from .hardware_profiles import fast_classifier_profile
        require(authority() == self.intake and INTAKE_SHA == self.intake_sha, 'W16R2 native authority changed')
        self.writer_mode()
        require(not deploy.development and deploy.binary == self.BINARY and deploy.binary_sha256 == self.BINARY_SHA
            and deploy.statement_identity == self.IDENTITY and deploy.statement_schema == R_C3_SCHEMA
            and deploy.min_bits == 95 and deploy.overlap == 8, 'deployment differs from pinned W16R2 candidate')
        templates = {t.policy_id: t for t in self.templates()}
        require(deploy.policy in templates and deploy.chunk_size == templates[deploy.policy].chunk_size,
                'W16R2 category or geometry changed')
        require(deploy.prover_export == self.EXPORT and deploy.verifier_export == self.VERIFIER_EXPORT
                and deploy.tables == self.VERIFIER_EXPORT / 'token_io', 'W16R2 export paths differ')
        for directory in (deploy.prover_export, deploy.verifier_export):
            require(records.sha256_file(directory / 'profile.json') == self.PROFILE_SHA, 'W16R2 profile differs')
        require(records.sha256_file(self.WRITER) == self.WRITER_SHA, 'shared numerical writer source changed')
        for path, expected in self.WRITER_DEPENDENCIES.items():
            require(records.sha256_file(path) == expected, 'shared numerical dependency changed')
        resident_writer.authenticate(self)
        deploy.validate()
        fast_classifier_profile(runtime_module=self)

    def make_cli(self, deployment): return PublicContentCLI(deployment, self)

    def server_argv(self, kind):
        require(authority() == self.intake and INTAKE_SHA == self.intake_sha, 'W16R2 native authority changed')
        policies = ','.join(c['policy_id'] for c in self.categories())
        common = ['--tables', str(self.VERIFIER_EXPORT / 'token_io'), '--policies', policies,
                  '--label', 'zk60-classify-verdict', FLAG]
        if kind == 'prove':
            return [str(self.prover_binary()), 'serve', '--export', str(self.EXPORT), *common,
                '--lanes', str(self.PROVER_LANES), '--lane-threads', str(self.PROVER_LANE_THREADS),
                '--witness-cache-gib', str(self.WITNESS_CACHE_GIB)]
        require(kind == 'check', 'unknown W16R2 server')
        return [str(self.BINARY), 'check-serve', '--export', str(self.VERIFIER_EXPORT), *common,
            '--expect-statement', self.IDENTITY, '--min-bits', '95',
            '--lanes', str(self.CHECK_LANES), '--lane-threads', str(self.CHECK_LANE_THREADS)]
