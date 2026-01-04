//
//  HearthstoneOnePreferences.swift
//  HSTracker
//
//  Created by HearthstoneOne AI on 05/01/26.
//  Copyright © 2026 Benjamin Michotte. All rights reserved.
//

import Foundation
import Preferences

class HearthstoneOnePreferences: NSViewController, PreferencePane {
    var preferencePaneIdentifier = Preferences.PaneIdentifier.hearthstoneOne
    
    var preferencePaneTitle = String.localizedString("AI", comment: "")
    
    // We can reuse an existing icon or use a system one. 
    // using "brain" or similar if available, otherwise just use a generic one or the app icon
    var toolbarItemIcon = NSImage(systemSymbolName: "brain", accessibilityDescription: "AI") ?? NSImage(named: NSImage.networkName)!

    private let stackView = NSStackView()
    private let enableCheckbox = NSButton(checkboxWithTitle: "Enable HearthstoneOne AI", target: nil, action: nil)
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "Status: Not Connected")
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        loadSettings()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        loadSettings()
    }

    private func setupUI() {
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Header
        let headerLabel = NSTextField(labelWithString: "HearthstoneOne AI Assistant")
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        stackView.addArrangedSubview(headerLabel)
        
        // Enable Checkbox
        stackView.addArrangedSubview(enableCheckbox)
        
        // Separator
        stackView.addArrangedSubview(NSBox())
        
        // Connection Settings Group
        let settingsGrid = NSGridView(views: [
            [NSTextField(labelWithString: "Server Host:"), hostField],
            [NSTextField(labelWithString: "Server Port:"), portField]
        ])
        settingsGrid.rowSpacing = 10
        settingsGrid.columnSpacing = 10
        settingsGrid.xPlacement = .leading
        
        hostField.placeholderString = "localhost"
        portField.placeholderString = "9876"
        
        // Make fields wider
        NSLayoutConstraint.activate([
            hostField.widthAnchor.constraint(equalToConstant: 200),
            portField.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        stackView.addArrangedSubview(settingsGrid)
        
        // Status indicator (simple placeholder for now)
        let noteLabel = NSTextField(labelWithString: "Note: Ensure the 'server.py' script is running.")
        noteLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(noteLabel)
    }
    
    private func setupActions() {
        enableCheckbox.target = self
        enableCheckbox.action = #selector(checkboxClicked(_:))
        
        hostField.target = self
        hostField.action = #selector(configChanged(_:))
        
        portField.target = self
        portField.action = #selector(configChanged(_:))
    }
    
    private func loadSettings() {
        enableCheckbox.state = Settings.hearthstoneOneEnabled ? .on : .off
        hostField.stringValue = Settings.hearthstoneOneHost
        portField.stringValue = String(Settings.hearthstoneOnePort)
    }
    
    @objc func checkboxClicked(_ sender: NSButton) {
        Settings.hearthstoneOneEnabled = (sender.state == .on)
    }
    
    @objc func configChanged(_ sender: Any) {
        Settings.hearthstoneOneHost = hostField.stringValue
        if let port = Int(portField.stringValue) {
            Settings.hearthstoneOnePort = port
        }
    }
}

extension Preferences.PaneIdentifier {
    static let hearthstoneOne = Self("hearthstoneOne")
}
