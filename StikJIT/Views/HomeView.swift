//
//  HomeView.swift
//  StikJIT
//
//  Editied by doomsboygaming on 3/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct HomeView: View {
    @AppStorage("username") private var username = "User"
    @AppStorage("customBackgroundColor") private var customBackgroundColorHex: String = Color.primaryBackground.toHex() ?? "#000000"
    @AppStorage("recentBundleIDs") private var recentBundleIDsString: String = ""
    
    @State private var selectedBackgroundColor: Color = Color(hex: UserDefaults.standard.string(forKey: "customBackgroundColor") ?? "#000000") ?? Color.primaryBackground
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("bundleID") private var bundleID: String = ""
    @State private var isProcessing = false
    @State private var isShowingInstalledApps = false
    @State private var isShowingPairingFilePicker = false
    @State private var pairingFileExists: Bool = false
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var importProgress: Float = 0.0
    
    @State private var viewDidAppeared = false
    @State private var pendingBundleIdToEnableJIT: String? = nil
    @StateObject private var appsViewModel = InstalledAppsViewModel()
    
    var recentBundleIDs: [String] {
        return recentBundleIDsString.split(separator: ",").map(String.init)
    }
    
    func addToRecent(bundleID: String) {
        var recent = recentBundleIDs
        if let index = recent.firstIndex(of: bundleID) {
            recent.remove(at: index)
        }
        recent.insert(bundleID, at: 0)
        if recent.count > 5 {
            recent = Array(recent.prefix(5))
        }
        recentBundleIDsString = recent.joined(separator: ",")
    }

    var body: some View {
        ZStack {
            selectedBackgroundColor.edgesIgnoringSafeArea(.all)
            
            homeContent
        }
        .onAppear {
            checkPairingFileExists()
            if pairingFileExists {
                loadApps()
            }
        }
        .onReceive(timer) { _ in
            refreshBackground()
            checkPairingFileExists()
        }
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList]) { result in
            handleFileImportResult(result)
        }
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackHelper.trigger()
                addToRecent(bundleID: selectedBundle)
                startJITInBackground(with: selectedBundle)
            }
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .onAppear() {
            viewDidAppeared = true
            if let pendingBundleId = pendingBundleIdToEnableJIT {
                addToRecent(bundleID: pendingBundleId)
                startJITInBackground(with: pendingBundleId)
                self.pendingBundleIdToEnableJIT = nil
            }
        }
    }
    
    // Breaking up the homeContent into a computed property to help with type-checking
    var homeContent: some View {
        VStack(spacing: 25) {
            Spacer()
            
            headerView
            
            mainActionButton
            
            // Recent Apps Section
            if pairingFileExists && !recentBundleIDs.isEmpty {
                recentAppsSection
            }
            
            statusMessageArea
            
            Spacer()
        }
        .padding()
    }
    
    var headerView: some View {
        VStack(spacing: 5) {
            Text("Welcome to StikJIT \(username)!")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
            
            Text(pairingFileExists ? "Click enable JIT to get started" : "Pick pairing file to get started")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    var mainActionButton: some View {
        Button(action: {
            if pairingFileExists {
                isShowingInstalledApps = true
            } else {
                isShowingPairingFilePicker = true
            }
        }) {
            HStack {
                Image(systemName: pairingFileExists ? "bolt.fill" : "doc.badge.plus")
                    .font(.system(size: 20))
                Text(pairingFileExists ? "Enable JIT" : "Select Pairing File")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
    }
    
    var recentAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Apps")
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(recentBundleIDs, id: \.self) { bundleID in
                        Button(action: {
                            HapticFeedbackHelper.trigger()
                            startJITInBackground(with: bundleID)
                        }) {
                            VStack(spacing: 8) {
                                if let appName = appsViewModel.apps[bundleID] {
                                    AppIconView(bundleID: bundleID, appName: appName, viewModel: appsViewModel)
                                        .frame(width: 60, height: 60)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.blue)
                                        )
                                }
                                
                                Text(appsViewModel.apps[bundleID] ?? bundleID.components(separatedBy: ".").last ?? "App")
                                    .font(.system(size: 12, design: .rounded))
                                    .lineLimit(1)
                                    .frame(width: 70)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 5)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground.opacity(0.4))
                .padding(.horizontal, 12)
        )
        .padding(.horizontal, 8)
        .padding(.top, 5)
    }
    
    var statusMessageArea: some View {
        ZStack {
            if isImportingFile {
                importProgressView
            }
            
            if showPairingFileMessage && pairingFileIsValid {
                Text("✓ Pairing file successfully imported")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
            
            Text(" ").opacity(0)
        }
        .frame(height: isImportingFile ? 60 : 30)
    }
    
    var importProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Processing pairing file...")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
                Spacer()
                Text("\(Int(importProgress * 100))%")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(importProgress), height: 8)
                        .animation(.linear(duration: 0.3), value: importProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 40)
    }
    
    private func handleFileImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let fileManager = FileManager.default
            let accessing = url.startAccessingSecurityScopedResource()
            
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let destinationURL = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    
                    try fileManager.copyItem(at: url, to: destinationURL)
                    print("File copied successfully!")
                    
                    DispatchQueue.main.async {
                        isImportingFile = true
                        importProgress = 0.0
                        pairingFileExists = true
                    }
                    
                    startHeartbeatInBackground()
                    
                    let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                        DispatchQueue.main.async {
                            if importProgress < 1.0 {
                                importProgress += 0.25
                            } else {
                                timer.invalidate()
                                isImportingFile = false
                                pairingFileIsValid = true
                                
                                withAnimation {
                                    showPairingFileMessage = true
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation {
                                        showPairingFileMessage = false
                                    }
                                }
                                
                                loadApps()
                            }
                        }
                    }
                    
                    RunLoop.current.add(progressTimer, forMode: .common)
                    
                } catch {
                    print("Error copying file: \(error)")
                }
            } else {
                print("Source file does not exist.")
            }
            
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            print("Failed to import file: \(error)")
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        print(url.path())
        if url.host() != "enable-jit" {
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
            if viewDidAppeared {
                addToRecent(bundleID: bundleId)
                startJITInBackground(with: bundleId)
            } else {
                pendingBundleIdToEnableJIT = bundleId
            }
        }
    }
    
    private func loadApps() {
        appsViewModel.loadApps()
    }
    
    private func checkPairingFileExists() {
        pairingFileExists = FileManager.default.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
    }
    
    private func refreshBackground() {
        selectedBackgroundColor = Color(hex: customBackgroundColorHex) ?? Color.primaryBackground
    }
    
    private func startJITInBackground(with bundleID: String) {
        isProcessing = true
        DispatchQueue.global(qos: .background).async {
            JITEnableContext.shared().debugApp(withBundleID: bundleID, logger: nil)
            
            DispatchQueue.main.async {
                isProcessing = false
            }
        }
    }
}

// Helper view to display app icons in recent apps list
struct AppIconView: View {
    let bundleID: String
    let appName: String
    let viewModel: InstalledAppsViewModel
    @State private var appIcon: UIImage?
    
    var body: some View {
        ZStack {
            if let image = appIcon {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray5))
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 26))
                            .foregroundColor(.gray)
                    )
                    .onAppear {
                        loadAppIcon()
                    }
            }
            
            // JIT indicator badge
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                )
                .position(x: 50, y: 10)
        }
    }
    
    private func loadAppIcon() {
        viewModel.loadAppIcon(for: bundleID) { image in
            if let image = image {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.appIcon = image
                    }
                }
            }
        }
    }
}
