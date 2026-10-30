// Preflight of actual S25 source scanner and call-kind table, extracted verbatim.


fn source(name: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("stage 25: {}: {e}", p.display()))
}


fn production_sources() -> Vec<(String, String)> {
    let parent = source("src/private_block.rs");
    let lines: Vec<&str> = parent.lines().collect();
    let mut out: Vec<(String, String)> = Vec::new();
    for (i, l) in lines.iter().enumerate() {
        let Some(rest) = l.trim().strip_prefix("mod ").or_else(|| l.trim().strip_prefix("pub mod ")) else { continue };
        let Some(name) = rest.strip_suffix(';') else { continue };
        if i > 0 && lines[i - 1].trim() == "#[cfg(test)]" {
            continue;
        }
        let path = format!("src/private_block/{name}.rs");
        let text = source(&path);
        out.push((path, text));
    }
    out.push(("src/private_block.rs".to_string(), parent));
    // R12b's public wrapper has one production child. Scan it too, and fail
    // closed if another child is added without extending this enumeration.
    let tied=source("src/private_block/tied_tables.rs");
    let children=tied.lines().take_while(|line| line.trim()!="#[cfg(test)]")
        .filter_map(|line| line.trim().strip_prefix("mod ").or_else(|| line.trim().strip_prefix("pub mod ")))
        .collect::<Vec<_>>();
    assert_eq!(children,vec!["derive;"],"the tied-table production module enumeration moved");
    out.push(("src/private_block/tied_tables/derive.rs".to_string(),source("src/private_block/tied_tables/derive.rs")));
    // the frozen seam is the toy's and the frozen-seam rung's endpoint and is
    // therefore on the block's path, although it lives outside this module
    // and outside this lane's write set
    out.push(("src/private_seam.rs".to_string(), source("src/private_seam.rs")));
    out
}


fn production_text(src: &str) -> &str {
    let cut = src.find("\n#[cfg(test)]\nmod tests {").map(|k| k + 1).unwrap_or(src.len());
    &src[..cut]
}


const CALL_SITES: [(&str, &str, usize, &str); 16] = [
    // NATIVE LANE: the trained-block CLI's request context, an unkeyed hash of
    // public words (variant, label, layer); its file digests are SHA-256 via
    // `Sha256::digest`, not an entry point of this table
    ("src/private_block/trained_block.rs", "blake3::hash(", 2, "driver-side, outside the protocol: the trained-block CLI's and the trained-stack CLI's request contexts, unkeyed hashes of public length-prefixed words (variant, label, layer indices)"),
    // R12b moves bounded public-file hashing out of trained_block.rs and
    // authenticates/recomputes the tied tables. These SHA-256 operations
    // share no oracle with BLAKE3 and consume no private witness value.
    ("src/private_block/tied_tables.rs", "Sha256::new(", 1, "C1 — bounded public token-file SHA-256, checked against the manifest and checkpoint derivation; its public digest is bound through D9"),
    ("src/private_block/tied_tables/derive.rs", "Sha256::new(", 5, "C1 — public checkpoint authentication, consumed tied-tensor bytes, derived embedding, head and multiplier table SHA-256; public digests bound through D9, outside the proof's BLAKE3 oracle classes"),
    // NATIVE LANE: the driver overlay's CLI bridge (pre-existing in the
    // candidate; this table had not been told about it): D4 recomputed to
    // check a policy's model root, the CLI's context derivation, and an
    // in-process seal check of the output plane that never leaves the process
    // and enters no transcript or commitment
    ("src/private_block/mvp_driver.rs", "blake3::Hasher::new(", 3, "driver-side, outside the protocol: the run's public-statement digest D4 recomputed (model root), the CLI's context derivation, and an in-process seal-check digest that is compared and dropped"),
    // NATIVE LANE (from the lane-C prototype): the trained-model statement's
    // identity, which a bound run absorbs as its `"calibration"` word
    ("src/private_block/trained_statement.rs", "blake3::Hasher::new(", 1, "D9 — the trained-model statement identity, unkeyed, over a 47-byte versioned domain literal and the length-prefixed statement fields"),
    ("src/private_block.rs", "blake3::hash(", 1, "D1 — the calibration identity, an unkeyed hash of a 30-byte public literal"),
    ("src/private_block.rs", "blake3::Hasher::new(", 1, "D2 — the block's public/weights digest, unkeyed, over a 31-byte literal and the framed public tensors"),
    ("src/private_block/layout.rs", "blake3::Hasher::new(", 1, "D3 — the block's schedule digest, unkeyed, over a 33-byte literal and the framed description lines"),
    ("src/private_block/run.rs", "blake3::Hasher::new(", 2, "D4 and D5 — the run's public statement digest and its schedule digest, both unkeyed"),
    ("src/private_block/endpoint_g.rs", "blake3::Hasher::new(", 1, "D6 — the generalised endpoint's spec digest, unkeyed, 142 bytes"),
    ("src/private_block/boundary.rs", "blake3::Hasher::new(", 1, "D7 — the internal boundary's spec digest, unkeyed, 151 bytes"),
    ("src/private_seam.rs", "blake3::Hasher::new(", 1, "D8 — the frozen seam's spec digest, unkeyed, 128 bytes"),
    ("src/private_block/run_sink.rs", "sha256_hex(", 1, "C1 — a segment file's digest. SHA-256 (`sha2`), NOT BLAKE3: it shares no oracle with anything above"),
    // STAGE 27 added the sixth: `ArrayStore::put`'s CONTENT digest, which
    // both names an array in `arrays.bin` and is the key the store
    // deduplicates on. Same kind as the other five — SHA-256 (`sha2`) over
    // bytes the bundle publishes anyway, sharing no oracle with any BLAKE3
    // call above, and deciding no proof byte and no challenge.
    ("src/private_block/run_capture.rs", "sha256_hex(", 6, "C1 — the capture writer's file, public-word and array-store content digests, SHA-256"),
    ("src/private_block/run_statement_file.rs", "sha256_hex(", 5, "C1 — the retained run statement's file digests, SHA-256"),
    ("src/private_block/plane_index.rs", "sha256_hex(", 0, "no hash of its own: the plane index table is public layout data the capture writer digests"),
];

