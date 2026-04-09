//
//  NetworkManager.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation
import Alamofire
import UIKit

final class NetworkManager {

    struct NetworkErrorBroadcast {
        let code: Int?
        let message: String
        let underlyingError: Error
    }

    static let shared = NetworkManager()
    static let errorNotification = Notification.Name("NetworkManagerErrorNotification")

    private init() {}

    // MARK: - GET

    func get<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        let response = await AF.request(
            url,
            method: .get,
            parameters: parameters,
            headers: headers
        )
        .validate()
        .serializingDecodable(T.self)
        .response
        if let error = response.error {
            handleError(error, response: response.response, data: response.data)
            throw error
        }
        if let value = response.value {
            return value
        }
        let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        handleError(error, response: response.response, data: response.data)
        throw error
    }

    // MARK: - POST

    func post<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = JSONEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        let response = await AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )
        .validate()
        .serializingDecodable(T.self)
        .response
        if let error = response.error {
            handleError(error, response: response.response, data: response.data)
            throw error
        }
        if let value = response.value {
            return value
        }
        let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        handleError(error, response: response.response, data: response.data)
        throw error
    }

    // MARK: - PUT

    func put<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = JSONEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        let response = await AF.request(
            url,
            method: .put,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )
        .validate()
        .serializingDecodable(T.self)
        .response
        if let error = response.error {
            handleError(error, response: response.response, data: response.data)
            throw error
        }
        if let value = response.value {
            return value
        }
        let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        handleError(error, response: response.response, data: response.data)
        throw error
    }

    // MARK: - DELETE

    func delete<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        let response = await AF.request(
            url,
            method: .delete,
            parameters: parameters,
            headers: headers
        )
        .validate()
        .serializingDecodable(T.self)
        .response
        if let error = response.error {
            handleError(error, response: response.response, data: response.data)
            throw error
        }
        if let value = response.value {
            return value
        }
        let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        handleError(error, response: response.response, data: response.data)
        throw error
    }

    private func handleError(_ error: Error, response: HTTPURLResponse?, data: Data?) {
        let fallbackMessage = error.localizedDescription
        let detailMessage = extractDetailMessage(from: data, fallback: fallbackMessage)
        let code = response?.statusCode
            ?? extractStatusCode(from: error)
        let displayMessage: String
        if let code {
            displayMessage = "[\(code)] \(detailMessage)"
        } else {
            displayMessage = detailMessage
        }
        logError(code: code, message: detailMessage)
        broadcastError(code: code, message: displayMessage, underlyingError: error)
        presentErrorAlert(message: displayMessage)
    }

    private func extractDetailMessage(from data: Data?, fallback: String) -> String {
        guard let data, !data.isEmpty else { return fallback }
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let json = jsonObject as? [String: Any] {
            if let errorInfo = json["error"] as? [String: Any] {
                if let message = errorInfo["message"] as? String, !message.isEmpty {
                    return message
                }
                if let errors = errorInfo["errors"] as? [[String: Any]],
                   let firstMessage = errors.first?["message"] as? String,
                   !firstMessage.isEmpty {
                    return firstMessage
                }
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return sanitizeHTML(text)
        }
        return fallback
    }

    private func logError(code: Int?, message: String) {
        if let code {
            print("\(code) : \"\(message)\"")
            return
        }
        print("Error : \"\(message)\"")
    }

    private func extractStatusCode(from error: Error) -> Int? {
        if let afError = error as? AFError {
            if case let .responseValidationFailed(reason) = afError,
               case let .unacceptableStatusCode(code) = reason {
                return code
            }
            return afError.responseCode
        }
        return (error as? URLError)?.errorCode
    }

    private func sanitizeHTML(_ text: String) -> String {
        guard text.contains("<") else { return text }
        if let data = text.data(using: .utf8),
           let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
           ) {
            let stripped = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return stripped.isEmpty ? text : stripped
        }
        return text
    }

    private func broadcastError(code: Int?, message: String, underlyingError: Error) {
        let payload = NetworkErrorBroadcast(code: code, message: message, underlyingError: underlyingError)
        NotificationCenter.default.post(
            name: NetworkManager.errorNotification,
            object: self,
            userInfo: ["payload": payload]
        )
    }

    private func presentErrorAlert(message: String) {
        DispatchQueue.main.async {
            guard let topViewController = UIApplication.shared.topMostViewController() else { return }
            let overlay = ErrorOverlayView()
            overlay.update(message: message)
            overlay.show(in: topViewController.view)
        }
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }
        guard let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return root.topMostViewController()
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let navigationController = self as? UINavigationController,
           let visible = navigationController.visibleViewController {
            return visible.topMostViewController()
        }
        if let tabBarController = self as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}

