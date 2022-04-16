import Crypto
extension Group{
	func getHashFor(_ email: String) -> String?{
		let trim = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Validates that email is in the form "*@*.@"
		guard
			trim.count > 5,
			trim.count < maxNameLength,
			let dotI = trim.lastIndex(of: "."),
			let atI = trim.lastIndex(of: "@"),
			dotI > atI,
			dotI != trim.endIndex,
			atI != trim.startIndex
		else {
			return nil
		}
		
		// Checks if hash is cached, otherwise it will be generated
		if let hash = self.emailHashCache[trim]{
			return hash
		} else {
			let emailData = trim.data(using: .utf8)!
			let hash = Insecure.MD5.hash(data: emailData).map {
				String(format: "%02hhx", $0)
			}.joined()
			
			self.emailHashCache[trim] = hash
		
			return hash
		}
	}
}
