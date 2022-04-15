import VoteKit
struct VoteCreationReceivedData<V: SupportedVoteType>: Codable{
	var nameOfVote: String
	var options: String
	
	var particularValidators: [String: String]
	var genericValidators: [String: String]
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
            throw voteCreationError.invalidOptionName
        }
        
        let options = self.options
			.split(separator: ",")
            .map{String($0.trimmingCharacters(in: .whitespacesAndNewlines))}
            .filter{$0 != ""}
        		
		guard options.nonUniques.isEmpty else{
			throw voteCreationError.optionAddedMultipleTimes
		}
        
        guard options.count >= V.minimumRequiredOptions else {
            throw voteCreationError.lessThanNOptions(V.minimumRequiredOptions)
        }
		
        // Checks that no option violates the maxNameLength constant
		guard options.allSatisfy({$0.count <= maxNameLength}) else {
            throw voteCreationError.invalidOptionName
        }
		
        return options.map(VoteOption.init)
	}
	
	func getTitle() throws -> String{
		let title = nameOfVote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= maxNameLength else {
			throw voteCreationError.invalidTitle
		}
		return title
	}
	
	
	enum voteCreationError: ErrorString{
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
}
