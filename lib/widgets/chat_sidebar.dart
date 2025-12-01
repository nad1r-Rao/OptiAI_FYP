import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_fonts.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/glasses_status.dart';

class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}



// ... imports ...

class _ChatSidebarState extends State<ChatSidebar> {
  final List<Map<String, dynamic>> menuItems = [
    {'title': 'Home', 'icon': Icons.home_outlined},
    {'title': 'History', 'icon': Icons.history},
    {'title': 'Settings', 'icon': Icons.settings_outlined},
    {'title': 'Help & Support', 'icon': Icons.help_outline},
  ];

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Help & Support"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• Use the camera button to analyze images."),
            Text("• Long press the mic for voice chat."),
            Text("• Use the sidebar to access history and settings."),
            SizedBox(height: 10),
            Text("Version: 1.0.0"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Container(
      width: 280, // Slightly wider for better layout
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          
          // 1. Glasses Status
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassesStatus(),
          ),
          
          Divider(color: theme.colorScheme.primary.withOpacity(0.2)),

          // 2. Menu Items & Recent Chats
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Menu
                  ...menuItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final title = item['title'];
                    final icon = item['icon'];
                    final isSelected = nav.selectedIndex == index && title != 'Help & Support';

                    return ListTile(
                      leading: Icon(
                        icon,
                        color: isSelected ? theme.colorScheme.primary : theme.iconTheme.color?.withOpacity(0.7),
                      ),
                      title: Text(
                        title,
                        style: AppFonts.body.copyWith(
                          color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      onTap: () {
                        if (title == 'Help & Support') {
                          Navigator.pop(context);
                          _showHelpDialog(context);
                          return;
                        }

                        nav.setIndex(index, context);
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) navigator.pop();

                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (title == 'Home') {
                            navigator.pushReplacement(MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
                          } else if (title == 'History') {
                            navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                          } else if (title == 'Settings') {
                            navigator.pushReplacement(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          }
                        });
                      },
                    );
                  }),

                  const SizedBox(height: 10),
                  Divider(color: theme.colorScheme.primary.withOpacity(0.2), indent: 20, endIndent: 20),
                  
                  // 3. Recent Conversations
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                    child: Text(
                      "Recent",
                      style: AppFonts.body.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  if (chatProvider.conversations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        "No recent chats",
                        style: AppFonts.body.copyWith(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  else
                    ...chatProvider.conversations.take(3).map((conv) {
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.body.copyWith(fontSize: 14),
                        ),
                        leading: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                        onTap: () {
                          final navigator = Navigator.of(context);
                          if (navigator.canPop()) navigator.pop();
                          
                          Future.delayed(const Duration(milliseconds: 200), () {
                             chatProvider.loadChat(conv.id);
                             navigator.pushReplacement(MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
                          });
                        },
                      );
                    }),
                ],
              ),
            ),
          ),

          // 4. New Chat Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("New Chat"),
              onPressed: () {
                chatProvider.clearChat();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Started new chat')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // 5. App Version
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              "v1.0.0",
              style: AppFonts.body.copyWith(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
