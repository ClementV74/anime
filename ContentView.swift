import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isShowingLoadingScreen = true
    @State private var isShowingDownloadAlert = false
    @State private var isShowingLoginView = false
    @State private var isSyncing = false
    @State private var isShowingSettings = false

    @State private var userId: Int? = {
        let savedUserId = UserDefaults.standard.integer(forKey: "userId")
        return savedUserId > 0 ? savedUserId : nil
    }()
    
    var body: some View {
            NavigationView {
                ZStack {
                    WebView(url: URL(string: "https://anime-sama.fr")!,
                            isShowingLoadingScreen: $isShowingLoadingScreen,
                            userId: $userId)
                        .navigationBarHidden(true)
                        .background(Color.black.edgesIgnoringSafeArea(.all))
                    
                    VStack {
                        HStack {
                            Spacer() // Pousse le bouton vers la droite
                            Button(action: {
                                isShowingSettings.toggle()
                            }) {
                                Text("⚙️")
                                    .foregroundColor(.white)
                                   
                                    .font(.system(size: 35))
                                    .background(Color.black)
                                    .cornerRadius(5)
                            }
                            .padding(.top, 5) // Ajoute un espacement en haut
                            .padding(.trailing, 12) // Ajoute un espacement à droite
                        }

                        Spacer()

                        Button(action: {
                            if userId == nil {
                                self.isShowingLoginView = true
                            } else if !isSyncing {
                                isSyncing = true
                                downloadLocalStorageFile()
                            }
                        }) {
                            Text(userId == nil ? "Se connecter" : (isSyncing ? "Synchronisation en cours..." : "Synchroniser"))
                                .foregroundColor(.white)
                                .padding()
                                .background(isSyncing ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.bottom, 20)
                        .disabled(isSyncing)
                    }

                    if isShowingLoginView {
                        LoginView(isShowing: $isShowingLoginView, userId: $userId)
                            .background(Color.black.opacity(0.5).edgesIgnoringSafeArea(.all))
                            .transition(.opacity)
                    }

                    // Écran de chargement pendant le chargement de la WebView
                    if isShowingLoadingScreen {
                        LoadingView()
                            .background(Color.black.opacity(0.5).edgesIgnoringSafeArea(.all))
                    }

                    // Vue des paramètres
                    if isShowingSettings {
                        SettingsView(isShowing: $isShowingSettings, userId: $userId)
                            .background(Color.black.opacity(0.5).edgesIgnoringSafeArea(.all))
                            .transition(.opacity)
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
                        message: Text("L'historique a été téléchargé avec succès."),
                        dismissButton: .default(Text("OK")) {
                            isSyncing = false
                        }
                    )
                }
            }
        }
    
   

   
    
    func downloadLocalStorageFile() {
        // Vérifier que userId n'est pas nil
        guard let userId = userId else {
            print("User ID is nil. Please log in first.")
            return
        }
        
        print("User ID during download: \(userId)")
        
        // Récupération des chemins d'accès en dehors de la fermeture
        let fileManager = FileManager.default
        let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let webkitDataDirectory = libraryDirectory.appendingPathComponent("WebKit/WebsiteData/Default")

        // Déplacement de la récupération du fichier local ici
        guard let localStoragePath = findLocalStorageFile(in: webkitDataDirectory),
              let fileData = try? Data(contentsOf: localStoragePath) else {
            print("Local storage file not found or could not be read.")
            return
        }

        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jsonFileURL = documentDirectory.appendingPathComponent("data.json")

        // Configuration de la requête HTTP
        let url = URL(string: "https://feegaffe.fr/histo/api.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        let mimeType = "application/octet-stream"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Construction du corps de la requête en dehors de la fermeture
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sqliteFile\"; filename=\"\(localStoragePath.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body

        // Effectuer la requête dans la fermeture sans capturer `fileManager`
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading file: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Invalid response from server")
                return
            }
            
            if let data = data {
                // Sauvegarder le fichier JSON localement en utilisant le chemin récupéré en dehors de la fermeture
                do {
                    try data.write(to: jsonFileURL)
                    print("Fichier JSON sauvegardé avec succès à l'emplacement : \(jsonFileURL)")

                    // Maintenant, téléverser le fichier JSON vers une autre API
                    uploadJSONFile(jsonFileURL: jsonFileURL, userId: userId)
                } catch {
                    print("Erreur lors de la sauvegarde du fichier JSON : \(error)")
                }
            }
        }.resume()
    }
    
    
    func uploadJSONFile(jsonFileURL: URL, userId: Int) {
        let url = URL(string: "https://feegaffe.fr/histo/upload.php")! // Updated API endpoint
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        let boundaryPrefix = "--\(boundary)"
        let boundarySuffix = "\(boundaryPrefix)--"

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Ajouter userId au corps de la requête
        body.append("\(boundaryPrefix)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userid\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)

        // Ajouter le fichier JSON
        body.append("\(boundaryPrefix)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"jsonfile\"; filename=\"data.json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        
        // Lire le contenu du fichier JSON
        guard let fileData = try? Data(contentsOf: jsonFileURL) else {
            print("Erreur lors de la lecture du fichier JSON")
            return
        }
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append(boundarySuffix.data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Erreur lors de l'envoi du fichier JSON : \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Erreur : Réponse invalide du serveur")
                return
            }

            // Suppression du fichier local après envoi réussi
            do {
                try FileManager.default.removeItem(at: jsonFileURL)
                print("Fichier JSON local supprimé avec succès.")
            } catch {
                print("Erreur lors de la suppression du fichier JSON local : \(error)")
            }

            DispatchQueue.main.async {
                isSyncing = false
            }
        }.resume()
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
    @Binding var userId: Int?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true // Permet la lecture en ligne
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = [.video] // Nécessite une action utilisateur pour les vidéos

        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nous n'avons pas besoin de faire quelque chose ici pour ce cas précis
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isShowingLoadingScreen = false

            // Assurez-vous que userId est correctement récupéré
            let userId = parent.userId ?? 0
            print("User ID in JavaScript: \(userId)")

            let jsCode = """
                const color = '#000411';
                const newStyle = `
                    body {
                        background-color: ${color} !important;
                        background-image: none !important;
                    }
                    [href*="https://youradexchange.com/"],
                    [href*="//feltatchaiz.net/"],
                    [src*="https://youradexchange.com/"] {
                        display: none !important;
                    }
                    img[src*="https://cdn.statically.io/gh/Anime-Sama/IMG/img/autres/flag_pal.png"] {
                        display: none !important;
                    }
                    #dl-banner-300x250 {
                        display: none !important;
                    }
                    img.logo-circular {
                        border-radius: 50%;
                        transition: transform 0.5s ease;
                    }
                    img.logo-circular:hover {
                        transform: rotate(360deg);
                    }
                    .xl\\:pl-60.pt-1.sm\\:inline-flex {
                        display: none !important;
                    }
                    .items-center.justify-center.align-center {
                        display: none !important;
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

                function refuseCookies() {
                    const rejectButton = document.querySelector('.qc-cmp2-close-icon');
                    if (rejectButton) {
                        rejectButton.click();
                        console.log('Cookies refusés automatiquement');
                    } else {
                        console.log('Bouton de refus des cookies non trouvé');
                    }
                }

                function observeConsentPopup() {
                    const observer = new MutationObserver((mutations) => {
                        mutations.forEach((mutation) => {
                            if (mutation.addedNodes.length > 0) {
                                refuseCookies();
                            }
                        });
                    });

                    observer.observe(document.body, {
                        childList: true,
                        subtree: true
                    });
                }
                injectStyle();
                observeLogo();
                observeConsentPopup();

                const paypalLink = document.querySelector('a[href="https://www.paypal.com/donate/?hosted_button_id=3FBNLMGT3JAJ2"]');
                if (paypalLink) {
                    paypalLink.remove();
                }
            """

            let jsCodeWithUserId = """
                \(jsCode)
                function injectButton(userId) {
                    const pElement = document.querySelector('p.text-xs.text-white.font-base.mt-1');
                    if (pElement) {
                        const button = document.createElement('button');
                        button.textContent = "Charger l'historique enregistré";
                        button.style.backgroundColor = 'rgb(52, 152, 219)';
                        button.style.color = 'rgb(255, 255, 255)';
                        button.style.padding = '10px 20px';
                        button.style.border = 'none';
                        button.style.borderRadius = '5px';
                        button.style.cursor = 'pointer';
                        button.addEventListener('click', async () => {
                            try {
                                // Récupérer les informations de la base de données avec l'ID utilisateur
                                const response = await fetch('https://feegaffe.fr/getUserData.php?userId=' + userId);
                                
                                // Conserver la clé `userId`
                                const userIdKey = 'userId';
                                const userIdValue = localStorage.getItem(userIdKey);

                                // Vider le localStorage
                                localStorage.clear();

                                // Restaurer la clé `userId`
                                if (userIdValue) {
                                    localStorage.setItem(userIdKey, userIdValue);
                                }
                                
                                if (!response.ok) {
                                    throw new Error('Network response was not ok');
                                }
                                
                                const data = await response.json();
                                console.log('Données récupérées :', data);

                                // Traiter les données JSON
                                for (const key in data) {
                                    if (data.hasOwnProperty(key)) {
                                        const value = data[key];
                                        // Si la valeur est un tableau
                                        if (Array.isArray(value)) {
                                            // Stocker les données dans le local storage
                                            localStorage.setItem(key, JSON.stringify(value));
                                            
                                            // Traitement spécifique pour histoUrl, histoEp, et histoName
                                            if (key === 'histoEp') {
                                                const histoUrl = data.histoUrl || [];
                                                const histoEp = value;
                                                
                                                // Assurez-vous que histoUrl et histoEp ont la même longueur
                                                if (histoUrl.length !== histoEp.length) {
                                                    console.error('Les longueurs de histoUrl et histoEp ne correspondent pas.');
                                                    return;
                                                }

                                                // Fonction pour convertir "Épisode X" en numéro d'épisode
                                                function convertEpisodeNumber(episodeString) {
                                                    let cleanedString = episodeString.replace("Episode ", "");
                                                    // Vérifier si c'est un nombre valide
                                                    let episodeNumber = parseInt(cleanedString, 10);
                                                    // Soustraire 1 pour obtenir l'index basé sur 0
                                                    return !isNaN(episodeNumber) ? episodeNumber - 1 : null;
                                                }

                                                // Parcourir les URLs et les épisodes correspondants
                                                histoUrl.forEach((url, index) => {
                                                    const episodeString = histoEp[index];
                                                    const episodeNumber = convertEpisodeNumber(episodeString); // Convertir l'épisode
                                                    if (episodeNumber !== null) {
                                                        const key = `savedEpNb${url}`; // Clé avec l'URL formatée
                                                        localStorage.setItem(key, episodeNumber);
                                                        console.log(`Stocké dans localStorage : ${key} = ${episodeNumber}`);
                                                    } else {
                                                        console.warn(`Numéro d'épisode invalide pour l'URL : ${url} avec la chaîne : ${episodeString}`);
                                                    }
                                                });
                                            }

                                            if (key === 'histoName') {
                                                const histoUrl = data.histoUrl || [];
                                                const histoName = value;

                                                // Assurez-vous que histoUrl et histoName ont la même longueur
                                                if (histoUrl.length !== histoName.length) {
                                                    console.error('Les longueurs de histoUrl et histoName ne correspondent pas.');
                                                    return;
                                                }

                                                // Parcourir les URLs et les noms des épisodes correspondants
                                                histoUrl.forEach((url, index) => {
                                                    const episodeName = histoName[index];
                                                    const key = `savedEpName${url}`; // Clé avec l'URL formatée
                                                    localStorage.setItem(key, episodeName);
                                                    console.log(`Stocké dans localStorage : ${key} = ${episodeName}`);
                                                });
                                            }

                                        } else {
                                            // Stocker les données dans le local storage
                                            localStorage.setItem(key, JSON.stringify(value));
                                        }
                                    }
                                }
                                
                                // Recharger la page après avoir traité les données
                                location.reload();
                                
                            } catch (error) {
                                console.error('Erreur lors de la récupération des données :', error);
                                pElement.innerHTML = 'Erreur lors de la récupération des données : ' + error.message;
                            }
                        });
                        pElement.parentNode.insertBefore(button, pElement.nextSibling);
                    } else {
                        setTimeout(() => injectButton(userId), 1000);
                    }
                }
                injectButton(\(userId));
            """


            webView.evaluateJavaScript(jsCodeWithUserId) { result, error in
                if let error = error {
                    print("JavaScript evaluation error: \(error.localizedDescription)")
                } else {
                    print("JavaScript evaluation result: \(String(describing: result))")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View
    {
        ContentView()
    }
}
    


