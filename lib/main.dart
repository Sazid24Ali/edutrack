import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/ocr_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const EduTrackApp());
}

class EduTrackApp extends StatefulWidget {
  const EduTrackApp({super.key});

  @override
  State<EduTrackApp> createState() => _EduTrackAppState();
}

class _EduTrackAppState extends State<EduTrackApp> {
  ThemeMode _themeMode = ThemeMode.dark; // default light

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: MainNavigation(onThemeChanged: toggleTheme),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const MainNavigation({super.key, required this.onThemeChanged});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const OcrScreen(),
      const PlannerScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "OCR"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Planner",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
