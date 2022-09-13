@_implementationOnly import CPNG

public enum PNGError: Error, CustomStringConvertible {
    case incorrectDataSize
    case unableToOpenFile(String)
    case readError(path: String, description: String?)
    case writeError(path: String, description: String?)
    
    public var description: String {
        switch self {
        case .incorrectDataSize:
            return "Incorrect data size"
        case .unableToOpenFile(let path):
            return "Unable to open file '\(path)'"
        case .readError(let path, let description):
            return "Unable to read file '\(path)'. \(description ?? "")".trimmingCharacters(in: .whitespaces)
        case .writeError(let path, let description):
            return "Unable to write to file '\(path)'. \(description ?? "")".trimmingCharacters(in: .whitespaces)
        }
    }
}
