import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';

class ProfilePage extends StatefulWidget {
  final String email;

  const ProfilePage({Key? key, required this.email}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  List<String> images = [];
  bool isLoading = true;
  String? token;
  String host = "event-production.up.railway.app";
  //final String host = "event-fit.it";
  var point = "0";
  List<String> ids = [];
  List<String> points = [];
  String? photo;
  String? save;

  int? enlargedImageIndex;
  bool isImageEnlarged = false;

  final ScrollController _scrollController = ScrollController();

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
          _initializeData();
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

  Future<void> _initializeData() async {
    await fetchProfileData(widget.email);
    await fetchImages(widget.email);
  }

  Future<void> fetchProfileData(String userEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    if (token == null) {
      throw Exception('Token not found');
    }
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        Uri.parse('https://$host/profileS'),
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
            save = data['save'].toString();
            print(save);
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

  Future<void> fetchImages(String email) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        Uri.parse('https://$host/getImageS'),
        headers: headers,
        body: jsonEncode({
          'email': email,
        }),
      );

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

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey[300],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // Implementa qui la logica di ricaricamento dati
              await Future.delayed(const Duration(seconds: 1));
              setState(() {
                isLoading = false;
              });
            },
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black54,
                      strokeWidth: 2,
                    ),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: profileImageUrl != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: profileImageUrl!,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: Colors.grey[200],
                                            child: Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.grey[200],
                                        child: Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                userName ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStat('Posts', images.length.toString()),
                                  _buildDivider(),
                                  _buildStat('Points', point),
                                  _buildDivider(),
                                  _buildStat('Save', save!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildPhotoCard(index);
                            },
                            childCount: images.length,
                          ),
                        ),
                      ),
                      // Aggiungi spazio in fondo alla griglia
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 30),
                      ),
                    ],
                  ),
          ),

          // Visualizzazione immagine ingrandita
          if (isImageEnlarged && enlargedImageIndex != null)
            GestureDetector(
              onTap: () => _toggleEnlargedImage(),
              child: Container(
                color: Colors.black.withOpacity(0.95),
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    // Immagine ingrandita
                    Center(
                      child: Hero(
                        tag: 'image_${enlargedImageIndex!}',
                        child: CachedNetworkImage(
                          imageUrl: images[enlargedImageIndex!],
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // Pulsante per chiudere
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 30),
                        onPressed: _toggleEnlargedImage,
                      ),
                    ),

                    // Info sull'immagine
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  points[enlargedImageIndex!].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.save,
                                  color: Colors.white, size: 24),
                              onPressed: () => savePhoto(enlargedImageIndex!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

// Metodo per costruire la card della foto
  Widget _buildPhotoCard(int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Immagine
            Expanded(
              child: _buildImageTile(index),
            ),
            // Barra inferiore
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stelle e punteggio
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        points[index].toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  // Pulsante Save
                  GestureDetector(
                    onTap: () => savePhoto(index),
                    child: const Icon(
                      Icons.save,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Metodo per costruire il riquadro dell'immagine con caricamento ottimizzato
  Widget _buildImageTile(int index) {
    return GestureDetector(
      onTap: () => _handleImageTap(index),
      child: Hero(
        tag: 'image_${index}',
        child: CachedNetworkImage(
          imageUrl: images[index],
          fit: BoxFit.cover,
          memCacheHeight: 300, // Cache ottimizzata
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.grey,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

// Metodo per gestire il toggle dell'immagine ingrandita
  void _toggleEnlargedImage() {
    setState(() {
      isImageEnlarged = !isImageEnlarged;
      if (!isImageEnlarged) {
        enlargedImageIndex = null;
      }
    });
  }

// Metodo modificato per gestire il tap sull'immagine
  void _handleImageTap(int index) {
    setState(() {
      if (isImageEnlarged && enlargedImageIndex == index) {
        isImageEnlarged = false;
        enlargedImageIndex = null;
      } else {
        isImageEnlarged = true;
        enlargedImageIndex = index;
      }
    });
  }

  Future<void> _handleImageLongPress(int index) async {
    try {
      setState(() {
        enlargedImageIndex = index;
        isImageEnlarged = true;
      });

      String id = ids[index].toString();
      bool isLoading = true;
      bool hasDetails = false;
      Map<String, dynamic>? photoData;
      AnimationController? animationController;

      // Fetch dei dettagli
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

      // Mostra il dialog comunque, anche se non ci sono dettagli
      animationController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      )..repeat(reverse: true);

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

          final imageUrl = images[index]?.toString() ??
              'https://via.placeholder.com/150'; // Assumo che l'URL sia in images[index]

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(80),
                    minScale: 0.5,
                    maxScale: 4,
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
                            return const Center(
                              child: Text(
                                'Immagine non disponibile',
                                style: TextStyle(color: Colors.white),
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
                      print('Total drag distance: $totalDragDistance');
                    },
                    onVerticalDragEnd: (details) async {
                      print('Drag end velocity: ${details.primaryVelocity}');
                      if (totalDragDistance < -50 && photoData != null) {
                        print('Swipe up detected!');
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
                                      const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Text(
                                          'Dettagli Foto',
                                          style: TextStyle(
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
                                                    Text(
                                                        'Tipo: ${item['type'] ?? 'N/A'}'),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                        'Marca: ${item['brand'] ?? 'N/A'}'),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                        'Modello: ${item['model'] ?? 'N/A'}'),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                        'Feedback: ${item['feedback'] ?? 'N/A'}'),
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
                        children: const [
                          Icon(Icons.keyboard_arrow_up,
                              color: Colors.white, size: 36),
                          SizedBox(height: 4),
                          Text(
                            'Scorri verso l\'alto per i dettagli',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLoading)
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                // Nessuna "X" come richiesto
              ],
            ),
          );
        },
      );

      // Mostra SnackBar solo se non ci sono dettagli
      if (!hasDetails && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun dettaglio disponibile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error in _handleImageLongPress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'operazione'),
            backgroundColor: Colors.red,
          ),
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
    String message = "";
    try {
      String idPhoto = ids[index].toString();
      final uri = Uri.parse('https://$host/salvePhoto?id_photo=$idPhoto');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseJson = jsonDecode(response.body);
      message = responseJson["message"];
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
      // Registra l'errore e mostra un messaggio all'utente
      print("Errore durante la chiamata API: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );

      throw Exception("Impossibile connettersi all'API.");
    }
  }
}
