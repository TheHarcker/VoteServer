enum ChatError: String, ErrorString, Codable{
	case notAllowed = "You are not allowed to enter the chat"
	case invalidRequest = "Invalid request"
	
	case emptyMessage = "A chat cannot be empty"
	case messageTooLong = "Your message was too long"
	
	case profanity = "You message contained profanity"
}
