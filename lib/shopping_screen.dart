import 'package:canvas_connect/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'messaging_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class ShoppingScreen extends StatefulWidget {
  final String username;

  ShoppingScreen({required this.username});

  @override
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;

  List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;

  int _selectedIndex = 2;

  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate based on selected index
    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MessagingScreen(username: widget.username),
        ),
      );
    } else if (index == 0) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ));
    } else if (index == 3) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SettingsScreen(),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchCart(); // Fetch the cart data when the screen is initialized
  }

  void _initializeUser() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final cartDoc = await FirebaseFirestore.instance
            .collection('carts')
            .doc(user.uid)
            .get();

        if (cartDoc.exists) {
          final data = cartDoc.data();
          print('Fetched cart data: $data'); // Debugging
          setState(() {
            _cart = List<Map<String, dynamic>>.from(data?['cart'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error fetching cart: $e'); // Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch cart: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCartInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('carts')
            .doc(user.uid)
            .set({'cart': _cart});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cart: $e')),
      );
    }
  }

  void _removeItem(int index) async {
    setState(() {
      _cart.removeAt(index);
    });

    await _updateCartInFirestore();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item removed and cart updated!')),
    );
  }

  Future<Map<int, String>> _getConvertedPricesForCart() async {
    // Define currency symbols and default rates
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    final Map<String, double> defaultRates = {
      'USD': 1.0, // Base currency
      'EUR': 0.85, // Example fallback
      'JPY': 151.41, // Example fallback for Yen
      'GBP': 0.74, // Example fallback for Pound
      'AUD': 1.5, // Example fallback for AUD
    };

    // Get the preferred currency
    String selectedCurrency = await Preferences.getCurrencyPreference();

    // Fetch exchange rates
    Map<String, double> rates;
    try {
      CurrencyService currencyService = CurrencyService();
      rates = await currencyService.fetchExchangeRates('USD');
    } catch (e) {
      rates = defaultRates; // Fallback if API fails
    }

    // Ensure the rate for the selected currency exists
    double exchangeRate =
        rates[selectedCurrency] ?? defaultRates[selectedCurrency] ?? 1.0;

    // Prepare the converted prices map for cart items
    Map<int, String> convertedPrices = {};
    String currencySymbol =
        currencySymbols[selectedCurrency] ?? selectedCurrency;

    for (int i = 0; i < _cart.length; i++) {
      final item = _cart[i];
      double priceInUSD = (item['price'] as num).toDouble();
      double convertedPrice = priceInUSD * exchangeRate;
      convertedPrices[i] =
          '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
    }

    return convertedPrices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.purple.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Welcome, ${'@${widget.username}' ?? 'Guest'}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                      userId: _currentUserId, profileUsername: widget.username),
                )); // Close the drawer
                // Add navigation logic here
              },
            ),
            // ListTile(
            //   leading: Icon(Icons.bookmark),
            //   title: Text('Bookmarks'),
            //   onTap: () {
            //     Navigator.of(context).pop(); // Close the drawer
            //     // Add navigation logic here
            //   },
            // ),
            // ListTile(
            //   leading: Icon(Icons.settings),
            //   title: Text('Settings'),
            //   onTap: () {
            //     Navigator.of(context).pop();
            //     // Add navigation logic here
            //   },
            // ),
            Divider(), // Optional divider
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<int, String>>(
        future: _getConvertedPricesForCart(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Failed to load cart prices'));
          }

          final convertedPrices = snapshot.data!;
          return _cart.isEmpty
              ? Center(child: Text('Your cart is empty.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return ListTile(
                            leading: Image.network(
                              item['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                            title: Text('Price: ${convertedPrices[index]}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _removeItem(index),
                            ),
                          );
                        },
                      ),
                    ),
                    // Checkout Button
                    ElevatedButton(
                      onPressed: () async {
                        if (_cart.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Your cart is empty!')),
                          );
                        } else {
                          final convertedPrices =
                              await _getConvertedPricesForCart();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                cart: _cart,
                                convertedPrices: convertedPrices,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text('Checkout'),
                    ),
                  ],
                );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.pink,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,

        currentIndex: _selectedIndex, // Set the currently selected index
        onTap: _onItemTapped, // Handle tab item selection
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_checkout),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final Map<int, String> convertedPrices;

  CheckoutScreen({required this.cart, required this.convertedPrices});

  Future<void> _completePurchase(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Save the purchase to the user's purchase history
        final purchasesRef = FirebaseFirestore.instance
            .collection('purchases')
            .doc(user.uid)
            .collection('history');

        await purchasesRef.add({
          'items': cart,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Clear the user's cart
        await FirebaseFirestore.instance
            .collection('carts')
            .doc(user.uid)
            .set({'cart': []});

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase completed!')),
        );

        // Navigate back to the shopping screen
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete purchase: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = convertedPrices.values.map((priceString) {
      // Remove currency symbols and convert to double
      final numericPrice =
          double.tryParse(priceString.replaceAll(RegExp(r'[^\d.]'), ''));
      return numericPrice ?? 0.0;
    }).fold(0.0, (sum, price) => sum + price);

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return ListTile(
                  leading: Image.network(
                    item['imageUrl'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text('Price: ${convertedPrices[index]}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total: ${convertedPrices.values.first.substring(0, 1)}${total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _completePurchase(context),
                  child: Text('Confirm Purchase'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
