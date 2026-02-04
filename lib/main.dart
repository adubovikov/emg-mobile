import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'services/data_recorder.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ориентация - ландшафт предпочтительнее для графиков
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  runApp(const EMGMonitorApp());
}

class EMGMonitorApp extends StatelessWidget {
  const EMGMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider(create: (_) => DataRecorder()),
      ],
      child: MaterialApp(
        title: 'Sichiray EMG Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF14141C),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A24),
            elevation: 0,
          ),
          tabBarTheme: TabBarThemeData(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: Colors.blue,
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: Colors.blue,
            thumbColor: Colors.blue,
            inactiveTrackColor: Colors.grey[700],
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
