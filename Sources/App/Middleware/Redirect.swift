import Vapor

// Intercepts RedirectError and redirects the client to the given page
struct RedirectErrorHandler:
	AsyncMiddleware {
	func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
		do {
			return try await next.respond(to: req)
		} catch let error as Redirect{
			return req.redirect(to: error.path)
		}
	}
}

struct Redirect: Error{
	let path: RedirectionPaths
	init(_ path: RedirectionPaths){
		self.path = path
	}
}
