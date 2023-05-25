import os
import string
import random
import Foundation

enum Language: String {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
}

struct Bard {
    private let session: URLSession
    private let token: String
    private var reqid: Int
    private var conversationId: String
    private var responseId: String
    private var choiceId: String
    private let snim0e: String
    private let language: Language?
    
    init(
        token: String? = nil,
        timeout: TimeInterval = 20,
        proxies: [String: Any]? = nil,
        session: URLSession = .shared,
        language: Language? = nil
    ) {
        self.token = token ?? ProcessInfo.processInfo.environment["_BARD_API_KEY"] ?? ""
        self.session = session
        self.reqid = Int.random(in: 0..<10_000)
        self.conversationId = ""
        self.responseId = ""
        self.choiceId = ""
        self.snim0e = getSNlM0e()
        self.language = language ?? Language(rawValue: ProcessInfo.processInfo.environment["_BARD_API_LANG"] ?? "")
    }
    
    private func getSNlM0e() -> String {
        guard let lastChar = token.last, lastChar == "." else {
            fatalError("__Secure-1PSID value must end with a single dot.")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var snim0eValue: String?
        
        let headers = [
            "Host": "bard.google.com",
            "X-Same-Domain": "1",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Origin": "https://bard.google.com",
            "Referer": "https://bard.google.com/"
        ]
        
        let url = URL(string: "https://bard.google.com/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        session.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                fatalError("Failed to retrieve SNlM0e value.")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            let pattern = #"SNlM0e":"(.*?)""#
            guard let match = responseString.range(of: pattern, options: .regularExpression) else {
                fatalError("SNlM0e value not found in the response.")
            }
            
            snim0eValue = String(responseString[match].dropFirst(10).dropLast(1))
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return snim0eValue ?? ""
    }
    
    private func extractLinks(from data: Any?) -> [String] {
        var links: [String] = []
        
        if let data = data as? [Any] {
            for item in data {
                if let subData = item as? [Any] {
                    links += extractLinks(from: subData)
                } else if let string = item as? String, string.starts(with: "http"), !string.contains("favicon") {
                    links.append(string)
                }
            }
        }
        
        return links
    }
    
    private func translateIfNeeded(_ text: String) -> String {
        guard let language = language, !Language.allCases.contains(language) else {
            return text
        }
        
        let translator = GoogleTranslator(source: "auto", target: language.rawValue)
        return translator.translate(text)
    }
    
    func getAnswer(for inputText: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params = [
            "bl": "boq_assistant-bard-web-server_20230419.00_p1",
            "_reqid": String(reqid),
            "rt": "c"
        ]
        
        var inputTextStruct: [[Any]] = [[inputText], nil, [conversationId, responseId, choiceId]]
        
        if let translatedText = translateIfNeeded(inputText) {
            inputTextStruct[0][0] = translatedText
        }
        
        let requestData = [
            "f.req": "[null, \(JSONSerialization.jsonString(from: inputTextStruct) ?? "")]",
            "at": snim0e
        ]
        
        let headers = [
            "Host": "bard.google.com",
            "X-Same-Domain": "1",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Origin": "https://bard.google.com",
            "Referer": "https://bard.google.com/",
            "__Secure-1PSID": token
        ]
        
        let url = URL(string: "https://bard.google.com/_/BardChatUi/data/assistant.lamda.BardFrontendService/StreamGenerate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = requestData.percentEncoded()
        
        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "BardError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            let responseLines = responseString.split(separator: "\n")
            
            guard responseLines.count > 3 else {
                completion(.failure(NSError(domain: "BardError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            let responseJSONString = String(responseLines[3])
            
            guard let responseJSONData = responseJSONString.data(using: .utf8) else {
                completion(.failure(NSError(domain: "BardError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response JSON"])))
                return
            }
            
            do {
                let parsedAnswer = try JSONSerialization.jsonObject(with: responseJSONData) as? [[[[Any]]]]
                var bardAnswer: [String: Any] = [
                    "content": parsedAnswer?[0][0][0][0] ?? "",
                    "conversation_id": parsedAnswer?[0][1][0] ?? "",
                    "response_id": parsedAnswer?[0][1][1] ?? "",
                    "factualityQueries": parsedAnswer?[0][3] ?? [],
                    "textQuery": parsedAnswer?[0][2][0] ?? "",
                    "choices": parsedAnswer?[0][4].map { ["id": $0[0], "content": $0[1][0]] } ?? [],
                    "links": extractLinks(from: parsedAnswer?[0][4]),
                    "images": Set(parsedAnswer?[0][4][0][4].compactMap { $0[0][0][0] } ?? [])
                ]
                
                if let language = language, !Language.allCases.contains(language) {
                    let translator = GoogleTranslator(source: "auto", target: language.rawValue)
                    bardAnswer["content"] = translator.translate(bardAnswer["content"] as? String ?? "")
                    
                    if let choices = bardAnswer["choices"] as? [[String: Any]] {
                        bardAnswer["choices"] = choices.map {
                            ["id": $0["id"] as? String ?? "", "content": translator.translate($0["content"] as? String ?? "")]
                        }
                    }
                }
                
                conversationId = bardAnswer["conversation_id"] as? String ?? ""
                responseId = bardAnswer["response_id"] as? String ?? ""
                choiceId = (bardAnswer["choices"] as? [[String: Any]])?.first?["id"] as? String ?? ""
                reqid += 100000
                
                completion(.success(bardAnswer))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
