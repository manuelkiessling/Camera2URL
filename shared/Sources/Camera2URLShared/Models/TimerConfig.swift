//
//  TimerConfig.swift
//  Camera2URLShared
//

import Foundation

/// Time unit for the timer interval
public enum TimerUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case seconds = "seconds"
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        rawValue.capitalized
    }
    
    public var singularName: String {
        switch self {
        case .seconds: return "second"
        case .minutes: return "minute"
        case .hours: return "hour"
        case .days: return "day"
        }
    }
    
    /// Convert a value in this unit to seconds
    public func toSeconds(_ value: Int) -> TimeInterval {
        switch self {
        case .seconds: return TimeInterval(value)
        case .minutes: return TimeInterval(value * 60)
        case .hours: return TimeInterval(value * 3600)
        case .days: return TimeInterval(value * 86400)
        }
    }
}

/// Configuration for automatic photo capture timer
public struct TimerConfig: Equatable, Codable, Sendable {
    public var value: Int {
        didSet {
            if value < 1 {
                value = 1
            }
        }
    }
    public var unit: TimerUnit
    
    public init(value: Int = 30, unit: TimerUnit = .seconds) {
        self.value = max(1, value)
        self.unit = unit
    }
    
    public var intervalInSeconds: TimeInterval {
        unit.toSeconds(value)
    }
    
    public var displayString: String {
        if value == 1 {
            return "every \(value) \(unit.singularName)"
        }
        return "every \(value) \(unit.rawValue)"
    }
}

