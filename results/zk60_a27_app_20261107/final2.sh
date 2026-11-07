#!/bin/bash
# Lane A27, job final2 (one guarded gpu-class job): the second kernel round (HL_A27_NTT4: the fused NTT's head
# and tail two stages per pass). The native acceptance again on this tree (accept.sh t2, FULL=1); the CLI kept
# as zk60_classify.a27-c2; the byte identity on the real export (bi2: A26's pin, c2, c2 with every A27 switch off);
# the post-change trace of one post's proofs (p3solo); then the 8-post stream A/B pairs, A26 as shipped against
# c2 (m4.plan).
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247/results/zk60_a27_app_20261107
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin
P=$R/final2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start at $(git -C $WT rev-parse --short HEAD 2>/dev/null) (+ the working tree); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
env FULL=1 /bin/bash $R/accept.sh t2
say "accept rc=$? ($(grep -c 'rc=0' $R/accept_t2.progress) steps rc=0; $(grep -cE 'MISSING|rc=[1-9]' $R/accept_t2.progress) problems)"
if grep -qE "MISSING|test build rc=[1-9]|release CLI rc=[1-9]" $R/accept_t2.progress; then say "STOP: a gate failed"; exit 2; fi
cp $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify $BIN/zk60_classify.a27-c2
say "candidate a27-c2 sha256 $(shasum -a 256 $BIN/zk60_classify.a27-c2 | cut -d' ' -f1)"
/bin/bash $R/bi2.sh bi2 $BIN/zk60_classify.a27-c2
say "bi2 done: $(tail -1 $R/byteid_bi2.out | cut -c1-600)"
free=$(df -g /Users/victorrielly | tail -1 | awk '{print $4}')
if [ "$free" -lt 40 ]; then say "STOP: free disk $free GiB under 40"; exit 3; fi
/bin/bash $R/runs.sh p3 $R/p3.plan
say "p3 done"
/bin/bash $R/runs.sh m4 $R/m4.plan
say "m4 done"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
