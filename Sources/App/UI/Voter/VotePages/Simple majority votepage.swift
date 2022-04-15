import Foundation
import VoteKit
struct SimMajVotePage: VotePage{
    var title: String
    var errorString: String? = nil
    var buttons: [UIButton] = [.backToPlaza]
    
    static var template: String = "votePages/simplemajority"
    
    var canVoteBlank: Bool = false
    var hideUI: Bool = false
    
    var selectedID: UUID?
    
    var options: [VoteOption] = []
    
    init(title: String, vote: SimpleMajority?, errorString: String? = nil, persistentData: UUID? = nil) async {
        self.title = title
        self.errorString = errorString

        if let vote = vote{
            self.options = await vote.options
            
            self.canVoteBlank = !(await vote.genericValidators.contains(.noBlankVotes))
        }
     
        self.selectedID = persistentData
        
        
    }
    
    struct Row: Codable{
        var id: UUID
        var name: String
        var status: String
    }
}

