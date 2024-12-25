import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _userName = TextEditingController();
  File? _profileImage;
  bool isLogin = true;
  String host = "127.0.0.1:5000";

  final ImagePicker _picker = ImagePicker();

  Future<void> signIn() async {
    try {
      await Auth().signInWithEmailAndPassword(
          email: _email.text, password: _password.text);

      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwtToken', token!);
    } on FirebaseAuthException catch (error) {
      String message = "Wrong Credentials";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      print('Error: ${error.message}');
    }
  }

  Future<void> createUser() async {
    try {
      await Auth().createUserWithEmailAndPassword(
          email: _email.text, password: _password.text);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://' + host + '/register'),
      );

      request.fields['email'] = _email.text;
      request.fields['userName'] = _userName.text;

      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profileImage',
          _profileImage!.path,
        ));
      }
      var response = await request.send();

      if (response.statusCode == 200) {
        await response.stream.bytesToString();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', _email.text);

        User? user = FirebaseAuth.instance.currentUser;
        String? token = await user?.getIdToken();

        prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', _email.text);

        await prefs.setString('jwtToken', token!);
      }
    } catch (e) {
      log('Errore: $e');
    }
  }

  // Metodo per selezionare un'immagine dalla galleria o scattarla
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // Metodo per caricare l'immagine su Firebase Storage
  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      String fileName = 'profile_images/${_email.text}.png';
      Reference ref = storage.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Errore nel caricamento dell\'immagine: $e');
      return '';
    }
  }

  // Metodo per aprire un bottom sheet e scegliere se scattare o selezionare un'immagine
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galleria'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Fotocamera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _profileImage != null && !isLogin
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50.0),
                      child: Image.file(
                        _profileImage!,
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(),
              const SizedBox(height: 32),
              Stack(
                children: [
                  Column(
                    children: [
                      // Campo per email
                      TextField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: Colors.white),
                          fillColor: Colors.black45,
                          filled: true,
                          prefixIcon:
                              const Icon(Icons.email, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      // Campo per password
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white),
                          fillColor: Colors.black45,
                          filled: true,
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      if (!isLogin) // Mostra questi campi solo quando si sta registrando
                        Column(
                          children: [
                            // Campo per nome utente
                            TextField(
                              controller: _userName,
                              decoration: InputDecoration(
                                labelText: 'Nome utente',
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                fillColor: Colors.black45,
                                filled: true,
                                prefixIcon: const Icon(Icons.person,
                                    color: Colors.white),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            // Selezione foto profilo
                            ElevatedButton(
                              onPressed: () {
                                _showPicker(
                                    context); // Mostra il bottom sheet per scegliere
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                minimumSize: const Size(double.infinity, 50),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: const Text('Seleziona foto profilo'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              // Pulsante di login/registrazione
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  isLogin ? signIn() : createUser();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(isLogin ? 'Accedi' : 'Registrati'),
              ),
              const SizedBox(height: 16),
              // Pulsante per cambiare tra login e registrazione
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin
                      ? 'Non hai un account? Registrati'
                      : 'Hai un account? Accedi',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              )
            ],
          ),
        ),
      ),
      backgroundColor: Colors.black87, // Colore di sfondo del login
    );
  }
}
