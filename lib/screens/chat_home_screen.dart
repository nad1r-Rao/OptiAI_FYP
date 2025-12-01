// 📁 chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/chat_bubble.dart';
import '../theme/app_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/recording_animation.dart';
import 'dart:typed_data';
import '../providers/chat_provider.dart';
import '../providers/speech_provider.dart';
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/glasses_status.dart';
import 'package:lottie/lottie.dart';
import '../widgets/empty_chat_state.dart';



class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Load chat history once after build
    Future.microtask(() {
      // context.read<ChatProvider>().loadChatHistory();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatProvider>().sendText(text);
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final speechProvider = context.watch<SpeechProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: AppColors.neonBlue),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('OptiAI Glasses', style: AppFonts.heading.copyWith(color: AppColors.neonBlue)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: UserAvatar(
              radius: 18,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.neonBlue,
            height: 0.5,
          ),
        ),
      ),
      drawer: const ChatSidebar(),
      body: Column(
        children: [
          // Top container removed as it's now in AppBar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            color: AppColors.background,
            child: const GlassesStatus(),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: chatProvider.messages.isEmpty
                  ? const EmptyChatState()
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];

                        if (message.imageBytes != null) {
                          return PreviewImageBubble(imageBytes: message.imageBytes);
                        }

                        return ChatBubble(
                          isUser: message.isUser,
                          message: message.message ?? '',
                        );
                      },
                    ),
            ),
          ),
          if (chatProvider.isThinking)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: TypingIndicator(),
            ),
          if (speechProvider.isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: RecordingAnimation(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.neonBlue, width: 0.5)),
              color: AppColors.background,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt, color: AppColors.neonBlue),
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      final imageBytes = await picked.readAsBytes();
                      chatProvider.sendTextWithImageToGemini("Analyze this image", imageBytes);
                    }
                  },
                ),
                GestureDetector(
                  onLongPressStart: (_) async {
                    bool available = await speechProvider.initialize();
                    if (available) {
                      speechProvider.startListening(
                        onResult: (text) {
                          // Do not update text controller, sending directly to chat
                        },
                        chatProvider: chatProvider,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Speech recognition not available')),
                      );
                    }
                  },
                  onLongPressEnd: (_) {
                    speechProvider.stopListening();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.mic, color: AppColors.neonGreen),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: AppFonts.body,
                    decoration: InputDecoration(
                      hintText: 'Ask anything..',
                      hintStyle: TextStyle(color: AppColors.softWhite),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: AppColors.neonPurple),
                  onPressed: _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewImageBubble extends StatelessWidget {
  final Uint8List? imageBytes;
  const PreviewImageBubble({super.key, this.imageBytes});

  void _openFullScreen(BuildContext context) {
    if (imageBytes == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(content: Image.memory(imageBytes!));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openFullScreen(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neonBlue, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
            color: AppColors.background,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(imageBytes!, width: 150, height: 100, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 20),
          height: 40,
          child: Lottie.asset('assets/lottie/avatar.json'),
        ),
        const SizedBox(width: 8),
        Text(
          'Thinking...',
          style: AppFonts.body.copyWith(color: AppColors.softWhite, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
