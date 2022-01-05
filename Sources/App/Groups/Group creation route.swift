import Vapor
/// Defines the /create path and its logic
func groupCreationRoutes(_ app: Application, groupsManager: GroupsManager) throws {
	app.get("create"){ _ in
		GroupCreatorUI()
	}
	
	app.post("create"){ req async throws -> Response in
		var groupData: GroupCreatorData?
		do{
			groupData = try req.content.decode(GroupCreatorData.self)
			//Makes groupData non optional for the rest of this scope
			let groupData = groupData!
			// Creates an ID for the session
			let session = AdminSession()
			
			// Saves the group
			await groupsManager.createGroup(session: session.sessionID, name: try groupData.getGroupName(), constituents: try groupData.getConstituents(), pwdigest: try groupData.getHashedPassword(for: req), allowsUnVerified: groupData.allowsNonVerified())
			
			//Registers the session with the client
			req.session.authenticate(session)
		} catch {
			return (try? await GroupCreatorUI(errorString: error.asString(), groupData).encodeResponse(for: req)) ?? req.redirect(to: .create)
		}
		
		return req.redirect(to: .voteadmin)
	}
}
