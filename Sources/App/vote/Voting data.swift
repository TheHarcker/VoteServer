import Foundation
import AltVoteKit

struct VotingData: Codable{
	var userID: String
	var priorities: [Int: String]
	
	
	func asSingleVote(for vote: Vote) async throws -> SingleVote{
		let defaultUUID = "3196F9B8-935C-4018-846F-037D741C0057"
		
		//Gets the priorities in the order the user sees them
		let orderedPriorities = (1...(await vote.options.count)).compactMap{priorities[$0]}
		
		//Converts from String to UUID
		let treatedPriorities = orderedPriorities.compactMap{ value -> UUID? in
			if value == defaultUUID{
				return nil
			} else {
				return UUID(uuidString: value)
			}
		}
		
		
		
		print(treatedPriorities)
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
		
		guard treatedPriorities.count == realOptions.count else {
			throw VotingDataError.invalidRequest
		}
		
		let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !userID.isEmpty else {
			throw VotingDataError.invalidUserId
		}
		
		
		//Preliminary checks for some validators
		if await vote.validators.contains(where: {$0.id == VoteValidator.preferenceForAllCandidates.id}){
			guard Set(realOptions) == Set(await vote.options) else {
				throw VotingDataError.allShouldBeFilledIn
			}
		}
		
		if await vote.validators.contains(where: {$0.id == VoteValidator.noForeignVotes.id}){
			guard await vote.eligibleVoters.contains(userID) else {
				throw VotingDataError.invalidUserId
			}
		}
		
		return SingleVote(userID, rankings: realOptions)
	}
}

enum VotingDataError: ErrorString{
	func errorString() -> String {
		switch self {
		case .invalidRequest:
			return "Invalid request, try reloading the page and try again"
		case .invalidUserId:
			return "Invalid user id"
		case .allShouldBeDifferent:
			return "Two or more priorities is the same"
		case .attemptedToVoteMultipleTimes:
			return "You've attempted to vote multiple times"
		case .allShouldBeFilledIn:
			return "You haven't put in a preference for all candidates"
		}
	}
	
	case invalidRequest
	case invalidUserId
	case allShouldBeDifferent
	case attemptedToVoteMultipleTimes
	case allShouldBeFilledIn
}
