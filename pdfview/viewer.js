const { getDocument, GlobalWorkerOptions, TextLayer } = globalThis.pdfjsLib;
GlobalWorkerOptions.workerSrc = "inline";

const $ = (id) => document.getElementById(id);
const viewer = $("viewer");
const pagesEl = $("pages");
const hud = $("hud");
const status = $("status");
const find = $("find");
const PAD = 16;
const BASE_MAX_PX = 2.5e6;

const SRC = window.__pdfviewSrc;
const sleep = (ms) => new Promise((res) => setTimeout(res, ms));
let etag = null;

function embeddedData() {
  const bin = atob($("pdfdata").textContent.trim());
  const data = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) data[i] = bin.charCodeAt(i);
  return data;
}

let doc;
const pages = [];
let scale = 1;
let settleTimer = null;
let gestureStart = 1;
let hits = [];
let hitIdx = -1;
let live = false;

function viewState() {
  const vr = viewRect();
  const cx = vr.left + vr.width / 2;
  const cy = vr.top + vr.height / 2;
  const i = currentPage();
  const r = pages[i].el.getBoundingClientRect();
  return [scale, i, (cx - r.left) / r.width, (cy - r.top) / r.height].map((v) => +v.toFixed(5)).join(",");
}

function restoreState(s) {
  const [sc, i, fx, fy] = s.split(",").map(Number);
  if (![sc, i, fx, fy].every(Number.isFinite) || !pages[i]) return false;
  scale = sc;
  layout();
  const vr = viewRect();
  const r = pages[i].el.getBoundingClientRect();
  viewer.scrollLeft += r.left + fx * r.width - (vr.left + vr.width / 2);
  viewer.scrollTop += r.top + fy * r.height - (vr.top + vr.height / 2);
  return true;
}

function reloadKeepingView() {
  history.replaceState(null, "", `#view=${viewState()}`);
  location.reload();
}

function setLive(v) {
  if (live === v) return;
  live = v;
  updateHud();
}

async function remoteTag() {
  const r = await fetch(SRC, { method: "HEAD", cache: "no-store" });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.headers.get("ETag");
}

// The PDF can be caught mid-write by latexmk, so a load that fails to parse is retried.
async function loadRemote() {
  for (let attempt = 0; ; attempt++) {
    try {
      const r = await fetch(SRC, { cache: "no-store" });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const tag = r.headers.get("ETag");
      const d = await getDocument({ data: new Uint8Array(await r.arrayBuffer()), isEvalSupported: false }).promise;
      etag = tag;
      return d;
    } catch (err) {
      if (attempt >= 20) throw err;
      await sleep(300);
    }
  }
}

// Reload only once the ETag has held still for 300 ms, so a half-written PDF is skipped.
async function pollRemote() {
  try {
    const tag = await remoteTag();
    setLive(true);
    if (tag !== etag && pages.length) {
      await sleep(300);
      if ((await remoteTag()) === tag) return reloadKeepingView();
    }
  } catch {
    setLive(false);
  }
  setTimeout(pollRemote, 1000);
}

function layout() {
  for (const p of pages) {
    p.el.style.width = `${p.w * scale}px`;
    p.el.style.height = `${p.h * scale}px`;
    p.text.style.transform = `scale(${scale})`;
  }
  updateHud();
}

function viewRect() {
  return viewer.getBoundingClientRect();
}

function currentPage() {
  const vr = viewRect();
  const mid = vr.top + vr.height / 2;
  let best = 0;
  let bestD = Infinity;
  pages.forEach((p, i) => {
    const r = p.el.getBoundingClientRect();
    const d = mid < r.top ? r.top - mid : mid > r.bottom ? mid - r.bottom : 0;
    if (d < bestD) [bestD, best] = [d, i];
  });
  return best;
}

