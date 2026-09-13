// Test de non-régression du crawler de surlignages (read.amazon.com/notebook).
//
// Il extrait `startNotebookCrawlScript` directement depuis
// kindle_webview_service.dart (en dé-échappant la chaîne Dart), le fait
// tourner dans jsdom avec un `fetch` stubé qui sert des fragments HTML façon
// notebook (pagination par token comprise), et vérifie l'état final de
// `window.__lexdayHl` : dédup, clés stables, notes, vraie page vs location.
//
//   npm install jsdom
//   node tool/kindle_notebook_crawl_test.js
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const SERVICE = path.join(__dirname, '..', 'lib', 'services', 'kindle_webview_service.dart');
const dart = fs.readFileSync(SERVICE, 'utf8');

function extractScript(name) {
  const re = new RegExp(`${name} = '''([\\s\\S]*?)''';`);
  const m = dart.match(re);
  if (!m) throw new Error(`script ${name} introuvable`);
  // Défaire les échappements Dart : \$ -> $, \\ -> \
  return m[1].replace(/\\\$/g, '$').replace(/\\\\/g, '\\');
}

const startScript = extractScript('startNotebookCrawlScript');
const checkScript = extractScript('checkNotebookCrawlScript');

// ── Fixtures ──────────────────────────────────────────────────────────────
const sidebar = `
<div id="kp-notebook-library">
  <div class="kp-notebook-library-each-book" id="B001AAAAAA">
    <img alt="Deep Work" src="x.jpg"/>
    <h2 class="kp-notebook-searchable">Deep Work</h2>
    <p class="kp-notebook-searchable">By: Cal Newport</p>
  </div>
  <div class="kp-notebook-library-each-book" id="B002BBBBBB">
    <h2>Atomic Habits</h2>
    <p>Par : James Clear</p>
  </div>
  <div class="kp-notebook-library-each-book" id="not-an-asin!">
    <h2>Should be skipped</h2>
  </div>
</div>`;

function row(id, text, { note = '', loc = '', header = 'Yellow highlight | Location:&nbsp;' + loc } = {}) {
  return `
  <div id="${id}" class="a-row a-spacing-base">
    <input type="hidden" id="kp-annotation-location" value="${loc}"/>
    <span id="annotationHighlightHeader">${header}</span>
    <div id="highlight-${id}"><span id="highlight">${text}</span></div>
    <div id="note-${id}"><span id="note">${note}</span></div>
  </div>`;
}

// Livre 1 : 2 pages (token de pagination), avec note, doublon volontaire
const book1page1 = `
<div id="kp-notebook-annotations">
  ${row('QT111AAAAAAA', 'Le premier surlignage de Deep Work.', { loc: '242' })}
  ${row('QT222BBBBBBB', 'Un passage avec une note.', { note: 'ma réflexion perso', loc: '512' })}
</div>
<input type="hidden" class="kp-notebook-annotations-next-page-start" value="TOKEN_PAGE_2"/>
<input type="hidden" class="kp-notebook-content-limit-state" value="LIMIT_STATE_X"/>`;

const book1page2 = `
<div id="kp-notebook-annotations">
  ${row('QT333CCCCCCC', 'Surlignage de la page 2, avec "guillemets" et\nretour ligne.', { header: 'Yellow highlight | Page:&nbsp;127', loc: '' })}
  ${row('QT111AAAAAAA', 'Le premier surlignage de Deep Work.', { loc: '242' })}
</div>
<input type="hidden" class="kp-notebook-annotations-next-page-start" value=""/>`;

// Livre 2 : 1 page, ligne sans id (fallback location+hash), highlight vide filtré
const book2page1 = `
<div id="kp-notebook-annotations">
  <div class="a-row a-spacing-base">
    <input type="hidden" id="kp-annotation-location" value="99"/>
    <span id="annotationHighlightHeader">Surlignement en jaune | Emplacement :&nbsp;99</span>
    <div><span id="highlight">Habitude atomique numéro un.</span></div>
    <div><span id="note"></span></div>
  </div>
  ${row('QT444DDDDDDD', '', { loc: '100' })}
</div>`;

const fetchLog = [];
function fakeFetch(url) {
  fetchLog.push(url);
  let html = '<div></div>';
  if (url.includes('asin=B001AAAAAA')) {
    html = url.includes('token=TOKEN_PAGE_2') ? book1page2 : book1page1;
    if (url.includes('token=TOKEN_PAGE_2') && !url.includes('contentLimitState=LIMIT_STATE_X')) {
      throw new Error('contentLimitState non propagé: ' + url);
    }
  } else if (url.includes('asin=B002BBBBBB')) {
    html = book2page1;
  } else {
    throw new Error('fetch inattendu: ' + url);
  }
  return Promise.resolve({ ok: true, text: () => Promise.resolve(html) });
}

