#!/bin/bash
# D60 review closure (2026-11-02): the RELEASE CLI beyond L = 1 / N = 1 (review F2), the F3 fail-closed rule on
# the release binary, and peak memory of D55 CLI proves and verifies (review F5). Usage: cli_close.sh <test binary>
#
# TEST RECEIPTS, NOT FOR PUBLICATION: every export here is written from the PUBLIC SYNTHETIC R13 loader fixture
# `r13-h24-wide` (each layer its layer 0; `seq_public` chained by the native builder) by the test binary's
# `run_fork_tests::d60_close_write_r13_multi_layer_test_export`; every D55 prove passes
# --d55-test-receipt-not-for-publication. Receipts outside the repository, under
# /Users/victorrielly/zk60-artifacts/d60_20261102/close/run-<timestamp>/.
#   E   the L = 3 export, and the F5 export: the longest admissible prefix (at most 32) of the repeated-layer
#       chain (one layer repeated, the residual stream grows until the norm's range refuses)
#   1   release stack-prove --d55-workers 3 WITHOUT the acknowledgement               -> 1, nothing created
#   2   release stack-prove --d55-workers 3 --d55-test-receipt-not-for-publication    -> 0, marker written
#   3   release stack-verify --d55-workers 3 (fresh process, verifier copy)           -> 0, published, marker reported
#   4   release stack-verify --d55-workers 1 / 2 / 64 on the published run            -> 0 each
#   5   CROSS-BINARY A: a copy of step 2's UNVERIFIED run verified and published by the TEST binary  -> 0
#   6   CROSS-BINARY B: the TEST binary proves an L = 3 receipt; the release CLI verifies + publishes -> 0
#   7   D12a at L = 3 on the release CLI: prove 0, verify 0; each verifier refuses the other's directory
#   8   tamper / file-system probes on copies of step 3's run (release, N = 3)       -> nonzero, no hang
#   9   one tamper under N = 1 and N = 3: the same refusal text
#   10  F5: peak memory (/usr/bin/time -l and the guard) of D55 prove (N = 6) and verify (N = 1, 6) and of D12a
#       prove / verify at the F5 L; and one public block's resident bytes at the rung and at Llama-3-8B T128
set -u
B=${1:?the test binary}
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2e328baa581cb5b0
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/close/cli
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
X=$R/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_trained_block
A=/Users/victorrielly/zk60-artifacts/d60_20261102/close/run-$(date +%Y%m%dT%H%M%S)
ACK=--d55-test-receipt-not-for-publication
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p $L
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/c_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done
[ -e "$A" ] && { echo "$A exists"; exit 1; }
mkdir -p $A
printf 'TEST RECEIPTS, NOT FOR PUBLICATION. Proved by results/zk60_d60_20261102/logs/close/cli_close.sh on exports written from the public synthetic R13 loader fixture r13-h24-wide (each layer its layer 0) and its public sequence; no real content. Every D55 run directory also carries D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt (D60 review F3).\n' > $A/TEST_RECEIPTS_NOT_FOR_PUBLICATION.txt
echo "artifacts: $A" | tee $L/c_artifacts.txt
shasum -a 256 $X $B | tee $L/c_binaries.sha256
step() { echo "== $1 $(date +%H:%M:%S)"; }
fail() { echo "FAIL: $*"; exit 1; }

