//
//  AISuggestionsArrowView.swift
//  HSTracker
//
//  Arrow overlay for HearthstoneOne AI suggestions.
//  Draws arrows from suggested card to target.
//

import Foundation
import AppKit

/// View that draws arrow indicators for AI suggestions
class AISuggestionsArrowView: NSView {
    
    /// Current suggestion to display
    var suggestion: AISuggestion? {
        didSet {
            needsDisplay = true
        }
    }
    
    /// Number of cards in hand (for position calculation)
    var handCount: Int = 0
    
    /// Number of minions on opponent board
    var opponentBoardCount: Int = 0
    
    /// Number of minions on player board
    var playerBoardCount: Int = 0
    
    // MARK: - Colors
    
    private let arrowColor = NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.2, alpha: 0.9) // Green
    private let highlightColor = NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.0, alpha: 0.5) // Yellow glow
    private let targetColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.3, alpha: 0.7) // Red target
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let suggestion = suggestion else { return }
        
        // Only draw for play_card actions
        guard suggestion.action == "play_card",
              let cardIndex = suggestion.cardIndex else { return }
        
        // Get card position in hand
        let cardPos = getHandCardPosition(index: cardIndex, handSize: handCount)
        
        // Draw card highlight
        drawCardHighlight(at: cardPos)
        
        // Draw arrow if there's a target
        if let targetType = suggestion.targetType {
            let targetPos = getTargetPosition(targetType: targetType, targetIndex: suggestion.targetIndex)
            drawArrow(from: cardPos, to: targetPos)
            drawTargetHighlight(at: targetPos)
        }
    }
    
    // MARK: - Position Calculations
    
    /// Get position of a card in hand
    private func getHandCardPosition(index: Int, handSize: Int) -> NSPoint {
        let hs = SizeHelper.hearthstoneWindow.frame
        let ratio = SizeHelper.screenRatio
        
        // Hand is centered horizontally
        // Cards are at bottom ~12% of screen
        let handY = hs.height * 0.06
        
        // Hand width depends on card count
        // Each card is roughly 8% of screen width
        let cardWidth = hs.width * 0.08 * ratio
        let totalHandWidth = cardWidth * CGFloat(handSize)
        let handStartX = (hs.width - totalHandWidth) / 2
        
        // Card center
        let cardCenterX = handStartX + cardWidth * (CGFloat(index) + 0.5)
        let cardCenterY = handY
        
        // Adjust for screen position
        return NSPoint(x: hs.minX + SizeHelper.getScaledXPos(cardCenterX / hs.width, width: hs.width, ratio: ratio),
                       y: hs.minY + cardCenterY)
    }
    
    /// Get position of target (minion or hero)
    private func getTargetPosition(targetType: String, targetIndex: Int?) -> NSPoint {
        let hs = SizeHelper.hearthstoneWindow.frame
        let ratio = SizeHelper.screenRatio
        
        switch targetType {
        case "enemy_hero":
            // Enemy hero is at top center
            let heroX = hs.width * 0.5
            let heroY = hs.height * 0.85
            return NSPoint(x: hs.minX + SizeHelper.getScaledXPos(heroX / hs.width, width: hs.width, ratio: ratio),
                           y: hs.minY + heroY)
            
        case "friendly_hero":
            // Friendly hero is at bottom center
            let heroX = hs.width * 0.5
            let heroY = hs.height * 0.15
            return NSPoint(x: hs.minX + SizeHelper.getScaledXPos(heroX / hs.width, width: hs.width, ratio: ratio),
                           y: hs.minY + heroY)
            
        case "enemy_minion":
            // Opponent's board
            return getMinionPosition(index: targetIndex ?? 0, boardSize: opponentBoardCount, isOpponent: true)
            
        case "friendly_minion":
            // Player's board
            return getMinionPosition(index: targetIndex ?? 0, boardSize: playerBoardCount, isOpponent: false)
            
        default:
            // Default to center
            return NSPoint(x: hs.minX + hs.width / 2, y: hs.minY + hs.height / 2)
        }
    }
    
    /// Get position of a minion on board
    private func getMinionPosition(index: Int, boardSize: Int, isOpponent: Bool) -> NSPoint {
        let hs = SizeHelper.hearthstoneWindow.frame
        let ratio = SizeHelper.screenRatio
        
        // Board is centered horizontally
        let minionWidth = SizeHelper.minionWidth
        let minionMargin = SizeHelper.minionMargin
        let totalBoardWidth = minionWidth * CGFloat(boardSize) + minionMargin * CGFloat(boardSize) * 2
        let boardStartX = (hs.width - totalBoardWidth) / 2
        
        // Minion center
        let minionCenterX = boardStartX + (minionWidth + minionMargin * 2) * (CGFloat(index) + 0.5)
        
        // Y position: opponent board is higher
        let minionCenterY = isOpponent ? hs.height * 0.62 : hs.height * 0.38
        
        return NSPoint(x: hs.minX + SizeHelper.getScaledXPos(minionCenterX / hs.width, width: hs.width, ratio: ratio),
                       y: hs.minY + minionCenterY)
    }
    
    // MARK: - Drawing Helpers
    
    /// Draw highlight circle around card
    private func drawCardHighlight(at point: NSPoint) {
        let radius: CGFloat = 35
        let rect = NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        
        let path = NSBezierPath(ovalIn: rect)
        highlightColor.setFill()
        path.fill()
        
        arrowColor.setStroke()
        path.lineWidth = 3
        path.stroke()
    }
    
    /// Draw target circle
    private func drawTargetHighlight(at point: NSPoint) {
        let radius: CGFloat = 30
        let rect = NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        
        // Outer ring
        let path = NSBezierPath(ovalIn: rect)
        targetColor.setStroke()
        path.lineWidth = 4
        path.stroke()
        
        // Inner ring
        let innerRadius: CGFloat = 15
        let innerRect = NSRect(x: point.x - innerRadius, y: point.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
        let innerPath = NSBezierPath(ovalIn: innerRect)
        targetColor.setStroke()
        innerPath.lineWidth = 2
        innerPath.stroke()
        
        // Center dot
        let dotRadius: CGFloat = 5
        let dotRect = NSRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        targetColor.setFill()
        dotPath.fill()
    }
    
    /// Draw arrow from source to target
    private func drawArrow(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        
        // Calculate direction
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        
        guard length > 0 else { return }
        
        // Normalize
        let nx = dx / length
        let ny = dy / length
        
        // Shorten arrow to not overlap with circles
        let startOffset: CGFloat = 40
        let endOffset: CGFloat = 35
        let adjustedStart = NSPoint(x: start.x + nx * startOffset, y: start.y + ny * startOffset)
        let adjustedEnd = NSPoint(x: end.x - nx * endOffset, y: end.y - ny * endOffset)
        
        // Draw line
        path.move(to: adjustedStart)
        path.line(to: adjustedEnd)
        
        arrowColor.setStroke()
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.stroke()
        
        // Draw arrowhead
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = 0.5 // radians (~30 degrees)
        
        let angle = atan2(dy, dx)
        let arrowPoint1 = NSPoint(
            x: adjustedEnd.x - arrowLength * cos(angle - arrowAngle),
            y: adjustedEnd.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = NSPoint(
            x: adjustedEnd.x - arrowLength * cos(angle + arrowAngle),
            y: adjustedEnd.y - arrowLength * sin(angle + arrowAngle)
        )
        
        let arrowHead = NSBezierPath()
        arrowHead.move(to: adjustedEnd)
        arrowHead.line(to: arrowPoint1)
        arrowHead.move(to: adjustedEnd)
        arrowHead.line(to: arrowPoint2)
        
        arrowColor.setStroke()
        arrowHead.lineWidth = 4
        arrowHead.lineCapStyle = .round
        arrowHead.stroke()
    }
}

/// Overlay controller for arrow indicators
class AISuggestionsArrowOverlay: OverWindowController {
    
    override var alwaysLocked: Bool { true }
    
    private var arrowView = AISuggestionsArrowView()
    
    /// Programmatic initialization
    convenience init() {
        // Create transparent window covering screen
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        self.init(window: panel)
        panel.contentView = arrowView
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window!.contentView = arrowView
        self.window!.isOpaque = false
        self.window!.backgroundColor = NSColor.clear
    }
    
    /// Update suggestion and board state
    func update(suggestion: AISuggestion?, handCount: Int, opponentBoardCount: Int, playerBoardCount: Int) {
        arrowView.suggestion = suggestion
        arrowView.handCount = handCount
        arrowView.opponentBoardCount = opponentBoardCount
        arrowView.playerBoardCount = playerBoardCount
        arrowView.needsDisplay = true
    }
    
    /// Clear the arrow
    func clear() {
        arrowView.suggestion = nil
        arrowView.needsDisplay = true
    }
    
    override func updateFrames() {
        self.window!.ignoresMouseEvents = true
        
        // Cover entire Hearthstone window
        let frame = SizeHelper.overHearthstoneFrame()
        self.window?.setFrame(frame, display: true)
    }
}
