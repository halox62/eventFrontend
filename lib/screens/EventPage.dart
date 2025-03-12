import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
import 'package:social_flutter_giorgio/screens/HomePage.dart';
import 'package:social_flutter_giorgio/screens/profile.dart';

class EventPageControl extends StatefulWidget {
  final String eventCode;

  const EventPageControl({Key? key, required this.eventCode}) : super(key: key);

  @override
  EventPage createState() => EventPage();
}

class EventPage extends State<EventPageControl> {
  String? userEmail;
  List<dynamic> eventPhotos = [];
  Map<int, String> usernamePhotos = {};
  Map<int, String> userPhotos = {};
  Map<int, bool> likedPhotos = {};
  List<dynamic> rankedPhotos = [];
  Map<int, String> points = {};
  double? eventLatitude;
  double? eventLongitude;
  int? enlargedImageIndex;
  bool isImageEnlarged = false;
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  String host = "event-production.up.railway.app";
  //final String host = "event-fit.it";
  String? eventName;
  String? token;
  String? profileImageUrl;
  String? userName;
  String? point;
  Map<int, String> profileImages = {};
  BuildContext? _dialogContext;
  late String endTime;
  late String startDate;
  DateTime? eventEndTime;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeEventPhotos(true);
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

  Future<void> _initializeEventPhotos(bool loading) async {
    try {
      await _name();
      if (eventEndTime == null) {
        throw Exception('Event time not initialized');
      }
      if (_isEventStarted()) {
        _showEventCountdown();
      } else {
        if (loading) {
          showLoadingDialog("Caricamento Eventi");
        }

        await _loadEventPhotos();
        await _loadLikePhotos();
        await _fetchEventCoordinates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessuna informazione disponibile'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (_dialogContext != null && mounted) {
        Navigator.of(_dialogContext!).pop();
      }
    }
  }

  bool _isEventStarted() {
    return DateTime.now().isBefore(eventEndTime!);
  }

