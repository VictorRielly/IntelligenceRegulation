#!/usr/bin/env python3
"""Build the test binary, run the trained accuracy test with several warm passes
under the guard, and `sample` the test process once its cold pass has printed.
Detached use: python3 profile_warm.py <out_dir>; writes <out_dir>/profile.done."""
import os, subprocess, sys, time

OUT = sys.argv[1]
REPO = "/Users/victorrielly/IntelligenceRegulation"
GUARD = f"{REPO}/scripts/zk60_resource_guard.py"
MAN = f"{REPO}/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml"
B = f"{REPO}/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
os.makedirs(OUT, exist_ok=True)
log = f"{OUT}/test.log"
status = []

def done(code):
    open(f"{OUT}/profile.done", "w").write(f"{code}\n" + "\n".join(status) + "\n")
    sys.exit(0)

r = subprocess.run(["python3", GUARD, "run", "--class", "build", "--need-gib", "4", "--cap-gib", "10", "--label", "m4i-profile-build",
                    "--wait-secs", "3600", "--max-secs", "3600", "--log", f"{OUT}/build.log", "--done", f"{OUT}/build.done", "--",
                    "cargo", "test", "--release", "--features", "gpu-metal", "--manifest-path", MAN, "--lib", "--no-run"])
status.append(f"build {r.returncode}")
if r.returncode != 0:
    done(1)
env = dict(os.environ, HL_GPU_REQUIRED="1", HL_M4_PROFILES="R13_SHIELD_T128_H24", HL_M4_WARM_PASSES="8")
test = subprocess.Popen(["python3", GUARD, "run", "--class", "gpu", "--need-gib", "60", "--cap-gib", "160", "--label", "m4i-profile-run",
                         "--wait-secs", "3600", "--max-secs", "1800", "--log", log, "--done", f"{OUT}/test.done", "--",
                         B, "--ignored", "--exact", "--nocapture", "--test-threads=1",
                         "private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times"], env=env)
# wait for the cold pass, then find the test process and sample it
t0 = time.time()
while time.time() - t0 < 900:
    if os.path.exists(log) and "metal-cold" in open(log, errors="replace").read():
        break
    if test.poll() is not None:
        break
    time.sleep(0.2)
pid = subprocess.run(["pgrep", "-f", f"{os.path.basename(B)} --ignored"], capture_output=True, text=True).stdout.split()
status.append(f"pids {pid}")
if pid:
    s = subprocess.run(["sample", pid[-1], "6", "-mayDie", "-file", f"{OUT}/sample.txt"], capture_output=True, text=True)
    status.append(f"sample {s.returncode} {s.stderr[-300:]}")
test.wait()
status.append(f"test {test.returncode}")
done(0)
