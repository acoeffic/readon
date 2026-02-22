// pages/auth/legal_notice_page.dart
// Page des mentions légales

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class LegalNoticePage extends StatelessWidget {
  const LegalNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpace.l),
              child: BackHeader(title: 'Mentions légales'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, 'Application LexDay'),
                    const SizedBox(height: AppSpace.m),

                    _buildSectionTitle(context, 'Éditeur de l\'application'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Nom de la société : [Nom de la société]'),
                    _buildText('Forme juridique : SAS / SASU'),
                    _buildText('Capital social : [montant] €'),
                    _buildText('Siège social : [adresse complète]'),
                    _buildText('Immatriculation : RCS [ville] – [numéro SIREN]'),
                    _buildText('Numéro de TVA intracommunautaire : [si applicable, sinon supprimer la ligne]'),
                    _buildText('Adresse email de contact : [email de contact]'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Direction de la publication'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Directeur de la publication : [Nom Prénom], en qualité de Président'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Hébergement'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Hébergeur : [Nom de l\'hébergeur]'),
                    _buildText('Adresse : [adresse complète de l\'hébergeur]'),
                    _buildText('Contact : [email ou téléphone]'),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Propriété intellectuelle'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'L\'ensemble de l\'application LexDay, incluant notamment les textes, '
                      'graphismes, logos, interfaces, fonctionnalités et code source, est '
                      'protégé par le droit de la propriété intellectuelle.',
                    ),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Toute reproduction, représentation, modification ou exploitation, '
                      'totale ou partielle, sans autorisation préalable, est strictement interdite.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Données personnelles'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Le traitement des données personnelles des utilisateurs est effectué '
                      'conformément à la réglementation en vigueur.',
                    ),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'Les modalités de collecte et de traitement sont détaillées dans la '
                      'Politique de confidentialité, accessible depuis l\'application.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Responsabilité'),
                    const SizedBox(height: AppSpace.s),
                    _buildText(
                      'L\'éditeur s\'efforce d\'assurer l\'exactitude et la mise à jour des '
                      'informations diffusées via l\'application LexDay. Toutefois, il ne '
                      'saurait être tenu responsable d\'erreurs, d\'omissions ou d\'une '
                      'indisponibilité temporaire du service.',
                    ),
                    const SizedBox(height: AppSpace.l),

                    _buildSectionTitle(context, 'Droit applicable'),
                    const SizedBox(height: AppSpace.s),
                    _buildText('Les présentes mentions légales sont soumises au droit français.'),
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
}
