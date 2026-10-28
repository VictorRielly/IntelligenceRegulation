# Shieldstral category benchmarks

Both policies are measured on the same examples. Moderate wording has slightly higher sexual-category F1, while strict wording has slightly higher violence and hate/harassment F1 in this sample. The differences are small and do not establish a general winner. The table below supports Victor’s product-policy choice; thresholds remain margin > 0. No integer fidelity, proof or privacy acceptance follows from these float benchmarks.

Report generated at 2026-10-28T21:10:30Z from retained MEASURED float benchmark results (completed 2026-10-26). Fixed pinned Shieldstral float reference; n=1, shared box.

## OpenAI Moderation: per-category ground truth

612 stratified examples with content ≤168 tokens: all eligible unsafe examples plus 300 sampled safe examples. Precision, recall and F1 use the stored importance weights. Missing category labels count as zero in the main columns. “Known F1” instead restricts negatives to examples with at least one known label in that category group; it does not make all missing annotations known.

| Category | Policy | Precision | Recall | F1 | Known F1 | Median abs margin | Count abs margin <1 |
|---|---|---:|---:|---:|---:|---:|---:|
| sexual | strict | 0.597 | 0.974 | 0.740 | 0.811 | 10.07 | 14 /612 |
| sexual | moderate | 0.612 | 0.974 | 0.752 | 0.824 | 10.07 | 15 /612 |
| violence | strict | 0.600 | 0.763 | 0.672 | 0.676 | 10.01 | 19 /612 |
| violence | moderate | 0.586 | 0.776 | 0.668 | 0.671 | 10.04 | 21 /612 |
| hate | strict | 0.447 | 0.798 | 0.573 | 0.574 | 5.20 | 46 /612 |
| hate | moderate | 0.431 | 0.803 | 0.561 | 0.563 | 5.09 | 47 /612 |

Margin quantiles are unweighted sample summaries. Full signed positive/negative quantiles, weighted near-boundary shares and bootstrap F1 intervals are in `bench/metrics_categories.json`. Near-zero float margins identify sensitivity candidates; integer error has not been measured yet.

## ToxicChat-200: broad toxicity proxy

ToxicChat does not provide ground truth for these three separate categories. The per-category scores below compare each verdict with broad toxicity and must not be read as category accuracy.

| Query | Policy | Precision vs toxicity | Recall vs toxicity | F1 vs toxicity | Flag fraction |
|---|---|---:|---:|---:|---:|
| sexual | strict | 0.769 | 0.714 | 0.741 | 0.130 |
| sexual | moderate | 0.769 | 0.714 | 0.741 | 0.130 |
| violence | strict | 0.400 | 0.071 | 0.121 | 0.025 |
| violence | moderate | 0.400 | 0.071 | 0.121 | 0.025 |
| hate | strict | 0.750 | 0.107 | 0.188 | 0.020 |
| hate | moderate | 0.600 | 0.107 | 0.182 | 0.025 |

The strict union of the three queries has toxicity precision 0.688, recall 0.786, F1 0.733.

The moderate union of the three queries has toxicity precision 0.667, recall 0.786, F1 0.721.

## Content-token lengths

These are content tokens only, before public template tokens. The population rows include posts outside the evaluated short-post subset.

| Set | n | ≤40 | ≤104 | ≤168 | ≤424 |
|---|---:|---:|---:|---:|---:|
| toxicchat_human | 2853 | 76.8% | 87.6% | 92.6% | 99.5% |
| openai_mod | 1680 | 19.9% | 56.5% | 73.5% | 91.5% |
| evaluated toxicchat | 200 | 73.5% | 84.5% | 90.0% | 99.0% |
| evaluated openai_mod | 612 | 28.1% | 75.3% | 100.0% | 100.0% |

## Provenance and remaining work

Counts, unique IDs and cross-category alignment were checked before rendering. `benchmark_report_sources.json` pins every present raw benchmark file and records completeness. Full model/reference/policy pins remain in the prep lane ledger and model files.

The next stage is integer/float verdict agreement, category F1, error-boundary examples and zero-refusal calibration in the export lane.
