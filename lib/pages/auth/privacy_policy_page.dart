// lib/pages/auth/privacy_policy_page.dart
// Page de la Politique de confidentialité

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpace.l),
              child: BackHeader(title: 'Politique de confidentialité'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dernière mise à jour : 05/03/2026',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '1. Responsable du traitement'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Les données personnelles collectées via l\'application LexDay sont traitées par :',
                    ),
                    _buildText('Société : LexDay SAS'),
                    _buildText('Forme juridique : SAS'),
                    _buildText('Siège social : 60 rue François 1er, 75008 Paris'),
                    _buildText('Email de contact : hello@lexday.fr'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '2. Données personnelles collectées'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Dans le cadre de l\'utilisation de LexDay, les données suivantes peuvent être collectées :',
                    ),
                    const SizedBox(height: AppSpace.s),
                    _buildSubTitle(context, '2.1 Données fournies directement par l\'Utilisateur'),
                    _buildBullet('Adresse email'),
                    _buildBullet('Nom d\'utilisateur / pseudonyme'),
                    _buildBullet('Photo de profil (facultative)'),
                    _buildBullet('Contenus publiés (lectures, commentaires, avis, interactions)'),
                    const SizedBox(height: AppSpace.s),
                    _buildSubTitle(context, '2.2 Données liées à l\'usage de l\'Application'),
                    _buildBullet('Livres suivis ou enregistrés'),
                    _buildBullet('Activité de lecture (progression, historique)'),
                    _buildBullet('Participation à des défis, badges ou classements'),
                    const SizedBox(height: AppSpace.s),
                    _buildSubTitle(context, '2.3 Données techniques'),
                    _buildBullet('Type d\'appareil'),
                    _buildBullet('Système d\'exploitation'),
                    _buildBullet('Adresse IP (de manière indirecte)'),
                    _buildBullet('Logs techniques nécessaires au fonctionnement et à la sécurité'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '3. Finalités du traitement'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Les données personnelles sont collectées pour les finalités suivantes :',
                    ),
                    _buildBullet('Création et gestion du compte utilisateur'),
                    _buildBullet('Fonctionnement des fonctionnalités sociales de LexDay'),
                    _buildBullet('Affichage de l\'activité de lecture et des interactions'),
                    _buildBullet('Amélioration de l\'expérience utilisateur'),
                    _buildBullet('Sécurité et prévention des abus'),
                    _buildBullet('Communication liée au service (notifications, informations importantes)'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '4. Base légale du traitement'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Les traitements sont fondés sur :'),
                    _buildBullet('L\'exécution du contrat (utilisation de l\'Application)'),
                    _buildBullet('Le consentement de l\'Utilisateur (contenus publiés, communications facultatives)'),
                    _buildBullet('L\'intérêt légitime du Responsable du traitement (sécurité, amélioration du service)'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '5. Caractère obligatoire ou facultatif des données'),
                    const SizedBox(height: AppSpace.s),
                    _buildBullet('Les données nécessaires à la création du compte sont obligatoires'),
                    _buildBullet('Les données de profil et de publication sont facultatives'),
                    _buildBullet('L\'absence de certaines données peut limiter l\'accès à certaines fonctionnalités'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '6. Destinataires des données'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Les données personnelles sont destinées :'),
                    _buildBullet('Aux équipes internes du Responsable du traitement'),
                    _buildBullet('Aux prestataires techniques strictement nécessaires (hébergement, maintenance)'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Aucune donnée personnelle n\'est vendue à des tiers.'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '7. Hébergement et sécurité'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Les données sont hébergées par un prestataire situé :'),
                    _buildBullet('Dans l\'Union européenne'),
                    _buildBullet('Ou dans un pays offrant un niveau de protection adéquat au sens du RGPD'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Des mesures techniques et organisationnelles sont mises en œuvre pour assurer :'),
                    _buildBullet('La confidentialité'),
                    _buildBullet('L\'intégrité'),
                    _buildBullet('La sécurité des données'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '8. Durée de conservation'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Les données sont conservées :'),
                    _buildBullet('Tant que le compte utilisateur est actif'),
                    _buildBullet('Puis supprimées ou anonymisées dans un délai de 12 mois après suppression du compte'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Les données techniques peuvent être conservées pour une durée plus courte à des fins de sécurité.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '9. Droits des Utilisateurs'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Conformément au RGPD, l\'Utilisateur dispose des droits suivants :',
                    ),
                    _buildBullet('Droit d\'accès'),
                    _buildBullet('Droit de rectification'),
                    _buildBullet('Droit à l\'effacement'),
                    _buildBullet('Droit à la limitation du traitement'),
                    _buildBullet('Droit d\'opposition'),
                    _buildBullet('Droit à la portabilité des données'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Ces droits peuvent être exercés à tout moment en écrivant à : hello@lexday.fr',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '10. Suppression du compte'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'L\'Utilisateur peut supprimer son compte à tout moment depuis l\'Application ou en contactant le Responsable du traitement.',
                    ),
                    _buildText(
                      'La suppression entraîne la suppression ou l\'anonymisation des données associées, sauf obligation légale contraire.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '11. Cookies et traceurs'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('LexDay peut utiliser :'),
                    _buildBullet('Des cookies ou traceurs strictement nécessaires au fonctionnement'),
                    _buildBullet('Des outils de mesure d\'audience anonymisés'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Aucun cookie publicitaire n\'est utilisé sans consentement explicite.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '12. Modification de la politique de confidentialité'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('La présente politique peut être modifiée à tout moment.'),
                    _buildText('Les Utilisateurs seront informés de toute modification substantielle.'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, '13. Réclamation'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'En cas de difficulté non résolue, l\'Utilisateur peut introduire une réclamation auprès de l\'autorité de contrôle compétente (CNIL).',
                    ),
                    const SizedBox(height: AppSpace.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSubTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