// ── Exécution ─────────────────────────────────────────────────────────────
const dom = new JSDOM(`<html><body>${sidebar}</body></html>`, { url: 'https://read.amazon.com/notebook', runScripts: 'outside-only' });
const { window } = dom;
window.fetch = fakeFetch;

const runInWindow = (code) => window.eval(code);
const startResult = runInWindow(startScript.replace(/^\s*\(function/, '(function').trim());
console.log('start →', startResult);

setTimeout(() => {
  const status = JSON.parse(runInWindow(checkScript.trim()));
  console.log('status →', JSON.stringify(status));

  const S = window.__lexdayHl;
  const H = S.highlights;
  const assert = (cond, msg) => { if (!cond) { console.error('❌ ' + msg); process.exitCode = 1; } else console.log('✅ ' + msg); };

  assert(status.done === true, 'crawl terminé');
  assert(S.booksTotal === 2, `2 livres valides (ASIN filtré) — got ${S.booksTotal}`);
  assert(H.length === 4, `4 surlignages (doublon dédupliqué, vide filtré) — got ${H.length}: ${JSON.stringify(H.map(h=>h.text))}`);

  const h1 = H.find(h => h.key === 'kindle:B001AAAAAA:QT111AAAAAAA');
  assert(!!h1, 'clé = kindle:<asin>:<rowId>');
  assert(h1 && h1.bookTitle === 'Deep Work' && h1.bookAuthor === 'Cal Newport', 'titre + auteur (préfixe By: retiré)');
  assert(h1 && h1.page === null, 'location NON mappée sur page');

  const h2 = H.find(h => h.note === 'ma réflexion perso');
  assert(!!h2, 'note attachée au surlignage');

  const h3 = H.find(h => h.key === 'kindle:B001AAAAAA:QT333CCCCCCC');
  assert(h3 && h3.page === 127, 'vraie page extraite de l\'entête — got ' + (h3 && h3.page));

  const h4 = H.find(h => h.bookTitle === 'Atomic Habits');
  assert(!!h4, 'livre 2 crawlé');
  assert(h4 && /^kindle:B002BBBBBB:99:[a-z0-9]+$/.test(h4.key), 'fallback clé location+hash — got ' + (h4 && h4.key));
  assert(h4 && h4.bookAuthor === 'James Clear', 'préfixe "Par :" retiré — got ' + (h4 && h4.bookAuthor));

  assert(fetchLog.length === 3, `3 fetch (2 pages livre 1 + 1 page livre 2) — got ${fetchLog.length}`);

  // Round-trip collectNotebookChunkScript → parse côté Dart simulé
  const chunk = decodeURIComponent(runInWindow(`(function(){ return encodeURIComponent(JSON.stringify(window.__lexdayHl.highlights.slice(0,150))); })();`));
  const parsed = JSON.parse(chunk);
  assert(parsed.length === H.length, 'round-trip encodeURIComponent OK (guillemets + retours ligne)');

  console.log(process.exitCode ? '\nDES TESTS ONT ÉCHOUÉ' : '\nTOUS LES TESTS PASSENT');
}, 300);

// ── Filtre incrémental : window.__lexdayHlOnly limite les livres crawlés ──
(async () => {
  const { JSDOM: J } = require('jsdom');
  const dom2 = new J(`<html><body>${sidebar}</body></html>`, { url: 'https://read.amazon.com/notebook', runScripts: 'outside-only' });
  const w2 = dom2.window;
  const fetched = [];
  w2.fetch = (url) => { fetched.push(url); return Promise.resolve({ ok: true, text: () => Promise.resolve('<div id="kp-notebook-annotations"></div>') }); };
  w2.eval('window.__lexdayHlOnly = ["B002BBBBBB"]; "ok";');
  w2.eval(startScript);
  for (let i = 0; i < 50 && !JSON.parse(w2.eval(checkScript)).done; i++) await new Promise(r => setTimeout(r, 20));
  const st = JSON.parse(w2.eval(checkScript));
  const onlyB002 = fetched.every(u => u.includes('asin=B002BBBBBB'));
  if (st.booksTotal === 1 && onlyB002) console.log('ok  : filtre __lexdayHlOnly → 1 seul livre crawlé');
  else { console.error('FAIL: filtre __lexdayHlOnly', st, fetched.slice(0, 3)); process.exitCode = 1; }
})();
