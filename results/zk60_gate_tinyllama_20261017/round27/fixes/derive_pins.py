"""FR25-05 / FR25-02 evidence (read-only): derive the registered D55 writer's
expected pin list from `run_capture.rs` AT A GIVEN SHA-256 (the bytes are
hashed before they are parsed), compare it with every D55 bundle manifest
under the given directories, and hash the s25 printout and `s25_tests.rs`.

    python3 -B derive_pins.py <run_capture.rs> <printout> <s25_tests.rs> <bundle root> [<bundle root> ...]

Writes nothing.  Prints the 75 names as a Python tuple (for the gate's
constant) and one line per bundle."""
import hashlib
import json
import os
import re
import sys

RC_SHA = "10b6d3be860c73cd257e4b6b040b0351f10b993d8b1d1fdb5775057b71ef21c7"


def const_list(src: str, name: str) -> list:
    m = re.search(r"pub\(super\) const " + name + r": \[&str; (\d+)\] = \[(.*?)\n\];", src, re.S)
    if m is None:
        raise SystemExit(f"{name}: not found")
    body = "\n".join(line.split("//", 1)[0] for line in m.group(2).splitlines())
    items = re.findall(r'"([^"]+)"', body)
    if len(items) != int(m.group(1)):
        raise SystemExit(f"{name}: {len(items)} items, declared {m.group(1)}")
    return items


rc, printout, s25 = sys.argv[1:4]
raw = open(rc, "rb").read()
got = hashlib.sha256(raw).hexdigest()
print("run_capture.rs sha256", got, "== 10b6d3be..:", got == RC_SHA)
if got != RC_SHA:
    raise SystemExit("not the read digest")
src = raw.decode()
own, shared = const_list(src, "OWN_SOURCE_FILES"), const_list(src, "SHARED_SOURCE_FILES")
names = own + shared
print("OWN", len(own), "SHARED", len(shared), "total", len(names), "distinct", len(set(names)))
print("REGISTERED_WRITER_PINS = (")
for n in names:
    print(f"    {n!r},")
print(")")
for p in (printout, s25):
    print(os.path.basename(p), hashlib.sha256(open(p, "rb").read()).hexdigest(), os.path.getsize(p))
TEST_EXTRA = ("src/private_block/run_fork.rs", "src/private_block/run_fork_wire.rs", "src/private_block/w16_privacy_gate_tests.rs")
for root in sys.argv[4:]:
    for dirpath, _dirs, files in sorted(os.walk(root)):
        if "manifest.json" not in files or "run.json" not in files:
            continue
        man = json.load(open(os.path.join(dirpath, "manifest.json")))
        if not str(man.get("schema", "")).startswith("hashline-native-capture/8-d55"):
            continue
        pins = [x["file"] for x in man.get("source_pins", [])]
        w = man.get("writer")
        want = set(names) | (set(TEST_EXTRA) if "test-only" in str(w) else set())
        print(f"{os.path.relpath(dirpath, root)}: writer={w!r} pins={len(pins)} distinct={len(set(pins))} "
              f"missing={sorted(want - set(pins))} extra={sorted(set(pins) - want)} proved_on_gpu={man.get('proved_on_gpu', 'ABSENT')}")
