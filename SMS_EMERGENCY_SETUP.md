# SMS Emergency Alert System Setup

## Overview
This feature enables the app to send emergency SOS alerts via SMS to a designated admin phone number when a user triggers an emergency alert.

## Features
- **Emergency SMS Alerts**: Automatically sends detailed emergency information via SMS
- **Configurable Phone Numbers**: Admin can configure both sender and receiver phone numbers
- **Rich Emergency Details**: Includes user info, location, emergency type, and map link
- **Permission Management**: Handles SMS permissions automatically

## Setup Instructions

### 1. Dependencies
Add the following to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_sms: ^2.3.3
  permission_handler: ^11.0.1
```

### 2. Android Permissions
Add these permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
```

### 3. Phone Number Configuration
The system uses two phone numbers:
- **System Phone Number**: The number that appears as the sender (default: +639449499106)
- **Admin Phone Number**: The number that receives emergency alerts (default: +639669623629)

### 4. Configuration
Users can configure phone numbers through the settings icon in the Request Assistance page:
1. Tap the settings icon (⚙️) in the app bar
2. Enter the system phone number (sender)
3. Enter the admin phone number (receiver)
4. Tap "Save"

## How It Works

### Emergency Alert Flow
1. User triggers emergency SOS
2. App gets current location and user details
3. Creates emergency data with `emergencyStatus: 'Sent'`
4. Stores data in Firebase Firestore and Storage
5. Sends SMS to admin with emergency details
6. Shows success/failure notification to user

### SMS Message Format
```
🚨 EMERGENCY SOS ALERT 🚨

📱 From: [System Phone Number]
👤 User: [User Full Name]
📞 Contact: [User Contact Number]
♿ Disability: [User Disability Type]
🚨 Emergency Type: [Fire/Injured/Hospital/Ambulance/Police]
📍 Location: [Location Name/Coordinates]

📝 Description: [Emergency Description]

🗺️ Map Link: [Google Maps Link]

⏰ Time: [Current Timestamp]

Please respond immediately!
```

## Technical Details

### Files Modified
- `lib/services/sms_service.dart` - SMS service implementation
- `lib/pages/request_assistance_page.dart` - Emergency alert integration
- `android/app/src/main/AndroidManifest.xml` - SMS permissions
- `pubspec.yaml` - Dependencies

### Key Functions
- `SmsService().sendEmergencySms()` - Sends emergency SMS
- `_showAdminPhoneNumberDialog()` - Phone number configuration UI
- `_sendEmergencyNotification()` - Emergency alert processing

### Data Structure
Emergency alerts include:
- `emergencyStatus: 'Sent'` - Status field for tracking
- User information (name, contact, disability type)
- Location data (coordinates, address, map link)
- Emergency details (type, description, timestamp)

## Troubleshooting

### Common Issues
1. **SMS Permission Denied**: Ensure SMS permissions are granted in app settings
2. **SMS Not Sending**: Check phone number format and carrier restrictions
3. **Location Errors**: Verify location permissions are enabled

### Debug Information
- Check console logs for SMS sending status
- Verify phone numbers in configuration dialog
- Ensure all required permissions are granted

## Security Notes
- Phone numbers are stored locally in the app
- SMS content includes sensitive location information
- Consider implementing additional security measures for production use

## Testing
1. Configure phone numbers in settings
2. Trigger emergency SOS alert
3. Verify SMS is received on admin phone
4. Check Firebase for stored emergency data
5. Verify `emergencyStatus` field is set to 'Sent'
