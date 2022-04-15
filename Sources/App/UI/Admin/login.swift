struct LoginUI: UIManager{
    internal init(prefilledJF: String? = nil, errorString: String? = nil, showRedirectToPlaza: Bool) {
		self.errorString = errorString
		self.prefilledJF = prefilledJF
        
        if showRedirectToPlaza{
            self.buttons = [.backToPlaza, .join, .createGroup]
        } else {
            self.buttons = [ .join, .createGroup]
        }
	}
	
    var buttons: [UIButton]
	
	var title: String = "Login"
	
	var errorString: String?
	
	var prefilledJF: String?
	
	static var template: String = "login"
	
}
