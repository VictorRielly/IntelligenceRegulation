# Text limits in the installed W16R2 app

The app accepts trimmed text up to **1,000 Unicode code points and 336 content tokens**. One native proof per policy covers up to 49 tokens for all three policies. The sexual-content and violence policies each allow 55. Beyond those thresholds the individual policies split the post with eight tokens of overlap. The 336-token fixture required 7, 7 and 8 proofs. [App profile](../../../apps/proven-media/deploy.json) · [Measured counts](RESULT.json)

## Author preview

Previously the composer accepted up to 2,000 UTF-16 units, the preview counted an untrimmed prefix and the submission checked the trimmed post against its 1,000-character limit. A draft could display a successful count and fail on submission. The preview and submission now share the server’s normalization and character check. Editing disables the Post button until the current draft has a passing preview. An earlier response cannot enable a later draft.

The installed W16R2 planner handled eight authenticated HTTP preview cases in an isolated test client. A 1,000-character draft and its 1,001-character variant each encoded to 223 tokens. The first preview accepted the post and counted 16 proofs. The second refused it before tokenization. Sending the second to the normal submission route also returned HTTP 400, as did the 337-token case. The test used a temporary author account and the installed public verifier export. No proof job was submitted. The app suite passed 322 tests and all four frontend suites passed, including an out-of-order preview test. [Preview results](PREVIEW.json) · [HTTP reproduction](check_preview.py)

## Native policy templates

I authenticated the retained November 25 pilot manifest against its recorded public development key. The three signed statement hashes matched their bytes in the public store and the hashes reported by the original successful standalone verifier runs. The app’s whole-post check re-tokenized the public fixture and compared the complete prefix and suffix ID lists, token ranges and padding with the native statements. [Reproduction](check_capacity.py) · [Archived standalone result](../app_composed_native_20261122/guest-20261125T073308.630547Z/RESULT.json)

| Policy | Prefix tokens | Suffix ID | Content capacity | Used positions for the 14-token post | Padding |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sexual content | 72 | 4 | 55 | 87 | 41 |
| Violence | 72 | 4 | 55 | 87 | 41 |
| Hate or harassment | 78 | 4 | 49 | 93 | 35 |

The installed public export’s profile digest matches the registered W16R2 digest and fixes the context at 128 positions. The policy ID sequences come from the app registry and the native statements. This audit reused the existing native reports and compared the installed binaries against their pins. It adds no new native replay, model-quality result or privacy claim. Both reproduction scripts require the retained public pilot and local app environment. The underlying content of the fixture was already public.
