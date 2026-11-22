// Test de la logique de connexion/import Kindle (miroir en JS de
// kindle_login_page.dart et books_service.dart : pas de SDK Dart disponible).
// Garde-fou : on vérifie aussi que le source Dart contient les conditions
// testées ici, pour que le test casse si le code diverge.
// Lancer : node tool/kindle_login_flow_test.js
const fs = require('fs');
const assert = require('assert');

const login = fs.readFileSync('lib/pages/profile/kindle_login_page.dart', 'utf8');
const auto = fs.readFileSync('lib/widgets/kindle_auto_sync_widget.dart', 'utf8');
assert(auto.includes("if (path.startsWith('/ap/')) return true;"), 'autosync : /ap/ non traité comme expiré');
assert(login.includes("Uri.tryParse(url)?.path.startsWith('/kindle/reading/insights')"), 'insights : test d\'URL non ancré');
const books = fs.readFileSync('lib/services/books_service.dart', 'utf8');
for (const needle of [
  "path.startsWith('/ap/')",
  "host == 'read.amazon.com' && path.startsWith('/landing')",
  "if (host == 'read.amazon.com') {",
  "path.startsWith('/kindle/reading/insights')",
  "host.endsWith('amazon.com') || host.endsWith('amazon.fr')",
]) assert(login.includes(needle), 'login page diverge : ' + needle);
for (const needle of [
  'if (!isFirstSync && !hasReadingEvidence) continue;',
  'existingUserBook == null && !isFirstSync && !hasReadingEvidence',
  'if (firstPercent == 100)',
]) assert(books.includes(needle), 'books_service diverge : ' + needle);

function parts(url) {
  try { const u = new URL(url); return { host: u.hostname.toLowerCase(), path: u.pathname }; }
  catch (_) { return { host: '', path: '' }; }
}
// Nouvelle logique (même ordre de cas que _onLibraryPageFinished)
function classifyNew(url) {
  const { host, path } = parts(url);
  if (path.startsWith('/ap/')) return 'login';
  if (host === 'read.amazon.com' && path.startsWith('/landing')) return 'landing';
  if (host === 'read.amazon.com') return 'library';
  if (path.startsWith('/kindle/reading/insights')) return 'insights';
  if (host.endsWith('amazon.com') || host.endsWith('amazon.fr')) return 'amazon_other';
  return 'other';
}
// Ancienne logique (url.contains)
function classifyOld(url) {
  if (url.includes('/ap/signin') || url.includes('/ap/register')) return 'login';
  if (url.includes('read.amazon.com/landing')) return 'landing';
  if (url.includes('read.amazon.com')) return 'library';
  if (url.includes('/kindle/reading/insights')) return 'insights';
  if ((url.includes('amazon.com') || url.includes('amazon.fr')) && !url.includes('/ap/')) return 'amazon_other';
  return 'other';
}
const ret = 'openid.return_to=https%3A%2F%2Fread.amazon.com%2Fkindle-library';
const cases = [
  ['signin', `https://www.amazon.com/ap/signin?${ret}`, 'login'],
  ['register', `https://www.amazon.com/ap/register?${ret}`, 'login'],
  ['SMS code (mfa)', `https://www.amazon.com/ap/mfa?ie=UTF8&${ret}&arb=abc`, 'login'],
  ['cvf', `https://www.amazon.com/ap/cvf/request?${ret}`, 'login'],
  ['cvf amazon.fr', `https://www.amazon.fr/ap/cvf/request?${ret}`, 'login'],
  ['challenge', `https://www.amazon.com/ap/challenge?${ret}`, 'login'],
  ['captcha (/ap/)', `https://www.amazon.com/ap/captcha?${ret}`, 'login'],
  ['forgot password', `https://www.amazon.com/ap/forgotpassword?${ret}`, 'login'],
  ['landing non connecté', 'https://read.amazon.com/landing', 'landing'],
  ['bibliothèque', 'https://read.amazon.com/kindle-library', 'library'],
  ['bibliothèque + query', 'https://read.amazon.com/kindle-library?x=1', 'library'],
  ['insights', 'https://www.amazon.com/kindle/reading/insights', 'insights'],
  ['accueil amazon.com', 'https://www.amazon.com/?ref_=nav', 'amazon_other'],
  ['accueil amazon.fr', 'https://www.amazon.fr/', 'amazon_other'],
  ['about:blank', 'about:blank', 'other'],
  ['URL illisible', 'http://[bad', 'other'],
];
let fail = 0;
for (const [name, url, want] of cases) {
  const got = classifyNew(url);
  if (got !== want) { fail++; console.log(`KO  ${name}: attendu ${want}, obtenu ${got}`); }
  else console.log(`OK  ${name} -> ${got}`);
}
// Reproduction du bug : l'ancienne logique prenait mfa/cvf/challenge pour la bibliothèque
const buggy = cases.filter(([n, u, w]) => w === 'login' && classifyOld(u) !== 'login').map(c => c[0]);
console.log('\nAncienne logique : pages de vérification prises pour autre chose :', buggy.join(', ') || 'aucune');
assert(buggy.includes('SMS code (mfa)'), 'le bug mfa devrait se reproduire avec l\'ancien code');

