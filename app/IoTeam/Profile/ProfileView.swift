//
//  ProfileView.swift
//  IoTeam
//
//  Created by Vincent on 02/07/26.
//

import SwiftUI
import Domain

struct ProfileView: View {
    // MARK: - Dependencies & State
    @Environment(LocaleManager.self) private var localeManager
    @Environment(AppSessionStore.self) private var sessionStore
    let observeDevicesUseCase: ObserveDevicesUseCase
    
    @State private var deviceCount = 0
    
    // Theme Colors
    let bgColor = Color(red: 244/255, green: 245/255, blue: 246/255)
    let logoutRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    
    var body: some View {
        @Bindable var bindableLocale = localeManager
        
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                Text("Profile")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.black)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - User Card
                        HStack(spacing: 16) {
                            // Replace "ProfilePic" with your actual image asset
                            Image("ProfilePic")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .background(Circle().fill(Color.gray.opacity(0.2)))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.black)
                                
                                Text(displayEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.black.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        
                        // MARK: - Menu Options List
                        VStack(spacing: 0) {
                            ProfileMenuRow(
                                iconName: "antenna.radiowaves.left.and.right",
                                title: "Manage Devices",
                                value: deviceCount.formatted(), // Injected device count
                                showDivider: true
                            ) {
                                print("Manage Devices tapped")
                            }
                            
                            ProfileMenuRow(
                                iconName: "person.2",
                                title: "Family",
                                showDivider: true
                            ) {
                                print("Family tapped")
                            }
                            
                            ProfileMenuRow(
                                iconName: "qrcode.viewfinder",
                                title: "Notifications",
                                showDivider: true
                            ) {
                                print("Notifications tapped")
                            }
                            
                            ProfileMenuRow(
                                iconName: "clock.arrow.circlepath",
                                title: "Usage History",
                                showDivider: true
                            ) {
                                print("Usage History tapped")
                            }
                            
                            // MARK: - App Language Picker
                            HStack(spacing: 16) {
                                Image(systemName: "globe")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.black)
                                    .frame(width: 28, alignment: .center)
                                
                                Text("App Language")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Picker("", selection: $bindableLocale.languageCode) {
                                    Text("System").tag(AppLanguage.system.rawValue)
                                    Text("English").tag(AppLanguage.english.rawValue)
                                    Text("Indonesian").tag(AppLanguage.indonesian.rawValue)
                                }
                                .pickerStyle(.menu)
                                .tint(Color.black.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        
                        // Footer notice from your original snippet
                        Text("Family and medicine flows are still mocked out for this prototype.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                        
                        Spacer(minLength: 20)
                        
                        // MARK: - Logout Button
                        Button(action: {
                            // Using your coordinator logic here
                            AppLaunchCoordinator.shared.logout()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Logout")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(logoutRed)
                            .cornerRadius(27)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        // MARK: - Device Stream Task
        .task {
            let stream = observeDevicesUseCase.execute()
            for await devices in stream {
                deviceCount = devices.count
            }
        }
    }
    
    private var displayName: String {
        sessionStore.currentUser?.fullName ?? "IoTeam User"
    }
    
    private var displayEmail: String {
        sessionStore.currentUser?.email ?? "No email"
    }
}

// MARK: - Reusable Menu Row Component

struct ProfileMenuRow: View {
    let iconName: String
    let title: String
    var value: String? = nil // Added optional value property
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.black)
                        .frame(width: 28, alignment: .center)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Display device count if provided
                    if let value = value {
                        Text(value)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.3))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                
                if showDivider {
                    Divider()
                        .padding(.leading, 60)
                }
            }
            .background(Color.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
