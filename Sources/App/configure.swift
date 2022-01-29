import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // Allow static files to be served from /Public
	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	// Adds support for using leaf to render views
    app.views.use(.leaf)
	
	
	// Adds support for sessions
	app.sessions.use(.memory)
	app.middleware.use(app.sessions.middleware)

	// Defines password hashing function
	app.passwords.use(.bcrypt)
	
    
    let groupsManager = GroupsManager()

    // Enables CLI
    setupCommands(groupsManager: groupsManager, app: app)
    
    // Register routes
    try routes(app, groupsManager: groupsManager)
}

let maxNameLength: Int = 100
let joinPhraseLength: Int = 6
