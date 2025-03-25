import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final String host = "www.event-fit.it";
  String? token;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwtToken');
      userEmail = prefs.getString('email');
      if (token == null || userEmail == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  Future<void> _checkTokenValidity(int statusCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (statusCode == 401) {
      try {
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          String? idToken = await user.getIdToken(true);
          prefs.setString('jwtToken', idToken!);
          _initializeData();
        } else {
          await Auth().signOut();
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.clear();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        }
      } catch (e) {
        await Auth().signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card per Elimina Account
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: BorderSide(color: Colors.white, width: 1),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.delete, color: Colors.red, size: 28),
              title: const Text(
                'Delete Account',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                // Logica di eliminazione account (come nel codice originale)
                bool? confirmDelete = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Conferma Eliminazione Account'),
                      content: const Text(
                          'Sei sicuro di voler procedere con l\'eliminazione del tuo account? Questa è un\'azione irreversibile.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('No, annulla'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sì, procedi'),
                        ),
                      ],
                    );
                  },
                );

                // Resto del codice di eliminazione account rimane invariato
                if (confirmDelete == true) {
                  final TextEditingController emailController =
                      TextEditingController();
                  bool? proceedWithDeletion = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Conferma Eliminazione'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                                'Per procedere, inserisci la tua email:'),
                            TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                hintText: 'Inserisci la tua email',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Annulla'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (emailController.text.trim() == userEmail) {
                                Navigator.of(context).pop(true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Email non corrispondente'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('Conferma'),
                          ),
                        ],
                      );
                    },
                  );

                  // Procedi con l'eliminazione dell'account
                  if (proceedWithDeletion == true) {
                    final url = Uri.parse('https://$host/delete_account');

                    final headers = {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    };
                    try {
                      final body = jsonEncode({
                        'email': userEmail,
                      });

                      final response = await http.post(
                        url,
                        headers: headers,
                        body: body,
                      );

                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Account eliminato con successo'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        await FirebaseAuth.instance.signOut();
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        prefs.clear();

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AuthPage()),
                        );
                      } else {
                        _checkTokenValidity(response.statusCode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
