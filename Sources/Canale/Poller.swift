// Error.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Venice

public enum PollerError: Swift.Error {
    case alreadyPolling
}

class Poller {
    private let channel = try! Channel<Void>()
    private var counter: Int = 0
    private let fd: FileDescriptor.Handle
    private let events: FileDescriptor.PollEvent
    private var pollingCoroutine: Coroutine?
    private var polling = false
    
    init(fd: FileDescriptor.Handle, events: FileDescriptor.PollEvent) {
        self.fd = fd
        self.events = events
    }
    
    private func notifyAll() throws {
        while counter > 0 {
            counter -= 1
            try channel.send(deadline: .never)
        }
    }
    
    private func notifyAll(_ error: Swift.Error) throws {
        while counter > 0 {
            counter -= 1
            try channel.send(error, deadline: .never)
        }
    }
    
    
    func poll(deadline: Deadline) throws {
        
        if !polling {
            pollingCoroutine = try Coroutine {
                defer { self.polling = false }
                
                do {
                    self.polling = true
                    try FileDescriptor.poll(self.fd, event: self.events, deadline: deadline)
                    try self.notifyAll()
                }
                catch {
                    try self.notifyAll(error)
                }
            }
        }
        
        counter += 1
        try channel.receive(deadline: .never)
    }
    
    func shutdown() throws {
        try notifyAll(Error(description: "Unable to poll"))
        pollingCoroutine?.cancel()
        pollingCoroutine = nil
        assert(counter == 0)
        
        try Coroutine.yield()
    }
    
    deinit {
        FileDescriptor.clean(fd)
    }
}
