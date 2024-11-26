import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canvas_connect/register_screen.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'home_screen.dart';
// import 'profile_screen.dart';
// import 'settings_screen.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      primaryColor: Colors.blueAccent.shade200,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.pink, // Set the default background color
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.blueAccent.shade200,
                const Color.fromARGB(255, 64, 220, 251),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          shadows: [
            Shadow(
              offset: Offset(0, 4),
              blurRadius: 0.5,
              color: Colors.black45,
            ),
          ],
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.9),
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        labelStyle: TextStyle(color: Colors.black54),
        prefixIconColor: Colors.blueAccent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          backgroundColor: const Color.fromARGB(255, 64, 220, 251),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: TextStyle(
            fontSize: 16,
            color: const Color.fromARGB(255, 7, 255, 226).withOpacity(0.9),
            shadows: [
              Shadow(
                offset: Offset(0, 4),
                blurRadius: 0.5,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
      colorScheme: ColorScheme.fromSwatch()
          .copyWith(secondary: const Color.fromARGB(255, 64, 220, 251)),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Chat App',
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        // '/profile': (context) => ProfileScreen(),
        // '/settings': (context) => SettingsScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() {
        _errorMessage = "Login failed. Please check your email and password.";
      });
    }
  }

  Future<void> _resetPassword() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _resetEmailController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Enter your email address",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _resetEmailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
              ),
              onPressed: () async {
                if (_resetEmailController.text.isNotEmpty) {
                  try {
                    await _auth.sendPasswordResetEmail(
                      email: _resetEmailController.text,
                    );
                    Navigator.of(context).pop(); // Close the dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Password reset email sent!")),
                    );
                  } catch (e) {
                    Navigator.of(context).pop(); // Close the dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error sending reset email")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter an email")),
                  );
                }
              },
              child: Text("Send Reset Email"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Login Screen')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade300,
              Colors.purple.shade300,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Canvas Connect',
                  style: TextStyle(
                    fontSize: 40,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [
                          Colors.blueAccent.shade200,
                          const Color.fromARGB(255, 64, 220, 251),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                    shadows: [
                      Shadow(
                        offset: Offset(0, 4),
                        blurRadius: 0.5,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.purpleAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors
                            .black, // Adjust to match your app's color theme
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _login();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    backgroundColor: Color.fromARGB(255, 64, 220, 251),
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: Text(
                    'Don\'t have an account? Register Here!',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color.fromARGB(255, 7, 255, 226)
                          .withOpacity(0.9),
                      shadows: [
                        Shadow(
                          offset: Offset(0, 4),
                          blurRadius: 0.5,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
