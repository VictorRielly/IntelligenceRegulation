#!/bin/bash
# D60 review probes: the RELEASE CLI (zk60_trained_block, built by the builder's cli_receipts.sh) against
# mutated copies of the builder's L = 1 TEST receipt (public synthetic fixture r13-h24-wide; not for
# publication). Each probe is a guarded LIGHT job (a 16 MB rung receipt verifies in ~0.2 s).
set -u
X=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a13712d1ade4dcee1/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_trained_block
SRC=/Users/victorrielly/zk60-artifacts/d60_20261102/cli/d55-run
EXP=/Users/victorrielly/zk60-artifacts/d60_20261102/cli/verifier-export
ID=6ac6d19087ee02ba9f87bcc6f772404b23726c293dd213b04d7392dc7f519b5b
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/d60_probes
L=/Users/victorrielly/IntelligenceRegulation/results/zk60_d60_20261102/review_logs
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p "$L" "$W"
shasum -a 256 "$X" | tee "$L/probe_binary.sha256"
SUMMARY="$L/probe_summary.txt"
: > "$SUMMARY"

fresh() { rm -rf "$W/$1"; cp -R "$SRC" "$W/$1"; }
flip() { python3 -c 'import sys; p,o=sys.argv[1],int(sys.argv[2]); b=bytearray(open(p,"rb").read()); o=o if o>=0 else len(b)+o; b[o]^=1; open(p,"wb").write(bytes(b))' "$1" "$2"; }

probe() { # <name> <want: 0|nonzero> <dir> <extra args...>
  local name=$1 want=$2 dir=$3; shift 3
  $G --class light --label d60-review-$name --wait-secs 600 --max-secs 120 --log "$L/p_$name.log" --done "$L/p_$name.done" -- \
    "$X" stack-verify --export "$EXP" --artifact "$W/$dir" --expect-statement "$ID" "$@"
  local got; got=$(head -1 "$L/p_$name.done" 2>/dev/null)
  local last; last=$(grep -v '^\s*$' "$L/p_$name.log" | grep -v '^{"event":"guard' | tail -1 | cut -c1-260)
  local ok=FAIL
  if [ "$want" = "0" ] && [ "$got" = "0" ]; then ok=ok; fi
  if [ "$want" = "nonzero" ] && [ -n "$got" ] && [ "$got" != "0" ]; then ok=ok; fi
  printf '%-34s exit %-4s want %-8s %s | %s\n' "$name" "$got" "$want" "$ok" "$last" | tee -a "$SUMMARY"
}

# honest copies: N = 1, 3, 64 (clamped to L = 1)
fresh honest; probe honest_n1 0 honest --d55-workers 1
probe honest_n3 0 honest --d55-workers 3
probe honest_n64 0 honest --d55-workers 64
probe n0_refused nonzero honest --d55-workers 0
probe n65_refused nonzero honest --d55-workers 65
probe nonint_refused nonzero honest --d55-workers 2x
probe controls_refused nonzero honest --d55-workers 1 --controls
probe d12a_verifier_on_d55 nonzero honest
# tampered frames
fresh fork_mid; flip "$W/fork_mid/d55-fork-000.bin" 7000000; probe fork_mid_byte nonzero fork_mid --d55-workers 1
fresh fork_end; flip "$W/fork_end/d55-fork-000.bin" -1; probe fork_end_tag_byte nonzero fork_end --d55-workers 1
fresh fork_start; flip "$W/fork_start/d55-fork-000.bin" 60; probe fork_start_tag_byte nonzero fork_start --d55-workers 1
fresh head_s0; flip "$W/head_s0/d55-head.bin" -1; probe head_s0_byte nonzero head_s0 --d55-workers 1
fresh tail_mid; flip "$W/tail_mid/d55-tail.bin" 700000; probe tail_mid_byte nonzero tail_mid --d55-workers 1
fresh tail_s1; flip "$W/tail_s1/d55-tail.bin" 50; probe tail_s1_byte nonzero tail_s1 --d55-workers 1
# file-system shapes
fresh fifo; rm "$W/fifo/d55-fork-000.bin"; mkfifo "$W/fifo/d55-fork-000.bin"; probe fifo_frame nonzero fifo --d55-workers 1
fresh link; mv "$W/link/d55-fork-000.bin" "$W/link-target.bin"; ln -s "$W/link-target.bin" "$W/link/d55-fork-000.bin"; probe symlink_frame nonzero link --d55-workers 1
fresh extra; echo hi > "$W/extra/notes.txt"; probe extra_file nonzero extra --d55-workers 1
fresh partial; cp "$W/partial/d55-tail.bin" "$W/partial/d55-tail.bin.partial"; probe partial_file nonzero partial --d55-workers 1
fresh short; python3 -c 'import sys; p=sys.argv[1]; b=open(p,"rb").read(); open(p,"wb").write(b[:-1])' "$W/short/d55-fork-000.bin"; probe short_frame nonzero short --d55-workers 1
fresh long; printf 'x' >> "$W/long/d55-fork-000.bin"; probe long_frame nonzero long --d55-workers 1
fresh renamed; mv "$W/renamed/d55-fork-000.bin" "$W/renamed/d55-fork-001.bin"; probe wrong_fork_name nonzero renamed --d55-workers 1
fresh stmtfile; rm -rf "$W/stmtfile/statement"; echo x > "$W/stmtfile/statement"; probe statement_is_a_file nonzero stmtfile --d55-workers 1
# a statement.json that names the BASE as run_profile (a D12a rendering) beside D55 frames
fresh stmtd12a; python3 -c '
import sys,re
p=sys.argv[1]; s=open(p).read()
s2=re.sub(r"\"run_profile\": \"[^\"]*\",\n \"base_run_profile\": (\"[^\"]*\"),\n \"run_construction\": \"[^\"]*\"", r"\"run_profile\": \1", s)
assert s2!=s; open(p,"w").write(s2)' "$W/stmtd12a/statement/statement.json"; probe statement_d12a_rendering nonzero stmtd12a --d55-workers 1
echo "== done"; cat "$SUMMARY"
