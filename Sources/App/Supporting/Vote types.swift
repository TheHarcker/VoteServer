import VoteKit
import AltVoteKit
import Foundation
import VoteExchangeFormat

enum VoteTypes{
    case alternative(AlternativeVote)
    case yesno(yesNoVote)
    case simplemajority(SimpleMajority)
    
    enum StringStub: String{
        case alternative = "alternativevote"
        case yesNo = "yesno"
        case simpleMajority = "simplemajority"
        
        init(_ voteTypes: VoteTypes){
            switch voteTypes {
            case .alternative(_):
                self = .alternative
            case .yesno(_):
                self = .yesNo
            case .simplemajority(_):
                self = .simpleMajority
            }
        }
    }
    
    init<V: SupportedVoteType>(vote: V){
        switch V.enumCase{
        case .alternative:
            self = .alternative(vote as! AlternativeVote)
        case .yesNo:
            self = .yesno(vote as! yesNoVote)
        case .simpleMajority:
            self = .simplemajority(vote as! SimpleMajority)
        }
    }
    
    func asStub() -> StringStub{
        StringStub(self)
    }
}


extension VoteTypes{
    func id() async -> UUID {
        switch self {
        case .alternative(let v):
            return await v.id
        case .yesno(let v):
            return await v.id
        case .simplemajority(let v):
            return await v.id
        }
    }
    
    func name() async -> String {
        switch self {
        case .alternative(let v):
            return await v.name
        case .yesno(let v):
            return await v.name
        case .simplemajority(let v):
            return await v.name
        }
    }
    
    func constituents() async -> Set<Constituent> {
        switch self {
        case .alternative(let v):
            return await v.constituents
        case .yesno(let v):
            return await v.constituents
        case .simplemajority(let v):
            return await v.constituents
        }
    }
    
    func options() async -> [VoteOption] {
        switch self {
        case .alternative(let v):
            return await v.options
        case .yesno(let v):
            return await v.options
        case .simplemajority(let v):
            return await v.options
        }
    }
}

/// Adds the types associated with each kind of vote
protocol SupportedVoteType: VoteProtocol{
    associatedtype ReceivedData: VotingData where ReceivedData.Vote == Self
    associatedtype VotePageUI: VotePage where VotePageUI.VoteType == Self
    static var enumCase: VoteTypes.StringStub {get}
    static var minimumRequiredOptions: Int {get}
}


extension AlternativeVote: SupportedVoteType{
    typealias ReceivedData = AltVotingData
    typealias PersistanceData = AltVotingData
    typealias VotePageUI = AltVotePageGenerator
    static let enumCase: VoteTypes.StringStub = .alternative
    static let minimumRequiredOptions: Int = 2
}

extension yesNoVote: SupportedVoteType{
    typealias ReceivedData = YnVotingData
    typealias PersistanceData = [UUID:Bool]
    typealias VotePageUI = YesNoVotePage
    static let enumCase: VoteTypes.StringStub = .yesNo
    static let minimumRequiredOptions: Int = 1
}

extension SimpleMajority: SupportedVoteType{
    typealias ReceivedData = SimpleMajorityVotingData
    typealias PersistanceData = UUID
    typealias VotePageUI = SimMajVotePage
    static let enumCase: VoteTypes.StringStub = .simpleMajority
    static let minimumRequiredOptions: Int = 2
}
