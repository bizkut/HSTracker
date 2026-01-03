//
//  AISuggestionsOverlay.swift
//  HSTracker
//
//  Overlay panel showing HearthstoneOne AI suggestions.
//

import Foundation
import AppKit

/// View for displaying AI suggestions
class AISuggestionsView: NSView {
    
    private var statusLabel: NSTextField!
    private var cardLabel: NSTextField!
    private var targetLabel: NSTextField!
    private var winLabel: NSTextField!
    
    private var currentSuggestion: AISuggestion?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.8).cgColor
        layer?.cornerRadius = 8
        
        // Status label
        statusLabel = createLabel(fontSize: 14, bold: true)
        statusLabel.textColor = NSColor.green
        statusLabel.stringValue = "🤖 HearthstoneOne AI"
        addSubview(statusLabel)
        
        // Card label
        cardLabel = createLabel(fontSize: 12, bold: false)
        cardLabel.textColor = NSColor.white
        cardLabel.stringValue = "Waiting for game..."
        addSubview(cardLabel)
        
        // Target label
        targetLabel = createLabel(fontSize: 11, bold: false)
        targetLabel.textColor = NSColor.lightGray
        targetLabel.stringValue = ""
        addSubview(targetLabel)
        
        // Win probability label
        winLabel = createLabel(fontSize: 11, bold: true)
        winLabel.textColor = NSColor.cyan
        winLabel.stringValue = ""
        addSubview(winLabel)
        
        // Layout
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardLabel.translatesAutoresizingMaskIntoConstraints = false
        targetLabel.translatesAutoresizingMaskIntoConstraints = false
        winLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            cardLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            cardLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            cardLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            targetLabel.topAnchor.constraint(equalTo: cardLabel.bottomAnchor, constant: 2),
            targetLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            targetLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            winLabel.topAnchor.constraint(equalTo: targetLabel.bottomAnchor, constant: 4),
            winLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            winLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            winLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func createLabel(fontSize: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        return label
    }
    
    /// Update display with new suggestion
    func update(suggestion: AISuggestion?) {
        currentSuggestion = suggestion
        
        guard let suggestion = suggestion else {
            cardLabel.stringValue = "Waiting for game..."
            targetLabel.stringValue = ""
            winLabel.stringValue = ""
            return
        }
        
        switch suggestion.action {
        case "play_card":
            let cardName = suggestion.cardName ?? "Unknown Card"
            cardLabel.stringValue = "Play: \(cardName)"
            
            if let targetType = suggestion.targetType {
                let targetStr = formatTarget(targetType, index: suggestion.targetIndex)
                targetLabel.stringValue = "→ \(targetStr)"
            } else {
                targetLabel.stringValue = ""
            }
            
        case "attack":
            cardLabel.stringValue = "Attack with minion"
            if let targetType = suggestion.targetType {
                let targetStr = formatTarget(targetType, index: suggestion.targetIndex)
                targetLabel.stringValue = "→ \(targetStr)"
            }
            
        case "hero_power":
            cardLabel.stringValue = "Use Hero Power"
            targetLabel.stringValue = ""
            
        case "end_turn":
            cardLabel.stringValue = "End Turn"
            targetLabel.stringValue = "(No better plays)"
            
        default:
            cardLabel.stringValue = suggestion.action
            targetLabel.stringValue = ""
        }
        
        // Win probability
        let winPct = Int(suggestion.winProbability * 100)
        winLabel.stringValue = "Win: \(winPct)%"
        
        // Color based on win probability
        if suggestion.winProbability >= 0.6 {
            winLabel.textColor = NSColor.green
        } else if suggestion.winProbability >= 0.4 {
            winLabel.textColor = NSColor.yellow
        } else {
            winLabel.textColor = NSColor.red
        }
    }
    
    private func formatTarget(_ targetType: String, index: Int?) -> String {
        switch targetType {
        case "enemy_hero":
            return "Enemy Hero"
        case "friendly_hero":
            return "Your Hero"
        case "enemy_minion":
            if let idx = index {
                return "Enemy Minion #\(idx + 1)"
            }
            return "Enemy Minion"
        case "friendly_minion":
            if let idx = index {
                return "Your Minion #\(idx + 1)"
            }
            return "Your Minion"
        default:
            return targetType
        }
    }
    
    /// Show connecting state
    func showConnecting() {
        statusLabel.textColor = NSColor.orange
        cardLabel.stringValue = "Connecting to AI server..."
        targetLabel.stringValue = ""
        winLabel.stringValue = ""
    }
    
    /// Show error state
    func showError(_ message: String) {
        statusLabel.textColor = NSColor.red
        cardLabel.stringValue = "Error: \(message)"
        targetLabel.stringValue = ""
        winLabel.stringValue = ""
    }
    
    /// Show connected state
    func showConnected() {
        statusLabel.textColor = NSColor.green
    }
}

/// Window controller for AI suggestions overlay
class AISuggestionsOverlay: OverWindowController {
    
    override var alwaysLocked: Bool { true }
    
    private var suggestionsView = AISuggestionsView()
    
    /// Whether AI suggestions are enabled
    static var isEnabled: Bool {
        return Settings.hearthstoneOneEnabled
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window!.contentView = suggestionsView
    }
    
    /// Update with new suggestion
    func update(suggestion: AISuggestion?) {
        suggestionsView.update(suggestion: suggestion)
    }
    
    /// Show connecting state
    func showConnecting() {
        suggestionsView.showConnecting()
    }
    
    /// Show error
    func showError(_ message: String) {
        suggestionsView.showError(message)
    }
    
    /// Show connected
    func showConnected() {
        suggestionsView.showConnected()
    }
    
    override func updateFrames() {
        self.window!.ignoresMouseEvents = true
    }
}
