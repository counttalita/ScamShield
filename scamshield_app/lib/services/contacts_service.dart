import 'dart:io';
import 'package:contacts_service/contacts_service.dart' as contacts_service;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class ContactsService {
  static ContactsService? _instance;
  static ContactsService get instance => _instance ??= ContactsService._();
  ContactsService._();

  List<contacts_service.Contact>? _cachedContacts;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  /// Check if contacts permission is granted
  Future<bool> hasContactsPermission() async {
    try {
      final status = await Permission.contacts.status;
      print('📱 Contacts permission status: $status');
      return status == PermissionStatus.granted;
    } catch (e) {
      print('❌ Error checking contacts permission: $e');
      return false;
    }
  }

  /// Request contacts permission with platform-specific handling
  Future<bool> requestContactsPermission() async {
    try {
      // Skip permission request on unsupported platforms
      if (kIsWeb) {
        print('🌐 Web platform - contacts permission not applicable');
        return false;
      }
      
      print('📱 Requesting contacts permission on ${Platform.operatingSystem}...');
      
      // Check current status first
      final currentStatus = await Permission.contacts.status;
      print('📱 Current permission status: $currentStatus');
      
      if (currentStatus == PermissionStatus.granted) {
        print('✅ Contacts permission already granted');
        return true;
      }
      
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        print('🚫 Contacts permission permanently denied');
        
        // Platform-specific handling for permanently denied
        if (Platform.isIOS) {
          print('🍎 iOS: Opening app settings for permission');
          await openAppSettings();
        } else if (Platform.isAndroid) {
          print('🤖 Android: Requesting permission (may open settings)');
          await Permission.contacts.request();
        }
        
        // Check again after potential settings visit
        final newStatus = await Permission.contacts.status;
        return newStatus == PermissionStatus.granted;
      }
      
      // Request permission
      final status = await Permission.contacts.request();
      print('📱 Permission request result: $status');
      
      final granted = status == PermissionStatus.granted;
      
      if (granted) {
        print('✅ Contacts permission granted on ${Platform.operatingSystem}!');
      } else {
        print('❌ Contacts permission denied on ${Platform.operatingSystem}');
        
        // Provide platform-specific guidance
        if (Platform.isIOS) {
          print('🍎 iOS: User can enable in Settings > Privacy & Security > Contacts');
        } else if (Platform.isAndroid) {
          print('🤖 Android: User can enable in Settings > Apps > ScamShield > Permissions');
        }
      }
      
      return granted;
    } catch (e) {
      print('❌ Error requesting contacts permission on ${Platform.operatingSystem}: $e');
      
      // Platform-specific error handling
      if (Platform.isIOS && e.toString().contains('NSContactsUsageDescription')) {
        print('🍎 iOS: Missing NSContactsUsageDescription in Info.plist');
      } else if (Platform.isAndroid && e.toString().contains('READ_CONTACTS')) {
        print('🤖 Android: Missing READ_CONTACTS permission in AndroidManifest.xml');
      }
      
      return false;
    }
  }

  /// Check if a phone number exists in user's contacts
  Future<bool> isNumberInContacts(String phoneNumber) async {
    try {
      if (!await hasContactsPermission()) {
        print('📱 No contacts permission - cannot check contacts');
        return false;
      }
      
      final contacts = await getAllContacts();
      
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      
      for (final contact in contacts) {
        if (contact.phones != null) {
          for (final phone in contact.phones!) {
            final contactNumber = _normalizePhoneNumber(phone.value ?? '');
            if (contactNumber == normalizedNumber) {
              print('✅ Found $phoneNumber in contacts: ${contact.displayName}');
              return true;
            }
          }
        }
      }
      
      print('❌ Number $phoneNumber not found in contacts');
      return false;
    } catch (e) {
      print('❌ Error checking if number is in contacts: $e');
      return false;
    }
  }

  /// Get all contacts (cached for performance)
  Future<List<contacts_service.Contact>> getAllContacts() async {
    // Check permission first
    if (!await hasContactsPermission()) {
      return [];
    }

    // Return cached contacts if still valid
    if (_cachedContacts != null && 
        _lastCacheUpdate != null && 
        DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration) {
      return _cachedContacts!;
    }

    try {
      // Fetch contacts from device
      final contacts = await contacts_service.ContactsService.getContacts();

      // Cache the results
      _cachedContacts = contacts.toList();
      _lastCacheUpdate = DateTime.now();

      return _cachedContacts!;
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }



  /// Get contact name for a phone number
  Future<String?> getContactName(String phoneNumber) async {
    final contacts = await getAllContacts();

    // Normalize the phone number for comparison
    final normalizedNumber = _normalizePhoneNumber(phoneNumber);
    
    for (final contact in contacts) {
      if (contact.phones != null) {
        for (final phone in contact.phones!) {
          final contactNumber = _normalizePhoneNumber(phone.value ?? '');
          if (contactNumber == normalizedNumber) {
            return contact.displayName ?? contact.givenName ?? 'Unknown Contact';
          }
        }
      }
    }
    
    return null;
  }

  /// Normalize phone number for comparison
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats (e.g., +1234567890, 1234567890, etc.)
    if (normalized.length > 10) {
      // Take the last 10 digits for US numbers
      normalized = normalized.substring(normalized.length - 10);
    }
    
    return normalized;
  }

  /// Clear contacts cache (call when contacts might have changed)
  void clearCache() {
    _cachedContacts = null;
    _lastCacheUpdate = null;
  }

  /// Get contacts statistics
  Future<Map<String, int>> getContactsStats() async {
    final contacts = await getAllContacts();
    if (contacts.isEmpty) {
      return {
        'totalContacts': 0,
        'contactsWithPhones': 0,
        'totalPhoneNumbers': 0,
      };
    }

    int contactsWithPhones = 0;
    int totalPhoneNumbers = 0;

    for (final contact in contacts) {
      if (contact.phones != null && contact.phones!.isNotEmpty) {
        contactsWithPhones++;
        totalPhoneNumbers += contact.phones!.length;
      }
    }

    return {
      'totalContacts': contacts.length,
      'contactsWithPhones': contactsWithPhones,
      'totalPhoneNumbers': totalPhoneNumbers,
    };
  }

  /// Check if contacts access is available on this platform
  static bool get isSupported {
    // Contacts service is supported on iOS and Android
    return true; // You might want to add platform checks here
  }
}
