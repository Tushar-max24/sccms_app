import 'package:flutter/material.dart';

class LocationMarker extends StatelessWidget {
  final double left;
  final double top;
  final VoidCallback onTap;

  LocationMarker({required this.left, required this.top, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(Icons.location_on, size: 30, color: Colors.red),
      ),
    );
  }
}
