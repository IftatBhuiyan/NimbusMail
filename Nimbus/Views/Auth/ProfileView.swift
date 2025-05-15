import SwiftUI
// import FirebaseAuth // Remove Firebase import
import Supabase // Add Supabase import if needed for User type info

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
                        
                        // Use Supabase user data if available
                        if let user = viewModel.authService?.currentUser { // Access via viewModel/authService
                            ProfileInfoRow(icon: "lock.shield.fill", label: "Sign-in Provider", value: getProviderName(for: user))
                            
                            let creationDate = user.createdAt
                                ProfileInfoRow(icon: "calendar", label: "Account Created", value: formattedDate(creationDate))
                        }
                    }
                    .padding()
                    .background(neumorphicBackgroundStyle())
                    
                    // Actions Section (Neumorphic Card)
                    VStack(spacing: 0) { // Use spacing 0 for divider consistency
                        Button(action: {
                            Task { // Call async signOut within a Task
                                await viewModel.signOut()
                            }
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
    
    // Helper method adjusted for Supabase User
    private func getProviderName(for user: User) -> String { // Parameter is now Supabase.User
        // Check appMetadata first
        if let providerJSON = user.appMetadata["provider"], case .string(let providerString) = providerJSON {
            // Common provider names from Supabase might be 'email', 'apple', 'google', etc.
            return providerString.capitalized
        } 
        // Fallback to checking identities array
        else if let firstIdentity = user.identities?.first {
             // Access non-optional 'provider' directly
             return firstIdentity.provider.capitalized
            }
        // Fallback if provider info isn't readily available
        return user.aud // Often 'authenticated'
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
        let mockViewModel = UserViewModel( // Use the preview initializer
            isAuthenticated: true,
            userEmail: "preview@example.com",
            userName: "Preview User"
            // No need to mock Supabase user details directly here for basic preview
        )
        
        return ProfileView(viewModel: mockViewModel)
            .environmentObject(mockViewModel)
    }
} 