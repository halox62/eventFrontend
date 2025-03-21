import 'dart:convert';
import 'dart:math';
import 'package:barcode_scan2/platform_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
import 'package:social_flutter_giorgio/screens/EventPage.dart';
import 'package:social_flutter_giorgio/screens/SelectLocationScreenState.dart';
import 'package:table_calendar/table_calendar.dart';

class EventCalendar extends StatefulWidget {
  const EventCalendar({Key? key}) : super(key: key);

  @override
  _EventCalendarState createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  String? userEmail;
  DateTime? selectedDate;
  DateTime selectedDay = DateTime.now();
  List<DateTime> highlightedDates = [];
  List<DateTime> addEventDates = [];
  List<dynamic> eventJson = [];
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  //String host = "event-production.up.railway.app";
  final String host = "www.event-fit.it";
  String eventName = "";
  bool creator = false;
  late BuildContext _dialogContext;
  int count = 0;
  bool _isLoadingDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initializePageEvent(true);
  }

  void showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        _isLoadingDialogShown = true;
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

  Future<void> _initializePageEvent(bool loading) async {
    try {
      if (loading) {
        showLoadingDialog("Caricamento Eventi");
      }

      await _initializeEventCreate();
      await _initializeEventSubscribe();
      Navigator.of(_dialogContext).pop();
    } catch (e) {
      _showFeedbackMessage('Errore durante il caricamento', isError: true);
    }
  }

  Future<bool> Creator() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');

    if (token != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http.get(Uri.parse('https://$host/creator'),
            headers: headers);

        if (response.statusCode == 200) {
          return true;
        } else {
          _checkTokenValidity(response.statusCode);
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<void> delete_event(String eventCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');

    if (token == null) {
      _showFeedbackMessage('Errore: Sessione non valida', isError: true);
      return;
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'eventCode': eventCode,
      });

      final response = await http.post(
        Uri.parse('https://$host/delete_event'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento cancellato con successo!'),
            backgroundColor: Colors.green,
          ),
        );
        await _initializeEventCreate();
        await _initializeEventSubscribe();
      } else {
        _showFeedbackMessage('Errore durante l\'eliminazione dell\'evento',
            isError: true);
      }
    } catch (e) {
      _showFeedbackMessage('Errore di connessione durante l\'eliminazione',
          isError: true);
    }
    Navigator.of(_dialogContext).pop();
  }

  Future<void> _handleRefresh() async {
    try {
      _initializePageEvent(true);
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
          _initializePageEvent(false);
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

  Future<void> _initializeEventCreate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');

    if (token != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http.get(
            Uri.parse('https://$host/createGetEventDates'),
            headers: headers);

        if (response.statusCode == 200) {
          List<dynamic> jsonResponse = json.decode(response.body);
          highlightedDates =
              jsonResponse.map((date) => DateTime.parse(date)).toList();
          setState(() {});
        } else {
          _checkTokenValidity(response.statusCode);
        }
      } catch (e) {
        _showFeedbackMessage('Errore di connessione durante l\'eliminazione',
            isError: true);
      }
    }
  }

  Future<void> _initializeEventSubscribe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.get(
          Uri.parse('https://$host/subscribeGetEventDates'),
          headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        addEventDates =
            jsonResponse.map((date) => DateTime.parse(date)).toList();
        setState(() {});
      } else {
        _checkTokenValidity(response.statusCode);
      }
    } catch (e) {
      _showFeedbackMessage('Errore di connessione durante l\'eliminazione',
          isError: true);
    }
  }

  Future<List<dynamic>> fetchEventsByDate(DateTime date) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');
    // Formatta la data come yyyy-MM-dd
    String dateOnly = DateFormat('yyyy-MM-dd').format(date);

    final url = Uri.parse('https://$host/events_by_date');

    final body = jsonEncode({'date': dateOnly});

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      eventJson = jsonDecode(response.body)['events'];
      return eventJson;
    } else {
      _checkTokenValidity(response.statusCode);
      throw Exception('Failed to load events');
    }
  }

  void _showDeleteConfirmation(
      BuildContext context, String eventCode, String eventName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conferma eliminazione'),
          content:
              Text('Sei sicuro di voler eliminare l\'evento "$eventName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () async {
                try {
                  // Close the current dialog first
                  Navigator.of(context).pop();

                  // Show loading dialog
                  showLoadingDialog("Eliminazione evento in corso...");

                  // Wait for delete operation to complete
                  await delete_event(eventCode);

                  // Hide loading dialog
                  hideLoadingDialog();

                  // Show success message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Evento eliminato con successo'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // Hide loading dialog in case of error
                  hideLoadingDialog();

                  // Show error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Errore durante l\'eliminazione: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
  }

  // Funzione per mostrare i dettagli dell'evento
  void _showEventDetails(DateTime date) async {
    try {
      final events = await fetchEventsByDate(date);

      if (events.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) {
            _dialogContext = context;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 700,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dettagli Eventi',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: eventJson.map<Widget>((event) {
                            return FutureBuilder<bool>(
                              future: Creator(),
                              builder: (context, snapshot) {
                                final bool isCreator = snapshot.data ?? false;

                                return Card(
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.3),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    event['eventName'] ?? 'N/A',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge,
                                                  ),
                                                ),
                                                if (isCreator)
                                                  FloatingActionButton.small(
                                                    onPressed: () =>
                                                        _showDeleteConfirmation(
                                                            context,
                                                            event['eventCode'] ??
                                                                '',
                                                            event['eventName'] ??
                                                                'questo evento'),
                                                    backgroundColor: Colors.red,
                                                    child: const Icon(
                                                        Icons.delete,
                                                        color: Colors.white),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            _buildInfoRow(
                                              context,
                                              Icons.event,
                                              'Codice',
                                              event['eventCode'] ?? 'N/A',
                                              isCode: true,
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.calendar_today,
                                              'Data Inizio',
                                              event['eventDate'] ?? 'N/A',
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.access_time,
                                              'Ora Inizio',
                                              event['endTime'] ?? 'N/A',
                                            ),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: SizedBox(
                                                height: 180,
                                                width: double.infinity,
                                                child: GoogleMap(
                                                  initialCameraPosition:
                                                      CameraPosition(
                                                    target: LatLng(
                                                      double.tryParse(event[
                                                                  'latitudine']
                                                              .toString()) ??
                                                          0.0,
                                                      double.tryParse(event[
                                                                  'longitude']
                                                              .toString()) ??
                                                          0.0,
                                                    ),
                                                    zoom: 14.0,
                                                  ),
                                                  markers: {
                                                    Marker(
                                                      markerId: const MarkerId(
                                                          'event_location'),
                                                      position: LatLng(
                                                        double.tryParse(event[
                                                                    'latitudine']
                                                                .toString()) ??
                                                            0.0,
                                                        double.tryParse(event[
                                                                    'longitude']
                                                                .toString()) ??
                                                            0.0,
                                                      ),
                                                      infoWindow: InfoWindow(
                                                        title: event[
                                                                'eventName'] ??
                                                            'Posizione Evento',
                                                      ),
                                                    ),
                                                  },
                                                  myLocationEnabled: false,
                                                  zoomControlsEnabled: false,
                                                  mapToolbarEnabled: false,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          EventPageControl(
                                                        eventCode: event[
                                                                'eventCode'] ??
                                                            'N/A',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors
                                                      .green, // Imposta il colore di sfondo verde
                                                  foregroundColor: Colors
                                                      .white, // Imposta il colore del testo e dell'icona in bianco
                                                ),
                                                icon: const Icon(
                                                    Icons.visibility),
                                                label: const Text(
                                                    'Visualizza Dettagli'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        _showFeedbackMessage('Nessun evento trovato per questa data');
      }
    } catch (e) {
      _showFeedbackMessage('Errore nel caricamento degli eventi',
          isError: true);
    }
  }

  void _showFeedbackMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

// Widget helper per le righe di informazioni
  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value,
      {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.black,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: isCode
                ? InkWell(
                    onTap: () => _showQRCode1(context, value),
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  )
                : Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQRCode1(BuildContext context, String code) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QR Code Evento',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // QR Code Container with shadow
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: code,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      errorStateBuilder: (context, error) => Center(
                        child: Text(
                          'Errore nella generazione del QR Code',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Code display with copy button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Codice copiato negli appunti'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              width: 300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      tooltip: 'Copia codice',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /* FilledButton.icon(
                    onPressed: () {
                      // Implement QR code saving functionality
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text(
                      'Salva QR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),*/
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Share.share(
                        'Codice evento: $code',
                        subject: 'QR Code Evento',
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text(
                      'Condividi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario Eventi'),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2030, 10, 16),
                focusedDay: DateTime.now(),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                selectedDayPredicate: (day) {
                  return highlightedDates
                      .any((highlightedDay) => isSameDay(highlightedDay, day));
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (highlightedDates.any((highlightedDay) =>
                      isSameDay(highlightedDay, selectedDay))) {
                    _showEventDetails(selectedDay);
                  } else if (addEventDates
                      .any((eventDate) => isSameDay(eventDate, selectedDay))) {
                    _showEventDetails(selectedDay);
                  }
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (addEventDates
                        .any((eventDate) => isSameDay(eventDate, date))) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            width: 40,
                            height: 40,
                          ),
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FloatingActionButton(
                    heroTag: "btn1",
                    onPressed: () {
                      _showCreateEventDialog(context);
                    },
                    backgroundColor: Colors.amber[800],
                    foregroundColor: Colors.white,
                    elevation: 4.0,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FloatingActionButton(
                    heroTag: "btn2",
                    onPressed: () {
                      _showAnotherDialog(context);
                    },
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 4.0,
                    child: const Icon(Icons.event),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _showAnotherDialog(BuildContext context) async {
    final TextEditingController codeController = TextEditingController();
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aggiungi codice evento',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    var result = await BarcodeScanner.scan();
                    if (result.rawContent.isNotEmpty) {
                      codeController.text = result.rawContent;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green, // Changed to green
                    foregroundColor: Colors.white, // White text for contrast
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    size: 24,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Scansiona QR Code',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'oppure',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  maxLength: 8,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Codice evento',
                    hintText: 'Inserisci 8 caratteri',
                    labelStyle: const TextStyle(
                        color: Colors.black), // Changed to green
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Colors.green), // Changed to green
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.green, // Changed to green
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(8),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Annulla',
                        style: TextStyle(
                          color: Color.fromARGB(255, 223, 91, 91),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (codeController.text.length == 8) {
                          try {
                            // Show loading dialog
                            showLoadingDialog("Aggiunta evento in corso...");

                            // Wait for the addEvent to complete
                            await addEvent(codeController.text);

                            // Hide loading dialog
                            hideLoadingDialog();

                            // Close the current dialog
                            if (dialogContext != null &&
                                Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            // Hide loading dialog in case of error
                            hideLoadingDialog();

                            // Show error message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Errore: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Attenzione codice sbagliato!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.green, // Changed to green
                        foregroundColor:
                            Colors.white, // White text for contrast
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Conferma',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> addEvent(String code) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');
    final url = Uri.parse('https://$host/addEvent');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode == 200) {
        await _initializeEventCreate();
        await _initializeEventSubscribe();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento aggiunto con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _checkTokenValidity(response.statusCode);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attenzione codice sbagliato!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      _showFeedbackMessage('Errore di connessione durante l\'eliminazione',
          isError: true);
    }
    return "ok";
  }

  void _showCreateEventDialog(BuildContext context) {
    TimeOfDay? selectedTime;
    LatLng? location;
    LatLng? selectedLocation;
    DateTime? selectedDate;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 400, maxHeight: 600),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Crea Evento',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      onChanged: (value) => setState(() => eventName = value),
                      decoration: InputDecoration(
                        labelText: 'Nome Evento',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectionTile(
                            context: context,
                            icon: Icons.calendar_today,
                            title: 'Data',
                            value: selectedDate != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(selectedDate!)
                                : 'Seleziona',
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (date != null) {
                                setState(() => selectedDate = date);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectionTile(
                            context: context,
                            icon: Icons.access_time,
                            title: 'Ora',
                            value: selectedTime != null
                                ? selectedTime!.format(context)
                                : 'Seleziona',
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() => selectedTime = time);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionTile(
                      context: context,
                      icon: Icons.location_on,
                      title: 'Posizione',
                      value: selectedLocation != null
                          ? '${selectedLocation!.latitude.toStringAsFixed(2)}, ${selectedLocation!.longitude.toStringAsFixed(2)}'
                          : 'Seleziona',
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectLocationScreen(),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            location = result;
                            selectedLocation = result;
                          });
                        }
                      },
                    ),
                    if (selectedLocation != null) ...[
                      const SizedBox(height: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(selectedLocation!.latitude,
                                  selectedLocation!.longitude),
                              zoom: 14.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId("selected_location"),
                                position: LatLng(selectedLocation!.latitude,
                                    selectedLocation!.longitude),
                                infoWindow: InfoWindow(
                                  title: "Posizione Selezionata",
                                  snippet:
                                      "${selectedLocation!.latitude}, ${selectedLocation!.longitude}",
                                ),
                              ),
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Annulla',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: selectedDate == null ||
                                  selectedTime == null ||
                                  location == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _showQRCode(eventName, selectedDate!,
                                      selectedTime!, location!);
                                },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Crea Evento'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
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

  String _generateRandomString(int length) {
    const characters =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => characters.codeUnitAt(random.nextInt(characters.length)),
    ));
  }

  Future<String> createEvent(String eventName, String code,
      DateTime selectedDate, TimeOfDay timeOfDay, LatLng location) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwtToken');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://$host/createEvent'),
      );

      request.headers.addAll(headers);

      request.fields['eventCode'] = code;

      DateTime today = DateTime.now();
      DateTime todayOnlyDate = DateTime(today.year, today.month, today.day);

      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Calcolo della data e ora di inizio
      DateTime startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      // Calcolo della data e ora di fine (24 ore dopo = 1440 minuti)
      DateTime endDateTime = startDateTime.add(const Duration(minutes: 1440));

      // Formattazione della data e ora di fine
      String formattedEndDate = DateFormat('yyyy-MM-dd').format(endDateTime);
      String formattedEndTime = DateFormat('HH:mm').format(endDateTime);

      // Aggiunta di tutti i campi alla richiesta
      request.fields['eventName'] = eventName;
      request.fields['eventDate'] = formattedDate;
      request.fields['eventTime'] = DateFormat('HH:mm').format(startDateTime);
      request.fields['endDate'] = formattedEndDate;
      request.fields['endTime'] = formattedEndTime;
      request.fields['latitudine'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['create'] = "yes";

      var response = await request.send();

      if (response.statusCode == 201) {
        await _initializeEventCreate();
        await _initializeEventSubscribe();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento creato con successo!'),
            backgroundColor: Colors.green,
          ),
        );

        return "ok";
      } else {
        _checkTokenValidity(response.statusCode);

        _showErrorSnackbar("Evento non creato!");

        return "NO";
      }
    } catch (error) {
      _showErrorSnackbar("Errore durante la creazione dell'evento");

      return "NO";
    }
  }

  void _showQRCode(String eventName, DateTime selectedDate, TimeOfDay timeOfDay,
      LatLng location) async {
    try {
      DateTime today = DateTime.now();
      DateTime todayOnlyDate = DateTime(today.year, today.month, today.day);

      if (selectedDate.isBefore(todayOnlyDate)) {
        _showErrorSnackbar("La data selezionata è precedente a oggi!");

        return;
      }

      if (selectedDate.year == today.year &&
          selectedDate.month == today.month &&
          selectedDate.day == today.day) {
        TimeOfDay now = TimeOfDay.now();
        if (timeOfDay.hour < now.hour ||
            (timeOfDay.hour == now.hour && timeOfDay.minute < now.minute)) {
          _showErrorSnackbar("L'orario selezionato è già passato!");
          return;
        }
      }

      showLoadingDialog("Creazione evento in corso...");

      String data = _generateRandomString(8);
      String res =
          await createEvent(eventName, data, selectedDate, timeOfDay, location);

      hideLoadingDialog();

      if (res == "ok") {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 320,
                    // Non definire un'altezza massima per permettere al contenuto di adattarsi
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Importante!
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'QR Code',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: data,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Condividi il tuo QR Code!',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Container per il codice
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: data));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Codice copiato negli appunti'),
                                        behavior: SnackBarBehavior.fixed,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Copia codice',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bottoni
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('Condividi'),
                              onPressed: () {
                                Share.share(
                                    'Unisciti al mio evento con il codice: $data');
                              },
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              child: const Text('Chiudi'),
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                // Aggiorna lo stato se necessario
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  void hideLoadingDialog() {
    if (_isLoadingDialogShown) {
      try {
        if (Navigator.of(_dialogContext, rootNavigator: true).canPop()) {
          Navigator.of(_dialogContext, rootNavigator: true).pop();
        }
      } catch (e) {
        print('Errore durante la chiusura del dialog: $e');
      } finally {
        _isLoadingDialogShown = false;
      }
    }
  }

  /*void showLoadingDialog(String message) {
    if (_isLoadingDialogShown) return;

    _isLoadingDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        _dialogContext = context;
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isLoadingDialogShown = false;
    });
  }*/

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
}
