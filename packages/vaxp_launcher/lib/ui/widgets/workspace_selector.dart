import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../services/workspace_service.dart';

class WorkspaceSelector extends StatelessWidget {
  const WorkspaceSelector({
    super.key,
    required this.workspaces,
    required this.hoveredWorkspace,
    required this.onWorkspaceHover,
    required this.onWorkspaceTap,
  });

  final List<Workspace> workspaces;
  final int? hoveredWorkspace;
  final Function(int?) onWorkspaceHover;
  final Function(int) onWorkspaceTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 200,
        borderRadius: 16,
        linearGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(0, 0, 0, 0), Color.fromARGB(0, 0, 0, 0)],
        ),
        border: 1.2,
        blur: 26,
        borderGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: workspaces.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: workspaces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final w = workspaces[idx];
                    final isHovered = hoveredWorkspace == w.index;
                    final isCurrent = w.isCurrent;

                    final Color baseColor;
                    if (isCurrent) {
                      baseColor = Colors.white.withOpacity(0.16);
                    } else if (isHovered) {
                      baseColor = Colors.white.withOpacity(0.12);
                    } else {
                      baseColor = Colors.white.withOpacity(0.08);
                    }

                    final Color borderColor = isCurrent
                        ? Colors.white.withOpacity(0.5)
                        : Colors.transparent;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => onWorkspaceHover(w.index),
                      onExit: (_) => onWorkspaceHover(null),
                      child: GestureDetector(
                        onTap: () => onWorkspaceTap(w.index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 160,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.desktop_windows_outlined,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Workspace',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                w.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
