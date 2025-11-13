import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vaxp_launcher/con/widgets/notification_service.dart';

import '../../application/control_center_cubit.dart';
import '../../application/control_center_state.dart';

class NotificationServicePanel extends StatelessWidget {
  const NotificationServicePanel({
    required this.notifications,
    required this.onPressed,
    super.key,
  });

  final List<VenomNotification> notifications;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: StreamBuilder<DateTime>(
            initialData: DateTime.now(),
            stream: Stream<DateTime>.periodic(
              const Duration(seconds: 1),
              (_) => DateTime.now(),
            ),
            builder: (context, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              final hours = now.hour.toString().padLeft(2, '0');
              final minutes = now.minute.toString().padLeft(2, '0');
              return Text(
                '$hours:$minutes',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(226, 255, 255, 255),
                ),
              );
            },
          ),
        ),
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color.fromARGB(88, 2, 2, 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_rounded,
                  size: 26,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                if (notifications.isNotEmpty)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Center(
                        child: Text(
                          notifications.length > 99
                              ? '99+'
                              : notifications.length.toString(),
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showNotificationsDialog(BuildContext context) {
  final cubit = context.read<ControlCenterCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (dialogContext) {
      return BlocProvider.value(
        value: cubit,
        child: const _NotificationsDialog(),
      );
    },
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 520,
          height: 360,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(220, 28, 32, 44),
                Color.fromARGB(180, 18, 20, 30),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: BlocBuilder<ControlCenterCubit, ControlCenterState>(
            builder: (context, state) {
              if (state.notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(40, 255, 255, 255),
                              Color.fromARGB(8, 255, 255, 255),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_off_rounded,
                          size: 46,
                          color: Color.fromARGB(255, 27, 167, 167),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No New Notifications',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(54, 255, 255, 255),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () {
                          context.read<ControlCenterCubit>().clearNotifications();
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Clear All'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = state.notifications[index];
                        final timeStr =
                            '${notif.time.hour.toString().padLeft(2, '0')}:${notif.time.minute.toString().padLeft(2, '0')}';
                        return Dismissible(
                          key: ValueKey(notif.id),
                          onDismissed: (_) {
                            context
                                .read<ControlCenterCubit>()
                                .removeNotification(notif.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.fromARGB(30, 255, 255, 255),
                                  Color.fromARGB(6, 255, 255, 255),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.02),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: Colors.tealAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        notif.appName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notif.summary,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (notif.body.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    notif.body,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

