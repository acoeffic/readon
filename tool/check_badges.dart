// tool/check_badges.dart
//
// Vérifie la synchronisation entre :
//   - le catalogue badges.md (source de vérité des IDs)
//   - les visuels dans assets/badges/<id>.webp (sources HD en PNG dans le bucket Supabase)
//
// Utilisation :
//   dart run tool/check_badges.dart              # rapport seul
//   dart run tool/check_badges.dart --delete-orphans   # supprime les WebP orphelins
//   dart run tool/check_badges.dart --help
//
// Trois statuts possibles par badge :
//   OK         badge dans badges.md ET fichier <id>.webp présent
//   MANQUANT   badge dans badges.md mais pas de WebP
//   ORPHELIN   WebP dans assets/badges/ sans entrée correspondante dans badges.md

import 'dart:io';

const _badgesMdPath = 'badges.md';
const _assetsDir = 'assets/badges';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  final deleteOrphans = args.contains('--delete-orphans');

  // 1. Vérifier que les fichiers/dossiers existent
  final mdFile = File(_badgesMdPath);
  if (!mdFile.existsSync()) {
    stderr.writeln('❌ Fichier introuvable : $_badgesMdPath');
    stderr.writeln('   (lance ce script depuis la racine du projet)');
    exit(1);
  }

  final assetsDir = Directory(_assetsDir);
  if (!assetsDir.existsSync()) {
    stderr.writeln('❌ Dossier introuvable : $_assetsDir');
    exit(1);
  }

  // 2. Parser badges.md pour extraire tous les IDs
  final mdIds = _extractBadgeIds(mdFile.readAsStringSync());
  if (mdIds.isEmpty) {
    stderr.writeln('❌ Aucun ID trouvé dans $_badgesMdPath');
    stderr.writeln('   (les IDs doivent être au format `| `xxx` |` dans les tables)');
    exit(1);
  }

  // 3. Scanner assets/badges/ pour les WebP
  final webpFiles = assetsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.webp'))
      .map((f) => f.uri.pathSegments.last) // nom de fichier seul
      .toList();

  final webpIds = webpFiles
      .map((name) => name.substring(0, name.length - 5)) // retire .webp
      .toSet();

  // 4. Classer
  final ok = <String>[];
  final missing = <String>[];
  final orphans = <String>[];

  for (final id in mdIds) {
    if (webpIds.contains(id)) {
      ok.add(id);
    } else {
      missing.add(id);
    }
  }

  for (final id in webpIds) {
    if (!mdIds.contains(id)) {
      orphans.add(id);
    }
  }

  // 5. Afficher le rapport
  ok.sort();
  missing.sort();
  orphans.sort();

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  Rapport de synchronisation des badges');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('Catalogue (badges.md)  : ${mdIds.length} badges');
  print('Visuels (assets/badges): ${webpIds.length} WebP');
  print('');
  print('✅ OK           : ${ok.length}');
  print('🎨 À dessiner   : ${missing.length}');
  print('🗑️  Orphelins    : ${orphans.length}');
  print('');

  if (missing.isNotEmpty) {
    print('🎨 Badges sans visuel ($_assetsDir/<id>.webp manquant) :');
    for (final id in missing) {
      print('   • $id');
    }
    print('');
  }

  if (orphans.isNotEmpty) {
    print('🗑️  WebP orphelins (fichier sans badge correspondant dans badges.md) :');
    for (final id in orphans) {
      print('   • $_assetsDir/$id.webp');
    }
    print('');
  }

  // 6. Suppression des orphelins (optionnel)
  if (deleteOrphans && orphans.isNotEmpty) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  Suppression des orphelins (--delete-orphans)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    stdout.write('Confirmer la suppression de ${orphans.length} fichier(s) ? [y/N] ');
    final reply = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (reply == 'y' || reply == 'yes' || reply == 'o' || reply == 'oui') {
      for (final id in orphans) {
        final f = File('$_assetsDir/$id.webp');
        try {
          f.deleteSync();
          print('   ✓ supprimé : $_assetsDir/$id.webp');
        } catch (e) {
          print('   ✗ échec    : $_assetsDir/$id.webp ($e)');
        }
      }
    } else {
      print('Annulé.');
    }
    print('');
  } else if (deleteOrphans && orphans.isEmpty) {
    print('Aucun orphelin à supprimer.');
    print('');
  }

  // 7. Exit code : 0 si tout est OK, 1 sinon
  // (pratique pour un usage en pre-commit ou CI plus tard)
  final hasIssues = missing.isNotEmpty || (orphans.isNotEmpty && !deleteOrphans);
  exit(hasIssues ? 1 : 0);
}

/// Extrait les IDs depuis badges.md.
///
/// Format attendu (cellule de tableau Markdown) :
///   | `books_5` | 📚 | Apprenti Lecteur | ...
///
/// On capture les IDs en lowercase + underscores + digits, entre backticks
/// et entourés de pipes (cellule de tableau).
Set<String> _extractBadgeIds(String markdown) {
  final regex = RegExp(r'^\|\s*`([a-z0-9_]+)`\s*\|', multiLine: true);
  return regex
      .allMatches(markdown)
      .map((m) => m.group(1)!)
      .toSet();
}

void _printHelp() {
  print('''
Vérifie la synchronisation entre badges.md et assets/badges/.

Usage :
  dart run tool/check_badges.dart [options]

Options :
  --delete-orphans   Supprime les WebP dans assets/badges/ qui n'ont
                     aucun badge correspondant dans badges.md
                     (demande confirmation avant suppression).
  --help, -h         Affiche cette aide.

Convention :
  Pour chaque badge d'id `xxx` dans badges.md, il doit exister
  assets/badges/xxx.webp (source HD en PNG dans le bucket Supabase)

Codes de sortie :
  0   tout est synchronisé
  1   au moins un badge manquant ou orphelin non supprimé
''');
}
