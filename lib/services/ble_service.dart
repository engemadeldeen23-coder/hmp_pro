import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ============================================================
//  BLE SERVICE (Singleton) - wraps the ESP32 communication
// ============================================================
class BleService {
  static final BleService _instance = BleService._();
  factory BleService() => _instance;
  BleService._();

  static const String serviceUuid =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String characteristicUuid =
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String deviceName = "LWD-PROBE";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  StreamSubscription<List<int>>? _sub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  final _statusCtrl = StreamController<String>.broadcast();
  final _dataCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _connCtrl = StreamController<bool>.broadcast();

  Stream<String> get statusStream => _statusCtrl.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataCtrl.stream;
  Stream<bool> get connectionStream => _connCtrl.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  DateTime? _lastHeartbeat;
  bool get isAlive =>
      _lastHeartbeat != null &&
      DateTime.now().difference(_lastHeartbeat!).inSeconds < 15;

  // ------- Scan & Connect -------
  Future<bool> scanAndConnect() async {
    try {
      _statusCtrl.add("Scanning...");
      if (!await FlutterBluePlus.isOn) {
        _statusCtrl.add("Bluetooth OFF");
        return false;
      }

      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));

      BluetoothDevice? found;
      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final n = r.device.platformName;
          final an = r.advertisementData.advName;
          if ((n.contains("LWD") || an.contains("LWD")) && found == null) {
            found = r.device;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 11));
      await sub.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      if (found == null) {
        _statusCtrl.add("Not found");
        return false;
      }

      return await _connect(found!);
    } catch (e) {
      _statusCtrl.add("Scan error: $e");
      return false;
    }
  }

  Future<bool> _connect(BluetoothDevice device) async {
    _statusCtrl.add("Connecting...");
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await device.connect(timeout: const Duration(seconds: 15));
        await Future.delayed(const Duration(milliseconds: 700));

        final services = await device.discoverServices();
        BluetoothCharacteristic? target;
        for (final s in services) {
          for (final c in s.characteristics) {
            final u = c.uuid.toString().toLowerCase().replaceAll('-', '');
            if (u == "6e400002b5a3f393e0a9e50e24dcca9e") target = c;
          }
        }
        if (target == null) throw Exception("Characteristic not found");

        _device = device;
        _rx = target;
        await target.setNotifyValue(true);

        _sub = target.onValueReceived.listen((v) {
          if (v.isEmpty) return;
          try {
            final t = utf8.decode(v, allowMalformed: true);
            _handleData(t);
          } catch (_) {}
        }, onError: (e) => print("BLE stream error: $e"));

        _stateSub = device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _connected = false;
            _connCtrl.add(false);
            _statusCtrl.add("Disconnected");
          }
        });

        _connected = true;
        _connCtrl.add(true);
        _statusCtrl.add("Online");
        return true;
      } catch (e) {
        if (attempt < 3) {
          try {
            await device.disconnect();
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    _connected = false;
    _connCtrl.add(false);
    _statusCtrl.add("Failed");
    return false;
  }

  void _handleData(String raw) {
    try {
      final t = raw.trim();
      if (!t.startsWith("{")) return;
      final m = jsonDecode(t) as Map<String, dynamic>;
      _lastHeartbeat = DateTime.now();
      _dataCtrl.add(m);
    } catch (e) {
      print("Parse error: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await _sub?.cancel();
      await _stateSub?.cancel();
      await _device?.disconnect();
    } catch (_) {}
    _sub = null;
    _stateSub = null;
    _device = null;
    _rx = null;
    _connected = false;
    _connCtrl.add(false);
    _statusCtrl.add("Disconnected");
  }

  void dispose() {
    disconnect();
    _statusCtrl.close();
    _dataCtrl.close();
    _connCtrl.close();
  }
}