import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../providers/chat_provider.dart';
import 'chat_home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load list of conversations
    Future.microtask(() {
      context.read<ChatProvider>().loadConversations();
    });
  }

  void _goToChatHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          "Chat History",
          style: AppFonts.heading.copyWith(color: AppColors.neonBlue),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _goToChatHome(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Clear All History',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All History?'),
                  content: const Text(
                      'This will delete ALL your conversations permanently.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete All',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await chatProvider.clearAllConversations();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All history cleared')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () {
                chatProvider.startNewChat();
                _goToChatHome(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
                foregroundColor: AppColors.background,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const Divider(color: Colors.white38),
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Text(
                      "No conversations yet.",
                      style: AppFonts.body.copyWith(color: AppColors.softWhite),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      return Dismissible(
                        key: Key(conv.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          chatProvider.deleteConversation(conv.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Conversation deleted')),
                          );
                        },
                        child: Card(
                          color: AppColors.cardDark,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.body.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              conv.lastMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.body.copyWith(fontSize: 12, color: Colors.white70),
                            ),
                            trailing: Text(
                              _formatDate(conv.timestamp),
                              style: AppFonts.body.copyWith(fontSize: 12, color: Colors.white54),
                            ),
                            onTap: () async {
                              await chatProvider.loadChat(conv.id);
                              if (mounted) _goToChatHome(context);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }
    return "${d.day}/${d.month}";
  }
}
