//
//  ProcessMonitor.swift
//  DevScope
//
//  Created by Arihant Sharma on 30/10/26.
//

import Foundation
import Combine
import Darwin

@MainActor
final class ProcessMonitor: ObservableObject {
    @Published private(set) var processes: [ProcessRecord] = []
    @Published private(set) var cpuPercentages: [Int: Double] = [:]
    
    @Published private(set) var systemCPUUsage: Double = 0
    @Published private(set) var usedMemoryBytes: UInt64 = 0
    @Published private(set) var totalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory

    private var previousCPUTime: [Int: UInt64] = [:]
    private var previousSampleTime: TimeInterval?
    
    private var previousSystemCPUTicks: [UInt32] = []
    
    private func updateSystemCPUUsage() {
        var cpuInfo: processor_info_array_t?
        var processorCount: natural_t = 0
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let ticksPerCPU = Int(CPU_STATE_MAX)
        var currentTicks: [UInt32] = []

        for processor in 0..<Int(processorCount) {
            let offset = processor * ticksPerCPU

            currentTicks.append(contentsOf: [
                UInt32(cpuInfo[offset + Int(CPU_STATE_USER)]),
                UInt32(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                UInt32(cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                UInt32(cpuInfo[offset + Int(CPU_STATE_NICE)])
            ])
        }

        guard !previousSystemCPUTicks.isEmpty,
              previousSystemCPUTicks.count == currentTicks.count else {
            previousSystemCPUTicks = currentTicks
            return
        }

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for index in stride(from: 0, to: currentTicks.count, by: ticksPerCPU) {
            let user = currentTicks[index] &- previousSystemCPUTicks[index]
            let system = currentTicks[index + 1] &- previousSystemCPUTicks[index + 1]
            let idle = currentTicks[index + 2] &- previousSystemCPUTicks[index + 2]
            let nice = currentTicks[index + 3] &- previousSystemCPUTicks[index + 3]

            totalTicks += UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice)
            idleTicks += UInt64(idle)
        }

        if totalTicks > 0 {
            systemCPUUsage = Double(totalTicks - idleTicks) / Double(totalTicks) * 100
        }

        previousSystemCPUTicks = currentTicks
    }
    
    private func updateSystemMemoryUsage() {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size /
            MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &statistics) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return
        }

        let pageSize = UInt64(vm_kernel_page_size)

        let active = UInt64(statistics.active_count)
        let wired = UInt64(statistics.wire_count)
        let compressed = UInt64(statistics.compressor_page_count)

        usedMemoryBytes = (active + wired + compressed) * pageSize
        totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    }

    func refresh() {
        do {
            let newProcesses = try ProcessScannerService.scan()
            updateSystemCPUUsage()
            updateSystemMemoryUsage()
            let now = ProcessInfo.processInfo.systemUptime

            guard let previousTime = previousSampleTime else {
                previousCPUTime = Dictionary(
                    uniqueKeysWithValues: newProcesses.map {
                        ($0.pid, $0.cpuTimeNanoseconds)
                    }
                )
                previousSampleTime = now
                processes = newProcesses
                return
            }

            let elapsedNanoseconds = (now - previousTime) * 1_000_000_000

            var newPercentages: [Int: Double] = [:]
            var newPreviousCPUTime: [Int: UInt64] = [:]

            for process in newProcesses {
                let currentCPU = process.cpuTimeNanoseconds

                if let previousCPU = previousCPUTime[process.pid],
                   currentCPU >= previousCPU,
                   elapsedNanoseconds > 0 {
                    let difference = currentCPU - previousCPU

                    newPercentages[process.pid] =
                        Double(difference) / elapsedNanoseconds * 100
                } else {
                    newPercentages[process.pid] = 0
                }

                newPreviousCPUTime[process.pid] = currentCPU
            }

            processes = newProcesses
            cpuPercentages = newPercentages
            previousCPUTime = newPreviousCPUTime
            previousSampleTime = now

        } catch {
            print("Process monitoring failed: \(error)")
        }
    }
}
