import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Sends a WhatsApp message by opening the WhatsApp app with a pre-filled message.
  /// 
  /// [phoneNumber] should include the country code without '+' or spaces (e.g., "923001234567")
  /// [message] is the text to pre-fill in the chat
  /// 
  /// Returns a result message indicating success or failure.
  Future<String> sendMessage(String phoneNumber, String message) async {
    // Clean the phone number (remove spaces, dashes, and leading +)
    final cleanNumber = phoneNumber
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('+', '');
    
    // URL-encode the message
    final encodedMessage = Uri.encodeComponent(message);
    
    // Build the WhatsApp deep link URL
    final url = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return "Opening WhatsApp...";
      } else {
        debugPrint('WhatsAppService: Could not launch $url');
        return "Could not open WhatsApp. Please make sure it's installed.";
      }
    } catch (e) {
      debugPrint('WhatsAppService: Error launching WhatsApp - $e');
      return "Error opening WhatsApp: $e";
    }
  }
}
