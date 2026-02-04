import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../models/emg_data.dart';

/// Сервис для записи EMG данных в CSV файлы
class DataRecorder extends ChangeNotifier {
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  final List<RecordedSample> _samples = [];
  String? _lastFilePath;

  bool get isRecording => _isRecording;
  DateTime? get recordingStartTime => _recordingStartTime;
  int get samplesCount => _samples.length;
  String? get lastFilePath => _lastFilePath;

  /// Начать запись
  void startRecording() {
    _samples.clear();
    _recordingStartTime = DateTime.now();
    _isRecording = true;
    notifyListeners();
  }

  /// Добавить сэмпл
  void addSample({
    required List<int> emgValues,
    required List<double> imuValues,
    required int battery,
  }) {
    if (!_isRecording) return;

    _samples.add(RecordedSample(
      timestamp: DateTime.now(),
      emgValues: List.from(emgValues),
      imuValues: List.from(imuValues),
      battery: battery,
    ));

    // Уведомляем только каждые 100 сэмплов для производительности
    if (_samples.length % 100 == 0) {
      notifyListeners();
    }
  }

  /// Остановить запись и сохранить файл
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    notifyListeners();

    if (_samples.isEmpty) {
      return null;
    }

    try {
      final filePath = await _saveToCSV();
      _lastFilePath = filePath;
      notifyListeners();
      return filePath;
    } catch (e) {
      debugPrint('Error saving CSV: $e');
      return null;
    }
  }

  /// Сохранить данные в CSV
  Future<String> _saveToCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _recordingStartTime?.toIso8601String().replaceAll(':', '-') ??
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'emg_recording_$timestamp.csv';
    final filePath = '${directory.path}/$fileName';

    // Создаём заголовки
    final headers = [
      'timestamp',
      'elapsed_ms',
      ...List.generate(numEMGChannels, (i) => 'emg_ch${i + 1}'),
      'gyro_x', 'gyro_y', 'gyro_z',
      'accel_x', 'accel_y', 'accel_z',
      'angle_x', 'angle_y', 'angle_z',
      'battery',
    ];

    // Создаём строки данных
    final rows = <List<dynamic>>[headers];

    for (final sample in _samples) {
      final elapsedMs = sample.timestamp.difference(_recordingStartTime!).inMilliseconds;

      final row = <dynamic>[
        sample.timestamp.toIso8601String(),
        elapsedMs,
        ...sample.emgValues,
        ...sample.imuValues,
        sample.battery,
      ];

      rows.add(row);
    }

    // Конвертируем в CSV
    const converter = ListToCsvConverter();
    final csvString = converter.convert(rows);

    // Записываем файл
    final file = File(filePath);
    await file.writeAsString(csvString);

    return filePath;
  }

  /// Поделиться последним записанным файлом
  Future<void> shareLastRecording() async {
    if (_lastFilePath == null) return;

    final file = File(_lastFilePath!);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(_lastFilePath!)],
        subject: 'EMG Recording',
      );
    }
  }

  /// Получить список всех записей
  Future<List<FileSystemEntity>> getRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((f) => f.path.endsWith('.csv') && f.path.contains('emg_recording'))
        .toList();

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Удалить запись
  Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
    return false;
  }

  /// Очистить все данные
  void clear() {
    _samples.clear();
    _recordingStartTime = null;
    _isRecording = false;
    notifyListeners();
  }
}

/// Структура для записанного сэмпла
class RecordedSample {
  final DateTime timestamp;
  final List<int> emgValues;
  final List<double> imuValues;
  final int battery;

  RecordedSample({
    required this.timestamp,
    required this.emgValues,
    required this.imuValues,
    required this.battery,
  });
}
