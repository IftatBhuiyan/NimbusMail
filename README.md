# Nimbus Email Client

Nimbus is a modern email client for iOS that unifies multiple email accounts in one beautiful interface. Connect your Gmail, Office365, Yahoo, AOL, and other email accounts to manage all your communications in one place.

## Features

- 📧 **Unified Inbox**: Manage all your email accounts in one place
- 🔄 **Multi-Provider Support**: Compatible with Gmail, Yahoo, Outlook, Office365, AOL, and more
- 🔒 **Secure Authentication**: Industry-standard OAuth integration with major providers
- ✉️ **Rich Compose Experience**: Write emails with formatting, attachments, and more
- 🎨 **Modern UI**: Clean and intuitive interface designed for iOS

## Open Source Notice

This project is open source but with specific restrictions on distribution and use of the Nimbus name and branding. Please read the full license terms in LICENSE.md.

### Important Licensing Points

- ✅ You may use this code for personal and educational purposes
- ✅ You may modify and contribute to this codebase
- ❌ You may NOT publish this app or derivatives on the App Store or other app marketplaces
- ❌ You may NOT use the Nimbus name or branding in derivative works

## Getting Started

### Requirements

- Xcode 14.0+
- iOS 16.0+
- Swift 5.7+
- macOS Ventura or later (for development)

### Setup

1. Clone the repository
2. Open `Nimbus.xcodeproj` in Xcode
3. Set up configuration files:
   - Copy `Info.plist.example` to `Info.plist`
   - Copy `GoogleService-Info.plist.example` to `GoogleService-Info.plist`
   - Copy `client_id.plist.example` to a file named `client_YOUR_CLIENT_ID.apps.googleusercontent.com-2.plist`
4. Update the copied files with your actual API keys and credentials:
   - Create a [Supabase](https://supabase.com) account and project for backend services
   - Configure [Google Sign-In](https://developers.google.com/identity/sign-in/ios/start-integrating) for authentication
   - Set up [Firebase](https://firebase.google.com) project (if needed)
5. Build and run the project

### Configuration Files

The repository includes example files for all required configuration:
- **Info.plist.example**: Contains app configuration and Supabase credentials
- **GoogleService-Info.plist.example**: Firebase configuration
- **client_id.plist.example**: Google Sign-In configuration

These example files contain placeholder values that must be replaced with your actual API keys and credentials.

## Contributing

Contributions are welcome! Before contributing, please read:

1. The [LICENSE.md](LICENSE.md) file to understand distribution limitations
2. Our [contribution guidelines](CONTRIBUTING.md) (if available)

## Contact

For questions about licensing or permissions to distribute, please contact Iftat Bhuiyan.

## Acknowledgements

- This project uses the Supabase platform for backend services
- Authentication services provided by various OAuth providers
- Thanks to all contributors who help improve Nimbus

---

**Note**: Nimbus is a personal project by Iftat Bhuiyan and is not affiliated with any of the email service providers whose services it integrates with. 