import Foundation

public class Bard {
    private let headers: [String: String] = [
        "Host": "bard.google.com",
        "X-Same-Domain": "1",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "Origin": "https://bard.google.com",
        "Referer": "https://bard.google.com/",
    ]
    
    private let token: String
    private let timeout: TimeInterval
    private let session: URLSession
    
    private var reqID: Int = Int.random(in: 0..<10000)
    private var conversationID: String = ""
    private var responseID: String = ""
    private var choiceID: String = ""
    
    private var snim0e: String?
    
    public init(token: String? = nil, timeout: TimeInterval = 20, session: URLSession? = nil) {
        self.token = token ?? ProcessInfo.processInfo.environment["_BARD_API_KEY"] ?? ""
        self.timeout = timeout
        self.session = session ?? URLSession(configuration: .default)
    }
    
    private func getSNlM0e(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://bard.google.com/") else {
            let error = NSError(domain: "Failed to create URL for getting SNlM0e.", code: 0, userInfo: nil)
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.allHTTPHeaderFields = headers
        
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "Invalid HTTP response", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let error = NSError(domain: "Response code not 200. Response Status is \(httpResponse.statusCode)", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                let error = NSError(domain: "Failed to get valid response data.", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            do {
                let pattern = "SNlM0e\":\"(.*?)\""
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
                
                guard let match = matches.first, let range = Range(match.range(at: 1), in: htmlString) else {
                    let error = NSError(domain: "SNlM0e value not found in response. Check __Secure-1PSID value.", code: 0, userInfo: nil)
                    completion(.failure(error))
                    return
                }
                
                let snim0e = String(htmlString[range])
                completion(.success(snim0e))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    public func getAnswer(inputText: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        getSNlM0e { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let snim0e):
                self.snim0e = snim0e
                self.makeAnswerRequest(inputText: inputText, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func makeAnswerRequest(inputText: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params: [String: String] = [
            "bl": "boq_assistant-bard-web-server_20230419.00_p1",
            "_reqid": String(reqID),
            "rt": "c"
        ]
        
        let inputTextStruct: [[Any?]]? = [
            [inputText],
            nil,
            [conversationID, responseID, choiceID]
        ]
        
        let data: [String: Any] = [
            "f.req": [nil, inputTextStruct] as Any,
            "at": snim0e ?? ""
        ]
        
        guard let url = URL(string: "https://bard.google.com/_/BardChatUi/data/assistant.lamda.BardFrontendService/StreamGenerate") else {
            let error = NSError(domain: "Failed to create URL for getting the answer.", code: 0, userInfo: nil)
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = try? JSONSerialization.data(withJSONObject: data, options: [])
        request.allHTTPHeaderFields = params
        
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "Invalid HTTP response", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let error = NSError(domain: "Response code not 200. Response Status is \(httpResponse.statusCode)", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "Failed to get valid response data.", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                if let jsonArray = jsonObject as? [[Any]], let respDict = jsonArray.last as? [String: Any] {
                    completion(.success(respDict))
                } else {
                    let error = NSError(domain: "Invalid response format.", code: 0, userInfo: nil)
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
