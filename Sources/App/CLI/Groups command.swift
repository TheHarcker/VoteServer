import Vapor

struct GroupsCommand: Command{
    let groupsManager: GroupsManager
    weak var app: Application?
    
    struct Signature: CommandSignature {
        @Argument(name: "value")
        var value: String
        
        @Flag(name: "info", short: "i")
        var info: Bool
        
        @Flag(name: "delete", short: "d")
        var delete: Bool
        
        @Option(name: "password", short: "p")
         var newPassword: String?
    }
    
    var help: String {
        """
        Manage groups:
        list - shows a list of groups
        [join phrase] - The joinphrase to use
        -i - Get info for the for this join phrase
        -d - Delete the group linked to this join phrase
        -p [Password] - Sets the password
        """
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let trimVal = signature.value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimVal.isEmpty || trimVal == "list"{
            Task{
                context.console.print("All groups:")
                let allGroups = await groupsManager.listAllGroups()
                context.console.print(allGroups)

            }
            return
        }
        
		guard trimVal.count == Config.joinPhraseLength else {
            throw "Invalid joinphrase"
        }
        let joinPhrase = trimVal
        if signature.info && signature.delete{
            throw "Only one flag at a time"
        }
        
        if signature.newPassword != nil && !signature.newPassword!.isEmpty{
            if signature.info || signature.delete{
                throw "Only one flag at a time"
            }
        
            let pw = signature.newPassword!.trimmingCharacters(in: .whitespacesAndNewlines)
            
            Task{
                guard let app = app, let group = await groupsManager.groupForJoinPhrase(joinPhrase) else {
                    throw "Group not found"
                }
                guard let digest = try? hashPassword(pw: pw, groupName: group.name, for: app) else {
                    throw "Invalid or insecure password"
                }
                await group.setPasswordTo(digest: digest)
                context.console.print("Password was set")

            }
            
        } else if signature.delete{
            Task{
                if await groupsManager.deleteGroup(jf: joinPhrase){
                    context.console.print("Successfully deleted: \(joinPhrase)")
                    return
                } else {
                    throw "Unable to delete: \(joinPhrase)"
                }
            }
        } else {
            
            Task{
                guard
                    let group = await groupsManager.groupForJoinPhrase(joinPhrase),
                    let lastAccess = await groupsManager.getLastAccess(for: group)
                else {
                    throw "Group not found"
                }
                
                let result = "Group:\"\(group.name)\"\nWith \(await group.constituentsSessionID.count) constituents in session\nGroup was last accessed at: " + lastAccess
                context.console.print(result)
                
            }
            return
        }
    }
}

