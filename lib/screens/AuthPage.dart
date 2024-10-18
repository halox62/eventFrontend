import 'dart:convert';
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

  final ImagePicker _picker = ImagePicker();

  Future<void> signIn() async {
    try {
      await Auth().signInWithEmailAndPassword(
          email: _email.text, password: _password.text);
      // Salva l'email nelle SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', _email.text);
    } on FirebaseAuthException catch (error) {
      print('Error: ${error.message}');
    }
  }

  Future<void> createUser() async {
    try {
      // Autenticazione con Firebase
      await Auth().createUserWithEmailAndPassword(
          email: _email.text, password: _password.text);

      // Crea una richiesta multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/register'),
      );

      // Aggiungi i campi dell'utente
      request.fields['email'] = _email.text;
      request.fields['userName'] = _userName.text;

      // Aggiungi il file immagine alla richiesta, se disponibile
      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profileImage',
          _profileImage!.path,
        ));
      }

      // Invia la richiesta e attendi la risposta
      var response = await request.send();

      // Controlla lo stato della risposta
      if (response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        print('Success: $responseData');
        // Salva l'email nelle SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', _email.text);
      } else {
        print(
            'Failed: ${response.statusCode}, Response: ${await response.stream.bytesToString()}');
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
      String fileName =
          'profile_images/${_email.text}.png'; // Salva con l'email
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
                  leading: Icon(Icons.photo_library),
                  title: Text('Galleria'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Fotocamera'),
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
          title: const Text('AuthPage'),
        ),
        body: Column(
          children: [
            TextField(
              controller: _email,
              decoration: InputDecoration(label: Text('Email')),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(label: Text('Password')),
            ),
            if (!isLogin) // Mostra questi campi solo quando si sta registrando
              Column(
                children: [
                  TextField(
                    controller: _userName,
                    decoration: InputDecoration(label: Text('Nome utente')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _showPicker(
                          context); // Mostra il bottom sheet per scegliere
                    },
                    child: Text('Seleziona foto profilo'),
                  ),
                  _profileImage != null
                      ? Image.file(
                          _profileImage!,
                          height: 100,
                          width: 100,
                        )
                      : Container(), // Mostra l'immagine selezionata
                ],
              ),
            ElevatedButton(
              onPressed: () {
                isLogin ? signIn() : createUser();
              },
              child: Text(isLogin ? 'Accedi' : 'Registrati'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(isLogin
                  ? 'Non hai un account? Registrati'
                  : 'Hai un account? Accedi'),
            )
          ],
        ));
  }
}
