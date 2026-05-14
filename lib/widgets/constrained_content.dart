import 'package:flutter/widgets.dart';
import '../utils/responsive.dart';

class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = Responsive.contentMaxWidth,
  });

  /// Variante pour les pages "contenu" (Feed, Library, Profile, Stats…) qui
  /// méritent d'utiliser plus de largeur sur iPad pour éviter l'effet "phone
  /// étiré". Reste à 600 px sur iPhone.
  const ConstrainedContent.wide({
    super.key,
    required this.child,
  }) : maxWidth = Responsive.wideContentMaxWidth;

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
