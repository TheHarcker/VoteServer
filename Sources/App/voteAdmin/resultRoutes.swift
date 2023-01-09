import Vapor
import AltVoteKit
import VoteKit
import Foundation

func ResultRoutes(_ path: RoutesBuilder, groupsManager: GroupsManager) {
	let adminOnly = path.grouped(EnsureGroupAdmin())
	adminOnly.redirectGet("results", to: .admin)
	adminOnly.redirectGet("results", ":voteID", to: .admin)

	adminOnly.post("results", ":voteID", use: showResults)
	func showResults(req: Request) async throws -> Response {
		guard let voteIDStr = req.parameters.get("voteID") else {
			throw Redirect(.admin)
		}
		
		let group = await groupsManager.groupForGroup(try req.auth.require(DBGroup.self))
		
		guard let vote = await group.voteForID(voteIDStr) else {
			throw Redirect(.admin)
		}
		
		guard let response = try? await getResults(req: req, group: group, vote: vote).encodeResponse(for: req) else {
			throw Abort(.internalServerError)
		}
		return response
	}
	
	struct SelectedOptions: Codable{
		var options: [String: String]
		
		func enabledUUIDs()->[UUID]{
			options
				.filter(\.value.isOn)
				.compactMap{UUID($0.key)}
		}
	}

	func getResults(req: Request, group: Group, vote: any DVoteProtocol) async -> UIManager{

         //Makes sure the vote is closed
		await group.setStatusFor(await vote.id, to: .closed)

        
        // Checks the exclude parameter
        var excluding: Set<VoteOption> = []
        if let options = try? req.content.decode(SelectedOptions.self){
            let enabled = options.enabledUUIDs()

            //Finds all options that were not selected by the user
			excluding = Set(await vote.options.filter { option in
                !enabled.contains(option.id)
            })
        }
        
        // Checks the force parameter
        let force = req.url.query?.split(separator: "&").contains("force=1") ?? false
        
		let id = await vote.id
		let vname = await vote.name
		
        do{
			if let vote = vote as? AlternativeVote {
				let winner = try await vote.findWinner(force: force, excluding: excluding)

				if winner.winners().isEmpty{
					throw "An issue occured during counting"
				}

				let enabledOptions = Set(await vote.options).subtracting(excluding)

				return AVResultsUI(title: "Your '\(await vote.name)' vote results", winners: winner, numberOfVotes: await vote.votes.count, enabledOptions: enabledOptions, disabledOptions: excluding)

			} else if let vote = vote as? yesNoVote {
				let count = try await vote.count(force: force)
				return await YesNoResultsUI(vote: vote, count: count)
			} else if let vote = vote as? SimpleMajority {
				let count = try await vote.count(force: force)

				return SimMajResultsUI(title: await vote.name, numberOfVotes: await vote.votes.count, count: count)
			} else {
				fatalError("Unknown vote type found")
			}
        } catch {
            guard let er = error as? [VoteValidationResult] else {
                return genericErrorPage(error: error)
            }
			return ValidationErrorUI(title: vname, validationResults: er, groupID: group.id, voteID: id)
        }
    }
    

	//MARK: Export CSV
	adminOnly.get("results", ":voteID", "downloadcsv", use: downloadResultsForVote)
	func downloadResultsForVote(req: Request) async throws -> Response{
		guard let voteIDStr = req.parameters.get("voteID") else {
			throw Redirect(.admin)
		}

		let dbGroup = try req.auth.require(DBGroup.self)
		let group = await groupsManager.groupForGroup(dbGroup)

		guard let vote = await group.voteForID(voteIDStr) else {
			throw Redirect(.results(voteIDStr))
		}
		
		let csvConfiguration = dbGroup.settings.csvConfiguration
		let csv = await vote.toCSV(config: csvConfiguration)
		return try await downloadResponse(for: req, content: csv, filename: "votes.csv")
	}
	adminOnly.get("results", ":voteID", "downloadconst", use: downloadConstituentsList)
	func downloadConstituentsList(req: Request) async throws -> Response{
		guard let voteIDStr = req.parameters.get("voteID") else {
			throw Redirect(.admin)
		}
		
		let dbGroup = try req.auth.require(DBGroup.self)

		let group = await groupsManager.groupForGroup(dbGroup)
		
		guard let vote = await group.voteForID(voteIDStr) else {
			throw Redirect(.results(voteIDStr))
		}

		let csv = await vote.constituents.toCSV(config: dbGroup.settings.csvConfiguration)

		return try await downloadResponse(for: req, content: csv, filename: "constituents.csv")
	}
}

/// Returns a response which makes the client download the content as a file with the given filename
func downloadResponse(for req: Request, content: String, filename: String) async throws -> Response{
	var headers = HTTPHeaders()
	headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
	return try await content.encodeResponse(status: .ok, headers: headers, for: req)
}
