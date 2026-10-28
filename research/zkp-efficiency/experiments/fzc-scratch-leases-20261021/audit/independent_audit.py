#!/usr/bin/env python3
"""Read-only native seam census and synthetic lease hazards; no GPU/native execution."""

import hashlib
import json
import os
import resource
import signal
from pathlib import Path


ROOT = Path("/home/victor/IntelligenceRegulation")
CUDA = ROOT / "ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs"
KERNEL = ROOT / "ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/fzc_kernels.cu"
REPORT = Path(__file__).with_name("independent_audit.json")


def limit_process():
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    signal.alarm(30)
    allowed = os.sched_getaffinity(0)
    os.sched_setaffinity(0, {min(allowed)})
    return min(allowed)


def source(path):
    raw = path.read_bytes()
    return raw.decode("utf-8"), hashlib.sha256(raw).hexdigest()


def position(src, needle):
    assert needle in src, f"native source anchor absent: {needle}"
    return src[:src.index(needle)].count("\n") + 1


def round_shape(degree, k, tail_log):
    nv = degree + 1
    return {
        "degree": degree,
        "nv": nv,
        "k": k,
        "tail_log": tail_log,
        "mapped_u64": 2 * nv + 1,
        "fallback_u64": 2 * nv,
        "tail_u64": k * (1 << tail_log) * 2,
    }


def tally(trace):
    names = ("mapped_u64", "fallback_u64", "tail_u64")
    baseline = {name: sum(row[name] for row in trace) for name in names}
    capacities = {name: 0 for name in names}
    cached_allocated = {name: 0 for name in names}
    cache_events = {name: 0 for name in names}
    for row in trace:
        for name in names:
            if row[name] > capacities[name]:
                capacities[name] = row[name]
                cached_allocated[name] += row[name]
                cache_events[name] += 1
    assert baseline == {"mapped_u64": 384, "fallback_u64": 352, "tail_u64": 63488}
    assert capacities == {"mapped_u64": 13, "fallback_u64": 12, "tail_u64": 2688}
    assert cache_events == {name: 2 for name in names}
    return {
        "baseline_per_attempt_native_allocation_events": len(trace) * len(names),
        "baseline_cumulative_u64": baseline,
        "baseline_cumulative_bytes": sum(baseline.values()) * 8,
        "baseline_per_attempt_peak_u64": max(sum(row[name] for name in names) for row in trace),
        "bounded_growth_cache_native_allocation_events": sum(cache_events.values()),
        "bounded_growth_cache_events_by_kind": cache_events,
        "bounded_growth_cache_cumulative_allocated_u64": cached_allocated,
        "bounded_growth_cache_cumulative_allocated_bytes": sum(cached_allocated.values()) * 8,
        "bounded_growth_cache_final_retained_u64": capacities,
        "bounded_growth_cache_final_retained_bytes": sum(capacities.values()) * 8,
        "interpretation": "One sequential same-context lease per kind; grow on demand. Counts assume each attempt reaches the host-tail transition and mapped allocation succeeds. Replacement may briefly hold old and new capacities simultaneously."
    }


def poll_can_false_complete(old_degree, new_degree, old_flag, old_payload_at_new_flag, reset_new_flag, prior_stream_complete):
    """Model only the observed flag predicate and lease eligibility, not CUDA behavior."""
    old_offset = 2 * (old_degree + 1)
    new_offset = 2 * (new_degree + 1)
    visible = old_flag if old_offset == new_offset else old_payload_at_new_flag
    if reset_new_flag:
        visible = 0
    # A completed prior stream makes a post-completion reset durable against
    # old writes. Without completion, an old kernel can still write seq=1.
    if reset_new_flag and not prior_stream_complete:
        visible = 1
    return visible == 1


def hazard_checks():
    cases = {
        "same_degree_stale_seq1": poll_can_false_complete(4, 4, 1, 0, False, True),
        "degree_5_to_4_old_payload_equals_seq1": poll_can_false_complete(5, 4, 1, 1, False, True),
        "degree_4_to_5_old_flag_slot_stale_seq1": poll_can_false_complete(4, 5, 1, 1, False, True),
        "clear_before_old_stream_completion_is_insufficient": poll_can_false_complete(4, 4, 1, 0, True, False),
        "same_context_sync_then_current_flag_reset": poll_can_false_complete(5, 4, 1, 1, True, True),
        "fresh_zeroed_mapping": poll_can_false_complete(4, 4, 0, 0, False, True),
    }
    assert all(cases[k] for k in list(cases)[:4])
    assert cases["same_context_sync_then_current_flag_reset"] is False
    assert cases["fresh_zeroed_mapping"] is False
    return cases


