// Test de extractInsightsPreloadedDataScript : lit days_read / titles_read
// dans un script inline façon Reading Insights.
//   npm install jsdom ; node tool/kindle_insights_calendar_test.js
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const dart = fs.readFileSync(path.join(__dirname, '..', 'lib', 'services', 'kindle_webview_service.dart'), 'utf8');
const m = dart.match(/extractInsightsPreloadedDataScript = '''([\s\S]*?)''';/);
const src = m[1].replace(/\\\$/g, '$').replace(/\\\\/g, '\\');
const inline = `window.Globals = { cards: ["calendar-card"], preloadedData: {"days_read":["2026-09-09","2026-09-11","bad","2026-09-12"],"goal_info":{"goals":{},"titles_read":[{"asin":"B079PH36FF","read_event_id":"x","date_read":"2026-08-18T19:10:32Z","content_type":"EBOK"},{"asin":"B0CVZ2Q5QQ","date_read":"2026-09-01T10:00:00Z"}]},"other":[1,2]} };`;
const dom = new JSDOM(`<html><head><script>${inline}</script></head><body></body></html>`, { runScripts: 'outside-only' });
const res = JSON.parse(dom.window.eval(src));
const assert = (c, msg) => { if (!c) { console.error('FAIL:', msg, JSON.stringify(res)); process.exitCode = 1; } else console.log('ok  :', msg); };
assert(res.found === true, 'trouvé');
assert(res.daysRead.length === 3 && res.daysRead[2] === '2026-09-12', 'days_read filtrés (3 valides)');
assert(res.titlesRead.length === 2 && res.titlesRead[0].asin === 'B079PH36FF' && res.titlesRead[0].dateRead === '2026-08-18T19:10:32Z', 'titles_read asin + date');
