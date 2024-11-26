import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return ListTile(
            title: Text(contact['username']),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: _generateChatId(_currentUserId, contact['userId']),
                    currentUserId: _currentUserId, // Pass the current user ID
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId; // Add currentUserId to constructor

  ChatScreen({required this.chatId, required this.currentUserId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  late Stream<QuerySnapshot> _messagesStream;

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

  // Send a new message to Firestore
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      try {
        await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'senderId': widget
              .currentUserId, // Use currentUserId passed from MessagingScreen
          'message': message,
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
      appBar: AppBar(title: Text('Chat')),
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
                    final timestamp = message['timestamp'];
                    String formattedTime = 'No timestamp';

                    if (timestamp != null) {
                      formattedTime = (timestamp as Timestamp)
                          .toDate()
                          .toLocal()
                          .toString();
                    }

                    return ListTile(
                      title: Text(
                          senderId), // You can map senderId to username if needed
                      subtitle: Text(messageText),
                      trailing: Text(formattedTime),
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
                    decoration: InputDecoration(hintText: 'Enter message'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
