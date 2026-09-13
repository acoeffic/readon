// Test de non-régression du fetch JSON de la bibliothèque Kindle
// (read.amazon.com/kindle-library/search).
//
// Extrait `fetchKindleLibraryJsonScript` + `checkKindleLibraryJsonScript` +
// `collectKindleLibraryJsonScript` depuis kindle_webview_service.dart, les fait
// tourner dans jsdom avec un `fetch` stubé (2 pages via paginationToken) et
// vérifie le mapping : titre, auteur nettoyé (« Name: »), pourcentage (0-1 ou
// 0-100), ASIN, clés brutes conservées pour les logs.
//
//   npm install jsdom
//   node tool/kindle_library_json_test.js
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const SERVICE = path.join(__dirname, '..', 'lib', 'services', 'kindle_webview_service.dart');
const dart = fs.readFileSync(SERVICE, 'utf8');

function extractScript(name) {
  const re = new RegExp(`${name} = '''([\\s\\S]*?)''';`);
  const m = dart.match(re);
  if (!m) throw new Error(`script ${name} introuvable`);
  return m[1].replace(/\\\$/g, '$').replace(/\\\\/g, '\\');
}

const fetchScript = extractScript('fetchKindleLibraryJsonScript');
const checkScript = extractScript('checkKindleLibraryJsonScript');
const collectScript = extractScript('collectKindleLibraryJsonScript');

const page1 = {
  itemsList: [
    { asin: 'B001AAAAAA', title: 'Deep Work', authors: ['Newport, Cal:'], percentageRead: 42, productUrl: 'https://m.media-amazon.com/a.jpg', resourceType: 'EBOOK' },
    { asin: 'B002BBBBBB', title: 'Atomic Habits', authors: ['Clear, James:'], percentageRead: 100, productUrl: 'https://m.media-amazon.com/b.jpg' },
    { asin: 'B003CCCCCC', title: 'Pas commencé', authors: [], percentageRead: 0 },
  ],
  paginationToken: '3',
};
const page2 = {
  itemsList: [
    { asin: 'B004DDDDDD', title: 'Ratio 0-1', authors: 'Solo Author:', percentageRead: 0.5 },
    { title: 'Sans ASIN ni pourcentage' },
    { asin: 'B0NOTITLE' },
  ],
  paginationToken: null,
};

const calls = [];
const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'https://read.amazon.com/kindle-library', runScripts: 'outside-only' });
const w = dom.window;
w.fetch = (url) => {
  calls.push(url);
  const body = url.includes('paginationToken=3') ? page2 : page1;
  return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(body) });
};

const started = w.eval(fetchScript);
if (started !== 'started') throw new Error('start attendu, reçu ' + started);

function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
(async () => {
  for (let i = 0; i < 50; i++) {
    const st = JSON.parse(w.eval(checkScript));
    if (st.done) break;
    await wait(20);
  }
  const st = JSON.parse(w.eval(checkScript));
  if (!st.done) throw new Error('crawl jamais terminé');
  if (st.error) throw new Error('erreur inattendue: ' + st.error);
  const res = JSON.parse(decodeURIComponent(w.eval(collectScript)));

  const assert = (cond, msg) => { if (!cond) { console.error('FAIL:', msg); process.exitCode = 1; } else console.log('ok  :', msg); };
  assert(calls.length === 2, '2 pages fetchées (pagination par token)');
  assert(calls[0].startsWith('https://read.amazon.com/kindle-library/search?'), 'URL same-origin');
  assert(res.count === 5, '5 livres mappés (item sans titre ignoré) — reçu ' + res.count);
  const byAsin = Object.fromEntries(res.books.filter(b => b.asin).map(b => [b.asin, b]));
  assert(byAsin.B001AAAAAA.percentComplete === 42, 'pourcentage entier conservé');
  assert(byAsin.B001AAAAAA.author === 'Newport, Cal', 'auteur nettoyé du « : » final');
  assert(byAsin.B001AAAAAA.coverUrl === 'https://m.media-amazon.com/a.jpg', 'couverture = productUrl');
  assert(byAsin.B002BBBBBB.percentComplete === 100, '100 % conservé');
  assert(byAsin.B003CCCCCC.percentComplete === 0, '0 % conservé (pas null)');
  assert(byAsin.B003CCCCCC.author === null, 'auteurs vides → null');
  assert(byAsin.B004DDDDDD.percentComplete === 50, 'ratio 0-1 converti en 50');
  assert(byAsin.B004DDDDDD.author === 'Solo Author', 'auteur string nettoyé');
  const noAsin = res.books.find(b => b.title === 'Sans ASIN ni pourcentage');
  assert(noAsin && noAsin.percentComplete === null && noAsin.asin === null, 'item sans champs → null');
  assert(Array.isArray(res.sampleKeys) && res.sampleKeys.includes('percentageRead'), 'clés brutes du 1er item conservées');
  assert(w.eval(fetchScript) === 'started', 'relance possible une fois terminé');
})().catch(e => { console.error(e); process.exit(1); });
