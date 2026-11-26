#!/usr/bin/env python3
"""A23: check that each quoted sentence in the handoff exists in the text it is attributed to.

Usage: python3 -I 20261126-apps-c2pa-attachment.py SPEC_HTML CLAIM_VERIFY_RS STORE_CORE_RS SETTINGS_MOD_RS
  SPEC_HTML       C2PA specification 2.5 as served at
                  https://spec.c2pa.org/specifications/specifications/2.5/specs/C2PA_Specification.html
  the three .rs   files of github.com/contentauth/c2pa-rs at commit bf30cc5ed8785165a42e17845ffe9eb2be4d4f4e
                  (sdk/src/claim/claim_verify.rs, sdk/src/store/store_core.rs, sdk/src/settings/mod.rs)
The output depends only on the four input files (no clock, no network). Standard library only.
"""
import hashlib
import re
import sys
from html.parser import HTMLParser


class TextOf(HTMLParser):
    def __init__(self):
        super().__init__()
        self.out, self.skip = [], 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self.skip += 1
        if tag in ("p", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "br", "pre", "dt", "dd", "section"):
            self.out.append("\n")
        if tag in ("td", "th"):
            self.out.append(" | ")

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data)


def spec_lines(path):
    p = TextOf()
    p.feed(open(path, encoding="utf-8").read())
    t = "".join(p.out)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n\s*\n+", "\n", t)
    return t.splitlines()


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


HEAD = re.compile(r"^((\d+|[A-G])(?:\.\d+)*)\. [A-Z]")

