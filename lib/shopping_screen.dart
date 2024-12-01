import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingScreen extends StatefulWidget {
  @override
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCart(); // Fetch the cart data when the screen is initialized
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _cart.isEmpty
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
                            title: Text('Price: ${item['price']}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _removeItem(index),
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_cart.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Your cart is empty!')),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(cart: _cart),
                            ),
                          );
                        }
                      },
                      child: Text('Checkout'),
                    ),
                  ],
                ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cart;

  CheckoutScreen({required this.cart});

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
    double total =
        cart.fold(0.0, (sum, item) => sum + (item['price'] as num).toDouble());

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
                  title: Text('Price: ${item['price']}'),
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
                  'Total: \$${total.toStringAsFixed(2)}',
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