# run_x <stem> <want: 0|1|nonzero> <binary: rel|test> <args...>
run_x() {
  local stem=$1 want=$2 which=$3; shift 3
  local cmd
  if [ "$which" = rel ]; then
    # /usr/bin/time -l: the child's exact maximum resident set size (getrusage), beside the guard's sampled peak
    cmd=(/usr/bin/time -l env HL_R13_LOADER_FIXTURES=$F $X "$@")
  else
    local w=0; [ "$want" != 0 ] && w=$want
    cmd=(env HL_R13_LOADER_FIXTURES=$F HL_D60_CLI_WANT=$w "HL_D60_CLI_ARGS=$*" $B --ignored --exact private_block::run::fork::tests::d60_close_cli_in_the_test_binary --nocapture --test-threads=1)
  fi
  $G --class cpu --need-gib 4 --cap-gib 40 --label d60close-cli-$stem --wait-secs 7200 --max-secs 1800 --log $L/c_$stem.log --done $L/c_$stem.done --result-json $L/c_$stem.guard.json -- "${cmd[@]}"
  local got; got=$(head -1 $L/c_$stem.done 2>/dev/null)
  local peak; peak=$(python3 -c 'import json,sys; print("guard_peak_rss=%sG" % json.load(open(sys.argv[1])).get("peak_rss_gib"))' $L/c_$stem.guard.json 2>/dev/null)
  local maxrss; maxrss=$(grep -h 'maximum resident set size' $L/c_$stem.log | awk '{printf "maxrss=%.1fMiB", $1/1048576}')
  local last; last=$(grep -h '"event"' $L/c_$stem.log | grep -v '"event":"guard' | tail -1 | cut -c1-300)
  echo "$stem [$which]: exit $got (want $want) $peak $maxrss | $last"
  if [ "$which" = test ]; then
    # the test asserts the command's exit itself; the test process exits 0 when it matched
    [ "$got" = 0 ] || fail "$stem: the test binary's command did not exit $want"
    return 0
  fi
  case $want in
    nonzero) [ -n "$got" ] && [ "$got" != 0 ] || fail "$stem exited $got, want nonzero" ;;
    *) [ "$got" = "$want" ] || fail "$stem exited $got, want $want" ;;
  esac
}

vcopy() { # <export> <verifier copy>: the export's PUBLIC files only (stack-verify refuses seq_*)
  mkdir -p $2; cp $1/profile.json $2/; for d in $1/layer_*; do cp -R $d $2/; done
}

step exports
$G --class cpu --need-gib 4 --cap-gib 20 --label d60close-export-l3 --wait-secs 7200 --max-secs 1800 --log $L/c_export_l3.log --done $L/c_export_l3.done -- \
  env HL_R13_LOADER_FIXTURES=$F HL_D60_EXPORT_DIR=$A/export-l3 HL_D60_EXPORT_L=3 $B --ignored --exact private_block::run::fork::tests::d60_close_write_r13_multi_layer_test_export --nocapture --test-threads=1
[ "$(cat $L/c_export_l3.done)" = 0 ] || fail "the L3 export"
grep -h "D60 F2 EXPORT" $L/c_export_l3.log
# the F5 export: the longest admissible prefix of the repeated-layer chain, at most 32 layers
$G --class cpu --need-gib 4 --cap-gib 20 --label d60close-export-big --wait-secs 7200 --max-secs 1800 --log $L/c_export_big.log --done $L/c_export_big.done -- \
  env HL_R13_LOADER_FIXTURES=$F HL_D60_EXPORT_DIR=$A/export-big HL_D60_EXPORT_L=32 HL_D60_EXPORT_UP_TO=1 $B --ignored --exact private_block::run::fork::tests::d60_close_write_r13_multi_layer_test_export --nocapture --test-threads=1
[ "$(cat $L/c_export_big.done)" = 0 ] || fail "the F5 export"
BIG=$(grep -h -o '| [0-9]* layers (each' $L/c_export_big.log | grep -o '[0-9]*' | head -1)
[ -n "$BIG" ] && [ "$BIG" -ge 4 ] || fail "the F5 export has fewer than 4 layers"
mv $A/export-big $A/export-l$BIG
echo "the F5 export: L = $BIG"; grep -h "D60 F2 EXPORT" $L/c_export_big.log
for n in 3 $BIG; do vcopy $A/export-l$n $A/verifier-l$n; done
E3=$A/export-l3; V3=$A/verifier-l3

