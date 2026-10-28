//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 7 (2026-10-20): frozen-r9's CLI
//! changes (PR4-15 / 16 / 17, TR6-3) at their edges.** TEST CODE ONLY,
//! reviewer's scratch copy; a child of `token_io::cli_tests` (its `Cli`
//! fixture: the native lane's tiny export, public synthetic data).
//! `REVIEW-R7 CONTROL` lines are asserted; `REVIEW-R7 NOTE` lines printed.

use super::*;
use super::super::cli::{owner_dir_at, read_prompt_file};

fn control(id: &str, what: &str, ok: bool, detail: &str) {
    eprintln!("REVIEW-R7 CONTROL {id} | {what} | {} | {}", detail.chars().take(240).collect::<String>(), if ok { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(ok, "REVIEW-R7 {id} ({what}): {detail}");
}

fn res<T>(r: &Result<T, String>) -> String {
    match r {
        Ok(_) => "ACCEPTED".into(),
        Err(e) => format!("refused: {e}"),
    }
}

/// RV7-1 (PR4-17): the prompt file at its edges.
#[test]
fn rv7_1_the_prompt_file_at_its_edges() {
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("rv7-1");
    let good = cli.prompt_file("good", &cli.prompt, 0o600);
    control("RV7-1a", "a 0600 prompt file", read_prompt_file(good.to_str().unwrap()).is_ok(), &res(&read_prompt_file(good.to_str().unwrap())));
    let ro = cli.prompt_file("ro", &cli.prompt, 0o400);
    control("RV7-1b", "a 0400 prompt file", read_prompt_file(ro.to_str().unwrap()).is_ok(), &res(&read_prompt_file(ro.to_str().unwrap())));
    let grp = cli.prompt_file("grp", &cli.prompt, 0o640);
    let r = read_prompt_file(grp.to_str().unwrap());
    control("RV7-1c", "a 0640 prompt file (group-readable)", r.is_err() && !r.as_ref().unwrap_err().contains(&cli.prompt[..5]), &res(&r));
    let link = cli.owners.join("link.prompt");
    std::os::unix::fs::symlink(&good, &link).unwrap();
    let r = read_prompt_file(link.to_str().unwrap());
    control("RV7-1d", "a symlink to a 0600 prompt file", r.is_err(), &res(&r));
    let fifo = cli.owners.join("fifo.prompt");
    let made = std::process::Command::new("mkfifo").arg(&fifo).status().map(|s| s.success()).unwrap_or(false);
    if made {
        std::fs::set_permissions(&fifo, std::fs::Permissions::from_mode(0o600)).unwrap();
        let r = read_prompt_file(fifo.to_str().unwrap());
        control("RV7-1e", "a FIFO named as the prompt file (must not block)", r.is_err(), &res(&r));
    }
    let empty = cli.prompt_file("empty", "\n", 0o600);
    control("RV7-1f", "an empty prompt file", read_prompt_file(empty.to_str().unwrap()).is_err(), &res(&read_prompt_file(empty.to_str().unwrap())));
    let bad = cli.prompt_file("bad", "1,2,x9y,4", 0o600);
    let r = read_prompt_file(bad.to_str().unwrap());
    control("RV7-1g", "a malformed prompt file; the refusal echoes no entry", r.is_err() && !r.as_ref().unwrap_err().contains("x9y"), &res(&r));
    // `--prompt` anywhere, also as the VALUE of another flag (a false positive, harmless)
    let out = cli.root.join("run-label");
    let pf = cli.prompt_file("lbl", &cli.prompt, 0o600);
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt-file", pf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", cli.owner_dir(&out).to_str().unwrap(), "--label", "--prompt"]));
    eprintln!("REVIEW-R7 NOTE | `--label --prompt` (the word as another flag's value): exit {code}");
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt=1,2,3", "--out", cli.root.join("run-eq").to_str().unwrap()]));
    control("RV7-1h", "`--prompt=ids` (the = form)", code != 0 && !cli.root.join("run-eq").exists(), &format!("exit {code}"));
}

/// RV7-2 (PR4-17): the owner's token file; a second owner call with the
/// default token path.
#[test]
fn rv7_2_the_owner_token_file_and_a_second_call() {
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("rv7-2");
    let out = cli.root.join("run");
    let (code, headers) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "p");
    assert_eq!((code, headers), (0, 1));
    assert_eq!(cli.verify(&out), 0);
    let dec = cli.dec(&out, "output.dec");
    let args = |extra: &[&str]| {
        let mut a = vec!["--export", cli.verifier_copy.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &cli.identity, "--expect-token-profile", &cli.token_profile, "--decommitment", dec.to_str().unwrap(), "--min-bits", "93"];
        a.extend_from_slice(extra);
        s(&a)
    };
    let c1 = token_owner_command(&args(&[]));
    let tf = dec.parent().unwrap().join("next_token");
    let mode = std::fs::metadata(&tf).map(|m| m.permissions().mode() & 0o777).unwrap_or(0);
    control("RV7-2a", "owner with the default token path: next_token beside the decommitment, 0600", c1 == 0 && mode == 0o600 && std::fs::read_to_string(&tf).unwrap().trim() == cli.want_token.to_string(), &format!("exit {c1}, mode {mode:o}"));
    let c2 = token_owner_command(&args(&[]));
    eprintln!("REVIEW-R7 NOTE | a SECOND owner call with the default token path (next_token exists): exit {c2} (after a full re-verification)");
    let c3 = token_owner_command(&args(&["--token-out", cli.owners.join("tok-b").to_str().unwrap()]));
    control("RV7-2b", "owner with a new --token-out", c3 == 0, &format!("exit {c3}"));
    let c4 = token_owner_command(&args(&["--token-out", cli.owners.join("tok-b").to_str().unwrap()]));
    control("RV7-2c", "owner with an EXISTING --token-out is refused (never overwritten)", c4 != 0 && std::fs::read_to_string(cli.owners.join("tok-b")).unwrap().trim() == cli.want_token.to_string(), &format!("exit {c4}"));
}