  void _showEventCountdown() {
    if (eventEndTime == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _countdownTimer?.cancel();

            _countdownTimer =
                Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!context.mounted) {
                timer.cancel();
                return;
              }

              setState(() {});

              final now = DateTime.now();
              if (now.isAfter(eventEndTime!)) {
                timer.cancel();

                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      _initializeEventPhotos(true);
                    }
                  });
                }
              }
            });

            final difference = eventEndTime!.difference(DateTime.now());
            final formattedEndTime =
                "${eventEndTime!.hour.toString().padLeft(2, '0')}:${eventEndTime!.minute.toString().padLeft(2, '0')}";

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "L'evento non è ancora iniziato",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Inizio evento previsto: $formattedEndTime",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CountdownUnit(
                          value: difference.inHours,
                          unit: "Ore",
                        ),
                        _CountdownSeparator(),
                        _CountdownUnit(
                          value: difference.inMinutes % 60,
                          unit: "Minuti",
                        ),
                        _CountdownSeparator(),
                        _CountdownUnit(
                          value: difference.inSeconds % 60,
                          unit: "Secondi",
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Homepage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Torna alla Home",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _countdownTimer?.cancel();
    });
  }

  Future<void> _handleRefresh() async {
    try {
      _initializeEventPhotos(true);
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
          _initializeEventPhotos(false);
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

  Future<void> _name() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/nameByCode');

    try {
      final body = jsonEncode({
        'code': widget.eventCode,
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        eventName = data['name'];
        endTime = data['EndTime'];
        startDate = data['startDate'];
        final timeParts = endTime.split(':');
        final DateParts = startDate.split("-");
        eventEndTime = DateTime(
          int.parse(DateParts[0]),
          int.parse(DateParts[1]),
          int.parse(DateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception('Failed to load event coordinates');
      }
    } catch (e) {
      print("Errore nel recuperare le coordinate dell'evento: $e");
    }
  }

  Future<void> _fetchEventCoordinates() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/get_coordinate');

    try {
      final body = jsonEncode({
        'code': widget.eventCode,
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

  /*Future<String> setPositionTrue(String eventCode) async {
    final url = Uri.parse('https://$host/set_position_true');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'eventCode': eventCode,
    });

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return 'Posizione ok';
    } else {
      _checkTokenValidity(response.statusCode);
      return 'Errore nella verifica della posizionecl';
    }
  }*/

  void showCustomSnackbar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent.shade200 : Colors.green,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        duration: const Duration(seconds: 4),
        animation: CurvedAnimation(
          parent: const AlwaysStoppedAnimation(1),
          curve: Curves.easeOutCirc,
        ),
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white70,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _checkUserProximity() async {
    String message;
    if (eventLatitude == null || eventLongitude == null) {
      return;
    }
    try {
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

        // Controlla se la distanza è entro 1 km
        if (distance <= 1000) {
          //message = await setPositionTrue(widget.eventCode);
          message = "Posizione ok";
          showCustomSnackbar(context, message);
        } else {
          message = 'Sei troppo lontano dall\'evento';
          showCustomSnackbar(context, message, isError: true);
        }
      } else if (permission.isDenied) {
        // Il permesso è stato negato
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homepage()),
        );
      } else if (permission.isPermanentlyDenied) {
        // Il permesso è stato negato in modo permanente, apri le impostazioni dell'app
        openAppSettings();
      }
    } catch (e) {
      print("Errore nel recuperare la posizione: $e");
    }
  }

  Future<void> _loadLikePhotos() async {
    final url = Uri.parse('https://$host/get_like');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      url,
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> LikeUserPhotos = List<Map<String, dynamic>>.from(data);

      final likePhotoMap = {
        for (var photo in LikeUserPhotos) photo['image_path']: true
      };

      setState(() {
        for (int j = 0; j < eventPhotos.length; j++) {
          likedPhotos[j] = likePhotoMap[eventPhotos[j]['image_path']] ?? false;
        }
      });
    } else if (response.statusCode == 404) {
      setState(() {
        likedPhotos = {for (int i = 0; i < eventPhotos.length; i++) i: false};
      });
    } else {
      _checkTokenValidity(response.statusCode);
      throw Exception('Failed to load liked photos');
    }
  }

  Future<void> _showRanking() async {
    final url = Uri.parse('https://$host/get_ranking');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'eventCode': widget.eventCode}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        rankedPhotos = data['photos'];
      });
    } else {
      var errorData = jsonDecode(response.body);
      _checkTokenValidity(errorData['msg']);
      throw Exception('Failed to load ranking');
    }
  }

  Future<void> _loadEventPhotos() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/photoByCode');

    final body = jsonEncode({
      'code': widget.eventCode,
    });

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is List && data.isNotEmpty) {
          setState(() {
            eventPhotos = List<Map<String, dynamic>>.from(data);
            likedPhotos = {};
            for (int i = 0; i < eventPhotos.length; i++) {
              likedPhotos[i] = false;
              final photoData = eventPhotos[i];
              usernamePhotos[i] = photoData['name'] ?? 'Unknown';
              profileImages[i] = photoData['image_profile'] ?? 'Unknown';
              userPhotos[i] = photoData['email'] ?? 'Unknown';
              points[i] = photoData['point']?.toString() ?? '0';
            }
          });
        } else {
          setState(() {
            eventPhotos = [];
          });
        }
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception('Failed to load event photos: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in _loadEventPhotos: $e');
    }
  }

  Future<void> _likePhoto(int index) async {
    final photoId = eventPhotos[index]['image_path'];
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/increment_like');
    final body = jsonEncode({'photoId': photoId});

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      setState(() {
        eventPhotos[index]['likes'] = (eventPhotos[index]['likes'] ?? 0) + 1;
        likedPhotos[index] = true;
      });
      print('Mi piace aggiunto con successo');
    } else {
      var errorData = jsonDecode(response.body);
      _checkTokenValidity(errorData['msg']);
      print('Errore nell\'aggiungere il mi piace');
    }
  }

  // Componente riutilizzabile per l'avatar del profilo
  Widget _buildProfileAvatar(int index) {
    final profileImage = profileImages[index];
    final username = usernamePhotos[index] ?? 'U';
    final email = userPhotos[index] ?? 'U';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(email: email),
          ),
        );
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            profileImage ?? '',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 32,
                height: 32,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Evento ${eventName ?? ''}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.black87),
            onPressed: () async {
              await _showRanking();
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Classifica',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.emoji_events, color: Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: rankedPhotos.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Nessuna foto in classifica',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: rankedPhotos.length,
                                  itemBuilder: (context, index) {
                                    final photo = rankedPhotos[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(8),
                                        leading: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            photo['image_path'],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              '#${index + 1}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: index < 3
                                                    ? Colors.amber
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.favorite,
                                                  size: 16,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${photo['likes']}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_pin, color: Colors.black87),
            onPressed: () async {
              await _fetchEventCoordinates();
              await _checkUserProximity();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.black87,
        backgroundColor: Colors.white,
        strokeWidth: 2,
        child: eventPhotos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 16),
                          Text(
                            'Nessuna Foto',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: eventPhotos.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _buildProfileAvatar(index),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  usernamePhotos[index] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onDoubleTap: () async {
                            if (likedPhotos[index] != true) {
                              await _likePhoto(index);
                            }
                          },
                          onLongPress: () => _handleImageLongPress(index),
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.width,
                            ),
                            child: Stack(
                              children: [
                                Image.network(
                                  eventPhotos[index]['image_path'],
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      height: MediaQuery.of(context).size.width,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Colors.black54),
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  (loadingProgress
                                                          .expectedTotalBytes ??
                                                      1)
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (BuildContext context,
                                      Object error, StackTrace? stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: Icon(
                                          Icons.error_outline,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (likedPhotos[index] == true)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 360,
                          right: 8,
                          left: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: likedPhotos[index] == true
                                        ? Colors.red
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${eventPhotos[index]['likes'] ?? 0} likes',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize
                                    .min, // Mantiene gli elementi compatti
                                children: [
                                  // Pulsante Preferito
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => savePhoto(index),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 20,
                                            ),
                                          ),
                                          Text(
                                            (points.isNotEmpty &&
                                                        index < points.length
                                                    ? points[index]
                                                    : '0')
                                                .toString(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => savePhoto(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.save,
                                          color: Colors.white,
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
      String id = eventPhotos[index]["id"].toString();
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
          content: Text('Nessun dettaglio disponibile'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> savePhoto(int index) async {
    try {
      String idPhoto = eventPhotos[index]["id"].toString();
      final uri = Uri.parse('https://$host/salvePhoto?id_photo=$idPhoto');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Foto salvata con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _checkTokenValidity(response.statusCode);
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

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String unit;

  const _CountdownUnit({
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit,
          style: TextStyle(
            color: Colors.black87.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ":",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
