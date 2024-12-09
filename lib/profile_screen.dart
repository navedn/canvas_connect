import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/intl.dart';

import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final String profileUsername;

  ProfileScreen({this.userId, required this.profileUsername});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late String _currentUserId;
  late String _aboutMe = "Loading...";
  String? _profileUID;
  bool _isLoading = true;
  List<Map<String, dynamic>> _portfolioImages = [];

  List<Map<String, dynamic>> _purchaseHistory = [];

  List<Map<String, dynamic>> _cart = []; // Shopping cart items

  Map<int, String> _convertedPrices = {}; // To store converted prices

  Map<int, String> _convertedPurchasePrices = {};

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchProfileUID();
    // _fetchPortfolioImages(); // This is already handled by _fetchProfileUID
  }

  void _initializeUser() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<Map<int, String>> _getConvertedPricesPortfolio() async {
    // Define currency symbols
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    // Get the preferred currency
    String selectedCurrency = await Preferences.getCurrencyPreference();

    // Fetch exchange rates
    CurrencyService currencyService = CurrencyService();
    Map<String, double> rates = await currencyService.fetchExchangeRates('USD');

    // Prepare the converted prices map for portfolio items
    Map<int, String> convertedPrices = {};

    for (int i = 0; i < _portfolioImages.length; i++) {
      final item = _portfolioImages[i];
      double priceInUSD = item['price'].toDouble();
      double convertedPrice = priceInUSD * (rates[selectedCurrency] ?? 1.0);
      String currencySymbol =
          currencySymbols[selectedCurrency] ?? selectedCurrency;

      convertedPrices[i] =
          '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
    }

    return convertedPrices;
  }

  Future<Map<int, String>> _getConvertedPricesPurchaseHistory() async {
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    String selectedCurrency = await Preferences.getCurrencyPreference();
    CurrencyService currencyService = CurrencyService();
    Map<String, double> rates = await currencyService.fetchExchangeRates('USD');

    Map<int, String> convertedPurchasePrices = {};
    for (int i = 0; i < _purchaseHistory.length; i++) {
      final purchase = _purchaseHistory[i];
      double totalPriceInUSD = (purchase['items'] as List).fold<double>(
        0.0,
        (sum, item) => sum + (item['price'] as num).toDouble(),
      );
      double convertedPrice =
          totalPriceInUSD * (rates[selectedCurrency] ?? 1.0);
      String currencySymbol =
          currencySymbols[selectedCurrency] ?? selectedCurrency;

      convertedPurchasePrices[i] =
          '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
    }
    return convertedPurchasePrices;
  }

  Future<void> _fetchProfileUID() async {
    try {
      final result = await _firestore
          .collection('usernames')
          .doc(widget.profileUsername)
          .get();

      if (mounted) {
        setState(() {
          _profileUID = result.data()?['userId'] as String?;
        });

        // Fetch About Me only after setting the profile UID
        if (_profileUID != null) {
          _fetchAboutMe();
          _fetchPortfolioImages();
          _fetchPurchaseHistory();
          _getConvertedPricesPortfolio().then((convertedPrices) {
            setState(() {
              _convertedPrices = convertedPrices;
            });
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false; // Stop loading if no profile UID found
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching profile UID: $e');
      if (mounted) {
        setState(() {
          _profileUID = null;
          _isLoading = false; // Stop loading if an error occurs
        });
      }
    }
  }

  Future<void> _fetchAboutMe() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(_profileUID).get();

      if (mounted) {
        setState(() {
          _aboutMe = userDoc.data()?['aboutMe'] ?? 'No information provided.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: $e')),
        );
      }
    }
  }

  Future<void> _updateAboutMe(String newText) async {
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .update({'aboutMe': newText});

      setState(() {
        _aboutMe = newText;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('About Me updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating About Me: $e')),
      );
    }
  }

  void _showEditAboutMeDialog(BuildContext context) {
    final TextEditingController _controller =
        TextEditingController(text: _aboutMe);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit About Me'),
          content: TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Write something about yourself...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel button
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newText = _controller.text.trim();
                if (newText.isNotEmpty) {
                  _updateAboutMe(newText);
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchPortfolioImages() async {
    try {
      final imagesSnapshot = await _firestore
          .collection('portfolio')
          .where('userId', isEqualTo: _profileUID)
          .get();

      if (mounted) {
        setState(() {
          _portfolioImages = imagesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching portfolio images: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPurchaseHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final historyQuerySnapshot = await FirebaseFirestore.instance
            .collection('purchases')
            .doc(_profileUID)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .get();

        if (historyQuerySnapshot.docs.isNotEmpty) {
          final fetchedHistory = historyQuerySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'items': List<Map<String, dynamic>>.from(data['items'] ?? []),
              'timestamp': data['timestamp'] as Timestamp,
            };
          }).toList();

          print('Fetched purchase history: $fetchedHistory'); // Debugging
          setState(() {
            _purchaseHistory = fetchedHistory;
          });

          _getConvertedPricesPurchaseHistory().then((convertedPurchasePrices) {
            setState(() {
              _convertedPurchasePrices = convertedPurchasePrices;
            });
          });
        }
      }
    } catch (e) {
      print('Error fetching purchase history: $e'); // Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch purchase history: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      // Create controllers for user inputs
      final TextEditingController priceController = TextEditingController();
      final TextEditingController titleController = TextEditingController();
      final TextEditingController descriptionController =
          TextEditingController();

      // Show a dialog to input the title, description, and price
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Upload Artwork'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(hintText: 'Enter title'),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        InputDecoration(hintText: 'Enter art description'),
                    maxLines: 3,
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'Enter price in USD'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Upload'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );

      // Validate inputs
      if (titleController.text.isEmpty ||
          descriptionController.text.isEmpty ||
          priceController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All fields are required.')),
        );
        return;
      }

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You must be logged in to upload images.')),
          );
          return;
        }

        final userId = currentUser.uid;

        // Upload to Firebase Storage
        final ref = _storage.ref().child(
            'portfolio/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask.whenComplete(() => null);
        final imageUrl = await snapshot.ref.getDownloadURL();

        // Save metadata to Firestore
        await _firestore.collection('portfolio').add({
          'userId': userId,
          'imageUrl': imageUrl,
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'price': double.parse(priceController.text),
          'uploadedAt': Timestamp.now(),
        });

        _fetchPortfolioImages();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Artwork uploaded successfully!')),
        );
      } catch (e) {
        print('Error uploading artwork: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload artwork.')),
        );
      }
    }
  }

  void _viewImageDetails(Map<String, dynamic> imageData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailsScreen(
          imageData: imageData,
          isOwnProfile: widget.userId == _profileUID,
          onAddToCart: () => _addToCart(imageData),
        ),
      ),
    );
  }

  void _viewPurchaseDetails(Map<String, dynamic> purchase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseDetailsScreen(purchase: purchase),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchCartFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _firestore.collection('carts').doc(user.uid).get();
    if (snapshot.exists) {
      return snapshot.data() as Map<String, dynamic>;
    }
    return {};
  }

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

  void _addToCart(Map<String, dynamic> item) async {
    setState(() {
      _cart.add(item); // Add the item to the local cart
    });

    try {
      await updateCartInFirestore(item); // Update Firestore cart
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to cart successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cart: $e')),
      );
    }
  }

  Future<void> updateCartInFirestore(Map<String, dynamic> item) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('carts').doc(user.uid).set({
        'cart': FieldValue.arrayUnion([item]), // Add the item to the array
      }, SetOptions(merge: true)); // Merge with existing data
    } catch (e) {
      throw Exception('Failed to update Firestore: $e');
    }
  }

  Future<void> saveCartToFirestore(Map<String, dynamic> cart) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('carts').doc(user.uid).set(cart);
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _profileUID;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile
            ? 'My Profile'
            : '@${widget.profileUsername}\'s Profile'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Me Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'About Me ',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (isOwnProfile) // Show Edit button for own profile
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () =>
                                      _showEditAboutMeDialog(context),
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _aboutMe,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Portfolio Section
                  Text(
                    'Portfolio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _portfolioImages.isEmpty
                      ? Text('No portfolio items yet.')
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          itemCount: _portfolioImages.length,
                          itemBuilder: (context, index) {
                            final image = _portfolioImages[index];
                            final convertedPrice = _convertedPrices[index] ??
                                ''; // Use the converted price

                            return GestureDetector(
                              onTap: () => _viewImageDetails(image),
                              child: Card(
                                elevation: 2,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Image.network(
                                        image['imageUrl'],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            image['title'] ?? 'Untitled',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          // Display the converted price here
                                          Text(
                                            convertedPrice.isEmpty
                                                ? '\$${image['price'].toStringAsFixed(2)}'
                                                : convertedPrice,
                                            style:
                                                TextStyle(color: Colors.green),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  SizedBox(height: 16),
                  if (_purchaseHistory.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Purchase History',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _purchaseHistory.length,
                      itemBuilder: (context, index) {
                        final purchase = _purchaseHistory[index];
                        final convertedPrice = _convertedPurchasePrices[
                                index] ??
                            ''; // Use the converted price for purchase history

                        return GestureDetector(
                          onTap: () => _viewPurchaseDetails(purchase),
                          child: Card(
                            child: ListTile(
                              title: Text(
                                'Total: ${convertedPrice.isEmpty ? '\$${(purchase['items'] as List).fold<double>(0.0, (sum, item) => sum + (item['price'] is num ? (item['price'] as num).toDouble() : 0.0))?.toStringAsFixed(2)}' : convertedPrice}',
                              ),
                              subtitle: Text(
                                'Purchased on: ${DateFormat.yMMMd().format(purchase['timestamp'].toDate())}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: isOwnProfile
          ? FloatingActionButton(
              onPressed: _uploadImage,
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}

class ImageDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> imageData;
  final bool isOwnProfile;
  final VoidCallback? onAddToCart;

  const ImageDetailsScreen({
    required this.imageData,
    required this.isOwnProfile,
    this.onAddToCart,
  });

  Future<String> _getConvertedPrice(String price) async {
    // Define currency symbols
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    // Get the preferred currency
    String selectedCurrency = await Preferences.getCurrencyPreference();

    // Fetch exchange rates
    CurrencyService currencyService = CurrencyService();
    Map<String, double> rates = await currencyService.fetchExchangeRates('USD');

    // Convert the price
    double priceInUSD = double.parse(price);
    double convertedPrice = priceInUSD * (rates[selectedCurrency] ?? 1.0);

    // Get the currency symbol
    String currencySymbol =
        currencySymbols[selectedCurrency] ?? selectedCurrency;

    return '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Details')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(imageData['imageUrl']),
          SizedBox(height: 16),
          Text('Uploaded by: ${imageData['userId']}'),
          FutureBuilder<String>(
            future: _getConvertedPrice(imageData['price'].toString()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('Price: Loading...');
              } else if (snapshot.hasError) {
                return Text('Price: Error');
              } else {
                return Text('Price: ${snapshot.data}');
              }
            },
          ),
          if (!isOwnProfile)
            ElevatedButton(
              onPressed: onAddToCart,
              child: Text('Add to Cart'),
            ),
        ],
      ),
    );
  }
}

class PurchaseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> purchase;

  const PurchaseDetailsScreen({required this.purchase});

  @override
  _PurchaseDetailsScreenState createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  late Future<Map<int, String>> _convertedPricesFuture;

  @override
  void initState() {
    super.initState();
    _convertedPricesFuture = _getConvertedPrices();
  }

  Future<Map<int, String>> _getConvertedPrices() async {
    // Define currency symbols
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'GBP': '£',
      'AUD': 'A\$',
    };

    // Get the preferred currency
    String selectedCurrency = await Preferences.getCurrencyPreference();

    // Fetch exchange rates
    CurrencyService currencyService = CurrencyService();
    Map<String, double> rates = await currencyService.fetchExchangeRates('USD');

    // Prepare the converted prices map
    final items = widget.purchase['items'] as List<Map<String, dynamic>>;
    Map<int, String> convertedPrices = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      double priceInUSD = double.parse(item['price'].toString());
      double convertedPrice = priceInUSD * (rates[selectedCurrency] ?? 1.0);
      String currencySymbol =
          currencySymbols[selectedCurrency] ?? selectedCurrency;

      convertedPrices[i] =
          '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
    }

    return convertedPrices;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.purchase['items'] as List<Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(title: Text('Purchase Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchased on: ${widget.purchase['timestamp'].toDate()}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<Map<int, String>>(
                future: _convertedPricesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error loading prices'));
                  } else {
                    final convertedPrices = snapshot.data!;
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Image.network(
                            item['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(item['title'] ?? 'Untitled'),
                          subtitle: Text(
                            'Price: ${convertedPrices[index] ?? 'Error'}',
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
