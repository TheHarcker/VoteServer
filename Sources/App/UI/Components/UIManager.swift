import Vapor
protocol UIManager: Codable, AsyncResponseEncodable, ResponseEncodable{
	/// The title of the page
	var title: String {get}
	
	/// Errors to be shown
	var errorString: String? {get}
	
	/// The buttons to be shown on the top row
	var buttons: [UIButton] {get}
	
	/// Name of the corresponding leaf template
	static var template: String {get}
	
	func render(for req: Request) async throws -> View
	func render(for req: Request) async throws -> Response

	func encodeResponse(for req: Request) async throws -> Response
}



extension UIManager{
	var buttons: [UIButton] {[]}
	
	func render(for req: Request) async throws -> View{
		try await req.view.render(Self.template, self)
	}
	
	func render(for req: Request) async throws -> Response{
		let view: View = try await self.render(for: req)
		return try await view.encodeResponse(for: req)
	}

	func encodeResponse(for req: Request) async throws -> Response {
		try await self.render(for: req)
	}
	
	func encodeResponse(for req: Request) -> EventLoopFuture<Response>{
		req.view.render(Self.template, self).encodeResponse(for: req)
	}
}
