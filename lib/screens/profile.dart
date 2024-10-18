import 'dart:convert'; // Per convertire le risposte JSON
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? profileImageUrl;
  List<String> images = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmail = prefs.getString('userEmail');

    if (userEmail != null) {
      await fetchProfileData(userEmail);
      await fetchImages(userEmail);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchProfileData(String userEmail) async {
    try {
      if (userEmail == null) {
        print('No email found. User may not be logged in.');
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/profile'),
        headers: {
          'Content-Type': 'application/json',
        },
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
    final url = Uri.parse('http://10.0.2.2:5000/getImage');

    try {
      // Prepara il corpo della richiesta
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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
        title: Text('Profile'),
      ),
      body: isLoading
          ? Center(
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
                            ? Icon(Icons.person,
                                size:
                                    40) // Icona di default se non c'è immagine
                            : null,
                      ),
                      SizedBox(width: 16),
                      Text(
                        userName ??
                            'Unknown User', // Mostra il nome dell'utente o un valore di default
                        style: TextStyle(
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Numero di colonne
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: images.length, // Usa la lista 'images'
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index], // Mostra ogni immagine dalla lista
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
