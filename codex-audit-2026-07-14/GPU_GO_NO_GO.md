# GPU readiness decision

## Outcome

**No-go for a GPU proof backend as the next integration milestone.**

**Conditional go for isolated kernel research:** it is reasonable to preserve
the packed q31 arithmetic, commitment kernels, and CPU differential oracle as
inputs to small experimental GPU kernels. Such work should remain behind a
research interface and must not be described as accelerating a secure FFN
proof until the protocol gates below close.

## Why GPU work is premature

### The current bottlenecks are protocol data, not only arithmetic

At the measured `2^20` shape, the current ct proof contains 88,247 ordinary
openings across 670 waves. The `z` and `w1` arrays alone are approximately 2.86
GiB under their current fixed-width types. A GPU can produce those responses
faster; it cannot make them fit a 256 KiB proof or remove verifier/network
work. Aggregation must change the protocol shape first.

### Security semantics are still moving

The optimized ARP parameter lacks a negligible ZK bound, multi-wave partials
introduce an unanalyzed privacy channel, the exact range relation is not in the
public Statement, and the proof parser/verifier boundary does not exist. A GPU
ABI built now would freeze layouts that need redesign.

### The benchmark is not the target computation

The current U-R rig proves a lookup/range/Hadamard fragment with internally
generated inputs. It excludes three FFN matmuls, requantization, residuals,
attention, normalization, model binding, witness inference, and serialization.
Its measured CPU rate already projects to roughly 54 minutes proving one
`512 x 11008` activation fragment. Stacked assumed thread/GPU multipliers do
not bridge that evidence gap.

### Zero knowledge cannot be recovered by faster execution

An invalid rejection bound and leaked partition measurements remain invalid at
any throughput. Those properties must be fixed and analyzed on the CPU
reference before translating the same transcript to another device.

## Mandatory gates

| Gate | Required evidence | Current status |
|---|---|---|
| Rejection/range ZK | Exact lookup replacement or rejection parameters with negligible proved defect and checked preconditions | **Fail** |
| Multi-wave privacy | Full simulator plus rank/recovery battery for all partial/share data | **Fail** |
| Independent verifier | Expected statement supplied separately; canonical proof bytes; all commitment/mask pins checked | **Fail** |
| Proof byte budget | Complete encoded artifact <=256 KiB, including every wave/opening | **Fail by orders** |
| Statement semantics | Typed multi-table range encoding and model digest; validated boundary repository-wide | **Fail** |
| Complete FFN unit | Caller-supplied 3-matmul FFN with rescale/range/activation/residual/output binding | **Fail** |
| CPU economics | Measured complete-unit cost with no modeled-away component and credible accelerator work ratio | **Fail** |
| Stable arithmetic ABI | Exact bounds, canonical residues, portable/scalar differential, overflow/property tests | **Partial** |
| GPU evidence | Named device/driver; bit identity; transfer-inclusive p50/p95; memory and power | **Not started** |

## Safe GPU work before those gates close

The following bounded research can proceed without treating the protocol as
frozen:

1. Build a standalone packed-field/NTT/commitment microkernel with no proof
   semantics in its API.
2. Differential-test every output against the scalar CPU oracle, including
   `0`, `1`, `q-1`, reduction boundaries, maximum safe accumulation, and tail
   lengths.
3. Measure host/device transfer and allocation explicitly; never infer it from
   a compute-only multiplier.
4. Keep transcript hashing, randomness, proof layout, and range/lookup
   composition on the CPU until their specifications are stable.
5. Treat the experiment as disposable: it must not constrain the aggregation
   or canonical proof design.

## Go criterion

Start integrated GPU backend work only when a fresh-process CPU reference can
verify one complete FFN-layer proof, the artifact is canonically serialized
and within its byte budget, the ZK simulator covers the entire transcript, and
the remaining prover work has a measured arithmetic profile suited to the
device. At that point, port one kernel at a time with bit-exact differential
tests and report end-to-end p50/p95 rather than multiplied assumptions.
