import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isShowingLoadingScreen = true

    var body: some View {
        NavigationView {
            ZStack {
                WebView(url: URL(string: "https://anime-sama.fr")!, isShowingLoadingScreen: $isShowingLoadingScreen)
                    .navigationBarHidden(true)
                    .background(Color.black) // Set background color to black
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.isShowingLoadingScreen = false
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isShowingLoadingScreen: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No need to implement anything here in this case
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
            parent.isShowingLoadingScreen = false
            
            // JavaScript code to inject styles and remove specific elements
            let jsCode = """
            const color = '#000411';
            const newStyle = `
                body {
                    background-color: ${color} !important;
                    background-image: none !important;
                }

                /* Ajout du CSS pour cacher les éléments */
                [href*="https://youradexchange.com/"],
                [src*="https://youradexchange.com/"] {
                    display: none !important;
                }

                /* Ajout du CSS pour cacher l image pal_flag */
                img[src*="https://cdn.statically.io/gh/Anime-Sama/IMG/img/autres/flag_pal.png"] {
                    display: none !important;
                }

                /* CSS pour rendre le logo circulaire et le faire tourner */
                img.logo-circular {
                    border-radius: 50%;
                    transition: transform 0.5s ease;
                }
                
                img.logo-circular:hover {
                    transform: rotate(360deg);
                }

                /*   */


                
            `;

            function injectStyle() {
                const style = document.createElement('style');
                style.type = 'text/css';
                style.innerHTML = newStyle;
                document.head.appendChild(style);
            }

            function replaceLogo() {
                const logos = document.querySelectorAll('img[src*="https://cdn.statically.io/gh/Anime-Sama/IMG/img/autres/logo_banniere.png"]');
                logos.forEach((logo) => {
                    logo.src = 'https://feegaffe.fr/logo.png';
                    logo.classList.add('logo-circular');
                });
            }

            function observeLogo() {
                const observer = new MutationObserver((mutations) => {
                    mutations.forEach((mutation) => {
                        if (mutation.addedNodes.length > 0 || mutation.type === 'attributes') {
                            replaceLogo();
                        }
                    });
                });

                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true
                });
            }

            // Appel de la fonction pour injecter le style CSS
            injectStyle();

            // Appel de la fonction pour observer et remplacer le logo
            observeLogo();
            const paypalLink = document.querySelector('a[href="https://www.paypal.com/donate/?hosted_button_id=3FBNLMGT3JAJ2"]');
            if (paypalLink) {
                paypalLink.remove();
            }
            """

            webView.evaluateJavaScript(jsCode) { (result, error) in
                if let error = error {
                    print("Error executing JavaScript: \(error)")
                } else {
                    print("JavaScript result: \(String(describing: result))")
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isShowingLoadingScreen = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
