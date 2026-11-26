# A26: how viewers treat an assertion with an entity-specific label

Applications researcher tick, 2026-11-26 UTC. Triage material, not a work order. Nothing was built or run.

## Question

From the C2PA user-experience guidance, the conformance-programme documents and the open verifier's documentation: does a consumer verifier display, hide or flag an assertion whose label belongs to a third party (A23 showed the specification permits one), and does any conformance or trust-list rule restrict such assertions?

## What was read, and how

Twelve files downloaded with curl and read by me as raw text; searches (8 of 12) only found addresses. No summary from a fetch tool was used. The script `20261126-apps-third-party-assertion-viewers.py` takes the files, prints each sha256 and length, and re-finds all 49 quotations below (`.out.txt`: 49 found, none missing; whitespace ignored, curly quotes folded). One guessed address was tried (a 2.5 edition of the user-experience guidance: 404). Not read as usable text: the open verifier's "Using the Verify tool" page (address from a search, returned 404 twice) and two address-redirect stubs. The conformance-programme PDF was read through a home-made extraction of its text operators, not a PDF reader; the quoted sentences were found in it, but its text order is not guaranteed.

Documents and versions (quotes in the script by id):
- **UX**: "C2PA User Experience Guidance for Implementers", edition 2.2, `https://spec.c2pa.org/specifications/specifications/2.2/ux/UX_Recommendations.html`. The index of the 2.5 specification set links this 2.2 edition as its User Experience Guidance (script: raw check true; a 2.5 UX address is not linked).
- **AIML**: "Guidance for Artificial Intelligence and Machine Learning", 2.3, `.../2.3/ai-ml/ai_ml.html`.
- **crJSON**: "Content Credentials JSON (crJSON) File Format Specification", 2.4, `.../2.4/crJSON/crjson-format.html`.
- **CONF** and **TRUST**: the open-source tools site's pages "C2PA Conformance Program" and "Trust lists", no version shown, `https://opensource.contentauthenticity.org/docs/conformance/` and `.../conformance/trust-lists`.
- **CP**: "C2PA Conformance Program", cover text "Version 0.2, 2026-07-31", `https://raw.githubusercontent.com/c2pa-org/conformance-public/main/docs/v0.2/C2PA%20Conformance%20Program.pdf`.
- **CAWG page**: the Rust library's page "Using the CAWG identity assertion", no version shown, `.../docs/sdk-repos/c2pa-rs/docs/cawg-identity`.
- **Lesson**: a training lesson with sample code, `https://learn.contentauthenticity.org/formatting-c2pa-data-for-display`.

## Findings

### 1. What the display guidance says about custom assertions (SOURCE, UX 2.2)

An entity-specific label is a "custom assertion" in this guidance. Section 3.4.2 (Custom Assertions):
- U1: "The C2PA specification allows for the inclusion of custom assertions, enabling implementers to record additional metadata that is not covered by the standard assertion types."
- U3: "Because custom assertions are not standardized, their meaning, trustworthiness, and privacy implications must be clearly conveyed to both creators and consumers of Content Credentials."
- U4: "Third-party implementers should exercise caution when deciding whether to display custom assertions from previous Manifest signers."
- U5: "For example, proprietary assertions may be shown with a label that clearly describes its purpose, or excluded from progressive disclosure displays altogether."

So the guidance neither requires display nor requires hiding; it names both as acceptable. U4 speaks of assertions "from previous Manifest signers" (earlier manifests); what a viewer should do with a custom assertion in the active manifest is not stated. Section 2: U9 "These are recommendations, not mandates, and we expect best practices to evolve."

