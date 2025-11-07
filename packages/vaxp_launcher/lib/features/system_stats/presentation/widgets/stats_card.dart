import 'package:flutter/material.dart';
import 'glass_card.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  final Widget? child; // New parameter for dynamic content

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    this.child, // Initialize the new parameter
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      fontSize: 16,
                    ),
                  ),
                ),
                // Consumption info to the right of the title
                if (child != null)
                  DefaultTextStyle(
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    child: child!,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(unit, style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 255, 255, 255))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}