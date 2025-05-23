# Nimbus Email Client

Nimbus is a modern email client for iOS that unifies multiple email accounts in one beautiful interface. Connect your Gmail, Office365, Yahoo, AOL, and other email accounts to manage all your communications in one place.

<img src="images/sc4.jpeg" alt="Nimbus App Icon" width="100" align="right">

## Screenshots

<p align="center">
  <img src="images/sc1.jpeg" alt="Nimbus Screenshot 1" width="250">
  <img src="images/sc2.jpeg" alt="Nimbus Screenshot 2" width="250">
  <img src="images/sc3.jpeg" alt="Nimbus Screenshot 3" width="250">
</p>

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
5. Set up the required Supabase database schema (see "Supabase Database Schema" section below)
6. Build and run the project

### Configuration Files

The repository includes example files for all required configuration:
- **Info.plist.example**: Contains app configuration and Supabase credentials
- **GoogleService-Info.plist.example**: Firebase configuration
- **client_id.plist.example**: Google Sign-In configuration

These example files contain placeholder values that must be replaced with your actual API keys and credentials.

## Supabase Database Schema

Nimbus requires a specific database schema in your Supabase project. You'll need to create the following tables:

### 1. Accounts Table
This table stores the email accounts linked by each app user:
```sql
CREATE TABLE accounts (
  user_id text NOT NULL,
  email_address text NOT NULL CHECK (email_address ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
  provider text NOT NULL, -- e.g., 'gmail', 'outlook'
  account_name text,
  last_synced_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, email_address)
);
```

### 2. Labels Table
Stores labels/folders for each linked email account:
```sql
CREATE TABLE labels (
  user_id text NOT NULL,
  account_email text NOT NULL,
  provider_label_id text NOT NULL,
  name text NOT NULL,
  type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, account_email, provider_label_id),
  FOREIGN KEY (user_id, account_email) REFERENCES accounts(user_id, email_address) ON DELETE CASCADE
);
```

### 3. Emails Table
Stores individual email message details:
```sql
CREATE TABLE emails (
  user_id text NOT NULL,
  account_email text NOT NULL,
  provider_message_id text NOT NULL,
  thread_id text,
  message_id_header text UNIQUE,
  references_header text,
  sender_name text,
  sender_email text,
  recipient_to text,
  recipient_cc text,
  recipient_bcc text,
  subject text,
  snippet text,
  body_html text,
  body_plain text,
  date_received timestamptz NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  has_attachments boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, account_email, provider_message_id),
  FOREIGN KEY (user_id, account_email) REFERENCES accounts(user_id, email_address) ON DELETE CASCADE
);
```

### 4. Email_Labels Junction Table
Links emails to their labels (Many-to-Many):
```sql
CREATE TABLE email_labels (
  user_id text NOT NULL,
  account_email text NOT NULL,
  provider_message_id text NOT NULL,
  provider_label_id text NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, account_email, provider_message_id, provider_label_id),
  FOREIGN KEY (user_id, account_email, provider_message_id)
    REFERENCES emails(user_id, account_email, provider_message_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id, account_email, provider_label_id)
    REFERENCES labels(user_id, account_email, provider_label_id) ON DELETE CASCADE
);
```

### Row Level Security (RLS)
Enable RLS on all tables and set up appropriate policies:

```sql
-- Enable RLS
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_labels ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow users to manage own accounts"
  ON accounts FOR ALL USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Allow users to manage labels for own accounts"
  ON labels FOR ALL USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Allow users to manage emails for own accounts"
  ON emails FOR ALL USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Allow users to manage email_labels for own accounts"
  ON email_labels FOR ALL USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);
```

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

