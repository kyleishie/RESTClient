import XCTest

import RESTClientTests

var tests = [XCTestCaseEntry]()
tests += RESTClientTests.allTests()
XCTMain(tests)