import 'package:canvas_connect/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'messaging_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'profile_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'shopping_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _newPasswordController = TextEditingController();
  String _apiKey = dotenv.env['PIXABAY_API_KEY'] ?? 'not working';
  // Replace with your Pixabay API key
  List<dynamic> _images = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _cart = []; // Shopping cart items

  List<dynamic> _portfolioImages = [];

  int _selectedIndex = 0; // Track the selected index for BottomNavigationBar

  final List<Widget> _pages = [];

  late String _username = '';

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _fetchImages(); // Fetch images when the screen loads
    _fetchPortfolioImages();
    _loadCartFromFirestore();
  }

  @override
  void dispose() {
    saveCartToFirestore({'cart': _cart}); // Save cart when screen is disposed
    _newPasswordController.dispose();
    super.dispose();
  }

// Add to cart method
  void _addToCart(Map<String, dynamic> item) async {
    setState(() {
      _cart.add(item);
    });

    try {
      await saveCartToFirestore({'cart': _cart});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to cart and saved to Firestore!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save cart to Firestore: $e')),
      );
    }
  }

  // Load cart from Firestore
  Future<void> _loadCartFromFirestore() async {
    try {
      final fetchedCart = await fetchCartFromFirestore();
      setState(() {
        _cart = (fetchedCart['cart'] as List<dynamic>?)
                ?.map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [];
      });
    } catch (e) {
      if (mounted) {
        // Check if the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cart: $e')),
        );
      }
    }
  }

