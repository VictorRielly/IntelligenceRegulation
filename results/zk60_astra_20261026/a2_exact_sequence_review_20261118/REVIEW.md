# Six original text sequences from tokens to classifier decisions

The exported integer model reproduced all six archived classifier margins and decisions. For each prompt, the replay looked up the original token IDs in the authenticated embedding table, passed the computed output of each of the 26 layers directly to the next, and normalized the last token for the classifier head. Both the input and output digest matched for every one of the 156 layer evaluations, covering 103,680,000 distinct residual words. All 18,432 final normalization words matched. [Result](RESULT.json)

The prompt lengths were 234, 174, 241, 181, 240 and 180 tokens. No token was added or removed. The earlier 256-position run failed at a pair of added padding positions. The independent replay here uses each original length throughout, including the full attention score square. [Padding diagnosis](../a2_padding_diagnosis_20261117/README.md)

The run took 67.3 seconds with 408.3 MiB peak RSS. The seven dense projections use a single BLAS thread, with a checked bound below 2⁵³ on the absolute sum of products for every dot product. Thus each integer product and partial sum is exactly representable in binary64. Per-channel multipliers and rounding use signed integer arithmetic. An integer calculation cross-checks one full output channel per projection. A single-threaded integer fallback is available. [Implementation](replay.py)

The independent evaluation starts from the original token IDs. The six native runs subsequently matched its numerical results, and every generated receipt passed both the ordinary verifier and the independent reader. [Native and independent receipt results](../a2_exact_model_identity_20261118/NATIVE_RESULTS.json)

## Native parity on November 20

The six native runs reached the same reference values as the independent forward replay. The comparison bound all 156 layer output digests to the native stdout and to their reference files, checked the carry into the next layer, and checked the final normalized values, margins and verdicts. Across the six original lengths this covers **103,680,000 distinct residual words** and **18,432 normalized head words**. All storage padding stayed zero. Two executions of the comparison produced identical reports. [Native parity](NATIVE_PARITY.json), [reproduction](native_parity.py)
