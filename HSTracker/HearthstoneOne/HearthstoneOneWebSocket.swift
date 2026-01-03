//
//  HearthstoneOneWebSocket.swift
//  HSTracker
//
//  WebSocket client for streaming logs to HearthstoneOne AI server.
//

import Foundation

/// WebSocket client for HearthstoneOne AI server
class HearthstoneOneWebSocket: NSObject {
    
    /// Shared instance
    static let shared = HearthstoneOneWebSocket()
    
    /// Server configuration
    var serverHost: String = "localhost"
    var serverPort: Int = 9876
    
    /// WebSocket connection
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    /// Connection state
    private(set) var isConnected: Bool = false
    private(set) var lastError: String?
    
    /// Callback for received suggestions
    var onSuggestionReceived: ((AISuggestion) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    
    /// Reconnection settings
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadSettings()
    }
    
    func loadSettings() {
        serverHost = Settings.hearthstoneOneHost
        serverPort = Settings.hearthstoneOnePort
    }
    
    // MARK: - Connection
    
    /// Connect to the WebSocket server
    func connect() {
        // Cancel any pending reconnect
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        guard webSocketTask == nil else { return }
        
        let urlString = "ws://\(serverHost):\(serverPort)"
        guard let url = URL(string: urlString) else {
            lastError = "Invalid WebSocket URL"
            return
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        logger.info("[HearthstoneOneWS] Connecting to \(urlString)")
    }
    
    /// Disconnect from the server
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
        reconnectAttempts = 0
    }
    
    // MARK: - Message Sending
    
    /// Send a log line to the server
    func sendLogLine(_ line: String) {
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "type": "log",
            "line": line
        ]
        
        sendJSON(message)
    }
    
    /// Request an AI suggestion
    func requestSuggestion() {
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "type": "request_suggestion"
        ]
        
        sendJSON(message)
    }
    
    /// Reset game state on server
    func resetGameState() {
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "type": "reset"
        ]
        
        sendJSON(message)
    }
    
    // MARK: - Private Methods
    
    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error = error {
                logger.warning("[HearthstoneOneWS] Send error: \(error)")
                self?.handleDisconnect()
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // Continue receiving
                
            case .failure(let error):
                logger.warning("[HearthstoneOneWS] Receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseServerMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseServerMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "status":
            // Connection status update
            if let connected = json["connected"] as? Bool {
                logger.info("[HearthstoneOneWS] Status: connected=\(connected)")
            }
            
        case "suggestion":
            // AI suggestion received
            if let suggestion = parseSuggestion(json) {
                DispatchQueue.main.async {
                    self.onSuggestionReceived?(suggestion)
                }
            }
            
        default:
            break
        }
    }
    
    private func parseSuggestion(_ json: [String: Any]) -> AISuggestion? {
        guard let action = json["action"] as? String else { return nil }
        
        // Create decoder-compatible data
        var suggestionDict: [String: Any] = [
            "action": action,
            "win_probability": json["win_probability"] as? Double ?? 0.5
        ]
        
        if let cardId = json["card_id"] as? String {
            suggestionDict["card_id"] = cardId
        }
        if let cardName = json["card_name"] as? String {
            suggestionDict["card_name"] = cardName
        }
        if let cardIndex = json["card_index"] as? Int {
            suggestionDict["card_index"] = cardIndex
        }
        if let targetType = json["target_type"] as? String {
            suggestionDict["target_type"] = targetType
        }
        if let targetIndex = json["target_index"] as? Int {
            suggestionDict["target_index"] = targetIndex
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: suggestionDict),
              let suggestion = try? JSONDecoder().decode(AISuggestion.self, from: data) else {
            return nil
        }
        
        return suggestion
    }
    
    private func handleDisconnect() {
        isConnected = false
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.onConnectionStateChanged?(false)
        }
        
        // Attempt reconnection
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = Double(reconnectAttempts) * 2.0 // Exponential backoff
            
            DispatchQueue.main.async {
                self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.connect()
                }
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HearthstoneOneWebSocket: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("[HearthstoneOneWS] Connected")
        isConnected = true
        reconnectAttempts = 0
        
        DispatchQueue.main.async {
            self.onConnectionStateChanged?(true)
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("[HearthstoneOneWS] Disconnected: \(closeCode)")
        handleDisconnect()
    }
}
