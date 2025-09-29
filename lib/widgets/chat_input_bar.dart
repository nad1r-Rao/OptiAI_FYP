import 'package:flutter/material.dart';
import '../widgets/recording_animation.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor, 
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Camera Button
          IconButton(
            icon: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
            onPressed: () {
              // TODO: handle camera
            },
          ),

          //Mic Button with modal
          IconButton(
            icon: Icon(Icons.mic, color: theme.colorScheme.secondary),
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RecordingAnimation(),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Stop Recording'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          //Text Input
          Expanded(
            child: TextField(
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Type your command...',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.hintColor,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          //Send Button
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed: () {
              // TODO: send text
            },
          ),
        ],
      ),
    );
  }
}
