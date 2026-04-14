import 'package:flutter/material.dart';

class TrackingHeaderWidget extends StatelessWidget {
  final String trackedName;
  final String distance;

  const TrackingHeaderWidget({
    Key? key,
    required this.trackedName,
    required this.distance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              children: [
                const TextSpan(text: 'TRACKING: '),
                TextSpan(
                  text: trackedName.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF5AB9EA)),
                ),
                TextSpan(
                  text: ' ($distance)',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
