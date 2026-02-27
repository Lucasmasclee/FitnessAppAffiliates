import 'package:flutter/material.dart';

import '../functionaliteit/rest_timer_service.dart';

/// Kleine widget rechtsonder, net boven de typische 'Next'/'Save'-knopbalk.
class RestTimerOverlay extends StatelessWidget {
  const RestTimerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RestTimerService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isActive) return const SizedBox.shrink();
        final text = service.remainingFormatted ?? '0:00';
        return Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 26, bottom: 80),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        text,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        onPressed: service.stop,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(2),
                          minimumSize: const Size(28, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
