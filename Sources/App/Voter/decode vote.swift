import VoteKit
import AltVoteKit
import Vapor

/// Decodes and stores data POSTed to /vote/[voteid] OR the API
/// - Throws: VotingDataError
/// - Returns: Either a view to be presented be non API clients or the result as a String for API clients
func decodeAndStore<V: SupportedVoteType>(group: Group, vote: V, constituent: Constituent, req: Request) async -> ((data: V.ReceivedData?, error: Error)?, [String]?){
    var votingData: V.ReceivedData
    do {
        votingData = try req.content.decode(V.ReceivedData.self)
    } catch {
        // Workaround for an empty set of radio buttons leading to error 422
        if (V.enumCase == .yesNo || V.enumCase == .simpleMajority), let e = error as? AbortError, e.status == .unprocessableEntity {
            votingData = V.ReceivedData.blank()
        } else {
            return ((nil, error), nil)
        }
    }
    
    /// The vote as a VoteStub
    guard let voteStub = try? await votingData.asSingleVote(for: vote, constituent: constituent) else{
        return ((votingData, VotingDataError.invalidRequest), nil)
    }
    
    /// Saves the singleVote to the vote
    guard await vote.addVote(voteStub) else {
        return ((votingData, VotingDataError.attemptedToVoteMultipleTimes), nil)
    }
    
    // Returns a list of priorities to show the user as confirmation for a cast vote
    let prio: [String]
    switch V.enumCase{
    case .alternative:
        let tmp = (voteStub as! SingleVote).rankings.map{$0.name}
        if tmp.isEmpty{
            prio = ["Voted blank"]
        } else{
            prio = tmp
        }
    case .yesNo:
        let val = (voteStub as! yesNoVote.yesNoVoteType).values
        if val.isEmpty{
            prio = ["Voted blank"]
        } else {
            // Fetches the full list of options to recall them in order
            prio = await vote.options.map { opt -> String in
                if let option = val[opt]{
                    return opt.name + ": " + (option ? "Yes" : "No")
                } else {
                    return opt.name + ": Blank"
                }
            }
        }
    case .simpleMajority:
        prio = [(voteStub as! SimpleMajority.SimpleMajorityVote).preferredOption?.name ?? "Voted blank"]
    }
    return (nil, prio)
}
