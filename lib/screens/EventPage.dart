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
  Map<int, bool> likedPhotos = {};
  List<dynamic> rankedPhotos = [];
  double? eventLatitude;
  double? eventLongitude;
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  String host = "event-production.up.railway.app";
  String? eventName;
  String? token;
  String? profileImageUrl;
  String? userName;
  String? point;
  Map<int, String> profileImages = {};

  @override
  void initState() {
    super.initState();
    _initializeEventPhotos();
  }

  Future<void> _initializeEventPhotos() async {
    await _name();
    await _loadEventPhotos();
    await _loadLikePhotos();
    await _fetchEventCoordinates();
    await _loadUserProfiles();
  }

  Future<void> _handleRefresh() async {
    try {
      await _name();
      await _loadEventPhotos();
      await _loadLikePhotos();
      await _fetchEventCoordinates();
      await _loadUserProfiles();
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
          initState();
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

  Future<void> _name() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://' + host + '/nameByCode');

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
    final url = Uri.parse('https://' + host + '/get_coordinate');

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

  Future<String> setPositionTrue(String eventCode) async {
    final url = Uri.parse('https://' + host + '/set_position_true');
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
  }

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
        backgroundColor: isError ? Colors.redAccent.shade200 : Colors.black87,
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
          message = await setPositionTrue(widget.eventCode);
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
    final url = Uri.parse('https://' + host + '/get_like');
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
    final url = Uri.parse('https://' + host + '/get_ranking');
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
    final url = Uri.parse('https://' + host + '/photoByCode');

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
        eventPhotos = List<Map<String, dynamic>>.from(data);
        likedPhotos = {};
        for (int i = 0; i < eventPhotos.length; i++) {
          likedPhotos[i] = false;
          final photoData = eventPhotos[i];
          usernamePhotos[i] = photoData['name'] ?? 'Unknown';
        }
      });
    } else {
      _checkTokenValidity(response.statusCode);
      throw Exception('Failed to load event photos');
    }
  }

  Future<void> _likePhoto(int index) async {
    final photoId = eventPhotos[index]['image_path'];
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://' + host + '/increment_like');
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

  Future<void> _loadUserProfiles() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://' + host + '/get_user_profiles');

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
          for (int i = 0; i < eventPhotos.length; i++) {
            if (i < data.length) {
              profileImages[i] = data[i]['image_path'] ?? '';
            } else {
              profileImages[i] = '';
            }
          }
        });
      } else {
        _checkTokenValidity(response.statusCode);
      }
    } catch (e) {
      print("Errore nel recuperare le immagini del profilo: $e");
    }
  }

  // Componente riutilizzabile per l'avatar del profilo
  Widget _buildProfileAvatar(int index) {
    final profileImage = profileImages[index];
    final username = usernamePhotos[index] ?? 'U';

    if (profileImage != null && profileImage.isNotEmpty) {
      return Container(
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
            profileImage,
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
      );
    }

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
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black54),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Caricamento foto...',
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
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 20,
                                color: likedPhotos[index] == true
                                    ? Colors.red
                                    : Colors.grey[400],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${eventPhotos[index]['likes'] ?? 0} likes',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
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
}
