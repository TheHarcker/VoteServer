import Vapor

func setupCommands(groupsManager: GroupsManager, app: Application){
    Task(priority: .background){
        let c = GroupsCommand(groupsManager: groupsManager, app: app)
        let console: Console = app.console

        var commands = Commands(enableAutocomplete: true)
        commands.use(c, as: "groups", isDefault: false)
        
        let group = commands.group(help: "")
        
        while true{
            guard let t = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }
            
            let str = Array(t.split(separator: " ").map{String($0)})

            let input: CommandInput = .init(arguments: [""] + str)
            
            do {
                try console.run(group, input: input)
            } catch {
                if let erStr = error as? String{
                    console.error(erStr)
                } else {
                    console.error("Unexpected input")
                }
            }
        }
    }
}
