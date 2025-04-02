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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EventPageControl extends StatefulWidget {
  final String eventCode;

  const EventPageControl({Key? key, required this.eventCode}) : super(key: key);

  @override
  EventPage createState() => EventPage();
}

class EventPage extends State<EventPageControl> with TickerProviderStateMixin {
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
  final String host = "www.event-fit.it";
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
          showLoadingDialog(AppLocalizations.of(context).loading_events);
        }

        await _loadEventPhotos();
        await _loadLikePhotos();
        await _fetchEventCoordinates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).no_info_available),
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
                    Text(
                      AppLocalizations.of(context).event_not_started,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)
                          .event_start_time(formattedEndTime),
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
                          unit: AppLocalizations.of(context).hours,
                        ),
                        _CountdownSeparator(),
                        _CountdownUnit(
                          value: difference.inMinutes % 60,
                          unit: AppLocalizations.of(context).minutes,
                        ),
                        _CountdownSeparator(),
                        _CountdownUnit(
                          value: difference.inSeconds % 60,
                          unit: AppLocalizations.of(context).seconds,
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
                      child: Text(
                        AppLocalizations.of(context).return_to_home,
                        style: const TextStyle(
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
          SnackBar(
            content: Text(AppLocalizations.of(context).refresh_error),
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
      print("Error retrieving event coordinates: $e");
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
      print("Error retrieving event coordinates: $e");
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
          label: AppLocalizations.of(context).dismiss,
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
        Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        double distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          eventLatitude!,
          eventLongitude!,
        );

        if (distance <= 1000) {
          message = AppLocalizations.of(context).position_ok;
          showCustomSnackbar(context, message);
        } else {
          message = AppLocalizations.of(context).too_far_from_event;
          showCustomSnackbar(context, message, isError: true);
        }
      } else if (permission.isDenied) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homepage()),
        );
      } else if (permission.isPermanentlyDenied) {
        openAppSettings();
      }
    } catch (e) {
      print("Error retrieving location: $e");
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
      print('Like added successfully');
    } else {
      var errorData = jsonDecode(response.body);
      _checkTokenValidity(errorData['msg']);
      print('Error adding like');
    }
  }

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
          AppLocalizations.of(context).event_title(eventName ?? ''),
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
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context).ranking,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.emoji_events, color: Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: rankedPhotos.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.photo_library_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        AppLocalizations.of(context)
                                            .no_photos_in_ranking,
                                        style: const TextStyle(
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
                children: [
                  SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context).no_photos,
                            style: const TextStyle(
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
                          onTap: () => _handleImageLongPress(index),
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
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context)
                                              .image_not_available,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
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
                                    AppLocalizations.of(context).likes(
                                        (eventPhotos[index]['likes'] ?? 0)
                                            .toString()),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
    if (isImageEnlarged) return;
    try {
      setState(() {
        enlargedImageIndex = index;
        isImageEnlarged = true;
      });

      String id = eventPhotos[index]["id"].toString();
      bool isLoading = true;
      bool hasDetails = false;
      Map<String, dynamic>? photoData;
      AnimationController? animationController;

      try {
        final response = await http.get(
          Uri.parse('https://$host/infoPhoto?id_photo=$id'),
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

      animationController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      )..repeat(reverse: true);

      // Aggiungiamo il TransformationController
      final TransformationController transformationController =
          TransformationController();

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

          final imageUrl = eventPhotos[index]["image_path"]?.toString() ??
              'https://via.placeholder.com/150';

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: InteractiveViewer(
                    transformationController: transformationController,
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(80),
                    minScale: 0.5,
                    maxScale: 4,
                    onInteractionEnd: (_) {
                      // Resetta la trasformazione quando l'utente finisce di interagire
                      transformationController.value = Matrix4.identity();
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.9),
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            return loadingProgress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                AppLocalizations.of(context)
                                    .image_not_available,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
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
                        isDetailsLoading = true;
                        await showModalBottomSheet(
                          context: dialogContext,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) {
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              if (context.mounted) {
                                isDetailsLoading = false;
                                (context as Element).markNeedsBuild();
                              }
                            });

                            return Container(
                              height: MediaQuery.of(context).size.height * 0.7,
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
                                        margin: const EdgeInsets.only(top: 12),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          AppLocalizations.of(context)
                                              .photo_details,
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          itemCount: photoData!['data'].length,
                                          itemBuilder: (context, idx) {
                                            final item =
                                                photoData!['data'][idx];
                                            return Card(
                                              elevation: 2,
                                              margin: const EdgeInsets.only(
                                                  bottom: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(AppLocalizations.of(
                                                            context)
                                                        .type(item['type'] ??
                                                            'N/A')),
                                                    const SizedBox(height: 8),
                                                    Text(AppLocalizations.of(
                                                            context)
                                                        .brand(item['brand'] ??
                                                            'N/A')),
                                                    const SizedBox(height: 8),
                                                    Text(AppLocalizations.of(
                                                            context)
                                                        .model(item['model'] ??
                                                            'N/A')),
                                                    const SizedBox(height: 8),
                                                    Text(AppLocalizations.of(
                                                            context)
                                                        .feedback(
                                                            item['feedback'] ??
                                                                'N/A')),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isDetailsLoading)
                                    Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
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
                        children: [
                          const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white, size: 36),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).swipe_up_for_details,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLoading)
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
              ],
            ),
          );
        },
      );

      // Pulizia dei controller dopo la chiusura del dialog
      transformationController.dispose();
      animationController.dispose();
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(AppLocalizations.of(context).operation_error);
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

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

      Overlay.of(context).insert(overlay);

      Future.delayed(const Duration(seconds: 3), () {
        overlay.remove();
      });
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
            content: Text(data['message'] ??
                AppLocalizations.of(context).photo_saved_successfully),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _checkTokenValidity(response.statusCode);
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          throw Exception(
              errorData['message'] ?? 'Error during save operation');
        } catch (e) {
          throw Exception('Error during save: ${response.statusCode}');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).save_photo_error),
          backgroundColor: Colors.red,
        ),
      );

      throw Exception("Unable to connect to the API.");
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
