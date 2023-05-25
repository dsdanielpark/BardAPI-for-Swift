import XCTest
@testable import BardAPI

final class BardAPITests: XCTestCase {

    let token = "xxxxxxxxxx" // Replace with your actual token

    let bard = Bard(token: token)

    let inputText = "나와 내 동년배들이 좋아하는 뉴진스에 대해서 알려줘"
    bard.getAnswer(inputText: inputText) { result in
        switch result {
        case .success(let response):
            print("Content: \(response["content"] ?? "")")
            print("Conversation ID: \(response["conversation_id"] ?? "")")
            print("Response ID: \(response["response_id"] ?? "")")
            print("Factuality Queries: \(response["factualityQueries"] ?? [])")
            print("Text Query: \(response["textQuery"] ?? "")")
            if let choices = response["choices"] as? [[String: Any]] {
                for choice in choices {
                    let choiceID = choice["id"] ?? ""
                    let choiceContent = choice["content"] ?? ""
                    print("Choice ID: \(choiceID), Content: \(choiceContent)")
                }
            }
        case .failure(let error):
            print("Error: \(error)")
        }
    }
    }

