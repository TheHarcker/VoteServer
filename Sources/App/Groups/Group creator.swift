import VoteKit
import Vapor
//Represents data received on a request to create a group
struct GroupCreatorData: Codable{
	var groupName: String
	var file: String?
	private var adminpw: String
	var allowsUnverifiedConstituents: String?
}

extension GroupCreatorData{
	func getGroupName() throws -> String{
		let trim = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trim.isEmpty && trim.count <= maxNameLength else {
			throw GroupCreationError.invalidGroupname
		}
		
		return trim
	}
	
	
	func getHashedPassword(for req: Request) throws -> String {
        return try hashPassword(pw: adminpw, groupName: try self.getGroupName(), for: req.application)
	}
	
	func getConstituents() throws -> Set<Constituent>{
		guard self.file != nil, !self.file!.isEmpty else {
			return []
		}
		if self.file!.count > 1_000_000 {
			throw GroupCreationError.nameTooLong
		}
		do{
			
			let constituents = try constituentsListFromCSV(file: self.file!, maxNameLength: maxNameLength)
			
			// Checks that no one is using the name or identifier "admin"
			if (constituents.map(\.identifier) + constituents.compactMap(\.name).map{$0.lowercased()}).contains(where: {$0.contains("admin")}){
				throw DecodeConstituentError.invalidIdentifier
			}
			
			let set = Set(constituents)
			
			if set.count != constituents.count {
				throw GroupCreationError.userAddedMultipleTimes
			}
			
			return set
			
		} catch let er as DecodeConstituentError{
			switch er {
			case .invalidIdentifier:
				throw GroupCreationError.invalidIdentifier
			case .nameTooLong:
				throw GroupCreationError.nameTooLong
			case .invalidCSV:
				throw GroupCreationError.invalidCSV
			case .invalidTag:
				throw GroupCreationError.invalidTag
			}
		}
	}
	
    /// Checks if the received data indicates that non verified constituents are allowed
	func allowsUnverified() -> Bool{
		self.allowsUnverifiedConstituents == "on"
	}
}

enum GroupCreationError: ErrorString{
	func errorString() -> String {
		switch self {
		case .userAddedMultipleTimes:
			return "User appears multiple times."
		case .invalidIdentifier:
			return "One or more invalid user identifiers were found."
		case .invalidGroupname:
			return "The group name is invalid."
		case .invalidPassword:
			return "The password is either too short or too simple."
		case .invalidCSV:
			return "The supplied CSV file was invalid, the separators needs to be \",\" and newlines. Check that the header row is \"Name,Identifier,Tag\"."
		case .nameTooLong:
			return "One of the supplied constituents has a name/identifier/tag which surpasses the maximum name length."
		case .invalidTag:
			return "One of the supplied tags are invalid, either by having the prefix \"-\" or exceeding the length limit."
		}
	}
	
	case userAddedMultipleTimes, invalidIdentifier, invalidGroupname, invalidPassword, invalidCSV, nameTooLong, invalidTag
}
