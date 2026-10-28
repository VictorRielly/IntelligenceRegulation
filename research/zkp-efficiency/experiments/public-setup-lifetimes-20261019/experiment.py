#!/usr/bin/env python3
"""Public-only source/lifetime census and synthetic differential tests.

No native Shape, witness, proof or RNG is executed. Native source is read as
data. Timing is the harness clock, never a prover/cache speed measurement.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import re
import resource
import signal
import time
from collections import OrderedDict

HERE = Path(__file__).resolve().parent
SEED = 2026101984
RUN_ID = '20261019T161854Z-4bc2599e'
P = 0xffffffff00000001
GENERATOR = 7


def cap():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def read_native(rel):
    return (HERE / 'native' / rel.replace('/', '__')).read_text()


def dump(name, obj):
    (HERE / name).write_text(json.dumps(obj, indent=2, sort_keys=True) + '\n')


def frozen(obj):
    return json.dumps(obj, sort_keys=True, separators=(',', ':'))


class PublicNtt:
    """Immutable public roots; formula/strides model the pinned native NTT."""
    def __init__(self, max_log, generator=GENERATOR):
        assert 0 <= max_log <= 20
        self.max_log = max_log
        self.roots = tuple(pow(generator, (P - 1) >> k, P) for k in range(max_log + 1))
        self.inv_roots = tuple(pow(x, P - 2, P) for x in self.roots)
        half = max(1, (1 << max_log) // 2)
        fwd, inv = [], []
        a = b = 1
        for _ in range(half):
            fwd.append(a)
            inv.append(b)
            a = a * self.roots[-1] % P
            b = b * self.inv_roots[-1] % P
        self.forward_twiddles = tuple(fwd)
        self.inverse_twiddles = tuple(inv)

    @property
    def native_fp_payload_bytes(self):
        return 8 * (len(self.roots) + len(self.inv_roots) + len(self.forward_twiddles) + len(self.inverse_twiddles))

    def transform(self, values, inverse=False):
        a = list(values)
        n = len(a)
        assert n and n & (n - 1) == 0 and n <= 1 << self.max_log
        j = 0
        for i in range(1, n):
            bit = n >> 1
            while j & bit:
                j ^= bit
                bit >>= 1
            j |= bit
            if i < j:
                a[i], a[j] = a[j], a[i]
        tw = self.inverse_twiddles if inverse else self.forward_twiddles
        length = 2
        while length <= n:
            half = length // 2
            stride = (1 << self.max_log) // length
            for start in range(0, n, length):
                for k in range(half):
                    u, v = a[start + k], a[start + k + half] * tw[k * stride] % P
                    a[start + k] = (u + v) % P
                    a[start + k + half] = (u - v) % P
            length *= 2
        if inverse:
            scale = pow(n, P - 2, P)
            a = [x * scale % P for x in a]
        return a


def reference_eval(values, inverse=False):
    """Independent direct Vandermonde evaluation, no twiddle/stride cache."""
    n = len(values)
    root = pow(GENERATOR, (P - 1) // n, P)
    if inverse:
        root = pow(root, P - 2, P)
    out = []
    for j in range(n):
        x = pow(root, j, P)
        acc = 0
        for coefficient in reversed(values):
            acc = (acc * x + coefficient) % P
        out.append(acc)
    if inverse:
        out = [x * pow(n, P - 2, P) % P for x in out]
    return out


def reference_sites(tokens, width, lc, blocks):
    """Allocate each endpoint/boundary's pairs explicitly, then join stages."""
    rows = (tokens * width) // (1 << lc)
    # Each internal commitment has its own pairs [outgoing, incoming].
    boundaries = [tuple(tuple(range(rows + 2 * site, rows + 2 * site + 2)) for site in range(2)) for _ in range(blocks - 1)]
    external = tuple(range(rows, rows + 2))
    return [(external if k == 0 else boundaries[k - 1][1], external if k == blocks - 1 else boundaries[k][0]) for k in range(blocks)]


