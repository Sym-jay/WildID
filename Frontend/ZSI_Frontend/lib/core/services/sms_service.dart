import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SMSService {
  SMSService._();

  static final List<String> _sentAlerts = [];

  static const String smsApiUrl = 'https://sms.gov.in/api/send';

  static Future<bool> sendEndangeredSpeciesAlert(String phone, String speciesName) async {
    if (phone.isEmpty) return false;

    try {
      String message = "🚨 ZSI ALERT: You've identified $speciesName - "
          "an endangered species! Your observation (#${DateTime.now().millisecondsSinceEpoch}) "
          "has been recorded for conservation research. Thank you!";

      await _sendSMS(phone, message);
      _sentAlerts.add('Alert: $speciesName to $phone at ${DateTime.now()}');
      return true;
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

      await _sendSMS(phone, message);
      _sentAlerts.add('Verification: $verifiedSpecies to $phone at ${DateTime.now()}');
      return true;
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

      await _sendSMS(phone, message);
      _sentAlerts.add('Tip: $speciesName to $phone at ${DateTime.now()}');
      return true;
    } catch (e) {
      debugPrint('Error sending conservation tip: $e');
      return false;
    }
  }

  static Future<void> _sendSMS(String phone, String message) async {
    try {
      var response = await http.post(
        Uri.parse(smsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': phone,
          'message': message,
          'senderId': 'ZSIIND',
          'apiKey': 'YOUR_GOI_SMS_API_KEY',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('SMS sent successfully to $phone');
      } else {
        throw Exception('SMS API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SMS sending error: $e');
      rethrow;
    }
  }

  static List<String> getSentAlerts() => List.from(_sentAlerts);
}
