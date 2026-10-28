/* Proven Media demo front end: vanilla JS, hash routes (#/, #/post/<id>, #/ledger, #/about).
   Operating model (D37): each item gets one classifier proof per registered category at creation; the
   proved labels travel with the item in a signed manifest and decide which audiences receive it. */
"use strict";

const $ = (sel, el = document) => el.querySelector(sel);
const S = { cfg: null, handle: "", audience: "adult", hide: [], timer: null, composeKind: "text", lastPostJSON: "" };

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function short(h, n = 12) { return h ? esc(String(h).slice(0, n)) + "…" : "—"; }
function fmtBytes(b) {
  if (b == null) return "—";
  if (b >= 1e9) return (b / 1e9).toFixed(2) + " GB";
  if (b >= 1e6) return (b / 1e6).toFixed(1) + " MB";
  if (b >= 1e3) return (b / 1e3).toFixed(1) + " kB";
  return b + " B";
}
function fmtS(s) { return s == null ? "—" : (s >= 100 ? Math.round(s) : Number(s).toFixed(1)) + " s"; }
function ago(iso) {
  if (!iso) return "";
  const t = Date.parse(iso), d = (Date.now() - t) / 1000;
  if (d < 60) return "just now";
  if (d < 3600) return Math.floor(d / 60) + " min ago";
  if (d < 86400) return Math.floor(d / 3600) + " h ago";
  return new Date(t).toLocaleDateString();
}
function since(ts) { if (!ts) return ""; const d = Math.max(0, Date.now() / 1000 - ts); return d < 60 ? Math.round(d) + " s" : Math.floor(d / 60) + " min " + Math.round(d % 60) + " s"; }
function avatar(handle) {
  let h = 0; for (const c of handle || "") h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const hue = h % 360, ch = (handle || "?").replace("@", "").slice(0, 2).toUpperCase();
  return `<div class="avatar" style="background:hsl(${hue} 55% 45%)">${esc(ch)}</div>`;
}
function row(k, v) { return `<tr><th>${k}</th><td>${v}</td></tr>`; }
const SHIELD = `<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z"/><path fill="#fff" d="m10.5 15.5-3-3 1.4-1.4 1.6 1.6 4.6-4.6 1.4 1.4z"/></svg>`;
const SHIELD_X = `<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z"/><path fill="#fff" d="m9.2 7.8 2.8 2.8 2.8-2.8 1.4 1.4-2.8 2.8 2.8 2.8-1.4 1.4-2.8-2.8-2.8 2.8-1.4-1.4 2.8-2.8-2.8-2.8z"/></svg>`;
const SHIELD_DOTS = `<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z"/><circle cx="8.5" cy="12" r="1.3" fill="#fff"/><circle cx="12" cy="12" r="1.3" fill="#fff"/><circle cx="15.5" cy="12" r="1.3" fill="#fff"/></svg>`;
const CRED = `<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M7 9h6M7 13h4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="16.5" cy="14.5" r="2.5" fill="currentColor"/></svg>`;

async function api(path, opts = {}) {
  const r = await fetch(path, opts);
  const ct = r.headers.get("content-type") || "";
  const body = ct.includes("json") ? await r.json() : await r.text();
  if (!r.ok) throw new Error((body && body.detail) || (body && body.error) || r.statusText);
  return body;
}
function toast(msg, ms = 3800) {
  const t = document.createElement("div"); t.className = "toast"; t.textContent = msg; document.body.appendChild(t);
  setTimeout(() => t.remove(), ms);
}
function isFake() { return S.cfg && S.cfg.prover && S.cfg.prover.kind === "fake"; }
function stubTag() { return isFake() ? `<span class="tag fake">fake: no proof</span>` : `<span class="tag" title="${esc(S.cfg?.prover?.label || "")}">demo stub</span>`; }
function audQuery() { return `audience=${encodeURIComponent(S.audience)}&hide=${encodeURIComponent(S.hide.join(","))}`; }
function audName() { return (S.cfg.audiences[S.audience] || {}).name || S.audience; }
function catName(id) { const c = S.cfg.categories.find(c => c.id === id); return c ? c.short : id; }

/* ---------------------------------------------------------------- frame */
function renderModebar() {
  const mb = $("#modebar"), p = S.cfg.prover;
  if (p.kind === "fake") {
    mb.className = "modebar fake";
    mb.innerHTML = `<div>FAKE PROVER: nothing is proved in this mode (development only). Restart without PM_PROVER=fake for the stub.</div>`;
    return;
  }
  mb.className = "modebar";
  mb.innerHTML = `<div><b>Demo stub:</b> each post gets a real zero-knowledge proof of a 1.1B model run (next-token proof), standing in for its three
    Shieldstral category proofs; the labels shown are not yet bound by the proof. <a href="#/about">What this means</a></div>`;
}
function renderAudiencePill() {
  const el = $("#audpill"); if (!el) return;
  el.innerHTML = `Viewing as <b>${esc(audName())}</b>${S.audience === "adult" && S.hide.length ? ` · hiding ${S.hide.map(catName).join(", ")}` : ""}`;
  el.classList.toggle("minor", S.audience === "minor");
}
function setAudience(a, hide) {
  S.audience = a; if (hide) S.hide = hide;
  try { localStorage.setItem("pm-audience", JSON.stringify({ a: S.audience, hide: S.hide })); } catch (e) {}
  renderAudiencePill(); S.lastPostJSON = ""; router();
}

/* ---------------------------------------------------------------- labels */
function chip(l) {
  const cls = l.value === "no" ? "no" : (l.value === "yes" ? "yes" : "unproved");
  const txt = l.value === "unproved" ? "not proved" : l.value;
  const how = l.value === "unproved" ? "no accepted proof: counts as the most restrictive label" : (l.bound_by_proof ? "proved" : "proof ran (stub); label not bound");
  return `<span class="chip ${cls}" title="${esc(l.name)}: ${esc(how)}">${esc(l.short)}: ${esc(txt)}</span>`;
}
function chips(labels) { return `<span class="chips">${(labels || []).map(chip).join("")}</span>`; }
function credentials(p) {
  const m = p.manifest; if (!m) return "";
  const rows = (m.entries || []).map(e => `<li><b>${esc(catName(e.category))}</b>: ${esc(e.verdict)} · ${e.proof_status === "accepted" ? "proof accepted" : "no proof"}${e.anchor ? " · anchored leaf " + short(e.anchor.leaf_hash, 8) : ""}</li>`).join("");
  return `<details class="cred"><summary title="Proof manifest (content credentials)">${CRED}<span class="sr">credentials</span></summary>
    <div class="cred-pop"><b>Proof manifest</b> <span class="muted">zk60.manifest/1</span><ul>${rows}</ul>
    <div class="muted">Signed (Ed25519) by ${esc(m.issuer && m.issuer.key_id)} · dev key · proved once at creation</div>
    <a href="#/post/${esc(p.id)}">Open the proofs →</a></div></details>`;
}

