struct AdminChatPage: UIManager{
	var title: String = "Chats"
	var errorString: String? = nil
	static var template: String = "adminchatpage.leaf"
	
	var buttons: [UIButton] = [.backToAdmin,]
}
