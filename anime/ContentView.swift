import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        NavigationView {
            WebView(url: URL(string: "https://anime-sama.fr")!)
                .navigationBarHidden(true)
                .background(Color.black) // Définir le fond en noir
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @State private var isLoading = true
    private let progress = Progress()

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Pas besoin d'implémenter cela dans ce cas
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
    }
}

struct ProgressBar: View {
    @Binding var isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: geometry.size.width - 40)
                        .padding()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