/* ---------------------------------------------------------------- chunks */
function progressBar(prog) {
  if (!prog || !prog.total) return "";
  const pct = Math.round(100 * (prog.done + prog.failed) / prog.total);
  return `<div class="progress"><div class="bar"><i style="width:${pct}%"></i></div>
    <span class="small muted">${prog.done + prog.failed} of ${prog.total} chunk run${prog.total > 1 ? "s" : ""} done${prog.failed ? ` (${prog.failed} without proof)` : ""} ·
    ${(prog.done + prog.failed) * 3} of ${prog.total * 3} category proofs</span></div>`;
}
function cell(ch, cat) {
  if (ch.status === "done") { const v = ch.labels[cat]; return `<td><span class="chip ${v === "no" ? "no" : (v === "yes" ? "yes" : "unproved")}">${esc(v === "unproved" ? "not proved" : v)}</span></td>`; }
  if (ch.status === "failed") return `<td><span class="chip unproved">no proof</span></td>`;
  if (ch.status === "running") return `<td><span class="cellrun"><span class="spinner"></span> ${ch.waiting_for_machine ? "waiting" : "proving"}</span></td>`;
  return `<td><span class="muted small">queued</span></td>`;
}
function chunkGrid(p, title) {
  const ch = p.chunks || []; if (!ch.length) return "";
  const cats = S.cfg.categories;
  const rows = ch.map(c => `<tr class="${c.status}"><td><b>${c.index + 1}</b></td><td class="mono small">${c.start}–${c.end} <span class="muted">(${c.tokens})</span></td>
    ${cats.map(k => cell(c, k.id)).join("")}<td class="small">${c.status === "running" ? esc(c.step_label || "") : (c.status === "failed" ? `<span class="bad-t">${esc((c.error || "").slice(0, 120))}</span>` : (c.status === "done" ? `<span class="hash">${short(c.statement_sha256, 10)}</span>` : ""))}</td></tr>`).join("");
  const d = S.cfg.deploy;
  return `<section class="card pad"><h2>${esc(title)}</h2>
    <p class="small muted">${ch.length} chunk${ch.length > 1 ? "s" : ""} × ${cats.length} categories = ${ch.length * cats.length} proofs ·
      profile <b>${esc(d.profile)}</b>: ${esc(d.effective_chunk_tokens)}-token chunks, overlap ${esc(d.effective_overlap_tokens)}${d.capped_by_prover ? ` (configured ${esc(d.chunk_tokens)}, capped by the stub's ${esc(S.cfg.limits.stub_chunk_max)}-token run)` : ""} ·
      demo stub: one run per chunk stands in for its 3 category proofs</p>
    ${progressBar(p.job && p.job.progress)}
    <div style="overflow-x:auto"><table class="table grid"><tr><th>chunk</th><th>tokens</th>${cats.map(k => `<th>${esc(k.short)}</th>`).join("")}<th>proof</th></tr>${rows}</table></div>
    <p class="small muted" style="margin-top:6px">A category is <b>yes</b> if any chunk is yes, and <b>not proved</b> if any chunk lacks an accepted proof (fail closed).</p></section>`;
}

/* ---------------------------------------------------------------- feed */
function hiddenCard(p) {
  const why = (p.reasons || []).map(r => `<li><b>${esc(r.label)}</b>: ${esc(r.why)}</li>`).join("");
  return `<article class="card post hidden-post"><div class="post-head"><div class="avatar" style="background:var(--ink-3)">?</div>
    <div><div class="name">Hidden for this audience</div><div class="time">${ago(p.created_at)} · ${esc(p.kind)} · audience: ${esc(p.audience.name)}</div></div></div>
    <p class="small">This item is not sent to viewers in the <b>${esc(p.audience.name)}</b> audience. Its proved labels decide distribution:</p>
    <ul class="small">${why}</ul><div class="post-foot">${chips(p.labels)}</div></article>`;
}
function footFor(p) {
  if (p.status === "published") {
    const anyUnproved = (p.labels || []).some(l => l.value === "unproved");
    return `${chips(p.labels)}${credentials(p)}${stubTag()}
      <a class="checklink" href="#/post/${esc(p.id)}">${anyUnproved ? "Why not proved →" : "Check the proofs yourself →"}</a>`;
  }
  if (p.status === "in-development") return `<span class="badge dev">${SHIELD_DOTS}Pending verification <span class="sub">· image proof path in development</span></span><a class="checklink" href="#/post/${esc(p.id)}">Details →</a>`;
  if (p.status === "deleted") return `<span class="badge dev">${SHIELD_DOTS}Deleted</span>`;
  return `<span class="badge pending">${SHIELD_DOTS}Pending verification…</span><a class="checklink" href="#/post/${esc(p.id)}">Progress →</a>`;
}
function mediaBlock(p) {
  if (p.kind === "image") return `<div class="media video"><div class="veil"><div><strong>Image not visible until its labels are proved</strong>
      <span>Pending verification · image proof path in development</span></div></div></div>`;
  return "";
}
function postCard(p) {
  if (p.hidden) return hiddenCard(p);
  const body = p.kind === "text"
    ? (p.text_hidden ? `<p class="post-text muted"><i>Text not shown.</i></p>` : `<p class="post-text">${esc(p.text)}</p>`)
    : mediaBlock(p);
  return `<article class="card post">
    <div class="post-head">${avatar(p.author)}<div><div class="name">${esc(p.author)}</div><div class="time">${ago(p.created_at)} · ${esc(p.kind)}</div></div></div>
    ${body}<div class="post-foot">${footFor(p)}</div></article>`;
}

function composeHTML() {
  const k = S.composeKind, max = S.cfg.limits.max_content_tokens;
  const tab = (id, label, dev) => `<button class="tab ${k === id ? "on" : ""}" data-kind="${id}">${label}${dev ? ` <span class="pill">in dev</span>` : ""}</button>`;
  let inner;
  if (k === "text") {
    inner = `<label for="ctext" class="sr">Post text</label>
      <textarea id="ctext" maxlength="2000" placeholder="What's happening? Long posts are split into chunks; each chunk is proved in 3 categories (${S.cfg.categories.map(c => esc(c.short)).join(", ")})."></textarea>
      <div class="compose-foot"><span id="counter" class="counter">up to ${max} tokens on the ${esc(S.cfg.deploy.profile)} profile</span>
      <button id="postbtn" class="btn ml-auto" disabled>Post</button></div>`;
  } else {
    const px = S.cfg.image_spec.canvas_px;
    inner = `<div class="drop">Choose an image (PNG, JPEG, WebP or GIF; one per post)<br><input id="cfile" type="file" accept="image/png,image/jpeg,image/webp,image/gif"></div>
      <div id="imgprev" class="imgprev" hidden>
        <figure><img id="prevorig" alt="Your image"><figcaption>Your image (the post)</figcaption></figure>
        <figure><canvas id="prevcanvas" width="${px}" height="${px}"></canvas><figcaption>What the classifier will see: ${px} × ${px} canvas (preview)</figcaption></figure>
      </div>
      <div id="mediaplan" class="small muted" style="margin-top:8px"></div>
      <div class="note stub" style="margin-top:10px">Image proofs are in development: three Shieldstral category proofs over the image's canonical ${px} × ${px} canvas
        (letterboxed, mean-colour margins), bound to the post through a salted input commitment. The image stays pending, visible to you alone,
        until its labels are proved. Fine detail and small text can be lost at ${px} px.</div>
      <div class="compose-foot"><button id="postbtn" class="btn ml-auto" disabled>Post image</button></div>`;
  }
  return `<section class="card pad" id="compose"><div class="tabs">${tab("text", "Text")}${tab("image", "Image", true)}</div>${inner}</section>`;
}

function bindCompose() {
  document.querySelectorAll("#compose .tab").forEach(b => b.onclick = () => { S.composeKind = b.dataset.kind; $("#compose").outerHTML = composeHTML(); bindCompose(); });
  const btn = $("#postbtn");
  if (S.composeKind === "text") {
    const ta = $("#ctext"), ctr = $("#counter"); let tmr = null;
    ta.oninput = () => {
      clearTimeout(tmr);
      tmr = setTimeout(async () => {
        if (!ta.value.trim()) { ctr.textContent = `up to ${S.cfg.limits.max_content_tokens} tokens on the ${S.cfg.deploy.profile} profile`; btn.disabled = true; return; }
        try {
          const r = await api("/api/tokenize", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ text: ta.value }) });
          ctr.textContent = r.fits
            ? `${r.count} tokens → ${r.chunks} chunk${r.chunks > 1 ? "s" : ""} × 3 categories = ${r.proofs} proofs (profile ${r.profile}: ${r.chunk_tokens}-token chunks, overlap ${r.overlap_tokens})`
            : `${r.count} tokens: too long for this deployment profile (at most ${r.max} tokens; the whole post is proved or nothing)`;
          ctr.classList.toggle("over", !r.fits); btn.disabled = !r.fits;
        } catch (e) { ctr.textContent = "could not count tokens"; }
      }, 220);
    };
    btn.onclick = async () => {
      if (!requireHandle()) return;
      btn.disabled = true;
      const fd = new FormData(); fd.append("author", S.handle); fd.append("kind", "text"); fd.append("text", ta.value);
      try {
        const r = await api("/api/posts", { method: "POST", body: fd });
        ta.value = ""; ta.oninput();
        toast(`Pending verification: ${r.proofs} proofs (${r.chunks} chunk${r.chunks > 1 ? "s" : ""} × 3 categories). Your post appears once its labels are proved.`);
        location.hash = `#/post/${r.post_id}`;
      } catch (e) { toast(e.message, 6000); btn.disabled = false; }
    };
  } else {
    const fi = $("#cfile"), plan = $("#mediaplan");
    fi.onchange = () => {
      const f = fi.files[0]; btn.disabled = !f; plan.textContent = "";
      $("#imgprev").hidden = !f;
      if (!f) return;
      const url = URL.createObjectURL(f), img = $("#prevorig");
      img.onload = () => {
        // approximate letterbox preview (the server computes the exact canonical canvas at upload)
        const px = S.cfg.image_spec.canvas_px, fill = S.cfg.image_spec.fill_rgb, cv = $("#prevcanvas"), g = cv.getContext("2d");
        g.fillStyle = `rgb(${fill.join(",")})`; g.fillRect(0, 0, px, px);
        const sc = px / Math.max(img.naturalWidth, img.naturalHeight), w = Math.max(1, Math.round(img.naturalWidth * sc)), h = Math.max(1, Math.round(img.naturalHeight * sc));
        g.imageSmoothingQuality = "high"; g.drawImage(img, Math.floor((px - w) / 2), Math.floor((px - h) / 2), w, h);
        plan.textContent = `${f.name} · ${img.naturalWidth} × ${img.naturalHeight} px · ${fmtBytes(f.size)} · 3 label proofs needed · the exact canvas is computed on upload (${S.cfg.image_spec.id})`;
      };
      img.src = url;
    };
    btn.onclick = async () => {
      if (!requireHandle()) return;
      const f = fi.files[0]; if (!f) return; btn.disabled = true;
      const fd = new FormData(); fd.append("author", S.handle); fd.append("kind", "image"); fd.append("file", f);
      try { const r = await api("/api/posts", { method: "POST", body: fd }); toast(r.message || "Stored."); location.hash = `#/post/${r.post_id}`; }
      catch (e) { toast(e.message, 6000); btn.disabled = false; }
    };
  }
}
function requireHandle() {
  if (S.handle) return true;
  toast("Choose a handle first (top right)."); $("#handle").focus(); return false;
}

