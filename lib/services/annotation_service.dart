// lib/services/annotation_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/annotation_model.dart';

class AnnotationService {
  /// Incrémenté quand des annotations sont créées HORS du flux UI normal —
  /// aujourd'hui l'import des surlignages Kindle en fin d'auto-sync. L'onglet
  /// Mes passages est keep-alive et ne charge qu'à sa première construction :
  /// sans ce signal, un import qui atterrit ensuite restait invisible jusqu'à
  /// un pull-to-refresh ou un redémarrage (constaté au premier test réel du
  /// sync des highlights, 21/08/2026).
  static final ValueNotifier<int> version = ValueNotifier<int>(0);
  static void notifyChanged() => version.value++;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupérer les annotations d'un livre, triées par date décroissante
  Future<List<Annotation>> getAnnotationsForBook(String bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('annotations')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Annotation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getAnnotationsForBook: $e');
      return [];
    }
  }

  /// Récupérer les annotations d'une session, triées par date décroissante
  Future<List<Annotation>> getAnnotationsForSession(String sessionId) async {
    try {
      final response = await _supabase
          .from('annotations')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Annotation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getAnnotationsForSession: $e');
      return [];
    }
  }

  /// Agrégat par livre pour la grille Mes passages : compte de passages et
  /// date du dernier, via la RPC `get_annotation_book_groups` (migration
  /// 20260821). `query` filtre côté serveur sur le contenu et la note.
  ///
  /// Remplace le chargement de toutes les annotations (limit 500) qui faisait
  /// silencieusement disparaître les passages anciens du mur dès que le
  /// volume montait — l'import Kindle en amène des centaines d'un coup.
  /// Les métadonnées livres arrivent par une 2e requête : `annotations.book_id`
  /// est du texte, `books.id` un bigint, pas de FK exploitable par PostgREST.
  Future<List<AnnotationBookGroup>> getAnnotationBookGroups({
    String? query,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final trimmed = query?.trim();
      final rows = await _supabase.rpc('get_annotation_book_groups', params: {
        'p_query': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      });

      final list = ((rows as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (list.isEmpty) return [];

      final bookIds = <int>{};
      for (final r in list) {
        final id = int.tryParse(r['book_id'] as String? ?? '');
        if (id != null) bookIds.add(id);
      }

      final booksById = <String, Map<String, dynamic>>{};
      if (bookIds.isNotEmpty) {
        try {
          final booksResponse = await _supabase
              .from('books')
              .select('id, title, author, cover_url, isbn, google_id')
              .inFilter('id', bookIds.toList());
          for (final row in (booksResponse as List)) {
            booksById[row['id'].toString()] = row as Map<String, dynamic>;
          }
        } catch (e) {
          // La grille reste affichable sans les couvertures.
          debugPrint('Erreur chargement livres des groupes: $e');
        }
      }

      return [
        for (final r in list)
          AnnotationBookGroup(
            bookId: r['book_id'] as String,
            passageCount: (r['passage_count'] as num?)?.toInt() ?? 0,
            latestAt: DateTime.parse(r['latest_at'] as String).toLocal(),
            book: booksById[r['book_id']],
          ),
      ];
    } catch (e) {
      debugPrint('Erreur getAnnotationBookGroups: $e');
      return [];
    }
  }

  /// Récupérer TOUTES les annotations de l'utilisateur, tous livres confondus,
  /// enrichies du livre auquel elles appartiennent.
  ///
  /// N'alimente plus la grille Mes passages (voir [getAnnotationBookGroups]) —
  /// conservé pour un futur usage type export ou Daily Review, mais attention
  /// à sa `limit` avant de s'en resservir.
  ///
  /// Deux requêtes plutôt qu'une jointure : `annotations.book_id` est stocké en
  /// texte alors que `books.id` est un bigint, il n'y a donc pas de clé
  /// étrangère exploitable par PostgREST.
  Future<List<AnnotationWithBook>> getAllAnnotationsWithBooks({
    int limit = 500,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('annotations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final annotations = (response as List)
          .map((json) => Annotation.fromJson(json))
          .toList();
      if (annotations.isEmpty) return [];

      // Les book_id exploitables (certains peuvent être non numériques si la
      // donnée a été écrite par un chemin exotique : on les ignore plutôt que
      // de faire échouer toute la page).
      final bookIds = <int>{};
      for (final a in annotations) {
        final id = int.tryParse(a.bookId);
        if (id != null) bookIds.add(id);
      }

      final booksById = <String, Map<String, dynamic>>{};
      if (bookIds.isNotEmpty) {
        try {
          final booksResponse = await _supabase
              .from('books')
              .select('id, title, author, cover_url, isbn, google_id')
              .inFilter('id', bookIds.toList());
          for (final row in (booksResponse as List)) {
            booksById[row['id'].toString()] = row as Map<String, dynamic>;
          }
        } catch (e) {
          // Le mur reste affichable sans les couvertures.
          debugPrint('Erreur chargement livres des annotations: $e');
        }
      }

      return [
        for (final a in annotations)
          AnnotationWithBook(
            annotation: a,
            book: booksById[a.bookId],
          ),
      ];
    } catch (e) {
      debugPrint('Erreur getAllAnnotationsWithBooks: $e');
      return [];
    }
  }

  /// Renseigner `image_path` après l'upload de la photo source.
  ///
  /// Séparé de `createAnnotation` parce que le chemin de stockage contient
  /// l'id de l'annotation : il faut donc l'insert avant l'upload.
  Future<void> setAnnotationImagePath(String id, String imagePath) async {
    await _supabase
        .from('annotations')
        .update({'image_path': imagePath}).eq('id', id);
  }

  /// Créer une nouvelle annotation
  Future<Annotation> createAnnotation({
    required String bookId,
    String? sessionId,
    required String content,
    int? pageNumber,
    AnnotationType type = AnnotationType.text,
    String? imagePath,
    String? audioPath,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final insertData = <String, dynamic>{
        'user_id': userId,
        'book_id': bookId,
        'content': content,
        'type': type.name,
      };
      if (sessionId != null) insertData['session_id'] = sessionId;
      if (pageNumber != null) insertData['page_number'] = pageNumber;
      if (imagePath != null) insertData['image_path'] = imagePath;
      if (audioPath != null) insertData['audio_path'] = audioPath;

      final response = await _supabase
          .from('annotations')
          .insert(insertData)
          .select()
          .single();

      return Annotation.fromJson(response);
    } catch (e) {
      debugPrint('Erreur createAnnotation: $e');
      rethrow;
    }
  }

  /// Mettre à jour une annotation existante
  Future<Annotation> updateAnnotation(
    String id, {
    String? content,
    int? pageNumber,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (content != null) updateData['content'] = content;
      if (pageNumber != null) updateData['page_number'] = pageNumber;

      final response = await _supabase
          .from('annotations')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return Annotation.fromJson(response);
    } catch (e) {
      debugPrint('Erreur updateAnnotation: $e');
      rethrow;
    }
  }

  /// Supprimer une annotation (et son image si type photo)
  Future<void> deleteAnnotation(String id) async {
    try {
      // Récupérer l'annotation pour vérifier s'il y a une image à supprimer
      final response = await _supabase
          .from('annotations')
          .select()
          .eq('id', id)
          .single();

      final annotation = Annotation.fromJson(response);

      // Supprimer l'image du storage si c'est une annotation photo
      if (annotation.type == AnnotationType.photo &&
          annotation.imagePath != null) {
        try {
          await _supabase.storage
              .from('annotations')
              .remove([annotation.imagePath!]);
        } catch (e) {
          debugPrint('Erreur suppression image annotation: $e');
        }
      }

      // Supprimer l'audio du storage si c'est une annotation vocale
      if (annotation.type == AnnotationType.voice &&
          annotation.audioPath != null) {
        try {
          await _supabase.storage
              .from('annotations')
              .remove([annotation.audioPath!]);
        } catch (e) {
          debugPrint('Erreur suppression audio annotation: $e');
        }
      }

      await _supabase.from('annotations').delete().eq('id', id);
    } catch (e) {
      debugPrint('Erreur deleteAnnotation: $e');
      rethrow;
    }
  }

  /// Uploader une image d'annotation dans Supabase Storage
  /// Retourne le chemin relatif dans le bucket (pour stocker dans image_path)
  Future<String> uploadAnnotationImage(
    String annotationId,
    String filePath,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final storagePath = '$userId/$annotationId.jpg';

      await _supabase.storage.from('annotations').upload(
            storagePath,
            File(filePath),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return storagePath;
    } catch (e) {
      debugPrint('Erreur uploadAnnotationImage: $e');
      rethrow;
    }
  }

  /// Uploader un enregistrement audio dans Supabase Storage
  /// Retourne le chemin relatif dans le bucket (pour stocker dans audio_path)
  Future<String> uploadAnnotationAudio(
    String annotationId,
    String filePath,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final storagePath = '$userId/$annotationId.m4a';

      await _supabase.storage.from('annotations').upload(
            storagePath,
            File(filePath),
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: true,
            ),
          );

      return storagePath;
    } catch (e) {
      debugPrint('Erreur uploadAnnotationAudio: $e');
      rethrow;
    }
  }

  /// Obtenir l'URL publique d'une image d'annotation
  String getImageUrl(String imagePath) {
    return _supabase.storage.from('annotations').getPublicUrl(imagePath);
  }

  /// Obtenir l'URL publique d'un audio d'annotation
  String getAudioUrl(String audioPath) {
    return _supabase.storage.from('annotations').getPublicUrl(audioPath);
  }
}

