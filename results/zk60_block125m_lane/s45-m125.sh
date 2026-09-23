#!/usr/bin/env bash
# Stage 45: the two 125M standalone block bundles, each followed by its
# FRESH-PROCESS re-verify. Every step takes the heavy lock on its own, so no
# two heavy runs overlap; each writes its own log and `.done` marker (exit
# code). Launched detached (setsid nohup) so it survives the session.
BIN=/home/victor/wt-zk60-block125m/hashline/target/release/deps/hashline-acaf18f42f87b555
LOGS=/home/victor/wt-zk60-block125m/results/zk60_block125m_lane
OUT=/home/victor/zk60-artifacts/block-captures-20260923
COMMIT=19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c
mkdir -p "$OUT"
for W in dense zero; do
  flock /tmp/zk-heavy.lock env MALLOC_MMAP_THRESHOLD_=131072 HL_BLOCK_CAPTURE_SHAPE=m125 HL_PB_INPUT=$W HL_BLOCK_CAPTURE_DIR=$OUT/m125-$W HL_TEST_SOURCE_COMMIT=$COMMIT /usr/bin/time -v "$BIN" --ignored --exact --nocapture --test-threads=1 private_block::block_capture_shaped_tests::write_a_shaped_block_bundle >> "$LOGS/s45-m125-$W-write.log" 2>&1
  echo $? > "$LOGS/s45-m125-$W-write.done"
  flock /tmp/zk-heavy.lock env MALLOC_MMAP_THRESHOLD_=131072 HL_BLOCK_CAPTURE_BUNDLE=$OUT/m125-$W /usr/bin/time -v "$BIN" --ignored --exact --nocapture --test-threads=1 private_block::block_capture_shaped_tests::reverify_a_shaped_block_bundle >> "$LOGS/s45-m125-$W-reverify.log" 2>&1
  echo $? > "$LOGS/s45-m125-$W-reverify.done"
done