function audiencePanel() {
  const cats = S.cfg.categories;
  return `<h3>Your audience</h3>
    <div class="seg"><button class="${S.audience === "adult" ? "on" : ""}" data-aud="adult">Adult</button><button class="${S.audience === "minor" ? "on" : ""}" data-aud="minor">Minor (under 18)</button></div>
    ${S.audience === "adult" ? `<p class="small" style="margin:10px 0 4px">Also hide items labelled (or not proved):</p>
      ${cats.map(c => `<label class="small check"><input type="checkbox" data-hide="${esc(c.id)}" ${S.hide.includes(c.id) ? "checked" : ""}> ${esc(c.name)}</label>`).join("")}`
      : `<p class="small" style="margin-top:10px">Minors receive only items proved <b>no</b> in all three categories. A category without an accepted proof counts as <b>yes</b> (fail closed).</p>`}`;
}
function bindAudience() {
  document.querySelectorAll("[data-aud]").forEach(b => b.onclick = () => setAudience(b.dataset.aud));
  document.querySelectorAll("[data-hide]").forEach(cb => cb.onchange = () => {
    const h = Array.from(document.querySelectorAll("[data-hide]:checked")).map(x => x.dataset.hide); setAudience("adult", h);
  });
}

async function viewFeed() {
  $("#app").innerHTML = `<div class="grid"><div class="stack">${composeHTML()}<div id="feed" class="stack"><div class="card empty">Loading…</div></div></div>
    <aside class="side"><section class="card pad panel" id="audience">${audiencePanel()}</section>
    <section class="card pad panel" id="queue"></section><section class="card pad panel" id="subs"></section>
    <section class="card pad panel"><h3>What the labels mean</h3><p class="small">Each item is classified once, at creation, in three categories by a classifier inside
    zero-knowledge proofs. Every label (yes or no) is published with its proof and travels with the item in a signed manifest; the labels decide who receives it.
    Anyone can check the proofs without the proofs revealing the item.</p>
    <p class="small muted">In this demo one next-token stub proof stands in for the three classifier proofs.</p></section></aside></div>`;
  bindCompose(); bindAudience();
  await refreshFeed();
}
async function refreshFeed() {
  const [feed] = await Promise.all([api(`/api/feed?${audQuery()}`), refreshQueue(), refreshSubs()]);
  const el = $("#feed"); if (!el) return;
  const html = feed.posts.length ? feed.posts.map(postCard).join("") : `<div class="card empty">No posts yet. Write the first one.</div>`;
  if (el.dataset.h !== html) { el.innerHTML = html; el.dataset.h = html; }
}
async function refreshQueue() {
  const el = $("#queue"); if (!el) return;
  const q = await api("/api/queue");
  el.innerHTML = queueHTML(q, true);
}
function queueHTML(q, compact) {
  const r = q.running, g = q.guard || {};
  let body = "";
  if (q.held) body += `<div class="note stub">Queue paused by the project coordinator (HOLD file).</div>`;
  if (r) {
    body += `<div class="qitem now"><div class="small"><b>${r.kind === "prove" ? `Proving chunk ${r.chunk + 1} of ${r.chunks}` : `Re-checking chunk ${r.chunk + 1}`}</b>
      · <a href="#/post/${esc(r.post_id)}">${esc(r.post_id.slice(0, 10))}…</a></div>
      <div class="small muted">${esc(r.label)}${r.step_since ? ` (${since(r.step_since)})` : ""}</div>${r.kind === "prove" ? progressBar(r.progress) : ""}</div>`;
  } else body += `<p class="small muted">Idle: no proof running.</p>`;
  const items = q.queued || [];
  if (items.length) {
    body += `<p class="small" style="margin:10px 0 4px"><b>${q.queued_jobs}</b> job${q.queued_jobs > 1 ? "s" : ""} waiting · one proof job at a time</p>`;
    body += items.slice(0, compact ? 4 : 50).map(it => `<div class="qitem"><div class="small">#${it.position} · <a href="#/post/${esc(it.post_id)}">${esc(it.post_id.slice(0, 10))}…</a> ·
      ${it.kind === "prove" ? `${it.jobs} chunk run${it.jobs > 1 ? "s" : ""} (${it.jobs * 3} proofs)` : `${it.jobs} re-check${it.jobs > 1 ? "s" : ""}`}
      <span class="muted">· done in ~${Math.max(1, Math.round(it.eta_s / 60))} min</span></div></div>`).join("");
    if (compact && items.length > 4) body += `<p class="small muted">… and ${items.length - 4} more (see <a href="#/status">Status</a>)</p>`;
  }
  body += `<dl class="kv" style="margin-top:10px"><dt>Machine</dt><dd>${esc(g.ram || "—")}</dd><dt>Guard budget</dt><dd>${esc(g.budget || "—")}</dd><dt>Locks</dt><dd>${esc(g.locks || "—")}</dd></dl>`;
  return `<h3><span class="dot ${r ? (r.waiting_for_machine ? "wait" : "live") : ""}"></span>Verification queue</h3>${body}`;
}
async function refreshSubs() {
  const el = $("#subs"); if (!el) return;
  if (!S.handle) { el.innerHTML = `<h3>Your submissions</h3><p class="small muted">Choose a handle (top right) to post and follow your submissions.</p>`; return; }
  const r = await api(`/api/submissions?author=${encodeURIComponent(S.handle)}`);
  const items = r.posts.map(p => {
    const snip = p.kind === "text" ? esc(p.text) : `<i>${esc(p.kind)} post</i>`;
    let prog = "";
    if (p.job && (p.job.status === "running" || p.job.status === "queued")) prog = `<div class="muted">${p.job.status === "running" ? `chunk ${(p.job.chunk || 0) + 1}: ${esc(p.job.step_label || "")}` : "queued"}${p.job.eta_s != null ? ` · ~${Math.max(1, Math.round(p.job.eta_s / 60))} min left` : ""}</div>${progressBar(p.job.progress)}`;
    else if (p.status === "published") prog = `<div>${chips(p.labels)}</div>`;
    const label = { "in-development": "pending verification", queued: "pending verification", screening: "pending verification", published: "labelled" }[p.status] || p.status;
    return `<li><span class="status ${esc(p.status)}">${esc(label)}</span> · <a href="#/post/${esc(p.id)}">${esc(p.id.slice(0, 12))}…</a>
      <div class="snip">${snip}</div>${prog}</li>`;
  }).join("");
  el.innerHTML = `<h3>Your submissions</h3>${items ? `<ul class="sub-list">${items}</ul>` : `<p class="small muted">Nothing yet.</p>`}`;
}

/* ---------------------------------------------------------------- proof page */
const PROVE_STEPS = [["seqgen", "Prepare the hidden input"], ["prove", "Prove (model run on the hidden post)"],
  ["verify", "Verify from public files only"], ["owner", "Platform opens the sealed output"], ["inowner", "Check the proof is about this post"], ["publish", "Publish the labels, anchor, sign the manifest"]];

