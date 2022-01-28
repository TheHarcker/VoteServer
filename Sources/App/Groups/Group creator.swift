import VoteKit
import Vapor
//Represents data received on a request to create a group
struct GroupCreatorData: Codable{
	var groupName: String
	var usernames: String
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
		let individualVoters = self.usernames.split(whereSeparator: \.isNewline)
		
		let constituents = try individualVoters.compactMap{ voterString -> Constituent? in
			var s = voterString.split(separator:",")
			
			//Enables having a dangling comma in the end (or middle) of the constituents list
			if s.last?.trimmingCharacters(in: .whitespacesAndNewlines) == ""{
				s = s.dropLast()
			}
			
			if s.count == 0 {
				return nil
			} else if s.count == 1 {
				let id = s.first!.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, id.count <= maxNameLength else {
					throw GroupCreationError.invalidUsername
				}
				return Constituent(identifier: id.lowercased())
			} else if s.count == 2{
				let id = s.first!.trimmingCharacters(in: .whitespacesAndNewlines)
				
				let name = s.last!.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, !name.isEmpty, id.count <= maxNameLength, name.count <= maxNameLength else {
					throw GroupCreationError.invalidUsername
				}
				
				return Constituent(name: name, identifier: id.lowercased())
				
			} else {
				throw GroupCreationError.invalidUsername
			}
			
		}
		
		guard constituents.map(\.identifier).nonUniques.isEmpty else{
			throw GroupCreationError.userAddedMultipleTimes
		}
		
		
		return Set(constituents)
		
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
			return "User appears multiple times"
		case .invalidUsername:
			return "One or more invalid usernames were found"
		case .invalidGroupname:
			return "The group name is invalid"
		case .invalidPassword:
			return "The password is either too short or too simple"
		}
	}
	
	case userAddedMultipleTimes, invalidUsername, invalidGroupname, invalidPassword
}
