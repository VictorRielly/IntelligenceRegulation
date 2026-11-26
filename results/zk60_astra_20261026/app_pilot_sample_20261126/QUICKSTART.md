# Check a signed post offline

This example authenticates the publisher's signature on a saved public pilot post. It uses a 6,264-byte manifest and a public development key. The example was tested with Python 3.12.13 and `cryptography==43.0.3`. If your Python environment needs the package, install it once with `python -m pip install cryptography`. Package installation may need an internet connection.

Extract the ZIP and open the `proven-media-signature-example` directory. With your Python environment active, run

```sh
python apps/proven-media/tools/verify_manifest.py sample/manifest.json --signature-only --public-key 32c026629c724e2b9ccac8670e54c1c2349110733b011065cd97ff37ac451d90
```

The command succeeds when it reports `accepted: true`, scope `publisher_signature_only`, and passing schema, issuer-key and signature checks. Open `sample/manifest.json` and find `labels` to read the three signed verdicts. In this 14-token fixture the publisher recorded “no” for each category.

For a different downloaded manifest, substitute its filename and the publisher key you trust for that post. The key above is for this example. Signature verification works offline. Replaying the classifier requires the full reader, model kit and proof data. The signature binds these labels to the holder of the signing key. The model's accuracy and the authorship of the text require separate evidence.
