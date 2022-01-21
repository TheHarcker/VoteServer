import Vapor
import AltVoteKit

/// Calls all route creaters, which inturn registers and handles the available paths in the app
func routes(_ app: Application, groupsManager: GroupsManager) throws {
	app.get { req in
		req.redirect(to: .create)
	}

	groupCreationRoutes(app, groupsManager: groupsManager)
	voteCreationRoutes(app, groupsManager: groupsManager)
	votingRoutes(app, groupsManager: groupsManager)
    ResultRoutes(app, groupsManager: groupsManager)
    adminRoutes(app, groupsManager: groupsManager)
    groupJoinRoutes(app, groupsManager: groupsManager)
    APIRoutes(app, routesGroup: app.grouped("api"), groupsManager: groupsManager)
}
