import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  
  Future<bool> requestPermission() async {
    // 1. Check Contact Permission
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return false;
    }
    
    // 2. Check Phone Permission (Runtime)
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
      if (!status.isGranted) {
        return false;
      }
    }
    
    return true;
  }

  Future<String> findAndCallContact(String name) async {
    if (!await requestPermission()) {
      return "Permission denied. Please allow Contact and Phone access.";
    }

    // Get all contacts (lightweight fetch first)
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    
    // Fuzzy search
    final lowerName = name.toLowerCase();
    final matches = contacts.where((c) => 
      c.displayName.toLowerCase().contains(lowerName)
    ).toList();

    if (matches.isEmpty) {
      return "I couldn't find a contact named '$name'.";
    }

    // Pick the best match (first one for now)
    final contact = matches.first;
    
    if (contact.phones.isEmpty) {
      return "${contact.displayName} doesn't have a phone number saved.";
    }

    // Use the first number
    final phoneNumber = contact.phones.first.number;
    
    // Clean the number for the dialer (remove spaces, dashes, etc if needed, 
    // but usually the plugin handles it. We'll strip just in case)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Call directly
    final success = await FlutterPhoneDirectCaller.callNumber(cleanNumber);
    
    if (success == true) {
      return "Calling ${contact.displayName}...";
    } else {
      return "Failed to initiate call to ${contact.displayName}.";
    }
  }
}
