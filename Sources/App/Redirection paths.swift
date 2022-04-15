import Vapor
import VoteExchangeFormat

/// Defines paths often used for redirection
enum RedirectionPaths{
	case create
    case createvote(VoteTypes.StringStub)
	case voteadmin(String?)
    case results(String)
    case admin
	case join
	case plaza
	case constituents
	case login
    case API(APIPath: APIPaths)
    
	func stringValue() -> String{
		switch self {
		case .create:
			return "create"
		case .createvote(let string):
            return "createvote/" + string.rawValue
		case .voteadmin(let id):
			if id == nil {
				return "voteadmin"
			} else {
				return "voteadmin/\(id!)"
			}
		case .results(let id):
			return "results/\(id)"
        case .admin:
            return "admin"
        case .join:
			return "join"
		case .plaza:
			return "plaza"
		case .constituents:
			return "admin/constituents"
		case .login:
			return "login"
        case .API(let APIPath):
            return "api/v1/" + APIPath.relativeStringValue()
		}
	}
}

extension Request{
	func redirect(to location: RedirectionPaths, type: RedirectType = .normal) -> Response {
		self.redirect(to: "/" + location.stringValue() + "/", type: type)
	}
}

extension RedirectionPaths: AsyncResponseEncodable, ResponseEncodable{
	func encodeResponse(for req: Request) async throws -> Response {
		req.redirect(to: self)
	}
	
	func encodeResponse(for req: Request) -> EventLoopFuture<Response> {
		req.eventLoop.makeSucceededFuture(req.redirect(to: self))
	}
}

// Enables creating routes directly for redirection
extension RoutesBuilder {
	@discardableResult
	func redirectGet(_ path: PathComponent..., to: RedirectionPaths) -> Route{
		return self.on(.GET, path){ req in
			req.redirect(to: to)
		}
	}
}
