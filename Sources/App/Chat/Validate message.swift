fileprivate let profanity = [
	"fuck",
 	"cunt",
 	"shit",
 ]

func checkMessage(msg: String) throws -> String{
	let msg = msg.trimmingCharacters(in: .whitespacesAndNewlines)
	if msg.isEmpty {
		throw ChatError.emptyMessage
	} else if msg.count > Config.maxChatLength {
		throw ChatError.messageTooLong
	}
	
	if profanity.contains(where: msg.contains) {
		throw ChatError.profanity
	}
	
	if msg.contains("<") || msg.contains(">") {
		throw ChatError.nonallowedCharacter
	}
	
	return msg
}