function stepsHTML(job) {
  const cur = job && job.status === "running" ? job.step : null;
  const idx = cur ? PROVE_STEPS.findIndex(s => s[0] === cur) : -1;
  return `<ol class="steps">${PROVE_STEPS.map(([k, label], i) => {
    const cls = idx < 0 ? "" : (i < idx ? "done" : (i === idx ? "now" : ""));
    return `<li class="${cls}"><span class="ic">${cls === "done" ? "✓" : ""}</span>${esc(label)}${cls === "now" && job.waiting_for_machine ? ` <span class="muted small">(waiting for the shared machine)</span>` : ""}</li>`;
  }).join("")}</ol>`;
}

function honestLimits() {
  return `<ul class="limits small">
    <li><b>Demo stub.</b> One next-token proof of TinyLlama-1.1B stands in for the three Shieldstral-1.0-3B category proofs. It proves the approved
      model ran on the hidden post; each label comes from a placeholder keyword list and is <b>not</b> bound by the proof.</li>
    <li><b>Text only; long posts in chunks.</b> On the laptop profile a post is split into chunks of at most 31 tokens (the stub's cap of the configured 40),
      overlap 8, at most 4 chunks; each chunk is proved separately. Image proofs are in development (video and audio are deferred).</li>
    <li><b>Slow.</b> About 2.5 minutes of work per chunk on a laptop CPU, plus any wait for the shared machine; verifying takes about 15 s
      per chunk. Shieldstral is estimated at 3–5 min per category proof of a 64-token chunk, so N chunks × 3 proofs per item. The product target (≥ 50 proved tokens/s on a high-end GPU) is far away.</li>
    <li><b>Privacy not certified.</b> The proofs are designed so a verifier learns nothing about the item beyond its labels, but no privacy acceptance covers this artifact.</li>
    <li><b>Binding to the shown text</b> is checked by the platform with its private opening (D21). A viewer can check the signed manifest's salted
      commitment against the text, but that commitment is not yet tied inside the proof to its hidden input.</li>
    <li><b>Soundness</b> about 2<sup>-95</sup> per run (the MVP level), not 128-bit. The integer model is less accurate than the original (about 1.2–1.3× perplexity).</li>
    <li><b>Publication.</b> ${esc(S.cfg.publisher.description)} Manifests use an Ed25519 development signing key.</li>
    <li><b>Operating rules.</b> Each item is proved once per category, at creation, and never re-proved. A category without an accepted proof counts as the most
      restrictive label (hidden from restricted audiences). The category policies are short placeholders until the exact texts land. The content length in tokens is public (pending the project lead).</li>
    <li>Research prototype: internal review rounds only, no external audit; single-user demo, no accounts.</li></ul>`;
}

function labelsHero(p, rec) {
  if (p.status === "published") {
    const unp = (p.labels || []).filter(l => l.value === "unproved");
    const fake = rec && rec.prover.kind === "fake";
    if (unp.length === (p.labels || []).length) {
      return `<section class="card hero unsafe"><div class="seal">${SHIELD_X}</div><div><h1>Labels not proved</h1>
        <p>${esc(p.status_message || "No accepted proof.")}</p>
        <p class="small">Fail closed: every category counts as the most restrictive label, so this item is hidden from restricted audiences (for example minors).
        It is not re-proved.${p.retry_allowed ? " The prover never ran on it (the shared machine was busy), so it may be submitted again." : ""}</p>
        <div style="margin-top:8px">${chips(p.labels)}</div></div></section>`;
    }
    return `<section class="card hero"><div class="seal">${SHIELD}</div><div><h1>Labelled: ${(p.labels || []).map(l => esc(l.short) + " " + esc(l.value === "unproved" ? "not proved" : l.value)).join(" · ")}</h1>
      <p class="muted">Classified by ${esc(S.cfg.classifier.name)} in ${(p.labels || []).length} registered categories · <b>proved once, at creation: ${esc((rec && (rec.proved_at || rec.created_at)) || "")}</b> ·
        published ${ago(p.published_at)}</p>
      <div style="margin:6px 0 10px">${chips(p.labels)}</div>
      ${p.status_message ? `<div class="note bad" style="margin-bottom:8px">${esc(p.status_message)}</div>` : ""}
      <div class="note ${fake ? "bad" : "stub"}">${fake ? "FAKE PROVER: nothing was proved for this post." :
        `<b>Demo stub: next-token proof, classifier proofs coming.</b> A real zero-knowledge proof was made and verified for this post: it shows the approved
        ${esc(rec && rec.prover ? rec.prover.model : "")} ran on each hidden chunk. Each run stands in for that chunk's three category proofs; the labels themselves come from a placeholder and are not yet bound by the proof.`}</div></div></section>`;
  }
  if (p.status === "deleted") return `<section class="card hero dev"><div class="seal">${SHIELD_DOTS}</div><div><h1>Deleted</h1><p>${esc(p.status_message || "")}</p></div></section>`;
  if (p.status === "in-development") {
    return `<section class="card hero dev"><div class="seal">${SHIELD_DOTS}</div><div><h1>Pending verification</h1>
      <p>${esc(p.status_message || "")}</p><p class="muted small">The image's three labels cannot be proved yet, so it is visible to you alone.
      It will be distributed once its labels are proved.</p></div></section>`;
  }
  const j = p.job || {};
  const prog = j.progress || { total: (p.chunks || []).length, done: 0, failed: 0 };
  const pos = j.status === "running" ? `Proving chunk ${(j.chunk || 0) + 1} of ${prog.total}: ${j.step_label || ""}` : `Queued${j.ahead ? ` behind ${j.ahead} job${j.ahead > 1 ? "s" : ""}` : ""}`;
  const eta = j.eta_s != null ? ` · about ${Math.max(1, Math.round(j.eta_s / 60))} min left (if the shared machine is free)` : "";
  return `<section class="card hero pending"><div class="seal">${SHIELD_DOTS}</div><div style="flex:1"><h1>Pending verification</h1>
    <p>Proving this item's labels, once, at creation: ${prog.total} chunk${prog.total > 1 ? "s" : ""} × 3 categories. It is distributed only when every chunk's proofs are done.</p>
    <p class="muted">${esc(pos)}${j.waiting_for_machine ? " (waiting for the shared machine)" : ""}${eta}${j.step_since ? ` · this step ${since(j.step_since)}` : ""}</p>
    ${progressBar(prog)}
    ${j.status === "running" ? stepsHTML({ status: "running", step: j.step, waiting_for_machine: j.waiting_for_machine }) : ""}
    <p class="small muted">Minutes per chunk are expected (${esc(S.cfg.expected.stub_work_s)} per stub run). You can leave this page; the jobs run detached, one at a time.</p></div></section>`;
}

function labelsTable(p, rec) {
  const pols = {}; ((rec && rec.policies) || S.cfg.categories.map(c => ({ ...c.policy, category: c.id }))).forEach(x => { pols[x.category] = x; });
  const anchors = (p.publication && p.publication.anchors) || {};
  const rows = (p.labels || []).map(l => {
    const pol = pols[l.category] || {};
    const mine = Object.values(anchors).filter(x => x.category === l.category);
    const a = mine.length ? { status: mine.every(x => x.status === "anchored") ? "anchored" : "pending", block_number: mine.map(x => x.block_number).filter(x => x != null).join(", ") } : null;
    const per = ((rec && rec.labels && rec.labels[l.category] && rec.labels[l.category].chunks) || []);
    const yesIn = per.filter(x => x.value === "yes").map(x => x.index + 1), unpIn = per.filter(x => x.value === "unproved").map(x => x.index + 1);
    const proof = (unpIn.length ? `<span class="bad-t">no proof in chunk ${unpIn.join(", ")}</span> <span class="muted">(counts as yes)</span>`
      : `<span class="ok-t">accepted in all ${per.length || 1} chunk${per.length > 1 ? "s" : ""}</span>${l.bound_by_proof ? "" : ` <span class="muted">(stub, label not bound)</span>`}`)
      + (yesIn.length ? `<div class="small">yes in chunk ${yesIn.join(", ")}</div>` : "");
    return `<tr><td><b>${esc(l.name)}</b></td><td>${chip(l)}</td><td>${proof}</td>
      <td>${esc(l.policy_id)} <span class="hash">${short(l.policy_sha256, 10)}</span>${pol.text ? `<details><summary class="small">policy text</summary><pre class="code">${esc(pol.text)}</pre></details>` : ""}</td>
      <td>${a ? (a.status === "anchored" ? `block ${esc(a.block_number)}` : "pending batch") : "—"}</td></tr>`;
  }).join("");
  const th = (rec && rec.threshold) || S.cfg.threshold;
  return `<section class="card pad"><h2>Labels: per category, over every chunk</h2>
    <div style="overflow-x:auto"><table class="table"><tr><th>category</th><th>label</th><th>proofs</th><th>policy (registered)</th><th>anchors</th></tr>${rows}</table></div>
    <p class="small muted" style="margin-top:8px">Decision rule: ${esc(th.rule)} (τ = ${esc(th.tau)}, c = ${esc(Number(th.c).toFixed(3))}). One fixed policy and one threshold per category; never re-proved.</p></section>`;
}

