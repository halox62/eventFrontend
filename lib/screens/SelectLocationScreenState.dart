import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SelectLocationScreen extends StatefulWidget {
  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  GoogleMapController? _controller;
  LatLng? selectedLocation; // Posizione selezionata
  LatLng? currentLocation; // Posizione corrente

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Chiamata per ottenere la posizione all'inizio
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) return; // Esci se i permessi vengono negati
    }

    // ignore: deprecated_member_use
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    // Anima la mappa sulla posizione attuale se il controller è disponibile
    if (_controller != null) {
      _controller!.animateCamera(CameraUpdate.newLatLng(currentLocation!));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    if (currentLocation != null) {
      _controller?.animateCamera(CameraUpdate.newLatLng(currentLocation!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mappa')),
      body: currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: currentLocation!,
                zoom: 12.0,
              ),
              markers: _createMarkers(),
              onTap: (LatLng location) {
                // Chiudi la mappa e ritorna la posizione selezionata
                Navigator.pop(context, location);
              },
            ),
    );
  }

  // Funzione per creare i marcatori
  Set<Marker> _createMarkers() {
    final markers = <Marker>{};

    // Aggiungi un marcatore per la posizione corrente
    if (currentLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('current-location'),
          position: currentLocation!,
          infoWindow: InfoWindow(title: 'Posizione Attuale'),
        ),
      );
    }

    // Aggiungi un marcatore per la posizione selezionata
    if (selectedLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('selected-location'),
          position: selectedLocation!,
          infoWindow: InfoWindow(title: 'Posizione Selezionata'),
        ),
      );
    }

    return markers;
  }
}
