//  SettingsView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.

import SwiftUI
import UniformTypeIdentifiers

// ConsoleLogsView implementation - integrated directly into SettingsView.swift
struct ConsoleLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logManager = LogManager.shared
    @State private var autoScroll = true
    @State private var scrollView: ScrollViewProxy? = nil
    
    // Alert handling
    @State private var showingExportAlert = false
    @State private var showingCopyAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Terminal logs area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Device Information
                                ForEach(["Version: \(UIDevice.current.systemVersion)",
                                         "Name: \(UIDevice.current.name)",
                                         "Model: \(UIDevice.current.model)",
                                         "StikJIT Version: App Version: 1.0"], id: \.self) { info in
                                    Text("[\(timeString())] ℹ️ \(info)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                }
                                
                                Spacer()
                                
                                // Log entries 
                                ForEach(logManager.logs) { logEntry in
                                    Text(AttributedString(createLogAttributedString(logEntry)))
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 1)
                                        .padding(.horizontal, 4)
                                        .id(logEntry.id)
                                }
                            }
                        }
                        .onAppear {
                            scrollView = proxy
                        }
                        .onChange(of: logManager.logs.count) {
                            if autoScroll, let lastLog = logManager.logs.last {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Error count with red theme
                        HStack {
                            Text("\(logManager.errorCount) Critical Errors.")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Action buttons with dark background
                        VStack(spacing: 1) {
                            // Export button
                            Button(action: {
                                exportLogs()
                            }) {
                                HStack {
                                    Text("Export Logs")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            
                            Divider()
                                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            
                            // Copy button
                            Button(action: {
                                copyLogs()
                            }) {
                                HStack {
                                    Text("Copy Logs")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                        }
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Console Logs")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Settings")
                                .fontWeight(.regular)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logManager.clearLogs()
                    }) {
                        Text("Clear")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(alertTitle, isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert(alertTitle, isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // Creates a formatted string for logs
    private func createLogAttributedString(_ logEntry: LogManager.LogEntry) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        
        // Timestamp part
        let timestampString = "[\(formatTime(date: logEntry.timestamp))]"
        let timestampAttr = NSAttributedString(
            string: timestampString,
            attributes: [.foregroundColor: UIColor.gray]
        )
        fullString.append(timestampAttr)
        fullString.append(NSAttributedString(string: " "))
        
        // Log type part
        let typeString = "[\(logEntry.type.rawValue)]"
        let typeColor = UIColor(colorForLogType(logEntry.type))
        let typeAttr = NSAttributedString(
            string: typeString,
            attributes: [.foregroundColor: typeColor]
        )
        fullString.append(typeAttr)
        fullString.append(NSAttributedString(string: " "))
        
        // Message part
        let messageAttr = NSAttributedString(
            string: logEntry.message,
            attributes: [.foregroundColor: UIColor.white]
        )
        fullString.append(messageAttr)
        
        return fullString
    }
    
    // Helper to display current time
    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    // Helper to format Date objects to time strings
    private func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Return color based on log type
    private func colorForLogType(_ type: LogManager.LogEntry.LogType) -> Color {
        switch type {
        case .info:
            return .green
        case .error:
            return .red
        case .debug:
            return .blue
        case .warning:
            return .orange
        }
    }
    
    // Export logs to a file
    private func exportLogs() {
        // Create logs content with device information
        var logsContent = "=== DEVICE INFORMATION ===\n"
        logsContent += "Version: \(UIDevice.current.systemVersion)\n"
        logsContent += "Name: \(UIDevice.current.name)\n" 
        logsContent += "Model: \(UIDevice.current.model)\n"
        logsContent += "StikJIT Version: App Version: 1.0\n\n"
        logsContent += "=== LOG ENTRIES ===\n"
        
        // Add all log entries with proper formatting
        logsContent += logManager.logs.map { 
            "[\(formatTime(date: $0.timestamp))] [\($0.type.rawValue)] \($0.message)" 
        }.joined(separator: "\n")
        
        // Save to document directory (accessible in Files app)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileURL = documentsDirectory.appendingPathComponent("StikJIT_Logs_\(timestamp).txt")
        
        do {
            // Write the logs to the file
            try logsContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set alert variables and show the alert
            alertTitle = "Logs Exported"
            alertMessage = "Logs have been saved to Files app in StikJIT folder."
            isError = false
            showingExportAlert = true
        } catch {
            // Set error alert variables and show the alert
            alertTitle = "Export Failed"
            alertMessage = "Failed to save logs: \(error.localizedDescription)"
            isError = true
            showingExportAlert = true
        }
    }
    
    // Copy logs to clipboard
    private func copyLogs() {
        // Create logs content with device information
        var logsContent = "=== DEVICE INFORMATION ===\n"
        logsContent += "Version: \(UIDevice.current.systemVersion)\n"
        logsContent += "Name: \(UIDevice.current.name)\n" 
        logsContent += "Model: \(UIDevice.current.model)\n"
        logsContent += "StikJIT Version: App Version: 1.0\n\n"
        logsContent += "=== LOG ENTRIES ===\n"
        
        // Add all log entries with proper formatting
        logsContent += logManager.logs.map { 
            "[\(formatTime(date: $0.timestamp))] [\($0.type.rawValue)] \($0.message)" 
        }.joined(separator: "\n")
        
        // Copy to clipboard
        UIPasteboard.general.string = logsContent
        
        // Show success alert using SwiftUI alert
        alertTitle = "Logs Copied"
        alertMessage = "Logs have been copied to clipboard."
        isError = false
        showingCopyAlert = true
    }
}

struct SettingsView: View {
    @AppStorage("username") private var username = "User"
    @AppStorage("customBackgroundColor") private var customBackgroundColorHex: String = Color.primaryBackground.toHex() ?? "#000000"
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String = "AppIcon"
    @AppStorage("connectionMode") private var connectionMode: Int = 0 // 0 = USB, 1 = TCP/WiFi
    @State private var isShowingPairingFilePicker = false

    @State private var selectedBackgroundColor: Color = Color.primaryBackground
    @State private var showIconPopover = false
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var importProgress: Float = 0.0
    
    @StateObject private var mountProg = MountingProgress.shared
    
    @State private var mounted = false
    
    @State private var showingConsoleLogsView = false
    
    // Developer profile image URLs 
    private let developerProfiles: [String: String] = [
        "Blu": "https://github.com/0-Blu.png",
        "jkcoxson": "https://github.com/jkcoxson.png",
        "Stossy11": "https://github.com/Stossy11.png",
        "Neo": "https://github.com/neoarz.png",
        "Se2crid": "https://github.com/Se2crid.png",
        "HugeBlack": "https://github.com/HugeBlack.png"
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // App Logo and Username Section 
                    VStack(spacing: 16) {
                        // App Logo
                        Image(uiImage: UIImage(named: selectedAppIcon) ?? UIImage(named: "AppIcon") ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 16)
                        
                        Text("StikJIT")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Username", text: $username)
                                .padding(14)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                        .opacity(0.6)
                    
                    // Appearance section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Appearance")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 4)
                            
                            ColorPicker("Background Color", selection: $selectedBackgroundColor)
                                .onChange(of: selectedBackgroundColor) { newColor in
                                    saveCustomBackgroundColor(newColor)
                                }
                                .foregroundColor(.primary)
                                .padding(.vertical, 6)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                    
                    // Connection Settings section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Connection Settings")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 4)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Connection Mode")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Picker for connection mode
                                Picker("Connection Mode", selection: $connectionMode) {
                                    Text("USB").tag(0)
                                    Text("WiFi/WireGuard").tag(1)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .onChange(of: connectionMode) { newValue in
                                    // Update the JITEnableContext when mode changes
                                    // FIXED: Use the ConnectionModeSwift enum now
                                    let swiftMode: ConnectionModeSwift = newValue == 0 ? .USB : .TCP
                                    JITEnableContext.shared().setConnectionModeSwift(swiftMode)
                                    
                                    // Show confirmation alert when changing modes
                                    let modeName = newValue == 0 ? "USB" : "WiFi/WireGuard"
                                    showAlert(title: "Connection Mode Changed", 
                                             message: "Now using \(modeName) mode. This change will take effect when you next enable JIT.", 
                                             showOk: true, completion: { _ in })
                                }
                                
                                if connectionMode == 0 {
                                    Text("USB mode allows JIT without WiFi or WireGuard. Connect your device via USB cable.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                } else {
                                    Text("WiFi/WireGuard mode requires network connectivity via WireGuard.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                    
                    // Pairing File section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Pairing File")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 4)
                            
                            Button {
                                isShowingPairingFilePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 18))
                                    Text("Import New Pairing File")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            if isImportingFile {
                                VStack(spacing: 10) {
                                    HStack {
                                        Text("Processing pairing file...")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(importProgress * 100))%")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(UIColor.tertiarySystemFill))
                                                .frame(height: 10)
                                            
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.green)
                                                .frame(width: geometry.size.width * CGFloat(importProgress), height: 10)
                                                .animation(.linear(duration: 0.3), value: importProgress)
                                        }
                                    }
                                    .frame(height: 10)
                                }
                                .padding(.top, 6)
                            }
                            
                            if showPairingFileMessage && pairingFileIsValid {
                                HStack {
                                    Spacer()
                                    Text("✓ Pairing file successfully imported")
                                        .font(.system(.callout, design: .rounded))
                                        .foregroundColor(.green)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 18)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(10)
                                    Spacer()
                                }
                                .padding(.top, 6)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.9)
                                            .combined(with: .opacity)
                                            .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                        removal: .opacity.animation(.easeOut(duration: 0.25))
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                    
                    // Developer Disk Image section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Developer Disk Image")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 4)
                            
                            // Status indicator with icon
                            HStack(spacing: 12) {
                                Image(systemName: mounted || (mountProg.mountProgress == 100) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(mounted || (mountProg.mountProgress == 100) ? .green : .red)
                                
                                Text(mounted || (mountProg.mountProgress == 100) ? "Successfully Mounted" : "Not Mounted")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(12)
                            
                            // Helper text shown separately below the status indicator
                            if !(mounted || (mountProg.mountProgress == 100)) {
                                Text("Import pairing file and restart the app to mount DDI")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }
                            
                            // Only show progress if actively mounting
                            if mountProg.mountProgress > 0 && mountProg.mountProgress < 100 && !mounted {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Mounting in progress...")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(mountProg.mountProgress))%")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(UIColor.tertiarySystemFill))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.green)
                                                .frame(width: geometry.size.width * CGFloat(mountProg.mountProgress / 100.0), height: 8)
                                                .animation(.linear(duration: 0.3), value: mountProg.mountProgress)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(.top, 6)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .onAppear() {
                            self.mounted = isMounted()
                        }
                    }
                    
                    
                    // About section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 4)
                            
                            // Main Developers 
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Developers")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                              
                                HStack(spacing: 16) {
                                    // App Creator
                                    VStack(spacing: 8) {
                                        ProfileImage(url: developerProfiles["Blu"] ?? "")
                                            .frame(width: 60, height: 60)
                                        
                                        Text("Blu")
                                            .fontWeight(.semibold)
                                        
                                        Text("App Creator")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        if let url = URL(string: "https://github.com/0-Blu") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    
                                    // Library Developer
                                    VStack(spacing: 8) {
                                        ProfileImage(url: developerProfiles["jkcoxson"] ?? "")
                                            .frame(width: 60, height: 60)
                                        
                                        Text("jkcoxson")
                                            .fontWeight(.semibold)
                                        
                                        Text("idevice & em_proxy")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        if let url = URL(string: "https://jkcoxson.com/") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Collaborators in vertical stack
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Collaborators")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Vertical stack of collaborators
                                VStack(spacing: 12) {
                                    CollaboratorRow(name: "Stossy11", url: "https://github.com/Stossy11", imageUrl: developerProfiles["Stossy11"] ?? "")
                                    
                                    CollaboratorRow(name: "Neo", url: "https://neoarz.xyz/", imageUrl: developerProfiles["Neo"] ?? "")
                                    
                                    CollaboratorRow(name: "Se2crid", url: "https://github.com/Se2crid", imageUrl: developerProfiles["Se2crid"] ?? "")
                                    
                                    CollaboratorRow(name: "HugeBlack", url: "https://github.com/HugeBlack", imageUrl: developerProfiles["HugeBlack"] ?? "")
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Links")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 6) {
                                    LinkRow(icon: "link", title: "Source Code", url: "https://github.com/0-Blu/StikJIT")
                                    LinkRow(icon: "xmark.shield", title: "Report an Issue", url: "https://github.com/0-Blu/StikJIT/issues")
                                    
                                    // StikNES promotion - moved here as requested
                                    Button(action: {
                                        if let url = URL(string: "https://apps.apple.com/us/app/stiknes/id6737158545") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Text("Like this app? Check out StikNES!")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Image(systemName: "gamecontroller.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                    
                    // Move System Logs section here (right after About card, before version)
                    SettingsCard {
                        Button(action: {
                            showingConsoleLogsView = true
                        }) {
                            HStack {
                                Text("System Logs")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 16)
                    
                    // Version info should now come after System Logs
                    HStack {
                        Spacer()
                        Text("Version 1.0 • iOS \(UIDevice.current.systemVersion)")
                            .font(.footnote)
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            
            // Add this sheet at the end of the ZStack, before the final closing bracket
            .sheet(isPresented: $showingConsoleLogsView) {
                ConsoleLogsView()
            }
        }
        .fileImporter(
            isPresented: $isShowingPairingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                // Get the first URL from the array
                guard let url = urls.first else { return }
                
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
                            pairingFileIsValid = false
                        }
                        
                        // Create timer to update progress 
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.05
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
                        
                        // Start heartbeat in background
                        startHeartbeatInBackground()
                        
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
        .onAppear {
            loadCustomBackgroundColor()
            
            // Set the connection mode in JITEnableContext when the view appears
            // FIXED: Use the ConnectionModeSwift enum now
            let swiftMode: ConnectionModeSwift = connectionMode == 0 ? .USB : .TCP
            JITEnableContext.shared().setConnectionModeSwift(swiftMode)
        }
    }

    private func loadCustomBackgroundColor() {
        selectedBackgroundColor = Color(hex: customBackgroundColorHex) ?? Color.primaryBackground
    }

    private func saveCustomBackgroundColor(_ color: Color) {
        customBackgroundColorHex = color.toHex() ?? "#000000"
    }

    private func changeAppIcon(to iconName: String) {
        selectedAppIcon = iconName
        UIApplication.shared.setAlternateIconName(iconName == "AppIcon" ? nil : iconName) { error in
            if let error = error {
                print("Error changing app icon: \(error.localizedDescription)")
            }
        }
    }

    private func iconButton(_ label: String, icon: String) -> some View {
        Button(action: {
            changeAppIcon(to: icon)
            showIconPopover = false
        }) {
            HStack {
                Image(uiImage: UIImage(named: icon) ?? UIImage())
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

// Helper components
struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct LinkRow: View {
    var icon: String
    var title: String
    var url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// Component for 2x2 grid layout of collaborators
struct CollaboratorGridItem: View {
    var name: String
    var url: String
    var imageUrl: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 8) {
                ProfileImage(url: imageUrl)
                    .frame(width: 50, height: 50)
                
                Text(name)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                    .font(.subheadline)
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct ProfileImage: View {
    var url: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(Color(UIColor.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let imageUrl = URL(string: url) else { return }
        
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            if let data = data, let downloadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
}

// Component for vertical collaborator list - Removed background for cleaner look
struct CollaboratorRow: View {
    var name: String
    var url: String
    var imageUrl: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                ProfileImage(url: imageUrl)
                    .frame(width: 40, height: 40)
                
                Text(name)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }
}