function manifestSection(p) {
  const m = p.manifest; if (!m) return "";
  return `<section class="card pad stack" id="manifest"><h2>Proof manifest <span class="muted small">zk60.manifest/1 · content credentials</span></h2>
    <p class="small">Attached to this item whenever it is served: one entry per category (model, policy, label, statement hash, bundle and anchor references,
    salted content commitment), signed with the app's publisher key (Ed25519, key id <span class="hash">${esc(m.issuer && m.issuer.key_id)}</span>, <b>local development key</b>).</p>
    <div><button class="btn ghost small" id="vmanbtn">Verify manifest</button> <a class="btn ghost small" href="/api/posts/${esc(p.id)}/manifest.json?${S.handle ? "author=" + encodeURIComponent(S.handle) + "&" : ""}${audQuery()}">Download ${esc(p.id.slice(0, 8))}….manifest.json</a>
      <span class="small muted">signature, then each entry's anchor and Merkle path in the ledger</span></div>
    <div id="vmanout" class="small"></div>
    <details><summary class="small">Manifest JSON</summary><pre class="code">${esc(JSON.stringify(m, null, 1))}</pre></details></section>`;
}

function anchorSection(p) {
  const pub = p.publication;
  if (!pub) return `<section class="card pad"><h2>Anchored at</h2><p class="small muted">No published proof (only accepted label proofs are anchored).</p></section>`;
  const rows = Object.entries(pub.anchors).map(([k, a]) => `<tr><td>chunk ${esc(a.chunk + 1)} · ${esc(catName(a.category))}</td><td>${a.status === "anchored" ? `block ${esc(a.block_number)} · ${esc(a.batch_id)}` : "pending"}</td>
    <td><span class="hash">${short(a.leaf_hash, 14)}</span> ${a.leaf_index != null ? `<span class="muted">#${esc(a.leaf_index)}</span>` : ""}</td>
    <td>${a.merkle_root ? `<span class="hash">${short(a.merkle_root, 12)}</span> <span class="muted">${(a.merkle_proof || []).length}-step path</span>` : "—"}</td></tr>`).join("");
  const any = Object.values(pub.anchors)[0] || {};
  const pend = Object.values(pub.anchors).some(a => a.status === "pending");
  return `<section class="card pad"><h2>Anchored at</h2>
    <p>${pend ? `<span class="badge pending">${SHIELD_DOTS}anchoring pending</span> <span class="small muted">next batch in ~${Math.ceil((pub.next_batch_in_s || 0) / 60)} min (every ${Math.round(pub.batch_secs / 60)} min or 1,000 leaves)</span>`
      : `<span class="badge">${SHIELD}anchored</span>`} <span class="tag">${any.chain === "base-sepolia" ? "Base Sepolia testnet" : "local stub"}</span></p>
    <p class="small muted">${esc(any.chain || "")} · <span class="mono">${esc(any.contract || "")}</span> · tx <span class="hash">${short(any.tx_hash, 12)}</span></p>
    <div style="overflow-x:auto;max-height:340px"><table class="table"><tr><th>proof</th><th>block</th><th>leaf</th><th>Merkle root</th></tr>${rows}</table></div>
    <p style="margin-top:10px"><button class="btn ghost small" id="vpubbtn">Verify publication</button>
    <span class="small muted">store, manifests, leaves, Merkle paths and block chain, from public data only</span></p>
    <div id="vpubout" class="small"></div>
    <p class="small muted" style="margin-top:8px">${esc(S.cfg.publisher.description)}</p></section>`;
}

function commitmentSection(p) {
  const pub = p.publication;
  if (!pub || !pub.salt) return "";
  return `<section class="card pad"><h2>Salted content commitment</h2>
    <p class="small">The manifest and the anchors carry <span class="hash">${short(pub.content_commitment, 24)}</span>, a salted hash of this post. The salt is served to
    viewers with the item so anyone can check the commitment is this text; without the salt it reveals nothing (deleting the post erases the salt).</p>
    <table class="table">${row("Rule", `<span class="mono">${esc(pub.content_commitment_rule)}</span>`)}${row("Salt (256-bit)", `<span class="hash">${esc(pub.salt)}</span>`)}</table>
    <p style="margin-top:8px"><button class="btn ghost small" id="ccbtn">Check it in my browser</button> <span id="ccout" class="small"></span></p></section>`;
}

async function checkCommitment(p) {
  const enc = new TextEncoder(), dom = enc.encode("zk60/proven-media/content/v1"), body = enc.encode(p.text);
  const salt = new Uint8Array(p.publication.salt.match(/../g).map(h => parseInt(h, 16)));
  const len = new Uint8Array(8); new DataView(len.buffer).setBigUint64(0, BigInt(body.length));
  const buf = new Uint8Array(dom.length + 32 + 8 + body.length);
  buf.set(dom, 0); buf.set(salt, dom.length); buf.set(len, dom.length + 32); buf.set(body, dom.length + 40);
  const h = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", buf))).map(b => b.toString(16).padStart(2, "0")).join("");
  return h === p.publication.content_commitment;
}

function verifySection(p, rec) {
  if (!rec || p.status !== "published") return "";
  const vw = rec.verify_with || {};
  const last = (p.checks || [])[0];
  let lastHTML = "";
  if (p.recheck) lastHTML = `<div class="note info"><span class="spinner"></span> ${esc(p.recheck.status === "queued" ? "Queued…" : (p.recheck.step_label || "Checking…"))}${p.recheck.waiting_for_machine ? " (waiting for the shared machine)" : ""}</div>`;
  else if (last) {
    const latest = {}; (p.checks || []).forEach(c => { const k = (c.verdict && c.verdict.chunk) || 0; if (!(k in latest)) latest[k] = c; });
    lastHTML = Object.entries(latest).sort((a, b) => a[0] - b[0]).map(([k, c]) => { const d = (c.verdict || {}).details || {};
      return c.ok ? `<div class="note ok"><b>Chunk ${+k + 1}: proof valid.</b> Re-verified ${ago(c.at)} in a fresh process from the public files only: ${fmtS(d.verify_seconds)} ·
         security floor ${esc(d.whole_run_floor_bits)} bits (≥ ${esc(d.min_bits)} required) · statement re-checked byte for byte${d.content_binding ? " · binding to this post confirmed by the platform" : ""}. Nothing was re-proved.</div>`
        : `<div class="note bad"><b>Chunk ${+k + 1}: check failed.</b> ${esc((d.message || "") + " " + (d.detail || ""))}</div>`; }).join("");
  } else {
    lastHTML = `<div class="note ok">Every chunk's proof was verified in a fresh process when it was proved.</div>`;
  }
  return `<section class="card pad stack" id="verify"><h2>Check the proof yourself</h2>
    <div><button class="btn" id="verifybtn" ${p.recheck ? "disabled" : ""}>Re-verify now</button>
      <span class="small muted">runs the verifier again on this server in a fresh process for every chunk (about 15 s of work each, through the shared machine's guard); it re-checks, it never re-proves</span></div>
    ${lastHTML}
    <div><b class="small">Or verify on your own machine</b>
      <p class="small">Download the bundle (${fmtBytes(rec.receipt.bytes)}: the receipt, the published statement, the record and the manifest) and run the public verifier:</p>
      <p><a class="btn ghost small" href="/api/posts/${esc(p.id)}/bundle.tar">Download bundle (.tar, ${fmtBytes(rec.receipt.bytes)})</a>
         <a class="btn ghost small" href="/api/posts/${esc(p.id)}/record.json">Download record.json</a></p>
      <pre class="code">${esc(vw.command || "")}</pre>
      <p class="small muted">Binary: ${esc(vw.binary || "")}. Public model files: ${esc(vw.public_model_files || "")}. Accept if ${esc(vw.accept_if || "")}.</p></div></section>`;
}

