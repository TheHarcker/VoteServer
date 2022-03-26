enum ChatError: String, ErrorString, Codable{
	case notAllowed = "You are not allowed to enter the chat"
	case invalidRequest = "Invalid request"
	
	case emptyMessage = "A chat cannot be empty"
	case messageTooLong = "Your message was too long"
	
	case profanity = "You message contained profanity"
	case nonallowedCharacter = "You are using prohibited characters"
	// Send when the server is rate limiting the client
	case rateLimited = "ratelimited"
}
