import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Micro-vibration globale au tap sur tout élément tappable de l'app
/// (boutons, cases, cartes, entrées de menu, onglets de navigation…).
///
/// Placé une seule fois dans `MaterialApp.builder` : aucune page n'a besoin
/// d'appeler `HapticFeedback` pour un simple tap.
///
/// Fonctionnement : au contact du doigt, on teste ce qui se trouve sous lui.
/// Si c'est un widget qui réagit au tap (`GestureDetector`, `InkWell`,
/// boutons Material… — tout ce qui expose une action `onTap`), on mémorise le
/// contact. La vibration (`selectionClick`, la plus légère) n'est émise qu'au
/// relâchement, si le geste est bien un tap : doigt quasi immobile et appui
/// court. Un scroll, un swipe ou un appui long ne vibrent donc pas.
///
/// Sans effet sur le web/desktop, et soumis au réglage système de l'utilisateur
/// (Retour haptique iOS, Vibration au toucher Android).
class TapHaptics extends StatefulWidget {
  const TapHaptics({super.key, required this.child});

  final Widget child;

  @override
  State<TapHaptics> createState() => _TapHapticsState();
}

class _PendingTap {
  const _PendingTap(this.position, this.timestamp);

  final Offset position;
  final Duration timestamp;
}

class _TapHapticsState extends State<TapHaptics> {
  final Map<int, _PendingTap> _pending = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: (e) => _pending.remove(e.pointer),
      child: widget.child,
    );
  }

  void _onDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (_isOverTappable(event)) {
      _pending[event.pointer] = _PendingTap(event.position, event.timeStamp);
    }
  }

  void _onUp(PointerUpEvent event) {
    final down = _pending.remove(event.pointer);
    if (down == null) return;
    final moved = (event.position - down.position).distance;
    final held = event.timeStamp - down.timestamp;
    if (moved < kTouchSlop && held < kLongPressTimeout) {
      HapticFeedback.selectionClick();
    }
  }

  /// Vrai si, sous le doigt, un widget *plus profond que ce Listener* réagit
  /// au tap. On s'arrête au Listener pour ignorer les détecteurs situés au-dessus
  /// (ex. le `GestureDetector` racine qui ferme le clavier, présent partout).
  bool _isOverTappable(PointerDownEvent event) {
    final self = context.findRenderObject();
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (identical(target, self)) break;
      if (target is RenderSemanticsGestureHandler && target.onTap != null) {
        return true;
      }
    }
    return false;
  }
}
