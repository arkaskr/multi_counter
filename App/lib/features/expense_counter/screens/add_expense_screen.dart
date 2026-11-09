import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_input.dart';
import '../models/group_model.dart';
import '../providers/expense_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  // Selected members to split with (by default, all accepted members)
  late Set<String> _includedMemberEmails;

  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant_rounded},
    {'name': 'Travel', 'icon': Icons.directions_car_rounded},
    {'name': 'Groceries', 'icon': Icons.local_grocery_store_rounded},
    {'name': 'Rent', 'icon': Icons.home_rounded},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_rounded},
    {'name': 'Entertainment', 'icon': Icons.movie_filter_rounded},
    {'name': 'Bills', 'icon': Icons.receipt_long_rounded},
    {'name': 'Other', 'icon': Icons.category_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _includedMemberEmails = widget.group.acceptedMembers.map((m) => m.email).toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = context.appTheme;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              surface: theme.surface,
              onSurface: theme.text,
            ),
            dialogBackgroundColor: theme.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a title for the expense');
      return;
    }

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid positive amount');
      return;
    }

    if (_includedMemberEmails.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one member to split with');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(expenseServiceProvider);

      // Build custom splits if not splitting with all accepted members
      List<Map<String, dynamic>>? customSplits;
      final allAccepted = widget.group.acceptedMembers;
      final selectedMembers = allAccepted.where((m) => _includedMemberEmails.contains(m.email)).toList();

      if (selectedMembers.length != allAccepted.length) {
        final splitCount = selectedMembers.length;
        final baseShare = (amount / splitCount);
        customSplits = selectedMembers.map((m) {
          return {
            'user': m.userId,
            'email': m.email,
            'name': m.name,
            'shareAmount': double.parse(baseShare.toStringAsFixed(2)),
          };
        }).toList();
      }

      await service.addExpense(
        groupId: widget.group.id,
        title: title,
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        note: _noteController.text.trim(),
        customSplits: customSplits,
      );

      ref.invalidate(groupDetailProvider(widget.group.id));
      ref.invalidate(groupsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
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
    final authState = ref.watch(authStateProvider);
    final currentUserName = authState.user?.name ?? 'You';

    final amountVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final splitCount = _includedMemberEmails.isNotEmpty ? _includedMemberEmails.length : 1;
    final perPersonShare = amountVal > 0 ? (amountVal / splitCount) : 0.0;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Expense',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payer Banner: "Paid by You"
              NeumorphicContainer(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.payment_rounded, color: theme.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paid by $currentUserName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                            ),
                          ),
                          Text(
                            'Enter what you spent for the group',
                            style: TextStyle(fontSize: 12, color: theme.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Amount Input
              Text(
                'AMOUNT PAID',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              NeumorphicInput(
                controller: _amountController,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixText: '₹ ',
                onChanged: (_) => setState(() {}),
                autofocus: true,
              ),
              const SizedBox(height: 20),

              // Title / Description
              Text(
                'WHAT WAS THIS FOR?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              NeumorphicInput(
                controller: _titleController,
                hintText: 'e.g. Dinner, Uber ride, Airbnb, Snacks',
              ),
              const SizedBox(height: 20),

              // Category Selector
              Text(
                'CATEGORY / TAG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final name = cat['name'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSelected = _selectedCategory == name;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.accent : theme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? theme.accent : theme.surface,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected ? Colors.white : theme.text,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : theme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Date Selector
              Text(
                'DATE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: NeumorphicContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: theme.accent, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        AppDateUtils.formatDisplayDate(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      const Spacer(),
                      Text('Change', style: TextStyle(color: theme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Split Between Members
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPLIT BETWEEN (${_includedMemberEmails.length}/${widget.group.acceptedMembers.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: theme.secondaryText,
                    ),
                  ),
                  if (perPersonShare > 0)
                    Text(
                      '₹${perPersonShare.toStringAsFixed(1)} / person',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              NeumorphicContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: widget.group.acceptedMembers.map((member) {
                    final isChecked = _includedMemberEmails.contains(member.email);

                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      activeColor: theme.accent,
                      dense: true,
                      title: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      subtitle: Text(
                        member.email,
                        style: TextStyle(fontSize: 11, color: theme.secondaryText),
                      ),
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _includedMemberEmails.add(member.email);
                          } else {
                            if (_includedMemberEmails.length > 1) {
                              _includedMemberEmails.remove(member.email);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Note / Details (Optional)
              Text(
                'NOTE (OPTIONAL)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              NeumorphicInput(
                controller: _noteController,
                hintText: 'Additional details or notes',
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: NeumorphicButton(
                  isProminent: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onTap: _isLoading ? null : _handleSubmit,
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Save Expense',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

