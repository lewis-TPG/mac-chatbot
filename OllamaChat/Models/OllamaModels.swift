import Foundation

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: [String: Any]?
    
    private enum CodingKeys: String, CodingKey {
        case model, prompt, stream, options
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(stream, forKey: .stream)
        
        if let options = options {
            var optionsContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .options)
            for (key, value) in options {
                if let intValue = value as? Int {
                    try optionsContainer.encode(intValue, forKey: DynamicCodingKey(stringValue: key)!)
                } else if let doubleValue = value as? Double {
                    try optionsContainer.encode(doubleValue, forKey: DynamicCodingKey(stringValue: key)!)
                } else if let boolValue = value as? Bool {
                    try optionsContainer.encode(boolValue, forKey: DynamicCodingKey(stringValue: key)!)
                } else if let stringValue = value as? String {
                    try optionsContainer.encode(stringValue, forKey: DynamicCodingKey(stringValue: key)!)
                }
            }
        }
    }
}

struct OllamaResponse: Codable {
    let model: String
    let createdAt: String
    let response: String
    let done: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case response
        case done
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}