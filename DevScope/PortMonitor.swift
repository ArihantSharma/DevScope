//
//  PortMonitor.swift
//  DevScope
//
//  Created by Arihant Sharma on 30/10/26.
//

import Foundation
import Combine

@MainActor
final class PortMonitor: ObservableObject {
    @Published private(set) var ports: [PortRecord] = []
    @Published private(set) var isScanning = false
    @Published private(set) var errorMessage: String?

    var conflictingPorts: [Int] {
        let grouped = Dictionary(grouping: ports, by: \.port)

        return grouped.compactMap { port, records in
            let distinctPIDs = Set(records.map(\.pid))
            return distinctPIDs.count > 1 ? port : nil
        }.sorted()
    }

    func refresh() {
        guard !isScanning else { return }

        isScanning = true
        errorMessage = nil

        Task { @MainActor in
            defer { isScanning = false }

            do {
                ports = try PortScannerService.scan()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
