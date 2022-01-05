struct LoginUI: UIManager{
	internal init(prefilledJF: String = "", errorString: String? = nil) {
		self.errorString = errorString
		self.prefilledJF = prefilledJF
	}
	
	var buttons: [UIButton] = [.createGroup, .init(uri: "/join/", text: "Join", color: .green)]
	
	var title: String = "Login"
	
	var errorString: String?
	
	var prefilledJF: String = ""
	
	static var template: String = "login"
	
}