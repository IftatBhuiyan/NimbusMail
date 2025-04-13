import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var viewModel: UserViewModel
    
    var body: some View {
        ZStack {
            // Apply neumorphic background
            neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)
            
            ScrollView { // Use ScrollView for content that might exceed screen height
                VStack(spacing: 20) {
                    // User Info Section (Neumorphic Card)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Consistent icon color
                                .padding(.trailing, 10)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(viewModel.userName ?? "User")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                
                                Text(viewModel.userEmail ?? "No Email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        if let user = Auth.auth().currentUser {
                            ProfileInfoRow(icon: "lock.shield.fill", label: "Sign-in Provider", value: getProviderName(for: user))
                            
                            if let creationDate = user.metadata.creationDate {
                                ProfileInfoRow(icon: "calendar", label: "Account Created", value: formattedDate(creationDate))
                            }
                        }
                    }
                    .padding()
                    .background(neumorphicBackgroundStyle())
                    
                    // Actions Section (Neumorphic Card)
                    VStack(spacing: 0) { // Use spacing 0 for divider consistency
                        Button(action: {
                            viewModel.signOut()
                            // Presentation mode dismiss is handled by the TabView change
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Sign Out")
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding()
                        }
                    }
                    .background(neumorphicBackgroundStyle())

                    // About Section (Neumorphic Card)
                    VStack(alignment: .leading, spacing: 15) {
                         ProfileInfoRow(icon: "info.circle.fill", label: "App Version", value: "1.0.0")
                    }
                    .padding()
                    .background(neumorphicBackgroundStyle())
                    
                    Spacer() // Push content to the top
                }
                .padding() // Padding around the main VStack
            }
        }
        // Removed NavigationView wrapper as it's provided by the Tab in ContentView
        // Removed .navigationTitle as it's set in ContentView
        // Removed .listStyle as we are using ScrollView + VStacks
    }
    
    // Helper function to create consistent info rows
    @ViewBuilder
    private func ProfileInfoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                .frame(width: 20, alignment: .center)
            Text(label)
                 .foregroundColor(Color(hex: "0D2750").opacity(0.8))
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    // Helper function for neumorphic background styling
    @ViewBuilder
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
             .fill(neumorphicBackgroundColor)
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
    
    // Helper methods (Keep existing ones)
    private func getProviderName(for user: User) -> String {
        if let providerData = user.providerData.first {
            switch providerData.providerID {
            case "apple.com": return "Apple"
            case "password": return "Email & Password"
            // Add other providers if needed (e.g., Google)
            // case "google.com": return "Google"
            default: return providerData.providerID.capitalized
            }
        }
        return "Unknown"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Preview Provider (Needs updating if you want previews for ProfileView)
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock UserViewModel for preview
        let mockViewModel = UserViewModel()
        mockViewModel.isAuthenticated = true
        mockViewModel.userName = "Preview User"
        mockViewModel.userEmail = "preview@example.com"
        // You might need to mock Firebase User data for provider/creation date
        
        return ProfileView(viewModel: mockViewModel)
            .environmentObject(mockViewModel)
    }
} 