def overlay_sites(tokens, width, lc, blocks, k):
    data_rows = tokens * width >> lc
    incoming = data_rows if k == 0 else data_rows + 2
    outgoing = data_rows
    return ((incoming, incoming + 1), (outgoing, outgoing + 1))


def shape_descriptor(tokens=128):
    # A synthetic public descriptor with the pinned Shape field names. This is
    # NOT a native admitted Shape; class/plane-list checks remain owner gates.
    text = read_native('hashline/src/private_block/shape.rs')
    body = text.split('pub(crate) struct Shape {', 1)[1].split('\n}', 1)[0]
    fields = re.findall(r'^    pub (\w+):', body, re.M)
    shape = {field: 0 for field in fields}
    lc = {32: 13, 64: 13, 128: 14}[tokens]
    shape.update(name='synthetic-r8-descriptor', profile=f'synthetic-8b-T{tokens}', tokens=tokens, width=4096, hidden=14336,
                 q_heads=32, head_dim=128, kv_heads=8, log_cols=lc, inv_rate=4, opened_cols=256,
                 f_e=9, endpoint_rows=(tokens * 4096 >> lc) + 5, endpoint_log_n=lc,
                 endpoint_inv_rate=4, endpoint_general=True, norm_wrho=32, wrho_s=16,
                 norm_tn=9, norm_cn_a=2092, norm_cn_m=1424, norm_ceps=78617,
                 sh_ao=3, sh_qkv=8, sh_s=6, sh_o=9, sh_g=8, sh_h=14, sh_z=4,
                 trained_calibration=True, t_pad=tokens, d_pad=4096, h_pad=32, f_pad=16384,
                 d_max=2097153)
    assert set(shape) == set(fields)
    return shape


def census():
    specs = [
        ('hashline/src/private_block.rs', 'let ntt = NttTables::new(si.enc_log().max(so.enc_log()));', 'One NTT for BOTH external endpoints; dropped on return.'),
        ('hashline/src/private_block/run.rs', 'let ntt = NttTables::new(st.rs.ntt_log());', 'One NTT for all blocks and internal boundaries per proving invocation (also one per verifier).'),
        ('hashline/src/private_block/trained_block.rs', 'let mut lays: Vec<(NormCalibration, super::layout::Layout)> = Vec::new();', 'Sealing already deduplicates layout by entire calibration, within fixed run shape; dropped after sealing.'),
        ('hashline/src/private_block/trained_block.rs', 'let lay = match lays.iter().position', 'Existing per-calibration sealing cache, not per-layer NTT construction.'),
        ('hashline/src/private_block/run.rs', 'fn stage_layout(&self, k: usize)', 'Fresh layout per stage plus mandatory IO row overlay.'),
        ('hashline/src/private_block/layout.rs', 'let fresh = Layout::for_shape(sh)?;', 'CS-8 independently rebuilds layout. Cache cannot silently remove this gate.'),
        ('hashline/src/private_block/trained_block.rs', 'if let Some(w) = self.chain.kept[k].take()', 'Witness cache is input-local and consumed; never immutable public setup.'),
        ('hashline/src/private_block/run.rs', 'let mut rng = ZkRng::from_os', 'Fresh OS stream per proof; never part of reusable public context.'),
        ('hashline/src/private_block/trained_block.rs', 'if blk.digest() != self.digests[k]', 'Reload digest check still binds the actual bytes; retaining mutable export path is insufficient.'),
        ('hashline/src/private_block/trained_block.rs', 'pub(crate) fn run_constants(&self, layers:', 'Base calibration depends on selected ordered layer range, not export path alone.'),
        ('hashline/src/private_block/endpoint_g.rs', 'let mut rng = ZkRng::from_os', 'Fresh endpoint role-separated OS stream; reusable NTT is not reusable prepared endpoint.'),
        ('hashline/src/private_block/run.rs', 'let bytes = wire::encode_segment', 'Serialization occurs after block phase reporting and before sink; recurring, currently unisolated.'),
        ('hashline/src/gpu/cuda.rs', 'static GPU: OnceLock<Option<Mutex<Gpu>>>', 'Device owner already persists for process lifetime; no new initialization removal claimed.'),
        ('hashline/src/gpu/cuda.rs', 'fn ensure_twiddles(&mut self, ntt:', 'Device stage-major twiddles already cached monotonically by capacity. CPU NTT reuse removes no already avoided upload.'),
        ('hashline/src/gpu/cuda.rs', 'if *ml >= ntt.max_log', 'Existing sufficient-capacity cache hit, including a smaller later request.'),
    ]
    rows = []
    for file, anchor, finding in specs:
        lines = read_native(file).splitlines()
        locations = [n for n, line in enumerate(lines, 1) if anchor in line]
        assert locations, (file, anchor)
        rows.append(dict(file=file, anchor=anchor, lines=locations, finding=finding))
    return rows


