//
//  main.swift
//  PrivilegedHelper
//
//  Main entry point for the privileged helper daemon.
//  Runs as root and handles privileged operations via XPC.
//

import Foundation
import Logging
import Shared

let mainLogger = Logger(label: "com.surge.helper")

mainLogger.info("PrivilegedHelper starting", metadata: [
    "version": .string(XPCConstants.version),
    "pid": .stringConvertible(getpid())
])

// Create and run the XPC listener
let delegate = HelperXPCDelegate()
let listener = NSXPCListener(machServiceName: XPCConstants.helperMachServiceName)
listener.delegate = delegate

mainLogger.info("Starting XPC listener", metadata: [
    "serviceName": .string(XPCConstants.helperMachServiceName)
])

listener.resume()

// Keep the helper running
RunLoop.current.run()
