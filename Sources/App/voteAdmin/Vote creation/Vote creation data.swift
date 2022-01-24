import VoteKit
struct VoteCreationReceivedData<V: SupportedVoteType>: Codable{
	var nameOfVote: String
	var options: String
	
	var particularValidators: [String: String]
	var genericValidators: [String: String]
}


extension VoteCreationReceivedData{
    func getAllEnabledIDs() -> [String]{
        particularValidators.compactMap { validator in
            if validator.value == "on" {
                return validator.key
            } else {
                return nil
            }
        }
        +
        genericValidators.compactMap { validator in
            if validator.value == "on" {
                return validator.key
            } else {
                return nil
            }
        }
    }
    
	func getPartValidators() -> [V.particularValidator] {
		return particularValidators.compactMap { validator in
			if validator.value == "on" {
                return V.particularValidator.allValidators.first{$0.id == validator.key}
			} else {
				return nil
			}
		}
	}
	
	func getGenValidators() -> [GenericValidator<V.voteType>] {
		return genericValidators.compactMap { validator in
			if validator.value == "on" {
                return GenericValidator.allValidators.first{$0.id == validator.key}
			} else {
				return nil
			}
		}
	}
	
    func getOptions() throws -> [VoteOption]{
        if self.options.contains(";"){
            throw voteCreationError.invalidOptionName
        }
        
        let options = self.options
			.split(separator: ",")
			.compactMap{ opt -> String? in
				let str = String(opt.trimmingCharacters(in: .whitespacesAndNewlines))
				return str == "" ? nil : str
			}
		
		
		guard options.nonUniques.isEmpty else{
			throw voteCreationError.optionAddedMultipleTimes
		}
        
        guard options.count >= V.minimumRequiredOptions else {
            throw voteCreationError.lessThanNOptions(V.minimumRequiredOptions)
        }
		
        // Checks that no option violates the maxNameLength constant
        guard options.contains(where: {$0.count <= maxNameLength}) else {
            throw voteCreationError.invalidOptionName
        }
		
		return options.map{
			VoteOption($0)}
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
				return "A vote needs atleast \(n) options"
            case .invalidOptionName:
                return "At least one of the options has an invalid name"
			}
		}
		
	}
}