def public_block_payload(tokens):
    """Allocation-free exact backing-element count from R8 constructors."""
    d, f, kv, half = 4096, 16384, 1024, 64
    lengths = dict(wq=d*d, wk=kv*d, wv=kv*d, wo=d*d,
                   gamma_a=d, gamma_m=d, wg=d*f, wu=d*f, wd=f*d,
                   rope_cos=tokens*half*8, rope_sin=tokens*half*8,
                   exp=256*8, act=256*2)
    return lengths


def cache_schedule(capacity, passes, pinned):
    """Public layer-id trace only. Never holds actual weights/witnesses."""
    retained = OrderedDict()
    hits = misses = 0
    # Current sealing then proving scans the same ordered public layer list.
    for scan in range(2 * passes):
        for layer in range(32):
            if layer in retained:
                hits += 1
                retained.move_to_end(layer)
                continue
            misses += 1
            if not capacity or (pinned and layer >= capacity):
                continue
            if len(retained) == capacity:
                retained.popitem(last=False)
            retained[layer] = None
    return dict(hits=hits, misses=misses, requests=hits+misses)


def run():
    start = time.monotonic()
    cap()
    checks = 0
    controls = {}
    pins = json.loads((HERE / 'source-pins.json').read_text())
    for pin in pins:
        expected = pin['sha256']
        assert hashlib.sha256((HERE / pin['snapshot']).read_bytes()).hexdigest() == expected
        assert hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest() == expected
        checks += 2
    source = census()
    dump('source-census.json', source)
    checks += len(source)
    assert '0xFFFF_FFFF_0000_0001' in read_native('zkp-core/src/field.rs')
    assert 'pub const GENERATOR: u64 = 7;' in read_native('zkp-core/src/field.rs')
    checks += 2
    rand = random.Random(SEED)
    large = PublicNtt(16)
    fixtures = []
    # Full small-domain outputs, inverse roundtrip and max-table stride reuse.
    for logn in range(8):
        n = 1 << logn
        for kind in ['random', 'boundary', 'zero']:
            values = ([rand.randrange(P) for _ in range(n)] if kind == 'random' else
                      [0, 1, P - 1, P - 2][0:n] if kind == 'boundary' and n <= 4 else
                      [([0, 1, P - 1, P - 2][i % 4]) for i in range(n)] if kind == 'boundary' else [0] * n)
            want = reference_eval(values)
            fresh = PublicNtt(logn)
            for plan in [fresh, large]:
                got = plan.transform(values)
                assert got == want
                assert plan.transform(got, inverse=True) == values
                checks += 2
            assert reference_eval(want, inverse=True) == values
            checks += 1
            fixtures.append(dict(log_n=logn, kind=kind, values=values, evaluations=want))
    # Reed-Solomon zero padding, all words compared independently.
    for n in [1, 2, 4, 8, 16, 32]:
        values = [rand.randrange(P) for _ in range(n)]
        padded = values + [0] * (3 * n)
        assert large.transform(padded) == reference_eval(padded)
        checks += 1
    # Complete production-capacity public twiddle values, direct pow oracle.
    for k in range(17):
        assert large.roots[k] == pow(GENERATOR, (P - 1) // (1 << k), P)
        checks += 1
    for i, value in enumerate(large.forward_twiddles):
        assert value == pow(GENERATOR, i * ((P - 1) // (1 << 16)), P)
        assert large.inverse_twiddles[i] * value % P == 1
        checks += 2
    sample = [rand.randrange(P) for _ in range(32)]
    controls['wrong_generator_changes_domain'] = PublicNtt(16, 3).transform(sample) != reference_eval(sample)
    controls['inverse_direction_changes_output'] = large.transform(sample, inverse=True) != reference_eval(sample)
    controls['output_order_changes_statement'] = list(reversed(large.transform(sample))) != reference_eval(sample)
    controls['zero_cannot_validate_domain_identity'] = PublicNtt(16, 3).transform([0] * 32) == reference_eval([0] * 32)
    try:
        PublicNtt(4).transform([1] * 32)
        controls['insufficient_capacity_refused'] = False
    except AssertionError:
        controls['insufficient_capacity_refused'] = True
    rows, overlay_checks, wrong_stages = [], 0, 0
    for tokens, lc in [(32, 13), (64, 13), (128, 14)]:
        shape = shape_descriptor(tokens)
        for blocks in [1, 2, 4, 32]:
            want = reference_sites(tokens, 4096, lc, blocks)
            for k in range(blocks):
                got = overlay_sites(tokens, 4096, lc, blocks, k)
                assert got == want[k]
                overlay_checks += 1
            for boundary in range(blocks - 1):
                assert set(want[boundary][1]).isdisjoint(want[boundary + 1][0])
                overlay_checks += 1
            # Same Shape + stage-0 overlay cached as a whole Layout is WRONG.
            naive = [want[0]] * blocks
            wrong = sum(a != b for a, b in zip(naive, want))
            wrong_stages += wrong
            rows.append(dict(tokens=tokens, blocks=blocks, data_rows=(tokens * 4096 >> lc),
                             correct_sites=want, whole_layout_shape_only_wrong_stages=wrong))
    controls['whole_stage_layout_shape_key_fails'] = wrong_stages > 0
    shape = shape_descriptor()
    shape_key = frozen(shape)
    mutations = []
    for field in shape:
        changed = copy.deepcopy(shape)
        value = changed[field]
        changed[field] = not value if type(value) is bool else value + 1 if isinstance(value, int) else value + '-different'
        assert frozen(changed) != shape_key
        mutations.append(field)
        checks += 1
    # Full native Shape is sufficient for Layout contents, not for block tables.
    # Different layers may have the same shape yet distinct exp/SiLU tables.
    pub_a = dict(model='synthetic-model-A', manifest='synthetic-manifest-A', block_digest='synthetic-block-A',
                 layer=0, shape=shape, rope_mode='registry-pinned', exp_key=2, act_key=[-4, -12])
    pub_b = copy.deepcopy(pub_a)
    pub_b.update(layer=1, manifest='synthetic-manifest-B', block_digest='synthetic-block-B', act_key=[-2, -11])
    controls['shape_not_key_for_public_layer_bundle'] = frozen(pub_a['shape']) == frozen(pub_b['shape']) and frozen(pub_a) != frozen(pub_b)
    changed_cal = copy.deepcopy(shape)
    changed_cal['norm_cn_a'] += 1
    geometry_fields = ['profile', 'tokens', 'width', 'hidden', 'log_cols']
    controls['geometry_key_omits_calibration'] = frozen([shape[k] for k in geometry_fields]) == frozen([changed_cal[k] for k in geometry_fields]) and frozen(shape) != frozen(changed_cal)
    # Canonical selected-layer base: enumerate counts then lexical tiebreak.
    calibrations = [(6, 2000), (7, 2100), (7, 2100), (6, 2000)]
    def base(selected):
        counts = {c: selected.count(c) for c in set(selected)}
        return min(counts, key=lambda c: (-counts[c], c))
    controls['layer_range_changes_base'] = base(calibrations) != base(calibrations[1:3])
    controls['mask_rng_transcript_witness_excluded'] = not any(x in shape for x in ['rng', 'mask', 'witness', 'transcript', 'prepared_endpoint', 'challenge'])
    assert all(controls.values()), controls
    # Logical constructor/payload accounting only; two sequential scopes today.
    ledger = []
    for tokens, lc in [(32, 13), (64, 13), (128, 14)]:
        log = lc + 2
        payload = 8 * ((1 << log) + 2 * (log + 1))
        for passes in [1, 2, 4, 8]:
            ledger.append(dict(context=tokens, passes=passes, blocks_per_pass=32,
                               current_prover_ntt_constructions=2 * passes,
                               candidate_public_ntt_constructions=1,
                               removed_constructions=2 * passes - 1,
                               public_ntt_fp_payload_bytes=payload,
                               existing_gpu_twiddle_payload_bytes=16 * ((1 << log) - 1),
                               additional_gpu_uploads_removed_by_cpu_cache=0,
                               cumulative_current_constructed_payload_bytes=payload * 2 * passes,
                               cumulative_candidate_constructed_payload_bytes=payload,
                               retained_across_sealing=True,
                               note='Fixed-context resident synthetic schedule. Forward/backward twiddle and root payload only; not peak RAM, DRAM, speed or proof work. Verifier remains separate.'))
    dump('fixtures.json', fixtures)
    dump('io-site-cases.json', rows)
    dump('ntt-lifetime-ledger.json', ledger)
    public_ledger = []
    for tokens in [32, 64, 128]:
        sizes = public_block_payload(tokens)
        per_layer = sum(sizes.values())
        for passes in [1, 2, 4, 8]:
            for capacity in [0, 1, 4, 16, 31, 32]:
                lru = cache_schedule(capacity, passes, pinned=False)
                pinned = cache_schedule(capacity, passes, pinned=True)
                assert lru['hits'] == (0 if capacity < 32 else (2 * passes - 1) * 32)
                assert pinned['hits'] == (2 * passes - 1) * capacity
                checks += 2
                public_ledger.append(dict(context=tokens, passes=passes, capacity_layers=capacity,
                                          per_layer_backing_payload_bytes=per_layer,
                                          retained_backing_payload_bytes=per_layer*capacity,
                                          lru=lru, public_fixed_pinned_subset=pinned,
                                          note='Synthetic public constructor-access trace. Retaining public words avoids only identified load/rebuild work, not any CS gate, per-input sealing, witness, proof or randomness. No actual resident source or bytes retained.'))
    controls['partial_LRU_thrashes_cyclic_public_scan'] = cache_schedule(31, 8, False)['hits'] == 0
    controls['pinned_public_subset_keeps_hits'] = cache_schedule(4, 8, True)['hits'] == 60
    controls['unpadding_understates_public_residency'] = 3*4096*16384 > 3*4096*14336
    assert all(controls.values())
    dump('public-block-residency-ledger.json', public_ledger)
    dump('public-block-payload-components.json', {str(t): public_block_payload(t) for t in [32, 64, 128]})
    report = json.loads((HERE / 'native/report.json').read_text())
    numbers = report['numbers']
    events = json.loads((HERE / 'clock-events.json').read_text())['public_clock_fields_only']
    sealed = next(x for x in events if x['event'] == 'sealed')
    proved = next(x for x in events if x['event'] == 'proved')
    assert proved['load_seconds'] == sealed['of_which_load_seconds']
    assert proved['sealing_witness_seconds'] == sealed['of_which_witness_seconds']
    checks += 2
    total = numbers['prove']['total_seconds']
    accounting = dict(scope='Carried owner R8 CPU diagnostic, researcher did not reverify receipt; no newly counted proof positions.',
                      context=128, passes=1, blocks=32, workload='single fixed-context transformer stack prefill',
                      device='CPU, GPU off', cpu_threads=16, cpu='Intel Core Ultra 9 185H',
                      total_seconds=total, diagnostic_positions_per_second=128 / total,
                      prove_run_seconds=numbers['prove']['prove_run_seconds'],
                      witness_rebuild_in_prove_seconds=numbers['prove']['of_which_witness_seconds'],
                      sealing_wall_seconds=numbers['prove']['sealing_pass_seconds'],
                      sealing_load_task_seconds=numbers['prove']['load_seconds'],
                      sealing_witness_task_seconds=sealed['of_which_witness_seconds'],
                      proof_block_load_seconds=proved['of_which_block_load_seconds'],
                      proof_block_load_nested_in_witness_handover=True,
                      reported_load_seconds_means='seal.load_s only, NOT sealing plus proving block loads',
                      receipt_bytes=numbers['prove']['receipt_bytes'],
                      verify_seconds=numbers['verify']['verify_seconds'], verify_load_seconds=numbers['verify']['load_seconds'],
                      recheck_seconds=numbers['recheck']['verify_seconds'], recheck_load_seconds=numbers['recheck']['load_seconds'],
                      startup_seconds=None, startup_fraction=None, serialization_seconds=None,
                      steady_positions_per_second=None, candidate_saving_seconds=None,
                      candidate_ceiling='Not numerically identifiable: T/(T-s+a), where s is exclusive avoided public construction, a is retained-cache/key/overlay cost. No constructor clocks.',
                      all_load_zero_cost_upper_speedup=total/(total-numbers['prove']['load_seconds']-proved['of_which_block_load_seconds']),
                      all_load_upper_bound_note='Optimistic bound for removing ALL reported sealing-load tasks plus proof-block loads, not a candidate forecast. Overlap during sealing reduces actual wall saving; every retained check and cache cost further reduces gain. NTT/layout outside this load scope remain separate.',
                      new_target_proofs=0, new_target_passes=0, new_target_positions=0,
                      target_steady_rate=None, target_total_rate=None,
                      warning='Sealing includes witness/refusals and is recurring per input. Load clocks may overlap sealing witness or be nested in witness hand-over. Do not add/subtract them as exclusive phases.')
    dump('target-accounting.json', accounting)
    result = dict(status='PASS', hypothesis_result='Bounded public NTT reuse exact in model; geometry-only and whole-stage Shape-only cache shortcuts falsified. No speed improvement measured.',
                  run_id=RUN_ID, seed=SEED, checks=checks + overlay_checks,
                  ntt_fixtures=len(fixtures), rs_fixtures=6, full_capacity_twiddles=32768,
                  io_overlay_checks=overlay_checks, stale_shape_only_wrong_stages=wrong_stages,
                  shape_field_mutations=len(mutations), negative_controls=controls,
                  source_pins=len(pins), r8_manifest_matched_sources=11,
                  ntt_T128_payload_bytes=large.native_fp_payload_bytes,
                  public_block_T128_payload_bytes=sum(public_block_payload(128).values()),
                  all32_public_blocks_T128_payload_bytes=32*sum(public_block_payload(128).values()),
                  residency_schedules=len(public_ledger),
                  wall_seconds=time.monotonic() - start, rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  affinity=sorted(os.sched_getaffinity(0)), threads=1, nice=os.getpriority(os.PRIO_PROCESS, 0),
                  platform=platform.platform(), python=platform.python_version(),
                  cpu=next(x.split(':', 1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
                  limits='59s CPU/wall;512MiB address space;estimated64MiB;one nice19 CPU;no build/GPU/install/downloaded-code execution',
                  scope='Source census + synthetic public descriptors and big-int field reference. No native Shape admission/CS8 override, proof, masks, transcript, verifier, physical traffic or candidate runtime test.')
    dump('result.json', result)
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    run()