Other statements that decide what a viewer would show:
- L2 (3.1.2) is "the signer, a trusted timestamp (if present), information about the inception action, and supporting source descriptions" (U10); L3 (3.1.3) "all relevant assertions tied to it" (U11); L4 (3.1.4) "the full technical detail of all Content Credentials-related data" (U12); the page adds that such interfaces are usually dedicated tools (paraphrase, not in the script). DERIVED: a verdict in a custom label would be absent from L1 and L2 as described, and its place at L3 depends on "relevant".
- 3.4 and 3.4.1 (U6, U7): viewers "should distinguish" assertions created by the signer from gathered ones, with labels such as "Entered by the creator". 3.4.3 (U8): CAWG assertions "are considered to be custom assertions within a C2PA manifest".
- 4.5.3 (U15): "C2PA recommends hiding not-well-formed manifests from end viewers altogether". 4.5 (U14) defines well-formed as "all assertions and ingredients abide by normative C2PA requirements". DERIVED, from A23: a malformed third-party assertion could make a viewer hide the whole manifest; the guidance does not say whether a custom one counts.
- 3.3.2 (U17): "source disclosures related to AI-edited or AI-enhanced are discouraged from being included in Content Credentials displays without additional verifiable context of how AI impacted the content." 4.3 (U18): "When labeling content, consideration must be given to the implied truth effect." These concern generation disclosures, not classifier verdicts; applying them to a verdict is my reading (DERIVED).

### 2. What shipped viewers do: little verified

- **Verify tool.** TRUST, section "Verify tool" (T3, T4): it uses the interim list "to validate that Content Credentials were signed using a "known certificate"" and, for a known certificate, "will display the name of the certificate owner and time of the claim signature." Nothing read says how it shows an unknown label. **NOT VERIFIED** (its documentation page did not load).
- **Lesson sample (F1 to F4).** The sample popover finds assertions by label (`cawg.identity`, `c2pa.actions.v2`) and builds five fields. DERIVED: that sample shows nothing under any other label. It is teaching code, not a statement about a product.
- **crJSON (SOURCE).** 3.6.1: "a generator may choose not to decode custom assertions, in which case it shall represent them as empty objects" (J4). 3.6.4: JSON-LD or CBOR ones decoded as standard (J1); "if it has any other serialization, then the output into crJSON is implementation dependent" (J2), which "could include producing an empty object" (J3). So a reader that follows this format may show a custom assertion as present but empty.
- **Open library, identity assertion (G1 to G5).** An identity assertion is a custom one (U8). If its issuer is not on a list, "the informational code cawg.ica.untrusted_issuer is reported for that identity assertion" and "it does not make the enclosing manifest's validation_state Invalid" (G2, G3); issuers are untrusted by default (G4). SOURCE; shows one third-party assertion type carrying its own trust result separate from the manifest's. "C2PA Tool also displays CAWG identity assertions." (G5.)

### 3. Conformance and trust lists: no restriction found

- CP states validator requirements only as headings under 6.1.1: "Requirements for Validator Products include:" ... "Assertion Validation" (P4, P5); it says the programme "will eventually require claims validators to demonstrate complete conformance" (P3); it accepts specification 2.2 and 2.4 (P9), not 2.5. COUNTED in the extracted text of CP: "custom assertion", "entity-specific", "third-party assertion" each 0; the same three terms are 0 in CONF and TRUST, where the bare word "assertion" occurs once and zero times.
- The generator scope covers "components ... involved in the generation of C2PA assertions referenced in the created_assertions claim field (including any data within them)" (P6, Target of Evaluation). DERIVED: a third-party assertion listed in `created_assertions` brings whatever produced it into the evaluated generator; where a gathered assertion falls is not stated.
- Trust lists hold "X.509 certificate trust anchors" for certificates of conforming generators (T1), and validators "must refer to the C2PA trust list to determine whether Content Credentials were signed with a valid certificate" (T2). They concern signers, not assertion labels.
- **NOT VERIFIED:** the Certificate Policy and the Generator Product Security Requirements (both linked from CONF) were not read; either could say more.

## What a product would have to build

A verdict stored as a custom assertion cannot be assumed visible to a consumer. A product would need its own display or check page that reads the assertion (and its receipt reference) and states what is proved and what is not, and would sign the claim under a signer a viewer's trust list accepts, or accept the "not trusted" warning (4.5.1, U16).