def main():
    cpu = limit_process()
    rust, rust_hash = source(CUDA)
    cu, cu_hash = source(KERNEL)
    anchors = {
        "FzcMapped_constructor": position(rust, "fn new(dev: &Arc<CudaDevice>, len: usize) -> Result<FzcMapped, String>"),
        "mapped_zero_initialization": position(rust, "std::ptr::write_volatile(host.add(i), 0)"),
        "eager_fallback_allocation": position(rust, "let pin = PinBuf::new_read(&dev, nv * 2)?;"),
        "mapped_allocation": position(rust, "match FzcMapped::new(&dev, nv * 2 + 1)"),
        "per_attempt_seq_reset": position(rust, "mapped, seq: 0,"),
        "seq_increment": position(rust, "self.seq += 1;"),
        "poll_flag": position(rust, "if m.read(2 * nv) == self.seq"),
        "fallback_drop_mapping": position(rust, "self.mapped = None;"),
        "fallback_copy": position(rust, "cu::memcpy_dtoh_async(self.pin.as_mut_slice()"),
        "fallback_stream_sync": position(rust, "cu::stream::synchronize(stream)"),
        "tail_pack_size": position(rust, "let n_words = self.k * half * 2;"),
        "tail_pin_allocation": position(rust, "let mut pin = PinBuf::new_read(&self.dev, n_words)?;"),
        "kernel_mapped_words": position(cu, "if (mapped) ((volatile u64*)mapped)[tid] = v;"),
        "kernel_system_fence": position(cu, "__threadfence_system();"),
        "kernel_mapped_flag": position(cu, "if (tid == 0) ((volatile u64*)mapped)[NV * 2] = seq;"),
    }
    assert anchors["eager_fallback_allocation"] < anchors["mapped_allocation"]
    assert anchors["kernel_mapped_words"] < anchors["kernel_system_fence"] < anchors["kernel_mapped_flag"]
    shapes = ((4, 20, 5), (5, 21, 6), (5, 20, 5), (4, 21, 6))
    trace = [round_shape(*shapes[i % len(shapes)]) for i in range(32)]
    counts = tally(trace)
    hazards = hazard_checks()
    report = {
        "scope": "Independent read-only Rust/CUDA seam audit and pure Python synthetic state model; no native execution or performance measurement.",
        "source_sha256": {str(CUDA): rust_hash, str(KERNEL): cu_hash},
        "source_anchor_lines": anchors,
        "trace": {"attempts": 32, "cycle": [round_shape(*s) for s in shapes], "assumptions": "Every attempt constructs split path, successful mapped allocation, one eventual tail transition with half=2^tail_log; sequential and same CUDA context."},
        "counts": counts,
        "negative_controls": hazards,
        "checks": {
            "source_anchors_present": True,
            "constructor_eager_fallback_precedes_mapping": True,
            "kernel_words_fence_flag_order": True,
            "trace_count_and_sizes": True,
            "unsafe_reuse_cases_detected": True,
            "sync_and_reset_case_rejects_false_completion": True,
        },
        "findings": [
            "Existing fresh FzcMapped zeroes all words; a retained allocation can expose prior flag 1 when a new DevFzcRounds resets seq to 0 and first launch increments to 1.",
            "Degree 5 to 4 moves the flag from index 12 to 10, an old payload word; degree 4 to 5 moves it to index 12, which may contain a prior larger-shape flag. Reset must address the new degree and synchronize prior writers first.",
            "The host polls a mapped flag after device __threadfence_system, but the flag is written inside a still-running kernel. Seeing it is not proof that the stream finished or that freeing/releasing mapped storage is safe. Stream completion must precede cross-attempt reuse and quarantine decisions.",
            "The constructor allocates fallback PinBuf before trying mapping. A cache lease for fallback must be acquired eagerly at construction to preserve constructor-stage refusal; lazy acquisition on timeout changes when failure becomes visible. A cache hit skips a new native allocation and therefore cannot reproduce every allocator refusal.",
            "Mapped allocation failure sets process-wide FZC_MAPPED_BROKEN and uses copy+sync; a reuse design must not silently retry a poisoned mapping or retain a buffer after context failure/uncertain stream completion.",
            "Host-tail packing allocates separate device d_pack and pinned PinBuf of k*half*2 words. Only the pinned host capacity is counted here; d_pack remains per-tail and is outside this lease census."
        ],
        "reuse_preconditions": [
            "Use one same-context sequential owner and keep each lease live through its final asynchronous writer/copy.",
            "Establish CUDA stream completion before returning or rebinding mapped/pinned storage; a mapped flag alone is insufficient.",
            "Reset the active mapped flag offset 2*(degree+1), and prevent stale or late seq=1 from satisfying the next attempt.",
            "Acquire fallback pinned capacity eagerly at constructor; preserve the mapped-failure fallback and process-wide broken flag.",
            "Quarantine/drop cached mapped and pinned resources after context poison, timeout with uncertain completion, or failed synchronization."
        ],
        "limitations": "Synthetic flag states demonstrate logical hazards only. No CUDA memory-model proof, context recovery test, or native failure injection was run."
    }
    REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"report": str(REPORT), "pinned_cpu": cpu, "checks": report["checks"], "counts": counts}, sort_keys=True))


if __name__ == "__main__":
    main()
