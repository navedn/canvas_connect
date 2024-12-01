import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final Future<void> Function(Map<String, dynamic> cart) saveCartToFirestore;

  ShoppingScreen({
    required this.cart,
    required this.saveCartToFirestore,
  });

  @override
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  late List<Map<String, dynamic>> _cart;

  @override
  void initState() {
    super.initState();
    _cart = List.from(widget.cart); // Create a local copy of the cart
  }

  void _removeItem(int index) async {
    setState(() {
      _cart.removeAt(index); // Remove the item from the cart
    });

    try {
      await widget.saveCartToFirestore({'cart': _cart}); // Update Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item removed and cart updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
      ),
      body: _cart.isEmpty
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