## Test that would confirm or kill this

Build one manifest with a domain-labelled CBOR assertion and run it through three viewers (the command-line tool, the open web reader's sample, the public Verify page): record shown, hidden, empty or flagged at each level. Kill "viewers do not show it" if two of three show the data to a consumer without a developer view.

## Not verified

Behaviour of any real viewer; the Verify page; the two other programme documents; whether a 2.5 UX edition exists beyond the index link; the extraction order of the PDF text; the web reader's source (queued as A32).

## Coordinator's check (2026-11-26)

The script was re-run by the co-coordinator on the tick's downloads with the heavy lock free: the output is identical. I then fetched my own copies of the eleven addresses (a HEAD request first, each file into its own new empty directory) and ran the same script on them: `20261126-apps-third-party-assertion-viewers-recheck.out.txt`, 49 of 49 quotations found.

- **Same bytes:** the user-experience guidance, the index page, the conformance-programme PDF and the lesson page have the same SHA-256 as the tick's copies; so do my copies of the two editions it cites for the machine-learning guidance (2.3) and the JSON format (2.4). The three pages of the open-source tools site are 515 bytes shorter each in my copies and strip to the same number of text characters (4,178, 3,415 and 3,927).
- **Later editions exist of two documents.** The canonical link of the machine-learning guidance page points to a 2.4 address and that of the JSON format page to a 2.5 address. The recheck above was run on those later editions: the quotations A1 and J1 to J4 are in them too. The JSON format's 2.5 edition is about four times as long in text; its one use of "entity-specific" concerns the type label of a trust list ("or a custom type using entity-specific namespace syntax"), not assertions. The canonical link of the user-experience guidance points to its own 2.2 address.
- **Read by me in my own copies, whole passage:** section 3.4.2 of the user-experience guidance (six sentences; the handoff quotes four, and the script a fifth, U2: "While C2PA does not restrict the content of custom assertions, their presence introduces important UX considerations."); sections 3.6.1 and 3.6.4 of the JSON format (2.5 edition); the "Verify tool" section of the trust-lists page; the issuer-trust section of the identity assertion page; and, in the conformance-programme PDF, the validator list of 6.1.1, the Target of Evaluation passage, section 6.7.5 and glossary entry 2.43. The PDF was read through the same extraction of its text operators as the tick's (21 page objects, text not compressed); the passages read in order.
- **One sentence to add [SOURCE, conformance programme v0.2, glossary 2.43 "Signer"]:** "In the C2PA Trust Model, the Assertions enumerated in the created_assertions object of the C2PA Claim are attributed to the Signer." Together with the Target of Evaluation passage (P6, which continues "this naturally includes any components that were executed in order to make that assertion"), this means a verdict placed among a signer's created assertions is attributed to that signer, and at a conforming product whatever produced it is inside the evaluated product. That is a reading of two quoted sentences, not a ruling by the programme.

**Carried forward [SOURCE, with the limits the handoff states]:** the display guidance allows a viewer to show a custom assertion with a label or to leave it out, as a recommendation; the JSON format lets a tool represent a custom assertion as an empty object; the identity assertion carries its own trust code separate from the manifest's; no restriction on such assertions in the conformance-programme text (v0.2), the conformance page or the trust-lists page.

**Not carried:** what any real viewer does (nothing was run and the Verify page's documentation did not load); the DERIVED remarks on levels 1 to 3, on a malformed assertion hiding a manifest and on the AI-disclosure sentences (U17, U18), which are the researcher's readings; the lesson sample as evidence about a product; "not 2.5" in section 3, which is an inference (the sentence P9 names v2.2 and v2.4 and is silent on 2.5); and "an entity-specific label is a custom assertion in this guidance" as more than a reading (the guidance does not use the term entity-specific: 0 occurrences). The Certificate Policy and the Generator Product Security Requirements were not read by anyone.
