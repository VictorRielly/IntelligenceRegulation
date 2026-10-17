#!/usr/bin/env python3
"""Bounded synthetic differential against the inspected local TensorRef reader.

Only synthetic tensor bytes are written. No checkpoint payload, proof or GPU.
"""
import hashlib
import importlib.util
import json
import math
import os
import platform
import random
import resource
import signal
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
IMPORTER = ROOT / "results/zk60_1b_checkpoint_20260927/importer_zk60_1b_checkpoint.py"
SEED = 2026093015
RUN = "20260930T004944Z-77f0d93d"
CHUNK = 1024 * 1024


class CountFile:
    def __init__(self, file, owner):
        self.file, self.owner = file, owner

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.file.close()

    def seek(self, where):
        return self.file.seek(where)

    def read(self, size):
        data = self.file.read(size)
        self.owner.bytes_read += len(data)
        self.owner.read_calls += 1
        if self.owner.corrupt_once and data:
            self.owner.corrupt_once = False
            data = data[:-1] + bytes([data[-1] ^ 1])
        return data


class CountPath:
    def __init__(self, path, corrupt_once=False):
        self.path = path
        self.name = path.name
        self.bytes_read = self.read_calls = self.opens = 0
        self.corrupt_once = corrupt_once

    def open(self, mode):
        self.opens += 1
        return CountFile(self.path.open(mode), self)


def read_tiles(ref, requests, max_tile_bytes=CHUNK, max_total_bytes=8*CHUNK,
               max_requests=16):
    """One complete SHA-256 scan; release the tuple only after digest parity.

    No remembered 'verified' flag, mmap, trusted stat or cross-call digest cache.
    All requested slices are buffered, including duplicates, in caller order.
    """
    if type(requests) not in (list, tuple) or not 0 < len(requests) <= max_requests:
        raise ValueError("invalid bounded request count")
    size = ref.end - ref.start
    total = 0
    for request in requests:
        if type(request) not in (list, tuple) or len(request) != 2:
            raise ValueError("invalid tile descriptor")
        offset, length = request
        if type(offset) is not int or type(length) is not int or offset < 0 or length < 0 or length > max_tile_bytes or offset + length > size:
            raise ValueError("tile exceeds bounded read limit")
        if offset % 2 or length % 2:
            raise ValueError("BF16 tile must align to elements")
        total += length
    if total > max_total_bytes:
        raise ValueError("aggregate tile buffer exceeds bound")
    digest = hashlib.sha256()
    buffers = [bytearray() for _ in requests]
    with ref.shard.open("rb") as stream:
        stream.seek(ref.data_start + ref.start)
        position = 0
        while position < size:
            chunk = stream.read(min(size - position, CHUNK))
            if not chunk:
                raise ValueError("tensor truncated after inventory")
            digest.update(chunk)
            for buffer, (offset, length) in zip(buffers, requests):
                lo, hi = max(offset, position), min(offset + length, position + len(chunk))
                if hi > lo:
                    buffer.extend(chunk[lo-position:hi-position])
            position += len(chunk)
    if digest.hexdigest() != ref.sha256:
        raise ValueError("tensor changed after source pinning")
    return tuple(bytes(buffer) for buffer in buffers)