const ENTRY_POINTS: [&str; 13] = [
    "blake3::hash(",
    "blake3::Hasher::new(",
    "blake3::Hasher::new_keyed(",
    "blake3::Hasher::new_derive_key(",
    "blake3::derive_key(",
    "blake3::keyed_hash(",
    "finalize_xof(",
    "hashtag::hasher(",
    "hash_pair(",
    "hash_columns(",
    "salt_leaf(",
    "Sha256::new(",
    "sha256_hex(",
];

const READ_ONLY_SITES: [(&str, &str); 14] = [
    ("zkp-core/src/transcript.rs:30", "T1 — the transcript constructor, legacy (unkeyed)"),
    ("zkp-core/src/transcript.rs:41", "T2 — the transcript constructor, tagged (keyed)"),
    ("zkp-core/src/transcript.rs:61", "T3 — a transcript absorb, state ‖ label ‖ data"),
    ("zkp-core/src/transcript.rs:103", "T4a — a transcript squeeze, 47 bytes"),
    ("zkp-core/src/transcript.rs:156-162", "T4b/T4c — `clone_state`, which the position tag and the refusal replay squeeze from"),
    ("zkp-core/src/pcs.rs:139, :149", "P1 — a column digest, single (verify side)"),
    ("zkp-core/src/pcs.rs:171, :196", "P2 — column digests, bulk (commit side)"),
    ("zkp-core/src/pcs.rs:678, :692", "P3 — a salted leaf, blake3(column digest ‖ salt)"),
    ("zkp-core/src/merkle.rs:15, :28", "P4 — a Merkle inner node, blake3(left ‖ right)"),
    ("hashline/src/zk.rs:689, :697", "P5 — the M commitment's column digest"),
    ("zkp-core/src/rng.rs:47", "R1 — the generator's seed derivation (keyed under 32 raw /dev/urandom bytes)"),
    ("zkp-core/src/rng.rs:54", "R2 — the generator's refill, unkeyed, XOF"),
    ("zkp-core/src/hashtag.rs:95-98", "K — the four tag keys, BLAKE3's derive_key mode"),
    ("hashline/src/gpu/kernels.cu:512, :1429", "G1/G2 — the two hand-written CUDA BLAKE3 column kernels (ruling J-3: outside the accepted toy statement's scope; agreement pinned by the differential probe `dev_hash_check`, cuda.rs:2783, and the proof-byte parity gates, NOT by the domain argument)"),
];

