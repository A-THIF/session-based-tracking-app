import 'package:flutter/material.dart';

import '../widgets/distance_card.dart';
import '../widgets/map_marker.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Session')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(child: MapMarker()),
            SizedBox(height: 20),
            DistanceCard(
              title: 'Distance',
              value: '1.24 km',
            ),
            SizedBox(height: 12),
            DistanceCard(
              title: 'Heading',
              value: 'NE 42°',
            ),
          ],
        ),
      ),
    );
  }
}
