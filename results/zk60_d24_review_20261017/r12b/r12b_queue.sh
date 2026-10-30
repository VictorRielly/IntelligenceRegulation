#!/bin/bash
# D24 review round 11 (R12b fix check, tree 51de5b83): serial guarded queue.
# Lean-memory rule (coordinator 22:58Z): no job here declares >= 3 GiB; the
# goldens / dense proofs are NOT rerun (Sol's evidence applies: his working
# tree equals the frozen manifest, 229/229). Read only on every other lane's
# tree; retained run dirs hold statement/: byte check only.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r12b
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r12b-scratch
S9=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
S8=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r12b.release.bin
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
A=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/dg_r12b_t256
FX=$S/fixture
Z=0000000000000000000000000000000000000000000000000000000000000000
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "queue start"
# ---- the scratch test build (review modules registered in my copy only)
guard build 2.3 4 3600 rv12b-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run
[ "$(cat $R/rv12b-test-build.done)" = 0 ] || { echo testbuild-fail > $R/r12b_queue.done; exit 1; }
BIN=$S/hashline/$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/rv12b-test-build.log | tail -1)
sha256sum $BIN > $R/test-binary.sha256
log "lib test binary: $BIN"
mkdir -p $S/review_tmp/review $S/review_tmp/port $S/review_tmp/author $S/review_out
# ---- my new R12b attack tests (non-ignored) and the R12 port
guard cpu 1.0 3 1800 rv12b-review-new /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/review RAYON_NUM_THREADS=8 $BIN --test-threads=1 --nocapture review_r12b_
guard cpu 1.0 3 1800 rv12b-review-r12port /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/port RAYON_NUM_THREADS=8 $BIN --test-threads=1 --nocapture review_r12_
# ---- F1 against my own honest fixture (full checkpoint passes; bounded memory)
guard cpu 0.6 2 1800 rv12b-f1 /usr/bin/env ZK60_REVIEW_R12B_FIXTURE=$FX RAYON_NUM_THREADS=8 $BIN --ignored --test-threads=1 --nocapture review_r12b_f1
guard cpu 0.6 2 1800 rv12b-sol-tied /usr/bin/env ZK60_R12B_TIED_FIXTURE=$FX RAYON_NUM_THREADS=8 $BIN --ignored --test-threads=1 --nocapture pinned_tied_tables_accept_honest_and_refuse_rehashed_forgery
sha256sum $FX/profile.json $FX/rotation_sign.bin $FX/token_io/* > $R/fixture.sha256
# ---- the author's tests on my binary (non-ignored subset)
guard cpu 1.5 4 3600 rv12b-author-subset /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $BIN --test-threads=4 r12_tests r12b_tests tied_tables r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests hash_domain pad::tests cs_port_tests --skip review_r
# ---- my CLI on Astra's actual R12b export (read only; the artifact never exists)
guard cpu 1.0 3 900 rv12b-cli-real-load /usr/bin/env RAYON_NUM_THREADS=8 $X verify --export $A --layer 0 --artifact $S/review_out/none --expect-statement $Z
guard cpu 1.0 3 900 rv12b-cli-f3-verify /usr/bin/env RAYON_NUM_THREADS=8 $X verify --export $A --layer 0 --artifact $S/review_out/none --expect-statement $Z --rope-from-export
guard cpu 1.0 3 900 rv12b-cli-f3-verify-dd /usr/bin/env RAYON_NUM_THREADS=8 $X verify --export $A --layer 0 --artifact $S/review_out/none --expect-statement $Z --rope-from-export --dd
guard cpu 1.0 3 900 rv12b-cli-f3-stack /usr/bin/env RAYON_NUM_THREADS=8 $X stack-verify --export $A --artifact $S/review_out/none --expect-statement $Z --rope-from-export
log "review_out after CLI checks: $(ls -A $S/review_out | tr '\n' ' ')"
# ---- retained receipts under my R12b CLI (statement/ exists: byte check only)
guard cpu 1.2 3 1800 rv12b-compat-tl-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --dd
guard cpu 2.5 4 2400 rv12b-compat-8b-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --dd
guard cpu 1.0 3 1800 rv12b-compat-tl /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
guard cpu 2.5 4 2400 rv12b-compat-8b /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
guard cpu 1.0 3 1800 rv12b-compat-tl-t32 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S8/verifier-tl-T32 --artifact $N/r6/compat-pg_rot1_b4_T32_cal128/run --expect-statement $(grep -o '"trained_statement_identity": "[0-9a-f]*"' $N/r6/compat-pg_rot1_b4_T32_cal128/run/statement/statement.json | cut -d'"' -f4)
log "queue end"
echo done > $R/r12b_queue.done
