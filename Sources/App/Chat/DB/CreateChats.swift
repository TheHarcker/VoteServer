import Fluent

struct CreateChats: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Chats.schema)
			.id()
			.field("group_id", .uuid, .required)
			.field("sender", .string, .required)
			.field("message", .string, .required)
			.field("timestamp", .datetime, .required)
			.field("systems_message", .bool, .required)
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Chats.schema).delete()
	}
}
