import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Cloud Firestore removed - using Supabase


import '../../../register/presentation/pages/register_page.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/presence_provider.dart';
import '../../../../core/errors/app_error.dart';

class RecentUserHighlightNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setHighlight(String? username) => state = username;
}

final recentUserHighlightProvider = NotifierProvider<RecentUserHighlightNotifier, String?>(
  RecentUserHighlightNotifier.new,
);

final allUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .where((user) {
            final isDeleted = user['is_deleted'] == true || user['isDeleted'] == true;
            final isInternalAccount = user['is_internal_account'] == true || user['isInternalAccount'] == true;
            final isHidden = user['is_hidden'] == true || user['isHidden'] == true;
            if (isDeleted || isInternalAccount || isHidden) return false;
            return true;
          })
          .map((user) => {
            ...user,
            'uid': (user['id'] ?? '').toString(),
            'isDeleted': user['is_deleted'] ?? false,
            'isInternalAccount': user['is_internal_account'] ?? false,
            'isHidden': user['is_hidden'] ?? false,
          })
          .toList());
});

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(allUsersProvider);
    final presenceState = ref.watch(onlinePresenceProvider);
    final highlightUsername = ref.watch(recentUserHighlightProvider);
    final currentUser = ref.watch(authStateProvider).value;
    final currentProfile = ref.watch(userProfileProvider).value;
    final currentUserId = currentUser?.id ?? currentProfile?['uid'] ?? currentProfile?['id'];
    final currentUserEmail = currentUser?.email ?? currentProfile?['email'];
    final currentUsername = currentProfile?['username']?.toString().toUpperCase();

    if (highlightUsername != null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (ref.read(recentUserHighlightProvider) == highlightUsername) {
          ref.read(recentUserHighlightProvider.notifier).setHighlight(null);
        }
      });
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 480;

                final newUserButton = ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage(standalone: true)),
                    );
                  },
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: isCompact ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                );

                final badges = staffAsync.maybeWhen(
                  data: (staffList) {
                    final onlineCount = staffList.where((s) {
                      final sId = (s['id'] ?? s['uid'] ?? '').toString();
                      final sEmail = (s['email'] ?? '').toString();
                      final uName = (s['username'] ?? '').toString();
                      return presenceState.isOnline(userId: sId, username: uName, email: sEmail);
                    }).length;
                    final offlineCount = staffList.length - onlineCount;
                    return Wrap(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4.5),
                              Text(
                                '$onlineCount Online',
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4.5),
                              Text(
                                '$offlineCount Offline',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
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
                          Text(
                            'Staff Management',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
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
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: staffAsync.when(
                data: (staffList) {
                  if (staffList.isEmpty) return const Center(child: Text('No staff accounts yet.'));

                  // Sort: currently logged-in admin first, then active users, then deactivated
                  final sorted = [...staffList];
                  sorted.sort((a, b) {
                    final aId = (a['id'] ?? a['uid'] ?? '').toString();
                    final bId = (b['id'] ?? b['uid'] ?? '').toString();
                    final aEmail = (a['email'] ?? '').toString().toLowerCase();
                    final bEmail = (b['email'] ?? '').toString().toLowerCase();
                    final aUName = (a['username'] ?? '').toString().toUpperCase();
                    final bUName = (b['username'] ?? '').toString().toUpperCase();

                    final aIsCurrent = (currentUserId != null && aId.isNotEmpty && aId == currentUserId) ||
                        (currentUserEmail != null && aEmail.isNotEmpty && aEmail == currentUserEmail.toString().toLowerCase()) ||
                        (currentUsername != null && aUName.isNotEmpty && aUName == currentUsername);

                    final bIsCurrent = (currentUserId != null && bId.isNotEmpty && bId == currentUserId) ||
                        (currentUserEmail != null && bEmail.isNotEmpty && bEmail == currentUserEmail.toString().toLowerCase()) ||
                        (currentUsername != null && bUName.isNotEmpty && bUName == currentUsername);

                    if (aIsCurrent && !bIsCurrent) return -1;
                    if (!aIsCurrent && bIsCurrent) return 1;

                    final aStatus = (a['status'] ?? 'active').toString().toLowerCase();
                    final bStatus = (b['status'] ?? 'active').toString().toLowerCase();
                    final aActive = aStatus == 'active';
                    final bActive = bStatus == 'active';
                    if (aActive && !bActive) return -1;
                    if (!aActive && bActive) return 1;

                    final aOnline = presenceState.isOnline(userId: aId, username: aUName, email: aEmail);
                    final bOnline = presenceState.isOnline(userId: bId, username: bUName, email: bEmail);
                    if (aActive && bActive) {
                      if (aOnline && !bOnline) return -1;
                      if (!aOnline && bOnline) return 1;
                    }
                    return 0;
                  });

                  return ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final s = sorted[index];
                      final sId = (s['id'] ?? s['uid'] ?? '').toString();
                      final sEmail = (s['email'] ?? '').toString().toLowerCase();
                      final uName = (s['username'] ?? '').toString().toUpperCase();

                      final isCurrentAdmin = (currentUserId != null && sId.isNotEmpty && sId == currentUserId) ||
                          (currentUserEmail != null && sEmail.isNotEmpty && sEmail == currentUserEmail.toString().toLowerCase()) ||
                          (currentUsername != null && uName.isNotEmpty && uName == currentUsername);

                      final status = (s['status'] ?? 'active').toString().toLowerCase();
                      final isActive = status == 'active';
                      final isDeactivated = status == 'deactivated' || status == 'disabled' || status == 'inactive';
                      final isHighlighted = (highlightUsername != null && uName == highlightUsername);
                      final isUserOnline = presenceState.isOnline(
                        userId: sId,
                        username: uName,
                        email: sEmail,
                      );

                      return Opacity(
                        opacity: isDeactivated ? 0.6 : 1.0,
                        child: Card(
                          color: isCurrentAdmin
                              ? const Color(0xFFE2E8F0) // Dark shade for currently logged-in admin card
                              : isHighlighted
                                  ? const Color(0xFFFEF3C7) // Soft amber for newly created
                                  : isDeactivated
                                      ? const Color(0xFFFFF8F0)
                                      : Colors.white,
                          elevation: isCurrentAdmin ? 3 : (isHighlighted ? 3 : 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isCurrentAdmin
                                  ? const Color(0xFF004B93) // Shifa dark navy border
                                  : isHighlighted
                                      ? const Color(0xFFD97706)
                                      : isDeactivated
                                          ? Colors.orange.shade200
                                          : Colors.grey.shade200,
                              width: isCurrentAdmin ? 2.0 : (isHighlighted ? 1.5 : 1),
                            ),
                          ),
                          child: Column(
                            children: [
                              if (isCurrentAdmin)
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF004B93),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10.0),
                                      topRight: Radius.circular(10.0),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shield, color: Colors.white, size: 14),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'LOGGED IN ADMIN ACCOUNT (YOU)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33FFFFFF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ACTIVE SESSION',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isHighlighted && !isCurrentAdmin)
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD97706),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10.5),
                                      topRight: Radius.circular(10.5),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.new_releases, color: Colors.white, size: 13),
                                      SizedBox(width: 6),
                                      Text(
                                        'NEWLY CREATED USER',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isDeactivated && !isHighlighted && !isCurrentAdmin)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade700,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10.5),
                                      topRight: Radius.circular(10.5),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.block, color: Colors.white, size: 13),
                                      SizedBox(width: 6),
                                      Text(
                                        'DEACTIVATED ACCOUNT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showUserDetails(context, s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isCurrentAdmin
                                                ? const Color(0xFF004B93)
                                                : (isActive ? const Color(0xFFE0F2FE) : Colors.orange.shade100),
                                            child: Icon(
                                              isCurrentAdmin
                                                  ? Icons.admin_panel_settings
                                                  : (isActive ? Icons.person : Icons.person_off),
                                              color: isCurrentAdmin
                                                  ? Colors.white
                                                  : (isActive ? const Color(0xFF004B93) : Colors.orange.shade700),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: isUserOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: isUserOnline
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                                          blurRadius: 3,
                                                          spreadRadius: 1,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s['name'] ?? 'Unknown',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15.5,
                                                      color: isDeactivated ? Colors.grey.shade600 : const Color(0xFF1E293B),
                                                      decoration: isDeactivated ? TextDecoration.lineThrough : null,
                                                    ),
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
                                                    child: const Text(
                                                      'YOU',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Role: ${s['role'] == 'admin' ? 'Admin' : 'User'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              'Username: ${s['username']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildStatusBadge(isUserOnline),
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
                                              if (isCurrentAdmin)
                                                const Tooltip(
                                                  message: 'Active admin session',
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                    child: Icon(Icons.verified_user, size: 20, color: Color(0xFF004B93)),
                                                  ),
                                                )
                                              else
                                                _DeactivationSwitch(
                                                  isActive: isActive,
                                                  userUid: s['uid'],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _UserDetailsModal(user: user);
      },
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? const Color(0xFF047857) : const Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDetailsModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;

  const _UserDetailsModal({required this.user});

  @override
  ConsumerState<_UserDetailsModal> createState() => _UserDetailsModalState();
}

class _UserDetailsModalState extends ConsumerState<_UserDetailsModal> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  late String _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _selectedRole = widget.user['role'] ?? 'staff';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    final newPass = _passwordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isNotEmpty) {
      if (newPass.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters long.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (newPass != confirmPass) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match. Please verify.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final phoneText = _phoneController.text.trim();
    if (phoneText.isNotEmpty && !RegExp(r'^\d{1,15}$').hasMatch(phoneText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must contain digits only.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = newPass.isNotEmpty ? 'Updating user password...' : 'Updating user details...';
    });

    try {
      final targetUid = widget.user['uid'] as String;

      // 1. If password is provided, update via admin auth helper
      if (newPass.isNotEmpty) {
        final authController = ref.read(authControllerProvider);
        await authController.adminUpdateUserPassword(
          targetUid: targetUid,
          newPassword: newPass,
        );
      }

      // 2. Update user profile fields (name, phone, role)
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ref.read(supabaseClientProvider).from('users').update(updateData).eq('id', targetUid);

      if (mounted) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _obscurePassword = true;
          _obscureConfirmPassword = true;
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPass.isNotEmpty
                  ? '✓ Password and user details updated successfully.'
                  : '✓ User details updated successfully.',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = AppError.map(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete ${widget.user['name']}? This user will be deactivated and removed from active staff lists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isSaving = true;
        _statusMessage = 'Deleting user account...';
      });
      try {
        final authController = ref.read(authControllerProvider);
        await authController.deleteUserAccount(targetUid: widget.user['uid']);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ User deleted successfully'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        final errorMsg = AppError.map(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawCreated = widget.user['created_at'] ?? widget.user['createdAt'];
    String dateStr = 'N/A';
    if (rawCreated is String) {
      final dt = DateTime.tryParse(rawCreated);
      if (dt != null) dateStr = dt.toLocal().toString().split('.')[0];
    } else if (rawCreated != null) {
      dateStr = rawCreated.toString();
    }
    final username = (widget.user['username'] ?? 'N/A').toString();
    final email = (widget.user['email'] ?? '').toString().isNotEmpty
        ? widget.user['email'].toString()
        : '${username.toLowerCase()}@internal.shifa.app';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'User Details & Security',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final modalPresence = ref.watch(onlinePresenceProvider);
                final isModalUserOnline = modalPresence.isOnline(
                  userId: widget.user['uid'] ?? widget.user['id'],
                  username: username,
                  email: email,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isModalUserOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isModalUserOnline ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isModalUserOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isModalUserOnline ? 'Online Now (Active in App)' : 'Offline (App Closed)',
                        style: TextStyle(
                          color: isModalUserOnline ? const Color(0xFF047857) : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Text(
              'Username: $username',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Auth Email: $email',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text('Created: $dateStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: (['staff', 'admin'].contains(_selectedRole)) ? _selectedRole : 'staff',
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: _isSaving ? null : (value) {
                if (value != null) setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 20),

            // ─── Manual Password Update Section ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF004B93)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CHANGE PASSWORD (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004B93),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Leave blank to keep the current password.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Minimum 6 characters',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isSaving) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // blue-50
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF004B93)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ─── Modal Actions (Overflow Safe) ───
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton.icon(
                  onPressed: _isSaving ? null : _deleteUser,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete User', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateUser,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Updating...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004B93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Toggle switch with confirmation dialog for deactivating/reactivating users.
class _DeactivationSwitch extends ConsumerStatefulWidget {
  final bool isActive;
  final String userUid;

  const _DeactivationSwitch({required this.isActive, required this.userUid});

  @override
  ConsumerState<_DeactivationSwitch> createState() => _DeactivationSwitchState();
}

class _DeactivationSwitchState extends ConsumerState<_DeactivationSwitch> {
  bool _isProcessing = false;

  Future<void> _handleToggle(bool newValue) async {
    final action = newValue ? 'reactivate' : 'deactivate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Account?'),
        content: Text(
          newValue
              ? 'This will restore the account. The user will be able to log in again.'
              : 'This will deactivate the account and log the user out from ALL devices immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? Colors.green : Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(newValue ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final authController = ref.read(authControllerProvider);
      if (newValue) {
        await authController.reactivateUser(targetUid: widget.userUid);
      } else {
        await authController.deactivateUser(targetUid: widget.userUid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? '✓ Account reactivated successfully'
                : '✓ Account deactivated — user logged out from all devices'),
            backgroundColor: newValue ? Colors.green : Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = AppError.map(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const SizedBox(
        width: 48,
        height: 24,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Switch(
      value: widget.isActive,
      activeThumbColor: Colors.green,
      activeTrackColor: Colors.green.shade200,
      inactiveThumbColor: Colors.orange.shade700,
      inactiveTrackColor: Colors.orange.shade100,
      onChanged: _handleToggle,
    );
  }
}
