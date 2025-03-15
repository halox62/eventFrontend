import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';

class SavedPhotosScreen extends StatefulWidget {
  const SavedPhotosScreen({Key? key}) : super(key: key);

  @override
  State<SavedPhotosScreen> createState() => _SavedPhotosScreenState();
}

class _SavedPhotosScreenState extends State<SavedPhotosScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  List<Map<String, dynamic>> _photos = [];
  String? _errorMessage;
  String? token;
  String? userEmail;
  late BuildContext _dialogContext;
  int? enlargedImageIndex;
  bool isImageEnlarged = false;
  List<String> ids = [];

  final String host = "event-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    userEmail = prefs.getString('email');

    try {
      if (token != null) {
        await _loadSavedPhotos();
      } else {
        const SnackBar(
          content: Text('Errore durante l\'aggiornamento'),
          behavior: SnackBarBehavior.floating,
        );
      }
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

  Future<void> _loadSavedPhotos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('https://$host/getUserPhotos');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          final List<dynamic> photosData = data['data'];
          setState(() {
            _photos = List<Map<String, dynamic>>.from(photosData);
            _isLoading = false;
          });
        } else {
          throw Exception(
              data['message'] ?? 'Errore nel caricamento delle foto');
        }
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception(
            'Errore nel caricamento delle foto: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile caricare le foto: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
          _loadSavedPhotos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Le tue foto salvate',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedPhotos,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _photos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.blue,
        ),
      );
    }

    if (_errorMessage != null && _photos.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 70,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              Text(
                'Si è verificato un errore',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSavedPhotos,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Nessuna foto salvata',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Le foto che salverai appariranno qui',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedPhotos,
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return _buildPhotoCard(photo, index);
          },
        ),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo, int index) {
    return GestureDetector(
      onTap: () => _handleImageLongPress(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(photo['file_url'] ?? ''),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra inferiore con azioni
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Titolo o info della foto, se disponibile
                      Expanded(
                        child: Text(
                          photo['title'] ?? 'Foto',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        photo['point']?.toString() ?? "0",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Pulsante Delete
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showDeleteDialog(context, photo['id']),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Miglioramenti per la visualizzazione delle immagini
  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 50),
                        SizedBox(height: 16),
                        Text(
                          'Impossibile caricare l\'immagine',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, int id) async {
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
                if (await _deletePhoto(id)) {
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

  Future<bool> _deletePhoto(int photoId) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('https://$host/delete_photo_save_id');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'image_id': photoId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _photos.remove(photoId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto eliminata con successo'),
              backgroundColor: Colors.red),
        );
        _loadSavedPhotos();
        return true;
      } else {
        _checkTokenValidity(response.statusCode);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore: impossibile eliminare la foto'),
              backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (error) {
      // Gestione errori di rete
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Errore di connessione'),
            backgroundColor: Colors.red),
      );
      return false;
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

  Future<void> _handleImageLongPress(int index) async {
    String message = "";
    try {
      setState(() {
        enlargedImageIndex = index;
        isImageEnlarged = true;
      });

      String id = _photos[index]["id"].toString();
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
        final responseJson = jsonDecode(response.body);
        message = responseJson["message"] ?? "Errore sconosciuto";

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

          final imageUrl = _photos[index]["file_url"]?.toString() ??
              'https://via.placeholder.com/150'; // Fallback per URL null

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
          SnackBar(
            content: Text(
                message.isEmpty ? 'Nessun dettaglio disponibile' : message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error in _handleImageLongPress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                message.isEmpty ? 'Errore durante l\'operazione' : message),
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
}
