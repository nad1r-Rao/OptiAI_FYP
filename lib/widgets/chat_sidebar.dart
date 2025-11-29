import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_fonts.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_home_screen.dart';
import '../screens/history_screen.dart';

class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  bool isCollapsed = false;

  final List<Map<String, dynamic>> menuItems = [
    {'title': 'Home', 'icon': Icons.home_outlined},
    {'title': 'History', 'icon': Icons.history},
    {'title': 'Settings', 'icon': Icons.settings_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 80 : 250,
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
          // Sidebar menu items
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final title = menuItems[index]['title'];
                final icon = menuItems[index]['icon'];
                final isSelected = nav.selectedIndex == index;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      nav.setIndex(index, context);
                      if (title == 'Home') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
                        );
                      } else if (title == 'History') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCollapsed ? 0 : 20,
                        vertical: 18,
                      ),
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.iconTheme.color?.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 15),
                            Flexible(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.body.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.textTheme.bodyLarge?.color,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Collapse toggle
          Divider(color: theme.colorScheme.primary.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: IconButton(
              icon: Icon(
                isCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  isCollapsed = !isCollapsed;
                });
              },
            ),
          ),

          // 🆕 New Chat Button (Responsive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: isCollapsed
                ? Tooltip(
                    message: 'New Chat',
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<ChatProvider>().clearChat();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Started new chat')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.add, size: 20, color: Colors.white),
                    ),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Flexible(
                      child: Text(
                        'New Chat',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: () {
                      context.read<ChatProvider>().clearChat();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Started new chat')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
