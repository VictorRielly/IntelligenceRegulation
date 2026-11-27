# Coordinator's recheck of A32 (2026-11-27)

By the Claude co-coordinator. Handoff: `20261127-apps-web-reader-custom-assertions.md`. Script
`20261127-apps-web-reader-custom-assertions-recheck.py`, output `...-recheck.out.txt` (37 checks, all passed).

## What was checked, and how

I downloaded my own copies of the public files the handoff cites, each into its own empty directory, with a program
and a generic client name, and read them as text; nothing was executed. The copies: eleven source files at the two
commits the handoff names (nine of the web library's repository, two of the Rust reader), one further source file of the
Rust reader that the handoff did not read (`sdk/src/assertion.rs`, same commit), five answers of the public repository
API (the tag, the tag object, the commit, the tree listing, the releases list) and the two public pages. The script
asserts every quotation and line number of the handoff in those copies, and that the handoff's text says what is checked.
The files the handoff lists without quoting from them were not fetched by me.

## Carried forward [read as source; nothing built or run]

1. The web reader library (version 0.17.2 at the commit read) hands back the manifest as its Rust reader (pinned at
   0.92.2) produced it. Its own wrapper only rebuilds the map of manifests; it does not touch assertions.
2. In that Rust reader, an assertion whose label it does not know falls to a catch-all arm and is returned as an entry
   with its label and its data when the data is CBOR or JSON. Binary data and UUID-typed data are left out (the source
   says "todo: support binary forms").
3. The repository holds no display component. Its one sample reads a file and writes the object to the console.
4. The public Verify page is a shell that asks for JavaScript and carries no text. The documentation page of the vendor's
   inspection tool lists four sections of content details and says nothing about assertions with other labels.

## Corrections

1. The caveat in finding 2 cites "line 63-70" for the arm that treats any label ending in `.metadata` as a metadata
   assertion. In the file it is lines 622 to 629.
2. `c2pa-v0.92.2` is an annotated tag: the tag reference points to a tag object, and that object's target is the commit
   the handoff names. The handoff's pairing of tag and commit is right; the path has one more step.

## Additions from my own reading

1. A byte string inside CBOR data does not come back as bytes. The conversion turns it into base64 text in the
   library's own wrapped form (`assertion.rs` lines 338 to 341; the library's test at lines 709 to 730 shows it on a label
   the library does not know). The wrapped form itself was not read. A 64-byte reference stored as a byte string would
   reach an application as text.
2. CBOR that does not parse is an error in that conversion, and the catch-all arm passes the error up. What the caller
   then does, and so whether one malformed custom assertion spoils the reading of the whole manifest, was not read.
3. Each returned entry also says whether the signer created the assertion.

## Not carried

- "The documented panels have no place for a domain-labelled assertion" stays the author's reading. A page that is
  silent about other labels does not show that the product hides them.
- Whether the inspection tool and the public Verify page are the same product is not established, as the handoff says.

## Limits

Source reading only. The handoff used 14 files and 2 pages against a budget of 12 reads; it says so. The test that
would settle finding 2 (one test manifest with a domain-labelled CBOR assertion, read back through the library) needs
the standard's open command-line tool, whose installation on the work machine is a question still with the owner.
