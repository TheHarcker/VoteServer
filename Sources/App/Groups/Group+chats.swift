import VoteKit
import WebSocketKit
extension Group{
	/// Checks if a constituent is allowed to chat
	/// - Parameter constituent: The constituent being checked
	/// - Returns: Whether the constituent is allowed
	func constituentCanChat(_ constituent: Constituent) async -> Bool {
		return self.settings.chatState != .disabled && (self.constituentIsVerified(constituent) || self.settings.chatState == .forAll)
	}
}
