import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SMSService {
  SMSService._();

  static final List<String> _sentAlerts = [];

  // Use environment variable or fallback to placeholder (must be configured in production)
  static const String smsApiUrl = String.fromEnvironment(
    'SMS_API_URL',
    defaultValue: 'https://sms.gov.in/api/send',
  );

  // API key should NEVER be hardcoded; use environment variables in production
  static const String smsApiKey = String.fromEnvironment(
    'SMS_API_KEY',
    defaultValue: '', // Empty until configured
  );

  static Future<bool> sendEndangeredSpeciesAlert(String phone, String speciesName) async {
    if (phone.isEmpty) return false;

    try {
      String message = "🚨 ZSI ALERT: You've identified $speciesName - "
          "an endangered species! Your observation (#${DateTime.now().millisecondsSinceEpoch}) "
          "has been recorded for conservation research. Thank you!";

      final success = await _sendSMS(phone, message);
      if (success) {
        _sentAlerts.add('Alert: $speciesName to $phone at ${DateTime.now()}');
      }
      return success;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  static Future<bool> sendVerificationAlert(String phone, String verifiedSpecies) async {
    if (phone.isEmpty) return false;

    try {
      String message = "✅ ZSI UPDATE: Your wildlife observation has been verified by our experts as "
          "$verifiedSpecies. Thank you for contributing to conservation data!";

      final success = await _sendSMS(phone, message);
      if (success) {
        _sentAlerts.add('Verification: $verifiedSpecies to $phone at ${DateTime.now()}');
      }
      return success;
    } catch (e) {
      debugPrint('Error sending verification SMS: $e');
      return false;
    }
  }

  static Future<bool> sendConservationTip(String phone, String speciesName) async {
    if (phone.isEmpty) return false;

    try {
      String message = "🌱 ZSI Conservation Tip: Help protect $speciesName by "
          "supporting wildlife reserves and reporting sightings to authorities.";

      final success = await _sendSMS(phone, message);
      if (success) {
        _sentAlerts.add('Tip: $speciesName to $phone at ${DateTime.now()}');
      }
      return success;
    } catch (e) {
      debugPrint('Error sending conservation tip: $e');
      return false;
    }
  }

  static Future<bool> _sendSMS(String phone, String message) async {
    try {
      // Validate API configuration
      if (smsApiKey.isEmpty) {
        debugPrint('SMS API key not configured. SMS alerts disabled.');
        return false;
      }

      // Validate phone number format
      if (!_isValidPhoneNumber(phone)) {
        debugPrint('Invalid phone number format: $phone');
        return false;
      }

      try {
        final client = http.Client();
        final request = http.Request('POST', Uri.parse(smsApiUrl))
          ..headers['Content-Type'] = 'application/json'
          ..body = json.encode({
            'phoneNumber': phone,
            'message': message,
            'senderId': 'ZSIIND',
            'apiKey': smsApiKey,
          });

        final streamResponse = await client.send(request).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('SMS request timeout');
            client.close();
            throw TimeoutException('SMS request timed out');
          },
        );

        final response = await http.Response.fromStream(streamResponse);
        client.close();

        if (response.statusCode == 200) {
          debugPrint('SMS sent successfully to $phone');
          return true;
        } else {
          debugPrint('SMS API error: ${response.statusCode} - ${response.body}');
          return false;
        }
      } catch (e) {
        debugPrint('SMS request failed: $e');
        return false;
      }
    } catch (e) {
      debugPrint('SMS sending error: $e');
      return false;
    }
  }

  static bool _isValidPhoneNumber(String phone) {
    // Basic validation for Indian phone numbers (10 digits)
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'\D'), ''));
  }

  static List<String> getSentAlerts() => List.from(_sentAlerts);
}
