import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchProfileUID();
    _fetchPortfolioImages();
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

      if (mounted) {
        setState(() {
          _profileUID = result.data()?['userId'] as String?;
        });

        // Fetch About Me only after setting the profile UID
        if (_profileUID != null) {
          _fetchAboutMe();
          _fetchPurchaseHistory();
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

      // Show a dialog to input the price
      final TextEditingController priceController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Set a Price for Your Art'),
            content: TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Enter price in USD'),
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

      if (priceController.text.isEmpty) return;

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('No user is signed in!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You must be logged in to upload images.')),
          );
          return;
        }

        final userId = currentUser.uid;

        print('Uploading image for user ID: $userId');

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
          'price': double.parse(priceController.text),
          'uploadedAt': Timestamp.now(),
        });

        _fetchPortfolioImages();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image uploaded successfully!')),
        );
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image.')),
        );
      }
    }
  }

  void _viewImageDetails(Map<String, dynamic> imageData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailsScreen(imageData: imageData),
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

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _profileUID;
    _fetchPortfolioImages();

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
                                    Text(
                                      '\$${image['price'].toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 14),
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
                        return Card(
                          child: ListTile(
                            title: Text(
                                'Total: \$${(purchase['items'] as List).cast<Map<String, dynamic>>().fold<double>(
                                      0.0,
                                      (sum, item) =>
                                          sum +
                                          (item['price'] as num).toDouble(),
                                    ).toStringAsFixed(2)}'),
                            subtitle: Text(
                                'Purchased on: ${purchase['timestamp'].toDate()}'),
                            trailing: Icon(Icons.arrow_forward),
                            onTap: () => _viewPurchaseDetails(purchase),
                          ),
                        );
                      },
                    ),
                  ]
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

  const ImageDetailsScreen({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(imageData['imageUrl']),
            SizedBox(height: 16),
            Text('Uploaded by: ${imageData['userId']}'),
            Text('Price: \$${imageData['price'].toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class PurchaseDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> purchase;

  const PurchaseDetailsScreen({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final items = purchase['items'] as List<Map<String, dynamic>>;
    return Scaffold(
      appBar: AppBar(title: Text('Purchase Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchased on: ${purchase['timestamp'].toDate()}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
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
                    title: Text(item['title'] ?? 'Unknown Item'),
                    subtitle: Text('\$${item['price']}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
