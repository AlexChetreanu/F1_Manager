//
//  RegisterView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct RegisterView: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isRegistered = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Înregistrare")
                .font(.largeTitle)
                .bold()

            TextField("Nume", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Parolă", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Confirmă parola", text: $passwordConfirmation)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            if isLoading {
                ProgressView()
            }

            Button("Înregistrează-te") {
                register()
            }
            .disabled(name.isEmpty || email.isEmpty || password.isEmpty || password != passwordConfirmation)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)

            NavigationLink(destination: DashboardView(), isActive: $isRegistered) {
                EmptyView()
            }
        }
        .padding()
    }

    func register() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "http://127.0.0.1:8000/api/register") else {
            self.errorMessage = "URL invalid"
            self.isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "name": name,
            "email": email,
            "password": password,
            "password_confirmation": passwordConfirmation
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Eroare: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Răspuns invalid"
                    return
                }

                guard let data = data else {
                    errorMessage = "Date lipsă"
                    return
                }

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    if let decoded = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                        UserDefaults.standard.set(decoded.token, forKey: "token")
                        isRegistered = true
                    } else {
                        errorMessage = "Token lipsă în răspuns"
                    }
                } else {
                    errorMessage = "Eroare server: \(httpResponse.statusCode)"
                }
            }
        }.resume()
    }
}
