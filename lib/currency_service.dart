import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CurrencyService {
  final String apiKey = dotenv.env['CURRENCYLAYER_API_KEY'] ?? 'not working';

  Future<Map<String, double>> fetchExchangeRates(String baseCurrency) async {
    final url =
        'https://api.currencylayer.com/live?access_key=$apiKey&source=$baseCurrency';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rates = data['quotes'] as Map<String, dynamic>;
      return rates
          .map((key, value) => MapEntry(key.substring(3), value.toDouble()));
    } else {
      throw Exception('Failed to fetch exchange rates');
    }
  }
}