def load_baseline():
    spec = importlib.util.spec_from_file_location("inspected_tensor_importer", IMPORTER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.TensorRef


def must_refuse(fn):
    try:
        fn()
    except ValueError:
        return
    raise AssertionError("negative control unexpectedly returned tiles")


def geometry_ledger(config, tile_size, batch):
    d, f, layers = config["hidden_size"], config["intermediate_size"], config["num_hidden_layers"]
    kv = config["num_key_value_heads"] * (d // config["num_attention_heads"])
    # Public config dimensions only. No tensor payload or learned value is read.
    shapes = [(d,d), (kv,d), (kv,d), (d,d), (f,d), (f,d), (d,f), (d,), (d,)]
    sizes = [2*math.prod(shape) for shape in shapes]
    baseline = candidate = tiles = scans = 0
    enumerated_baseline = enumerated_candidate = 0
    for size in sizes:
        ntiles = (size + tile_size - 1) // tile_size
        nscans = (ntiles + batch - 1) // batch
        baseline += ntiles * size
        candidate += nscans * size
        tiles += ntiles
        scans += nscans
        # Independent request/group enumeration, separate from ceiling formulas.
        offsets = list(range(0, size, tile_size))
        enumerated_baseline += sum(size for _ in offsets)
        enumerated_candidate += sum(size for _ in range(0, len(offsets), batch))
    assert (baseline,candidate) == (enumerated_baseline,enumerated_candidate)
    return {"layers":layers, "tile_bytes":tile_size, "batch_tiles":batch,
            "proved_stack_raw_bf16_bytes":sum(sizes)*layers,
            "baseline_full_tensor_scan_bytes":baseline*layers,
            "candidate_full_tensor_scan_bytes":candidate*layers,
            "existing_read_bytes_single_scan_bytes":sum(sizes)*layers,
            "largest_existing_read_bytes_payload":max(sizes),
            "source_counted_scan_byte_reduction_fraction":1-candidate/baseline,
            "tile_requests":tiles*layers, "candidate_full_scans":scans*layers,
            "initial_inventory_bytes_excluded":True,
            "assumption":"Each block tensor is tiled completely exactly once; no measured caller uses this schedule yet."}


def main():
    resource.setrlimit(resource.RLIMIT_CPU, (55,55))
    resource.setrlimit(resource.RLIMIT_AS, (512*CHUNK,512*CHUNK))
    signal.alarm(59)
    started = time.perf_counter()
    TensorRef = load_baseline()
    g = random.Random(SEED)
    cases, controls = [], []
    comparisons = 0
    with tempfile.TemporaryDirectory(prefix="synthetic-tiles-", dir=OUT) as temp:
        tensor_path = Path(temp)/"synthetic.tensor"
        for size in [2,30,4098,131074,CHUNK-2,CHUNK+2,2*CHUNK+6]:
            payload = g.randbytes(size)
            prefix = g.randbytes(74)
            suffix = g.randbytes(20)
            tensor_path.write_bytes(prefix+payload+suffix)
            requests = [(0, min(size, 128)), (size,0), (0, min(size,128)),
                        (max(0,size-14), min(size,14))]
            if size > CHUNK:
                requests += [(CHUNK-4, min(12,size-(CHUNK-4))), (2,min(CHUNK,size-2))]
            for _ in range(8):
                offset = g.randrange(size//2+1)*2
                length = g.randrange(min(512,(size-offset)//2)+1)*2
                requests.append((offset,length))
            digest = hashlib.sha256(payload).hexdigest()
            def ref(path):
                return TensorRef("synthetic",path,"BF16",(size//2,),10,10+size,64,digest)
            old_path, new_path = CountPath(tensor_path), CountPath(tensor_path)
            old = tuple(ref(old_path).read_tile(o,n) for o,n in requests)
            new = read_tiles(ref(new_path), requests)
            oracle = tuple(payload[o:o+n] for o,n in requests)
            assert old == new == oracle
            assert old_path.bytes_read == size*len(requests)
            assert new_path.bytes_read == size
            assert old_path.opens == len(requests) and new_path.opens == 1
            comparisons += len(requests)
            cases.append({"tensor_bytes":size,"requests":len(requests),
                          "returned_bytes":sum(n for _,n in requests),
                          "baseline_read_bytes":old_path.bytes_read,
                          "candidate_read_bytes":new_path.bytes_read,
                          "baseline_read_calls":old_path.read_calls,
                          "candidate_read_calls":new_path.read_calls,
                          "return_sha256":hashlib.sha256(b"".join(new)).hexdigest()})
        # Largest fixture remains synthetic. Check changed bytes beyond returned tile.
        narrow = [(0,16),(size-8,8)]
        original = tensor_path.read_bytes()
        for label, changed in [
            ("mutation_in_returned_tile", original[:74]+bytes([original[74]^1])+original[75:]),
            ("mutation_outside_all_requested_tiles", original[:174]+bytes([original[174]^1])+original[175:]),
            ("late_tensor_mutation", original[:74+size-2]+bytes([original[74+size-2]^1])+original[74+size-1:]),
            ("truncated_payload",original[:74+size-2])]:
            tensor_path.write_bytes(changed)
            must_refuse(lambda: ref(CountPath(tensor_path)).read_tile(*narrow[0]))
            must_refuse(lambda: read_tiles(ref(CountPath(tensor_path)),narrow))
            controls.append(label)
        tensor_path.write_bytes(original)
        must_refuse(lambda: read_tiles(ref(CountPath(tensor_path,True)),narrow))
        controls.append("mutation_during_scan_no_partial_return")
        # A cached-verified flag would return corrupted bytes or miss unrelated corruption.
        cached = tuple(payload[o:o+n] for o,n in narrow)
        changed = bytearray(original)
        changed[174] ^= 1
        tensor_path.write_bytes(changed)
        assert tuple(bytes(changed[74+o:74+o+n]) for o,n in narrow) == cached
        must_refuse(lambda: read_tiles(ref(CountPath(tensor_path)),narrow))
        controls.append("unsafe_skip_rehash_accepts_outside_corruption")
        tensor_path.write_bytes(original)
        bad_requests = [[],[(True,2)],[(-2,2)],[(0,3)],[(1,2)],[(size,2)],
                        [(0,CHUNK+2)],[(0,2)]*17,[(0,CHUNK)]*9,[(0,2,4)]]
        for req in bad_requests:
            path = CountPath(tensor_path)
            must_refuse(lambda: read_tiles(ref(path),req))
            assert path.opens == 0
        controls.append("ten_invalid_batches_refused_before_io")
        # Noncached next call revalidates the whole tensor even for an empty tile.
        must_refuse(lambda: read_tiles(TensorRef("s",CountPath(tensor_path),"BF16",(size//2,),10,10+size,64,"0"*64),[(size,0)]))
        controls.append("wrong_pin_even_for_zero_length_tile")

    configs = {}
    config_paths = {
        "tinyllama_1_1b":"results/zk60_mvp_20260929/tinyllama-1.1b/config.json",
        "llama3_8b":"results/zk60_mvp_20260929/llama3-8b/config.json"}
    for name,path in config_paths.items():
        configs[name] = geometry_ledger(json.loads((ROOT/path).read_text()),CHUNK,8)
    # Separately reported stack parameter counts in the source-identity audits.
    assert configs["tinyllama_1_1b"]["proved_stack_raw_bf16_bytes"] == 968974336*2
    assert configs["llama3_8b"]["proved_stack_raw_bf16_bytes"] == 6979584000*2
    pins = [str(IMPORTER.relative_to(ROOT)),*config_paths.values(),
            "ops/zkp-mvp/driver-overlay/hashline/src/private_block/mvp_driver.rs",
            "ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/run.rs",
            "results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/report.json"]
    cpu = next((line.split(":",1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")),"unknown")
    result = {"run_identity":RUN,"seed":SEED,"status":"passed",
              "baseline":"Actual inspected local TensorRef.read_tile imported with bytecode writes disabled",
              "cases":cases,"independent_slice_comparisons":comparisons,
              "negative_controls":controls,"invalid_batch_cases":len(bad_requests),
              "source_counted_geometry":configs,
              "source_pins_sha256":{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in pins},
              "script_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "elapsed_s":time.perf_counter()-started,"peak_rss_kib":resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              "cpu":cpu,"device":"CPU only; no accelerator", "threads":1,
              "python":platform.python_version(),"platform":platform.platform(),
              "limits":{"wall_s":59,"cpu_s":55,"address_space_mib":512,"estimated_memory_mib":64},
              "candidate_max_requested_payload_mib":8,
              "candidate_buffer_bound_note":"At most 8 MiB bytearrays + 8 MiB final bytes + 2 MiB transient scan chunks, plus Python overhead; no retained model",
              "scope":"Synthetic exact raw BF16 byte slicing and full-tensor SHA-256 refusal; no quantization, calibrated import, native witness/proof or GPU speed measured",
              "full_stack":{"completed_independently_verified_model_passes":0,"countable_tokens":0,
                            "context_length":None,"passes":0,"steady_tokens_per_s":None,"total_tokens_per_s":None,
                            "startup_fraction":None,"witness_s":None,"proof_s":None,"serialization_s":None,
                            "verification_s":None,"proof_lag_s":None}}
    (OUT/"result.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({k:result[k] for k in ["status","independent_slice_comparisons","elapsed_s","peak_rss_kib","negative_controls","source_counted_geometry"]},indent=2))


if __name__ == "__main__":
    main()
