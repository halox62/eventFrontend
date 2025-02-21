import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:social_flutter_giorgio/firebase_options.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
import 'package:social_flutter_giorgio/screens/Event.dart';
import 'package:social_flutter_giorgio/screens/ShareProfileDialog.dart';
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
  //String host = "10.0.2.2:5000";
  String host = "event-production.up.railway.app";
  final TextEditingController _searchController = TextEditingController();
  late List<dynamic> profilesListSearch;
  late List<dynamic> imagesListSearch;
  late List<dynamic> emailsListSearch;
  bool isLoading = true;

  int? enlargedImageIndex;
  bool isImageEnlarged = false;
  late BuildContext _dialogContext;

  @override
  void initState() {
    super.initState();
    _initializeData(true);
  }

  Future<void> _initializeData(bool loading) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    userEmail = prefs.getString('email');

    try {
      if (loading) {
        showLoadingDialog("Loading");
      }

      if (token != null) {
        await fetchProfileData();
        await fetchImages();
        Navigator.of(_dialogContext).pop();
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(_dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'aggiornamento'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleImageTap(int index) {
    setState(() {
      if (enlargedImageIndex == index) {
        enlargedImageIndex = null;
        isImageEnlarged = false;
      } else if (isImageEnlarged) {
        enlargedImageIndex = null;
        isImageEnlarged = false;
      }
    });
  }

  void _handleImageLongPress(int index) {
    setState(() {
      enlargedImageIndex = index;
      isImageEnlarged = true;
    });
  }

  Future<void> _handleRefresh() async {
    try {
      await _initializeData(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'aggiornamento'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          _initializeData(false);
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

  Future<void> signOut() async {
    await Auth().signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  Future<void> _fetchEventCoordinates(String code) async {
    final url = Uri.parse('https://$host/get_coordinate');
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

  void showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        _dialogContext = context;
        return Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
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
      Uri.parse('https://$host/upload'),
    );
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));
    request.headers.addAll(headers);

    var response = await request.send();

    if (response.statusCode == 200) {
      await _initializeData(true);
    } else {
      _checkTokenValidity(response.statusCode);
      print('Upload failed');
    }
  }

  Future<List<dynamic>?> checkUserEvents() async {
    DateTime now = DateTime.now();
    String clientTime = DateFormat("HH:mm").format(now);

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(
        Uri.parse('https://$host/getEventCode?clientTime=$clientTime'),
        headers: headers,
      );

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
    return null;
  }

  Future<void> uploadImageForEvent(String eventCode, String eventName) async {
    String message = "Errore caricamento";
    double latitudine;
    double longitudine;

    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      Position currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      latitudine = currentPosition.latitude;
      longitudine = currentPosition.longitude;

      if (_capturedImage != null) {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://$host/uploadEventImage'),
        );
        request.headers.addAll(headers);

        request.fields['eventCode'] = eventCode;
        request.fields['latitudine'] = latitudine.toString();
        request.fields['longitudine'] = longitudine.toString();
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _capturedImage!.path,
        ));

        var response = await request.send();

        if (response.statusCode == 200) {
          await _initializeData(true);
          message = 'Foto caricata per l\'evento $eventName';
        } else {
          _checkTokenValidity(response.statusCode);
          if (response.statusCode == 403) {
            message = "Foto non caricata sei troppo lontano dall'evento";
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else if (permission.isDenied) {
    } else if (permission.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<String> getEventName(String eventCode) async {
    try {
      final response = await http.post(
        Uri.parse('https://$host/nameByCode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'code': eventCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['name'] ?? 'N/A';
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Error fetching event name: $e');
      return 'N/A';
    }
  }

  void showEventsDialog(List<dynamic> events) {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleziona un evento',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < events.length; i++)
                          FutureBuilder<String>(
                            future: getEventName(events[i]),
                            builder: (context, snapshot) {
                              final eventName =
                                  snapshot.data ?? 'Caricamento...';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      showLoadingDialog("Loading");
                                      await uploadImageForEvent(
                                          events[i], eventName);
                                      Navigator.of(context).pop();
                                      Navigator.of(_dialogContext).pop();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.event,
                                                  color: Colors.green,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      eventName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Codice: ${events[i]}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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

  Widget _buildButton(String text,
      {bool outlined = false,
      required void Function() onPressed,
      required MaterialColor color}) {
    return outlined
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: onPressed,
            child: Text(text, style: const TextStyle(fontSize: 16)),
          )
        : FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: onPressed,
            child: Text(text, style: const TextStyle(fontSize: 16)),
          );
  }

  void _showUploadSuccess(BuildContext context, bool withEvent) {
    // Ensure we're using a valid context by scheduling the SnackBar for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // Check if the context is still valid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  withEvent
                      ? 'Foto caricata nell\'evento con successo!'
                      : 'Foto caricata con successo',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  void _showEventSelectionDialog(List<dynamic> events, File image) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use separate context for dialog
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Carica foto',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sei iscritto a degli eventi. Vuoi caricare la foto in uno di essi?',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      "Scegli evento",
                      color: Colors.green,
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        showEventsDialog(events);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildButton(
                      "Carica senza evento",
                      color: Colors.grey,
                      outlined: true,
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await uploadImage(image);
                        if (context.mounted) {
                          // Check if the original context is still valid
                          _showUploadSuccess(context, false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _uploadImageWithoutEvent(File image) async {
    showLoadingDialog("Caricamento foto...");
    await uploadImage(image);
    Navigator.of(_dialogContext).pop();
    if (context.mounted) {
      _showUploadSuccess(context, false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void onTabTapped() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleziona sorgente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    context: context,
                    icon: Icons.photo_library_outlined,
                    label: 'Galleria',
                    onTap: () {
                      Navigator.pop(context);
                      _processGalleryImage();
                    },
                  ),
                  _buildOptionButton(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Fotocamera',
                    onTap: () {
                      Navigator.pop(context);
                      _processCameraImage();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(177, 233, 144, 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 40,
              color: const Color.fromRGBO(76, 175, 80, 1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCameraImage() async {
    try {
      showLoadingDialog("Apertura fotocamera...");
      final image = await takePicture();
      Navigator.of(_dialogContext).pop();

      if (image != null) {
        _processSelectedImage(image);
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore con la fotocamera: $e");
    }
  }

  Future<void> _processGalleryImage() async {
    try {
      showLoadingDialog("Apertura galleria...");
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      Navigator.of(_dialogContext).pop();

      if (pickedFile != null) {
        File image = File(pickedFile.path);
        _processSelectedImage(image);
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore con la galleria: $e");
    }
  }

  Future<void> _processSelectedImage(File image) async {
    try {
      setState(() {
        _capturedImage = image;
      });

      showLoadingDialog("Verifica eventi...");
      final isEnrolledInEvents = await checkUserEvents();
      Navigator.of(_dialogContext).pop();

      if (isEnrolledInEvents != null && isEnrolledInEvents.isNotEmpty) {
        _showEventSelectionDialog(isEnrolledInEvents, image);
      } else {
        _uploadImageWithoutEvent(image);
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore: $e");
    }
  }

  Future<void> fetchImages() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/getImage');

    try {
      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        photo = "true";
        setState(() {
          images = List<String>.from(data['images']);
        });
      } else {
        _checkTokenValidity(response.statusCode);
      }
    } catch (error) {
      print('Errore durante la richiesta: $error');
    }
  }

  Future<void> fetchProfileData() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response =
          await http.post(Uri.parse('https://$host/profile'), headers: headers);
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
    final url = Uri.parse('https://$host/delete_photo_by_url');
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
        await _initializeData(true);
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
    String apiUrl = "https://$host/search_profiles";

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: (query) => searchProfiles(query),
            decoration: InputDecoration(
              hintText: 'Cerca...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: const Icon(
                Icons.search,
                color: Color.fromRGBO(0, 0, 0, 1),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: NavigationDrawer(
        backgroundColor: colorScheme.surface,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(177, 233, 144, 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Menu',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // Chiude il drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.score_outlined),
            title: const Text('Scoreboard'),
            onTap: () {
              Navigator.pop(context); // Chiude il drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScoreboardPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Event'),
            onTap: () {
              Navigator.pop(context); // Chiude il drawer
              event();
            },
          ),
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: const Text('Connect'),
            onTap: () {
              Navigator.pop(context); // Chiude il drawer
              if (userEmail != null) {
                showDialog(
                  context: context,
                  builder: (context) => ShareProfileDialog(email: userEmail),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email non disponibile')),
                );
              }
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color.fromRGBO(177, 233, 144, 1),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _handleRefresh();
          setState(() {
            enlargedImageIndex = null;
            isImageEnlarged = false;
          });
        },
        child: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'profile-image',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colorScheme.shadow.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  backgroundImage: profileImageUrl != null
                                      ? NetworkImage(profileImageUrl!)
                                      : null,
                                  child: profileImageUrl == null
                                      ? Icon(Icons.person,
                                          size: 40,
                                          color: colorScheme.onSurfaceVariant)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName ?? 'Unknown User',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color.fromRGBO(76, 175, 80, 1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${point ?? '0'} points',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                images.isNotEmpty
                    ? SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _handleImageTap(index),
                                      onLongPress: () =>
                                          _handleImageLongPress(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Image.network(
                                          images[index],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () =>
                                              _showDeleteDialog(context, index),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: images.length,
                          ),
                        ),
                      )
                    : SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessuna foto disponibile',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
            if (isImageEnlarged && enlargedImageIndex != null)
              GestureDetector(
                onTap: () => _handleImageTap(enlargedImageIndex!),
                child: Container(
                  color: colorScheme.scrim.withOpacity(0.9),
                  alignment: Alignment.center,
                  child: Hero(
                    tag: 'enlarged-image-${enlargedImageIndex!}',
                    child: Image.network(
                      images[enlargedImageIndex!],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 300,
        height: 60,
        child: FloatingActionButton(
          onPressed: onTabTapped,
          elevation: 4,
          backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(
            Icons.add_a_photo,
            size: 36,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 60,
        elevation: 0,
        color: colorScheme.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            SizedBox(width: 48),
            SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, int index) async {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Conferma eliminazione',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'Sei sicuro di voler eliminare questa foto?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annulla',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                showLoadingDialog("Photo Deletion");
                if (await _deletePhoto(images[index])) {
                  Navigator.of(_dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Foto eliminata con successo'),
                      backgroundColor: colorScheme.primaryContainer,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                Navigator.of(_dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
  }
}
