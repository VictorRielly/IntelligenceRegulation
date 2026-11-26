"""A26 check script. Usage (run with python3 -I):

  python3 -I this.py ux=FILE aiml=FILE conf=FILE confprog=FILE crjson=FILE trust=FILE cawgid=FILE fmt=FILE

Prints each file's sha256 and byte length, then re-finds every quoted sentence in the
stripped text of its file (whitespace ignored, curly quotes and the Mac-Roman apostrophe
folded to plain ones) and prints FOUND or NOT FOUND, plus the nearest preceding heading
for pages read as HTML. Then prints counts of a few terms in each file's text.
Reads only the files named on the command line. No network, no clock, no paths printed.
"""
import hashlib
import re
import sys
from html.parser import HTMLParser


class Strip(HTMLParser):
    def __init__(self):
        super().__init__()
        self.out = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self.skip += 1
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self.out.append("\n\n## ")
        elif tag in ("p", "li", "tr", "div", "br", "dt", "dd", "pre"):
            self.out.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip -= 1

    def handle_data(self, d):
        if not self.skip:
            self.out.append(d)


def fold(t):
    for a, b in (("’", "'"), ("‘", "'"), ("“", '"'), ("”", '"'),
                 ("Õ", "'"), ("​", ""), (" ", " ")):
        t = t.replace(a, b)
    return t


def html_text(raw):
    p = Strip()
    p.feed(raw.decode("utf-8", errors="replace"))
    return fold("".join(p.out))


def pdf_text(data):
    out = []

    def dec(tok):
        if tok.startswith(b"<"):
            h = re.sub(rb"\s+", b"", tok[1:-1])
            if len(h) % 2:
                h += b"0"
            return bytes.fromhex(h.decode()).decode("cp1252", errors="replace")
        s = re.sub(rb"\\([()\\])", rb"\1", tok[1:-1])
        return s.decode("cp1252", errors="replace")

    for m in re.finditer(rb"BT\b(.*?)\bET\b", data, re.S):
        line = ""
        for t in re.finditer(rb"\[(.*?)\]\s*TJ|(<[0-9A-Fa-f\s]*>|\((?:\\.|[^\\)])*\))\s*Tj",
                             m.group(1), re.S):
            if t.group(1) is not None:
                for p in re.finditer(rb"<[0-9A-Fa-f\s]*>|\((?:\\.|[^\\)])*\)|-?\d+\.?\d*", t.group(1)):
                    tok = p.group(0)
                    if tok[:1] in (b"<", b"("):
                        line += dec(tok)
                    else:
                        try:
                            if float(tok) < -200:
                                line += " "
                        except ValueError:
                            pass
            else:
                line += dec(t.group(2))
        out.append(line)
    return fold("\n".join(out))


def nospace(t):
    chars, idx = [], []
    for i, c in enumerate(t):
        if not c.isspace():
            chars.append(c)
            idx.append(i)
    return "".join(chars), idx


