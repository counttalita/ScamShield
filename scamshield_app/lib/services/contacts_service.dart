import 'package:contacts_service/contacts_service.dart' as contacts_service;
import 'package:permission_handler/permission_handler.dart';

class ContactsService {
  static ContactsService? _instance;
  static ContactsService get instance => _instance ??= ContactsService._();
  ContactsService._();

  List<contacts_service.Contact>? _cachedContacts;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  /// Check if contacts permission is granted
  Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status == PermissionStatus.granted;
  }

  /// Request contacts permission
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status == PermissionStatus.granted;
  }

  /// Get all contacts (cached for performance)
  Future<List<contacts_service.Contact>?> getContacts() async {
    // Check permission first
    if (!await hasContactsPermission()) {
      return null;
    }

    // Return cached contacts if still valid
    if (_cachedContacts != null && 
        _lastCacheUpdate != null && 
        DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration) {
      return _cachedContacts;
    }

    try {
      // Fetch contacts from device
      final contacts = await contacts_service.ContactsService.getContacts();

      // Cache the results
      _cachedContacts = contacts.toList();
      _lastCacheUpdate = DateTime.now();

      return _cachedContacts;
    } catch (e) {
      print('Error fetching contacts: $e');
      return null;
    }
  }

  /// Check if a phone number exists in contacts
  Future<bool> isNumberInContacts(String phoneNumber) async {
    final contacts = await getContacts();
    if (contacts == null) return false;

    // Normalize the phone number for comparison
    final normalizedNumber = _normalizePhoneNumber(phoneNumber);
    
    for (final contact in contacts) {
      if (contact.phones != null) {
        for (final phone in contact.phones!) {
          final contactNumber = _normalizePhoneNumber(phone.value ?? '');
          if (contactNumber == normalizedNumber) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  /// Get contact name for a phone number
  Future<String?> getContactName(String phoneNumber) async {
    final contacts = await getContacts();
    if (contacts == null) return null;

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
    final contacts = await getContacts();
    if (contacts == null) {
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
