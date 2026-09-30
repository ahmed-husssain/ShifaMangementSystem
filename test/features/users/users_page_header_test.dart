import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildTestHeader(BoxConstraints constraints) {
  final isCompact = constraints.maxWidth < 480;

  final newUserButton = ElevatedButton.icon(
    onPressed: () {},
    icon: Icon(Icons.person_add, size: isCompact ? 16 : 18),
    label: Text(
      'New User',
      style: TextStyle(
        fontSize: isCompact ? 13 : 14,
        fontWeight: FontWeight.bold,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF004B93),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 1,
    ),
  );

  final badges = Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Text('0 Online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Text('4 Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    ],
  );

  if (isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'Staff Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            newUserButton,
          ],
        ),
        const SizedBox(height: 6),
        badges,
      ],
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            badges,
          ],
        ),
      ),
      const SizedBox(width: 16),
      newUserButton,
    ],
  );
}

void main() {
  final screenSizes = <String, Size>{
    'Smallest Mobile (320x568)': const Size(320, 568),
    'Standard Android (360x640)': const Size(360, 640),
    'iPhone SE / mini (375x667)': const Size(375, 667),
    'iPhone Standard (390x844)': const Size(390, 844),
    'Large Mobile (412x915)': const Size(412, 915),
    'Tablet (768x1024)': const Size(768, 1024),
  };

  for (final entry in screenSizes.entries) {
    testWidgets('Header renders without overlap or overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) => buildTestHeader(constraints),
              ),
            ),
          ),
        ),
      );

      final titleFinder = find.text('Staff Management');
      final buttonFinder = find.byType(ElevatedButton);

      expect(titleFinder, findsOneWidget);
      expect(buttonFinder, findsOneWidget);

      final titleRect = tester.getRect(titleFinder);
      final buttonRect = tester.getRect(buttonFinder);

      expect(titleRect.overlaps(buttonRect), isFalse,
          reason: 'Title and New User button MUST NEVER overlap on ${entry.key}');
      expect(buttonRect.right, lessThanOrEqualTo(entry.value.width),
          reason: 'Button must fit within the screen bounds on ${entry.key}');
    });
  }
}
