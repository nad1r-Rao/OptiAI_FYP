//lib/providers/navigation_provider.dart
import 'package:flutter/material.dart';
import '../screens/chat_home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';

/// A provider class for managing the state of the bottom navigation bar.
///
/// This class keeps track of the currently selected tab and handles the
/// navigation logic when a new tab is selected. It uses [ChangeNotifier]
/// to notify listeners when the selected index changes.
class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;

  /// The index of the currently selected tab.
  int get selectedIndex => _selectedIndex;

  /// Sets the selected tab index and navigates to the corresponding screen.
  ///
  /// [index] The index of the tab to select.
  /// [context] The [BuildContext] used for navigation.
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
