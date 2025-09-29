import 'dart:typed_data';

class ChatMessage {
  final bool isUser;
  final String? message;
  final Uint8List? imageBytes;

  ChatMessage({
    required this.isUser,
    this.message,
    this.imageBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'isUser': isUser ? 1 : 0,
      'message': message,
      'image': imageBytes,
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      isUser: map['isUser'] == 1,
      message: map['message'],
      imageBytes: map['image'],
    );
  }
}
