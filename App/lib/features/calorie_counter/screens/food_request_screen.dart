import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';

/// Screen 13: Request a Missing Food (remains pending until verified & approved).
class FoodRequestScreen extends ConsumerStatefulWidget {
  final String initialFoodName;

  const FoodRequestScreen({super.key, this.initialFoodName = ''});

  @override
  ConsumerState<FoodRequestScreen> createState() => _FoodRequestScreenState();
}

class _FoodRequestScreenState extends ConsumerState<FoodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _prepCtrl = TextEditingController();
  final _servingCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _categoryHint = 'indian_meals';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialFoodName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _prepCtrl.dispose();
    _servingCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final userId = ref.read(nutritionUserIdProvider);
      await ref.read(foodCatalogueServiceProvider).submitFoodRequest(
            userId: userId,
            foodName: _nameCtrl.text,
            categoryHint: _categoryHint,
            brandOrPreparation: _prepCtrl.text,
            servingDescription: _servingCtrl.text,
            referenceUrlOrNote: _refCtrl.text,
          );
      ref.invalidate(foodRequestsProvider);
      _nameCtrl.clear();
      _prepCtrl.clear();
      _servingCtrl.clear();
      _refCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Food request submitted with Pending status. It cannot be logged until verified.'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final requestsAsync = ref.watch(foodRequestsProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Request a Food',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NeumorphicContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: NutritionAccentPalette.warmOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To ensure nutritional accuracy, custom unverified foods cannot be logged. Submitted foods stay Pending until verified against ICMR-NIN / USDA data.',
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: theme.text),
                      decoration: const InputDecoration(
                        labelText: 'Food Name *',
                        hintText: 'e.g. Methi Thepla, Ragi Dosa',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryHint,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.text),
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(
                            value: 'indian_meals', child: Text('Indian Meals')),
                        DropdownMenuItem(value: 'fruits', child: Text('Fruits')),
                        DropdownMenuItem(
                            value: 'vegetables', child: Text('Vegetables')),
                        DropdownMenuItem(value: 'dairy', child: Text('Dairy')),
                        DropdownMenuItem(
                            value: 'nuts_seeds', child: Text('Nuts & Seeds')),
                        DropdownMenuItem(value: 'protein', child: Text('Protein')),
                        DropdownMenuItem(
                            value: 'beverages', child: Text('Beverages')),
                        DropdownMenuItem(
                            value: 'international', child: Text('International')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _categoryHint = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prepCtrl,
                      style: TextStyle(color: theme.text),
                      decoration: const InputDecoration(
                        labelText: 'Preparation Method / Brand (optional)',
                        hintText: 'e.g. Homemade roasted on tawa',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _servingCtrl,
                      style: TextStyle(color: theme.text),
                      decoration: const InputDecoration(
                        labelText: 'Typical Serving Size (optional)',
                        hintText: 'e.g. 1 medium piece (~40g)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _refCtrl,
                      style: TextStyle(color: theme.text),
                      decoration: const InputDecoration(
                        labelText: 'Source / Packaging Reference (optional)',
                      ),
                    ),
                    const SizedBox(height: 18),
                    NeumorphicButton(
                      isEnabled: !_submitting,
                      color: NutritionAccentPalette.warmOrange,
                      onTap: _submit,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          _submitting
                              ? 'Submitting...'
                              : 'Submit Request for Verification',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Food Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 10),
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return NeumorphicContainer(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No food requests submitted yet.',
                      style: TextStyle(color: theme.secondaryText),
                    ),
                  );
                }
                return Column(
                  children: requests.map((r) {
                    final statusColor = r.status == 'approved'
                        ? NutritionAccentPalette.softGreen
                        : (r.status == 'rejected'
                            ? NutritionAccentPalette.fatCoral
                            : NutritionAccentPalette.carbsAmber);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NeumorphicContainer(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.foodName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.text,
                                    ),
                                  ),
                                  if (r.servingDescription.isNotEmpty)
                                    Text(
                                      r.servingDescription,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                r.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}