#[test]
fn every_hash_call_site_in_the_lanes_own_sources_is_classified() {
    /// is the match at `idx` inside a string literal on this line?
    fn in_string(line: &str, idx: usize) -> bool {
        let b = line.as_bytes();
        let (mut i, mut q) = (0usize, 0usize);
        while i < idx {
            match b[i] {
                b'\\' => i += 1,
                b'"' => q += 1,
                _ => {}
            }
            i += 1;
        }
        q % 2 == 1
    }
    fn count_sites(text: &str, pat: &str) -> usize {
        let mut n = 0usize;
        for line in text.lines() {
            let t = line.trim_start();
            if t.starts_with("//") || (t.starts_with('*') && (t.len() < 2 || t.as_bytes()[1] == b' ' || t.as_bytes()[1] == b'/')) {
                continue;
            }
            let mut from = 0usize;
            while let Some(i) = line[from..].find(pat) {
                let at = from + i;
                if !in_string(line, at) {
                    n += 1;
                }
                from = at + pat.len();
            }
        }
        n
    }

    let mut scanned: Vec<(String, String)> = production_sources();
    for extra in ["src/private_block/run_capture.rs", "src/private_block/run_statement_file.rs", "src/private_block/plane_index.rs"] {
        scanned.push((extra.to_string(), source(extra)));
    }
    let mut found = 0usize;
    let mut classified = 0usize;
    for (path, src) in &scanned {
        let text = production_text(src);
        for pat in ENTRY_POINTS {
            let n = count_sites(text, pat);
            let want = CALL_SITES.iter().find(|(f, p, _, _)| f == path && *p == pat).map(|(_, _, c, _)| *c).unwrap_or(0);
            assert_eq!(
                n, want,
                "{path}: {n} call(s) of `{pat}` and the stage-25 call-kind table declares {want}. A new hash call site must be classified in CALL_SITES with its kind from the memo's §5 before this test passes."
            );
            found += n;
        }
    }
    // every row of the table is real, and every row has a reason
    for (path, pat, want, why) in CALL_SITES {
        assert!(scanned.iter().any(|(f, _)| f == path), "{path} is in the call-kind table and is not scanned");
        assert!(why.len() > 30, "{path}'s `{pat}` row has no call kind: {why}");
        classified += want;
    }
    assert_eq!(found, classified, "the scan and the table disagree on how many sites there are");
    assert!(found >= 18, "the call-site scan found only {found} sites; it has stopped working");
    // the read-only half is an enumeration and is not scanned
    assert_eq!(READ_ONLY_SITES.len(), 14, "the read-only call-kind list moved");
    for (site, kind) in READ_ONLY_SITES {
        assert!(site.contains(':'), "a read-only entry carries no file:line: {site}");
        assert!(kind.len() > 20, "a read-only entry carries no kind: {site}");
    }
    // NON-VACUITY, in test code alone: the scanner sees a real call, skips a
    // comment and skips a string literal
    assert_eq!(count_sites("    let h = blake3::Hasher::new();", "blake3::Hasher::new("), 1);
    assert_eq!(count_sites("    // let h = blake3::Hasher::new();", "blake3::Hasher::new("), 0);
    assert_eq!(count_sites("    let s = \"the unkeyed blake3::Hasher::new()\";", "blake3::Hasher::new("), 0);
    // and the LABEL scan it extends is still there
    assert!(
        source("src/private_block/hash_domain_tests.rs").contains("fn every_absorb_label_on_the_path_is_in_the_table()"),
        "the absorb-label scan this test extends is gone"
    );
    eprintln!("S25 W-11: {found} hash call sites in {} scanned lane sources, every one classified; {} read-only sites listed with file:line", scanned.len(), READ_ONLY_SITES.len());
}

