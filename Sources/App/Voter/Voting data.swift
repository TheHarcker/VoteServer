import Foundation
import VoteKit
import AltVoteKit
import VoteExchangeFormat

// Defines data received from a vote page
protocol VotingData: VoteData{
    associatedtype Vote: SupportedVoteType
    
    func asSingleVote(for vote: Vote, constituent: Constituent) async throws -> Vote.voteType
    func asCorrespondingPersistenseData()-> Vote.VotePageUI.PersistanceData?
}

extension YnVotingData: VotingData{
    func asSingleVote(for vote: yesNoVote, constituent: Constituent) async throws -> yesNoVote.yesNoVoteType{
        
        // Cheks if the vote is explicitly blank, and whether that is allowed
        if blank == true || votes == nil || votes!.isEmpty{
            if blank == nil && votes == nil{
                throw VotingDataError.invalidRequest
            }
            
            if await vote.genericValidators.contains(.noBlankVotes){
                throw VotingDataError.blankVotesNotAllowed
            } else {
                return .init(constituent: constituent, values: [:])
            }
        }
        
        //TODO: Maybe add a cache for this? Of type [vote.id: [UUID: VoteOption]] and a helper function for either generating or accessing this dictionary; this would require vote.options to be constant, or just a hash of vote.options to be saved and compared at every use of the cache
        // Lookup for translating UUID -> VoteOption
        let uuidToOption = await vote.options.reduce(into: [UUID: VoteOption]()) { partialResult, option in
            partialResult[option.id] = option
        }
        
        // Converts the input
        let values = try getValues(votes: votes!)
        let val = try values.reduce(into: [VoteOption: Bool]()) { partialResult, d in
            guard let option = uuidToOption[d.key] else {
                throw VotingDataError.invalidRequest
            }
            partialResult[option] = d.value
        }
        
        // Checks if there has been given a preference for all options, the case for blank votes is handled above
        // uuidToOption.count, is synchronous for await vote.options.count
        if await vote.particularValidators.contains(.preferenceForAllRequired) && values.count != uuidToOption.count{
            throw VotingDataError.allShouldBeFilledIn
        }
        
        return .init(constituent: constituent, values: val)
    }
    
    // Converts the input into the correct data types
    private func getValues(votes: [String: String]) throws-> [UUID: Bool]{
        try votes.reduce(into: [UUID: Bool]()) { partialResult, d in
            guard let uuid = UUID(d.key) else {
                throw VotingDataError.invalidRequest
            }
            
            switch d.value{
            case "yes":
                partialResult[uuid] = true
            case "no":
                partialResult[uuid] = false
            default:
                throw VotingDataError.invalidRequest
            }
        }
    }
    
    
    func asCorrespondingPersistenseData()-> [UUID:Bool]?{
        if votes == nil || votes!.isEmpty {
            return nil
        }
        return try? getValues(votes: votes!)
    }

}

extension SimpleMajorityVotingData: VotingData{
    func asSingleVote(for vote: SimpleMajority, constituent: Constituent) async throws -> SimpleMajority.SimpleMajorityVote{
        // Cheks if the vote is explicitly blank, and whether that is allowed
        if blank == true || selectedOption == nil{
            // A request with blank and selectedOption as nil
            if blank == nil{
                throw VotingDataError.invalidRequest
            }
            
            if await vote.genericValidators.contains(.noBlankVotes){
                throw VotingDataError.blankVotesNotAllowed
            } else {
                return .init(constituent: constituent, preferredOption: nil)
            }
        }
        
        // Finds the option that was voted for 
        guard let uuid = UUID(selectedOption!), let option = await vote.options.first(where: {$0.id == uuid}) else {
            throw VotingDataError.invalidRequest
        }
        
        return .init(constituent: constituent, preferredOption: option)
        
    }
    
    func asCorrespondingPersistenseData()-> UUID?{
        if selectedOption != nil {
            return UUID(selectedOption!)
        } else {
            return nil
        }
    }
}



extension AltVotingData: VotingData{
	typealias Vote = AlternativeVote

	/// Gets the priorities in the order the user sees them
	private func orderForOptions(_ options: [VoteOption], addDefault: Bool) -> [String]{
		let priorities = blank == true ? [:] : priorities ?? [:]
		
		if addDefault{
			return (1...(options.count)).map{priorities[$0] ?? "default"}
		} else {
			return (1...(options.count)).compactMap{priorities[$0]}
		}
			
	}
	
	func asSingleVote(for vote: AlternativeVote, constituent: Constituent) async throws -> SingleVote{
		
		let defaultValue = "default"
		
		//Gets the priorities in the order the user sees them
		let orderedPriorities = orderForOptions(await vote.options, addDefault: false)
		
		//Converts from String to UUID
		let treatedPriorities = orderedPriorities.compactMap{ value -> UUID? in
			if value == defaultValue{
				return nil
			} else {
				return UUID(uuidString: value)
			}
		}
		
		guard treatedPriorities.nonUniques.isEmpty else {
			throw VotingDataError.allShouldBeDifferent
		}
		
		let voteOptions = await vote.options
		
		//Converts from UUID to VoteOption
		let realOptions = treatedPriorities.compactMap{prio in
			voteOptions.first{option in
				option.id == prio
			}
		}
		
		//Checks that all of the supplied priorities are used
		guard treatedPriorities.count == realOptions.count else {
			throw VotingDataError.invalidRequest
		}
		
		
		//Check for violations of the NoBlanks validator
        let noBlanks = await vote.genericValidators.contains(.noBlankVotes)
		if realOptions.isEmpty && noBlanks{
			throw VotingDataError.blankVotesNotAllowed
		}


		//Check for violations of the preferenceForAllCandidates validator. That is violated if there isn't preferences for all candiates and it isn't a blank vote
        let preferenceForAll = await vote.particularValidators.contains(.allCandidatesRequiresAVote)
		if Set(realOptions) != Set(await vote.options) && !realOptions.isEmpty && preferenceForAll{
			throw VotingDataError.allShouldBeFilledIn
		}
		
		return SingleVote(constituent, rankings: realOptions)
	}
    
    func asCorrespondingPersistenseData()->Self?{
        return self
    }
}

enum VotingDataError: ErrorString{
	func errorString() -> String {
		switch self {
		case .invalidRequest:
			return "Invalid request, try reloading the page and try again"
		case .allShouldBeDifferent:
			return "Two or more priorities are the same"
		case .attemptedToVoteMultipleTimes:
			return "You've attempted to vote multiple times"
		case .allShouldBeFilledIn:
			return "You haven't put in a preference for all candidates"
		case .blankVotesNotAllowed:
			return "Blank votes are not allowed in this vote"
		}
	}
	
	case invalidRequest
	case allShouldBeDifferent
	case attemptedToVoteMultipleTimes
	case allShouldBeFilledIn
	case blankVotesNotAllowed
}
