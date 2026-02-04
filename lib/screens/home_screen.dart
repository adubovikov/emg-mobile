import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../services/data_recorder.dart';
import '../services/fft_analyzer.dart';
import '../widgets/chart_widget.dart';
import '../models/emg_data.dart';

/// Цвета для каналов EMG
const List<Color> emgColors = [
  Color(0xFF00C864), // Зелёный
  Color(0xFF64C8FF), // Голубой
  Color(0xFFFFC864), // Оранжевый
  Color(0xFFFF6464), // Красный
  Color(0xFFC864FF), // Фиолетовый
  Color(0xFFFFFF64), // Жёлтый
  Color(0xFF64FFC8), // Бирюзовый
  Color(0xFFFF96C8), // Розовый
];

/// Цвета для IMU
const List<Color> imuGyroColors = [
  Color(0xFFFF6464), // GyroX - красный
  Color(0xFF64FF64), // GyroY - зелёный
  Color(0xFF6464FF), // GyroZ - синий
];

const List<Color> imuAccColors = [
  Color(0xFFFF9696), // AccX
  Color(0xFF96FF96), // AccY
  Color(0xFF9696FF), // AccZ
];

const List<Color> imuAngleColors = [
  Color(0xFFFFC864), // Pitch
  Color(0xFF64FFC8), // Roll
  Color(0xFFC864FF), // Yaw
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FFTAnalyzer _fftAnalyzer = FFTAnalyzer();
  int _selectedSpectrumChannel = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Подписываемся на обновления данных
    final bleService = context.read<BleService>();
    final recorder = context.read<DataRecorder>();

    bleService.onDataUpdate = () {
      if (mounted) setState(() {});
    };

    // Интегрируем запись данных
    bleService.onRecordSample = (emgValues, imuValues, battery) {
      recorder.addSample(
        emgValues: emgValues,
        imuValues: imuValues,
        battery: battery,
      );
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Sichiray EMG Monitor'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'EMG'),
            Tab(text: 'IMU'),
            Tab(text: 'FFT'),
            Tab(text: 'Stats'),
          ],
        ),
        actions: [
          _buildRecordButton(),
          _buildConnectionButton(),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEMGTab(),
                _buildIMUTab(),
                _buildFFTTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return Consumer<DataRecorder>(
      builder: (context, recorder, _) {
        return Row(
          children: [
            if (recorder.isRecording) ...[
              // Индикатор записи
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              const SizedBox(width: 4),
              Text(
                '${recorder.samplesCount}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: Icon(
                recorder.isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: recorder.isRecording ? Colors.white : Colors.red,
              ),
              onPressed: () async {
                if (recorder.isRecording) {
                  final filePath = await recorder.stopRecording();
                  if (filePath != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Записано: ${filePath.split('/').last}'),
                        action: SnackBarAction(
                          label: 'Поделиться',
                          onPressed: () => recorder.shareLastRecording(),
                        ),
                      ),
                    );
                  }
                } else {
                  recorder.startRecording();
                }
              },
              tooltip: recorder.isRecording ? 'Остановить запись' : 'Начать запись',
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionButton() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        return Row(
          children: [
            if (bleService.isConnected)
              IconButton(
                icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
                onPressed: () => bleService.disconnect(),
                tooltip: 'Отключить',
              )
            else
              IconButton(
                icon: Icon(
                  bleService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                  color: bleService.isScanning ? Colors.blue : Colors.grey,
                ),
                onPressed: () => _showDeviceDialog(context),
                tooltip: 'Подключить',
              ),
          ],
        );
      },
    );
  }

  Widget _buildInfoBar() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        final data = bleService.emgData;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A1A24),
          child: Row(
            children: [
              // Статус подключения
              Icon(
                bleService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: bleService.isConnected ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                bleService.isConnected ? 'Подключено' : 'Отключено',
                style: TextStyle(
                  color: bleService.isConnected ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),

              // Батарея
              if (bleService.isConnected) ...[
                Icon(Icons.battery_full, color: Colors.grey[400], size: 20),
                const SizedBox(width: 4),
                Text(
                  '${data.battery}%',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(width: 16),
              ],

              const Spacer(),

              // Углы IMU
              if (bleService.isConnected) ...[
                Text(
                  'P: ${data.imuData[6].last.toStringAsFixed(1)}°',
                  style: TextStyle(color: imuAngleColors[0], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'R: ${data.imuData[7].last.toStringAsFixed(1)}°',
                  style: TextStyle(color: imuAngleColors[1], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'Y: ${data.imuData[8].last.toStringAsFixed(1)}°',
                  style: TextStyle(color: imuAngleColors[2], fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEMGTab() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        final data = bleService.emgData;
        final threshold = data.threshold * 10.0;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numEMGChannels,
            itemBuilder: (context, index) {
              return SignalChart(
                title: 'EMG Ch${index + 1}',
                data: data.getEMGChannel(index),
                lineColor: emgColors[index],
                threshold: threshold,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIMUTab() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        final data = bleService.emgData;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Гироскоп
              Expanded(
                child: Column(
                  children: [
                    Text('Gyroscope', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'GyroX',
                        data: data.getIMUChannel(0),
                        lineColor: imuGyroColors[0],
                        minY: 0,
                        maxY: 300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'GyroY',
                        data: data.getIMUChannel(1),
                        lineColor: imuGyroColors[1],
                        minY: 0,
                        maxY: 300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'GyroZ',
                        data: data.getIMUChannel(2),
                        lineColor: imuGyroColors[2],
                        minY: 0,
                        maxY: 300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Акселерометр
              Expanded(
                child: Column(
                  children: [
                    Text('Accelerometer', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'AccX',
                        data: data.getIMUChannel(3),
                        lineColor: imuAccColors[0],
                        minY: 47,
                        maxY: 207,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'AccY',
                        data: data.getIMUChannel(4),
                        lineColor: imuAccColors[1],
                        minY: 47,
                        maxY: 207,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'AccZ',
                        data: data.getIMUChannel(5),
                        lineColor: imuAccColors[2],
                        minY: 47,
                        maxY: 207,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Углы
              Expanded(
                child: Column(
                  children: [
                    Text('Angles', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'Pitch',
                        data: data.getIMUChannel(6),
                        lineColor: imuAngleColors[0],
                        minY: -180,
                        maxY: 180,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'Roll',
                        data: data.getIMUChannel(7),
                        lineColor: imuAngleColors[1],
                        minY: -180,
                        maxY: 180,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SignalChart(
                        title: 'Yaw',
                        data: data.getIMUChannel(8),
                        lineColor: imuAngleColors[2],
                        minY: -180,
                        maxY: 180,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFFTTab() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        final data = bleService.emgData;

        // Вычисляем спектр для выбранного канала
        final channelData = data.emgData[_selectedSpectrumChannel];
        final spectrum = _fftAnalyzer.computeSpectrum(channelData);

        // Находим метрики спектра
        final dominant = _fftAnalyzer.findDominantFrequency(spectrum);
        final medianFreq = _fftAnalyzer.computeMedianFrequency(spectrum);
        final meanFreq = _fftAnalyzer.computeMeanFrequency(spectrum);

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Выбор канала
              Row(
                children: [
                  Text('Канал: ', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(numEMGChannels, (index) {
                          final isSelected = index == _selectedSpectrumChannel;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text('${index + 1}'),
                              selected: isSelected,
                              selectedColor: emgColors[index],
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedSpectrumChannel = index);
                                }
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Спектр
              Expanded(
                flex: 3,
                child: SpectrumChart(
                  title: 'Spectrum EMG Ch${_selectedSpectrumChannel + 1}',
                  frequencies: spectrum.map((bin) => bin.frequency).toList(),
                  magnitudes: spectrum.map((bin) => bin.magnitude).toList(),
                  barColor: emgColors[_selectedSpectrumChannel],
                ),
              ),

              const SizedBox(height: 8),

              // Частотные метрики
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFreqMetric('Dominant', dominant?.frequency ?? 0, 'Hz'),
                    _buildFreqMetric('Median', medianFreq, 'Hz'),
                    _buildFreqMetric('Mean', meanFreq, 'Hz'),
                    _buildFreqMetric('EMG Band', 
                      _fftAnalyzer.computeBandPower(spectrum, 20, 150), 'pwr'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Частотные диапазоны
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    _buildBandPowerIndicator(
                      'Low (0-20Hz)',
                      _fftAnalyzer.computeBandPower(spectrum, 0, 20),
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildBandPowerIndicator(
                      'EMG (20-150Hz)',
                      _fftAnalyzer.computeBandPower(spectrum, 20, 150),
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildBandPowerIndicator(
                      'High (150-250Hz)',
                      _fftAnalyzer.computeBandPower(spectrum, 150, 250),
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFreqMetric(String label, double value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBandPowerIndicator(String label, double power, Color color) {
    // Нормализуем мощность для визуализации (логарифмическая шкала)
    final normalizedPower = power > 0 ? (power.clamp(0.01, 1000) / 1000) : 0.0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: normalizedPower.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              power.toStringAsFixed(2),
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        final data = bleService.emgData;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Заголовок таблицы
              Row(
                children: [
                  const Expanded(flex: 2, child: Text('Channel', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('RMS', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('Min/Max', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('Mean', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(),
              // Строки данных
              Expanded(
                child: ListView.builder(
                  itemCount: numEMGChannels,
                  itemBuilder: (context, index) {
                    final channelData = data.getEMGChannel(index);
                    final stats = ChannelStats.fromData(channelData);
                    final isActive = stats.rms > data.threshold * 10;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? emgColors[index].withValues(alpha: 0.2) : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: emgColors[index],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('EMG ${index + 1}'),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                if (isActive) const Text('▲ ', style: TextStyle(color: Colors.green)),
                                Text(stats.rms.toStringAsFixed(1)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${stats.min.toStringAsFixed(0)} / ${stats.max.toStringAsFixed(0)}'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(stats.mean.toStringAsFixed(1)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Настройки
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Threshold: ${data.threshold}'),
                        Slider(
                          value: data.threshold.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => data.threshold = value.toInt());
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smoothing: ${data.smoothing == 0 ? "OFF" : data.smoothing}'),
                        Slider(
                          value: data.smoothing.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => data.smoothing = value.toInt());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DeviceSelectDialog(),
    );
  }
}

class _DeviceSelectDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, bleService, _) {
        return AlertDialog(
          title: const Text('BLE Устройства'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                // Кнопка сканирования
                ElevatedButton.icon(
                  onPressed: bleService.isScanning ? null : () => bleService.startScan(),
                  icon: Icon(bleService.isScanning ? Icons.stop : Icons.search),
                  label: Text(bleService.isScanning ? 'Сканирование...' : 'Сканировать'),
                ),
                const SizedBox(height: 16),

                // Список устройств
                Expanded(
                  child: bleService.scanResults.isEmpty
                      ? Center(
                          child: Text(
                            bleService.isScanning ? 'Поиск устройств...' : 'Нажмите "Сканировать"',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: bleService.scanResults.length,
                          itemBuilder: (context, index) {
                            final result = bleService.scanResults[index];
                            final name = result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : 'Unknown';

                            return ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(name),
                              subtitle: Text('${result.device.remoteId}\nRSSI: ${result.rssi}'),
                              onTap: () async {
                                Navigator.of(context).pop();
                                final success = await bleService.connect(result.device);
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ошибка подключения')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}
