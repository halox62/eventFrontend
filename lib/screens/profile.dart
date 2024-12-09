import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  List<String> images = [];
  bool isLoading = true;
  String? token;
  String host = "127.0.0.1:5000";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _checkTokenValidity(String message) async {
    message.toLowerCase();
    if (message.contains("token")) {
      await Auth().signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail');
    token = prefs.getString('jwtToken');

    if (userEmail != null) {
      await fetchProfileData(userEmail!);
      await fetchImages(userEmail!);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchProfileData(String userEmail) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        Uri.parse('http://' + host + '/profile'),
        headers: headers,
        body: jsonEncode({
          'email': userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            userName = data['userName'];
            profileImageUrl = data['profileImageUrl'];
            isLoading = false;
          });
        }
      } else {
        var errorData = jsonDecode(response.body);
        _checkTokenValidity(errorData['msg']);
        throw Exception('Failed to load profile data');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error fetching profile data: $error');
    }
  }

  Future<void> fetchImages(String email) async {
    final url = Uri.parse('http://' + host + '/getImage');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      // Prepara il corpo della richiesta
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': email}),
      );

      // Controlla se la risposta è andata a buon fine
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          images = List<String>.from(
              data['images']); // Aggiorna la lista delle immagini
        });
      } else {
        var errorData = jsonDecode(response.body);
        _checkTokenValidity(errorData['msg']);
        print('Errore: ${response.statusCode}');
        print(response.body);
      }
    } catch (error) {
      print('Errore durante la richiesta: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Mostra un indicatore di caricamento
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : null, // Mostra l'immagine del profilo se disponibile
                        child: profileImageUrl == null
                            ? const Icon(Icons.person,
                                size:
                                    40) // Icona di default se non c'è immagine
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        userName ??
                            'Unknown User', // Mostra il nome dell'utente o un valore di default
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
