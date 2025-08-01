//
//  LoginView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(alignment: .center) {
            Text("LFGuild")
                .font(.largeTitle)
                .fontWeight(.bold)
            VStack(alignment: .leading, spacing: 8) {
                Image("LFGuildLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                TextField("Email", text: $email, prompt: Text("Email").foregroundColor(.blue))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(15)
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .foregroundColor(.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .padding()

                SecureField("Password", text: $password, prompt: Text("Password").foregroundColor(.blue))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(15)
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .foregroundColor(.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .padding()
            }

            HStack(spacing: 12) {
                Button(action: {
                    signIn()
                }) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    register()
                }) {
                    Text("Register")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
            }
        }
        .padding()
    }

    private func signIn() {
        print("Sign in tapped with email: \(email)")
    }

    private func register() {
        print("Register tapped")
    }
}

#Preview {
    LoginView()
}
