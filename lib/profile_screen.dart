import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  late String _currentUserId;
  late String _aboutMe;
  String? _profileUID;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchProfileUID();
  }

  void _initializeUser() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<void> _fetchProfileUID() async {
    try {
      final result = await _firestore
          .collection('usernames')
          .doc(widget.profileUsername)
          .get();

      setState(() {
        _profileUID = result.data()?['userId'] as String?;
      });

      // Fetch About Me only after setting the profile UID
      if (_profileUID != null) {
        _fetchAboutMe();
      } else {
        setState(() {
          _isLoading = false; // Stop loading if no profile UID found
        });
      }
    } catch (e) {
      print('Error fetching profile UID: $e');
      setState(() {
        _profileUID = null;
        _isLoading = false; // Stop loading if an error occurs
      });
    }
  }

  Future<void> _fetchAboutMe() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(_profileUID).get();

      setState(() {
        _aboutMe = userDoc.data()?['aboutMe'] ?? 'No information provided.';
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile: $e')),
      );
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

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile
            ? 'My Profile, ${widget.profileUsername}'
            : 'Profile: ${_profileUID ?? 'Loading...'}'),
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
                ],
              ),
            ),
    );
  }
}
