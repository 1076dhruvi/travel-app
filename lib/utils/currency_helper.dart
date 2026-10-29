class CurrencyHelper {
  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'AED', 'name': 'UAE Dirham'},
  ];

  static String getSymbol(String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty) return '\$';
    final code = currencyCode.toUpperCase();
    for (final c in supportedCurrencies) {
      if (c['code'] == code) {
        return c['symbol']!;
      }
    }
    return code;
  }

  static String formatAmount(double amount, String? currencyCode) {
    final symbol = getSymbol(currencyCode);
    if (amount == amount.roundToDouble()) {
      return '$symbol${amount.toInt()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
