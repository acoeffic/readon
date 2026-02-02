import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/kindle_webview_service.dart';

class StepSyncProgress extends StatefulWidget {
  final KindleReadingData? kindleData;
  final VoidCallback onSyncComplete;

  const StepSyncProgress({
    super.key,
    required this.kindleData,
    required this.onSyncComplete,
  });

  @override
  State<StepSyncProgress> createState() => _StepSyncProgressState();
}

class _StepSyncProgressState extends State<StepSyncProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    final bookCount = widget.kindleData?.books.length ?? 0;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _countAnimation = Tween<double>(
      begin: 0,
      end: bookCount.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onSyncComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Synchronisation en cours...',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.l),
          AnimatedBuilder(
            animation: _countAnimation,
            builder: (context, child) {
              return Text(
                '${_countAnimation.value.toInt()} livres trouvés',
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Import de ta bibliothèque...',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
