import SwiftUI

struct SettingsView: View {
    @AppStorage("includeQuotedReplies") private var includeQuotedReplies: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Composing")) {
                    Toggle("Include Quoted Text in Replies", isOn: $includeQuotedReplies)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline) // Or .large depending on desired style
        }
    }
}

#Preview {
    SettingsView()
} 