function fitScale(widthOnly) {
  const p = pages[currentPage()];
  const sw = (viewer.clientWidth - 2 * PAD) / p.w;
  return widthOnly ? sw : Math.min(sw, (viewer.clientHeight - 2 * PAD) / p.h);
}

function zoomTo(s, cx, cy) {
  s = Math.min(16, Math.max(0.02, s));
  const vr = viewRect();
  if (cx === undefined) [cx, cy] = [vr.left + vr.width / 2, vr.top + vr.height / 2];
  let p = pages[0];
  let bestD = Infinity;
  for (const q of pages) {
    const r = q.el.getBoundingClientRect();
    const d = Math.max(r.top - cy, cy - r.bottom, 0) + Math.max(r.left - cx, cx - r.right, 0);
    if (d < bestD) [bestD, p] = [d, q];
  }
  const r0 = p.el.getBoundingClientRect();
  const fx = (cx - r0.left) / r0.width;
  const fy = (cy - r0.top) / r0.height;
  scale = s;
  layout();
  const r1 = p.el.getBoundingClientRect();
  viewer.scrollLeft += r1.left + fx * r1.width - cx;
  viewer.scrollTop += r1.top + fy * r1.height - cy;
  scheduleSharpen();
}

function updateHud() {
  if (!pages.length) return;
  const h = hits.length ? `  ${hitIdx + 1}/${hits.length} matches` : "";
  hud.textContent = `${currentPage() + 1}/${pages.length}  ${Math.round(scale * 100)}%${h}${live ? "  live" : ""}`;
}

function render(p, canvas, vp, transform) {
  return p.page.render({ canvas, canvasContext: canvas.getContext("2d"), viewport: vp, transform }).promise;
}

function ensureBase(p) {
  if (p.base) return;
  const k = Math.min(Math.sqrt(BASE_MAX_PX / (p.w * p.h)), 3);
  const vp = p.page.getViewport({ scale: k });
  const c = document.createElement("canvas");
  c.className = "base";
  c.width = Math.floor(vp.width);
  c.height = Math.floor(vp.height);
  p.base = c;
  render(p, c, vp).then(() => p.el.prepend(c), () => (p.base = null));
}

function scheduleSharpen() {
  clearTimeout(settleTimer);
  settleTimer = setTimeout(sharpen, 120);
}

function sharpen() {
  const vr = viewRect();
  const ratio = window.devicePixelRatio || 1;
  for (const p of pages) {
    const r = p.el.getBoundingClientRect();
    if (r.bottom > vr.top - vr.height && r.top < vr.bottom + vr.height) ensureBase(p);
    const x0 = Math.max(r.left, vr.left) - r.left;
    const y0 = Math.max(r.top, vr.top) - r.top;
    const x1 = Math.min(r.right, vr.right) - r.left;
    const y1 = Math.min(r.bottom, vr.bottom) - r.top;
    p.task?.cancel();
    p.task = null;
    if (x1 <= x0 || y1 <= y0) {
      p.hi?.remove();
      p.hi = null;
      continue;
    }
    const c = document.createElement("canvas");
    c.className = "hi";
    c.width = Math.ceil((x1 - x0) * ratio);
    c.height = Math.ceil((y1 - y0) * ratio);
    Object.assign(c.style, {
      left: `${(x0 / r.width) * 100}%`,
      top: `${(y0 / r.height) * 100}%`,
      width: `${((x1 - x0) / r.width) * 100}%`,
      height: `${((y1 - y0) / r.height) * 100}%`,
    });
    const vp = p.page.getViewport({ scale: (r.width / p.w) * ratio });
    const task = p.page.render({
      canvas: c,
      canvasContext: c.getContext("2d"),
      viewport: vp,
      transform: [1, 0, 0, 1, -x0 * ratio, -y0 * ratio],
    });
    p.task = task;
    task.promise.then(
      () => {
        if (p.task !== task) return;
        p.task = null;
        p.hi?.remove();
        p.hi = c;
        p.text.before(c);
      },
      () => {}
    );
  }
}

