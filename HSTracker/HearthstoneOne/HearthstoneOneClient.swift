//
//  HearthstoneOneClient.swift
//  HSTracker
//
//  HearthstoneOne AI integration client.
//  Connects to the Python suggestion server.
//

import Foundation

/// AI suggestion from HearthstoneOne server
struct AISuggestion: Codable {
    let action: String
    let cardId: String?
    let cardName: String?
    let cardIndex: Int?
    let targetType: String?
    let targetIndex: Int?
    let winProbability: Double
    let alternatives: [[String: Any]]?
    
    enum CodingKeys: String, CodingKey {
        case action
        case cardId = "card_id"
        case cardName = "card_name"
        case cardIndex = "card_index"
        case targetType = "target_type"
        case targetIndex = "target_index"
        case winProbability = "win_probability"
        case alternatives
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        cardId = try container.decodeIfPresent(String.self, forKey: .cardId)
        cardName = try container.decodeIfPresent(String.self, forKey: .cardName)
        cardIndex = try container.decodeIfPresent(Int.self, forKey: .cardIndex)
        targetType = try container.decodeIfPresent(String.self, forKey: .targetType)
        targetIndex = try container.decodeIfPresent(Int.self, forKey: .targetIndex)
        winProbability = try container.decodeIfPresent(Double.self, forKey: .winProbability) ?? 0.5
        alternatives = nil // Skip complex nested decoding for now
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encodeIfPresent(cardId, forKey: .cardId)
        try container.encodeIfPresent(cardName, forKey: .cardName)
        try container.encodeIfPresent(cardIndex, forKey: .cardIndex)
        try container.encodeIfPresent(targetType, forKey: .targetType)
        try container.encodeIfPresent(targetIndex, forKey: .targetIndex)
        try container.encode(winProbability, forKey: .winProbability)
    }
}


/// Client for HearthstoneOne AI suggestion server
class HearthstoneOneClient {
    
    /// Shared instance
    static let shared = HearthstoneOneClient()
    
    /// Server configuration - can be changed in preferences
    var serverHost: String = "localhost"
    var serverPort: Int = 9876
    
    /// Connection state
    private(set) var isConnected: Bool = false
    private(set) var lastError: String?
    
    /// URLSession for requests
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        return URLSession(configuration: config)
    }()
    
    /// Base URL for server (with fallback for invalid host)
    var baseURL: URL {
        if let url = URL(string: "http://\(serverHost):\(serverPort)") {
            return url
        }
        // Fallback to localhost if host is invalid
        return URL(string: "http://localhost:\(serverPort)")!
    }
    
    /// Initialize with settings
    init() {
        // Load from settings if available
        loadSettings()
    }
    
    /// Load settings from UserDefaults
    func loadSettings() {
        serverHost = Settings.hearthstoneOneHost
        serverPort = Settings.hearthstoneOnePort
    }
    
    /// Save settings to UserDefaults
    func saveSettings() {
        Settings.hearthstoneOneHost = serverHost
        Settings.hearthstoneOnePort = serverPort
    }
    
    /// Check if server is available
    func checkHealth(completion: @escaping (Bool, String?) -> Void) {
        let url = baseURL.appendingPathComponent("health")
        
        let task = session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isConnected = false
                    self.lastError = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    self.isConnected = false
                    self.lastError = "Server returned error"
                    completion(false, "Server returned error")
                    return
                }
                
                self.isConnected = true
                self.lastError = nil
                completion(true, nil)
            }
        }
        task.resume()
    }
    
    /// Get AI suggestion for current game state
    func getSuggestion(hand: [[String: Any]], mana: Int, opponentBoard: [[String: Any]], playerBoard: [[String: Any]], completion: @escaping (AISuggestion?, String?) -> Void) {
        
        let url = baseURL.appendingPathComponent("suggest")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build game state
        let gameState: [String: Any] = [
            "hand": hand,
            "mana": mana,
            "opponent_board": opponentBoard,
            "player_board": playerBoard
        ]
        
        let requestBody: [String: Any] = ["game_state": gameState]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, "Failed to serialize request")
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isConnected = false
                    completion(nil, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    completion(nil, "No data received")
                    return
                }
                
                do {
                    let suggestion = try JSONDecoder().decode(AISuggestion.self, from: data)
                    self.isConnected = true
                    completion(suggestion, nil)
                } catch {
                    completion(nil, "Failed to decode response: \(error)")
                }
            }
        }
        task.resume()
    }
    
    /// Convert HSTracker entities to game state format
    static func buildGameState(player: Player, opponent: Player) -> (hand: [[String: Any]], mana: Int, opponentBoard: [[String: Any]], playerBoard: [[String: Any]]) {
        
        // Build hand
        var hand: [[String: Any]] = []
        for entity in player.hand {
            hand.append([
                "id": entity.cardId,
                "name": entity.card.name,
                "cost": entity[.cost],
                "type": entity.card.type.rawValue
            ])
        }
        
        // Build opponent board
        var oppBoard: [[String: Any]] = []
        for entity in opponent.board.filter({ $0.isMinion }) {
            oppBoard.append([
                "id": entity.cardId,
                "attack": entity.attack,
                "health": entity.health,
                "position": entity.zonePosition
            ])
        }
        
        // Build player board
        var playerBoard: [[String: Any]] = []
        for entity in player.board.filter({ $0.isMinion }) {
            playerBoard.append([
                "id": entity.cardId,
                "attack": entity.attack,
                "health": entity.health,
                "position": entity.zonePosition
            ])
        }
        
        return (hand, player.currentMana, oppBoard, playerBoard)
    }
}