/// Un livre et l'agrégat de ses passages (compte + date du dernier), pour la
/// grille Mes passages. Le livre peut être `null` si la ligne `books` a
/// disparu.
class AnnotationBookGroup {
  final String bookId;
  final int passageCount;
  final DateTime latestAt;
  final Map<String, dynamic>? book;

  const AnnotationBookGroup({
    required this.bookId,
    required this.passageCount,
    required this.latestAt,
    this.book,
  });

  String? get bookTitle => book?['title'] as String?;
  String? get bookAuthor => book?['author'] as String?;
  String? get bookCoverUrl => book?['cover_url'] as String?;
  String? get bookIsbn => book?['isbn'] as String?;
  String? get bookGoogleId => book?['google_id'] as String?;
}

/// Une annotation accompagnée des métadonnées du livre auquel elle appartient.
/// Le livre peut être `null` si la ligne `books` a disparu.
class AnnotationWithBook {
  final Annotation annotation;
  final Map<String, dynamic>? book;

  const AnnotationWithBook({required this.annotation, this.book});

  String? get bookTitle => book?['title'] as String?;
  String? get bookAuthor => book?['author'] as String?;
  String? get bookCoverUrl => book?['cover_url'] as String?;
  String? get bookIsbn => book?['isbn'] as String?;
  String? get bookGoogleId => book?['google_id'] as String?;
}
