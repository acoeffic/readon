// lib/services/annotation_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/annotation_model.dart';

class AnnotationService {
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

  /// Créer une nouvelle annotation
  Future<Annotation> createAnnotation({
    required String bookId,
    String? sessionId,
    required String content,
    int? pageNumber,
    AnnotationType type = AnnotationType.text,
    String? imagePath,
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
    bool? isPublic,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (content != null) updateData['content'] = content;
      if (pageNumber != null) updateData['page_number'] = pageNumber;
      if (isPublic != null) updateData['is_public'] = isPublic;

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

  /// Obtenir l'URL publique d'une image d'annotation
  String getImageUrl(String imagePath) {
    return _supabase.storage.from('annotations').getPublicUrl(imagePath);
  }
}
