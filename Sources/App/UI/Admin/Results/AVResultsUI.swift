import VoteKit
struct AVResultsUI: UIManager{
	internal init(title: String, winners: WinnerWrapper, numberOfVotes: Int, enabledOptions: Set<VoteOption>, disabledOptions: Set<VoteOption>) {
		assert(enabledOptions.isDisjoint(with: disabledOptions), "ShowWinnerUI received the option (\(enabledOptions.intersection(disabledOptions))) as both enabled and disabled")
		
        
        
		self.title = title
		self.winners = Array(winners.winners())
		
		self.enabledOptions = Array(enabledOptions).sorted(by: {$0.name<$1.name})
		self.disabledOptions = Array(disabledOptions).sorted(by: {$0.name<$1.name})

		self.hasEnabledAndDisabled = !enabledOptions.isEmpty && !disabledOptions.isEmpty

		self.numberOfVotes = numberOfVotes
		
		if case .tie = winners{
			hasMultipleWinners = true
		} else {
			hasMultipleWinners = false
		}
	}
	
	var title: String
	var errorString: String? = nil
    var buttons: [UIButton] = [.backToAdmin]
	static var template: String = "results/altvote"
	
	var winners: [VoteOption]
	var hasMultipleWinners: Bool
	
	var numberOfVotes: Int
	var enabledOptions: [VoteOption]
	var disabledOptions: [VoteOption]
	
	var hasEnabledAndDisabled: Bool
}
