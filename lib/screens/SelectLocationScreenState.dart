import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({Key? key}) : super(key: key);

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  GoogleMapController? _controller;
  LatLng? selectedLocation;
  LatLng? currentLocation;
  String host = "127.0.0.1:5000";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permessi per la posizione negati.')),
        );
        return;
      }
    }

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'I permessi per la posizione sono disabilitati. Abilitali nelle impostazioni.'),
          action: SnackBarAction(
            label: 'Impostazioni',
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_controller != null) {
        _controller!.animateCamera(CameraUpdate.newLatLng(currentLocation!));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nell\'ottenere la posizione: $e')),
      );
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
      appBar: AppBar(title: const Text('Mappa')),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: currentLocation!,
                zoom: 12.0,
              ),
              markers: _createMarkers(),
              onTap: (LatLng location) {
                setState(() {
                  selectedLocation = location;
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  Navigator.pop(context, location);
                });
              },
            ),
    );
  }

  Set<Marker> _createMarkers() {
    return {
      if (currentLocation != null)
        Marker(
          markerId: const MarkerId('current-location'),
          position: currentLocation!,
          infoWindow: const InfoWindow(title: 'Posizione Attuale'),
        ),
      if (selectedLocation != null)
        Marker(
          markerId: const MarkerId('selected-location'),
          position: selectedLocation!,
          infoWindow: const InfoWindow(title: 'Posizione Selezionata'),
        ),
    };
  }
}
