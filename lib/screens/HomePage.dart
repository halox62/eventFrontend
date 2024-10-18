import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:social_flutter_giorgio/firebase_options.dart';
import 'package:social_flutter_giorgio/screens/Event.dart';
import 'package:social_flutter_giorgio/screens/profile.dart';
import '../auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );
  runApp(Homepage());
}

class Homepage extends StatefulWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  File? _capturedImage;
  List<String> images = [];
  String? userName;
  String? profileImageUrl;

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

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Future<void> event() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EventPage()),
    );
  }

  Future<File?> takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      return File(pickedFile.path);
    } else {
      return null;
    }
  }

  Future<void> uploadImage(File imageFile) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmail = prefs.getString('userEmail');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:5000/upload'),
    );

    if (userEmail != null) {
      request.fields['email'] = userEmail;
    }

    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      print('File URL: ${jsonResponse['file_url']}');
    } else {
      print('Upload failed');
    }
  }

  void onTabTapped() async {
    var index = 1;
    if (index == 1) {
      // Quando si clicca su "Add", apri la fotocamera per scattare una foto
      final image = await takePicture();
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });

        await uploadImage(_capturedImage!);
      }
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
            decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
        )),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.event),
              title: Text('Event'),
              onTap: () {
                event();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                signOut();
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                            size: 40) // Icona di default se non c'è immagine
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
                  crossAxisCount: 2, // Numero di colonne
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
      ),
      floatingActionButton: Container(
        width: 100.0, // Imposta la larghezza desiderata
        height: 60.0, // Imposta l'altezza desiderata
        child: FloatingActionButton(
          onPressed: onTabTapped,
          child: Icon(Icons.add_a_photo),
          backgroundColor: Colors.amber[800],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Container(height: 60.0),
      ),
      /*bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped, // Collega il metodo onTabTapped per gestire i tap
        currentIndex: _currentIndex, // Stato corrente del bottone selezionato
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'profile',
          ),
        ],
      
        selectedItemColor: Colors.amber[800],
      ),*/
    );
  }
}
