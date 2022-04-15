import Foundation
import VoteKit
struct YesNoVotePage: VotePage, UITableManager{
    var title: String
    var errorString: String? = nil
    var buttons: [UIButton] = [.backToPlaza]
    static var template: String = "votePages/yesno"
    
    var rows: [Row] = []
    var tableHeaders: [String] = ["Name", "Yes", "No"]
    
    var canVoteBlank: Bool = false
    var hideUI: Bool = false
    
    /// Adds a button after every option allowing the user to deselect misclicked options
    var allowsResetting = false
    
    init(title: String, vote: yesNoVote?, errorString: String? = nil, persistentData: [UUID:Bool]? = nil) async {
        
        
        if let vote = vote {
            self.canVoteBlank = await !vote.genericValidators.contains(.noBlankVotes)
            rows = await vote.options.map{ option in
                let status: String
                switch persistentData?[option.id]{
                case true:
                    status = "yes"
                case false:
                    status = "no"
                default:
                    status = ""
                }
                return Row(id: option.id, name: option.name, status: status)
            }
            
            allowsResetting = await !vote.particularValidators.contains(.preferenceForAllRequired)
        }
        
        self.title = title
        self.errorString = errorString
    }
    
    struct Row: Codable{
        var id: UUID
        var name: String
        var status: String
    }
}

