#!/bin/bash
# D24 review r9: `--dd` at geometries with no DD profile, on all four CLI
# commands; each must exit 1 with the D30 refusal and create no output dir.
set -u
X=$1
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
S8=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8-scratch
P=$S/review_out/probes
# a well-formed pin (the verifier checks its form before anything else)
PIN=0000000000000000000000000000000000000000000000000000000000000000
mkdir -p $P
n=0; bad=0
for E in $S8/verifier-tl-T32 $S8/verifier-8b-T32 $S/verifier-8b-b7-T64; do
  b=$(basename $E)
  for cmd in prove verify stack-prove stack-verify; do
    out=$P/$b-$cmd
    rm -rf $out
    case $cmd in
      prove) a=(prove --export $E --layer 0 --seq ho00 --out $out --dd) ;;
      verify) a=(verify --export $E --layer 0 --artifact $out --expect-statement $PIN --dd) ;;
      stack-prove) a=(stack-prove --export $E --seq ho00 --out $out --dd) ;;
      stack-verify) a=(stack-verify --export $E --artifact $out --expect-statement $PIN --dd) ;;
    esac
    o=$($X "${a[@]}" 2>&1); rc=$?
    m=$(echo "$o" | grep -o 'DD (D30) is registered only[^"]*' | head -1)
    ex=no; [ -e $out ] && ex=yes
    n=$((n+1))
    if [ $rc = 1 ] && [ -n "$m" ] && [ $ex = no ]; then st=OK; else st=BAD; bad=$((bad+1)); fi
    echo "probe $b $cmd exit=$rc dir=$ex $st :: ${m:-$(echo "$o" | tail -1 | cut -c1-200)}"
  done
done
echo "probes $n bad $bad"
[ $bad = 0 ]
