import XCTest
import RxSwift
@testable import DataViz

class EventSourceSessionTests: XCTestCase {

    var context: ContextMock!
    var disposeBag: DisposeBag!
    var sut: EventSourceSessionImpl!

    let testUrl = URL(string: "http://test.com")!
    var state: EventSourceSessionState?
    var error: Error?
    var data: String?

    override func setUp() {
        super.setUp()

        disposeBag = DisposeBag()
        context = ContextMock()
        sut = EventSourceSessionImpl(context: context, url: testUrl)
        sut.state.subscribe(onNext: { [weak self] state in
            self?.state = state
        }).disposed(by: disposeBag)
        sut.error.subscribe(onNext: { [weak self] error in
            self?.error = error
        }).disposed(by: disposeBag)
        sut.data.subscribe(onNext: { [weak self] data in
            self?.data = data
        }).disposed(by: disposeBag)
    }
    
    override func tearDown() {
        state = nil
        error = nil
        data = nil
        sut = nil
        context = nil
        disposeBag = nil
        super.tearDown()
    }
    
    func testClosedStateOnInit() {
        XCTAssertEqual(state, .closed)
    }

    func testConectingStateOnStart() {
        sut.start()
        XCTAssertEqual(state, .connecting)
    }

    func testCreateNewURLSessionOnStart() {
        sut.start()
        XCTAssertTrue(context.newUrlSessionInvoked)
    }

    func testCorrectSessionSetupOnStart() {
        sut.start()
        XCTAssertEqual(context.urlSessionMock.dataTaskUrl, testUrl)
        XCTAssertEqual(context.newUrlSessionConfiguration?.timeoutIntervalForRequest, TimeInterval(INT_MAX))
        XCTAssertEqual(context.newUrlSessionConfiguration?.timeoutIntervalForResource, TimeInterval(INT_MAX))
    }

    func testStartSessionDataTaskOnStart() {
        sut.start()
        XCTAssertTrue(context.urlSessionMock.dataTaskInvoked)
        XCTAssertTrue(context.urlSessionMock.dataTaskMock.resumeInvoked)
    }

    func testClosedStateOnStop() {
        sut.start()
        sut.stop()
        XCTAssertEqual(state, .closed)
    }

    func testInvalidateAndCancelURLSessionRequestOnStop() {
        sut.start()
        sut.stop()
        XCTAssertTrue(context.urlSessionMock.invalidateAndCancelInvoked)
    }

    func testErrorOnUrlSessionDelegateDidCompleteWithError() {
        sut.start()
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: testUrl) as URLSessionTask
        let error = NSError(domain: "com.test", code: 500, userInfo: nil)
        sut.urlSession(session, task: task, didCompleteWithError: error)
        XCTAssertEqual(state, .closed)
        XCTAssertNotNil(self.error)
    }

    func testOpenStateOnUrlSessionDelegateDidResiveResponse() {
        sut.start()
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: testUrl) as URLSessionDataTask
        let response = URLResponse()
        sut.urlSession(session, dataTask: task, didReceive: response, completionHandler: { _ in })
        XCTAssertEqual(state, .open)
    }

    func testAllowContinueLoadingOnUrlSessionDelegateDidResiveResponse() {
        sut.start()
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: testUrl) as URLSessionDataTask
        let response = URLResponse()
        var responseDisposition: URLSession.ResponseDisposition?
        sut.urlSession(session, dataTask: task, didReceive: response, completionHandler: { disposition in
            responseDisposition = disposition
        })
        XCTAssertEqual(responseDisposition, .allow)
    }

    func testCorrectDataParsingOnUrlSessionDelegateDidResiveData() {
        sut.start()
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: testUrl) as URLSessionDataTask
        let response = URLResponse()
        sut.urlSession(session, dataTask: task, didReceive: response, completionHandler: { _ in })
        let valueString = "[{\"name\":\"Pressure\",\"unit\":\"hPa\",\"measurements\":[],\"_id\":\"58c15afe518ca70001b80345\"}]"
        let dataString = "data: \(valueString)\n\n"
        sut.urlSession(session, dataTask: task, didReceive: dataString.data(using: .utf8)!)
        XCTAssertEqual(data, valueString)
    }
}
