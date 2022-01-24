import Foundation
import Vapor
import VoteKit
import AltVoteKit

func votingRoutes(_ app: Application, groupsManager: GroupsManager) {
    
    /// Shows the voting ui for the supplied voteID
    app.get("vote", ":voteID") { req async throws -> Response in
        guard let (group, vote, constituent) = await voteGroupAndUserID(for: req) else{
            return req.redirect(to: .plaza)
        }
        switch vote {
        case .alternative(let v):
            return try await checkAndShow(group: group, constituent: constituent, vote: v).encodeResponse(for: req)
        case .yesno(let v):
            return try await checkAndShow(group: group, constituent: constituent, vote: v).encodeResponse(for: req)
        case .simplemajority(let v):
            return try await checkAndShow(group: group, constituent: constituent, vote: v).encodeResponse(for: req)
        }
        
    }
    
    /// Receives the vote the constituent wants to cast, and either accepts the vote or an error will be shown to the user
    app.post("vote", ":voteID") { req async throws -> Response in
        guard let (group, vote, constituent) = await voteGroupAndUserID(for: req) else{
            return req.redirect(to: .plaza)
        }
        
        // Checks that the vote is open, otherwise the relevant votepage will be shown in the closed mode
        guard await group.statusFor(await vote.id()) == .open else {
            switch vote {
            case .alternative(let v):
                return try await AltVotePageGenerator.closed(title: v.name).encodeResponse(for: req)
            case .yesno(let v):
                return try await YesNoVotePage.closed(title: v.name).encodeResponse(for: req)
            case .simplemajority(let v):
                return try await SimMajVotePage.closed(title: v.name).encodeResponse(for: req)
            }
        }
        
        switch vote {
        case .alternative(let v):
            return try await d(group: group, vote: v, constituent: constituent, req: req).encodeResponse(for: req)
        case .yesno(let v):
            return try await d(group: group, vote: v, constituent: constituent, req: req).encodeResponse(for: req)
        case .simplemajority(let v):
            return try await d(group: group, vote: v, constituent: constituent, req: req).encodeResponse(for: req)
        }
    }
    
    
    /// Checks that a vote can be accessed and renders the vote page
    /// - Returns: The relevant vote page; either in a "Redy to vote state" or an error state
    func checkAndShow<V: SupportedVoteType>(group: Group, constituent: Constituent, vote: V, errorString: String? = nil, persistentData: V.VotePageUI.PersistanceData? = nil) async -> UIManager{
        //Checks that the vote is open
        guard await group.statusFor(vote) == .open  else {
            return await V.VotePageUI.closed(title: await vote.name)
        }
        
        // Checks that the user hasn't voted yet
        guard !(await vote.hasConstituentVoted(constituent)) else{
            return await V.VotePageUI.hasVoted(title: await vote.name)
        }
        
        // Creates a vote page for the given vote
        return await V.VotePageUI.init(title: await vote.name, vote: vote, errorString: errorString, persistentData: persistentData)
    }
    
    
    
    /// Returns a UI dependent on the success of decoding and storing votes
    /// - Returns: The UI to show, either a vote page where the constituent can try to fix the error or a success page which shows what was voted for
    func d<V: SupportedVoteType>(group: Group, vote: V, constituent: Constituent, req: Request) async -> UIManager{
        
        let p: ((data: V.ReceivedData?, error: Error)?, [String]?) = await decodeAndStore(group: group, vote: vote, constituent: constituent, req: req)
        assert(p.0 == nil || p.1 == nil)
        
        
        if let confirmationStrings = p.1{
            let voterID = constituent.name ?? constituent.identifier
            return SuccessfullVoteUI(title: await vote.name, voterID: voterID, priorities: confirmationStrings )
        } else {
            let votePage = await checkAndShow(group: group, constituent: constituent, vote: vote, errorString: p.0?.error.asString(), persistentData: p.0?.data?.asCorrespondingPersistenseData())
            return votePage
        }
    }
    
    
    
    func voteGroupAndUserID(for req: Request) async -> (group: Group, vote: VoteTypes, constituent: Constituent)?{
        guard
            let voterSession = req.session.authenticated(VoterSession.self),
            let groupID = req.session.authenticated(GroupSession.self),
            let voteIDStr = req.parameters.get("voteID"),
            let group = await groupsManager.groupForGroupID(groupID),
            let constituent = await group.constituentsSessionID[voterSession],
            let vote = await group.voteForID(voteIDStr)
        else {
            return nil
        }
        
        return (group, vote, constituent)
    }
}
