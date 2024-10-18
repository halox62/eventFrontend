import 'dart:convert';
import 'dart:math';
import 'package:barcode_scan2/platform_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:social_flutter_giorgio/screens/SelectLocationScreenState.dart';
import 'package:table_calendar/table_calendar.dart';

class EventPage extends StatefulWidget {
  @override
  Event createState() => Event();
}

class Event extends State<EventPage> {
  String? userEmail;
  DateTime? selectedDate;
  DateTime selectedDay = DateTime.now();
  late Map<DateTime, List<dynamic>> events;
  List<DateTime> highlightedDates = [];
  List<dynamic> eventJson = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail');

    if (userEmail != null) {
      // Effettua la chiamata API per ottenere le date
      try {
        final response = await http.get(
            Uri.parse('http://10.0.2.2:5000/getEventDates?email=$userEmail'));

        if (response.statusCode == 200) {
          // Analizza il JSON e aggiorna la lista di date
          List<dynamic> jsonResponse = json.decode(response.body);

          // Supponendo che la risposta contenga una lista di stringhe di date
          highlightedDates =
              jsonResponse.map((date) => DateTime.parse(date)).toList();

          // Chiedi una ricostruzione del widget per aggiornare il calendario
          setState(() {});
        } else {
          print('Failed to load dates: ${response.statusCode}');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  Future<List<dynamic>> fetchEventsByDate(DateTime date) async {
    String dateOnly = DateFormat('yyyy-MM-dd').format(date);

    final url = Uri.parse('http://10.0.2.2:5000/events_by_date?date=$dateOnly');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Parsing della risposta JSON
      eventJson = jsonDecode(response.body)['events'];
      return eventJson;
    } else {
      throw Exception('Failed to load events');
    }
  }

  // Funzione per mostrare i dettagli dell'evento
  void _showEventDetails(DateTime date) async {
    await fetchEventsByDate(date);
    print("list ${eventJson}");
    if (eventJson.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          final event = eventJson[0]; // Assume che ci sia almeno un evento
          return AlertDialog(
            title: Text('Dettagli Evento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${event['eventCode'] ?? 'N/A'}'),
                SizedBox(height: 8),
                Text('Data: ${event['eventDate'] ?? 'N/A'}'),
                SizedBox(height: 8),
                Text('Ora: ${event['eventTime'] ?? 'N/A'}'),
                SizedBox(height: 8),
                Text('Durata: ${event['duration'] ?? 'N/A'} minuti'),
                SizedBox(height: 8),
                Text('Latitudine: ${event['latitudine'] ?? 'N/A'}'),
                SizedBox(height: 8),
                Text('Longitudine: ${event['longitude'] ?? 'N/A'}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Chiudi'),
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
        title: Text('Calendario Eventi'),
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 10, 16),
        focusedDay: DateTime.now(),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          // Evidenzia le date contenute in highlightedDates
          selectedDecoration: BoxDecoration(
            color: Colors.orange,
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
          }
        },
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
                    child: Icon(Icons.add),
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
                      // Azione del secondo pulsante
                    },
                    child: Icon(Icons.event), // Scegli un'icona appropriata
                    backgroundColor: Colors.blue, // Colore del secondo pulsante
                    elevation: 4.0, // Aggiungi un'ombra per effetto
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16), // Spazio tra i pulsanti e il bordo inferiore
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
          title: Text('Aggiungi codice evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  // Qui implementa il lettore di QR Code
                  // Usa un pacchetto come 'qr_code_scanner' o 'barcode_scan2'
                  // Per esempio, se usi 'barcode_scan2':
                  var result = await BarcodeScanner.scan();

                  // Se il risultato contiene un valore, aggiornalo nel TextField
                  if (result.rawContent.isNotEmpty) {
                    codeController.text = result.rawContent;
                  }
                },
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Scansiona QR Code'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: codeController,
                maxLength: 8,
                decoration: InputDecoration(
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
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Conferma'),
              onPressed: () {
                if (codeController.text.length == 8) {
                  // Logica per processare il codice inserito
                  print('Codice inserito: ${codeController.text}');
                  Navigator.of(context).pop();
                } else {
                  // Mostra un errore se il codice non è valido
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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

  void _showCreateEventDialog(BuildContext context) {
    TimeOfDay? selectedTime;
    LatLng? location;
    int? duration;
    LatLng? selectedLocation;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Crea Evento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seleziona la data
                  Text(
                    selectedDate == null
                        ? 'Nessuna data selezionata'
                        : '${selectedDate!.toLocal()}'.split(' ')[0],
                  ),
                  SizedBox(height: 10),
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
                          selectedDate = pickedDate; // Aggiorna selectedDate
                        });
                      }
                    },
                    child: Text('Seleziona Data'),
                  ),

                  // Seleziona l'ora
                  SizedBox(height: 10),
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
                    child: Text('Seleziona Ora'),
                  ),
                  if (selectedTime != null)
                    Text('Ora selezionata: ${selectedTime!.format(context)}'),

                  // Seleziona la durata
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(labelText: 'Durata (minuti)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        duration = int.tryParse(value);
                      });
                    },
                  ),

                  // Inserisci il luogo
                  ElevatedButton(
                    onPressed: () async {
                      // Apri la schermata per selezionare la posizione
                      location = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SelectLocationScreen(),
                        ),
                      );

                      if (location != null) {
                        setState(() {
                          selectedLocation = location;
                        });
                      }
                    },
                    child: Text('Seleziona Posizione'),
                  ),
                  if (selectedLocation != null)
                    Text(
                        'Posizione selezionata: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Annulla'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Crea QR Code'),
                  onPressed: selectedDate == null ||
                          selectedTime == null ||
                          // ignore: unnecessary_null_comparison
                          location == null ||
                          duration == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _showQRCode(
                              context,
                              selectedDate!,
                              selectedTime!,
                              duration!,
                              location!); // Passa i dettagli dell'evento
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
  Future<void> createEvent(String email, String code, DateTime selectedDate,
      TimeOfDay timeOfDay, int duration, LatLng location) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/createEvent'),
      );

      // Aggiungi i campi dell'utente
      request.fields['email'] = email;
      request.fields['eventCode'] = code;

      // Formatta la data e l'ora per inviarle al server
      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      String formattedTime = '${timeOfDay.hour}:${timeOfDay.minute}';

      request.fields['eventDate'] = formattedDate;
      request.fields['eventTime'] = formattedTime;
      request.fields['duration'] = duration.toString();
      request.fields['latitudine'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['create'] = "yes";

      // Invia la richiesta e attendi la risposta
      var response = await request.send();

      if (response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        print('Success: $responseData');
      } else {
        print(
            'Failed: ${response.statusCode}, Response: ${await response.stream.bytesToString()}');
      }
    } catch (error) {
      print('Errore durante la creazione dell\'evento: $error');
    }
  }

  void _showQRCode(BuildContext context, DateTime selectedDate,
      TimeOfDay timeOfDay, int duration, LatLng location) {
    String data = _generateRandomString(8);
    createEvent(userEmail!, data, selectedDate, timeOfDay, duration, location);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('QR Code'),
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
                SizedBox(height: 20), // Spazio tra il QR code e il testo
                Text('Condividi il tuo QR Code!'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Condividi'),
              onPressed: () {
                Share.share(data); // Condividi i dettagli dell'evento
              },
            ),
            TextButton(
              child: Text('Chiudi'),
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
