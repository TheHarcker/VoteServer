import Crypto
import VoteKit
extension Group{
	fileprivate func getHashFor(_ email: String?) -> String?{
		guard let trim = email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
			return nil
		}
		
		// Validates that email is in the form "*@*.*"
		guard
			trim.count > 5,
			trim.count < Config.maxNameLength,
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
	
	func getGravatarURLForConst(_ const: Constituent?, size: UInt? = nil) -> String{
		if let hash = self.getHashFor(const?.email) {
			let sParam: String
			if size != nil {
				sParam = "&s=\(size!)"
			} else {
				sParam = ""
			}
			
			return "https://www.gravatar.com/avatar/" + hash + "?d=mp" + sParam
		} else {
			return getDefaultGravatar(size: size)
		}
	}
	
	func getDefaultGravatar(size: UInt? = nil)->String{
		let sParam: String
		if size != nil {
			sParam = "&s=\(size!)"
		} else {
			sParam = ""
		}
		return "https://www.gravatar.com/avatar?d=mp" + sParam
	}
}