function chunkRecords(rec) { return ((rec && rec.chunks) || []).filter(c => c.record).map(c => c.record); }

function publicTable(rec) {
  const first = chunkRecords(rec)[0] || {};
  const pr = rec.prover || {}, sec = first.security || {}, cc = first.content_commitment || {};
  const ch = rec.chunking || {};
  return `<section class="card pad"><h2>What is public</h2><table class="table">
    ${row("Labels", "one per registered category, aggregated over the chunks; each chunk × category has its own proof (above)")}
    ${row("Classifier (target)", `${esc(S.cfg.classifier.name)} <span class="muted">· ${esc(S.cfg.classifier.status)}</span>`)}
    ${row("Model proved (stub)", esc(pr.model || "—"))}
    ${row("Model identity", `<span class="hash">${short(pr.model_digest, 24)}</span> <span class="muted">statement identity, pinned by the approval record</span>`)}
    ${row("Token profile", `<span class="hash">${short(pr.token_profile_digest, 24)}</span>`)}
    ${row("Category set", `${esc(S.cfg.category_set.id)} <span class="hash">${short(S.cfg.category_set.digest, 16)}</span>`)}
    ${row("Content length", `${esc(rec.content_length)} tokens <span class="muted">(public by the design rule, pending the project lead)</span>`)}
    ${row("Chunking", `${esc(ch.n_chunks)} chunk${ch.n_chunks > 1 ? "s" : ""} of ≤ ${esc(ch.chunk_tokens)} tokens, overlap ${esc(ch.overlap_tokens)} (profile ${esc(ch.profile)})`)}
    ${row("Hidden-input commitments (in the proofs)", `one per chunk, inside each statement (first: <span class="hash">${short(cc.value, 16)}</span>); ${esc(cc.kind || "")}. Not put in the anchors (O-2 / D23).`)}
    ${row("Receipts", `${esc(rec.receipt.segments)} sealed segments in total · ${fmtBytes(rec.receipt.bytes)}`)}
    ${row("Security floor", `${esc(sec.whole_run_floor_bits)} bits per run <span class="muted">(verifier requires ${esc(sec.min_bits_required)}; ${esc(sec.note || "")})</span>`)}
  </table></section>`;
}

function privateList() {
  return `<section class="card pad"><h2>What stays private</h2><ul class="small">
    <li>The post's tokens as the proof's input: a 0600 file on the platform, never on a command line or in a log.</li>
    <li>Every intermediate number of the model run (the hidden activations are deleted after proving).</li>
    <li>The openings of the input and output commitments (held by the platform; never in a bundle, D21).</li>
    <li>The stub's opened next token; the classifier's confidence scores (only the labels are published).</li>
    <li>The content itself from any audience its labels exclude: hidden items are served as placeholders only.</li></ul></section>`;
}

function timingStats(rec) {
  const recs = chunkRecords(rec);
  if (!recs.length) return "";
  const sum = (f) => recs.reduce((a, r) => a + (f(r) || 0), 0);
  const waited = sum(r => Object.values((r.timings || {}).waited_for_machine_s || {}).reduce((a, b) => a + (b || 0), 0));
  const peak = Math.max(...recs.flatMap(r => Object.values((r.timings || {}).peak_rss_gib || {}).filter(x => x != null)), 0);
  const rows = recs.map(r => { const t = r.timings || {}, c = r.chunk || {};
    return `<tr><td>${esc((c.index || 0) + 1)}</td><td>${fmtS(t.seqgen_s)}</td><td>${fmtS(t.prove_s)} <span class="muted">(${fmtS(t.prove_with_loading_s)})</span></td><td>${fmtS(t.verify_s)}</td><td>${fmtBytes(r.receipt.bytes)}</td><td class="small">${esc(r.proved_at || "")}</td></tr>`; }).join("");
  return `<section class="card pad"><h2>Timings and sizes</h2><div class="stats">
    <div class="stat"><b>${fmtS(sum(r => (r.timings || {}).prove_s))}</b><span>proving, all chunks</span></div>
    <div class="stat"><b>${fmtS(sum(r => (r.timings || {}).verify_s))}</b><span>verifying, all chunks</span></div>
    <div class="stat"><b>${fmtBytes(rec.receipt.bytes)}</b><span>proof size, ${esc(rec.receipt.segments)} segments</span></div>
    <div class="stat"><b>${fmtS(rec.timings && rec.timings.work_s)}</b><span>all steps (work); ${fmtS(waited)} waiting for the machine</span></div></div>
    <div style="overflow-x:auto"><table class="table" style="margin-top:12px"><tr><th>chunk</th><th>prepare</th><th>prove (with loading)</th><th>verify</th><th>proof</th><th>proved at</th></tr>${rows}</table></div>
    <p class="small muted">Peak memory (largest step) ${peak ? peak.toFixed(2) + " GiB" : "—"} · laptop CPU (Intel Core Ultra 9 185H), no GPU; shared box, n = 1 · ${esc((recs[0].prover || {}).cli || "")}</p></section>`;
}

function imagePlan(p) {
  const m = p.media || {}, px = m.canvas_px || S.cfg.image_spec.canvas_px;
  const mine = S.handle && ("@" + S.handle) === p.author;
  return `<section class="card pad"><h2>Planned proofs</h2>
    ${mine ? `<div class="imgprev"><figure><img src="/api/posts/${esc(p.id)}/canvas.png?author=${encodeURIComponent(S.handle)}" alt="canonical canvas" width="${px}" height="${px}">
      <figcaption>The exact canonical canvas the classifier will see (shown to you, the author, only)</figcaption></figure></div>` : ""}
    <table class="table">
    ${row("Proofs needed", `3 (one per category), over the canonical ${px} × ${px} canvas`)}
    ${row("Classifier", `${esc(S.cfg.classifier.name)}: Pixtral vision encoder + text decoder, the three registered category policies`)}
    ${row("Canonical pipeline", `<span class="small">${esc(S.cfg.image_spec.text)}</span>`)}
    ${row("Binding", `the run's hidden input endpoint (planned); today the app keeps a salted commitment to the canonical tensor
      <span class="hash">${short(m.salted_commitment, 20)}</span>`)}
    ${row("Image", m.width ? `${m.width} × ${m.height} px master (lossless PNG, EXIF orientation applied, metadata dropped)` : "—")}
    ${row("New prover relations", "non-causal attention, 2D RoPE, GELU, patch embedding, 2×2 merge")}
    ${row("What it cannot see", "detail lost at the canvas size; text in the image too small to read; anything outside the image (captions are separate)")}
    ${row("Status", "in development (design: results/zk60_multimodal_design_20261021/)")}</table></section>`;
}

function hiddenPage(p) {
  const why = (p.reasons || []).map(r => `<li><b>${esc(r.label)}</b>: ${esc(r.why)}</li>`).join("");
  return `<div id="postpage" class="stack" style="padding:20px 0 32px"><a href="#/" class="small">← Feed</a>
    <section class="card hero dev"><div class="seal">${SHIELD_DOTS}</div><div><h1>Hidden for this audience</h1>
    <p>This item is not sent to viewers in the <b>${esc(p.audience.name)}</b> audience. Its proved labels decide distribution:</p><ul>${why}</ul>
    <div style="margin-top:8px">${chips(p.labels)}</div>
    <p class="small muted" style="margin-top:8px">Switch the audience (top right) to see how distribution changes. The content is not served to this audience at all.</p></div></section></div>`;
}

