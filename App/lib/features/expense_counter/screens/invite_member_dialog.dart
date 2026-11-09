import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_input.dart';
import '../providers/expense_providers.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  final String groupId;

  const InviteMemberDialog({super.key, required this.groupId});

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(expenseServiceProvider);
      final msg = await service.inviteMember(widget.groupId, email);
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupsProvider);

      if (mounted) {
        Navigator.of(context).pop(msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: theme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Invite to Group',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the email address of the person you want to invite. They will receive a pending request in their app and must accept before joining.',
              style: TextStyle(fontSize: 13, color: theme.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 18),
            Text(
              'Friend\'s Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            NeumorphicInput(
              controller: _emailController,
              hintText: 'e.g. friend@example.com',
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: theme.secondaryText)),
                ),
                const SizedBox(width: 8),
                NeumorphicButton(
                  isProminent: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  onTap: _isLoading ? null : _handleInvite,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Request',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

