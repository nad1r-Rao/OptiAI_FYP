//lib/providers/navigation_provider.dart
import 'package:flutter/material.dart';
import '../screens/chat_home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';

class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index, BuildContext context) {
    _selectedIndex = index;
    notifyListeners();

    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }
}
