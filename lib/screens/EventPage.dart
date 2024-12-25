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
  String host = "10.0.2.2:5000";
  String? eventName;
  String? token;

  Future<void> _initializeEventPhotos() async {
    await _name();
    await _loadEventPhotos();
    await _loadLikePhotos();
    await _fetchEventCoordinates();
  }

  @override
  void initState() {
    super.initState();
    _initializeEventPhotos();
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
    final url = Uri.parse('http://' + host + '/nameByCode');

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
    final url = Uri.parse('http://' + host + '/get_coordinate');

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
    final url = Uri.parse('http://' + host + '/set_position_true');
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
        } else {
          message = 'Sei troppo lontano dall\'evento';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
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
    final url = Uri.parse('http://' + host + '/get_like');
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
    final url = Uri.parse('http://' + host + '/get_ranking');
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
    final url = Uri.parse('http://' + host + '/photoByCode');

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
    final url = Uri.parse('http://' + host + '/increment_like');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evento $eventName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () async {
              await _showRanking();
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    child: rankedPhotos.isEmpty
                        ? const Center(
                            child: Text('Nessuna foto in classifica'))
                        : ListView.builder(
                            itemCount: rankedPhotos.length,
                            itemBuilder: (context, index) {
                              final photo = rankedPhotos[index];
                              return ListTile(
                                leading: Image.network(
                                  photo['image_path'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                                title: Text('${photo['likes']} likes'),
                              );
                            },
                          ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_pin),
            onPressed: () async {
              await _fetchEventCoordinates();
              await _checkUserProximity();
            },
          ),
        ],
      ),
      body: eventPhotos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 1,
              ),
              itemCount: eventPhotos.length,
              itemBuilder: (BuildContext context, int index) {
                return GestureDetector(
                  onDoubleTap: () async {
                    if (likedPhotos[index] != true) {
                      await _likePhoto(index);
                    }
                  },
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: MediaQuery.of(context).size.width,
                                child: Image.network(
                                  eventPhotos[index]['image_path'],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
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
                                    );
                                  },
                                  errorBuilder: (BuildContext context,
                                      Object error, StackTrace? stackTrace) {
                                    return const Center(
                                        child: Text(
                                            'Errore nel caricamento dell\'immagine'));
                                  },
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  color: Colors.black.withOpacity(0.6),
                                  child: Text(
                                    usernamePhotos[index] ??
                                        'Sconosciuto', // Usa un valore di fallback se nullo
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              if (likedPhotos[index] == true)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child:
                                      Icon(Icons.favorite, color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.favorite,
                                      size: 16,
                                      color: likedPhotos[index] == true
                                          ? Colors.red
                                          : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${eventPhotos[index]['likes'] ?? 0} likes'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