step 1-refused-without-the-acknowledgement
run_x d55_l3_noack 1 rel stack-prove --export $E3 --seq public --out $A/d55-l3-noack --d55-workers 3
grep -q 'D60 review F3' $L/c_d55_l3_noack.log || fail "the refusal does not name D60 review F3"
[ -e $A/d55-l3-noack ] || [ -e $A/d55-l3-noack.unverified-statement ] && fail "the refused prover created something"
echo "nothing created"

step 2-prove-l3-n3
run_x d55_l3_prove 0 rel stack-prove --export $E3 --seq public --out $A/d55-l3 --d55-workers 3 $ACK
ID3=$(grep -h -o '"statement_identity":"[0-9a-f]*"' $L/c_d55_l3_prove.log | head -1 | cut -d'"' -f4)
[ -n "$ID3" ] || fail "no statement identity"
grep -q '"event":"d55-test-receipt","not_for_publication":true' $L/c_d55_l3_prove.log || fail "no d55-test-receipt event"
grep -q '"workers":3,"frames":5' $L/c_d55_l3_prove.log || fail "not an L3 N3 fork run (5 frames on 3 workers)"
ls -la $A/d55-l3 | tee $L/c_d55_l3_dir.txt
cmp -s $A/d55-l3/D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt /dev/null && fail "empty marker"
# the copy for cross-binary A, taken BEFORE any verification
cp -R $A/d55-l3 $A/xb-a; cp -R $A/d55-l3.unverified-statement $A/xb-a.unverified-statement

step 3-verify-l3-n3
run_x d55_l3_verify_n3 0 rel stack-verify --export $V3 --artifact $A/d55-l3 --expect-statement $ID3 --d55-workers 3
grep -q '"event":"statement-published"' $L/c_d55_l3_verify_n3.log || fail "not published"
grep -q '"event":"d55-publication","not_for_publication":true,"test_receipt_marker":"present"' $L/c_d55_l3_verify_n3.log || fail "the marker was not reported"
cp $A/d55-l3/statement/statement.json $L/c_d55_l3_statement.json; cp $A/d55-l3/statement/segments.json $L/c_d55_l3_segments.json

step 4-verify-l3-other-n
for n in 1 2 64; do
  run_x d55_l3_verify_n$n 0 rel stack-verify --export $V3 --artifact $A/d55-l3 --expect-statement $ID3 --d55-workers $n
  grep -q '"event":"statement-checked"' $L/c_d55_l3_verify_n$n.log || fail "N$n: the published statement was not checked"
done

step 5-cross-binary-a-test-binary-verifies-the-release-receipt
run_x xb_a_test_verify 0 test stack-verify --export $V3 --artifact $A/xb-a --expect-statement $ID3 --d55-workers 2
grep -q '"event":"statement-published"' $L/c_xb_a_test_verify.log || fail "the test binary did not publish the release receipt's statement"
cmp $A/xb-a/statement/statement.json $A/d55-l3/statement/statement.json || fail "the two binaries published different statements"
cmp $A/xb-a/statement/segments.json $A/d55-l3/statement/segments.json || fail "the two binaries hashed different bytes"
echo "the test binary published byte-identical statement.json and segments.json"

step 6-cross-binary-b-release-verifies-the-test-binary-receipt
run_x xb_b_test_prove 0 test stack-prove --export $E3 --seq public --out $A/xb-b --d55-workers 3 $ACK
run_x xb_b_rel_verify 0 rel stack-verify --export $V3 --artifact $A/xb-b --expect-statement $ID3 --d55-workers 3
grep -q '"event":"statement-published"' $L/c_xb_b_rel_verify.log || fail "the release CLI did not publish the test binary's receipt's statement"
grep -q '"test_receipt_marker":"present"' $L/c_xb_b_rel_verify.log || fail "the marker was not reported"

