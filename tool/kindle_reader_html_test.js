// Test du parseur de position de lecture depuis le HTML du Cloud Reader
// (fetchKindleReaderHtmlScript) : fetch stubé, JSON inline avec \x22.
//   npm install jsdom ; node tool/kindle_reader_html_test.js
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const dart = fs.readFileSync(path.join(__dirname, '..', 'lib', 'services', 'kindle_webview_service.dart'), 'utf8');
const m = dart.match(/fetchKindleReaderHtmlScript\(List<String> asins\) \{[\s\S]*?return '''([\s\S]*?)''';/);
if (!m) throw new Error('script introuvable');
// Dé-échappement Dart (non-raw) : \\ -> \, puis interpolation $list.
const src = m[1].replace(/\\\\/g, '\\').replace('$list', JSON.stringify(['A1', 'A2', 'A3', 'A4']));
const check = dart.match(/checkKindleReaderHtmlScript = '''([\s\S]*?)''';/)[1];
const collect = dart.match(/collectKindleReaderHtmlScript = '''([\s\S]*?)''';/)[1];

const html = (pos, srl, end) => `<html><script>var x = "{\\x22foo\\x22:1,${pos === null ? '' : `\\x22mostRecentPositionRead\\x22:${pos},`}\\x22srl\\x22:${srl},\\x22endReadingPosition\\x22:${end}}";</script></html>`;
const pages = { A1: html(575269, 0, 737970), A2: html(578291, 881, 580824), A3: html(null, 143, 540883) };
const dom = new JSDOM('<html></html>', { url: 'https://read.amazon.com/kindle-library/search', runScripts: 'outside-only' });
const w = dom.window;
w.fetch = (url) => {
  const asin = url.split('asin=')[1];
  if (asin === 'A4') return Promise.resolve({ ok: false, status: 500, url, text: () => Promise.resolve('') });
  return Promise.resolve({ ok: true, status: 200, url, text: () => Promise.resolve(pages[asin]) });
};
if (w.eval(src) !== 'started') throw new Error('start attendu');
(async () => {
  for (let i = 0; i < 50 && !JSON.parse(w.eval(check)).done; i++) await new Promise(r => setTimeout(r, 20));
  const res = JSON.parse(decodeURIComponent(w.eval(collect)));
  const assert = (c, msg) => { if (!c) { console.error('FAIL:', msg, JSON.stringify(res)); process.exitCode = 1; } else console.log('ok  :', msg); };
  assert(res.results.A1 && res.results.A1.percent === 78, 'A1 = 78 % (srl 0)');
  assert(res.results.A2 && res.results.A2.percent === 100, 'A2 = 100 % (99,56 arrondi, srl 881)');
  assert(res.results.A3 && res.results.A3.percent === null, 'A3 jamais ouvert → percent null');
  assert(res.failed.length === 1 && res.failed[0] === 'A4', 'A4 HTTP 500 → failed');
  assert(res.error === 'HTTP 500', 'erreur remontée');
})();
