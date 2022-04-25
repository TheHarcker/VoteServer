import Fluent
import Vapor
import VoteKit

final class Chats: Model, Content {
	static let schema = "Chats"
	
	@ID(key: .id)
	var id: UUID?
	
	//@Parent
	@Field(key: "group_id")
	var groupID: UUID
	
	//@Parent
	@Field(key: "sender")
	var sender: String
	
	@Field(key: "message")
	var message: String
	
	@Field(key: "timestamp")
	var timestamp: Date
	
	@Field(key: "systems_message")
	var systemsMessage: Bool
	
	init(id: UUID? = nil, groupID: UUID, sender: String, message: String, timestamp: Date = Date(), systemsMessage: Bool = false){
		self.id = id
		self.groupID = groupID
		self.sender = sender
		self.message = message
		self.timestamp = timestamp
		self.systemsMessage = systemsMessage
	}
	
	init(){
		
	}
}


extension Chats{
	func chatFormat(senderName: String, imageURL: String?) async -> ChatFormat{
		guard self.id != nil else {
			fatalError("Attempted to access chat which hasn't been saved")
		}
				
		return ChatFormat(id: self.id!, sender: senderName, message: self.message, imageURL: imageURL, timestamp: self.timestamp, isSystemsMessage: self.systemsMessage)
	}
}

extension Array where Element == Chats{
	func chatFormat(group: Group) async -> [ChatFormat]{
		let groupID = group.id
		
		guard
			self.allSatisfy( { chat in
				chat.groupID == groupID
			})
		else {
			fatalError("Chatformat called for messages from different groups")
		}
		
		// [ConstituentIdentifier: (ScreenName, gravatar.com + Email hash)]
		var constituents = [String: (name: String, imageURL: String?)]()
		var output = [ChatFormat]()
		constituents["Admin"] = ("Admin", Config.adminProfilePicture)
		
		for chat in self{
			if constituents[chat.sender] == nil {
				let const = await group.constituent(for: chat.sender)
				let imageURL = await group.getGravatarURLForConst(const)
				
				constituents[chat.sender] = (name: const?.getNameOrId() ?? "[Deleted]", imageURL: imageURL)
			}
			
			let c = constituents[chat.sender]!
			
			output.append(ChatFormat(id: chat.id!, sender: c.name, message: chat.message, imageURL: c.imageURL, timestamp: chat.timestamp, isSystemsMessage: chat.systemsMessage))
		}
		return output
	}
	
}
