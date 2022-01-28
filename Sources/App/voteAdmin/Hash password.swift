import Vapor

func hashPassword(pw: String, groupName: String, for app: Application) throws -> String{
    let trimmedPW = pw.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard trimmedPW.count >= 7, groupName.count < 3 || (!trimmedPW.contains(groupName) && !groupName.contains(trimmedPW)) else {
        throw GroupCreationError.invalidPassword
    }
    
    return try app.password.hash(trimmedPW)
}
