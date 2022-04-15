import AltVoteKit
import VoteKit
import Foundation
import VoteExchangeFormat

struct AltVotePageGenerator: VotePage{
	var title: String
    var errorString: String?
    var buttons: [UIButton] = [.backToPlaza]
    
	var numbers: [PriorityData]
	var options: [VoteOption]
	var hideUI: Bool = false
	var canVoteBlank: Bool
	
	init(title: String, vote: AlternativeVote?, errorString: String? = nil, persistentData: AltVotingData? = nil) async {
		
		if let options = await vote?.options {
			assert(options.count != 0 || errorString != nil)

			canVoteBlank = await !vote!.genericValidators.contains(.noBlankVotes)
			
			
			if let priorities = persistentData?.priorities{
				self.numbers = options.count == 0 ? [] : (1...options.count).map({PriorityData(number: $0, selected: priorities[$0] ?? "default")})
			} else {
				self.numbers = options.count == 0 ? [] : (1...options.count).map({PriorityData(number: $0)})
			}
			self.options = options

		} else {
			self.canVoteBlank = false

			self.options = []
			self.numbers = []
		}
		
		
		self.title = title
		self.errorString = errorString
		
		
	}
	
	static var template: String = "votePages/altvote"
	
	struct PriorityData: Codable{
		internal init(number: Int, selected: String = "default") {
			self.number = number
			self.selected = selected
		}
		
		let number: Int
		let selected: String
	}
}




