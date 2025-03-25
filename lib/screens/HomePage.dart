import 'dart:async';
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
import 'package:social_flutter_giorgio/screens/SavedPhotosScreen.dart';
import 'package:social_flutter_giorgio/screens/SettingsPage.dart';
import 'package:social_flutter_giorgio/screens/ShareProfileDialog.dart';
import 'package:social_flutter_giorgio/screens/profile.dart';
import 'package:social_flutter_giorgio/screens/ScoreboardPage.dart';
import '../auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  File? _capturedImage;
  List<String> images = [];
  List<String> ids = [];
  List<String> points = [];
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
  int save = 0;
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  //String host = "event-production.up.railway.app";
  final String host = "www.event-fit.it";
  final TextEditingController _searchController = TextEditingController();
  late List<dynamic> profilesListSearch;
  late List<dynamic> imagesListSearch;
  late List<dynamic> emailsListSearch;
  bool isLoading = true;
  String id = "-1";

  int? enlargedImageIndex;
  bool isImageEnlarged = false;
  late BuildContext _dialogContext;

  @override
  void initState() {
    super.initState();
    _initializeData(true);
  }

  Future<void> _initializeData(bool loading) async {
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
      if (loading) {
        showLoadingDialog("Loading");
      }
      await fetchProfileData();
      await fetchImages();
      Navigator.of(_dialogContext).pop();
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

  /*void _handleImageTap(int index) {
    setState(() {
      if (enlargedImageIndex == index) {
        enlargedImageIndex = null;
        isImageEnlarged = false;
      } else if (isImageEnlarged) {
        enlargedImageIndex = null;
        isImageEnlarged = false;
      }
    });
  }*/

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
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

  Future<void> signOut() async {
    await Auth().signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
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
    try {
      var status = await Permission.camera.status;

      if (!status.isGranted) {
        if (mounted) {
          Navigator.of(_dialogContext).pop();
        }

        status = await Permission.camera.request();

        if (!status.isGranted) {
          if (mounted) {
            showDialogPermissionDenied();
          }
          return null;
        }
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        return File(pickedFile.path);
      } else {
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }

  void showDialogPermissionDenied() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Permesso Fotocamera"),
        content: const Text(
            "Per utilizzare questa funzione è necessario concedere i permessi della fotocamera."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Annulla",
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text(
              "Apri Impostazioni",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> uploadImage(File imageFile) async {
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
      final responseBody = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(responseBody);
      await _initializeData(true);
      if (context.mounted) {
        _showUploadSuccess(context, false);
      }
      return jsonResponse['id'].toString();
    } else {
      _showErrorSnackbar("Foto non caricata");
      _checkTokenValidity(response.statusCode);
      return "-1";
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
      }
    } catch (e) {
      print('Error: $e');
    }
    return null;
  }

  Future<String> uploadImageForEvent(String eventCode, String eventName) async {
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
          final responseBody = await response.stream.bytesToString();
          Map<String, dynamic> jsonResponse = json.decode(responseBody);
          await _initializeData(true);
          if (context.mounted) {
            _showUploadSuccess(context, false);
          }
          return jsonResponse['id'].toString();
        } else {
          if (response.statusCode == 403) {
            _showErrorSnackbar(
                "Foto non caricata sei troppo lontano dall'evento");
          } else {
            _checkTokenValidity(response.statusCode);
          }
          return "-1";
        }
      }
    } else if (permission.isDenied) {
    } else if (permission.isPermanentlyDenied) {
      openAppSettings();
    }
    return "-1";
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Crea un overlay che scende dall'alto
      final overlay = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 300,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Inserisce l'overlay
      Overlay.of(context).insert(overlay);

      // Rimuove l'overlay dopo 3 secondi
      Future.delayed(const Duration(seconds: 3), () {
        overlay.remove();
      });
    });
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

  Future<String> showEventsDialog(List<dynamic> events) async {
    final completer = Completer<String>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        completer.complete(
                            "-1"); // Complete with error code if closed
                      },
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
                                      Navigator.of(dialogContext)
                                          .pop(); // Close events dialog first

                                      showLoadingDialog("Loading");
                                      final result = await uploadImageForEvent(
                                          events[i], eventName);

                                      if (_dialogContext.mounted) {
                                        Navigator.of(_dialogContext)
                                            .pop(); // Dismiss loading dialog

                                        if (result == "-1") {
                                          _showErrorSnackbar(
                                              "Foto non caricata sei troppo lontano dall'evento");
                                        } else {
                                          _showUploadSuccess(
                                              _dialogContext, true);
                                        }
                                      }

                                      completer.complete(result);
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

    return completer.future;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // Chiude qualsiasi SnackBar correntemente visualizzato
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Crea un overlay che scende dall'alto
        final overlay = OverlayEntry(
          builder: (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          withEvent
                              ? 'Foto caricata nell\'evento con successo!'
                              : 'Foto caricata con successo',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Inserisce l'overlay
        Overlay.of(context).insert(overlay);

        // Rimuove l'overlay dopo 3 secondi
        Future.delayed(const Duration(seconds: 3), () {
          overlay.remove();
        });
      }
    });
  }

  Future<String> _showEventSelectionDialog(
      List<dynamic> events, File image) async {
    final completer = Completer<String>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _dialogContext = dialogContext;

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

                        showLoadingDialog("Loading");
                        final eventId = await showEventsDialog(events);
                        if (_dialogContext.mounted) {
                          Navigator.of(_dialogContext)
                              .pop(); // Dismiss loading dialog
                        }

                        completer.complete(eventId);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildButton(
                      "Carica senza evento",
                      color: Colors.grey,
                      outlined: true,
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();

                        showLoadingDialog("Loading");
                        final uploadId = await uploadImage(image);
                        if (_dialogContext.mounted) {
                          Navigator.of(_dialogContext).pop();
                          _showUploadSuccess(_dialogContext, false);
                        }

                        completer.complete(uploadId);
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

    return completer.future;
  }

  Future<String> _uploadImageWithoutEvent(File image) async {
    showLoadingDialog("Caricamento foto...");
    id = await uploadImage(image);
    Navigator.of(_dialogContext).pop();
    if (context.mounted) {
      _showUploadSuccess(context, false);
    }
    return id;
  }

  Future<void> uploadDetails(String id, String brand, String type,
      String feedback, String model) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://$host/uploadInfo'),
      );

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      request.fields['id'] = id;
      request.fields['brand'] = brand;
      request.fields['type'] = type;
      request.fields['feedback'] = feedback;
      request.fields['model'] = model;

      request.headers.addAll(headers);

      var response = await request.send();

      if (response.statusCode == 200) {
        _showTopSnackBar(context, 'Dettagli caricati con successo',
            isSuccess: true);
      } else {
        _checkTokenValidity(response.statusCode);
        _showTopSnackBar(context, 'Errore nei Dettagli', isSuccess: false);
        _showOutfitDetailsSheet(id);
      }
    } catch (e) {
      _showOutfitDetailsSheet(id);
    }
  }

  void _showTopSnackBar(BuildContext context, String message,
      {bool isSuccess = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // Chiude qualsiasi overlay correntemente visualizzato
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Crea un overlay che scende dall'alto
        final overlay = OverlayEntry(
          builder: (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Inserisce l'overlay
        Overlay.of(context).insert(overlay);

        // Rimuove l'overlay dopo 3 secondi
        Future.delayed(const Duration(seconds: 3), () {
          if (overlay.mounted) {
            overlay.remove();
          }
        });
      }
    });
  }

  Future<void> _uploadAllItems(
      Map<String, Map<String, String>> itemsDetails, String id) async {
    String item = "";
    try {
      // Carica ogni item
      for (var entry in itemsDetails.entries) {
        item = entry.key;
        await uploadDetails(
          id,
          entry.value['store'] ?? '', // brand
          entry.key, // type
          entry.value['feedback'] ?? '',
          entry.value['model'] ?? '',
        );
      }

      // Mostra un messaggio di successo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tutti i capi sono stati caricati con successo')),
      );
    } catch (e) {
      // Mostra l'errore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Errore durante il caricamento dei dettagli per $item')),
      );
    }
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
                    onTap: () async {
                      Navigator.pop(context);
                      id = await _processGalleryImage();
                      print(id);
                      if (id != "-1") {
                        _showOutfitDetailsSheet(id);
                        id = "-1";
                      }
                    },
                  ),
                  _buildOptionButton(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Fotocamera',
                    onTap: () async {
                      Navigator.pop(context);
                      id = await _processCameraImage();
                      if (id != "-1") {
                        _showOutfitDetailsSheet(id);
                        id = "-1";
                      }
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

  void _showOutfitDetailsSheet(String id) {
    final formKey = GlobalKey<FormState>();
    Set<String> selectedTypes = {};
    bool isFirstStep = true;
    bool isItemDetails = false;
    String? currentItem;

    Map<String, Map<String, String>> itemsDetails = {};
    final List<Map<String, dynamic>> clothingTypes = [
      {'id': 'shirt', 'icon': FontAwesomeIcons.shirt, 'label': 'Maglietta'},
      {'id': 'pants', 'icon': Icons.checkroom, 'label': 'Pantaloni'},
      {'id': 'dress', 'icon': FontAwesomeIcons.person, 'label': 'Vestito'},
      {'id': 'shoes', 'icon': FontAwesomeIcons.shoePrints, 'label': 'Scarpe'},
      {'id': 'hat', 'icon': FontAwesomeIcons.hatCowboy, 'label': 'Cappello'},
      {'id': 'accessory', 'icon': FontAwesomeIcons.gem, 'label': 'Accessorio'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Widget buildTypeSelection() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Seleziona i capi del tuo outfit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: clothingTypes.length,
                    itemBuilder: (context, index) {
                      final type = clothingTypes[index];
                      final isSelected = selectedTypes.contains(type['id']);
                      final hasDetails = itemsDetails.containsKey(type['id']);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedTypes.remove(type['id']);
                              itemsDetails.remove(type['id']);
                            } else {
                              selectedTypes.add(type['id']);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    type['icon'],
                                    size: 32,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[700],
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: -5,
                                      top: -5,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: hasDetails
                                              ? Colors.green
                                              : Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          hasDetails ? Icons.check : Icons.add,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                type['label'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Pulsante Salva spostato qui, subito dopo la griglia
                  if (selectedTypes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton(
                        onPressed: itemsDetails.length == selectedTypes.length
                            ? () async {
                                if (id != "-1") {
                                  Navigator.pop(context);
                                  await _uploadAllItems(itemsDetails, id);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Salva outfit (${itemsDetails.length}/${selectedTypes.length} dettagli inseriti)',
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (selectedTypes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const Text(
                            'Capi selezionati:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...clothingTypes
                              .where(
                                  (type) => selectedTypes.contains(type['id']))
                              .map((type) {
                            final hasDetails =
                                itemsDetails.containsKey(type['id']);
                            return ListTile(
                              leading: Icon(type['icon']),
                              title: Text(type['label']),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    currentItem = type['id'];
                                    isItemDetails = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      hasDetails ? Colors.green : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                child: Text(hasDetails
                                    ? 'Modifica'
                                    : 'Aggiungi dettagli'),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              );
            }

            Widget buildItemDetailsForm() {
              final currentType =
                  clothingTypes.firstWhere((type) => type['id'] == currentItem);
              final details = itemsDetails[currentItem] ?? {};
              final storeController =
                  TextEditingController(text: details['store'] ?? '');
              final modelController =
                  TextEditingController(text: details['model'] ?? '');
              final feedbackController =
                  TextEditingController(text: details['feedback'] ?? '');

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(currentType['icon']),
                          const SizedBox(width: 10),
                          Text(
                            'Dettagli ${currentType['label']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: storeController,
                        decoration: InputDecoration(
                          labelText: 'Brand',
                          prefixIcon: const Icon(Icons.store),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Inserisci il nome del Brand';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: modelController,
                        decoration: InputDecoration(
                          labelText: 'Modello/Collezione',
                          prefixIcon: const Icon(Icons.label),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: feedbackController,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: 'Feedback',
                          prefixIcon: const Icon(Icons.comment),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isItemDetails = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Indietro'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  setState(() {
                                    itemsDetails[currentItem!] = {
                                      'store': storeController.text,
                                      'model': modelController.text,
                                      'feedback': feedbackController.text,
                                    };
                                    isItemDetails = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Salva'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: isItemDetails
                      ? buildItemDetailsForm()
                      : buildTypeSelection(),
                ),
              ),
            );
          },
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

  Future<String> _processCameraImage() async {
    try {
      var status = await Permission.camera.status;

      if (!status.isGranted) {
        status = await Permission.camera.request();

        if (!status.isGranted) {
          if (mounted) {
            showDialogPermissionDenied();
          }
          return id;
        }
      }

      if (mounted) {
        showLoadingDialog("Apertura fotocamera...");
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (mounted) {
        Navigator.of(_dialogContext).pop();
      }
      if (pickedFile != null) {
        File image = File(pickedFile.path);
        return await _processSelectedImage(image);
      } else {
        return id;
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(_dialogContext).pop();
        } catch (navError) {
          print("Errore nel chiudere il dialogo: $navError");
        }
      }

      if (mounted) {
        _showErrorSnackbar("Si è verificato un errore con la fotocamera");
      }

      return id;
    }
  }

  Future<String> _processGalleryImage() async {
    bool isDialogOpen = false;

    try {
      isDialogOpen = true;
      showLoadingDialog("Apertura galleria...");
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (isDialogOpen) {
        Navigator.of(_dialogContext).pop();
        isDialogOpen = false;
      }
      if (pickedFile != null) {
        File image = File(pickedFile.path);
        id = await _processSelectedImage(image);
        return id;
      } else {
        return id;
      }
    } catch (e) {
      if (isDialogOpen) {
        Navigator.of(_dialogContext).pop();
        isDialogOpen = false;
      }
      _showErrorSnackbar("Si è verificato un errore con la galleria");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );

      return id;
    }
  }

  Future<String> _processSelectedImage(File image) async {
    try {
      setState(() {
        _capturedImage = image;
      });

      showLoadingDialog("Verifica eventi...");
      final isEnrolledInEvents = await checkUserEvents();
      Navigator.of(_dialogContext).pop();

      if (isEnrolledInEvents != null && isEnrolledInEvents.isNotEmpty) {
        id = await _showEventSelectionDialog(isEnrolledInEvents, image);
        return id;
      } else {
        id = await _uploadImageWithoutEvent(image);
        return id;
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorSnackbar("Si è verificato un errore");
      return id;
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
          images.clear();
          ids.clear();
          points.clear();
          setState(() {
            for (var image in data['images']) {
              images.add(image['url']);
              ids.add(image['id'].toString());
              points.add(image['point'].toString());
            }
          });
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
            save = data['save'];
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
          SnackBar(
            content: Text('Foto eliminata con successo'),
            backgroundColor: Colors.green,
          ),
        );
        await _initializeData(true);
        return true;
      } else {
        _checkTokenValidity(response.statusCode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: impossibile eliminare la foto'),
            backgroundColor: Colors.red,
          ),
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
    _searchController.clear();
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

        throw Exception("Errore durante la ricerca");
      }
    } catch (e) {
      throw Exception("Errore di connessione");
    }
  }

  void _showSearchResultsDialog(List emails, List profiles, List images) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Bordo arrotondato
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titolo con divider
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Profili',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),

                // Lista dei risultati
                SizedBox(
                  height: 300, // Altezza fissa per evitare problemi di overflow
                  child: ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (images.isNotEmpty &&
                                  images[index] != null &&
                                  images[index].isNotEmpty)
                              ? NetworkImage(images[index])
                              : null,
                          child: (images.isEmpty ||
                                  images[index] == null ||
                                  images[index].isEmpty)
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          profiles[index],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
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

                const Divider(),

                // Pulsante Chiudi
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Chiudi'),
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
            icon: Icon(Icons.menu, color: Color.fromRGBO(0, 0, 0, 1)),
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
                        color: Color.fromRGBO(0, 0, 0, 1),
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
            leading: const Icon(Icons.save),
            title: const Text('Save'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SavedPhotosScreen(),
                  fullscreenDialog: false,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: const Text('Connect'),
            onTap: () {
              Navigator.pop(context);
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
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(),
                  fullscreenDialog: false,
                ),
              );
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
                                  child: GestureDetector(
                                    /*onLongPress: () {
                                      // Mostra un dialogo o un bottom sheet per cambiare la foto
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: Icon(Icons.photo_camera),
                                              title: Text('Scatta una foto'),
                                              onTap: () {
                                                // Logica per scattare una foto
                                                Navigator.pop(context);
                                              },
                                            ),
                                            ListTile(
                                              leading:
                                                  Icon(Icons.photo_library),
                                              title:
                                                  Text('Scegli dalla galleria'),
                                              onTap: () {
                                                // Logica per scegliere dalla galleria
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },*/
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
                                              color:
                                                  colorScheme.onSurfaceVariant)
                                          : null,
                                    ),
                                  )),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    /*onLongPress: () {
                                      // Show dialog to edit username
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          String newUsername =
                                              userName ?? 'Unknown User';
                                          return AlertDialog(
                                            title: Text(
                                                'Vuoi modificare il tuo username'),
                                            content: TextField(
                                              autofocus: true,
                                              controller: TextEditingController(
                                                  text: newUsername),
                                              onChanged: (value) {
                                                newUsername = value;
                                              },
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  updateUsername(newUsername);
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Save'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },*/
                                    child: Text(
                                      userName ?? 'Unknown User',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromRGBO(
                                              76, 175, 80, 0.9),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 4),
                                            Text(
                                              '${point ?? '0'} points',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromRGBO(
                                              33, 150, 243, 0.9),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$save save',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                images.isNotEmpty
                    ? SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          _handleImageTap(index);
                                          /*setState(() {
                                            enlargedImageIndex = index;
                                            isImageEnlarged = true;
                                          });*/
                                          //_showFullScreenImage(images[index]);
                                        },
                                        /*onLongPress: () =>
                                            _handleImageLongPress(index),*/
                                        child: Container(
                                          width: double.infinity,
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
                                    ),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Punteggio con stella
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                points[index].toString(),
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Pulsanti delete e save
                                          Row(
                                            children: [
                                              // Pulsante Delete
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  onTap: () =>
                                                      _showDeleteDialog(
                                                          context, index),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.black,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Pulsante Save
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  onTap: () =>
                                                      savePhoto(ids[index]),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: const Icon(
                                                      Icons.save,
                                                      color: Colors.black,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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

  Future<void> _handleImageTap(int index) async {
    try {
      setState(() {
        enlargedImageIndex = index;
        isImageEnlarged = true;
      });

      bool isLoading = true;
      bool hasDetails = false;
      Map<String, dynamic>? photoData;
      AnimationController? animationController;

      try {
        final response = await http.get(
          Uri.parse('https://$host/infoPhoto?id_photo=${ids[index]}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] && data['data']?.isNotEmpty == true) {
            hasDetails = true;
            photoData = data;
          }
        } else {
          _checkTokenValidity(response.statusCode);
        }
      } catch (e) {
        print('Error fetching photo details: $e');
      } finally {
        isLoading = false;
      }

      if (hasDetails) {
        animationController = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: this,
        )..repeat(reverse: true);
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          bool showSwipeIndicator = hasDetails;
          bool isDetailsLoading = false;
          double totalDragDistance = 0.0;

          if (hasDetails) {
            Future.delayed(const Duration(seconds: 5), () {
              if (dialogContext.mounted) {
                showSwipeIndicator = false;
                (dialogContext as Element).markNeedsBuild();
              }
            });
          }

          final animation = hasDetails && animationController != null
              ? Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(0, -0.5),
                ).animate(CurvedAnimation(
                  parent: animationController,
                  curve: Curves.easeInOut,
                ))
              : null;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(
                          dialogContext), // Chiusura solo con tap sull'immagine
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(80),
                        minScale: 0.5,
                        maxScale: 4,
                        child: Container(
                          color: Colors.black.withOpacity(0.9),
                          child: Center(
                            child: Image.network(
                              images[index],
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                return loadingProgress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator());
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasDetails)
                      GestureDetector(
                        onVerticalDragUpdate: (details) {
                          totalDragDistance += details.primaryDelta!;
                        },
                        onVerticalDragEnd: (details) async {
                          if (totalDragDistance < -50 && photoData != null) {
                            setDialogState(() => isDetailsLoading = true);
                            await showModalBottomSheet(
                              context: dialogContext,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => StatefulBuilder(
                                builder: (context, setBottomSheetState) {
                                  Future.delayed(
                                      const Duration(milliseconds: 500), () {
                                    if (context.mounted) {
                                      setBottomSheetState(
                                          () => isDetailsLoading = false);
                                      setDialogState(
                                          () => isDetailsLoading = false);
                                    }
                                  });

                                  return Container(
                                    height: MediaQuery.of(context).size.height *
                                        0.7,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black12,
                                            spreadRadius: 1,
                                            blurRadius: 10)
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 12),
                                              width: 40,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.all(20),
                                              child: Text(
                                                'Dettagli Foto',
                                                style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView.builder(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20),
                                                itemCount:
                                                    photoData!['data'].length,
                                                itemBuilder: (context, idx) =>
                                                    Card(
                                                  elevation: 2,
                                                  margin: const EdgeInsets.only(
                                                      bottom: 16),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            'Tipo: ${photoData!['data'][idx]['type'] ?? 'N/A'}'),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            'Marca: ${photoData!['data'][idx]['brand'] ?? 'N/A'}'),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            'Modello: ${photoData!['data'][idx]['model'] ?? 'N/A'}'),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            'Feedback: ${photoData!['data'][idx]['feedback'] ?? 'N/A'}'),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isDetailsLoading)
                                          Container(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                          totalDragDistance = 0.0;
                        },
                        behavior: HitTestBehavior.translucent,
                      ),
                    if (showSwipeIndicator && hasDetails && animation != null)
                      Positioned(
                        bottom: 40,
                        child: SlideTransition(
                          position: animation,
                          child: Column(
                            children: const [
                              Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white, size: 36),
                              SizedBox(height: 4),
                              Text(
                                'Scorri verso l\'alto per i dettagli',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isLoading)
                      const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                    // Rimosso il pulsante "X" (IconButton con Icons.close)
                  ],
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      print('Error in _handleImageTap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore durante l\'operazione'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isImageEnlarged = false;
          enlargedImageIndex = -1;
        });
      }
    }
  }

  Future<void> updateUsername(String newUsername) async {
    final uri = Uri.parse('https://$host/update_username');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newUserName': newUsername}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nome modificato con successo'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nome non modificato'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      content: Text('Foto eliminata con successo'),
                      backgroundColor: Colors.green,
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

  Future<void> savePhoto(String idPhoto) async {
    try {
      final uri = Uri.parse('https://$host/salvePhoto?id_photo=$idPhoto');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Controlla lo status code
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Decodifica la risposta per mostrare un messaggio più specifico
        final Map<String, dynamic> data = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Foto salvata con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Controlla se è un problema di token
        _checkTokenValidity(response.statusCode);

        // Mostra errore specifico se disponibile nella risposta
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          throw Exception(
              errorData['message'] ?? 'Errore durante il salvataggio');
        } catch (e) {
          throw Exception(
              'Errore durante il salvataggio: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Registra l'errore e mostra un messaggio all'utente
      print("Errore durante la chiamata API: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile salvare la foto. Riprova più tardi.'),
          backgroundColor: Colors.red,
        ),
      );

      throw Exception("Impossibile connettersi all'API.");
    }
  }
}
