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

/// The main chat screen of the application.
///
/// This widget serves as the central hub for user interaction, displaying the
/// chat history, providing an input field for text and voice commands, and
/// integrating with various providers to manage state.
class ChatHomeScreen extends StatefulWidget {
  /// Creates a const [ChatHomeScreen].
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

/// The state for the [ChatHomeScreen].
///
/// Manages the text input controller, scroll controller for the chat view,
/// and the logic for sending messages and scrolling to the latest message.
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

  /// Scrolls the chat view to the bottom to show the latest message.
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

  /// Sends the text from the input field to the [ChatProvider].
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
      body: Row(
        children: [
          const ChatSidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(bottom: BorderSide(color: AppColors.neonBlue, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('OptiAI Glasses', style: AppFonts.heading.copyWith(color: AppColors.neonBlue)),
                      const CircleAvatar(
                        backgroundColor: AppColors.neonGreen,
                        child: Icon(Icons.person, color: AppColors.background),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: ListView.builder(
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
                                _textController.text = text;
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
                            hintText: 'Type your command...',
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
          ),
        ],
      ),
    );
  }
}

/// A widget that displays a preview of an image in the chat.
///
/// This bubble is used to show images sent by the user or captured from
/// the ESP32 camera. Tapping on the image opens it in a full-screen dialog.
class PreviewImageBubble extends StatelessWidget {
  /// The image data to be displayed.
  final Uint8List? imageBytes;
  /// Creates a const [PreviewImageBubble].
  const PreviewImageBubble({super.key, this.imageBytes});

  /// Opens the image in a full-screen dialog.
  ///
  /// [context] The build context for showing the dialog.
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

/// A widget that displays a "typing..." indicator with a fading animation.
///
/// This is shown when the AI is processing a request to give the user
/// visual feedback that the system is working.
class TypingIndicator extends StatefulWidget {
  /// Creates a const [TypingIndicator].
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

/// The state for the [TypingIndicator].
///
/// Manages the animation controller for the fading effect.
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
    return FadeTransition(
      opacity: _dotController,
      child: Row(
        children: [
          Text(
            'OptiAI Glasses is typing...',
            style: AppFonts.body.copyWith(color: AppColors.softWhite),
          ),
        ],
      ),
    );
  }
}