# (key, id, heading the sentence sits under, quoted sentence)
Q = [
    # UX guidance, version 2.2
    ("ux", "U1", "3.4.2. Custom Assertions", "The C2PA specification allows for the inclusion of custom assertions, enabling implementers to record additional metadata that is not covered by the standard assertion types."),
    ("ux", "U2", "3.4.2. Custom Assertions", "While C2PA does not restrict the content of custom assertions, their presence introduces important UX considerations."),
    ("ux", "U3", "3.4.2. Custom Assertions", "Because custom assertions are not standardized, their meaning, trustworthiness, and privacy implications must be clearly conveyed to both creators and consumers of Content Credentials."),
    ("ux", "U4", "3.4.2. Custom Assertions", "Third-party implementers should exercise caution when deciding whether to display custom assertions from previous Manifest signers."),
    ("ux", "U5", "3.4.2. Custom Assertions", "For example, proprietary assertions may be shown with a label that clearly describes its purpose, or excluded from progressive disclosure displays altogether."),
    ("ux", "U6", "3.4. Assertions", "implementers should distinguish between assertion sources that have been created by the Signer rather than gathered from other sources and included in the signed Manifest."),
    ("ux", "U7", "3.4.1. Created vs. Gathered Assertions", 'At Levels 2 and 3, implementations should clearly differentiate between created and gathered assertions using contextual labels such as "Recorded by the capture device" or "Entered by the creator."'),
    ("ux", "U8", "3.4.3. Identity Assertions", "CAWG assertions are considered to be custom assertions within a C2PA manifest, and should follow CAWG UX guidance accordingly."),
    ("ux", "U9", "2. Principles", "These are recommendations, not mandates, and we expect best practices to evolve."),
    ("ux", "U10", "3.1.2. Level 2 (L2)", "It includes key information such as the signer, a trusted timestamp (if present), information about the inception action, and supporting source descriptions, if applicable"),
    ("ux", "U11", "3.1.3. Level 3 (L3)", "This includes not only the signer, but all relevant assertions tied to it, such as editing history, attribution (if applicable), and ingredient relationships."),
    ("ux", "U12", "3.1.4. Level 4 (L4)", "It exposes the full technical detail of all Content Credentials-related data."),
    ("ux", "U13", "4.4. L2 and L3 Summaries", "Manifest summaries are a curated collection of assertions across the entire provenance of an asset."),
    ("ux", "U14", "4.5. Validation States", "Well-formed: Hard bindings are intact and all assertions and ingredients abide by normative C2PA requirements."),
    ("ux", "U15", "4.5.3. Not Well-Formed, Valid or Trusted", "C2PA recommends hiding not-well-formed manifests from end viewers altogether"),
    ("ux", "U16", "4.5.1. Well-Formed and Valid, But Not Trusted", "Instead of hiding an otherwise valid manifest, implementers should consider adding a warning to their direct disclosures that explain the issue."),
    ("ux", "U17", "3.3.2. Source Disclosures", "source disclosures related to AI-edited or AI-enhanced are discouraged from being included in Content Credentials displays without additional verifiable context of how AI impacted the content."),
    ("ux", "U18", "4.3. L1 Source Disclosures", "When labeling content, consideration must be given to the implied truth effect."),
    ("ux", "U19", "2.1. Designing for trust", "Instead of asserting definitive claims about an asset's authenticity, empower users with access to Content Credentials information that helps them make informed judgments."),
    # AI and ML guidance, version 2.3
    ("aiml", "A1", "9. AI-ML Output Content Credential", "Additional material in the assertion store such as links to the AI-ML model Content Credential, provenance of the inputs to the model, the components and security of the environment the model ran in, timestamps, and even explainability metadata that tell the consumer why the model provided the result it provided all can enable more trust in the results."),
    # crJSON format, version 2.4
    ("crjson", "J1", "3.6.4. Custom Assertions", "If a crJSON generator chooses to decode a custom assertion that is serialized in either JSON-LD or CBOR, it shall be decoded according to the rules for standard assertions."),
    ("crjson", "J2", "3.6.4. Custom Assertions", "However, if it has any other serialization, then the output into crJSON is implementation dependent."),
    ("crjson", "J3", "3.6.4. Custom Assertions", '"Implementation dependent" could include producing an empty object for the assertion value.'),
    ("crjson", "J4", "", "Additionally, a generator may choose not to decode custom assertions, in which case it shall represent them as empty objects."),
    # Conformance programme web page and trust-list page (CAI open-source site, no version shown)
    ("conf", "C1", "Generator products", "A conforming generator product produces manifest data that conforms to the C2PA Content Credentials specification, creates assertions in the asset's active manifest and signs a claim using a valid X.509 certificate on the C2PA trust list."),
    ("conf", "C2", "Validator products", "A conforming validator product produces correct validation results according to the C2PA Content Credentials specification."),
    ("trust", "T1", "C2PA trust list", "The C2PA trust list is a list of X.509 certificate trust anchors (either root or subordinate certification authorities) that issue certificates to conforming generator products under the C2PA Certificate Policy."),
    ("trust", "T2", "C2PA trust list", "Conforming validator products must refer to the C2PA trust list to determine whether Content Credentials were signed with a valid certificate."),
    ("trust", "T3", "Verify tool", 'The C2PA Verify tool currently uses the ITL to validate that Content Credentials were signed using a "known certificate".'),
    ("trust", "T4", "Verify tool", "Conversely, if the Content Credential was signed by a known certificate, the Verify tool will display the name of the certificate owner and time of the claim signature."),
    # Conformance Program document, version 0.2 (PDF)
    ("confprog", "P0", "cover", "Version 0.2, 2026-07-31"),
    ("confprog", "P1", "6.1.1. C2PA Content Credentials Specification Process Requirements", "The minimum release level of the C2PA Content Credentials Specification for applicability of this version of the C2PA Conformance Program is v2.2."),
    ("confprog", "P2", "6.1.1. C2PA Content Credentials Specification Process Requirements", "includes over 150 normative requirements attributed to claims Validator Products which validate C2PA manifests for consumers."),
    ("confprog", "P3", "6.1.1. C2PA Content Credentials Specification Process Requirements", "The C2PA Conformance Program will eventually require claims validators to demonstrate complete conformance to these exacting requirements in order to receive its approval."),
    ("confprog", "P4", "6.1.1. C2PA Content Credentials Specification Process Requirements", "Requirements for Validator Products include:"),
    ("confprog", "P5", "6.1.1. C2PA Content Credentials Specification Process Requirements", "Assertion Validation"),
    ("confprog", "P6", "Target of Evaluation", "involved in the generation of C2PA assertions referenced in the created_assertions claim field (including any data within them)"),
    ("confprog", "P7", "2.26. Generator Product", "The asset's active manifest contains assertions made by the Generator Product, and features a claim signed by a certificate where the Generator Product is the subject, about the provenance of the asset."),
    ("confprog", "P8", "6.7.1. Use of C2PA Machine-Readable Lists", "Conforming Validator Products SHALL regularly refresh the C2PA Trust List to determine whether a C2PA Claim is signed with a C2PA Claim Signing Certificate that cryptographically ladders up to a Certification Authority on the C2PA Trust List."),
    ("confprog", "P9", "6.7.5. Program Versioning and Grace Period", "This version accepts Applicant assertions as meeting the C2PA Content Credential Specification v2.2 and v2.4."),
    # CAI Rust library, CAWG identity page (no version shown)
    ("cawgid", "G1", "Trusting identity claims aggregation issuers", "the library treats ICA issuers as untrusted unless they appear on an explicit allow-list."),
    ("cawgid", "G2", "Trusting identity claims aggregation issuers", "If the issuer is not on the list, the informational code cawg.ica.untrusted_issuer is reported for that identity assertion and cawg.ica.credential_valid is withheld."),
    ("cawgid", "G3", "Trusting identity claims aggregation issuers", "The cawg.ica.untrusted_issuer result is scoped to the individual identity assertion and is recorded informationally: it does not make the enclosing manifest's validation_state Invalid, nor does it downgrade a manifest that is otherwise Trusted on the basis of its own C2PA signer."),
    ("cawgid", "G4", "Trusting identity claims aggregation issuers", "The default value is empty, meaning that no ICA issuer is trusted."),
    ("cawgid", "G5", "", "C2PA Tool also displays CAWG identity assertions."),
    # Training-course code sample (a lesson, not a rule)
    ("fmt", "F1", "", "// Get all assertions from the active manifest"),
    ("fmt", "F2", "", "const identityAssertion = assertions.find(a => a.label === 'cawg.identity');"),
    ("fmt", "F3", "", "const actionsAssertion = assertions.find(a => a.label === 'c2pa.actions.v2');"),
    ("fmt", "F4", "", "{ label: 'Signed At', value: timestamp }"),
]

