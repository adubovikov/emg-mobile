import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import '../models/emg_data.dart';

/// Сервис для FFT анализа EMG сигналов
class FFTAnalyzer {
  static const int fftSize = 256;
  static const double sampleRate = 500.0; // Hz - примерная частота сэмплирования

  late final FFT _fft;
  late final Float64List _window;

  FFTAnalyzer() {
    _fft = FFT(fftSize);
    _window = _createHannWindow(fftSize);
  }

  /// Создание окна Ханна для уменьшения спектральной утечки
  Float64List _createHannWindow(int size) {
    final window = Float64List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));
    }
    return window;
  }

  /// Вычислить спектр для одного канала
  /// Возвращает список (частота, амплитуда) пар
  List<FrequencyBin> computeSpectrum(List<double> data) {
    if (data.length < fftSize) {
      return [];
    }

    // Берём последние fftSize сэмплов
    final samples = data.sublist(data.length - fftSize);

    // Применяем окно и конвертируем в Float64x2
    final input = Float64x2List(fftSize);
    for (int i = 0; i < fftSize; i++) {
      input[i] = Float64x2(samples[i] * _window[i], 0);
    }

    // Выполняем FFT
    _fft.inPlaceFft(input);

    // Вычисляем амплитуды для положительных частот
    final result = <FrequencyBin>[];
    final halfSize = fftSize ~/ 2;
    final frequencyResolution = sampleRate / fftSize;

    for (int i = 0; i < halfSize; i++) {
      final real = input[i].x;
      final imag = input[i].y;
      final magnitude = math.sqrt(real * real + imag * imag) / fftSize;
      final frequency = i * frequencyResolution;

      result.add(FrequencyBin(
        frequency: frequency,
        magnitude: magnitude,
      ));
    }

    return result;
  }

  /// Вычислить спектры для всех EMG каналов
  List<List<FrequencyBin>> computeAllSpectra(EMGData emgData) {
    final result = <List<FrequencyBin>>[];

    for (int ch = 0; ch < numEMGChannels; ch++) {
      final channelData = emgData.emgData[ch];
      result.add(computeSpectrum(channelData));
    }

    return result;
  }

  /// Найти доминирующую частоту
  FrequencyBin? findDominantFrequency(List<FrequencyBin> spectrum) {
    if (spectrum.isEmpty) return null;

    // Пропускаем DC компоненту (0 Hz)
    FrequencyBin? dominant;
    double maxMagnitude = 0;

    for (int i = 1; i < spectrum.length; i++) {
      if (spectrum[i].magnitude > maxMagnitude) {
        maxMagnitude = spectrum[i].magnitude;
        dominant = spectrum[i];
      }
    }

    return dominant;
  }

  /// Вычислить мощность в частотном диапазоне
  double computeBandPower(List<FrequencyBin> spectrum, double lowFreq, double highFreq) {
    double power = 0;

    for (final bin in spectrum) {
      if (bin.frequency >= lowFreq && bin.frequency <= highFreq) {
        power += bin.magnitude * bin.magnitude;
      }
    }

    return power;
  }

  /// Вычислить медианную частоту
  double computeMedianFrequency(List<FrequencyBin> spectrum) {
    if (spectrum.isEmpty) return 0;

    // Вычисляем общую мощность
    double totalPower = 0;
    for (final bin in spectrum) {
      totalPower += bin.magnitude * bin.magnitude;
    }

    if (totalPower == 0) return 0;

    // Находим частоту, при которой накоплено 50% мощности
    double cumulativePower = 0;
    for (final bin in spectrum) {
      cumulativePower += bin.magnitude * bin.magnitude;
      if (cumulativePower >= totalPower / 2) {
        return bin.frequency;
      }
    }

    return spectrum.last.frequency;
  }

  /// Вычислить среднюю частоту (mean frequency)
  double computeMeanFrequency(List<FrequencyBin> spectrum) {
    if (spectrum.isEmpty) return 0;

    double weightedSum = 0;
    double totalMagnitude = 0;

    for (final bin in spectrum) {
      weightedSum += bin.frequency * bin.magnitude;
      totalMagnitude += bin.magnitude;
    }

    if (totalMagnitude == 0) return 0;
    return weightedSum / totalMagnitude;
  }
}

/// Структура для хранения частотного бина
class FrequencyBin {
  final double frequency;
  final double magnitude;

  const FrequencyBin({
    required this.frequency,
    required this.magnitude,
  });
}

/// Типичные частотные диапазоны для EMG анализа
class EMGFrequencyBands {
  /// Низкие частоты (артефакты движения, обычно фильтруются)
  static const double lowArtifactLow = 0;
  static const double lowArtifactHigh = 20;

  /// Основной EMG диапазон
  static const double emgLow = 20;
  static const double emgHigh = 150;

  /// Высокочастотный EMG
  static const double highEmgLow = 150;
  static const double highEmgHigh = 250;

  /// Частота сетевой наводки (для notch фильтра)
  static const double powerLine50 = 50;
  static const double powerLine60 = 60;
}
