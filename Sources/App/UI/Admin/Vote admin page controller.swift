import VoteKit
/// A page showing the validators, options and constituents in a vote
struct VoteAdminUIController: UITableManager{
	let title: String
	var errorString: String? = nil

	var tableHeaders = ["User id", "Name", "Has voted", "Verified", ""]
	let rows: [ConstituentAndStatus]
	var tableClass: String = ""

	var buttons: [UIButton] = [.backToAdmin, .reload]

    /// The name of the vote
    var voteName: String
    
	/// Show the "Get results" button
	let showGetResults: Bool

	/// Show the  "Close vote" button or the "Open vote" and "Delete vote" buttons
	let isOpen: Bool
	
	/// Number of votes cast
	let voteCount: Int
	/// The number of voters who is verified and/or has joined the group 
	let constituentsCount: Int
	
	/// The options available for the vote
	let options: [String]
	
	/// Special settings added to the vote
	let settings: [String]
	
	/// The id for the vote being presented
	let voteID: String
	
	static var template: String = "voteadmin"
	
    
    init(vote: VoteTypes, group: Group) async{
        switch vote {
        case .alternative(let v):
            self = await Self(vote: v, group: group)
        case .yesno(let v):
            self = await Self(vote: v, group: group)
        case .simplemajority(let v):
            self = await Self(vote: v, group: group)
        }
    }
    
    private init<V: SupportedVoteType>(vote: V, group: Group) async {
        let status = await group.statusFor(vote) ?? .closed
        
        self.voteCount = await vote.votes.count
        self.constituentsCount = await vote.constituents.count
        
        // Sets the page title to the name of the vote, and conditionally adds " (closed)"
        self.title = await vote.name + (status == .open ? "" : " (closed)")
        self.voteName = await vote.name
        
        self.showGetResults = voteCount >= 2 && status == .closed
        self.isOpen = status == .open
        
        self.voteID = await vote.id.uuidString
        self.settings = await vote.particularValidators.map(\.name) + vote.genericValidators.map(\.name)
        self.options = await vote.options.map(\.name)
        
        
        var tempRows = [Constituent: ConstituentAndStatus]()
        
        let votes = await vote.votes
        let verified = await group.verifiedConstituents
        let unverified = await group.unverifiedConstituents

        //NB: Three seperate loops gives a worst case complexity of O(k + ln(k)*m+ln(k+m)*n), instead of nested loops which has a worst case scenario of O(k*(m*ln(k)+n*ln(k+m))
        votes.forEach { vote in
            tempRows[vote.constituent] = ConstituentAndStatus(constituent: vote.constituent, hasVoted: true, isVerified: false)
        }
        
        verified.forEach { const in
            if tempRows[const] != nil {
                tempRows[const]!.isVerified = true
            } else {
                tempRows[const] = ConstituentAndStatus(constituent: const, hasVoted: false, isVerified: true)
            }
        }
        
        unverified.forEach { const in
            if tempRows[const] == nil {
                tempRows[const] = ConstituentAndStatus(constituent: const, hasVoted: false, isVerified: false)
            }
        }
        
        rows = tempRows.map(\.value).sorted{ lhs, rhs in
            return lhs.constIdentifier < rhs.constIdentifier
        }
    }
}

struct ConstituentAndStatus: Codable{
	internal init(constituent: Constituent, hasVoted: Bool, isVerified: Bool) {
        self.constName = constituent.name ?? constituent.identifier
        self.constIdentifier = constituent.identifier
        self.constB64ID = constituent.identifier.asURLSafeB64() ?? ""
        
		self.hasVoted = hasVoted
		self.isVerified = isVerified
	}
	
    var constName: String
    var constIdentifier: String
    var constB64ID: String
	var hasVoted: Bool
	var isVerified: Bool
}
