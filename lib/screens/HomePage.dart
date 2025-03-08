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

class _HomepageState extends State<Homepage> {
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
  String host = "event-production.up.railway.app";
  //final String host = "event-fit.it";
  final TextEditingController _searchController = TextEditingController();
  late List<dynamic> profilesListSearch;
  late List<dynamic> imagesListSearch;
  late List<dynamic> emailsListSearch;
  bool isLoading = true;
  int count = 0;
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    userEmail = prefs.getString('email');

    try {
      if (token != null) {
        if (loading) {
          showLoadingDialog("Loading");
        }
        await fetchProfileData();
        await fetchImages();
        Navigator.of(_dialogContext).pop();
      } else {
        prefs.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      return File(pickedFile.path);
    } else {
      return null;
    }
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
      return jsonResponse['id'].toString();
    } else {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
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

  Future<String> _showEventSelectionDialog(
      List<dynamic> events, File image) async {
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
                        id = await uploadImage(image);
                        if (context.mounted) {
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
    return id;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dettagli caricati con successo')),
        );
      } else {
        _checkTokenValidity(response.statusCode);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nei Dettagli')),
        );
        _showOutfitDetailsSheet(id);
      }
    } catch (e) {
      _showOutfitDetailsSheet(id);
    }
  }

  Future<void> _uploadAllItems(
      Map<String, Map<String, String>> itemsDetails, String id) async {
    try {
      // Mostra un indicatore di caricamento
      /*showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );*/

      // Carica ogni item
      for (var entry in itemsDetails.entries) {
        await uploadDetails(
          id,
          entry.value['store'] ?? '', // brand
          entry.key, // type
          entry.value['feedback'] ?? '',
          entry.value['model'] ?? '',
        );
      }

      // Chiudi l'indicatore di caricamento
      //Navigator.pop(context);

      // Mostra un messaggio di successo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tutti i capi sono stati caricati con successo')),
      );
    } catch (e) {
      // Chiudi l'indicatore di caricamento in caso di errore
      //Navigator.pop(context);

      // Mostra l'errore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento: $e')),
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
                      _showOutfitDetailsSheet(id);
                    },
                  ),
                  _buildOptionButton(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Fotocamera',
                    onTap: () async {
                      Navigator.pop(context);
                      id = await _processCameraImage();
                      _showOutfitDetailsSheet(id);
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
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: itemsDetails.length ==
                                    selectedTypes.length
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
      showLoadingDialog("Apertura fotocamera...");
      final image = await takePicture();
      Navigator.of(_dialogContext).pop();

      if (image != null) {
        return await _processSelectedImage(image);
      } else {
        return id;
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore con la fotocamera: $e");
      return id;
    }
  }

  Future<String> _processGalleryImage() async {
    try {
      showLoadingDialog("Apertura galleria...");
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      Navigator.of(_dialogContext).pop();

      if (pickedFile != null) {
        File image = File(pickedFile.path);
        id = await _processSelectedImage(image);
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore con la galleria: $e");
    }
    return id;
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
        return await _showEventSelectionDialog(isEnrolledInEvents, image);
      } else {
        return await _uploadImageWithoutEvent(image);
      }
    } catch (e) {
      Navigator.of(_dialogContext).pop();
      _showErrorDialog("Si è verificato un errore: $e");
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
          for (var image in data['images']) {
            images.add(image['url']);
            ids.add(image['id'].toString());
            points.add(image['point'].toString());
          }
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
              Navigator.pop(context); // Chiude il drawer
              showDialog(
                context: context,
                builder: (context) => SavedPhotosScreen(),
              );
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
                                          setState(() {
                                            enlargedImageIndex = index;
                                            isImageEnlarged = true;
                                          });
                                          //_showFullScreenImage(images[index]);
                                        },
                                        onLongPress: () =>
                                            _handleImageLongPress(index),
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

  Future<void> _handleImageLongPress(int index) async {
    setState(() {
      enlargedImageIndex = index;
      isImageEnlarged = true;
    });

    try {
      String id = ids[index];
      final response = await http.get(
        Uri.parse('https://$host/infoPhoto?id_photo=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (BuildContext context) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Dettagli Foto',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemCount: data['data'].length,
                        itemBuilder: (context, index) {
                          final item = data['data'][index];
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('Tipo', item['type']),
                                  SizedBox(height: 8),
                                  _buildInfoRow('Marca', item['brand']),
                                  SizedBox(height: 8),
                                  _buildInfoRow('Modello', item['model']),
                                  SizedBox(height: 8),
                                  _buildInfoRow('Feedback', item['feedback']),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception('Failed to load photo info');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non ci sono dettagli disponibili'),
          backgroundColor: Colors.red,
        ),
      );
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
