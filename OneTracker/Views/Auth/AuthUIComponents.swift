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
                    .padding(.leading, 8)
            }
            
            if isSecure && !isShowingPassword {
                SecureField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization)
                    .padding(15)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autocapitalization)
                    .padding(15)
            }
            
            if isSecure {
                Button(action: {
                    isShowingPassword.toggle()
                }) {
                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// Custom primary button style for authentication actions
struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var isLoading: Bool = false
    var backgroundColor: Color = Color.blue
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(backgroundColor)
        .cornerRadius(10)
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