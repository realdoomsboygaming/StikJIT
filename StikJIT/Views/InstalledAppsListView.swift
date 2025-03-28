//
//  InstalledAppsListView.swift
//  StikJIT
//
//  Editied by doomsboygaming on 03/28/2025.
//

import SwiftUI

struct InstalledAppsListView: View {
    @StateObject private var viewModel = InstalledAppsViewModel()
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var onSelectApp: (String) -> Void
    
    var filteredApps: [(key: String, value: String)] {
        let sorted = viewModel.apps.sorted(by: { $0.key < $1.key })
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { bundleID, appName in
            bundleID.localizedCaseInsensitiveContains(searchText) ||
            appName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        listContent
    }
    
    var listContent: some View {
        NavigationView {
            VStack {
                searchBar
                
                appList
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Installed Apps")
            .navigationBarItems(leading: Button("Done") {
                dismiss()
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.blue))
        }
    }
    
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search apps", text: $searchText)
                .foregroundColor(Color.primary)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    var appList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps, id: \.key) { bundleID, appName in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onSelectApp(bundleID)
                        }
                    }) {
                        HStack(spacing: 16) {
                            // App Icon
                            if let image = viewModel.appIcons[bundleID] {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.2), 
                                            radius: 3, x: 0, y: 1)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "app")
                                            .font(.system(size: 26))
                                            .foregroundColor(.gray)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .onAppear {
                                        loadAppIcon(for: bundleID)
                                    }
                            }
                            
                            // App Name and Bundle ID
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.blue)
                                
                                Text(bundleID)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.gray)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if bundleID != filteredApps.last?.key {
                        Divider()
                            .padding(.leading, 96)
                            .padding(.trailing, 20)
                            .opacity(0.4)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // Helper method to load app icon
    private func loadAppIcon(for bundleID: String) {
        viewModel.loadAppIcon(for: bundleID) { _ in }
    }
}
