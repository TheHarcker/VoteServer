import Vapor
/// Defines the /create path and its logic
func groupCreationRoutes(_ app: Application, groupsManager: GroupsManager) {
	app.get("create", use: GroupCreatorUI.init)
	app.post("create", use: createGroup)
    @Sendable func createGroup(req: Request) async throws -> GroupCreatorUI{
		var groupData: GroupCreatorData?
		do{
			groupData = try req.content.decode(GroupCreatorData.self)
			//Makes groupData non optional for the rest of this scope
			let groupData = groupData!
			// Creates an ID for the session
			let session = AdminSession()
			
			// Saves the group
            guard await groupsManager.createGroup(session: session.sessionID, db: req.db, name: try groupData.getGroupName(), constituents: try groupData.getConstituents(), pwdigest: try groupData.getHashedPassword(for: req), allowsUnverified: groupData.allowsUnverified) else {
				throw Abort(.internalServerError)
			}
			
			//Registers the session with the client
			req.session.authenticate(session)
		} catch {
			return GroupCreatorUI(errorString: error.asString(), groupData)
		}
		
		throw Redirect(.admin)
	}
}
