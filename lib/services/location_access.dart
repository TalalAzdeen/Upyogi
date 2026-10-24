import 'package:geolocator/geolocator.dart';

class LocationAccess {
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Enable location services and try again.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) throw StateError('Location permission is blocked. Enable it in app settings.');
    if (permission == LocationPermission.denied) throw StateError('Location permission was denied. You can choose a point on the map.');
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
  }
}
