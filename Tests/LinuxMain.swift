#if os(Linux)

import XCTest
@testable import CanaleTests

XCTMain([
    testCase(SocketTests.allTests)
])

#endif
