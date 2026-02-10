// lib/services/contacts_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _prefKeyContactsPromptSeen = 'has_seen_contacts_prompt';

  /// Verifie si c'est la premiere session terminee de l'utilisateur
  Future<bool> hasCompletedFirstSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return true;

    try {
      final result = await _supabase
          .from('profiles')
          .select('has_completed_first_session')
          .eq('id', user.id)
          .single();

      return result['has_completed_first_session'] as bool? ?? false;
    } catch (e) {
      debugPrint('Erreur hasCompletedFirstSession: $e');
      return true;
    }
  }

  /// Marque la premiere session comme terminee
  Future<void> markFirstSessionCompleted() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'has_completed_first_session': true})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Erreur markFirstSessionCompleted: $e');
    }
  }

  /// Verifie si l'utilisateur a deja vu le prompt contacts (cache local + DB)
  Future<bool> hasSeenContactsPrompt() async {
    // Cache local d'abord pour eviter un appel DB
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeyContactsPromptSeen) == true) return true;

    final user = _supabase.auth.currentUser;
    if (user == null) return true;

    try {
      final result = await _supabase
          .from('profiles')
          .select('has_seen_contacts_prompt')
          .eq('id', user.id)
          .single();

      final seen = result['has_seen_contacts_prompt'] as bool? ?? false;
      if (seen) {
        await prefs.setBool(_prefKeyContactsPromptSeen, true);
      }
      return seen;
    } catch (e) {
      debugPrint('Erreur hasSeenContactsPrompt: $e');
      return false;
    }
  }

  /// Marque le prompt contacts comme vu
  Future<void> markContactsPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyContactsPromptSeen, true);

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'has_seen_contacts_prompt': true})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Erreur markContactsPromptSeen: $e');
    }
  }

  /// Demande la permission d'acces aux contacts
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Verifie si la permission contacts est definitivement refusee
  Future<bool> isContactsPermissionPermanentlyDenied() async {
    return await Permission.contacts.isPermanentlyDenied;
  }

  /// Hash une chaine en SHA256
  String _hashSHA256(String input) {
    return sha256.convert(utf8.encode(input.toLowerCase().trim())).toString();
  }

  /// Normalise un numero de telephone pour le hashing
  String _normalizePhone(String phone) {
    // Enlever tous les caracteres non-numeriques sauf le +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Gestion des numeros francais
    if (cleaned.startsWith('+33')) {
      cleaned = cleaned.substring(3); // Enlever +33
    } else if (cleaned.startsWith('0033')) {
      cleaned = cleaned.substring(4); // Enlever 0033
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = cleaned.substring(1); // Enlever le 0 initial
    }

    // Prefixer avec 33 pour uniformiser
    if (cleaned.length == 9 && !cleaned.startsWith('33')) {
      cleaned = '33$cleaned';
    }

    return cleaned;
  }

  /// Recupere les contacts, extrait emails et telephones, retourne les hashes SHA256
  Future<List<String>> getContactHashes() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final Set<String> hashes = {};

      for (final contact in contacts) {
        // Hash des emails
        for (final email in contact.emails) {
          if (email.address.isNotEmpty) {
            hashes.add(_hashSHA256(email.address));
          }
        }

        // Hash des telephones
        for (final phone in contact.phones) {
          if (phone.number.isNotEmpty) {
            final normalized = _normalizePhone(phone.number);
            if (normalized.length >= 9) {
              hashes.add(_hashSHA256(normalized));
            }
          }
        }
      }

      return hashes.toList();
    } catch (e) {
      debugPrint('Erreur getContactHashes: $e');
      return [];
    }
  }

  /// Envoie les hashes a Supabase et retourne les utilisateurs matchants
  Future<List<ContactMatch>> findMatchedUsers(List<String> hashes) async {
    if (hashes.isEmpty) return [];

    try {
      // Batching si trop de hashes
      final List<ContactMatch> allMatches = [];
      const batchSize = 1000;

      for (int i = 0; i < hashes.length; i += batchSize) {
        final batch = hashes.sublist(
          i,
          i + batchSize > hashes.length ? hashes.length : i + batchSize,
        );

        final result = await _supabase.rpc(
          'find_contacts_matches',
          params: {'p_hashes': batch},
        );

        for (final item in (result as List)) {
          final json = item as Map<String, dynamic>;
          allMatches.add(ContactMatch(
            id: json['id'] as String,
            displayName: json['display_name'] as String? ?? 'Utilisateur',
            email: json['email'] as String?,
            avatarUrl: json['avatar_url'] as String?,
            isProfilePrivate: json['is_profile_private'] as bool? ?? false,
          ));
        }
      }

      return allMatches;
    } catch (e) {
      debugPrint('Erreur findMatchedUsers: $e');
      return [];
    }
  }

  /// Flow complet : permission → contacts → hash → matching
  Future<List<ContactMatch>> fetchAndMatchContacts() async {
    final granted = await requestContactsPermission();
    if (!granted) return [];

    final hashes = await getContactHashes();
    return findMatchedUsers(hashes);
  }

  /// Flow complet avec details : retourne les contacts matches ET non-matches
  /// Les contacts non-matches gardent leur nom et telephone pour l'invitation SMS
  Future<ContactsResult> fetchContactsWithDetails() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final Set<String> allHashes = {};
      final Map<String, _RawContactInfo> hashToContact = {};

      for (final contact in contacts) {
        final name = contact.displayName.isNotEmpty
            ? contact.displayName
            : 'Contact';

        // Hash des emails
        for (final email in contact.emails) {
          if (email.address.isNotEmpty) {
            final hash = _hashSHA256(email.address);
            allHashes.add(hash);
            hashToContact.putIfAbsent(
              hash,
              () => _RawContactInfo(
                name: name,
                phone: contact.phones.isNotEmpty
                    ? contact.phones.first.number
                    : null,
                email: email.address,
              ),
            );
          }
        }

        // Hash des telephones
        for (final phone in contact.phones) {
          if (phone.number.isNotEmpty) {
            final normalized = _normalizePhone(phone.number);
            if (normalized.length >= 9) {
              final hash = _hashSHA256(normalized);
              allHashes.add(hash);
              hashToContact.putIfAbsent(
                hash,
                () => _RawContactInfo(
                  name: name,
                  phone: phone.number,
                  email: contact.emails.isNotEmpty
                      ? contact.emails.first.address
                      : null,
                ),
              );
            }
          }
        }
      }

      // Obtenir les utilisateurs matches
      final matched = await findMatchedUsers(allHashes.toList());

      // Identifier les contacts non-matches
      final matchedNames =
          matched.map((m) => m.displayName.toLowerCase()).toSet();
      final matchedEmails = matched
          .where((m) => m.email != null)
          .map((m) => m.email!.toLowerCase())
          .toSet();

      final seenNames = <String>{};
      final unmatched = <UnmatchedContact>[];

      for (final entry in hashToContact.entries) {
        final info = entry.value;
        if (info.phone == null) continue;

        final nameKey = info.name.toLowerCase();
        if (matchedNames.contains(nameKey)) continue;
        if (matchedEmails.contains(info.email?.toLowerCase())) continue;
        if (seenNames.contains(nameKey)) continue;

        seenNames.add(nameKey);
        unmatched.add(UnmatchedContact(
          displayName: info.name,
          phone: info.phone!,
          email: info.email,
        ));
      }

      unmatched.sort((a, b) => a.displayName.compareTo(b.displayName));

      return ContactsResult(matched: matched, unmatched: unmatched);
    } catch (e) {
      debugPrint('Erreur fetchContactsWithDetails: $e');
      return ContactsResult(matched: [], unmatched: []);
    }
  }

  /// Envoie une demande d'ami
  Future<bool> sendFriendRequest(String targetUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // Verifier s'il n'existe pas deja une relation
      final existing = await _supabase
          .from('friends')
          .select('id, status')
          .or(
            'and(requester_id.eq.${user.id},addressee_id.eq.$targetUserId),and(requester_id.eq.$targetUserId,addressee_id.eq.${user.id})',
          )
          .limit(1);

      if ((existing as List).isNotEmpty) return false;

      await _supabase.from('friends').insert({
        'requester_id': user.id,
        'addressee_id': targetUserId,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      debugPrint('Erreur sendFriendRequest: $e');
      return false;
    }
  }
}

class _RawContactInfo {
  final String name;
  final String? phone;
  final String? email;
  _RawContactInfo({required this.name, this.phone, this.email});
}

/// Resultat combine du scan de contacts
class ContactsResult {
  final List<ContactMatch> matched;
  final List<UnmatchedContact> unmatched;

  ContactsResult({required this.matched, required this.unmatched});
}

/// Contact non inscrit sur Lexsta (pour invitation SMS)
class UnmatchedContact {
  final String displayName;
  final String phone;
  final String? email;

  UnmatchedContact({
    required this.displayName,
    required this.phone,
    this.email,
  });
}

/// Modele simplifie pour un contact matche
class ContactMatch {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final bool isProfilePrivate;

  ContactMatch({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.isProfilePrivate = false,
  });
}
