import 'dart:typed_data';

/// Represents a single message in a chat conversation.
///
/// A [ChatMessage] can be from a user or a bot. It can contain either a
/// text message or an image, or both. This class is used to model the
/// data for each message displayed in the chat UI.
class ChatMessage {
  /// A boolean indicating whether the message is from the user (`true`) or from the bot (`false`).
  final bool isUser;

  /// The text content of the message. This can be null if the message is an image.
  final String? message;

  /// The image data of the message, represented as a byte array. This can be null if the message is text-based.
  final Uint8List? imageBytes;

  /// Creates a new instance of [ChatMessage].
  ///
  /// Requires [isUser] to be specified. [message] and [imageBytes] are optional,
  /// but typically one of them should be provided.
  ChatMessage({
    required this.isUser,
    this.message,
    this.imageBytes,
  });

  /// Converts the [ChatMessage] instance to a map.
  ///
  /// This is useful for serialization, particularly when storing chat history
  /// or sending data to a remote server.
  ///
  /// Returns a [Map<String, dynamic>] representing the chat message.
  Map<String, dynamic> toMap() {
    return {
      'isUser': isUser ? 1 : 0,
      'message': message,
      'image': imageBytes,
    };
  }

  /// Creates a [ChatMessage] instance from a map.
  ///
  /// This is a factory method that reconstructs a [ChatMessage] from a
  /// map representation, typically used for deserialization.
  ///
  /// [map] is the map to convert from.
  ///
  /// Returns a new [ChatMessage] instance.
  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      isUser: map['isUser'] == 1,
      message: map['message'],
      imageBytes: map['image'],
    );
  }
}
