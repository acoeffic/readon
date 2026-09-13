// Test de non-régression du scoping de `extractionScript` (Reading Insights).
//
// Contexte : ce script JS décidait quels livres Kindle sont « terminés ». Il
// balayait TOUT le document, donc les carrousels de recommandation et les blocs
// promo faisaient basculer en `finished` des livres de la bibliothèque de
// l'utilisateur. Il est désormais scopé à la section « N titles read ».
//
// Aucun SDK Dart n'étant nécessaire, ce test tourne en Node avec jsdom :
//
//   npm install jsdom
//   node tool/kindle_insights_scope_test.js
//
// Il extrait le JS directement depuis kindle_webview_service.dart (en
// dé-échappant la chaîne Dart), donc il reste synchronisé avec le source.

const path = require('path');
const SERVICE = path.join(__dirname, '..', 'lib', 'services', 'kindle_webview_service.dart');

function extractScript() {
  const src = require('fs').readFileSync(SERVICE, 'utf8');
  const m = src.match(/static const String extractionScript = \'\'\'([\s\S]*?)\'\'\';/);
  if (!m) throw new Error('extractionScript introuvable dans ' + SERVICE);
  return m[1].replace(/\\\$/g, '$').replace(/\\\\/g, '\\').trim();
}

const { JSDOM } = require('jsdom');
const script = extractScript();

function run(html, label) {
  const dom = new JSDOM(html);
  const { window } = dom;
  global.window = window; global.document = window.document;
  // innerText n'existe pas dans jsdom : approximation par textContent
  Object.defineProperty(window.HTMLElement.prototype, 'innerText', {
    get() { return this.textContent; }, configurable: true,
  });
  const result = JSON.parse(new Function('document', 'return ' + script.trim())(window.document));
  const titles = (result.books || []).map(b => b.title).sort();
  console.log(`\n--- ${label} ---`);
  console.log('booksScoped :', result.booksScoped);
  console.log('livres      :', titles.length ? titles.join(' | ') : '(aucun)');
  return result;
}

const cover = (alt) => `<a href="/dp/B01"><img alt="${alt}" src="x"></a>`;

// CAS 1 : section "titles read" + carrousel promo ailleurs sur la page
const r1 = run(`<html><body><div id="a-page">
  <div class="header"><span>Reading Insights</span></div>
  <section>
    <div><span>3 titles read</span></div>
    <div class="grid">${cover('Le Comte de Monte-Cristo')}${cover('Dune')}${cover('Fondation')}</div>
  </section>
  <section>
    <h3>Recommandé pour vous</h3>
    <div class="carousel">${cover('PUB Un livre que je lis')}${cover('PUB Autre promo')}</div>
  </section>
</div></body></html>`, 'CAS 1 — section presente + carrousel promo');

// CAS 2 : libellé sur deux blocs + variante de formulation
const r2 = run(`<html><body><div id="a-page">
  <section><div><span>Titles read in 2026</span></div>
  <div>${cover('Sapiens')}${cover('Factfulness')}</div></section>
  <div class="promo">${cover('PUB Ne doit pas apparaitre')}</div>
</div></body></html>`, 'CAS 2 — "Titles read in 2026", promo hors section');

// CAS 3 : aucune section reconnaissable -> doit ne RIEN remonter
const r3 = run(`<html><body><div id="a-page">
  <h1>Votre annee de lecture</h1>
  <div>${cover('Un livre')}${cover('Un autre')}</div>
</div></body></html>`, 'CAS 3 — libelle absent (doit etre vide + booksScoped=false)');

// CAS 4 : francais
const r4 = run(`<html><body><div id="a-page">
  <section><span>12 livres lus cette annee</span>
  <div>${cover('Belle du Seigneur')}${cover('LEtranger')}</div></section>
  <div>${cover('PUB hors section')}</div>
</div></body></html>`, 'CAS 4 — libelle francais');

const fail = [];
if (r1.books.some(b => b.title.startsWith('PUB'))) fail.push('CAS1: promo capturee');
if (r1.books.length !== 3) fail.push('CAS1: attendu 3 livres, recu ' + r1.books.length);
if (r2.books.some(b => b.title.startsWith('PUB'))) fail.push('CAS2: promo capturee');
if (r3.books.length !== 0 || r3.booksScoped !== false) fail.push('CAS3: aurait du etre vide');
if (r4.books.some(b => b.title.startsWith('PUB'))) fail.push('CAS4: promo capturee');
console.log('\n==============================');
console.log(fail.length ? 'ECHECS:\n - ' + fail.join('\n - ') : 'TOUS LES CAS PASSENT');

function run2(html, label) {
  const dom = new JSDOM(html);
  Object.defineProperty(dom.window.HTMLElement.prototype, 'innerText', {
    get() { return this.textContent; }, configurable: true });
  const r = JSON.parse(new Function('document', 'return ' + script)(dom.window.document));
  const t = (r.books || []).map(b => b.title);
  console.log(`\n--- ${label} ---\nbooksScoped: ${r.booksScoped}  livres: ${t.length}`);
  if (t.length && t.length <= 5) console.log('   ', t.join(' | '));
  return r;
}
const cover2 = a => `<a href="/dp/B01"><img alt="${a}" src="x"></a>`;
const many = n => Array.from({length:n},(_,i)=>cover2('Livre '+i)).join('');

// CAS 5 : la grille est un FRERE de l'en-tete, gros lecteur (60 livres)
const r5 = run2(`<html><body><div id="a-page">
 <div class="sec"><div class="hdr"><span>60 titles read</span></div><div class="grid">${many(60)}</div></div>
 <div class="promo">${cover2('PUB promo')}</div></div></body></html>`, 'CAS 5 — grille soeur de l en-tete, 60 livres');

// CAS 6 : libelle present dans un item de nav, sans grille de livres
const r6 = run2(`<html><body><div id="a-page">
 <nav><li><span>Titles read</span></li></nav>
 <div class="promo">${cover2('PUB 1')}${cover2('PUB 2')}</div></div></body></html>`, 'CAS 6 — libelle dans la nav, aucune section reelle');

// CAS 7 : deux sections (annee en cours + annee precedente)
const r7 = run2(`<html><body><div id="a-page">
 <section><span>2 titles read</span><div>${cover2('Anna Karenine')}${cover2('Bel-Ami')}</div></section>
 <section><span>5 titles read</span><div>${many(5)}</div></section></div></body></html>`, 'CAS 7 — deux sections');

const fail2 = [];
if (r5.books.some(b=>b.title.startsWith('PUB'))) fail2.push('CAS5: promo capturee');
if (r5.books.length !== 60) fail2.push('CAS5: attendu 60, recu ' + r5.books.length);
if (r6.books.length > 0) fail2.push('CAS6: a capture ' + r6.books.map(b=>b.title).join(','));
if (r7.books.length === 0) fail2.push('CAS7: rien capture');
console.log('\n==============================');
console.log(fail2.length ? 'ECHECS:\n - ' + fail2.join('\n - ') : 'TOUS LES CAS PASSENT');

