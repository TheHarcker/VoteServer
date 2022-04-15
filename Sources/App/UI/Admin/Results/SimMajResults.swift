import VoteKit
struct SimMajResultsUI: UIManager{
    var numberOfVotes: Int
    
    var title: String
    
    var errorString: String? = nil
    var buttons: [UIButton] = [.backToAdmin]
    
    static var template: String = "results/simplemajority"
    
    var results: [String]
    
    init(title: String, numberOfVotes: Int, count: [VoteOption : UInt]){
        self.title = title
        self.numberOfVotes = numberOfVotes
        
        results = count.map{ option, count in
            return (option.name, count)
        }
        .sorted { el1, el2 in
            if el1.1 != el2.1{
                return el1.1 > el2.1
            } else {
                //If two options are tied, they'll be sorted by name
                return el1.0 < el2.0
            }
        }
        .map{ (name, count) in
            name + ": \(count)"
        }
        
    }
}
