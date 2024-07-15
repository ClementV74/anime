import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isShowingLoadingScreen = true
    @State private var isShowingDownloadAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                WebView(url: URL(string: "https://anime-sama.fr")!, isShowingLoadingScreen: $isShowingLoadingScreen)
                    .navigationBarHidden(true)
                    .background(Color.black.edgesIgnoringSafeArea(.all)) // Set background color to black
                
                VStack {
                    Spacer()
                    Button(action: {
                        downloadLocalStorageFile()
                    }) {
                        Text("Télécharger")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.isShowingLoadingScreen = false
                }
            }
            .alert(isPresented: $isShowingDownloadAlert) {
                Alert(
                    title: Text("Téléchargement terminé"),
                    message: Text("Le fichier localstorage.sqlite3 a été téléchargé avec succès."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    func downloadLocalStorageFile() {
        let fileManager = FileManager.default
        let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let webkitDataDirectory = libraryDirectory.appendingPathComponent("WebKit/WebsiteData/Default")

        if let localStoragePath = findLocalStorageFile(in: webkitDataDirectory) {
            let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            // Generate unique filename based on current timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            let destinationURL = documentDirectory.appendingPathComponent("DownloadedLocalStorage_\(timestamp).sqlite3")
            
            // Check if file with same name already exists
            var destinationURLFinal = destinationURL
            var count = 1
            while fileManager.fileExists(atPath: destinationURLFinal.path) {
                let newName = "DownloadedLocalStorage_\(timestamp)_\(count).sqlite3"
                destinationURLFinal = documentDirectory.appendingPathComponent(newName)
                count += 1
            }
            
            do {
                try fileManager.copyItem(at: localStoragePath, to: destinationURLFinal)
                
                // Present the share sheet to allow the user to download the file
                let activityViewController = UIActivityViewController(activityItems: [destinationURLFinal], applicationActivities: nil)
                
                // Get the root view controller to present the share sheet
                if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    rootViewController.present(activityViewController, animated: true, completion: {
                        self.isShowingDownloadAlert = true
                    })
                }
            } catch {
                print("Error copying file: \(error.localizedDescription)")
            }
        } else {
            print("Local storage file not found.")
        }
    }
    
    func findLocalStorageFile(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        let localStorageFileName = "localstorage.sqlite3"
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for item in contents {
                if item.lastPathComponent == localStorageFileName {
                    return item
                }
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    if let found = findLocalStorageFile(in: item) {
                        return found
                    }
                }
            }
        } catch {
            print("Error searching directory: \(error.localizedDescription)")
        }
        
        return nil
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
