#!/bin/bash
# NATIVE LANE R6 item 1, the fidelity-improved run: wait (detached, no lock
# held) until (1) the R6 CPU CLI exists (r6/cli-build.done = 0) and (2) the
# calibration lane has VERIFIED llama3_8b_pg_rot1_b7_T128: a
# logs/*verify*llama3_8b_pg_rot1_b7_T128*.done holding 0 whose .log ends
# with "errors": [] and "ok": true. Then sanity-check the per-layer format
# (sh_s null + listed per layer; layer_01 sh_s 7) and run r6_stack.sh on it
# (8B T128: need 7.5 / cap 10.5, witness cache 0, verify needs 3 GiB).
# Gives up after 8 h. Never starts on a half-written export.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
C=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
V=llama3_8b_pg_rot1_b7_T128
E=$C/export/$V
t0=$(date +%s)
ready() {
  [ "$(cat $D/r6/cli-build.done 2>/dev/null)" = 0 ] || return 1
  [ -x $D/r6/zk60_trained_block.release.bin ] || return 1
  for f in $C/logs/*verify*${V}*.done; do
    [ -f "$f" ] || continue
    [ "$(cat "$f")" = 0 ] || continue
    l="${f%.done}.log"
    [ -f "$l" ] && tail -c 400 "$l" | grep -q '"errors": \[\]' && tail -c 400 "$l" | grep -q '"ok": true' && { echo "verified marker $f"; return 0; }
  done
  return 1
}
until ready; do
  [ $(( $(date +%s) - t0 )) -lt 28800 ] || { echo "gave up after 8 h at $(date -u +%H:%M:%S)"; exit 3; }
  sleep 60
done
echo "ready at $(date -u +%H:%M:%S)"
python3 - "$E" <<'PY' || exit 4
import json, os, sys
e = sys.argv[1]
p = json.load(open(os.path.join(e, "profile.json")))
assert p["profile_constants"]["sh_s"] is None, "profile sh_s is not null"
assert "sh_s" in p["per_layer_constants_differ"], "sh_s is not listed per layer"
n = len(p["layers"]) if isinstance(p["layers"], list) else int(p["layers"])
v = {i: json.load(open(os.path.join(e, f"layer_{i:02d}", "manifest.json")))["constants"]["sh_s"] for i in range(n)}
print("per-layer sh_s:", {k: x for k, x in v.items() if x != v[0]}, "base", max(set(v.values()), key=list(v.values()).count))
assert v[1] == 7, f"layer 1 sh_s is {v[1]}"
PY
SEQ=$(ls -d $E/seq_* 2>/dev/null | head -1 | xargs -n1 basename | sed 's/^seq_//')
[ -n "$SEQ" ] || { echo "no seq_* in $E"; exit 5; }
echo "sequence $SEQ"
VNEED=3 VCAP=8 $D/r6_stack.sh $E $SEQ 7.5 10.5 0
echo "b7 stack script exit $?"
