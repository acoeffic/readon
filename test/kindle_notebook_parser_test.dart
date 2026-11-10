import 'package:flutter_test/flutter_test.dart';
import 'package:lexday/services/kindle_http_sync.dart';

// Fragment minimal reproduisant la structure du notebook Amazon telle que lue
// par le crawler JS (tool/kindle_notebook_crawl_test.js).
const _fragment = '''
<div class="a-row a-spacing-base" id="QOYOO6NR1UH3AL4LXYZ9">
  <div id="annotationHighlightHeader">Highlight (yellow) | Page: 42</div>
  <span id="highlight">  Une phrase surlignée.  </span>
  <span id="note">Ma note</span>
  <input id="kp-annotation-location" value="1234" />
</div>
<div class="a-row" id="short">
  <span id="highlight">Sans id Amazon</span>
  <input id="kp-annotation-location" value="77" />
</div>
<input class="kp-notebook-annotations-next-page-start" value="TOKEN2" />
<input class="kp-notebook-content-limit-state" value="LIMIT1" />
''';

void main() {
  test('parse un fragment notebook comme le crawler JS', () {
    final p = KindleHttpSync.parseNotebookFragment(
      _fragment,
      asin: 'B000000001',
      title: 'Livre',
    );
    expect(p.highlights, hasLength(2));
    expect(p.nextToken, 'TOKEN2');
    expect(p.limitState, 'LIMIT1');

    final a = p.highlights[0];
    expect(a.text, 'Une phrase surlignée.');
    expect(a.note, 'Ma note');
    expect(a.page, 42);
    expect(a.sourceKey, 'kindle:B000000001:QOYOO6NR1UH3AL4LXYZ9');

    final b = p.highlights[1];
    expect(b.page, isNull); // location ≠ page
    expect(
      b.sourceKey,
      'kindle:B000000001:77:${KindleHttpSync.hashText('Sans id Amazon')}',
    );
  });

  test('dédup entre pages via seen', () {
    final seen = <String>{};
    KindleHttpSync.parseNotebookFragment(_fragment,
        asin: 'B000000001', title: 'T', seen: seen);
    final again = KindleHttpSync.parseNotebookFragment(_fragment,
        asin: 'B000000001', title: 'T', seen: seen);
    expect(again.highlights, isEmpty);
  });

  test('hashText identique au JS', () {
    // JS: h=((h<<5)-h+c)|0 ; (h>>>0).toString(36). "abc" → 96354 → "22ci"
    expect(KindleHttpSync.hashText('abc'), '22ci');
  });
}
