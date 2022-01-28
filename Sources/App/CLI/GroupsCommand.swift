import Vapor

struct GroupsCommand: Command, Sendable{
    let groupsManager: GroupsManager
    
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
        if signature.value.isEmpty || signature.value == "list"{
            Task{
                let allGroups = await groupsManager.listAllGroups()
                context.console.print(allGroups)

            }
            return
        }
        
        
        guard signature.value.count == joinPhraseLength else {
            throw "Invalid joinphrase"
        }
        
        let joinPhrase = signature.value
        
        if signature.info && signature.delete{
            throw "Only one flag at a time"
        }
        
        if signature.newPassword != nil && !signature.newPassword!.isEmpty{
            if signature.info || signature.delete{
                throw "Only one flag at a time"
            }
        
            let pw = signature.newPassword!.trimmingCharacters(in: .whitespacesAndNewlines)
            
            Task{
                guard let group = await groupsManager.groupForJoinPhrase(joinPhrase) else {
                    context.console.error("Group not found")
                    return
                }
                guard let digest = try? hashPassword(pw: pw, groupName: group.name, for: context.application) else {
                    context.console.error("Invalid or insecure password")
                    return
                }
                await group.setPasswordTo(digest: digest)
                context.console.info("Password was set")

            }
            
        } else if signature.delete{
            Task{
                if await groupsManager.deleteGroup(jf: joinPhrase){
                    context.console.print("Successfully deleted: \(joinPhrase)")
                } else {
                    context.console.error("Unable to delete: \(joinPhrase)")
                }
            }
            
            return
        } else if signature.info{
            
            Task{
                guard
                    let group = await groupsManager.groupForJoinPhrase(joinPhrase),
                    let lastAccess = await groupsManager.getLastAccess(for: group)
                else {
                    context.console.error("Group not found")
                    return
                }
                
                let result = "Group:\"\(group.name)\"\nWith \(await group.constituentsSessionID.count) constituents in session\nGroup was last accessed at: " + lastAccess
                context.console.print(result)
                
            }
            return
        }
    }
}

