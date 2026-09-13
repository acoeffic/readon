import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../models/user_custom_list.dart';
import 'list_share_card.dart';

/// Partage d'une liste perso : lien web public ou carte image.
class ListShareService {
  final _screenshotController = ScreenshotController();

  /// URL publique de la liste (page Next.js, consultable sans compte).
  static String webUrl(String shareToken) =>
      'https://www.lexday.fr/liste/$shareToken';

  /// Pré-télécharge jusqu'à [max] couvertures pour la carte.
  Future<List<ListShareCover>> downloadCovers(
    List<Book> books, {
    int max = 6,
  }) async {
    final selection = books.take(max).toList();
    final results = await Future.wait(selection.map((book) async {
      final url = book.coverUrl;
      if (url != null && url.isNotEmpty) {
        try {
          final response = await http
              .get(Uri.parse(url.replaceFirst('http://', 'https://')))
              .timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            return ListShareCover(
              bytes: response.bodyBytes,
              title: book.title,
            );
          }
        } catch (_) {}
      }
      return ListShareCover(title: book.title);
    }));
    return results;
  }

  /// Capture la [ListShareCard] en PNG haute résolution.
  Future<Uint8List?> captureCard({
    required UserCustomList list,
    required List<ListShareCover> covers,
    required String booksLabel,
  }) {
    final card = ListShareCard(
      title: list.title,
      booksLabel: booksLabel,
      icon: list.icon,
      gradientColors: list.gradientColors,
      covers: covers,
    );
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  Future<File> saveTempFile(Uint8List bytes, int listId) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/lexday_list_${listId}_'
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }
}

/// Feuille de partage : lien web ou carte image.
Future<void> showListShareSheet(
  BuildContext context, {
  required UserCustomList list,
  required String shareToken,
}) async {
  final l = AppLocalizations.of(context)!;
  final box = context.findRenderObject() as RenderBox?;
  final origin =
      box != null ? box.localToGlobal(Offset.zero) & box.size : null;
  final text = l.listShareText(list.title, ListShareService.webUrl(shareToken));

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.link),
            title: Text(l.listShareLinkOption),
            subtitle: Text(l.listShareLinkSubtitle),
            onTap: () async {
              Navigator.pop(sheetContext);
              await Share.share(text, sharePositionOrigin: origin);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.image),
            title: Text(l.listShareImageOption),
            subtitle: Text(l.listShareImageSubtitle),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _shareAsImage(
                list: list,
                text: text,
                booksLabel: l.nBooks(list.bookCount),
                origin: origin,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _shareAsImage({
  required UserCustomList list,
  required String text,
  required String booksLabel,
  Rect? origin,
}) async {
  final service = ListShareService();
  try {
    final covers = await service.downloadCovers(list.books);
    final bytes = await service.captureCard(
      list: list,
      covers: covers,
      booksLabel: booksLabel,
    );
    if (bytes == null) {
      await Share.share(text, sharePositionOrigin: origin);
      return;
    }
    final file = await service.saveTempFile(bytes, list.id);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: origin,
    );
  } catch (e) {
    debugPrint('Erreur partage image liste: $e');
    await Share.share(text, sharePositionOrigin: origin);
  }
}
