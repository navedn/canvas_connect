import 'package:canvas_connect/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MessagingScreen extends StatefulWidget {
  @override
  final String username;

  MessagingScreen({required this.username});

  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _currentUserId;
  List<Map<String, dynamic>> _contacts = [];

  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchContacts();
  }

  // Initialize the current user's ID
  void _initializeUser() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  // Fetch the contacts list from Firestore
  Future<void> _fetchContacts() async {
    try {
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('contacts')
          .get();

      setState(() {
        _contacts = contactsSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        _contacts.sort((a, b) => a['username'].compareTo(b['username']));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching contacts: $e')),
      );
    }
  }

  // Add a new contact and send an introductory message
  Future<void> _addContact(String username, String message) async {
    try {
      // Use the 'usernames' collection for username lookup
      final userQuery = await _firestore
          .collection('usernames') // Assuming 'usernames' stores the mapping
          .doc(username)
          .get();

      if (userQuery.exists) {
        final recipientId = userQuery.data()?['userId'];

        // Add recipient to the current user's contacts
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('contacts')
            .doc(recipientId)
            .set({
          'username': username,
          'userId': recipientId,
        });

        // Add current user to the recipient's contacts
        final currentUserDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        final currentUsername = currentUserDoc.data()?['username'] ?? 'Unknown';

        await _firestore
            .collection('users')
            .doc(recipientId)
            .collection('contacts')
            .doc(_currentUserId)
            .set({
          'username': currentUsername,
          'userId': _currentUserId,
        });

        await _firestore
            .collection('chats')
            .doc(_generateChatId(_currentUserId, recipientId))
            .collection('messages')
            .add({
          'senderId': _currentUserId,
          'recipientId': recipientId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        }).then((value) {
          print('Message sent and timestamp is set');
        }).catchError((e) {
          print('Error: $e');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message sent to $username!')),
        );

        // Update the contact list
        _fetchContacts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate based on selected index
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      );
    }
  }

  // Generate a unique chat ID based on user IDs
  String _generateChatId(String userId1, String userId2) {
    return userId1.hashCode <= userId2.hashCode
        ? '$userId1-$userId2'
        : '$userId2-$userId1';
  }

  // Show a pop-up dialog to enter username and message
  void _showAddContactDialog() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              SizedBox(height: 8),
              TextField(
                controller: messageController,
                decoration: InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final username = usernameController.text.trim();
                final message = messageController.text.trim();

                if (username.isNotEmpty && message.isNotEmpty) {
                  _addContact(username, message);
                }

                Navigator.of(context).pop();
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
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
        title: Text('Messages'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(), // Open Drawer
          ),
        ),
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
                    'Welcome, ${user?.email ?? 'Guest'}',
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
                Navigator.of(context).pop(); // Close the drawer
                // Add navigation logic here
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
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade300,
                  child: Text(
                    contact['username'][0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  contact['username'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.chat, color: Colors.blue.shade300),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: _generateChatId(
                          _currentUserId,
                          contact['userId'],
                        ),
                        currentUserId: _currentUserId,
                        messageUsername: contact['username'],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
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
          onPressed: _showAddContactDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(Icons.add),
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

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String messageUsername;

  ChatScreen(
      {required this.chatId,
      required this.currentUserId,
      required this.messageUsername});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  late Stream<QuerySnapshot> _messagesStream;

  // Cache to store usernames
  final Map<String, String> _usernamesCache = {};

  @override
  void initState() {
    super.initState();
    _messagesStream = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<String> _getUsername(String userId) async {
    if (_usernamesCache.containsKey(userId)) {
      return _usernamesCache[userId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final username = userDoc.data()?['username'] ?? 'Unknown';
      _usernamesCache[userId] = username;
      return username;
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      try {
        await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'senderId': widget.currentUserId,
          'message': message,
          'senderUsername': widget.messageUsername,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
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
        title: Text('Messaging: @' + widget.messageUsername),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final senderId = message['senderId'];
                    final messageText = message['message'];
                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = timestamp != null
                        ? DateFormat('MM/dd/yyyy hh:mm a')
                            .format(timestamp.toDate())
                        : 'No timestamp';
                    final isCurrentUser = senderId == widget.currentUserId;

                    return FutureBuilder<String>(
                      future: _getUsername(senderId),
                      builder: (context, snapshot) {
                        final username = widget.messageUsername ??
                            'Loading...'; // Display while loading
                        return Align(
                          alignment: isCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            padding: EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.blueAccent.withOpacity(0.8)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                                bottomLeft: isCurrentUser
                                    ? Radius.circular(12)
                                    : Radius.zero,
                                bottomRight: isCurrentUser
                                    ? Radius.zero
                                    : Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isCurrentUser)
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                SizedBox(height: 4),
                                Text(
                                  messageText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCurrentUser
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Enter message',
                      prefixIcon: Icon(Icons.message, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(14),
                  ),
                  child: Icon(Icons.send, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