async function viewPost(id) {
  const q = `?${S.handle ? "author=" + encodeURIComponent(S.handle) + "&" : ""}${audQuery()}`;
  let p;
  try { p = await api(`/api/posts/${encodeURIComponent(id)}${q}`); }
  catch (e) { $("#app").innerHTML = `<div class="card empty" style="margin-top:20px">${esc(e.message)}</div>`; return; }
  const live = p.status === "queued" || p.status === "screening" || p.recheck;
  const anc = p.publication ? Object.values(p.publication.anchors).map(a => a.status).join() : "";
  const sig = JSON.stringify([p.hidden, p.status, p.job, p.recheck, (p.checks || []).length, anc, (p.labels || []).map(l => l.value),
    (p.chunks || []).map(c => c.status + (c.step || "") + (c.waiting_for_machine ? "w" : "")), live ? Math.floor(Date.now() / 5000) : 0]);
  if (S.lastPostJSON === sig && $("#postpage")) return;    // nothing changed: keep the page (and open <details>)
  S.lastPostJSON = sig;
  if (p.hidden) { $("#app").innerHTML = hiddenPage(p); return; }
  const rec = p.record;
  const postBody = p.kind === "text"
    ? (p.text != null ? `<p class="post-text">${esc(p.text)}</p>` : `<p class="muted"><i>The text of this post is not shown.</i></p>`)
    : mediaBlock(p);
  let html = `<div id="postpage" class="stack" style="padding:20px 0 32px"><a href="#/" class="small">← Feed</a>${labelsHero(p, rec)}
    <section class="card post"><div class="post-head">${avatar(p.author)}<div><div class="name">${esc(p.author)}</div>
    <div class="time">${ago(p.created_at)} · item ${esc(p.id)}</div></div></div>${postBody}</section>`;
  if (p.status === "published") {
    html += labelsTable(p, rec);
    html += chunkGrid(p, "Chunks: one proof per chunk and category");
    html += manifestSection(p);
    if (rec) html += verifySection(p, rec);
    html += `<div class="cols">${anchorSection(p)}<div class="stack">${commitmentSection(p)}${privateList()}</div></div>`;
    if (rec) {
      html += publicTable(rec) + timingStats(rec);
      const sts = chunkRecords(rec).filter(r => r.statement);
      if (sts.length) html += `<section class="card pad"><details><summary>The published statements (statement.json, one per chunk)</summary>${sts.map(r => `<p class="small"><b>chunk ${(r.chunk || {}).index + 1}</b></p><pre class="code">${esc(JSON.stringify(r.statement, null, 1))}</pre>`).join("")}</details></section>`;
    }
  } else if (p.kind === "image") html += imagePlan(p);
  else if (p.status === "queued" || p.status === "screening") html += chunkGrid(p, "Chunk × category proof status");
  if (S.handle && ("@" + S.handle) === p.author && !["deleted", "queued", "screening"].includes(p.status))
    html += `<section class="card pad"><h2>Your post</h2><p class="small">Deleting erases the text and the salt (crypto-shredding) and deletes the receipt;
      the anchored leaves stay on the ledger and can no longer be linked to the content.</p><button class="btn ghost small" id="delbtn">Delete this post</button></section>`;
  html += `<section class="card pad"><h2>Honest limits</h2>${honestLimits()}</section></div>`;
  $("#app").innerHTML = html;
  const vb = $("#verifybtn");
  if (vb) vb.onclick = async () => { vb.disabled = true; try { await api(`/api/posts/${p.id}/verify`, { method: "POST" }); toast("Re-verification queued."); S.lastPostJSON = ""; viewPost(id); } catch (e) { toast(e.message); vb.disabled = false; } };
  const checkList = (checks) => Object.entries(checks).map(([k, v]) => `<li>${v ? `<span class="ok-t">✓</span>` : `<span class="bad-t">✗</span>`} ${esc(k.replace(/_/g, " "))}</li>`).join("");
  const pb = $("#vpubbtn");
  if (pb) pb.onclick = async () => {
    const out = $("#vpubout"); out.innerHTML = `<span class="spinner"></span> checking…`;
    try {
      const r = await api(`/api/posts/${p.id}/verify-publication`, { method: "POST" });
      const per = Object.entries(r.per_proof).map(([k, x]) => { const bad = Object.entries(x.checks).filter(([, v]) => !v).map(([n]) => n.replace(/_/g, " "));
        return `<li>${bad.length ? `<span class="bad-t">✗</span>` : (x.pending ? "…" : `<span class="ok-t">✓</span>`)} ${esc(k)}${x.pending ? " (anchoring pending)" : ""}${bad.length ? ": " + esc(bad.join(", ")) : ` (${Object.keys(x.checks).length} checks)`}</li>`; }).join("");
      out.innerHTML = `<div class="note ${r.accepted ? "ok" : (r.pending ? "info" : "bad")}"><b>${r.accepted ? "Publication verified." : (r.pending ? "Stored and checked; anchoring pending." : "Publication NOT verified.")}</b><ul class="checks" style="list-style:none;padding:0;margin:6px 0 0">${per}</ul>
        <div class="muted">Segment sizes checked here; tools/verify_manifest.py --rehash re-hashes every segment.</div>
        <div class="muted" style="margin-top:4px">The proof itself is re-checked by “Re-verify now”; a third party runs tools/verify_manifest.py --run-verifier.</div></div>`;
    } catch (e) { out.textContent = e.message; }
  };
  const mb = $("#vmanbtn");
  if (mb) mb.onclick = async () => {
    const out = $("#vmanout"); out.innerHTML = `<span class="spinner"></span> checking…`;
    try {
      const r = await api(`/api/posts/${p.id}/verify-manifest`, { method: "POST" });
      out.innerHTML = `<div class="note ${r.accepted ? (r.pending_anchor.length ? "info" : "ok") : "bad"}"><b>${r.accepted ? "Manifest verified" : "Manifest NOT verified"}</b>
        ${r.pending_anchor.length ? ` · anchoring pending for ${r.pending_anchor.map(catName).join(", ")}` : ""}${r.reasons.length ? "<br>" + esc(r.reasons.join("; ")) : ""}
        <details><summary class="small">${Object.keys(r.checks).length} checks</summary><ul class="checks" style="list-style:none;padding:0;margin:6px 0 0">${checkList(r.checks)}</ul></details></div>`;
    } catch (e) { out.textContent = e.message; }
  };
  const cb = $("#ccbtn");
  if (cb) cb.onclick = async () => {
    const out = $("#ccout");
    try { const ok = await checkCommitment(p); out.innerHTML = ok ? `<span class="ok-t">✓ matches this post's text</span>` : `<span class="bad-t">✗ does not match</span>`; }
    catch (e) { out.textContent = "this browser cannot compute SHA-256 here (needs localhost or https)"; }
  };
  const db = $("#delbtn");
  if (db) db.onclick = async () => {
    if (!confirm("Delete this post? Its text and salt are erased and its receipt deleted. The anchored leaves stay (now unlinkable).")) return;
    try { await api(`/api/posts/${p.id}?author=${encodeURIComponent(S.handle)}`, { method: "DELETE" }); toast("Deleted."); S.lastPostJSON = ""; viewPost(id); }
    catch (e) { toast(e.message); }
  };
}

