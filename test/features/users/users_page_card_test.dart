import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildUserCard({
  required String name,
  required String username,
  required String role,
  required bool isOnline,
  required bool isActive,
  bool isCurrentAdmin = false,
}) {
  Widget buildStatusBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: online ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: online ? const Color(0xFF047857) : const Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with presence dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 20,
                child: Icon(Icons.person, size: 22),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004B93),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Role: ${role == 'admin' ? 'Admin' : 'User'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Username: $username',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right-aligned status and switch
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              buildStatusBadge(isOnline),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive ? 'Active' : 'Disabled',
                    style: TextStyle(
                      color: isActive ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(value: isActive, onChanged: (_) {}),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('Staff names Daniyal and Shifa are fully visible without being truncated by Offline badge on 360x640 mobile screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                buildUserCard(name: 'Mahir', username: 'MAHIR', role: 'admin', isOnline: false, isActive: true),
                buildUserCard(name: 'Shifa', username: 'SHHC', role: 'admin', isOnline: false, isActive: true),
                buildUserCard(name: 'Ayaz', username: 'AYAZ', role: 'staff', isOnline: false, isActive: true),
                buildUserCard(name: 'Daniyal', username: 'DANIYAL', role: 'staff', isOnline: false, isActive: true),
                buildUserCard(name: 'Shifa Home Care', username: 'CARE', role: 'staff', isOnline: false, isActive: true),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify all names are completely rendered and NOT truncated with ellipsis
    expect(find.text('Mahir'), findsOneWidget);
    expect(find.text('Shifa'), findsOneWidget);
    expect(find.text('Ayaz'), findsOneWidget);
    expect(find.text('Daniyal'), findsOneWidget);
    expect(find.text('Shifa Home Care'), findsOneWidget);

    // Verify offline tags are visible
    expect(find.text('Offline'), findsNWidgets(5));

    // Verify that the title text and offline tags do not overlap
    final daniyalRect = tester.getRect(find.text('Daniyal'));
    final offlineFinder = find.text('Offline');
    final offlineRect3 = tester.getRect(offlineFinder.at(3));

    expect(daniyalRect.overlaps(offlineRect3), isFalse, reason: 'Daniyal and Offline badge must not overlap');
    expect(daniyalRect.right, lessThanOrEqualTo(offlineRect3.left), reason: 'Daniyal name must stay to the left of the offline tag');
  });
}
