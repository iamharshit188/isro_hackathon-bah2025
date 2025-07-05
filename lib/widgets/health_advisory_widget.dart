import 'package:flutter/material.dart';

class HealthAdvisoryWidget extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color borderColor;

  const HealthAdvisoryWidget({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: borderColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
} 