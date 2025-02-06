import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  Future<void> _checkLocationPermissionAndGetLocation() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isDenied) {
      _showPermissionDeniedDialog();
      return;
    }

    if (status.isPermanentlyDenied) {
      _showPermanentDeniedDialog();
      return;
    }

    _getCurrentLocation();
  }

  void _showPermissionDeniedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Permessi Localizzazione'),
        content: const Text(
            'Abbiamo bisogno dei permessi di localizzazione per continuare'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  void _showPermanentDeniedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Permessi Disabilitati'),
        content: const Text(
            'Per favore, abilita i permessi di localizzazione nelle impostazioni'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Impostazioni'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      _controller?.animateCamera(CameraUpdate.newLatLng(currentLocation!));
    } catch (e) {
      _showLocationErrorDialog(e.toString());
    }
  }

  void _showLocationErrorDialog(String error) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Errore Posizione'),
        content: Text('Impossibile ottenere la posizione: $error'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
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
      appBar: AppBar(title: const Text('Seleziona Posizione')),
      body: Stack(
        children: [
          currentLocation == null
              ? const Center(child: CupertinoActivityIndicator())
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
          if (currentLocation == null)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Caricamento posizione...',
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
            ),
        ],
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
