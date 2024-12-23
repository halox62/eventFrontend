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
  String host = "10.0.2.2:5000";
  String eventName = "";

  @override
  void initState() {
    super.initState();
    _initializeEventCreate();
    _initializeEventSubscribe();
  }

  Future<void> _checkTokenValidity(int statusCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (statusCode == 401) {
      try {
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          String? idToken = await user.getIdToken(true);
          prefs.setString('jwtToken', idToken!);
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
    userEmail = prefs.getString('userEmail');
    token = prefs.getString('jwtToken');

    if (userEmail != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http.get(
            Uri.parse(
                'http://' + host + '/createGetEventDates?email=$userEmail'),
            headers: headers);

        if (response.statusCode == 200) {
          List<dynamic> jsonResponse = json.decode(response.body);
          highlightedDates =
              jsonResponse.map((date) => DateTime.parse(date)).toList();
          setState(() {});
        } else {
          var errorData = jsonDecode(response.body);
          _checkTokenValidity(errorData['msg']);
          print('Failed to load dates: ${response.statusCode}');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<void> _initializeEventSubscribe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail');

    if (userEmail != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final response = await http.get(
            Uri.parse(
                'http://' + host + '/subscribeGetEventDates?email=$userEmail'),
            headers: headers);

        if (response.statusCode == 200) {
          List<dynamic> jsonResponse = json.decode(response.body);
          addEventDates =
              jsonResponse.map((date) => DateTime.parse(date)).toList();
          setState(() {});
        } else {
          var errorData = jsonDecode(response.body);
          _checkTokenValidity(errorData['msg']);
          print('Failed to load dates: ${response.statusCode}');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<List<dynamic>> fetchEventsByDate(DateTime date) async {
    // Formatta la data come yyyy-MM-dd
    String dateOnly = DateFormat('yyyy-MM-dd').format(date);

    final url = Uri.parse('http://' + host + '/events_by_date');

    final body = jsonEncode({
      'date': dateOnly,
      'email': userEmail,
    });

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
      var errorData = jsonDecode(response.body);
      _checkTokenValidity(errorData['msg']);
      throw Exception('Failed to load events');
    }
  }

  // Funzione per mostrare i dettagli dell'evento
  void _showEventDetails(DateTime date) async {
    await fetchEventsByDate(date);
    if (eventJson.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Dettagli degli Eventi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: eventJson.map<Widget>((event) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: ${event['eventName'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Code: ${event['eventCode'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Data: ${event['eventDate'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Data Fine: ${event['endDate'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Ora Fine: ${event['endTime'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 200, // Altezza della mappa
                          width: double.infinity, // Larghezza piena
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                double.tryParse(
                                        event['latitudine'].toString()) ??
                                    0.0,
                                double.tryParse(
                                        event['longitude'].toString()) ??
                                    0.0,
                              ),
                              zoom: 14.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('event_location'),
                                position: LatLng(
                                  double.tryParse(
                                          event['latitudine'].toString()) ??
                                      0.0,
                                  double.tryParse(
                                          event['longitude'].toString()) ??
                                      0.0,
                                ),
                                infoWindow: const InfoWindow(
                                  title: 'Posizione Evento',
                                ),
                              ),
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventPageControl(
                                  eventCode: event['eventCode'] ?? 'N/A',
                                ),
                              ),
                            );
                          },
                          child: Text('Apri ${event['eventCode']}'),
                        ),
                        const Divider(thickness: 1),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Chiudi'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario Eventi'),
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 10, 16),
        focusedDay: DateTime.now(),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),

          // Evidenzia le date contenute in highlightedDates
          selectedDecoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          // Evidenzia le date contenute in addEventDates di blu
          markerDecoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        selectedDayPredicate: (day) {
          // Controlla se la data corrente è in highlightedDates
          return highlightedDates
              .any((highlightedDay) => isSameDay(highlightedDay, day));
        },
        onDaySelected: (selectedDay, focusedDay) {
          // Controlla se la data selezionata è un evento e mostra i dettagli
          if (highlightedDates.any(
              (highlightedDay) => isSameDay(highlightedDay, selectedDay))) {
            _showEventDetails(selectedDay);
          } else if (addEventDates
              .any((eventDate) => isSameDay(eventDate, selectedDay))) {
            _showEventDetails(
                selectedDay); // Mostra i dettagli per le date in addEventDates
          }
        },

        // Aggiungi i marker per evidenziare le date di addEventDates in blu
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (addEventDates.any((eventDate) => isSameDay(eventDate, date))) {
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
                    '${date.day}', // Mostra il numero del giorno
                    style: const TextStyle(
                      color: Colors
                          .white, // Colore del testo (bianco per contrastare il blu)
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }
            return null; // Se la data non è in addEventDates, non mostrare niente
          },
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
                  margin: const EdgeInsets.symmetric(
                      horizontal: 4.0), // Spaziatura tra i pulsanti
                  child: FloatingActionButton(
                    heroTag: "btn1", // Un tag univoco per il primo pulsante
                    onPressed: () {
                      // Azione del primo pulsante
                      _showCreateEventDialog(context);
                    },
                    child: const Icon(Icons.add),
                    backgroundColor: Colors.amber[800],
                    elevation: 4.0, // Aggiungi un'ombra per effetto
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 4.0), // Spaziatura tra i pulsanti
                  child: FloatingActionButton(
                    heroTag: "btn2", // Un tag univoco per il secondo pulsante
                    onPressed: () {
                      _showAnotherDialog(context);
                    },
                    child:
                        const Icon(Icons.event), // Scegli un'icona appropriata
                    backgroundColor: Colors.blue, // Colore del secondo pulsante
                    elevation: 4.0, // Aggiungi un'ombra per effetto
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
              height: 16), // Spazio tra i pulsanti e il bordo inferiore
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation
          .centerFloat, // Posiziona i pulsanti al centro
    );
  }

  Future<void> _showAnotherDialog(BuildContext context) async {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aggiungi codice evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  var result = await BarcodeScanner.scan();
                  if (result.rawContent.isNotEmpty) {
                    codeController.text = result.rawContent;
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scansiona QR Code'),
              ),
              const Text("O"),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Inserisci codice (8 caratteri)',
                  hintText: 'Codice evento',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(8),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Conferma'),
              onPressed: () {
                if (codeController.text.length == 8) {
                  // Logica per processare il codice inserito
                  addEvent(codeController.text);
                  Navigator.of(context).pop();
                } else {
                  // Mostra un errore se il codice non è valido
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Inserisci un codice valido a 8 caratteri.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void addEvent(String code) async {
    final url = Uri.parse('http://' + host + '/addEvent');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': userEmail, 'code': code}),
      );

      // Controlla se la risposta è andata a buon fine
      if (response.statusCode == 200) {
      } else {
        var errorData = jsonDecode(response.body);
        _checkTokenValidity(errorData['msg']);
        print('Errore: ${response.statusCode}');
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Crea Evento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        eventName = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nome Evento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: const Text('Seleziona Data'),
                  ),
                  if (selectedDate != null)
                    Text(
                      '${selectedDate!.toLocal()}'.split(' ')[0],
                    ),

                  // Seleziona l'ora
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                    child: const Text('Seleziona Ora'),
                  ),
                  if (selectedTime != null) Text(selectedTime!.format(context)),

                  // Inserisci il luogo
                  ElevatedButton(
                    onPressed: () async {
                      location = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SelectLocationScreen(),
                        ),
                      );
                      if (location != null) {
                        setState(() {
                          selectedLocation = location;
                        });
                      }
                    },
                    child: const Text('Seleziona Posizione'),
                  ),
                  if (selectedLocation != null)
                    Expanded(
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
                    )
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Annulla'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Crea Evento'),
                  onPressed: selectedDate == null ||
                          selectedTime == null ||
                          location == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _showQRCode(eventName, selectedDate!, selectedTime!,
                              location!);
                        },
                ),
              ],
            );
          },
        );
      },
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
  Future<String> createEvent(String email, String eventName, String code,
      DateTime selectedDate, TimeOfDay timeOfDay, LatLng location) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://' + host + '/createEvent'),
      );

      request.headers.addAll(headers);

      request.fields['email'] = email;
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
        var responseData = await response.stream.bytesToString();
        print('Success: $responseData');
        return "ok";
      } else {
        final errorBody = await response.stream.bytesToString();
        var errorData = jsonDecode(errorBody);
        _checkTokenValidity(errorData['msg']);
        print(
            'Failed: ${response.statusCode}, Response: ${await response.stream.bytesToString()}');
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
    String res = await createEvent(
        userEmail!, eventName, data, selectedDate, timeOfDay, location);
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
                },
              ),
            ],
          );
        },
      );
    } /* else {
      String message = "Event not create";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }*/
  }
}