function scrollToPagePoint(i, fy = 0) {
  const p = pages[Math.max(0, Math.min(pages.length - 1, i))];
  const r = p.el.getBoundingClientRect();
  viewer.scrollTop += r.top + fy * r.height - viewRect().top - (fy ? viewer.clientHeight / 3 : PAD);
}

async function followDest(dest) {
  if (typeof dest === "string") dest = await doc.getDestination(dest);
  if (!Array.isArray(dest)) return;
  const idx = typeof dest[0] === "number" ? dest[0] : await doc.getPageIndex(dest[0]);
  const p = pages[idx];
  const top = dest[1]?.name === "XYZ" && dest[3] != null ? (p.view[3] - dest[3]) / p.h : 0;
  scrollToPagePoint(idx, Math.max(0, top));
}

async function addLinks(p) {
  for (const a of await p.page.getAnnotations()) {
    if (a.subtype !== "Link" || (!a.url && !a.dest)) continue;
    const [x0, y0, x1, y1] = [
      Math.min(a.rect[0], a.rect[2]),
      Math.min(a.rect[1], a.rect[3]),
      Math.max(a.rect[0], a.rect[2]),
      Math.max(a.rect[1], a.rect[3]),
    ];
    const el = document.createElement("a");
    el.className = "link";
    Object.assign(el.style, {
      left: `${((x0 - p.view[0]) / p.w) * 100}%`,
      top: `${((p.view[3] - y1) / p.h) * 100}%`,
      width: `${((x1 - x0) / p.w) * 100}%`,
      height: `${((y1 - y0) / p.h) * 100}%`,
    });
    if (a.url) {
      el.href = a.url;
      el.target = "_blank";
      el.title = a.url;
    } else {
      el.href = "#";
      el.onclick = (e) => {
        e.preventDefault();
        followDest(a.dest);
      };
    }
    p.el.append(el);
  }
}

function clearHits() {
  for (const h of hits) h.classList.remove("hit", "cur");
  hits = [];
  hitIdx = -1;
  updateHud();
}

function runSearch(q) {
  clearHits();
  q = q.trim().toLowerCase();
  if (!q) return;
  for (const p of pages) {
    for (const s of p.text.querySelectorAll("span:not(.markedContent)")) {
      if (s.textContent.toLowerCase().includes(q)) {
        s.classList.add("hit");
        hits.push(s);
      }
    }
  }
  const cur = currentPage();
  const start = hits.findIndex((h) => pages.findIndex((p) => p.el.contains(h)) >= cur);
  showHit(start < 0 ? 0 : start);
}

function showHit(i) {
  if (!hits.length) return updateHud();
  hits[hitIdx]?.classList.remove("cur");
  hitIdx = (i + hits.length) % hits.length;
  const h = hits[hitIdx];
  h.classList.add("cur");
  const r = h.getBoundingClientRect();
  const vr = viewRect();
  viewer.scrollTop += r.top + r.height / 2 - (vr.top + vr.height / 2);
  viewer.scrollLeft += r.left + r.width / 2 - (vr.left + vr.width / 2);
  updateHud();
}

function openFind() {
  find.hidden = false;
  find.select();
  find.focus();
}

find.addEventListener("keydown", (e) => {
  e.stopPropagation();
  if (e.key === "Enter") {
    e.preventDefault();
    if (find.dataset.q === find.value && hits.length) showHit(hitIdx + (e.shiftKey ? -1 : 1));
    else runSearch((find.dataset.q = find.value));
  } else if (e.key === "Escape") {
    find.hidden = true;
    find.blur();
  }
});

