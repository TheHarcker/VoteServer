import Vapor
import VoteExchangeFormat
import Foundation
func APIRoutes(_ app: Application, routesGroup API: RoutesBuilder, groupsManager: GroupsManager){
	let chat = API.grouped("chat")
	chat.webSocket("socket", onUpgrade: joinChat)
	chat.webSocket("adminsocket", onUpgrade: joinChat)
	
	func joinChat(req: Request, socket: WebSocket) async{
		guard Config.enableChat else {
			try? await socket.close()
			return
		}
		
		if req.url.path.hasSuffix("adminsocket") {
			guard
				let sessionID = req.session.authenticated(AdminSession.self),
				let group = await groupsManager.groupForSession(sessionID)
			else {
				try? await socket.close()
				return
			}
			await group.socketController.connectAdmin(socket)
			return
			
		} else if req.url.path.hasSuffix("socket") {
			guard
				let (group, constituent) = await groupsManager.groupAndVoterForReq(req: req),
				//Checks that the constituent is allowed to enter the chat
				await group.constituentCanChat(constituent)
			else{
				try? await socket.close()
				return
			}
			await group.socketController.connect(socket, constituent: constituent)
		}
	}

	
	API.get{ _ throws -> Response in
		throw Abort(.badRequest)
	}
	
	/// userID: String
	/// joinPhrase: String
	API.post("join", use: joinGroup)
	func joinGroup(req: Request) async throws -> Response{
		try await App.joinGroup(req, groupsManager, forAPI: true)
	}
	
	API.get("getdata") { req async throws -> GroupData in
		guard
			let (group, const) = await groupsManager.groupAndVoterForAPI(req: req),
			let data = await group.getExchangeData(for: const.identifier)
		else {
			throw Abort(.unauthorized)
		}
		
		return data
	}
	
	/// Returns full information (metadata, options, validators) regarding a vote only if the client are allowed to vote at the moment
	API.get("getvote", ":voteID", use: getVote)
	func getVote(req: Request) async throws -> ExtendedVoteData{
		guard let (group, const) = await groupsManager.groupAndVoterForAPI(req: req) else {
			throw Abort(.unauthorized)
		}
		
		guard
			let voteIDStr = req.parameters.get("voteID"),
			let vote = await group.voteForID(voteIDStr)
		else {
			throw Abort(.notFound)
		}
		
		let voteData: ExtendedVoteData
		let voteStatus = await group.statusFor(await vote.id())
		switch vote {
		case .alternative(let v):
			guard !(await v.hasConstituentVoted(const)) && voteStatus == .open else {throw Abort(.unauthorized)}
			voteData = await ExtendedVoteData(v, constituentID: const.identifier, group: group)
		case .yesno(let v):
			guard !(await v.hasConstituentVoted(const)) && voteStatus == .open else {throw Abort(.unauthorized)}
			voteData = await ExtendedVoteData(v, constituentID: const.identifier, group: group)
		case .simplemajority(let v):
			guard !(await v.hasConstituentVoted(const)) && voteStatus == .open else {throw Abort(.unauthorized)}
			voteData = await ExtendedVoteData(v, constituentID: const.identifier, group: group)
		}
		
		return voteData
	}
	
	API.post("postvote", ":voteID", use: postVote)
	func postVote(req: Request) async throws -> [String]{
		// Retrieve contextual information
		guard let (group, const) = await groupsManager.groupAndVoterForAPI(req: req) else{
			throw Abort(.unauthorized) //401
		}
		
		guard
			let voteIDStr = req.parameters.get("voteID"),
			let vote = await group.voteForID(voteIDStr)
		else {
			throw Abort(.notFound) //404
		}
		
		// Checks that the vote is open
		guard await group.statusFor(await vote.id()) == .open else {
			throw Abort(.unauthorized) //401
		}
		
		// Decodes and stores the vote
		let p: ((data: Any?, error: Error)?, [String]?)
		switch vote {
		case .alternative(let v):
			p = await decodeAndStore(group: group, vote: v, constituent: const, req: req)
		case .yesno(let v):
			p = await decodeAndStore(group: group, vote: v, constituent: const, req: req)
		case .simplemajority(let v):
			p = await decodeAndStore(group: group, vote: v, constituent: const, req: req)
		}
		
		if let confirmationStrings = p.1{
			return confirmationStrings
		} else if p.0 != nil {
			throw p.0!.error
		} else {
			assertionFailure("This case should never be reached")
			throw Abort(.internalServerError) //500
		}
	}
}


