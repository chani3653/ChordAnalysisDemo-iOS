//
//  MainModels.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

// MARK: - Analysis Availability State

enum AnalysisAvailabilityState: Equatable {
    case unknown
    case checking
    case available
    case unavailable
    case analyzing(progress: Int?, jobID: Int?)

    var statusText: String {
        switch self {
        case .unknown:
            return "확인 전"
        case .checking:
            return "확인중"
        case .available:
            return "분석됨"
        case .unavailable:
            return "미분석"
        case .analyzing(let progress, _):
            if let progress {
                return "분석중 \(progress)%"
            }
            return "분석중"
        }
    }
}

// MARK: - Video Item ViewModel

struct VideoItemViewModel {
    let searchItem: YouTubeSearchItem
    let videoId: String
    let durationText: String
    var analysisState: AnalysisAvailabilityState
}

// MARK: - Analysis Flow Error

enum AnalysisFlowError: LocalizedError {
    case missingJob
    case failedStatus(message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingJob:
            return "분석 요청에 필요한 작업 정보가 없습니다."
        case .failedStatus(let message):
            return message
        case .timeout:
            return "분석이 일정 시간 내에 완료되지 않았습니다."
        }
    }
}

// MARK: - YouTube Duration Parsing

enum YouTubeDurationParser {

    static func parseToSeconds(_ duration: String?) -> Int {
        guard let duration, !duration.isEmpty else { return 0 }

        var hours = 0, minutes = 0, seconds = 0
        var currentNumber = ""
        var isTimeSection = false

        for character in duration {
            if character == "T" { isTimeSection = true; continue }
            if character.isNumber { currentNumber.append(character); continue }
            guard isTimeSection, !currentNumber.isEmpty else { continue }
            let value = Int(currentNumber) ?? 0
            switch character {
            case "H": hours = value
            case "M": minutes = value
            case "S": seconds = value
            default: break
            }
            currentNumber = ""
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    static func format(_ duration: String?) -> String {
        guard let duration, !duration.isEmpty else { return "" }

        var hours = 0, minutes = 0, seconds = 0
        var currentNumber = ""
        var isTimeSection = false

        for character in duration {
            if character == "T" { isTimeSection = true; continue }
            if character.isNumber { currentNumber.append(character); continue }
            guard isTimeSection, !currentNumber.isEmpty else { continue }
            let value = Int(currentNumber) ?? 0
            switch character {
            case "H": hours = value
            case "M": minutes = value
            case "S": seconds = value
            default: break
            }
            currentNumber = ""
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Loading State Display Mapping

enum AnalysisDisplayStateMapper {

    static func displayState(for status: String, progress: Int?) -> AnalysisLoadingOverlayView.AnalysisLoadingDisplayState {
        switch status {
        case "pending":
            return .pending
        case "downloading":
            return .downloading(progress: progress)
        case "analyzing":
            return .analyzing(progress: progress)
        case "complete":
            return .completed
        default:
            return .pending
        }
    }
}
