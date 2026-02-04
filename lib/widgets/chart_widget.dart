import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Виджет графика для отображения данных EMG/IMU
class SignalChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color lineColor;
  final double? minY;
  final double? maxY;
  final double? threshold;

  const SignalChart({
    super.key,
    required this.title,
    required this.data,
    required this.lineColor,
    this.minY,
    this.maxY,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              if (data.isNotEmpty)
                Text(
                  data.last.toStringAsFixed(1),
                  style: TextStyle(
                    color: lineColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateInterval(),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[800]!,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: data.length.toDouble() - 1,
                minY: minY ?? _calculateMinY(),
                maxY: maxY ?? _calculateMaxY(),
                lineBarsData: [
                  LineChartBarData(
                    spots: _createSpots(),
                    isCurved: false,
                    color: lineColor,
                    barWidth: 1.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                extraLinesData: _createExtraLines(),
                lineTouchData: const LineTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _createSpots() {
    if (data.isEmpty) return [];
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i]),
    );
  }

  double _calculateMinY() {
    if (data.isEmpty) return -64;
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    return range < 10 ? -64 : minVal - range * 0.1;
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 64;
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    return range < 10 ? 64 : maxVal + range * 0.1;
  }

  double _calculateInterval() {
    final minVal = minY ?? _calculateMinY();
    final maxVal = maxY ?? _calculateMaxY();
    return (maxVal - minVal) / 4;
  }

  ExtraLinesData _createExtraLines() {
    final lines = <HorizontalLine>[];

    // Центральная линия (нулевая)
    final minVal = minY ?? _calculateMinY();
    final maxVal = maxY ?? _calculateMaxY();
    
    if (minVal < 0 && maxVal > 0) {
      lines.add(HorizontalLine(
        y: 0,
        color: Colors.grey[700]!,
        strokeWidth: 1,
      ));
    }

    // Линии threshold
    if (threshold != null && threshold! > 0) {
      lines.add(HorizontalLine(
        y: threshold!,
        color: Colors.red.withValues(alpha: 0.7),
        strokeWidth: 1,
        dashArray: [5, 5],
      ));
      lines.add(HorizontalLine(
        y: -threshold!,
        color: Colors.red.withValues(alpha: 0.7),
        strokeWidth: 1,
        dashArray: [5, 5],
      ));
    }

    return ExtraLinesData(horizontalLines: lines);
  }
}

/// Виджет FFT спектра
class SpectrumChart extends StatelessWidget {
  final String title;
  final List<double> frequencies;
  final List<double> magnitudes;
  final Color barColor;

  const SpectrumChart({
    super.key,
    required this.title,
    required this.frequencies,
    required this.magnitudes,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              if (frequencies.isNotEmpty && magnitudes.isNotEmpty)
                Text(
                  'Peak: ${_getPeakFrequency().toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: Colors.orange[300],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateMaxMagnitude() / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[800]!,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 20 == 0) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _createBarGroups(),
                barTouchData: BarTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    if (magnitudes.isEmpty) return [];

    return List.generate(
      magnitudes.length,
      (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: magnitudes[i],
            color: barColor,
            width: 2,
          ),
        ],
      ),
    );
  }

  double _getPeakFrequency() {
    if (frequencies.isEmpty || magnitudes.isEmpty) return 0;

    int peakIdx = 0;
    double peakMag = magnitudes[0];

    for (int i = 1; i < magnitudes.length; i++) {
      if (magnitudes[i] > peakMag) {
        peakMag = magnitudes[i];
        peakIdx = i;
      }
    }

    return peakIdx < frequencies.length ? frequencies[peakIdx] : 0;
  }

  double _calculateMaxMagnitude() {
    if (magnitudes.isEmpty) return 1;
    return magnitudes.reduce((a, b) => a > b ? a : b).clamp(0.1, double.infinity);
  }
}
