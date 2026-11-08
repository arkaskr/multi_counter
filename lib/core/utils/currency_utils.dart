import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final NumberFormat _integerFormat = NumberFormat('#,##0');
  static final NumberFormat _decimalFormat = NumberFormat('#,##0.00');

  /// Formats an amount with the currency symbol.
  /// Example: formatCurrency(45.0, '₹') -> "₹45"
  /// Example: formatCurrency(45.5, '₹') -> "₹45.50"
  static String formatCurrency(double amount, [String symbol = '₹']) {
    final isWhole = (amount % 1) == 0;
    final formattedNumber = isWhole
        ? _integerFormat.format(amount.toInt())
        : _decimalFormat.format(amount);
    return '$symbol$formattedNumber';
  }

  /// Formats amount number without currency symbol.
  static String formatNumber(double amount) {
    final isWhole = (amount % 1) == 0;
    return isWhole
        ? _integerFormat.format(amount.toInt())
        : _decimalFormat.format(amount);
  }
}
