import 'dart:async';
import 'package:geolocator/geolocator.dart';

class GpsService {
  static final GpsService _instance = GpsService._();
  factory GpsService() => _instance;
  GpsService._();

  StreamSubscription<Position>? _sub;
  Position? _current;
  Position? get current => _current;

  final _posCtrl = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _posCtrl.stream;

  bool _running = false;
  bool get isRunning => _running;
  String _status = "GPS not started";
  String get status => _status;

  Future<void> start() async {
    if (_running) return;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _status = "Enable location services";
        return;
      }

      // First fix
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _current = pos;
        _posCtrl.add(pos);
      } catch (_) {}

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );

      _sub = Geolocator.getPositionStream(locationSettings: settings)
          .listen((pos) {
        _current = pos;
        _status =
            "${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";
        _posCtrl.add(pos);
      }, onError: (e) {
        _status = "GPS error";
      });

      _running = true;
      _status = "GPS ready";
    } catch (e) {
      _status = "GPS unavailable";
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
    _status = "GPS stopped";
  }

  void dispose() {
    stop();
    _posCtrl.close();
  }
}