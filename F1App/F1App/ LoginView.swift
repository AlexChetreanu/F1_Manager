//
//   LoginView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct LoginView: View {
    @AppStorage("token") var token: String?
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAuthenticated = false

    var body: some View {
        NavigationView {
            

            VStack(spacing: 20) {
                Text("Autentificare")
                    .font(.largeTitle)
                    .bold()

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Parolă", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if isLoading {
                    ProgressView()
                }

                Button("Login") {
                    login()
                }
                .disabled(email.isEmpty || password.isEmpty)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                
                .fullScreenCover(isPresented: $isAuthenticated) {
                    DashboardView()
                }

                NavigationLink("Nu ai cont? Înregistrează-te", destination: RegisterView())
                    .foregroundColor(.blue)
            }
            .padding()
        }
    }
    

    func login() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "http://127.0.0.1:8000/api/login") else {
            self.errorMessage = "URL invalid"
            self.isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Eroare rețea: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Răspuns invalid"
                    return
                }

                guard let data = data else {
                    self.errorMessage = "Date lipsă"
                    return
                }

                print("Status code: \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseStr)")
                }

                if httpResponse.statusCode == 200 {
                    if let decoded = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                        UserDefaults.standard.set(decoded.token, forKey: "token")
                        UserDefaults.standard.set(decoded.user.name, forKey: "user_name")
                        UserDefaults.standard.set(decoded.user.email, forKey: "user_email")
                        self.isAuthenticated = true
                    } else {
                        self.errorMessage = "Token lipsă în răspuns"
                    }
                } else {
                    // încearcă să decodezi mesajul de eroare
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       let message = errorResponse["message"] {
                        self.errorMessage = message
                    } else {
                        self.errorMessage = "Credențiale invalide sau eroare de server"
                    }
                }
            }
        }.resume()
    }

}



struct DashboardView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Acasă", systemImage: "house.fill")
                }

            DriversView()
                .tabItem {
                    Label("Piloți", systemImage: "person.3.fill")
                }

            StandingsView()
                .tabItem {
                    Label("Clasament", systemImage: "list.number")
                }

            RacesView()
                .tabItem {
                    Label("Curse", systemImage: "flag.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
             //   .navigationBarBackButtonHidden(false)
        }
    }
}

    

