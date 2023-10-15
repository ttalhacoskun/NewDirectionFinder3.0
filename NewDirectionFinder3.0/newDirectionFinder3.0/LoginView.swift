//
//  LoginView.swift
//  newDirectionFinder3.0
//
//  Created by Talha Coşkun on 13.10.2023.
//

import SwiftUI

struct LoginView: View {
    @State private var isLoggedIn: Bool = false
    @State private var username  = ""
    @State private var password  = ""
    @State private var wrongUserName = 0
    @State private var wrongPassword = 0
    @State private var showLoginScreen = false
    
    var body: some View {
        NavigationView{
            ZStack{
                Color.blue
                    .ignoresSafeArea()
                Circle()
                    .scale(1.7)
                    .foregroundColor(.white.opacity(0.15))
                Circle()
                    .scale(1.35)
                    .foregroundColor(.white)
                
                VStack{
                    Text("Login")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    TextField("Username", text: $username)
                        .padding()
                        .frame(width: 300,height: 50)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .border(.red,width: CGFloat(wrongUserName))
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .frame(width: 300,height: 50)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .border(.red,width: CGFloat(wrongPassword))
                    
                    Button("Login"){
                        autheticateUser(username: username, password: password)
                    }
                    .foregroundColor(.white)
                    .frame(width: 300, height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                NavigationLink(destination: Home(),
                               isActive: $showLoginScreen) {
                    EmptyView()
                }
                       
            }
            .navigationBarHidden(false)
        }
        
    }
    
    func autheticateUser(username: String, password: String) {
        if username.lowercased() == "x" {
            wrongUserName = 0
            if password.lowercased() == "1"{
                wrongPassword = 0
                showLoginScreen = true
            }else{
                wrongPassword = 2
            }
            
            }else{
                wrongUserName = 2
        }
    }
    
}
