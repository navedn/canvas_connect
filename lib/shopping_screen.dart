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
              : ListView.builder(
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
    );
  }
}