# (id, statement it supports, quote)
SPEC_QUOTES = [
    ("S1", "third-party labels allowed (namespace)", "Entity-specific namespaces, meaning any namespace other than c2pa or those on the registry, shall begin with the Internet domain name for the entity"),
    ("S2", "third-party labels allowed (label)", "Each assertion has a label defined either by the C2PA specifications or an external entity."),
    ("S3", "third-party content types", "Entity-specific assertions can be any of those, any of the other JUMBF content types"),
    ("S4", "unknown label: no extra validation", "If the assertion’s label is not listed below, then that type of assertion does not require any additional validation steps beyond those already described."),
    ("S5", "schemas not enforced", "Validators should not validate inputs against these schemas."),
    ("S6", "must be declared in the claim", "the claim shall be rejected with a failure code of assertion.undeclared."),
    ("S7", "well-formedness check names standard assertions", "If the content of a standard assertion is not well-formed CBOR or is non-conforming JSON, the claim shall be rejected with a failure code of assertion.cbor.invalid or assertion.json.invalid."),
    ("S8", "unknown constructs may be ignored", "it may ignore the unsupported construct and process the rest of C2PA Manifest as if that construct were not present."),
    ("S9", "forward compatibility", "Gracefully handle unknown or unrecognized data (e.g., new fields, structures, or claim types) without causing fatal errors."),
    ("S10", "gathered_assertions not attributed to signer", "it was not sourced from the claim generator and is not attributed to the signer."),
    ("S11", "hash rules do not govern custom assertions", "This section does not govern algorithms used by custom assertions that are defined outside of this specification."),
    ("S12", "allowed hashes", 'SHA2-512 ("sha512").'),
    ("S13", "allowed hashes: SHA-3 excluded", "The SHA-3 family of hash algorithms are not on the allowed list"),
    ("S14", "external data allowed", "Some assertion data, due to its size or an infrequent need for it, may be externally hosted."),
    ("S15", "external data not fetched at validation", "the externally hosted data is not retrieved nor validated as part of manifest validation"),
    ("S16", "retrieval optional, failure does not reject", "As the retrieval of external data is optional, the inability to retrieve or validate external data shall not cause a claim to be rejected."),
    ("S17", "no fetch from a rejected claim", "A validator shall not attempt to retrieve external data from a rejected claim."),
    ("S18", "external reference: any data", "Both a hashed and an unhashed external reference assertion can be used for either arbitrary data (in any format) or a complete assertion"),
    ("S19", "external reference: optional retrieval", "data referenced through an external reference assertion shall be considered optional: its contents should not be retrieved as part of manifest validation."),
    ("S20", "signer takes responsibility if in created_assertions", "By including an external reference assertion in created_assertions the signer is taking responsibility for the data that is referred to by the assertion."),
    ("S21", "process evidence", "The hashed variant of an external reference assertion may be used to reference externally-stored creation-process evidence."),
    ("S22", "process evidence kinds are open", "Entity-specific evidence types shall conform to the same syntax as entity-specific namespaces."),
    ("S23", "log content implementation dependent", "All aspects of the log are implementation dependent."),
    ("S24", "when retrieved: size check", "If the length of the retrieved representation is not equal to the value of the size field, the validator shall return a failure code of assertion.hashedURI.mismatch"),
    ("S25", "when retrieved: hash check", "Compute the hash of the retrieved representation using the determined hash algorithm"),
    ("S26", "validator may bound retrieval", "a maximum number of decoded representation bytes, as described in Section 14.10.5.3.5, “Retrieved representation”, enforced separately from the encoded-byte limit;"),
    ("S27", "size field is an a priori bound", "provides an a priori bound on decoded representation bytes that a validator can apply as a read limit"),
    ("S28", "size field type", "size-type = int .ge 1"),
    ("S29", "hashed ext uri: alg mandatory", "Unlike alg fields in other types, this field is mandatory here."),
    ("S30", "linked resources: retrieval optional", "The C2PA specification does not require validators to perform network retrieval."),
    ("S31", "linked resources: codes never reject", "None of these codes, when reported under this procedure, shall cause the claim to be rejected."),
    ("S32", "manifest larger than asset is expected", "Embedding may not be practical, such as when the size of the C2PA Manifest Store is larger than the asset’s digital content."),
    ("S33", "JPEG 1 segment limit", "Since a single marker segment in JPEG 1 cannot be larger than 64K bytes, it is likely that multiple APP11 segments will be required"),
    ("S34", "AI disclosure purpose", "provide a means for a Claim Generator to provide machine-readable AI transparency information."),
    ("S35", "AI disclosure: modelType required", "it shall be present in the ai-model-disclosure-map object."),
    ("S36", "AI disclosure: model name field", '? "modelName": tstr, ; human-readable name of the AI model used'),
    ("S37", "AI disclosure: model identifier field", "; unique identifier of the AI model used (e.g., a URI, PURL, etc.)"),
    ("S38", "AI disclosure: harm evaluation pending", "; harmEvaluation: harm-evaluation-object"),
    ("S39", "AI disclosure: pending fields note", "; The remaining fields for the AI model disclosure metadata are pending"),
    ("S40", "AI disclosure: not attached without a model", "No trained model invoked; AI Model Disclosure assertion is not attached"),
    ("S41", "ingredient may record inference input", "Another common use for an ingredient is to describe some assets or data that were used as input to a process, such as the training or inference requests associated with an AI/ML model."),
    ("S42", "action names open", "or entity-specific action name (com.fabrikam.gaussianBlur, etc.)."),
    ("S43", "action parameters open", "the open-ended inclusion of any custom fields (and their associated values)"),
    ("S44", "actions can link to process data", "One use of an external reference assertion with a hashed location is to provide a cryptographically bound reference to data about the process."),
    ("S45", "reviewed action", "Content was read and assessed without modification."),
    ("S46", "classifier asset type", "c2pa.types.classifier"),
]

