//
//  PortScanner.swift
//  DevScope
//
//  Created by Arihant Sharma on 30/10/26.
//

import Foundation

struct PortRecord: Identifiable, Sendable {
    nonisolated let pid: Int
    nonisolated let processName: String
    nonisolated let port: Int
    nonisolated let address: String

    nonisolated var id: String {
        "\(pid)-\(port)-\(address)"
    }
}

enum PortScannerService {
    nonisolated static func scan() throws -> [PortRecord] {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = [
            "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 || !outputData.isEmpty else {
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw NSError(
                domain: "DevScope.PortScanner",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        message.isEmpty ? "Port scan failed." : message
                ]
            )
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw NSError(
                domain: "DevScope.PortScanner",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not read scanner output."
                ]
            )
        }

        var records: [PortRecord] = []
        var currentPID: Int?
        var currentName = ""

        for line in output.split(whereSeparator: \.isNewline) {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int(value)
                currentName = ""

            case "c":
                currentName = value

            case "n":
                guard let pid = currentPID, !currentName.isEmpty else {
                    continue
                }

                // Extract the final numeric port from the endpoint.
                guard let match = value.range(
                    of: #":(\d+)$"#,
                    options: .regularExpression
                ) else {
                    continue
                }

                let portText = value[match].dropFirst()
                guard let port = Int(portText) else { continue }

                let address = String(value[..<match.lowerBound])

                records.append(
                    PortRecord(
                        pid: pid,
                        processName: currentName,
                        port: port,
                        address: address
                    )
                )

            default:
                continue
            }
        }

        var uniqueRecords: [String: PortRecord] = [:]

        for record in records {
            uniqueRecords[record.id] = record
        }

        return uniqueRecords.values.sorted {
            if $0.port != $1.port {
                return $0.port < $1.port
            }

            return $0.processName.localizedCaseInsensitiveCompare(
                $1.processName
            ) == .orderedAscending
        }
    }
}
