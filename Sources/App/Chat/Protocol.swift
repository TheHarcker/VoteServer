import Foundation


//MARK: Server to client
struct ChatFormat: Codable{
	
	// Unique ID of a message
	var id: UUID
	
	// Author of a message
	var sender: String
	
	// Content of a message
	var message: String
	
	// When the message was send
	var timestamp: Date
	
	// A message from the admin / server
	var isSystemsMessage: Bool
}

enum ServerChatProtocol: Codable{
	case newMessages([ChatFormat])
	// The server can request the client to reload the plaza, e.g. if a new vote has opened
	case requestReload
	case error(ChatError)
	
	static func newMessage(_ chat: ChatFormat) -> Self{
		return ServerChatProtocol.newMessages([chat])
	}
}

//MARK: Client to server
enum ClientChatProtocol: Codable{
	case query
	case send(String)
}
