import SwiftUI

struct LoginView: View {
    @Binding var isShowing: Bool
    @Binding var userId: Int? // Assurez-vous que le type est Int?
    @State private var username = ""
    @State private var password = ""
    @State private var isError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Text("Connexion")
                .font(.headline)
                .padding()
                .foregroundColor(.black)

            TextField("Nom d'utilisateur", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .foregroundColor(.black)
                .background(Color.white)
                .cornerRadius(5)

            SecureField("Mot de passe", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .foregroundColor(.black)
                .background(Color.white)
                .cornerRadius(5)

            Button(action: {
                authenticateUser()
            }) {
                Text("Se connecter")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()

            if isError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .frame(width: 300, height: 200)
        .preferredColorScheme(.light)
    }

    func authenticateUser() {
        guard let url = URL(string: "https://feegaffe.fr/login.php") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "username": username,
            "password": password
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Authentication error: \(error)")
                DispatchQueue.main.async {
                    self.isError = true
                    self.errorMessage = "Erreur de connexion. Veuillez réessayer."
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.isError = true
                    self.errorMessage = "Aucune donnée reçue du serveur."
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(AuthenticationResult.self, from: data)
                if result.success, let userId = result.userId {
                    DispatchQueue.main.async {
                        self.userId = userId
                        UserDefaults.standard.set(userId, forKey: "userId")
                        self.isShowing = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isError = true
                        self.errorMessage = result.message ?? "Erreur de connexion. Veuillez réessayer."
                    }
                }
            } catch {
                print("JSON decoding error: \(error)")
                DispatchQueue.main.async {
                    self.isError = true
                    self.errorMessage = "Erreur de traitement des données. Veuillez réessayer."
                }
            }
        }.resume()
    }
}

struct AuthenticationResult: Codable {
    let success: Bool
    let userId: Int? // Assurez-vous que c'est de type Int?
    let message: String? //
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
