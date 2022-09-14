@_implementationOnly import CPNG

public enum PNGError: Error, CustomStringConvertible {
    case incorrectDataSize
    case unableToOpenFile
    case readError(description: String?)
    case writeError(description: String?)
    
    public var description: String {
        switch self {
        case .incorrectDataSize:
            return "Incorrect data size"
        case .unableToOpenFile:
            return "Unable to open file"
        case .readError(let description):
            return "Unable to read file. \(description ?? "")".trimmingCharacters(in: .whitespaces)
        case .writeError(let description):
            return "Unable to write to file. \(description ?? "")".trimmingCharacters(in: .whitespaces)
        }
    }
}