TERMS = [
    "assertion", "custom assertion", "entity-specific", "third-party assertion", "third party assertion",
    "gathered", "created_assertions", "unknown assertion", "unrecognized", "unrecognised",
]


def main():
    files = {}
    for a in sys.argv[1:]:
        k, _, p = a.partition("=")
        files[k] = p
    texts = {}
    print("INPUTS")
    for k in ("ux", "aiml", "conf", "confprog", "crjson", "trust", "cawgid", "fmt"):
        if k not in files:
            print(k, "MISSING ARGUMENT")
            continue
        raw = open(files[k], "rb").read()
        print(k, "sha256", hashlib.sha256(raw).hexdigest(), "bytes", len(raw))
        texts[k] = pdf_text(raw) if raw[:5] == b"%PDF-" else html_text(raw)
    print()
    print("QUOTES")
    miss = 0
    for k, qid, head, q in Q:
        if k not in texts:
            print(qid, "NOT FOUND (file missing)")
            miss += 1
            continue
        t = texts[k]
        ns, idx = nospace(t)
        pos = ns.find(nospace(fold(q))[0])
        if pos < 0:
            print(qid, k, "NOT FOUND")
            miss += 1
            continue
        orig = idx[pos]
        nearest = ""
        h = t.rfind("\n## ", 0, orig)
        if h >= 0:
            nearest = t[h + 4:t.find("\n", h + 4)].strip()
        hs = ""
        if head and head != "cover":
            hs = " heading-text-before-quote=" + ("yes" if nospace(head)[0] in ns[:pos] else "NO")
        print(qid, k, "FOUND", "nearest-heading=[" + nearest + "]" + hs)
    print()
    print("quotes not found:", miss, "of", len(Q))
    print()
    print("RAW CHECKS (index page of the specification set, raw markup)")
    if "idx" in files:
        raw = open(files["idx"], "rb").read()
        print("idx", "sha256", hashlib.sha256(raw).hexdigest(), "bytes", len(raw))
        for needle in ('href="../2.2/ux/UX_Recommendations.html"',
                       'href="../2.5/ux/UX_Recommendations.html"',
                       'UX_Recommendations.html" class="xref page">User Experience Guidance<'):
            print("  contains", needle, "->", needle.encode() in raw)
    else:
        print("idx MISSING ARGUMENT")
    print()
    print("TERM COUNTS (whitespace and case ignored)")
    for k in ("ux", "aiml", "conf", "confprog", "crjson", "trust", "cawgid"):
        if k not in texts:
            continue
        ns = nospace(texts[k])[0].lower()
        cells = ["%s=%d" % (w, ns.count(nospace(w)[0])) for w in TERMS]
        print(k, "chars", len(ns), " ".join(cells))


main()
