import 'dart:math';

/// Количество каналов EMG
const int numEMGChannels = 8;

/// Количество каналов IMU (gx, gy, gz, ax, ay, az, pitch, roll, yaw)
const int numIMUChannels = 9;

/// Количество точек на графике
const int maxDataPoints = 300;

/// Модель данных EMG/IMU
class EMGData {
  /// Данные EMG (8 каналов)
  final List<List<double>> emgData;
  
  /// Данные IMU (9 каналов)
  final List<List<double>> imuData;
  
  /// Уровень батареи (0-100)
  int battery = 0;
  
  /// Threshold для детекции активации
  int threshold = 2;
  
  /// Сглаживание (0 = выкл, 1-10 = сила)
  int smoothing = 3;

  EMGData()
      : emgData = List.generate(numEMGChannels, (_) => List<double>.filled(maxDataPoints, 0.0, growable: true)),
        imuData = List.generate(numIMUChannels, (_) => List<double>.filled(maxDataPoints, 0.0, growable: true));

  /// Добавляет новые значения EMG
  void addEMGSample(List<double> values) {
    for (int i = 0; i < numEMGChannels && i < values.length; i++) {
      emgData[i].removeAt(0);
      emgData[i].add(values[i]);
    }
  }

  /// Добавляет новые значения IMU
  void addIMUSample(List<double> values) {
    for (int i = 0; i < numIMUChannels && i < values.length; i++) {
      imuData[i].removeAt(0);
      imuData[i].add(values[i]);
    }
  }

  /// Получает данные EMG канала с применением сглаживания
  List<double> getEMGChannel(int channel) {
    if (channel < 0 || channel >= numEMGChannels) return [];
    
    List<double> data = List.from(emgData[channel]);
    if (smoothing > 0) {
      data = _smoothData(data, smoothing * 2 + 1);
    }
    return data;
  }

  /// Получает данные IMU канала с применением сглаживания
  List<double> getIMUChannel(int channel) {
    if (channel < 0 || channel >= numIMUChannels) return [];
    
    List<double> data = List.from(imuData[channel]);
    if (smoothing > 0) {
      data = _smoothData(data, smoothing * 2 + 1);
    }
    return data;
  }

  /// Применяет скользящее среднее
  List<double> _smoothData(List<double> data, int windowSize) {
    if (windowSize <= 1 || data.length < windowSize) return data;
    
    List<double> result = List.from(data);
    for (int i = windowSize - 1; i < data.length; i++) {
      double sum = 0;
      for (int j = 0; j < windowSize; j++) {
        sum += data[i - j];
      }
      result[i] = sum / windowSize;
    }
    return result;
  }

  /// Очищает все данные
  void clear() {
    for (int i = 0; i < numEMGChannels; i++) {
      emgData[i] = List<double>.filled(maxDataPoints, 0.0, growable: true);
    }
    for (int i = 0; i < numIMUChannels; i++) {
      imuData[i] = List<double>.filled(maxDataPoints, 0.0, growable: true);
    }
  }
}

/// Статистика канала
class ChannelStats {
  final double rms;
  final double min;
  final double max;
  final double mean;
  final double peak;

  ChannelStats({
    required this.rms,
    required this.min,
    required this.max,
    required this.mean,
    required this.peak,
  });

  factory ChannelStats.fromData(List<double> data) {
    if (data.isEmpty) {
      return ChannelStats(rms: 0, min: 0, max: 0, mean: 0, peak: 0);
    }

    double sum = 0;
    double sumSq = 0;
    double minVal = data[0];
    double maxVal = data[0];

    for (final v in data) {
      sum += v;
      sumSq += v * v;
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    final meanVal = sum / data.length;
    final rmsVal = sqrt(sumSq / data.length);
    final peakVal = minVal.abs() > maxVal.abs() ? minVal.abs() : maxVal.abs();

    return ChannelStats(
      rms: rmsVal,
      min: minVal,
      max: maxVal,
      mean: meanVal,
      peak: peakVal,
    );
  }
}
