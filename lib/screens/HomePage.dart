import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:social_flutter_giorgio/firebase_options.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
import 'package:social_flutter_giorgio/screens/Event.dart';
import 'package:social_flutter_giorgio/screens/profile.dart';
import 'package:social_flutter_giorgio/screens/ScoreboardPage.dart';
import '../auth.dart';
import 'dart:io';
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
  runApp(const Homepage());
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
  String? userEmail;
  String? token;
  String? point;
  String? photo;
  String? profileImageUrl;
  List<dynamic> CodeEventList = [];
  double? eventLatitude;
  double? eventLongitude;
  bool hasError = false;
  //String host = "127.0.0.1:5000";
  String host = "10.0.2.2:5000";
  final TextEditingController _searchController = TextEditingController();
  late List<dynamic> profilesListSearch;
  late List<dynamic> imagesListSearch;
  late List<dynamic> emailsListSearch;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _checkTokenValidity(int statusCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (statusCode == 401) {
      try {
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          String? idToken = await user.getIdToken(true);
          prefs.setString('jwtToken', idToken!);
        } else {
          await Auth().signOut();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        }
      } catch (e) {
        await Auth().signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail');
    token = prefs.getString('jwtToken');

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

  Future<void> _fetchEventCoordinates(String code) async {
    final url = Uri.parse('http://' + host + '/get_coordinate');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      final body = jsonEncode({
        'code': code,
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          eventLatitude = double.tryParse(data['latitude'].toString()) ?? 0.0;
          eventLongitude = double.tryParse(data['longitude'].toString()) ?? 0.0;
        });
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception('Failed to load event coordinates');
      }
    } catch (e) {
      print("Errore nel recuperare le coordinate dell'evento: $e");
    }
  }

  Future<void> event() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EventCalendar()),
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
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://' + host + '/upload'),
    );
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (userEmail != null) {
      request.fields['email'] = userEmail!;
    }

    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));
    request.headers.addAll(headers);

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      print('File URL: ${jsonResponse['file_url']}');
    } else {
      _checkTokenValidity(response.statusCode);
      print('Upload failed');
    }
  }

  Future<List<dynamic>?> checkUserEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (userEmail != null) {
      try {
        final response = await http.get(
            Uri.parse('http://' + host + '/getEventCode?email=$userEmail'),
            headers: headers);

        if (response.statusCode == 200) {
          Map<String, dynamic> jsonResponse = json.decode(response.body);
          CodeEventList = jsonResponse['event_codes'];
          return CodeEventList;
        } else {
          _checkTokenValidity(response.statusCode);
          print('Failed to load dates: ${response.statusCode}');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
    return null;
  }

  Future<void> uploadImageForEvent(String eventCode) async {
    String message;
    await _fetchEventCoordinates(eventCode);
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      // Il permesso è stato concesso
      // Ottieni la posizione corrente del dispositivo
      Position currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Calcola la distanza tra la posizione corrente e quella dell'evento
      double distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        eventLatitude!,
        eventLongitude!,
      );

      if (distance <= 1000) {
        message = 'Posizione ok';
        if (_capturedImage != null) {
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          };
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('http://' + host + '/uploadEventImage'),
          );
          request.headers.addAll(headers);

          request.fields['eventCode'] = eventCode;
          request.fields['email'] = userEmail!;
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            _capturedImage!.path,
          ));

          var response = await request.send();

          if (response.statusCode == 200) {
            print('Foto caricata con successo');
          } else {
            _checkTokenValidity(response.statusCode);
            print('Errore nel caricamento della foto');
          }
        }
      } else {
        message = 'Sei troppo lontano dall\'evento';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else if (permission.isDenied) {
      print("Permesso negato. Non è possibile accedere alla posizione.");
      // Potresti mostrare un messaggio all'utente per spiegare che è necessario il permesso
    } else if (permission.isPermanentlyDenied) {
      // Il permesso è stato negato in modo permanente, apri le impostazioni dell'app
      openAppSettings();
    }
  }

  void showEventsDialog(List<dynamic> events) {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleziona un evento'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                for (var i = 0; i < events.length; i++)
                  GestureDetector(
                    onTap: () async {
                      await uploadImageForEvent(events[i]);
                      await uploadImage(_capturedImage!);
                      Navigator.of(context).pop(); // Chiudi il popup
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                          content:
                              Text('Foto caricata per l\'evento ${events[i]}'),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text('Evento: ${events[i]}'),
                      // subtitle: Text('Data: ${events[i]['eventDate']}'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void onTabTapped() async {
    var index = 1;
    if (index == 1) {
      // Scatta una foto
      final image = await takePicture();
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });

        final isEnrolledInEvents = await checkUserEvents();

        if (isEnrolledInEvents != null) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Caricare foto in un evento?'),
                content:
                    const Text('Sei iscritto a eventi. Vuoi caricare la foto?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('No'),
                    onPressed: () async {
                      await uploadImage(_capturedImage!);
                      Navigator.of(context)
                          .pop(); // Chiudi popup senza fare nulla
                    },
                  ),
                  TextButton(
                    child: const Text('Sì'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      showEventsDialog(isEnrolledInEvents);

                      // Mostra conferma di caricamento
                      //ScaffoldMessenger.of(context).showSnackBar(
                      //SnackBar(
                      //   content: Text(
                      //     'Foto caricata con successo negli eventi!')),
                      //  );
                    },
                  ),
                ],
              );
            },
          );
        } else {
          // Se non sei iscritto ad eventi, carica direttamente la foto o mostra un messaggio
          await uploadImage(_capturedImage!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Foto caricata senza evento associato')),
          );
        }
      }
    }

    /*if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }*/
  }

  Future<void> fetchImages(String? email) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('http://' + host + '/getImage');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        photo = "true";
        setState(() {
          images = List<String>.from(data['images']);
        });
      } else {
        _checkTokenValidity(response.statusCode);
        print(response.body);
      }
    } catch (error) {
      print('Errore durante la richiesta: $error');
    }
  }

  Future<void> fetchProfileData(String? userEmail) async {
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
            point = data['point'];
            isLoading = false;
          });
        }
      } else {
        _checkTokenValidity(response.statusCode);
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

  Future<bool> _deletePhoto(String photoUrl) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('http://' + host + '/delete_photo_by_url');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'image_url': photoUrl}),
      );

      if (response.statusCode == 200) {
        setState(() {
          images.remove(photoUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto eliminata con successo')),
        );
        return true;
      } else {
        _checkTokenValidity(response.statusCode);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore: impossibile eliminare la foto')),
        );
        return false;
      }
    } catch (error) {
      // Gestione errori di rete
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di connessione')),
      );
      return false;
    }
  }

  Future<void> searchProfiles(String query) async {
    String apiUrl = "http://" + host + "/search_profiles";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'profilo': query,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        profilesListSearch = data['profiles'];
        imagesListSearch = data['images'];
        emailsListSearch = data['emails'];
        _showSearchResultsDialog(
            emailsListSearch, profilesListSearch, imagesListSearch);
      } else {
        _checkTokenValidity(response.statusCode);
        print("Errore API: ${response.statusCode}");
        throw Exception("Errore durante la ricerca: ${response.body}");
      }
    } catch (e) {
      print("Errore durante la chiamata API: $e");
      throw Exception("Impossibile connettersi all'API.");
    }
  }

  void _showSearchResultsDialog(List emails, List profiles, List images) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titolo
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Risultati della ricerca',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Risultati
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: images.isNotEmpty
                              ? NetworkImage(images[index])
                              : null,
                          child:
                              images.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(profiles[index]),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProfilePage(email: emails[index]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Pulsante Chiudi
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text('Chiudi'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchProfiles() {
    final searchText = _searchController.text;
    searchProfiles(searchText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
          ),
          onSubmitted: (value) {
            _searchProfiles();
          },
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
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
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.score_outlined),
              title: const Text('Scoreboard'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ScoreboardPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Event'),
              onTap: () {
                event();
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_sharp),
              title: const Text('Connect'),
              onTap: () {
                //event();/////////////////////////////////////////TO DO
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    point ?? 'Unknown Point',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: images.isNotEmpty
                  ? GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            // Immagine
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            // Pulsante di eliminazione
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () async {
                                  bool isDeleted =
                                      await _deletePhoto(images[index]);
                                  if (isDeleted) {
                                    setState(() {
                                      images.removeAt(index);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nessuna foto disponibile',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            )
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 100.0,
        height: 60.0,
        child: FloatingActionButton(
          onPressed: onTabTapped,
          child: const Icon(Icons.add_a_photo),
          backgroundColor: Colors.amber[800],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Container(height: 60.0),
      ),
    );
  }
}
