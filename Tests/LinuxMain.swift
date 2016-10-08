#if os(Linux)

import XCTest
@testable import Canale

XCTMain([
    testCase(SocketTests.allTests)
])

#endif
