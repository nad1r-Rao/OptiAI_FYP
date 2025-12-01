import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../providers/chat_provider.dart';
import '../models/conversation.dart';
import 'chat_home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ChatProvider>().loadConversations();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToChatHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
      (route) => false,
    );
  }

  Map<String, List<Conversation>> _groupConversations(List<Conversation> conversations) {
    final grouped = <String, List<Conversation>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var conv in conversations) {
      // Filter logic
      if (_searchQuery.isNotEmpty) {
        final title = conv.title.toLowerCase();
        final lastMsg = conv.lastMessage.toLowerCase();
        if (!title.contains(_searchQuery) && !lastMsg.contains(_searchQuery)) {
          continue;
        }
      }

      final date = conv.timestamp;
      final dateOnly = DateTime(date.year, date.month, date.day);

      String header;
      if (dateOnly == today) {
        header = 'Today';
      } else if (dateOnly == yesterday) {
        header = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        header = 'Previous 7 Days';
      } else {
        header = 'Older';
      }

      if (!grouped.containsKey(header)) {
        grouped[header] = [];
      }
      grouped[header]!.add(conv);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;
    final groupedConversations = _groupConversations(conversations);

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
          if (conversations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Clear All History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.cardDark,
                    title: const Text('Clear All History?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                        'This will delete ALL your conversations permanently.',
                        style: TextStyle(color: Colors.white70)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          chatProvider.startNewChat();
          _goToChatHome(context);
        },
        backgroundColor: AppColors.neonBlue,
        icon: const Icon(Icons.add, color: AppColors.background),
        label: Text(
          "New Chat",
          style: AppFonts.body.copyWith(
            color: AppColors.background,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: AppColors.neonBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 20),
                        Text(
                          "No conversations yet.",
                          style: AppFonts.body.copyWith(color: AppColors.softWhite),
                        ),
                      ],
                    ),
                  )
                : groupedConversations.isEmpty
                    ? Center(
                        child: Text(
                          "No results found.",
                          style: AppFonts.body.copyWith(color: AppColors.softWhite),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                        children: groupedConversations.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  entry.key,
                                  style: AppFonts.body.copyWith(
                                    color: AppColors.neonBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ...entry.value.map((conv) => _buildConversationItem(context, chatProvider, conv)),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(BuildContext context, ChatProvider chatProvider, Conversation conv) {
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        chatProvider.deleteConversation(conv.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            conv.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              conv.lastMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.body.copyWith(fontSize: 13, color: Colors.white60),
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          onTap: () async {
            await chatProvider.loadChat(conv.id);
            if (mounted) _goToChatHome(context);
          },
        ),
      ),
    );
  }
}
