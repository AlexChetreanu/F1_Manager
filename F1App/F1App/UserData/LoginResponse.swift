//
//  LoginResponse.swift
//  F1App
//
//  Created by Alexandru Chetreanu on 07.06.2025.
//

struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct User: Codable {
    let id: Int
    let name: String
    let email: String
}
