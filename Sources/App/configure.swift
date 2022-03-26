import Leaf
import Vapor
import Fluent
import FluentSQLiteDriver

// configures your application
public func configure(_ app: Application) throws {
    // Allow static files to be served from /Public
	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	// Adds support for using leaf to render views
    app.views.use(.leaf)
	
	//DB
	app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

	app.migrations.add(CreateChats())
	
	app.migrations.add(SessionRecord.migration)

	try app.autoMigrate().wait()
	
	
	// Enables sessions
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
let joinPhraseLength: UInt = 6
let maxChatLength: UInt = 1000
let chatQueryLimit: Int = 100
let messageRateLimiting: (seconds: Double, messages: Int) = (seconds: 10.0, messages: 10)
