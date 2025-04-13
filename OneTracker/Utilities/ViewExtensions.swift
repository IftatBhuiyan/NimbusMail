import SwiftUI

// This approach doesn't work because EnvironmentValues doesn't support direct subscripting with ObjectIdentifier
// Removing this implementation in favor of a more reliable approach
// extension EnvironmentObject {
//     static func extract<T: ObservableObject>(from view: any View) -> T? {
//         guard let mirror = Mirror(reflecting: view).descendant("_content") as? EnvironmentValues else {
//             return nil
//         }
//         
//         return mirror[ObjectIdentifier(T.self)] as? T
//     }
// }

// A better approach is to use environment object wrapper directly in views that need it
extension View {
    func withErrorHandling() -> some View {
        // A modifier that adds global error handling to a view
        self.onAppear {
            // Configure global error handling if needed
        }
    }
} 