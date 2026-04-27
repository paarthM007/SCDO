import 'package:flutter/material.dart';
import 'package:scdo_app/theme/glass_theme.dart';

class PathVisualizer extends StatelessWidget {
  final List<dynamic> pathEdges;
  final Color accentColor;

  const PathVisualizer({
    super.key,
    required this.pathEdges,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pathEdges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < pathEdges.length; i++) ...[
                _buildNode(pathEdges[i]["from"]),
                _buildEdge(pathEdges[i]["mode"], pathEdges[i]["dist_km"]),
                if (i == pathEdges.length - 1) _buildNode(pathEdges[i]["to"]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNode(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
          )
        ],
      ),
      child: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEdge(String mode, dynamic dist) {
    IconData icon;
    switch (mode) {
      case "AIR":
        icon = Icons.flight;
        break;
      case "SEA":
        icon = Icons.directions_boat;
        break;
      case "HIGHWAY":
        icon = Icons.local_shipping;
        break;
      default:
        icon = Icons.arrow_forward;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 1,
                color: accentColor.withOpacity(0.3),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 4),
              Container(
                width: 30,
                height: 1,
                color: accentColor.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "$dist km",
            style: TextStyle(
              fontSize: 9,
              color: GlassTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