/* ---------------------------------------------------------------- status (admin) */
async function viewStatus() {
  const st = await api("/api/status");
  const d = st.deploy;
  const prof = Object.entries(d.profiles).map(([k, v]) => `<tr class="${k === d.profile ? "active" : ""}"><td><b>${esc(k)}</b>${k === d.profile ? ` <span class="tag">active</span>` : ""}</td><td>${esc(v.label || "")}</td>
    <td>${esc(v.chunk_tokens)}</td><td>${esc(v.overlap_tokens)}</td><td>${esc(v.max_chunks)}</td><td class="small muted">${esc(v.note || "")}</td></tr>`).join("");
  const posts = Object.entries(st.posts).map(([k, v]) => `${esc(k)}: <b>${esc(v)}</b>`).join(" · ") || "none";
  $("#app").innerHTML = `<div class="stack" style="padding:20px 0 32px">
  <section class="card pad"><h1>Status</h1><p class="small muted">Server time ${esc(st.server_time)} · prover <b>${esc(st.prover.kind)}</b> (${esc(st.prover.label)}) · posts: ${posts}</p></section>
  <section class="card pad"><h2>Deployment profile: chunking (D41)</h2>
    <p class="small">Long content is split into chunks; each chunk is proved separately in each category. The chunk size and overlap are chosen per hardware profile in
    <span class="mono">${esc(d.file)}</span> (edit <span class="mono">active_profile</span> and restart, or set <span class="mono">PM_PROFILE</span>).</p>
    <div class="stats" style="margin:10px 0">
      <div class="stat"><b>${esc(d.profile)}</b><span>${esc(d.label)}</span></div>
      <div class="stat"><b>${esc(d.effective_chunk_tokens)}</b><span>tokens per chunk${d.capped_by_prover ? ` (configured ${esc(d.chunk_tokens)}, capped by the stub's ${esc(st.prover.max_content_tokens)})` : ""}</span></div>
      <div class="stat"><b>${esc(d.effective_overlap_tokens)}</b><span>tokens of overlap</span></div>
      <div class="stat"><b>${esc(d.max_chunks)}</b><span>chunks per post at most (≤ ${esc(d.max_content_tokens)} tokens)</span></div></div>
    <div style="overflow-x:auto"><table class="table"><tr><th>profile</th><th>hardware</th><th>chunk tokens</th><th>overlap</th><th>max chunks</th><th></th></tr>${prof}</table></div>
    <p class="small muted" style="margin-top:6px">${st.categories.length} categories × N chunks = proofs per post. The demo stub runs one proof per chunk standing in for that chunk's ${st.categories.length} category proofs.</p></section>
  <section class="card pad">${queueHTML(st.queue, false)}</section>
  <section class="card pad"><h2>Ledger</h2><p class="small">${esc(st.ledger.blocks)} block${st.ledger.blocks === 1 ? "" : "s"} · ${esc(st.ledger.pending_leaves)} leaves waiting for the next batch (every ${Math.round(st.ledger.batch_secs / 60)} min) · <a href="#/ledger">open the ledger</a></p></section>
  </div>`;
}

/* ---------------------------------------------------------------- ledger & about */
async function viewLedger() {
  const r = await api("/api/ledger");
  const rows = r.blocks.map(b => { const t = b.txs[0] || {}, a = t.args || {};
    return `<tr><td>${esc(b.block_number)}</td><td>${esc(b.ts)}</td><td>${esc(a.batch_id)}</td><td>${esc(a.count)}</td>
      <td><span class="hash">${short(a.root, 14)}</span></td><td><span class="hash">${short(t.tx_hash, 12)}</span></td>
      <td><span class="hash">${short(b.block_hash, 10)}</span></td><td><span class="hash">${short(b.prev_block_hash, 8)}</span></td></tr>`; }).join("");
  const nb = r.next_batch_in_s != null ? `next batch in ~${Math.ceil(r.next_batch_in_s / 60)} min` : "nothing pending";
  $("#app").innerHTML = `<div class="stack" style="padding:20px 0 32px"><section class="card pad"><h1>Ledger</h1>
    <p>Each accepted label proof (one per item and category, yes or no) is stored by its manifest's hash: segment hashes, statement hash, label, model, policy,
    profile, verifier and the salted content commitment. Its leaf joins a sorted Merkle batch that closes every ${Math.round(r.batch_secs / 60)} minutes or at
    1,000 leaves; one <span class="mono">anchor(root, count, batchFileHash)</span> call per batch goes into a hash-chained block.</p>
    <div class="note stub">${esc(r.description)}</div>
    <p style="margin-top:10px"><b>${esc(r.pending)}</b> leaf${r.pending === 1 ? "" : "s"} waiting for the next batch · ${esc(nb)}
    ${r.pending ? `<button class="btn ghost small" id="closebtn">Close the batch now (presenter)</button>` : ""}</p></section>
    <section class="card pad" style="overflow-x:auto"><table class="table"><tr><th>block</th><th>time</th><th>batch</th><th>leaves</th><th>Merkle root</th><th>tx</th><th>block hash</th><th>prev</th></tr>
    ${rows || `<tr><td colspan="8" class="muted">No blocks yet.</td></tr>`}</table></section></div>`;
  const cb = $("#closebtn");
  if (cb) cb.onclick = async () => { cb.disabled = true; const x = await api("/api/ledger/close-batch", { method: "POST" }); toast(x.batch_id ? `Closed ${x.batch_id}.` : "Nothing to close."); viewLedger(); };
}

function viewAbout() {
  const cats = S.cfg.categories.map(c => `<li><b>${esc(c.name)}</b> (${esc(c.policy.id)}, sha256 ${short(c.policy.sha256, 12)})
    <details><summary class="small">policy text</summary><pre class="code">${esc(c.policy.text)}</pre></details></li>`).join("");
  $("#app").innerHTML = `<div class="stack" style="padding:20px 0 32px">
  <section class="card pad"><h1>How it works</h1>
    <p>Proven Media labels every item <b>inside zero-knowledge proofs</b>, once, when it is created: a harmful-content classifier answers one fixed question per
    category. Every label, yes or no, is published with its proof and travels with the item in a <b>signed proof manifest</b> (like content credentials).
    The platform uses the proved labels to decide who receives the item: explicit content is not sent to minors, for example. Anyone can check the proofs,
    and the proofs never reveal the item itself.</p>
    <div class="flow"><div><b>Post</b>The item goes to the platform; the proof's input is written to a private 0600 file. It is pending verification.</div>
    <div><b>Label</b>The prover runs the classifier on the hidden item, once per category, and proves every step (minutes, on a laptop CPU).</div>
    <div><b>Verify &amp; sign</b>A fresh verifier, holding only public model files, checks the proofs; the labels are anchored and the manifest is signed.</div>
    <div><b>Distribute</b>Each audience receives the item only if its labels allow it. A label without an accepted proof counts as yes (fail closed).</div></div></section>
  <section class="card pad"><h2>The categories and the statement</h2>
    <p class="small"><b>${esc(S.cfg.classifier.name)}</b> (${esc(S.cfg.classifier.source)}). Each category is one fixed policy text with one threshold:
    ${esc(S.cfg.threshold.rule)}. Public: the labels, the model identity, the policy texts and the content length. Private: the content and the confidence scores.
    <b>Today</b> the app runs the demo stub: ${esc(S.cfg.prover.what_is_proved || "")}</p>
    <ul class="small">${cats}</ul>
    <p class="small muted">The policy texts are short placeholders until the calibration lane's exact texts land; each new text will be a new registered id.</p></section>
  <section class="card pad"><h2>Audiences</h2><p class="small"><b>Adult</b>: receives every labelled item, and may choose to hide categories.
    <b>Minor (under 18)</b>: receives only items proved <b>no</b> in all three categories. Hidden items are served as a placeholder with the reason, never with their content.</p></section>
  <section class="card pad"><h2>Images</h2><p class="small">Three classifier proofs per image, over a canonical canvas (Shieldstral's Pixtral encoder:
    new prover relations, in design): ${esc(S.cfg.image_spec.text)} Video and audio are deferred.</p></section>
  <section class="card pad"><h2>Honest limits</h2>${honestLimits()}</section></div>`;
}

/* ---------------------------------------------------------------- router */
async function router() {
  const h = location.hash || "#/";
  const [, page, id] = h.split("/");
  document.querySelectorAll(".nav a").forEach(a => a.classList.toggle("on", a.dataset.nav === (page || "feed") || (!page && a.dataset.nav === "feed")));
  S.lastPostJSON = "";
  clearInterval(S.timer);
  try {
    if (page === "post" && id) { await viewPost(id); S.timer = setInterval(() => viewPost(id).catch(() => {}), 3000); }
    else if (page === "ledger") await viewLedger();
    else if (page === "status") { await viewStatus(); S.timer = setInterval(() => viewStatus().catch(() => {}), 5000); }
    else if (page === "about") viewAbout();
    else { await viewFeed(); S.timer = setInterval(() => refreshFeed().catch(() => {}), 4000); }
  } catch (e) { $("#app").innerHTML = `<div class="card empty" style="margin-top:20px">Error: ${esc(e.message)}</div>`; }
  window.scrollTo(0, 0);
}

async function boot() {
  try { S.handle = localStorage.getItem("pm-handle") || ""; } catch (e) { S.handle = ""; }
  try { const a = JSON.parse(localStorage.getItem("pm-audience") || "null"); if (a) { S.audience = a.a || "adult"; S.hide = a.hide || []; } } catch (e) {}
  const qs = new URLSearchParams(location.search);
  const as = qs.get("as");                                  // presenter convenience: /?as=victor&audience=minor
  if (as) { S.handle = as.replace(/^@/, "").replace(/[^A-Za-z0-9_]/g, "").slice(0, 24); try { localStorage.setItem("pm-handle", S.handle); } catch (e) {} }
  if (qs.get("audience")) S.audience = qs.get("audience") === "minor" ? "minor" : "adult";
  const hi = $("#handle"); hi.value = S.handle;
  hi.onchange = () => { S.handle = hi.value.trim().replace(/^@/, "").replace(/[^A-Za-z0-9_]/g, "").slice(0, 24); hi.value = S.handle;
    try { localStorage.setItem("pm-handle", S.handle); } catch (e) {} refreshSubs().catch(() => {}); };
  S.cfg = await api("/api/config");
  renderModebar(); renderAudiencePill();
  $("#audpill").onclick = () => setAudience(S.audience === "minor" ? "adult" : "minor");
  window.addEventListener("hashchange", router);
  router();
}
boot();
