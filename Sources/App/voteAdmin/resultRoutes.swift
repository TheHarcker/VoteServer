import Vapor
import AltVoteKit
import VoteKit

func ResultRoutes(_ app: Application, groupsManager: GroupsManager) {
	app.get("results"){ req in
		req.redirect(to: .admin)
	}

    app.get("results", ":voteID"){ req in
        req.redirect(to: .admin)
    }

	app.post("results", ":voteID"){ req async throws -> Response in
		guard let voteIDStr = req.parameters.get("voteID") else {
			return req.redirect(to: .admin)
		}

		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID),
			let vote = await  group.voteForID(voteIDStr)
		else {
			return req.redirect(to: .admin)
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


	func getResults(req: Request, group: Group, vote: VoteTypes) async -> UIManager{

         //Makes sure the vote is closed
        await group.setStatusFor(await vote.id(), to: .closed)

        
        // Checks the exclude parameter
        var excluding: Set<VoteOption> = []
        if let options = try? req.content.decode(SelectedOptions.self){
            let enabled = options.enabledUUIDs()

            //Finds all options that were not selected by the user
            excluding = Set(await vote.options().filter { option in
                !enabled.contains(option.id)
            })
        }
        
        // Checks the force parameter
        let force = req.url.query?.split(separator: "&").contains("force=1") ?? false
        
        let vid: UUID?
        let vname: String?
        do{
            switch vote {
            case .alternative(let v):
                vid  = await v.id
                vname = await v.name

                let winner = try await v.findWinner(force: force, excluding: excluding)


                if winner.winners().isEmpty{
                    throw "An issue occured during counting"
                }

                let enabledOptions = Set(await v.options).subtracting(excluding)

                return AVResultsUI(title: "Your '\(await v.name)' vote results", winners: winner, numberOfVotes: await v.votes.count, enabledOptions: enabledOptions, disabledOptions: excluding)

            case .yesno(let v):
                vid  = await v.id
                vname = await v.name

                let count = try await v.count(force: force)
                return await YesNoResultsUI(vote: v, count: count)
            case .simplemajority(let v):
                vid  = await v.id
                vname = await v.name

                let count = try await v.count(force: force)

                return SimMajResultsUI(title: await v.name, numberOfVotes: await v.votes.count, count: count)

            }

        } catch {
            guard let er = error as? [VoteValidationResult] else {
                return genericErrorPage(error: error)
            }
            return ValidationErrorUI(title: vname ?? "", validationResults: er, voteID: vid ?? UUID())
        }
    }
    

	//MARK: Export CSV
	app.get("results", ":voteID", "downloadcsv"){ req async throws -> Response in
		guard let voteIDStr = req.parameters.get("voteID") else {
			return req.redirect(to: .admin)
		}


		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID),
			let vote = await group.voteForID(voteIDStr)
		else {
			return req.redirect(to: .results(voteIDStr))
		}
		
        let csv: String
        let csvConfiguration = await group.settings.csvConfiguration
        switch vote {
        case .alternative(let v):
            csv = await v.toCSV(config: csvConfiguration)
        case .yesno(let v):
            csv = await v.toCSV(config: csvConfiguration)
        case .simplemajority(let v):
            csv = await v.toCSV(config: csvConfiguration)
        }
		
		return try await downloadResponse(for: req, content: csv, filename: "votes.csv")
	}
	
	app.get("results", ":voteID", "downloadconst"){ req async throws -> Response in
		guard let voteIDStr = req.parameters.get("voteID") else {
			return req.redirect(to: .admin)
		}
		
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID),
			let vote = await group.voteForID(voteIDStr)
		else {
			return req.redirect(to: .results(voteIDStr))
		}

        let csv = await vote.constituents().toCSV(config: group.settings.csvConfiguration)

		return try await downloadResponse(for: req, content: csv, filename: "constituents.csv")
		
	}
}

func downloadResponse(for req: Request, content: String, filename: String) async throws -> Response{
	var headers = HTTPHeaders()
	headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
	return try await content.encodeResponse(status: .ok, headers: headers, for: req)
}
