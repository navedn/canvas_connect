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

class CurrencyService {
  final String apiKey = dotenv.env['CURRENCYLAYER_API_KEY'] ?? 'not working';

  Future<Map<String, double>> fetchExchangeRates(String baseCurrency) async {
    final url =
        'https://api.currencylayer.com/live?access_key=$apiKey&source=$baseCurrency';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if there's an error in the response
        if (data['error'] != null) {
          if (data['error']['code'] == 104) {
            // Handle rate limit exceeded error (code 104)
            throw Exception('Rate limit exceeded. Please try again later.');
          }
          throw Exception('Error: ${data['error']['info']}');
        }

        // Check if the 'quotes' field exists and is not null
        if (data['quotes'] != null) {
          final rates = data['quotes'] as Map<String, dynamic>;

          // Cache the fetched rates locally
          await Preferences.saveExchangeRates(rates);

          return rates.map(
              (key, value) => MapEntry(key.substring(3), value.toDouble()));
        } else {
          throw Exception('No quotes data available');
        }
      } else {
        throw Exception('Failed to fetch exchange rates');
      }
    } catch (e) {
      // Handle errors by checking for rate limit exceeded or other issues
      if (e.toString().contains('exceeded the maximum rate limitation') ||
          e.toString().contains('Rate limit exceeded')) {
        // Provide a fallback rate from local storage
        Map<String, double> fallbackRates =
            await Preferences.getFallbackExchangeRates();
        if (fallbackRates.isNotEmpty) {
          return fallbackRates;
        }
      }
      throw e;
    }
  }
}

class Preferences {
  // Save the exchange rates locally for fallback
  static Future<void> saveExchangeRates(Map<String, dynamic> rates) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('exchangeRates', jsonEncode(rates));
  }

  // Get the saved exchange rates
  static Future<Map<String, double>> getFallbackExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    String? ratesJson = prefs.getString('exchangeRates');
    if (ratesJson != null) {
      // Decode the JSON and ensure correct types
      final Map<String, dynamic> ratesMap =
          Map<String, dynamic>.from(jsonDecode(ratesJson));

      // Convert the values to double
      return ratesMap
          .map((key, value) => MapEntry(key, (value as num).toDouble()));
    }
    return {}; // Return empty if no fallback rates are available
  }

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

class CurrencyUtils {
  static Future<String> getConvertedPrice(
      String price, String baseCurrency) async {
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    String selectedCurrency = await Preferences.getCurrencyPreference();
    CurrencyService currencyService = CurrencyService();
    Map<String, double> rates;

    try {
      // Fetch exchange rates, with fallback to local storage if API limit is exceeded
      rates = await currencyService.fetchExchangeRates(baseCurrency);
    } catch (e) {
      // Handle the case where the API request fails or rate limit is exceeded
      if (e.toString().contains('Rate limit exceeded')) {
        // Fallback to default rates or cached data
        rates = await Preferences.getFallbackExchangeRates();
      } else {
        rethrow; // Propagate other errors
      }
    }

    double priceInBase = double.parse(price);
    double convertedPrice = priceInBase * (rates[selectedCurrency] ?? 1.0);
    String currencySymbol =
        currencySymbols[selectedCurrency] ?? selectedCurrency;

    return '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
  }
}
