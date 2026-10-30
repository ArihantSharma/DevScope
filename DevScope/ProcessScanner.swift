//
//  ProcessScanner.swift
//  DevScope
//
//  Created by Arihant Sharma on 30/10/26.
//

import Foundation
import Darwin

struct ProcessRecord: Identifiable, Sendable {
    let pid: Int
    let name: String
    let parentPID: Int
    let userID: UInt32

    // Cumulative CPU time in nanoseconds
    let cpuTimeNanoseconds: UInt64

    // Current resident memory in bytes
    let memoryBytes: UInt64

    var id: Int { pid }
}

enum ProcessScannerService {

    static func scan() throws -> [ProcessRecord] {
        let bufferSize = Int(
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                nil,
                0
            )
        )

        guard bufferSize > 0 else {
            throw NSError(
                domain: "DevScope.ProcessScanner",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to retrieve process list."
                ]
            )
        }

        let capacity = bufferSize + 1024

        var pids = [pid_t](
            repeating: 0,
            count: capacity
        )

        let bytesWritten = pids.withUnsafeMutableBufferPointer {
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                $0.baseAddress,
                Int32($0.count * MemoryLayout<pid_t>.size)
            )
        }

        guard bytesWritten > 0 else {
            throw NSError(
                domain: "DevScope.ProcessScanner",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to read process IDs."
                ]
            )
        }

        let count = Int(bytesWritten) / MemoryLayout<pid_t>.size
        var records: [ProcessRecord] = []

        for pid in pids.prefix(count) where pid > 0 {
            var info = proc_bsdinfo()

            let infoSize = proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                &info,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )

            guard infoSize == MemoryLayout<proc_bsdinfo>.size else {
                continue
            }

            let nameBytes = withUnsafeBytes(of: info.pbi_name) {
                Array($0)
            }

            let nameLength = nameBytes.firstIndex(of: 0) ?? nameBytes.count

            let name = String(
                decoding: nameBytes[..<nameLength],
                as: UTF8.self
            )

            // Retrieve CPU and memory information.
            var taskInfo = proc_taskinfo()

            let taskInfoSize = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &taskInfo,
                Int32(MemoryLayout<proc_taskinfo>.size)
            )

            var cpuTime: UInt64 = 0
            var memory: UInt64 = 0

            if taskInfoSize == MemoryLayout<proc_taskinfo>.size {
                cpuTime = taskInfo.pti_total_user
                    + taskInfo.pti_total_system

                memory = taskInfo.pti_resident_size
            }

            records.append(
                ProcessRecord(
                    pid: Int(pid),
                    name: name,
                    parentPID: Int(info.pbi_ppid),
                    userID: info.pbi_uid,
                    cpuTimeNanoseconds: cpuTime,
                    memoryBytes: memory
                )
            )
        }

        return records.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }
    }
}