step 7-d12a-at-l3
run_x d12a_l3_prove 0 rel stack-prove --export $E3 --seq public --out $A/d12a-l3
run_x d12a_l3_verify 0 rel stack-verify --export $V3 --artifact $A/d12a-l3 --expect-statement $ID3
run_x d12a_on_d55_l3 1 rel stack-verify --export $V3 --artifact $A/d55-l3 --expect-statement $ID3
run_x d55_on_d12a_l3 1 rel stack-verify --export $V3 --artifact $A/d12a-l3 --expect-statement $ID3 --d55-workers 3

step 8-probes-l3
W=$A/probes
mkdir -p $W
fresh() { rm -rf "$W/$1"; cp -R $A/d55-l3 "$W/$1"; }
flip() { python3 -c 'import sys; p,o=sys.argv[1],int(sys.argv[2]); b=bytearray(open(p,"rb").read()); o=o if o>=0 else len(b)+o; b[o]^=1; open(p,"wb").write(bytes(b))' "$1" "$2"; }
mid() { python3 -c 'import os,sys; print(os.path.getsize(sys.argv[1])//2)' "$1"; }
probe() { # <name> <want> <dir> [N]
  run_x p_$1 $2 rel stack-verify --export $V3 --artifact $W/$3 --expect-statement $ID3 --d55-workers ${4:-3}
}
fresh fork1_body; flip $W/fork1_body/d55-fork-001.bin $(mid $W/fork1_body/d55-fork-001.bin); probe fork1_body nonzero fork1_body
fresh fork1_start; flip $W/fork1_start/d55-fork-001.bin 60; probe fork1_start_tag nonzero fork1_start
fresh fork2_end; flip $W/fork2_end/d55-fork-002.bin -1; probe fork2_end_tag nonzero fork2_end
fresh head_root0; flip $W/head_root0/d55-head.bin 48; probe head_root0 nonzero head_root0
fresh head_s0; flip $W/head_s0/d55-head.bin -1; probe head_s0_tag nonzero head_s0
fresh tail_b0; flip $W/tail_b0/d55-tail.bin 200000; probe tail_b0_opening nonzero tail_b0
fresh tail_s1; flip $W/tail_s1/d55-tail.bin 50; probe tail_s1_tag nonzero tail_s1
fresh swap02; mv $W/swap02/d55-fork-000.bin $W/swap02/t; mv $W/swap02/d55-fork-002.bin $W/swap02/d55-fork-000.bin; mv $W/swap02/t $W/swap02/d55-fork-002.bin; probe forks_0_2_swapped_same_block nonzero swap02
fresh swap01; mv $W/swap01/d55-fork-000.bin $W/swap01/t; mv $W/swap01/d55-fork-001.bin $W/swap01/d55-fork-000.bin; mv $W/swap01/t $W/swap01/d55-fork-001.bin; probe forks_0_1_swapped nonzero swap01
fresh fifo; rm $W/fifo/d55-fork-001.bin; mkfifo $W/fifo/d55-fork-001.bin; probe fifo_fork1 nonzero fifo
fresh link; mv $W/link/d55-fork-001.bin $W/link-target.bin; ln -s $W/link-target.bin $W/link/d55-fork-001.bin; probe symlink_fork1 nonzero link
fresh marker_gone; rm $W/marker_gone/D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt; probe marker_removed 0 marker_gone
grep -q '"test_receipt_marker":"ABSENT"' $L/c_p_marker_removed.log || fail "a removed marker was not reported ABSENT"
fresh marker_other; flip $W/marker_other/D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt 3; probe marker_other_content nonzero marker_other
fresh extra; echo hi > $W/extra/notes.txt; probe extra_file nonzero extra
# the same-block swap is refused by the chain (the fork index), not by a digest: all three layers are one block
grep -h '"event":"rejected"' $L/c_p_forks_0_2_swapped_same_block.log | cut -c1-300

