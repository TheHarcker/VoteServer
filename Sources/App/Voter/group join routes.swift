import Vapor
import VoteKit
import Foundation
func groupJoinRoutes(_ app: Application, groupsManager: GroupsManager) {
	app.get("join"){ req async -> GroupJoinUI in
        let showRedirectToPlaza = await groupsManager.groupAndVoterForReq(req: req) != nil
        return GroupJoinUI(title: "Join", showRedirectToPlaza: showRedirectToPlaza)
	}
	
	app.get("join", ":joinphrase"){req async throws -> Response in
		guard
			let jf = req.parameters.get("joinphrase"),
			let group = await groupsManager.groupForJoinPhrase(jf)
		else {
			return req.redirect(to: .join)
		}
        let showRedirectToPlaza = await groupsManager.groupAndVoterForReq(req: req) != nil
		return try await GroupJoinUI(title: group.name, joinPhrase: jf, showRedirectToPlaza: showRedirectToPlaza).encodeResponse(for: req)
	}
	
	app.post("join") { req async throws in
        try await joinGroup(req, groupsManager, forAPI: false)
	}
	
	app.post("join", ":joinphrase") { req async throws in
		try await joinGroup(req, groupsManager, forAPI: false)
	}
	
	
	app.get("plaza"){req async -> Response in
		guard let (group, constituent) = await groupsManager.groupAndVoterForReq(req: req) else {
			return req.redirect(to: .join)
		}
		
		let controller = await PlazaUI(constituent: constituent, group: group)
		
		return (try? await controller.encodeResponse(for: req)) ?? req.redirect(to: .join)
	}
    
    app.post("plaza"){ req async -> Response in
        guard let (group, constituent) = await groupsManager.groupAndVoterForReq(req: req) else {
            return req.redirect(to: .join)
        }
        
        if
            await group.settings.constituentsCanSelfResetVotes,
            let deleteID = (try? req.content.decode([String:String].self))?["deleteId"],
            let voteID = UUID(deleteID),
            let vote = await group.voteForID(voteID),
            await group.statusFor(voteID) == .open
        {
            await group.singleVoteReset(vote: vote, constituentID: constituent.identifier)
            return req.redirect(to: .plaza)
        }
        
        
        let controller = await PlazaUI(constituent: constituent, group: group)
        
        return (try? await controller.encodeResponse(for: req)) ?? req.redirect(to: .join)
    }
    
}


enum joinGroupErrors: ErrorString, Equatable{
	case userIDIsInvalid
	case userIsNotAllowedIn
	case noGroupForJF(JoinPhrase)
	case constituentIsAlreadyIn
	
	func errorString() -> String {
		switch self {
		case .userIDIsInvalid:
			return "Invalid userID"
		case .userIsNotAllowedIn:
			return "You're not allowed to access this group"
		case .noGroupForJF(let joinPhrase):
			return "No group was found for '\(joinPhrase.htmlEscaped())'"
		case .constituentIsAlreadyIn:
			return "This user has already joined, if you think this is an error ask the admin to reset your access"
		}
	}
}




func joinGroup(_ req: Request, _ groupsManager: GroupsManager, forAPI: Bool) async throws -> Response{
	struct JoinGroupData: Codable{
		var userID: String
		var joinPhrase: String
	}

	guard let content = try? req.content.decode(JoinGroupData.self) else{
		throw "Invalid request"
	}
	
	
	let userID = content.userID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	let joinPhrase = content.joinPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
	
	var groupName: String?
	do{
		guard !userID.isEmpty else {
			throw joinGroupErrors.userIDIsInvalid
		}
        
        // Checks that the user id does not contain a comma or a semicolon
		guard !userID.contains(","), !userID.contains(";"), userID.count <= maxNameLength, !userID.contains("admin") else {
            throw joinGroupErrors.userIDIsInvalid
        }
		
		guard let group = await groupsManager.groupForJoinPhrase(joinPhrase) else {
			throw joinGroupErrors.noGroupForJF(joinPhrase)
		}

		groupName = group.name

		
		// Creates a constituent object for the requesting client
		let const: Constituent
		if let c = await group.verifiedConstituent(for: userID){
			const = c
		} else {
			//Checks if verification is required
            guard await group.settings.allowsUnverifiedConstituents else {
				throw joinGroupErrors.userIsNotAllowedIn
			}
			
			const = Constituent(stringLiteral: userID)
		}
		
		
		let constituentID = UUID()
		// Adds the constituent
		guard await group.joinConstituent(const, for: constituentID) else {
			throw joinGroupErrors.constituentIsAlreadyIn
		}
		

        if forAPI{
            guard let data = await group.getExchangeData(for: userID) else {
                throw Abort(.internalServerError)
            }
			req.session.authenticate(APISession(sessionID: constituentID))
			req.session.authenticate(await group.groupSession)

            return Response(body: .init(data: try JSONEncoder().encode(data)))
        } else{
            // Adds the group and constituent key to the user's session
            req.session.authenticate(VoterSession(sessionID: constituentID))
			req.session.authenticate(await group.groupSession)

            return req.redirect(to: .plaza)
        }

	} catch {
        if forAPI{
            if let er = error as? joinGroupErrors {
                if er == .constituentIsAlreadyIn{
                    throw Abort(.alreadyReported)
                }
            }
           throw Abort(.unauthorized)
            
        } else {
            let showRedirectToPlaza = await groupsManager.groupAndVoterForReq(req: req) != nil
            
            return try await GroupJoinUI(title: groupName ?? "Join", joinPhrase: joinPhrase, userID: userID, errorString: error.asString(), showRedirectToPlaza: showRedirectToPlaza).encodeResponse(for: req)
        }
	}
}
