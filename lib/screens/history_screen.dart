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

    // Load chat history into memory and display it
    Future.microtask(() {
      context.read<ChatProvider>().loadChatHistory(show: true, force: true);
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
    final messages = chatProvider.messages;

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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ElevatedButton.icon(
                //   onPressed: () {
                //     chatProvider.clearChat();
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(content: Text('Started new chat')),
                //     );
                //   },
                //   // icon: const Icon(Icons.chat_bubble_outline),
                //   label: const Text('New Chat'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: AppColors.neonBlue,
                //     foregroundColor: AppColors.background,
                //   ),
                // ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: const Text(
                            'Are you sure you want to delete all chat history? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await chatProvider.clearChatHistoryFromFirestore();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat history deleted')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white38),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      "No chat history found.",
                      style: AppFonts.body.copyWith(color: AppColors.softWhite),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg.isUser;
                      final alignment =
                          isUser ? Alignment.centerRight : Alignment.centerLeft;
                      final color = isUser
                          ? AppColors.neonGreen.withOpacity(0.2)
                          : AppColors.neonBlue.withOpacity(0.2);

                      return Align(
                        alignment: alignment,
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: msg.message != null
                                  ? Text(
                                      msg.message!,
                                      style: AppFonts.body.copyWith(
                                          color: AppColors.softWhite),
                                    )
                                  : msg.imageBytes != null
                                      ? Image.memory(
                                          msg.imageBytes!,
                                          width: 200,
                                        )
                                      : const SizedBox.shrink(),
                            ),
                            Text(
                              // Just shows timestamp of current time for now
                              // Replace with saved timestamp field if added to Firestore
                              DateTime.now()
                                  .toLocal()
                                  .toString()
                                  .substring(0, 16),
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
