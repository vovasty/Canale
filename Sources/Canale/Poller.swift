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
import CLibvenice

class Poller {
    private let channel = FallibleChannel<Void>()
    private var counter: Int = 0
    private let fd: Int32
    private let events: Venice.PollEvent
    private var polling = false
    
    init(fd: Int32, events: Venice.PollEvent) {
        self.fd = fd
        self.events = events
    }
    
    private func notifyAll() {
        while counter > 0 {
            counter -= 1
            channel.send()
        }
    }
    
    private func notifyAll(_ error: Error) {
        while counter > 0 {
            counter -= 1
            channel.send(error)
        }
    }
    
    
    func poll() throws {
        if !polling {
            co {
                do {
                    self.polling = true
                    let ev = try Venice.poll(self.fd, events: self.events, deadline: -1)
                    self.polling = false
                    
                    guard ev.contains(self.events) else {
                        self.notifyAll(ZeroMqError(description: "Unable to poll"))
                        return
                    }
                    
                    self.notifyAll()
                }
                catch {
                    self.notifyAll(error)
                    return
                }
            }
        }
        
        counter += 1
        try channel.receive()
    }
    
    func shutdown() {
        notifyAll(ZeroMqError(description: "Unable to poll"))
        
        assert(!polling)
        assert(counter == 0)
        
        yield
    }
    
    deinit {
        fdclean(fd)
    }
}
