//
//  AuthViewModel.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    func login() {
        let url = API.url("/api/login")

        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { result -> Bool in
                guard let httpResponse = result.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                          throw URLError(.badServerResponse)
                      }
                return true
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    self.errorMessage = "Autentificare eșuată"
                }
            }, receiveValue: { success in
                self.isAuthenticated = success
            })
            .store(in: &cancellables)
    }
}
