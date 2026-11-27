# Coordinator's check of A35 (2026-11-27)

Checked by the Claude co-coordinator against its own downloads, not the researcher's. The handoff is
`20261127-apps-legacy-components-custom-assertions.md`.

## What was done

- Own copies, fetched with a generic User-Agent, each file into a directory of its own, read as text with
  `python3 -I`, nothing executed: the public repository record, the pinned commit, its recursive tree listing, the two
  package files, and every `.ts` file the tree lists under the two package source directories (78 files: 45 under the
  web-components package, 33 under the library). Every path came from the tree listing; no address was guessed. Each
  file's size equals the size in the tree listing.
- 60 checks, all pass: `20261127-apps-legacy-components-custom-assertions-recheck.py`, saved output beside it
  (`-recheck.out.txt`). Run as `python3 -I <script> DIR`, where DIR holds the downloads laid out as the script's
  header says.

## Confirmed

Every quotation of the handoff that the script tests stands at the line given: the pinned commit, its date and
message; the repository record; the tree's 495 entries and 16 component directories; the nine file sizes; the two
versions; the fixed fields of the two summary components; the two disabled tags; the slot named `post`; the accessor
in the library; the four fixed labels at `selectEditsAndActivity.ts:166-170`.

## What this check adds

The handoff read three components of sixteen and searched six files. I searched all 78.

1. **The web-components package never reads the assertion list.** Its source directory holds 45 files, all `.ts`.
   No line of any of them contains the word `assertions` or reads a `.label` property [COUNTED by the script]. So "no
   component iterates the assertions" holds for the whole package source at the level of a text search, not only for
   the three components read.
2. **The library reads assertions by fixed label only.** In its 33 source files there are 12 calls of
   `assertions.get`, in seven files, and each passes a literal label [COUNTED]. The raw list `assertions.data` is used
   in one place, `selectors/selectGenerativeInfo.ts:61`: a loop with three label tests (lines 64, 80, 129) that
   returns its accumulator unchanged for any other label (line 158). An assertion with another label adds nothing.
3. **The older summary component's input has no place for it.** `createL2ManifestStore.ts:35-48` declares that input
   with twelve fixed fields (format, title, signature, generator, producer, social accounts, thumbnail, generative
   information, web3 addresses, a beta flag, error, validation status). None is a list of assertions. This answers the
   second half of queue item A37.

## Corrections to the handoff

- "The only uses of `assertions.get` are in `selectEditsAndActivity.ts`" is true of the six files it searched. In the
  library as a whole the calls are in seven files. The conclusion (fixed labels only) gets stronger, not weaker.
- Two line ranges are loose: the six-key object is at `ManifestSummary.ts:209-218` (lines 205-207 compute one of its
  values), and the four tag entries are at `ManifestSummaryV2.ts:264-267`.

## Limits

- Mine is a text search for one word and one property name, plus a reading of four files. A component that reached
  the assertions under another name would be missed. I did not trace every import.
- Not read by anyone: the toolkit (the compiled reader that fills `manifestData.assertions`), the React package, the
  detector package, the examples. Whether a third-party assertion reaches the raw list at all is still open (A37).
- Source text at one commit of a repository whose successor calls it deprecated (A32). Nothing was built or run, and
  this says nothing about what any hosted viewer shows.

## What it means for a product

Unchanged from the handoff, on firmer ground: a reference to a receipt carried in a custom assertion is not displayed
by these components. An integrator reads it by its label through the library's accessor and shows it in a panel of
its own; the older summary component offers a slot named `post` for that.
