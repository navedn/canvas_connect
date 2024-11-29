import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'messaging_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'profile_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _newPasswordController = TextEditingController();
  String _apiKey = dotenv.env['PIXABAY_API_KEY'] ?? 'not working';
  // Replace with your Pixabay API key
  List<dynamic> _images = [];
  bool _isLoading = false;

  int _selectedIndex = 0; // Track the selected index for BottomNavigationBar

  final List<Widget> _pages = [];

  late String _username = '';

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _fetchImages(); // Fetch images when the screen loads
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

      if (response.statusCode == 200) {
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
      setState(() {
        _isLoading = false;
      });
    }
  }

// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        actions: [
          IconButton(onPressed: () => {}, icon: Icon(Icons.search)),
          IconButton(onPressed: () => {}, icon: Icon(Icons.more_vert)),
        ],
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
            ListTile(
              leading: Icon(Icons.bookmark),
              title: Text('Bookmarks'),
              onTap: () {
                Navigator.of(context).pop(); // Close the drawer
                // Add navigation logic here
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                // Add navigation logic here
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
        onRefresh: _fetchImages,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _images.isEmpty
                ? Center(child: Text('No images found. Pull to refresh.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Number of columns
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final image = _images[index];
                      return GestureDetector(
                        onTap: () {
                          // Handle image tap if needed
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image['webformatURL'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
