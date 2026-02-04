import 'dart:typed_data';
import '../models/emg_data.dart';

/// Парсер протокола Sichiray EMG
/// 
/// Формат пакета:
/// [0:2]   AA AA    - заголовок
/// [2]     5F       - длина (95)
/// [3:7]   timestamp (4 байта)
/// [7:16]  IMU (9 байт): gx, gy, gz, ax, ay, az, pitch, roll, yaw
/// [16:96] EMG (80 байт = 8 каналов × 10 семплов)
/// [96]    battery
/// [97]    0x55     - checksum
class SichirayProtocol {
  /// Буфер для сборки пакетов
  final List<int> _buffer = [];

  /// Callback при получении данных
  final void Function(List<double> emg, List<double> imu, int battery)? onData;

  /// Счётчик пакетов
  int packetCount = 0;

  SichirayProtocol({this.onData});

  /// Обрабатывает входящие данные BLE
  void processData(List<int> data) {
    _buffer.addAll(data);
    _parsePackets();
  }

  /// Очищает буфер
  void clear() {
    _buffer.clear();
    packetCount = 0;
  }

  /// Парсит пакеты из буфера
  void _parsePackets() {
    while (_buffer.length >= 100) {
      // Ищем заголовок AA AA 5F
      int headerIdx = -1;
      for (int i = 0; i <= _buffer.length - 4; i++) {
        if (_buffer[i] == 0xAA && _buffer[i + 1] == 0xAA && _buffer[i + 2] == 0x5F) {
          headerIdx = i;
          break;
        }
      }

      if (headerIdx == -1) {
        // Заголовок не найден, оставляем последние 3 байта
        if (_buffer.length > 3) {
          _buffer.removeRange(0, _buffer.length - 3);
        }
        break;
      }

      // Удаляем данные до заголовка
      if (headerIdx > 0) {
        _buffer.removeRange(0, headerIdx);
      }

      // Ищем следующий заголовок для определения конца пакета
      int nextHeader = -1;
      for (int i = 4; i <= _buffer.length - 3; i++) {
        if (_buffer[i] == 0xAA && _buffer[i + 1] == 0xAA && _buffer[i + 2] == 0x5F) {
          nextHeader = i;
          break;
        }
      }

      if (nextHeader == -1 || nextHeader < 98) {
        // Недостаточно данных для полного пакета
        break;
      }

      // Проверяем checksum
      if (_buffer[97] == 0x55) {
        packetCount++;
        _parseValidPacket(Uint8List.fromList(_buffer.sublist(0, nextHeader)));
      }

      // Удаляем обработанный пакет
      _buffer.removeRange(0, nextHeader);
    }
  }

  /// Парсит валидный пакет
  void _parseValidPacket(Uint8List packet) {
    // IMU данные: offset 7, 9 байт
    List<double> imu = [];
    for (int i = 0; i < numIMUChannels; i++) {
      double rawVal = packet[7 + i].toDouble();
      double val;
      if (i < 6) {
        // Gyro и Accel - unsigned 0-255
        val = rawVal;
      } else {
        // Углы: преобразуем в градусы
        val = (rawVal - 127.0) * 180.0 / 127.0;
      }
      imu.add(val);
    }

    // EMG данные: offset 16, 80 байт
    List<double> emg = [];
    for (int ch = 0; ch < numEMGChannels; ch++) {
      double sum = 0;
      for (int sample = 0; sample < 10; sample++) {
        int idx = 16 + sample * 8 + ch;
        if (idx < packet.length) {
          sum += packet[idx].toDouble() - 127.0;
        }
      }
      emg.add(sum / 10.0);
    }

    // Battery
    int battery = packet[96];

    // Callback
    onData?.call(emg, imu, battery);
  }
}
