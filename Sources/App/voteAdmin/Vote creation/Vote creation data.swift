import VoteKit
struct VoteCreationReceivedData<V: SupportedVoteType>: Codable{
	let nameOfVote: String
	let options: String
	
	let particularValidators: [String: String]
	let genericValidators: [String: String]
}


extension VoteCreationReceivedData{
	func getAllEnabledIDs() -> [String]{
		particularValidators.filter(\.value.isOn).map(\.key)
		+
		genericValidators.filter(\.value.isOn).map(\.key)
	}
	
	func getPartValidators() -> [V.particularValidator] {
		particularValidators
			.filter(\.value.isOn)
			.compactMap{ validator in V.particularValidator.allValidators.first{$0.id == validator.key}}
	}
	
	func getGenValidators() -> [GenericValidator<V.voteType>] {
		genericValidators
			.filter(\.value.isOn)
			.compactMap{ validator in GenericValidator.allValidators.first{$0.id == validator.key}}
	}
	
	func getOptions() throws -> [VoteOption]{
		if self.options.contains(";"){
			throw VoteCreationError.invalidOptionName
		}
		
		let options = self.options
			.split(separator: ",")
			.map{String($0.trimmingCharacters(in: .whitespacesAndNewlines))}
			.filter{$0 != ""}
		
		guard options.nonUniques.isEmpty else{
			throw VoteCreationError.optionAddedMultipleTimes
		}
		
		if options.count < V.minimumRequiredOptions {
			// Use the title as an option in votes that allow single options
			if
				V.minimumRequiredOptions == 1,
				let title = try? self.getTitle(),
				!title.contains(","),
				!title.contains(";")
			{
				return [VoteOption(title)]
			}
			throw VoteCreationError.lessThanNOptions(V.minimumRequiredOptions)
		}
		
		// Checks that no option violates the maxNameLength constant
		guard options.allSatisfy({$0.count <= Config.maxNameLength}) else {
			throw VoteCreationError.invalidOptionName
		}
		
		return options.map(VoteOption.init)
	}
	
	func getTitle() throws -> String{
		let title = nameOfVote.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !title.isEmpty, title.count <= Config.maxNameLength else {
			throw VoteCreationError.invalidTitle
		}
		return title
	}
}

enum VoteCreationError: ErrorString{
	case invalidTitle
	case optionAddedMultipleTimes
	case lessThanNOptions(Int)
	case invalidOptionName
	
	func errorString() -> String{
		
		switch self {
		case .invalidTitle:
			return "Invalid name detected for the vote"
		case .optionAddedMultipleTimes:
			return "An option has been added multiple times"
		case .lessThanNOptions(let n):
			return "A vote needs at least \(n) options"
		case .invalidOptionName:
			return "At least one of the options has an invalid name"
		}
	}
	
}
