import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD'];
  String selectedCurrency = 'USD'; // Default currency

  @override
  void initState() {
    super.initState();
    // Load the saved currency preference on screen load
    _loadCurrencyPreference();
  }

  // Load the saved currency preference
  _loadCurrencyPreference() async {
    String savedCurrency = await Preferences.getCurrencyPreference();
    setState(() {
      selectedCurrency = savedCurrency;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferred Currency', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            DropdownButton<String>(
              value: selectedCurrency,
              items: currencies.map((currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCurrency = value!;
                });

                // Save the selected currency preference locally
                Preferences.saveCurrencyPreference(value!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class Preferences {
  // Save the currency preference locally
  static Future<void> saveCurrencyPreference(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('preferredCurrency', currency);
  }

  // Get the saved currency preference
  static Future<String> getCurrencyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferredCurrency') ??
        'USD'; // Default to USD if not set
  }
}

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
