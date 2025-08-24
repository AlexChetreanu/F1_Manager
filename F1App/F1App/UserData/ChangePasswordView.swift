//
//  ChangePasswordView.swift
//  F1App
//
//  Created by Alexandru Chetreanu on 07.06.2025.
//

import SwiftUI

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @AppStorage("token") var token: String?

    var body: some View {
        Form {
            Section(header: Text("Actualizare Parolă")) {
                SecureField("Parola actuală", text: $currentPassword)
                SecureField("Parolă nouă", text: $newPassword)
                SecureField("Confirmă parola nouă", text: $confirmPassword)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
            }

            Button("Actualizează parola") {
                updatePassword()
            }
            .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
        }
        .navigationTitle("Schimbă parola")
    }

    func updatePassword() {
        errorMessage = nil
        successMessage = nil

        guard newPassword == confirmPassword else {
            errorMessage = "Parolele nu coincid."
            return
        }

        let url = API.url("/api/password")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: String] = [
            "current_password": currentPassword,
            "password": newPassword,
            "password_confirmation": confirmPassword
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)


        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Eroare rețea: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Răspuns invalid"
                    return
                }

                if httpResponse.statusCode == 200 {
                    self.successMessage = "Parola a fost actualizată cu succes!"
                    self.currentPassword = ""
                    self.newPassword = ""
                    self.confirmPassword = ""
                } else {
                    if let data = data,
                       let responseJSON = try? JSONDecoder().decode([String: String].self, from: data),
                       let message = responseJSON["message"] {
                        self.errorMessage = message
                    } else {
                        self.errorMessage = "Actualizarea parolei a eșuat."
                        print("Token trimis: \(token ?? "nil")")

                    }
                }
                print("Cod status: \(httpResponse.statusCode)")
                if let data = data {
                    print("Răspuns server: \(String(data: data, encoding: .utf8) ?? "nil")")
                }

            }
        }.resume()
    }
}