RS_QUOTES = [
    ("R1", "claim_verify", "No fetching of the external reference is performed, only the structure of the assertion is checked."),
    ("R2", "claim_verify", "// we should have accounted for all assertions in the store"),
    ("R3", "claim_verify", ".validation_status(validation_status::ASSERTION_HASHEDURI_MATCH)"),
    ("R4", "claim_verify", "// make sure assertion data has not changed"),
    ("R5", "store_core", "CAI_CBOR_ASSERTION_UUID => {"),
    ("R6", "store_core", "// make sure it is CBOR"),
    ("R7", "store_core", "CAI_JSON_ASSERTION_UUID => {"),
    ("R8", "store_core", "CAI_UUID_ASSERTION_UUID => {"),
    ("R9", "store_core", "CAI_EMBEDDED_FILE_UUID => {"),
    ("R10", "settings", "pub(crate) const MAX_ASSERTIONS: usize = 100_000;"),
    ("R11", "settings", "pub(crate) const DEFAULT_MAX_MANIFEST_RESPONSE_SIZE: u64 = 10 * 1024 * 1024;"),
    ("R12", "settings", "/// The default is 32 MB."),
    ("R13", "settings", "max_decompressed_manifest_size_in_mb: 32,"),
    ("R14", "settings", "/// Maximum size in megabytes of a Brotli-decompressed JUMBF manifest."),
]

# Searches that back "I found no sentence stating X": pattern, over the spec text; prints the match count and lines.
SPEC_SEARCHES = [
    ("maximum size or size limit of a manifest/assertion", r"maximum (size|length) of (a|the|an) (C2PA )?(manifest|assertion)|size limit|manifest size limit|assertion size limit"),
    ("any 'shall not exceed' sentence", r"shall not exceed"),
    ("any 'at most' bytes sentence", r"at most \d+ ?(bytes|KB|MB|GB|KiB|MiB)"),
    ("'unknown assertion' phrase", r"unknown assertion|unrecognized assertion|unrecognised assertion"),
]


def find_first(lines, needle, start=0):
    """First line at or after index start containing needle (spec: start after the contents list)."""
    for i in range(start, len(lines)):
        if needle in lines[i]:
            return i
    return None


def section_of(lines, i):
    for j in range(i, -1, -1):
        if j > 140 and HEAD.match(lines[j]):
            return lines[j][:70]
    return "?"


def main(argv):
    spec, cv, sc, st = argv[1:5]
    for name, p in (("spec html", spec), ("claim_verify.rs", cv), ("store_core.rs", sc), ("settings/mod.rs", st)):
        print(f"input {name}: sha256 {sha(p)}")
    lines = spec_lines(spec)
    print(f"spec text lines: {len(lines)}")
    print()
    print("== spec quotes (id | found | line in extracted text | section heading | supports)")
    miss = 0
    for qid, what, q in SPEC_QUOTES:
        i = find_first(lines, q, 141)
        if i is None:
            miss += 1
            print(f"{qid} | NOT FOUND | - | - | {what}")
        else:
            print(f"{qid} | found | {i + 1} | {section_of(lines, i)} | {what}")
    print()
    files = {"claim_verify": cv, "store_core": sc, "settings": st}
    print("== c2pa-rs quotes (id | found | file:line | supports-text)")
    for qid, f, q in RS_QUOTES:
        src = open(files[f], encoding="utf-8").read().splitlines()
        i = find_first(src, q)
        if i is None:
            miss += 1
            print(f"{qid} | NOT FOUND | {f} | {q}")
        else:
            print(f"{qid} | found | {f}.rs:{i + 1} | {q}")
    print()
    print("== spec searches (pattern, number of matching lines, first 5 lines trimmed to 160 chars)")
    for what, pat in SPEC_SEARCHES:
        rx = re.compile(pat, re.I)
        hits = [(i + 1, ln) for i, ln in enumerate(lines) if i > 140 and rx.search(ln)]
        print(f"[{what}] pattern {pat!r}: {len(hits)} lines")
        for n, ln in hits[:5]:
            print(f"   line {n}: {ln[:160]}")
    print()
    print(f"quotes not found: {miss}")


if __name__ == "__main__":
    main(sys.argv)
