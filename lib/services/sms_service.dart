import 'dart:convert';
import 'package:http/http.dart' as http;

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  // ✅ Add all recipients here (will be auto-formatted to 63 format)
  static List<String> recipients = [
    "09685448793", // admin
  ];

  // ✅ Your PhilSMS API key (Bearer Token)
  static const String philsmsApiKey = "2491|PRTffbIKUO5h0w2oBeuPuCZN4zfTICq24EtPuCdC";

  String formatNumber(String number) {
    number = number.replaceAll(RegExp(r'[^0-9]'), ''); // remove spaces/symbols
    if (number.startsWith('0')) {
      return '63${number.substring(1)}';
    }
    if (number.startsWith('+')) {
      return number.substring(1); // drop the plus
    }
    return number;
  }

  Future<bool> sendEmergencySms({
    required String userName,
    required String emergencyType,
    required String locationName,
    required String mapLink,
    required String description,
    required String contactNumber,
    required String disabilityType,
  }) async {
    try {
      // ✅ Build the message (like PHP `$send_data['message']`)
      String message = '''
[ACCAP Emergency Alert]

Name: $userName
Type: $emergencyType
Location: $locationName
Details: $description
Contact: $contactNumber
Disability: $disabilityType

View Map: $mapLink
''';

      final url = Uri.parse("https://app.philsms.com/api/v3/sms/send");

      // ✅ Format all recipients like PHP "recipient"
      String recipientList = recipients.map((n) => formatNumber(n)).join(",");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $philsmsApiKey",
        },
        body: jsonEncode({
          "sender_id": "PhilSMS",   // same as PHP
          "recipient": recipientList,
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ SMS sent successfully via PhilSMS: ${response.body}");
        return true;
      } else {
        print("❌ Failed to send SMS: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("⚠️ Error sending emergency SMS via PhilSMS: $e");
      return false;
    }
  }
}
