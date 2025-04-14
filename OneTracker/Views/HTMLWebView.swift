import SwiftUI
@preconcurrency import WebKit

struct HTMLWebView: UIViewRepresentable {
    let htmlString: String
    @Binding var dynamicHeight: CGFloat // Binding to communicate height back
    
    func makeUIView(context: Context) -> WKWebView {
        // WKPreferences related setup removed as javaScriptEnabled is deprecated
        // and the default WKWebpagePreferences allows JavaScript.
        
        let configuration = WKWebViewConfiguration()
        // If specific webpage preferences were needed, they'd be set here:
        // let webpagePreferences = WKWebpagePreferences()
        // webpagePreferences.allowsContentJavaScript = true // Default is true anyway
        // configuration.defaultWebpagePreferences = webpagePreferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator // Handle navigation
        webView.scrollView.isScrollEnabled = false // Disable internal scrolling again, outer ScrollView handles it
        webView.isOpaque = false // Allow background color to show through
        webView.backgroundColor = UIColor.clear // Match SwiftUI background
        
        // Observe the content size changes (more reliable than just didFinish)
        webView.scrollView.addObserver(context.coordinator,
                                       forKeyPath: "contentSize",
                                       options: .new,
                                       context: nil)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only reload if HTML content changes significantly (optional optimization)
        // if uiView.isLoading { return } // Basic check
        
        // Use loadHTMLString with a base URL to handle relative paths if needed
        // For simplicity, assuming content doesn't rely on external relative resources
        // Inject basic styling to match app better (optional)
        let styledHTML = """
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <style>
            body { 
                font-family: -apple-system, sans-serif; 
                /* Keep basic font, remove padding/margin/overflow overrides */
                background-color: transparent; 
                color: #0D2750; /* Match app text color */
            }
            a { 
                color: #007AFF; /* Standard iOS blue link color */
            }
            img {
                max-width: 100%; /* Prevent images from overflowing */
                height: auto;
            }
        </style>
        \(htmlString)
        """
        // Reset height before loading new content to avoid stale values
        // self.dynamicHeight = 0 // REMOVED: Avoid modifying state in updateUIView
        // Provide a generic https base URL to potentially help with resource loading
        uiView.loadHTMLString(styledHTML, baseURL: URL(string: "https://"))
    }
    
    // Coordinator to handle navigation and observe content size
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLWebView

        init(_ parent: HTMLWebView) {
            self.parent = parent
        }
        
        // KVO observer for contentSize
        override func observeValue(forKeyPath keyPath: String?,
                                   of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?,
                                   context: UnsafeMutableRawPointer?) {
            if keyPath == "contentSize", let scrollView = object as? UIScrollView {
                 DispatchQueue.main.async { // Ensure UI updates on main thread
                    // Only update if the height has actually changed
                    if self.parent.dynamicHeight != scrollView.contentSize.height {
                         self.parent.dynamicHeight = scrollView.contentSize.height
                         print("WebView content height updated: \(scrollView.contentSize.height)")
                    }
                 }
            }
        }

        // Handle link taps: open in external browser
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
             if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                 // Check if it's an external link
                 if url.scheme == "http" || url.scheme == "https" {
                      UIApplication.shared.open(url) // Open in Safari
                      decisionHandler(.cancel) // Don't navigate within the webview
                      return
                 }
             }
             decisionHandler(.allow) // Allow other navigation types (initial load)
         }
         
         // --- ADDED: Error Handling --- 
         func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
             print("[HTMLWebView Error] Failed provisional navigation: \(error.localizedDescription)")
         }

         func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
             print("[HTMLWebView Error] Failed navigation: \(error.localizedDescription)")
         }
         // --- END ADDED: Error Handling ---
         
         // Optional: Cleanup observer when the view is dismantled (though often managed automatically)
         // deinit {
         //    // Need a way to access the webView to remove observer
         //    // This might require storing the webView instance in the coordinator
         // }
    }
} 