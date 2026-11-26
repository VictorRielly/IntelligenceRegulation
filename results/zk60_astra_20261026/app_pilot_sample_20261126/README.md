# Offline example for a pilot guest

[Download the signed-post example](proven-media-signature-example.zip) and follow the [instructions](QUICKSTART.md). The 63,598-byte ZIP lets a guest authenticate the three moderation labels on a saved 14-token public post with Python and `cryptography`. The original signed manifest is 6,264 bytes. The ZIP’s SHA-256 is `3cb9eaee62a00e0cf94a73ea2701e8ef6a10f0c6ba13388346c5c5c50b8979f3`.

The example reuses the signature checker and its four Python modules from the previously qualified guest reader, together with the licenses and the original signed post. The included development public key is for the worked example. A guest checking another publisher’s post supplies a separately trusted key. Native proof verification follows the [full pilot instructions](../app_composed_native_20261122/PILOT.md).

I tested the ZIP in a fresh Python 3.12.13 environment containing `cryptography` 43.0.3 and its dependencies. The documented command accepted the historical signature. Changing a signed label or supplying another key caused the checker to exit with failure. The checker ran without an application database, model kit, proof store or network connection. Two builds produced identical bytes. [Test output](SAMPLE_CHECK.json) · [Rebuild](build_sample.py) · [Repeat the verification](check_sample.py)

## Files needed to reproduce the original guide

The earlier release lists left 23 local file targets in the pilot guide unavailable from a clean checkout, including its sample manifest and original publisher key. The [pilot dependency list](PILOT_FILES.json) names those 23 files plus seven qualifications, helpers and reports used by the linked code. Together they occupy 232,769 bytes. I approve these exact versions for the coordinator’s proposed commit under the coordinator’s release authority. The list’s SHA-256 is `33b8c30489653b1361d6757dabf61812454cc4ab0f89e042db07eae003ab8360`. Historical operator reports retain some local path names.

I reconstructed the [original release](../app_release_scope_20261126/README.md) and repeated the guest checks against commit `4c1589199` with the named additions. The sample link in the app README is a four-line follow-up to that commit. All 41 distinct local file targets in the pilot guide resolved. Three commands reproduced their saved results on that tree.

| Command | Reproduced result |
| --- | --- |
| `tools/verify_manifest.py` with the guide’s manifest, test key and `--signature-only` | Same passing signature, issuer-key and schema checks as the original run |
| `audit_pilot_labels.py` | Three signed “no” labels, 84 inventory entries and three archived Merkle paths. The original native reports each recorded a 97-bit floor. |
| `qualify_reader_source.py` | Identical 103,708-byte full reader archive, the historical post’s three accepted chunks and four passing public-store tests |

These runs verify the distributed source and archived reports. Fresh native replay still needs the larger kit and proof store. A separate participant machine and independent distribution of a live publisher key remain open for the outside pilot.
