//
//  LoginView.swift
//  newDirectionFinder3.0
//
//  Created by Talha Coşkun on 12.10.2023.
//

import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var username: String
    @Binding var password: String
    
    var body: some View {
        NavigationView{
            VStack {
                TextField("Kullanıcı Adı", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                SecureField("Şifre", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    // Kullanıcıyı doğrulama işlemini burada gerçekleştirin.
                    if username == "kullanici_adi" && password == "sifre" {
                        isLoggedIn = true
                    }
                }) {
                    Text("Giriş Yap")
                }
            }
            .padding()
            
        }
    }
}