// Fetch images from Pixabay API
  Future<void> _fetchImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://pixabay.com/api/?key=$_apiKey&q=art&image_type=photo&per_page=20'),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _images = data['hits'];
        });
      } else {
        _showError('Failed to fetch images. Try again later.');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPortfolioImages() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final imagesSnapshot = await _firestore.collection('portfolio').get();
      if (mounted) {
        setState(() {
          _portfolioImages = imagesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          // Shuffle the images list to randomize order
          _portfolioImages.shuffle();
        });
      }
    } catch (e) {
      print('Error fetching portfolio images: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Function to change password directly
  Future<void> _changePassword(BuildContext context) async {
    final user = _auth.currentUser;
    if (user != null && _newPasswordController.text.isNotEmpty) {
      try {
        await user.updatePassword(_newPasswordController.text);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password changed successfully.'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a new password.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Future<void> _changePasswordWithEmail(BuildContext context) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _auth.sendPasswordResetEmail(email: user.email!);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password reset email sent to ${user.email}'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
        ));
      }
    }
  }

  // Sign out function
  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // Fetch the current user's username
  Future<void> _fetchUsername() async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          _username = userDoc.data()?['username'] ?? 'Unknown';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching username: $e')),
        );
      }
    }
  }

  Future<void> saveCartToFirestore(Map<String, dynamic> cart) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('carts').doc(user.uid).set(cart);
  }

  // Fetch cart from Firestore
  Future<Map<String, dynamic>> fetchCartFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _firestore.collection('carts').doc(user.uid).get();
    if (snapshot.exists) {
      return snapshot.data() as Map<String, dynamic>;
    }
    return {};
  }

  // Function to handle Bottom Navigation Bar item selection
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate based on selected index
    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MessagingScreen(username: _username),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(
            builder: (context) => ShoppingScreen(username: _username),
          ))
          .then((_) => _loadCartFromFirestore()); // Refresh cart on return
    } else if (index == 3) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (context) => SettingsScreen(),
          ))
          .then((_) => _loadCartFromFirestore()); // Refresh cart on return
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text('Home: Discover Art'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(), // Open Drawer
          ),
        ),
        // actions: [
        //   IconButton(onPressed: () => {}, icon: Icon(Icons.search)),
        //   IconButton(onPressed: () => {}, icon: Icon(Icons.more_vert)),
        // ],
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
                    'Welcome, ${'@$_username' ?? 'Guest'}',
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
                      userId: user?.uid, profileUsername: _username),
                ));
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
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (context) => SettingsScreen(),
                    ))
                    .then((_) => _loadCartFromFirestore());
              },
            ),
            Divider(), // Optional divider
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPortfolioImages,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _portfolioImages.isEmpty
                ? Center(child: Text('No portfolio images found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: _portfolioImages.length,
                    itemBuilder: (context, index) {
                      final image = _portfolioImages[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => DetailScreen(
                              currentUserID: user!.uid,
                              imageUrl: image['imageUrl'],
                              title: image['title'],
                              description: image['description'],
                              userId: image['userId'],
                              price: image['price'].toString(),
                              onAddToCart: () => _addToCart(image),
                            ),
                          ));
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image[
                                  'imageUrl'], // Ensure 'imageUrl' key exists in Firestore
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // backgroundColor: const Color.fromARGB(255, 102, 81, 81),
        // selectedItemColor: Colors.blue,
        // unselectedItemColor: Colors.black,

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
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final String imageUrl;
  final String userId;
  final String title;
  final String description;
  final String price;
  final String currentUserID;
  final VoidCallback onAddToCart;

  DetailScreen({
    required this.currentUserID,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.userId,
    required this.price,
    required this.onAddToCart,
  });

  // Method to fetch the account's username
  Future<String> _fetchAccountUsername() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      return userDoc.data()?['username'] ?? 'Unknown';
    } catch (e) {
      return 'Error fetching username';
    }
  }

  // Method to get the converted price in the selected currency
  Future<String> _getConvertedPrice(String price) async {
    final Map<String, String> currencySymbols = {
      'USD': '\$', // Dollar
      'EUR': '€', // Euro
      'JPY': '¥', // Yen
      'GBP': '£', // Pound
      'AUD': 'A\$', // Australian Dollar
    };

    final Map<String, double> defaultRates = {
      'USD': 1.0, // Base currency
      'EUR': 0.85,
      'JPY': 151.41,
      'GBP': 0.74,
      'AUD': 1.5,
    };

    String selectedCurrency = await Preferences.getCurrencyPreference();

    // Fetch exchange rates, fallback to defaultRates on failure
    Map<String, double> rates;
    try {
      CurrencyService currencyService = CurrencyService();
      rates = await currencyService.fetchExchangeRates('USD');
    } catch (e) {
      print('Failed to fetch exchange rates: $e');
      rates = defaultRates;
    }

    // Ensure a rate exists for the selected currency
    double priceInUSD = double.parse(price);
    double rate =
        rates[selectedCurrency] ?? defaultRates[selectedCurrency] ?? 1.0;

    if (rate == 1.0 && !defaultRates.containsKey(selectedCurrency)) {
      print('Warning: Fallback rate applied for currency $selectedCurrency.');
    }

    double convertedPrice = priceInUSD * rate;
    String currencySymbol =
        currencySymbols[selectedCurrency] ?? selectedCurrency;

    return '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Image Details',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          FutureBuilder<String>(
            future: _fetchAccountUsername(), // Fetch the username
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return IconButton(
                  onPressed: null,
                  icon: Icon(Icons.person),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to fetch user profile')),
                  ),
                  icon: Icon(Icons.person),
                );
              }

              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: currentUserID,
                      profileUsername: snapshot.data!,
                    ),
                  ));
                },
                icon: Icon(Icons.person),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10, // Ensures consistent sizing for the image
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                FutureBuilder<String>(
                  future: _fetchAccountUsername(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        "Loading artist...",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      );
                    }
                    return Text(
                      "Uploaded by: ${snapshot.data}",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    );
                  },
                ),
                SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _getConvertedPrice(price),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        "Fetching price...",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      );
                    }
                    return Text(
                      "Price: ${snapshot.data}",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.purple.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: onAddToCart,
          child: Icon(
            Icons.add_shopping_cart,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}
