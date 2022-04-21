import VoteKit

struct GroupSettings: Codable, Sendable{
    internal init(allowsUnverifiedConstituents: Bool, constituentsCanSelfResetVotes: Bool = false, csvConfiguration: CSVConfiguration = .defaultConfiguration(), showTags: Bool = false) {
        self.allowsUnverifiedConstituents = allowsUnverifiedConstituents
        self.constituentsCanSelfResetVotes = constituentsCanSelfResetVotes
        self.csvConfiguration = csvConfiguration
        
		let allCSVConfigurations: [CSVConfiguration] = [.defaultConfiguration(),.SMKid(), .defaultWithTags()]
        self.csvKeys = allCSVConfigurations.reduce(into: [String: CSVConfiguration](), { $0[$1.name] = $1})
		
		self.showTags = showTags
		
		self.chatState = Config.enableChat ? .forAll : .disabled
    }
    
    /// If this group allows unverified constituents to join
    var allowsUnverifiedConstituents: Bool
    
    /// Whether constituens should be able to reset their own votes
    var constituentsCanSelfResetVotes: Bool = false
    
    var csvConfiguration: CSVConfiguration = .defaultConfiguration()
    
    let csvKeys: [String: CSVConfiguration]
	
	/// Whether tags and tag statistic should be shown in the constituents list
	var showTags: Bool
	
	var chatState: ChatState
	
	enum ChatState: String, CaseIterable, Codable{
		case disabled = "Disabled"
		case forAll = "For all"
		case onlyVerified = "Only for verified constituents"
	}
}
