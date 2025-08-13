//
//  ProfileView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct ProfileView: View {
    @AppStorage("token") var token: String?
    @State private var isLoggingOut = false
    @State private var logoutError: String?
    
    var body: some View {
        NavigationView {
                    Form {
                        Section(header: Text("Contul meu")) {
                            NavigationLink(destination:
                                Form {
                                    Section(header: Text("Informații cont")) {
                                        HStack {
                                            Text("Nume")
                                            Spacer()
                                            Text(UserDefaults.standard.string(forKey: "user_name") ?? "N/A")
                                                .foregroundColor(.gray)
                                        }

                                        HStack {
                                            Text("Email")
                                            Spacer()
                                            Text(UserDefaults.standard.string(forKey: "user_email") ?? "N/A")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .navigationTitle("Profil")
                            ) {
                                Label("Profil", systemImage: "person.fill")
                            }
                    
                            NavigationLink(destination: ChangePasswordView()) {
                                Label("Parolă", systemImage: "lock.fill")
                            }


                    
                    NavigationLink(destination: Text("Subscriții View")) {
                        Label("Subscriții", systemImage: "creditcard.fill")
                    }
                }
                
                Section(header: Text("Setări")) {
                    NavigationLink(destination: Text("Notificări View")) {
                        Label("Notificări", systemImage: "bell.fill")
                    }
                }
                
                Section(header: Text("Suport")) {
                    NavigationLink(destination: Text("Ajutor View")) {
                        Label("Help", systemImage: "questionmark.circle.fill")
                    }
                    
                    NavigationLink(destination: Text("Despre View")) {
                        Label("Despre", systemImage: "info.circle.fill")
                    }
                }
                
                Section {
                    if isLoggingOut {
                        ProgressView()
                    } else {
                        Button(role: .destructive) {
                            logout()
                        } label: {
                            HStack {
                                
                                Text("Deconectează-te")
                            }
                        }
                    }
                    
                    if let logoutError = logoutError {
                        Text(logoutError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profil")
        }
    }
    
    func logout() {
        guard let token = token, let url = URL(string: "http://127.0.0.1:8000/api/logout") else {
            self.token = nil
            return
        }
        
        isLoggingOut = true
        logoutError = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isLoggingOut = false
                
                if let error = error {
                    logoutError = "Eroare la delogare: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logoutError = "Răspuns invalid"
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self.token = nil // Revine automat la LoginView
                } else {
                    logoutError = "Delogare eșuată: \(httpResponse.statusCode)"
                }
            }
        }.resume()
    }
}
