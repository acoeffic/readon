// lib/pages/auth/terms_of_service_page.dart
// Page des Conditions Générales d'Utilisation

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsOfServicePage extends StatelessWidget {
  final bool requireAcceptance;
  final VoidCallback? onAccept;

  const TermsOfServicePage({
    super.key,
    this.requireAcceptance = false,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Conditions d\'utilisation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    '1. Objet',
                    'Les présentes Conditions Générales d\'Utilisation (ci-après les « CGU ») ont pour objet de définir les conditions dans lesquelles les utilisateurs (ci-après l\'« Utilisateur ») peuvent accéder et utiliser l\'application LexDay (ci-après l\'« Application »).\n\nLexDay est une application de club de lecture social, permettant notamment de :\n• Suivre ses lectures,\n• Partager son activité de lecture,\n• Interagir avec d\'autres utilisateurs,\n• Participer à des défis, badges ou classements.\n\nToute utilisation de l\'Application implique l\'acceptation pleine et entière des présentes CGU.',
                  ),
                  _buildSection(
                    '2. Éditeur de l\'Application',
                    'L\'Application est éditée par :\n• Société : LexDay\n• Adresse email : contact@readon.app',
                  ),
                  _buildSection(
                    '3. Accès à l\'Application',
                    'L\'Application est accessible :\n• Via une application mobile et/ou une interface web,\n• À toute personne disposant d\'un accès à Internet.\n\nL\'Éditeur s\'efforce d\'assurer un accès continu à l\'Application, sans toutefois garantir une disponibilité permanente.\n\nL\'Éditeur se réserve le droit de :\n• Suspendre l\'accès à l\'Application pour maintenance,\n• Modifier, interrompre ou faire évoluer tout ou partie des fonctionnalités.',
                  ),
                  _buildSection(
                    '4. Création de compte utilisateur',
                    'L\'accès à certaines fonctionnalités de LexDay nécessite la création d\'un compte utilisateur.\n\nL\'Utilisateur s\'engage à :\n• Fournir des informations exactes lors de l\'inscription,\n• Mettre à jour ses informations si nécessaire,\n• Conserver la confidentialité de ses identifiants.\n\nToute activité réalisée depuis un compte est réputée effectuée par son titulaire.',
                  ),
                  _buildSection(
                    '5. Fonctionnalités de l\'Application',
                    'LexDay permet notamment à l\'Utilisateur :\n• D\'enregistrer ses lectures,\n• De suivre sa progression de lecture,\n• De publier des activités ou commentaires,\n• D\'interagir avec d\'autres membres de la communauté,\n• De participer à des défis, challenges ou classements.\n\nL\'Éditeur se réserve le droit de faire évoluer les fonctionnalités à tout moment.',
                  ),
                  _buildSection(
                    '6. Comportement des Utilisateurs',
                    'L\'Utilisateur s\'engage à adopter un comportement respectueux et loyal.\n\nIl est strictement interdit :\n• De publier des contenus illicites, diffamatoires, injurieux ou haineux,\n• D\'usurper l\'identité d\'un tiers,\n• De détourner l\'Application de son usage social et culturel,\n• De perturber le bon fonctionnement de l\'Application.\n\nL\'Éditeur se réserve le droit de suspendre ou supprimer tout compte ne respectant pas ces règles.',
                  ),
                  _buildSection(
                    '7. Contenus publiés par les Utilisateurs',
                    'Les Utilisateurs sont seuls responsables des contenus qu\'ils publient (textes, commentaires, avis, données de lecture).\n\nEn publiant du contenu sur LexDay, l\'Utilisateur concède à l\'Éditeur :\n• Une licence non exclusive,\n• Gratuite,\n• Mondiale,\n• Pour la durée de protection légale,\n• Aux fins d\'exploitation, d\'affichage et de promotion de l\'Application.\n\nL\'Utilisateur garantit disposer des droits nécessaires sur les contenus publiés.',
                  ),
                  _buildSection(
                    '8. Responsabilité',
                    'L\'Application est fournie « en l\'état ».\n\nL\'Éditeur ne saurait être tenu responsable :\n• Des interruptions de service,\n• Des erreurs ou omissions,\n• Des conséquences liées à l\'utilisation des informations partagées par d\'autres Utilisateurs.\n\nL\'Utilisateur est seul responsable de l\'usage qu\'il fait de l\'Application et des interactions avec la communauté.',
                  ),
                  _buildSection(
                    '9. Propriété intellectuelle',
                    'L\'Application LexDay, incluant notamment :\n• Son nom,\n• Son interface,\n• Son code,\n• Sa structure,\n• Ses éléments graphiques,\n\nest protégée par le droit de la propriété intellectuelle.\n\nToute reproduction ou exploitation non autorisée est strictement interdite.',
                  ),
                  _buildSection(
                    '10. Données personnelles',
                    'L\'Éditeur s\'engage à respecter la réglementation applicable en matière de protection des données personnelles, notamment le RGPD.\n\nLes modalités de collecte et de traitement des données sont détaillées dans la Politique de confidentialité, accessible depuis l\'Application.',
                  ),
                  _buildSection(
                    '11. Durée – Résiliation',
                    'Les présentes CGU sont conclues pour une durée indéterminée.\n\nL\'Utilisateur peut supprimer son compte à tout moment.\n\nL\'Éditeur se réserve le droit de suspendre ou supprimer un compte en cas de violation des CGU.',
                  ),
                  _buildSection(
                    '12. Modification des CGU',
                    'Les présentes CGU peuvent être modifiées à tout moment par l\'Éditeur.\n\nLes nouvelles versions sont opposables dès leur mise en ligne.',
                  ),
                  _buildSection(
                    '13. Droit applicable et juridiction compétente',
                    'Les présentes CGU sont soumises au droit français.\n\nEn cas de litige, et à défaut de résolution amiable, les tribunaux compétents seront ceux du ressort du siège social de l\'Éditeur.',
                  ),
                  _buildSection(
                    '14. Contact',
                    'Pour toute question relative aux CGU :\n📧 contact@readon.app',
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          // Bouton d'acceptation (si requis)
          if (requireAcceptance && onAccept != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'J\'accepte les conditions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}