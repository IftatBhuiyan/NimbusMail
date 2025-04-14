import Foundation
import Security

// Simple Keychain Service for storing sensitive data like refresh tokens

struct KeychainService {
    
    // Define a unique service name for your app
    private static let service = "com.EclipseStudio.LunarMail.authtokens" // Example service name
    
    // MARK: - Save
    static func save(token: String, account: String) -> Bool {
        guard let data = token.data(using: .utf8) else {
            print("Error: Could not convert token string to data.")
            return false
        }
        
        // Query to find existing item for this account
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Attributes for the new/updated item
        let attributes: [String: Any] = [
            kSecValueData as String: data
            // kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked // Example: More secure accessibility
        ]
        
        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            // Item exists, update it
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                print("Keychain Error: Failed to update item. Status: \(updateStatus)")
                return false
            }
            print("Keychain: Successfully updated token for \(account)")
            return true
            
        case errSecItemNotFound:
            // Item does not exist, add it
            var newItemQuery = query
            newItemQuery[kSecValueData as String] = data
            // newItemQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked // Add accessibility rule
            
            let addStatus = SecItemAdd(newItemQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Keychain Error: Failed to add item. Status: \(addStatus)")
                return false
            }
            print("Keychain: Successfully added token for \(account)")
            return true
            
        default:
            // Any other error
            print("Keychain Error: SecItemCopyMatching failed. Status: \(status)")
            return false
        }
    }
    
    // MARK: - Load
    static func loadToken(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                 print("Keychain Error: Failed to load item. Status: \(status)")
            }
            // Don't print error if simply not found
            return nil
        }
        
        guard let retrievedData = dataTypeRef as? Data,
              let token = String(data: retrievedData, encoding: .utf8) else {
            print("Keychain Error: Failed to convert retrieved data to string.")
            return nil
        }
        
        print("Keychain: Successfully loaded token for \(account)")
        return token
    }
    
    // MARK: - Delete
    static func deleteToken(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("Keychain Error: Failed to delete item. Status: \(status)")
            return false
        }
        
        if status == errSecSuccess {
            print("Keychain: Successfully deleted token for \(account)")
        } else {
             print("Keychain: Token for \(account) not found, nothing to delete.")
        }
        return true
    }
} 