/// RV7-3 (TR6-3, git's rule): the working-tree test at its edges.
#[test]
fn rv7_3_the_git_rule_at_its_edges() {
    let cli = Cli::new("rv7-3");
    let out = cli.root.join("run");
    let mk = |name: &str| {
        let d = cli.owners.join(name);
        std::fs::create_dir_all(&d).unwrap();
        d
    };
    let stub = mk("stub");
    std::fs::create_dir_all(stub.join(".git").join("info")).unwrap();
    let repo = mk("repo");
    std::fs::create_dir_all(repo.join(".git")).unwrap();
    std::fs::write(repo.join(".git").join("HEAD"), "ref: refs/heads/main\n").unwrap();
    let wt = mk("wt");
    std::fs::write(wt.join(".git"), "gitdir: /elsewhere/.git/worktrees/x\n").unwrap();
    let junk = mk("junk");
    std::fs::write(junk.join(".git"), "not a gitfile\n").unwrap();
    let lnk = mk("lnk");
    std::os::unix::fs::symlink(repo.join(".git"), lnk.join(".git")).unwrap();
    let dangling = mk("dangling");
    std::fs::create_dir_all(dangling.join(".git")).unwrap();
    std::os::unix::fs::symlink("/nonexistent/HEAD", dangling.join(".git").join("HEAD")).unwrap();
    let explicit = |d: &Path| owner_dir_at(&[("--owner-dir".to_string(), d.join("x.owner-private").to_str().unwrap().to_string())], &out, None).map(|_| ());
    for (id, what, d, want_refused) in [
        ("RV7-3a", "a stub .git (no HEAD), as this box's $HOME holds", &stub, false),
        ("RV7-3b", "a .git directory holding HEAD", &repo, true),
        ("RV7-3c", "a .git FILE starting gitdir:", &wt, true),
        ("RV7-3e", "a .git SYMLINK to a repository's .git", &lnk, true),
    ] {
        let r = explicit(d);
        control(id, &format!("explicit --owner-dir under {what}"), r.is_err() == want_refused, &res(&r));
    }
    for (what, d) in [("a .git FILE that is not a gitfile", &junk), ("a .git directory whose HEAD is a dangling symlink", &dangling)] {
        eprintln!("REVIEW-R7 NOTE | explicit --owner-dir under {what}: {}", res(&explicit(d)));
    }
    // the DEFAULT, with $HOME a repository / a stub
    for (id, home, want_refused) in [("RV7-3f", &repo, true), ("RV7-3g", &stub, false)] {
        let run = cli.root.join(format!("run-{id}"));
        let r = owner_dir_at(&[], &run, Some(home)).map(|_| ());
        control(id, &format!("the DEFAULT owner dir with $HOME = {}", home.file_name().unwrap().to_string_lossy()), r.is_err() == want_refused, &res(&r));
    }
}

/// RV7-4 (PR4-16): the owner base's mode when it already exists.
#[test]
fn rv7_4_a_preexisting_owner_base_keeps_its_mode() {
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("rv7-4");
    let home = cli.owners.join("home");
    std::fs::create_dir_all(home.join("zk60-owner-private")).unwrap();
    std::fs::set_permissions(home.join("zk60-owner-private"), std::fs::Permissions::from_mode(0o755)).unwrap();
    let od = owner_dir_at(&[], &cli.root.join("run"), Some(&home)).expect("the default owner dir");
    let m = |p: &Path| std::fs::metadata(p).map(|m| m.permissions().mode() & 0o777).unwrap_or(0);
    eprintln!(
        "REVIEW-R7 NOTE | a pre-existing ~/zk60-owner-private at 0755: after owner_dir_at it is {:o}; token-io/ {:o}; the owner dir (to be created by prove 0700) {}",
        m(&home.join("zk60-owner-private")),
        m(&home.join("zk60-owner-private").join("token-io")),
        od.display()
    );
    let fresh = cli.owners.join("fresh-home");
    std::fs::create_dir_all(&fresh).unwrap();
    owner_dir_at(&[], &cli.root.join("run2"), Some(&fresh)).expect("the default owner dir");
    let (a, b) = (m(&fresh.join("zk60-owner-private")), m(&fresh.join("zk60-owner-private").join("token-io")));
    control("RV7-4", "a fresh owner base: both levels created 0700", (a, b) == (0o700, 0o700), &format!("{a:o} / {b:o}"));
}
