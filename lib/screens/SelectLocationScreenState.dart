import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    var status = await Permission.locationWhenInUse.request();

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
    final localizations = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(localizations.location_permission_title),
        content: Text(localizations.location_permission_required_message),
        actions: [
          CupertinoDialogAction(
            child: Text(localizations.ok),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  void _showPermanentDeniedDialog() {
    final localizations = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(localizations.location_permission_disabled_title),
        content:
            Text(localizations.location_permission_permanent_denied_message),
        actions: [
          CupertinoDialogAction(
            child: Text(localizations.settings),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
          CupertinoDialogAction(
            child: Text(localizations.cancel),
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
    final localizations = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(localizations.location_error_title),
        content: Text('${localizations.location_error_message}: $error'),
        actions: [
          CupertinoDialogAction(
            child: Text(localizations.ok),
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
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.select_location)),
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
                  localizations.loading_location,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _createMarkers() {
    final localizations = AppLocalizations.of(context)!;
    return {
      if (currentLocation != null)
        Marker(
          markerId: const MarkerId('current-location'),
          position: currentLocation!,
          infoWindow: InfoWindow(title: localizations.current_location),
        ),
      if (selectedLocation != null)
        Marker(
          markerId: const MarkerId('selected-location'),
          position: selectedLocation!,
          infoWindow: InfoWindow(title: localizations.selected_location),
        ),
    };
  }
}