viewer.addEventListener(
  "wheel",
  (e) => {
    if (!e.ctrlKey) return;
    e.preventDefault();
    zoomTo(scale * Math.exp(-e.deltaY * 0.01), e.clientX, e.clientY);
  },
  { passive: false }
);
viewer.addEventListener("gesturestart", (e) => {
  e.preventDefault();
  gestureStart = scale;
});
viewer.addEventListener("gesturechange", (e) => {
  e.preventDefault();
  zoomTo(gestureStart * e.scale, e.clientX, e.clientY);
});
viewer.addEventListener("gestureend", (e) => e.preventDefault());
viewer.addEventListener("scroll", () => {
  updateHud();
  scheduleSharpen();
});
window.addEventListener("resize", scheduleSharpen);

let pendingG = false;
window.addEventListener("keydown", (e) => {
  const k = e.key;
  const mod = e.metaKey || e.ctrlKey;
  const step = 80;
  let handled = true;
  if (mod && k === "f") openFind();
  else if (mod && (k === "=" || k === "+")) zoomTo(scale * 1.25);
  else if (mod && k === "-") zoomTo(scale / 1.25);
  else if (mod && k === "0") zoomTo(fitScale());
  else if (mod) handled = false;
  else if (k === "/") openFind();
  else if (k === "n" && hits.length) showHit(hitIdx + 1);
  else if (k === "N" && hits.length) showHit(hitIdx - 1);
  else if (k === "Escape") clearHits();
  else if (k === "j" || k === "ArrowDown") viewer.scrollBy(0, step);
  else if (k === "k" || k === "ArrowUp") viewer.scrollBy(0, -step);
  else if (k === "h" || k === "ArrowLeft") viewer.scrollBy(-step, 0);
  else if (k === "l" || k === "ArrowRight") viewer.scrollBy(step, 0);
  else if (k === "d" || (k === " " && !e.shiftKey)) viewer.scrollBy(0, viewer.clientHeight / 2);
  else if (k === "u" || (k === " " && e.shiftKey)) viewer.scrollBy(0, -viewer.clientHeight / 2);
  else if (k === "J" || k === "PageDown") scrollToPagePoint(currentPage() + 1);
  else if (k === "K" || k === "PageUp") scrollToPagePoint(currentPage() - 1);
  else if (k === "G") scrollToPagePoint(pages.length - 1);
  else if (k === "g") {
    if (pendingG) scrollToPagePoint(0);
    pendingG = !pendingG;
    return;
  } else if (k === "+" || k === "=") zoomTo(scale * 1.25);
  else if (k === "-") zoomTo(scale / 1.25);
  else if (k === "z" || k === "0") zoomTo(fitScale());
  else if (k === "w") zoomTo(fitScale(true));
  else if (k === "s") zoomTo(1);
  else if (k === "r") reloadKeepingView();
  else handled = false;
  pendingG = false;
  if (handled) e.preventDefault();
});

async function main() {
  doc = SRC ? await loadRemote() : await getDocument({ data: embeddedData(), isEvalSupported: false }).promise;
  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const vp = page.getViewport({ scale: 1 });
    const el = document.createElement("div");
    el.className = "page";
    const text = document.createElement("div");
    text.className = "textLayer";
    text.style.width = `${vp.width}px`;
    text.style.height = `${vp.height}px`;
    el.append(text);
    pagesEl.append(el);
    pages.push({ page, el, text, w: vp.width, h: vp.height, view: page.view, base: null, hi: null, task: null });
  }
  const saved = location.hash.match(/view=([^&]+)/)?.[1];
  if (!saved || !restoreState(saved)) {
    scale = fitScale();
    layout();
  }
  status.remove();
  sharpen();
  if (SRC) pollRemote();
  for (const p of pages) {
    await new TextLayer({ textContentSource: p.page.streamTextContent(), container: p.text, viewport: p.page.getViewport({ scale: 1 }) }).render();
    p.text.style.width = `${p.w}px`;
    p.text.style.height = `${p.h}px`;
    addLinks(p);
  }
}

main().catch((err) => {
  status.textContent = `Error: ${err?.message || err}`;
  console.error(err);
});
