import 'dart:convert';
import 'dart:math';
import 'package:barcode_scan2/platform_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:share_plus/share_plus.dart';
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
  Event createState() => Event();
}

class Event extends State<EventCalendar> {
  String? userEmail;
  String? token;
  DateTime? selectedDate;
  DateTime selectedDay = DateTime.now();
  List<DateTime> highlightedDates = [];
  List<DateTime> addEventDates = [];
  List<dynamic> eventJson = [];
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  String host = "event-production.up.railway.app";
  String eventName = "";
  bool creator = false;

  @override
  void initState() {
    super.initState();
    _initializePageEvent();
  }

  Future<void> _initializePageEvent() async {
    try {
      await _initializeEventCreate();
      await _initializeEventSubscribe();
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<bool> Creator() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');

    if (token != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http
            .get(Uri.parse('https://' + host + '/creator'), headers: headers);

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
  }

  Future<void> _handleRefresh() async {
    try {
      await _initializeEventCreate();
      await _initializeEventSubscribe();
    } catch (e) {
      print('Errore durante il refresh: $e');
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

  Future<void> _initializeEventCreate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');

    if (token != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http.get(
            Uri.parse('https://' + host + '/createGetEventDates'),
            headers: headers);

        if (response.statusCode == 200) {
          List<dynamic> jsonResponse = json.decode(response.body);
          highlightedDates =
              jsonResponse.map((date) => DateTime.parse(date)).toList();
          setState(() {});
        } else {
          var errorData = jsonDecode(response.body);
          _checkTokenValidity(errorData['msg']);
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<void> _initializeEventSubscribe() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.get(
          Uri.parse('http://' + host + '/subscribeGetEventDates'),
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
      print('Error: $e');
    }
  }

  Future<List<dynamic>> fetchEventsByDate(DateTime date) async {
    // Formatta la data come yyyy-MM-dd
    String dateOnly = DateFormat('yyyy-MM-dd').format(date);

    final url = Uri.parse('https://' + host + '/events_by_date');

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
                Navigator.of(context).pop();
                await delete_event(eventCode);
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
      // Mostra un dialog di caricamento
      /* showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Chiude il dialog di caricamento
      Navigator.of(context).pop();*/

      final events = await fetchEventsByDate(date);

      if (events.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) {
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
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.calendar_today,
                                              'Data Inizio',
                                              event['eventDate'] ?? 'N/A',
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.event_available,
                                              'Data Fine',
                                              event['endDate'] ?? 'N/A',
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.access_time,
                                              'Ora Fine',
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
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
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
                    child: const Icon(Icons.add),
                    backgroundColor: Colors.amber[800],
                    elevation: 4.0,
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
                    child: const Icon(Icons.event),
                    backgroundColor: Colors.blue,
                    elevation: 4.0,
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
      builder: (BuildContext context) {
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
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'Scansiona QR Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    labelStyle: TextStyle(color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
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
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Annulla',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (codeController.text.length == 8) {
                          addEvent(codeController.text);
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Inserisci un codice valido a 8 caratteri.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Conferma',
                        style: TextStyle(
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

  void addEvent(String code) async {
    final url = Uri.parse('https://' + host + '/addEvent');
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
            content: Text('Evento non aggiunto!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Errore durante la richiesta: $error');
    }
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

// Funzione per creare l'evento
  Future<String> createEvent(String eventName, String code,
      DateTime selectedDate, TimeOfDay timeOfDay, LatLng location) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://' + host + '/createEvent'),
      );

      request.headers.addAll(headers);

      request.fields['eventCode'] = code;

      DateTime today = DateTime.now();
      DateTime todayOnlyDate = DateTime(today.year, today.month, today.day);

      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

      if (selectedDate.isBefore(todayOnlyDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("La data selezionata è precedente a oggi!")),
        );
        return "NO";
      }

      // Calcolo della data e ora di inizio
      DateTime startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      DateTime endDateTime = startDateTime.add(const Duration(minutes: 1440));

      // Formattazione della data e ora di fine
      String formattedEndDate = DateFormat('yyyy-MM-dd').format(endDateTime);
      String formattedEndTime =
          '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
      request.fields['eventName'] = eventName;
      request.fields['eventDate'] = formattedDate;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento non creato!'),
            backgroundColor: Colors.red,
          ),
        );
        return "NO";
      }
    } catch (error) {
      print('Errore durante la creazione dell\'evento: $error');
      return "NO";
    }
  }

  void _showQRCode(String eventName, DateTime selectedDate, TimeOfDay timeOfDay,
      LatLng location) async {
    String data = _generateRandomString(8);
    String res =
        await createEvent(eventName, data, selectedDate, timeOfDay, location);
    if (res == "ok") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('QR Code'),
            content: SizedBox(
              width: 250.0, // Imposta una larghezza fissa
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // Imposta la dimensione minima per la colonna
                children: [
                  QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(
                      height: 20), // Spazio tra il QR code e il testo
                  const Text('Condividi il tuo QR Code!'),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Condividi'),
                onPressed: () {
                  //Share.share(data); // Condividi i dettagli dell'evento
                },
              ),
              TextButton(
                child: const Text('Chiudi'),
                onPressed: () {
                  Navigator.of(context).pop();
                  initState();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