step 9-n-independence
probe fork1_body_n1 nonzero fork1_body 1
a=$(grep -h '"event":"rejected"' $L/c_p_fork1_body.log); b=$(grep -h '"event":"rejected"' $L/c_p_fork1_body_n1.log)
[ -n "$a" ] && [ "$a" = "$b" ] || fail "the N = 1 and N = 3 refusals differ: $a / $b"
echo "N = 1 and N = 3 give the same refusal: $(echo $a | cut -c1-200)"

step 10-memory-at-l$BIG
EB=$A/export-l$BIG; VB=$A/verifier-l$BIG
run_x mem_d55_prove_l${BIG}_n6 0 rel stack-prove --export $EB --seq public --out $A/d55-l$BIG --d55-workers 6 $ACK
IDB=$(grep -h -o '"statement_identity":"[0-9a-f]*"' $L/c_mem_d55_prove_l${BIG}_n6.log | head -1 | cut -d'"' -f4)
cp -R $A/d55-l$BIG $A/d55-l$BIG-n1; cp -R $A/d55-l$BIG.unverified-statement $A/d55-l$BIG-n1.unverified-statement
run_x mem_d55_verify_l${BIG}_n6 0 rel stack-verify --export $VB --artifact $A/d55-l$BIG --expect-statement $IDB --d55-workers 6
run_x mem_d55_verify_l${BIG}_n1 0 rel stack-verify --export $VB --artifact $A/d55-l$BIG-n1 --expect-statement $IDB --d55-workers 1
run_x mem_d12a_prove_l$BIG 0 rel stack-prove --export $EB --seq public --out $A/d12a-l$BIG
run_x mem_d12a_verify_l$BIG 0 rel stack-verify --export $VB --artifact $A/d12a-l$BIG --expect-statement $IDB
# the other half: one public block's resident bytes at the rung and at Llama-3-8B T128 (what load_fork_blocks
# holds L of on every D55 CLI path; D12a's BlockCache holds one)
$G --class cpu --need-gib 8 --cap-gib 40 --label d60close-f5-block --wait-secs 7200 --max-secs 1800 --log $L/c_f5_block.log --done $L/c_f5_block.done --result-json $L/c_f5_block.guard.json -- \
  env HL_D60_F5_PROFILES=R13_RUNG_H24,R13_8B_T128_H24 $B --ignored --exact private_block::run::fork::tests::d60_close_f5_resident_bytes_of_one_public_block --nocapture --test-threads=1
[ "$(cat $L/c_f5_block.done)" = 0 ] || fail "the F5 block-size probe"
{
  echo "peak memory of the release CLI on R13 rung h24 (T32, width 384) exports, public synthetic, CPU path:"
  echo "maxrss = /usr/bin/time -l's maximum resident set size (exact, getrusage); guard = the guard's peak_rss (sampled every 0.5 s)"
  for s in d55_l3_prove d55_l3_verify_n3 d55_l3_verify_n1 d12a_l3_prove d12a_l3_verify mem_d55_prove_l${BIG}_n6 mem_d55_verify_l${BIG}_n6 mem_d55_verify_l${BIG}_n1 mem_d12a_prove_l$BIG mem_d12a_verify_l$BIG; do
    printf '%-26s %s %s %s | %s\n' "$s" \
      "$(grep -h 'maximum resident set size' $L/c_$s.log | awk '{printf "maxrss %.1f MiB", $1/1048576}')" \
      "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("guard %sG wall %.1fs" % (d.get("peak_rss_gib"), d.get("child_wall_seconds") or 0))' $L/c_$s.guard.json)" \
      "$(grep -h -o '"block_load_seconds":[0-9.]*' $L/c_$s.log | tail -1)" \
      "$(grep -h -o '"receipt_bytes":[0-9]*' $L/c_$s.log | tail -1)"
  done
  grep -h -o "D60 F5 BLOCK.*" $L/c_f5_block.log
} | tee $L/c_mem_summary.txt
du -sh $A/d55-l$BIG $A/d12a-l$BIG | tee -a $L/c_mem_summary.txt
step done
