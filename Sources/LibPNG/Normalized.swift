@propertyWrapper
public struct Normalized<Value: FixedWidthInteger & UnsignedInteger>: Hashable, Comparable {
    public static func < (lhs: Normalized<Value>, rhs: Normalized<Value>) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    @usableFromInline var rawValue: Value
    
    @inlinable public var wrappedValue: Double {
        get { Double(rawValue) / Double(Value.max) }
        set { rawValue = Value(newValue * Double(Value.max)) }
    }
    
    @inlinable public var projectedValue: Value {
        _read { yield rawValue }
        _modify { yield &rawValue }
    }
    
    @inlinable public init(wrappedValue: Double) {
        self.rawValue = Value(wrappedValue * Double(Value.max))
    }
}
