import SwiftUI

// Custom text field style for authentication screens
struct AuthTextField: View {
    var placeholder: String
    var text: Binding<String>
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .none
    var icon: String? = nil
    
    @State private var isShowingPassword = false
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                    .padding(.leading, 12)
            }
            
            if isSecure && !isShowingPassword {
                SecureField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization)
                    .padding(.vertical, 15)
                    .padding(.leading, icon == nil ? 15 : 0)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization)
                    .padding(.vertical, 15)
                    .padding(.leading, icon == nil ? 15 : 0)
            }
            
            if isSecure {
                Button(action: {
                    isShowingPassword.toggle()
                }) {
                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
        )
    }
}

// Custom primary button style for authentication actions
struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var isLoading: Bool = false
    var backgroundColor: Color = .accentColor
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(color: backgroundColor.opacity(0.3), radius: 5, x: 0, y: 3)
        .disabled(isLoading)
    }
}

// Separator with text
struct TextDivider: View {
    var text: String
    
    var body: some View {
        HStack {
            VStack { Divider() }.padding(.horizontal, 15)
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
            VStack { Divider() }.padding(.horizontal, 15)
        }
    }
}

// Error message view
struct ErrorMessageView: View {
    var error: String
    
    var body: some View {
        if !error.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
        }
    }
} 