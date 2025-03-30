//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
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
    @AppStorage("connectionMode") private var connectionMode: Int = 0 // 0 = USB, 1 = TCP/WiFi
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
    @State private var pendingBundleIdToEnableJIT : String? = nil

    var body: some View {
        ZStack {
            selectedBackgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Spacer()
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
                
                // Connection mode indicator when in USB mode
                if connectionMode == 0 {
                    HStack {
                        Image(systemName: "cable.connector")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        Text("USB Mode")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("WiFi/WireGuard Mode")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Main action button - changes based on whether we have a pairing file
                Button(action: {
                    if pairingFileExists {
                        // Got a pairing file, show apps
                        if !isMounted() {
                            showAlert(title: "Device Not Mounted", message: "The Developer Disk Image has not been mounted yet. Check in settings for more information.", showOk: true) { cool in
                                // No Need
                            }
                            return
                        }
                        
                        isShowingInstalledApps = true
                        
                    } else {
                        // No pairing file yet, let's get one
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
                
                // Status message area - keeps layout consistent
                ZStack {
                    // Progress bar for importing file
                    if isImportingFile {
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
                    
                    // Success message
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
                    
                    // Invisible text to reserve space - no layout jumps
                    Text(" ").opacity(0)
                }
                .frame(height: isImportingFile ? 60 : 30)  // Adjust height based on what's showing
                
                Spacer()
                
                // Add a connection mode explanation at the bottom
                VStack(spacing: 4) {
                    Text(connectionMode == 0 ? 
                        "USB mode: Connect your device with a cable" : 
                        "WireGuard mode: Ensure WireGuard is connected")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("Change connection mode in Settings")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 16)
            }
            .padding()
        }
        .onAppear {
            checkPairingFileExists()
            let swiftMode: JITEnableContextSwiftBridge.ConnectionModeSwift = connectionMode == 0 ? .USB : .TCP
            JITEnableContext.shared().setConnectionModeSwift(swiftMode)
            
            // Add to logs
            LogManager.shared.addInfoLog("App started in \(connectionMode == 0 ? "USB" : "WiFi/WireGuard") mode")
        }
        .onReceive(timer) { _ in
            refreshBackground()
            checkPairingFileExists()
        }
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList]) {result in
            switch result {
            
            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        if fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path) {
                            try fileManager.removeItem(at: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        }
                        
                        try fileManager.copyItem(at: url, to: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        print("File copied successfully!")
                        
                        // Show progress bar and initialize progress
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0.0
                            pairingFileExists = true
                        }
                        
                        // Start heartbeat in background
                        startHeartbeatInBackground()
                        
                        // Create timer to update progress instead of sleeping
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.25
                                } else {
                                    timer.invalidate()
                                    isImportingFile = false
                                    pairingFileIsValid = true
                                    
                                    // Show success message
                                    withAnimation {
                                        showPairingFileMessage = true
                                    }
                                    
                                    // Hide message after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            showPairingFileMessage = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Ensure timer keeps running
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
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackUtil.trigger()   // Use the new struct name
                startJITInBackground(with: selectedBundle)
            }
        }
        .onOpenURL { url in
            print(url.path())
            if url.host() != "enable-jit" {
                return
            }
            
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
                if viewDidAppeared {
                    startJITInBackground(with: bundleId)
                } else {
                    pendingBundleIdToEnableJIT = bundleId
                }
            }
            
        }
        .onAppear() {
            viewDidAppeared = true
            if let pendingBundleIdToEnableJIT {
                startJITInBackground(with: pendingBundleIdToEnableJIT)
                self.pendingBundleIdToEnableJIT = nil
            }
        }
    }
    
    private func checkPairingFileExists() {
        pairingFileExists = FileManager.default.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
    }
    
    private func refreshBackground() {
        selectedBackgroundColor = Color(hex: customBackgroundColorHex) ?? Color.primaryBackground
    }
    
    private func startJITInBackground(with bundleID: String) {
        isProcessing = true
        
        // Add log message with connection mode info
        let modeString = connectionMode == 0 ? "USB" : "WiFi/WireGuard"
        LogManager.shared.addInfoLog("Starting JIT for \(bundleID) using \(modeString) mode")
        
        DispatchQueue.global(qos: .background).async {
            JITEnableContext.shared().debugApp(withBundleID: bundleID, logger: { message in
                if let message = message {
                    // Log messages from the JIT process
                    LogManager.shared.addInfoLog(message)
                }
            })
            
            DispatchQueue.main.async {
                LogManager.shared.addInfoLog("JIT process completed for \(bundleID)")
                isProcessing = false
            }
        }
    }
}

// ViewModel for InstalledAppsListView
class InstalledAppsViewModel: ObservableObject {
    @Published var apps: [String: String] = [:]
    @Published var appIcons: [String: UIImage] = [:]
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        do {
            // Use the new Swift-friendly method
            if let appList = JITEnableContext.shared().getAppList() {
                self.apps = appList
            } else {
                print("Error loading apps")
                self.apps = [:]
            }
         } catch {
            print("Error loading apps: \(error)")
            self.apps = [:]
        }
    }
    
    func loadAppIcon(for bundleID: String, completion: @escaping (UIImage?) -> Void) {
        // Implement app icon loading logic here
        // For now, just complete with nil
        completion(nil)
    }
}

#Preview {
    HomeView()
}