// ── Synchro cachée : _isSignedOutUrl ──
function signedOutNew(url){const {host,path}=parts(url);return path.startsWith('/ap/')||(host.includes('read.amazon.')&&path.startsWith('/landing'));}
function signedOutOld(url){const {host,path}=parts(url);return path.startsWith('/ap/signin')||path.startsWith('/ap/register')||(host.includes('read.amazon.')&&path.startsWith('/landing'));}
for (const [name,url,want] of [
  ['autosync mfa', `https://www.amazon.com/ap/mfa?${ret}`, true],
  ['autosync cvf', `https://www.amazon.com/ap/cvf/request?${ret}`, true],
  ['autosync signin', `https://www.amazon.com/ap/signin?${ret}`, true],
  ['autosync landing', 'https://read.amazon.com/landing', true],
  ['autosync bibliothèque', 'https://read.amazon.com/kindle-library', false],
  ['autosync page Amazon légitime /gp/…/landing', 'https://www.amazon.com/gp/help/landing-page', false],
]) { const g=signedOutNew(url); if(g!==want){fail++;console.log(`KO  ${name}: attendu ${want}, obtenu ${g}`);} else console.log(`OK  ${name} -> ${g}`); }
assert(!signedOutOld(`https://www.amazon.com/ap/mfa?${ret}`), 'ancien code : mfa non détecté comme expiré');

// ── Import : décision par livre (miroir de importKindleBooks) ──
function importDecision({ first, percent, bookRow, userBook }) {
  const evidence = percent != null && percent > 0;
  if (!bookRow && !first && !evidence) return 'skip';
  if (!userBook && !first && !evidence) return 'skip';
  let status = null;
  if (first) {
    if (percent === 100) status = 'finished';
    else if (percent != null && percent > 0) status = 'reading';
  } else if (percent === 100) status = 'finished';
  else if (evidence && (!userBook || true)) status = 'reading';
  return userBook ? 'update:' + (status || 'none') : 'insert:' + (status || 'to_read');
}
const imp = [
  ['sync normal, jamais ouvert, inconnu', { first: false, percent: null, bookRow: false, userBook: false }, 'skip'],
  ['sync normal, 0 %, inconnu', { first: false, percent: 0, bookRow: false, userBook: false }, 'skip'],
  ['sync normal, 0 %, livre en base mais pas chez lui', { first: false, percent: 0, bookRow: true, userBook: false }, 'skip'],
  ['sync normal, 35 %, nouveau', { first: false, percent: 35, bookRow: false, userBook: false }, 'insert:reading'],
  ['sync normal, 100 %, nouveau', { first: false, percent: 100, bookRow: false, userBook: false }, 'insert:finished'],
  ['sync normal, déjà dans sa biblio, 0 %', { first: false, percent: 0, bookRow: true, userBook: true }, 'update:none'],
  ['sync normal, déjà dans sa biblio, 50 %', { first: false, percent: 50, bookRow: true, userBook: true }, 'update:reading'],
  ['1er sync, sans progression (coché à la main)', { first: true, percent: null, bookRow: false, userBook: false }, 'insert:to_read'],
  ['1er sync, 0 %', { first: true, percent: 0, bookRow: false, userBook: false }, 'insert:to_read'],
  ['1er sync, 40 %', { first: true, percent: 40, bookRow: false, userBook: false }, 'insert:reading'],
  ['1er sync, 100 %', { first: true, percent: 100, bookRow: false, userBook: false }, 'insert:finished'],
];
for (const [name, input, want] of imp) {
  const got = importDecision(input);
  if (got !== want) { fail++; console.log(`KO  ${name}: attendu ${want}, obtenu ${got}`); }
  else console.log(`OK  ${name} -> ${got}`);
}
console.log(fail ? `\n${fail} échec(s)` : '\nTous les cas passent');
process.exit(fail ? 1 : 0);
