import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'protocol.dart';
import '../models/emg_data.dart';

/// BLE UUID для HM-10/HM-11 модуля (Sichiray EMG)
class BleUuids {
  static const String service = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String notifyChar = "0000ffe2-0000-1000-8000-00805f9b34fb";
  static const String writeChar = "0000ffe1-0000-1000-8000-00805f9b34fb";
  static const String altNotifyChar = "0000ff03-0000-1000-8000-00805f9b34fb";
}

/// Сервис для BLE подключения
class BleService extends ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;

  final List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  StreamSubscription<List<int>>? _dataSubscription;
  late SichirayProtocol _protocol;
  final EMGData emgData = EMGData();

  VoidCallback? onDataUpdate;
  void Function(List<int> emgValues, List<double> imuValues, int battery)? onRecordSample;

  int _bytesReceived = 0;
  int get bytesReceived => _bytesReceived;

  BleService() {
    _protocol = SichirayProtocol(onData: _onProtocolData);
  }

  Future<bool> checkPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.locationWhenInUse.request();
      return bluetoothScan.isGranted && bluetoothConnect.isGranted && location.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bluetooth = await Permission.bluetooth.request();
      return bluetooth.isGranted;
    }
    return true;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isScanning) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      
      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final exists = _scanResults.any((sr) => sr.device.remoteId == r.device.remoteId);
          if (!exists) {
            _scanResults.add(r);
            notifyListeners();
          }
        }
      });
    } catch (_) {}

    await Future.delayed(timeout);
    _isScanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnected) await disconnect();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;

      final services = await device.discoverServices();
      BluetoothCharacteristic? notifyChar;

      // Ищем FFE2 (приоритет) или FF03
      for (final service in services) {
        for (final char in service.characteristics) {
          final charUuid = char.uuid.toString().toLowerCase();
          
          if (charUuid.contains('ffe2') && char.properties.notify) {
            notifyChar = char;
            break;
          }
          
          if (charUuid.contains('ff03') && char.properties.notify && notifyChar == null) {
            notifyChar = char;
          }
        }
        if (notifyChar != null) break;
      }

      // Fallback - любая notify характеристика
      if (notifyChar == null) {
        for (final service in services) {
          for (final char in service.characteristics) {
            if (char.properties.notify) {
              notifyChar = char;
              break;
            }
          }
          if (notifyChar != null) break;
        }
      }

      if (notifyChar == null) {
        await device.disconnect();
        return false;
      }

      await notifyChar.setNotifyValue(true);
      _dataSubscription = notifyChar.onValueReceived.listen(_onBleData);

      // Подписываемся на дополнительные характеристики
      for (final service in services) {
        for (final char in service.characteristics) {
          final charUuid = char.uuid.toString().toLowerCase();
          if (char != notifyChar && char.properties.notify) {
            if (charUuid.contains('ffe2') || charUuid.contains('ff03') || charUuid.contains('ffe1')) {
              try {
                await char.setNotifyValue(true);
                char.onValueReceived.listen(_onBleData);
              } catch (_) {}
            }
          }
        }
      }

      _isConnected = true;
      _protocol.clear();
      _bytesReceived = 0;
      notifyListeners();
      return true;
    } catch (_) {
      _device = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _isConnected = false;
    notifyListeners();
  }

  void _onBleData(List<int> data) {
    _bytesReceived += data.length;
    _protocol.processData(data);
  }

  void _onProtocolData(List<double> emg, List<double> imu, int battery) {
    emgData.addEMGSample(emg);
    emgData.addIMUSample(imu);
    emgData.battery = battery;
    
    final emgInts = emg.map((e) => e.toInt()).toList();
    onRecordSample?.call(emgInts, imu, battery);
    
    onDataUpdate?.call();
  }

  void clearData() {
    emgData.clear();
    _protocol.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
