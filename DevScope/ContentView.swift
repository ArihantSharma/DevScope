//
//  ContentView.swift
//  DevScope
//
//  Created by Arihant Sharma on 30/10/26.
//


import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case ports = "Ports"
    case processes = "Processes"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .ports: return "network"
        case .processes: return "cpu"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: AppSection? = .overview
    @StateObject private var monitor = ProcessMonitor()
    @StateObject private var portMonitor = PortMonitor()
    
    @AppStorage("appAppearance") private var appAppearance = "system"
    @AppStorage("refreshInterval") private var refreshInterval = 1

    var body: some View {
        
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text("WORKSPACE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 12)

                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                selection == section
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(
                                selection == section
                                    ? Color.accentColor
                                    : Color.primary
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 190, maxHeight: .infinity)
            .navigationTitle("DevScope")
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    OverviewView(monitor: monitor, portMonitor: portMonitor)
                case .ports:
                    PortInspectorView(portMonitor: portMonitor)
                case .processes:
                    ProcessInspectorView(monitor: monitor)
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .preferredColorScheme(
            appAppearance == "light" ? .light :
            appAppearance == "dark" ? .dark : nil
        )
        .navigationSplitViewStyle(.balanced)
        .task {
            monitor.refresh()
            portMonitor.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(
                            for: .seconds(Int64(refreshInterval))
                        )

                guard !Task.isCancelled else { break }

                monitor.refresh()
            }
        }
        .frame(minWidth: 760, minHeight: 500)
    }
}

struct OverviewView: View {
    @ObservedObject var monitor: ProcessMonitor
    @ObservedObject var portMonitor: PortMonitor
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overview")
                        .font(.largeTitle.bold())

                    Text("Your local development environment")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    MetricCard(
                        title: "Active Ports",
                        value: "\(portMonitor.ports.count)",
                        subtitle: "Listening TCP entries",
                        symbol: "network"
                    )

                    MetricCard(
                        title: "Running Processes",
                        value: "\(monitor.processes.count)",
                        subtitle: "Currently detected",
                        symbol: "cpu"
                    )

                    MetricCard(
                        title: "Port Conflicts",
                        value: "\(portMonitor.conflictingPorts.count)",
                        subtitle: "Ports used by multiple processes",
                        symbol: "exclamationmark.triangle"
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    Label("Get started", systemImage: "terminal")
                        .font(.title3.bold())

                    Text("Inspect the services running on your Mac, find which processes own ports, and diagnose development server conflicts.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        // The real scanner will be connected next.
                    } label: {
                        Label("Port Inspector", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)

                    Text("Port scanning is the next feature to implement.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}


struct SettingsView: View {
    @AppStorage("appAppearance") private var appAppearance = "system"
    @AppStorage("refreshInterval") private var refreshInterval = 1

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appAppearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Monitoring") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }

                Text("Controls how frequently process and port information is refreshed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Local monitoring", systemImage: "lock.shield")

                Text("DevScope inspects processes and listening ports locally on this Mac. It does not upload monitoring data to a remote server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Application", value: "DevScope")
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Build", value: "Prototype")
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: 750, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }
}


#Preview {
    ContentView()
}

struct PortInspectorView: View {
    @ObservedObject var portMonitor: PortMonitor
    
    @State private var searchText = ""
    @State private var sortBy = SortOption.port
    @State private var selectedProcess: PortRecord?
    @State private var processToInspect: PortRecord?

    private enum SortOption: String, CaseIterable, Identifiable {
        case port = "Port"
        case process = "Process"
        case pid = "PID"

        var id: String { rawValue }
    }

    private var filteredPorts: [PortRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = portMonitor.ports.filter { record in
            guard !query.isEmpty else { return true }

            return record.processName.localizedCaseInsensitiveContains(query)
                || String(record.port).contains(query)
                || String(record.pid).contains(query)
                || record.address.localizedCaseInsensitiveContains(query)
        }

        return filtered.sorted { first, second in
            switch sortBy {
            case .port:
                if first.port != second.port {
                    return first.port < second.port
                }
                return first.processName.localizedCaseInsensitiveCompare(
                    second.processName
                ) == .orderedAscending

            case .process:
                let comparison = first.processName.localizedCaseInsensitiveCompare(
                    second.processName
                )
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return first.port < second.port

            case .pid:
                if first.pid != second.pid {
                    return first.pid < second.pid
                }
                return first.port < second.port
            }
        }
    }
    
    
    private var portSelection: Binding<String?> {
        Binding(
            get: {
                selectedProcess?.id
            },
            set: { selectedID in
                guard let selectedID else {
                    selectedProcess = nil
                    return
                }

                selectedProcess = filteredPorts.first {
                    $0.id == selectedID
                }
            }
        )
    }




    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Port Inspector")
                        .font(.largeTitle.bold())

                    Text("\(filteredPorts.count) of \(portMonitor.ports.count) listening entries")
                        .foregroundStyle(.secondary)
                }

                Spacer()
                
                Button("Inspect Process") {
                    guard let selectedProcess else { return }
                    showProcessDetails(for: selectedProcess)
                }
                .disabled(selectedProcess == nil)

                Button {
                    portMonitor.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(portMonitor.isScanning)
            }

            HStack(spacing: 12) {
                
                if !portMonitor.conflictingPorts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "\(portMonitor.conflictingPorts.count) port conflict(s) detected",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.orange)

                        ForEach(portMonitor.conflictingPorts, id: \.self) { port in
                            Button {
                                searchText = String(port)
                            } label: {
                                HStack {
                                    Text("Port \(port)")
                                    Spacer()
                                    Text("Inspect processes")
                                    Image(systemName: "chevron.right")
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                TextField("Search ports, processes, PIDs…", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 130)
            }

            if let errorMessage = portMonitor.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if portMonitor.isScanning {
                ProgressView("Scanning listening ports…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPorts.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Listening Ports" : "No Matches",
                    systemImage: searchText.isEmpty
                        ? "network.slash"
                        : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "No listening TCP ports were found."
                            : "Try another process name, port, PID, or address."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                
                
                Table(filteredPorts, selection: portSelection) {
                    TableColumn("Port") { record in
                        Text(String(record.port))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 65, ideal: 80)

                    TableColumn("Process") { record in
                        Text(record.processName)
                            .lineLimit(1)
                            .help(record.processName)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("PID") { record in
                        Text(String(record.pid))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 65, ideal: 80)

                    TableColumn("Address") { record in
                        Text(record.address)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .help(record.address)
                    }
                }
                .contextMenu {
                    Button("Inspect Process") {
                        if let selectedProcess {
                            showProcessDetails(for: selectedProcess)
                        }
                    }
                }


            }
        }
        .padding(24)
        .task {
            portMonitor.refresh()
        }
        
        .sheet(item: $processToInspect) { record in
            ProcessDetailView(record: record, allPorts: portMonitor.ports)
        }

    }
    
    private func showProcessDetails(for record: PortRecord) {
        processToInspect = record
    }
    
    
    

}



struct ProcessDetailView: View {
    let record: PortRecord
    let allPorts: [PortRecord]
    @Environment(\.dismiss) private var dismiss

    private var processPorts: [PortRecord] {
        allPorts
            .filter { $0.pid == record.pid }
            .sorted { $0.port < $1.port }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "terminal")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.processName)
                        .font(.title.bold())

                    Text("Process ID: \(record.pid)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Copy PID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        String(record.pid),
                        forType: .string
                    )
                }
                
                Button("Close") {
                    dismiss()
                }
            }

            Divider()

            Text("Listening Ports")
                .font(.headline)

            if processPorts.isEmpty {
                Text("No listening ports found for this process.")
                    .foregroundStyle(.secondary)
            } else {
                Table(processPorts) {
                    TableColumn("Port") { port in
                        Text(String(port.port))
                            .font(.system(.body, design: .monospaced))
                    }

                    TableColumn("Address") { port in
                        Text(port.address)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
    }
}




struct ProcessInspectorView: View {
    @ObservedObject var monitor: ProcessMonitor
    
    @State private var isMonitoring = true
    @State private var searchText = ""
    @State private var sortBy = SortOption.name
    @State private var selectedProcess: ProcessRecord?
    @State private var processToInspect: ProcessRecord?
    @State private var isScanning = false
    @State private var errorMessage: String?


    private enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case pid = "PID"
        case parentPID = "Parent PID"
        case cpu = "CPU Usage"
        case memory = "Memory"

        var id: String { rawValue }
    }

    private var filteredProcesses: [ProcessRecord] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var result = monitor.processes.filter { process in
            query.isEmpty
                || process.name.localizedCaseInsensitiveContains(query)
                || String(process.pid).contains(query)
                || String(process.parentPID).contains(query)
        }

        switch sortBy {
        case .name:
            result.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
        case .pid:
            result.sort { $0.pid < $1.pid }
        case .parentPID:
            result.sort { $0.parentPID < $1.parentPID }
        case .cpu:
            result.sort {
                (monitor.cpuPercentages[$0.pid] ?? 0) >
                (monitor.cpuPercentages[$1.pid] ?? 0)
            }
        case .memory:
            result.sort {
                $0.memoryBytes > $1.memoryBytes
            }
        }
        

        return result
    }

    private var processSelection: Binding<Int?> {
        Binding(
            get: { selectedProcess?.pid },
            set: { selectedPID in
                guard let selectedPID else {
                    selectedProcess = nil
                    return
                }

                selectedProcess = filteredProcesses.first {
                    $0.pid == selectedPID
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Process Inspector")
                        .font(.largeTitle.bold())

                    Text("\(filteredProcesses.count) of \(monitor.processes.count) processes")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Inspect Process") {
                    if let selectedProcess {
                        processToInspect = selectedProcess
                    }
                }
                .disabled(selectedProcess == nil)

                Button {
                    monitor.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                
                Button(isMonitoring ? "Pause" : "Resume") {
                    isMonitoring.toggle()
                }
            }
            
            HStack(spacing: 14) {
                MetricCard(
                    title: "System CPU",
                    value: String(format: "%.1f%%", monitor.systemCPUUsage),
                    subtitle: "Overall processor usage",
                    symbol: "cpu"
                )

                MetricCard(
                    title: "Memory Used",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(monitor.usedMemoryBytes),
                        countStyle: .memory
                    ),
                    subtitle: String(
                        format: "%.1f%% of RAM",
                        Double(monitor.usedMemoryBytes) /
                        Double(max(monitor.totalMemoryBytes, 1)) * 100
                    ),
                    symbol: "memorychip"
                )
            }

            HStack {
                TextField(
                    "Search process name, PID or parent PID…",
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)

                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 150)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if isScanning && monitor.processes.isEmpty {
                ProgressView("Scanning processes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredProcesses.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Processes" : "No Matches",
                    systemImage: "cpu",
                    description: Text(
                        searchText.isEmpty
                            ? "No accessible processes were found."
                            : "Try another process name or PID."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredProcesses, selection: processSelection) {
                    TableColumn("Process") { process in
                        Text(process.name)
                            .lineLimit(1)
                            .help(process.name)
                    }
                    .width(min: 130, ideal: 200)

                    TableColumn("PID") { process in
                        Text(String(process.pid))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 70, ideal: 85)

                    TableColumn("Parent PID") { process in
                        Text(String(process.parentPID))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("User ID") { process in
                        Text(String(process.userID))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("Memory") { process in
                        Text(ByteCountFormatter.string(
                            fromByteCount: Int64(process.memoryBytes),
                            countStyle: .memory
                        ))
                    }

                    TableColumn("CPU") { process in
                        Text(
                            String(
                                format: "%.1f%%",
                                monitor.cpuPercentages[process.pid] ?? 0
                            )
                        )
                        .monospacedDigit()
                    }
                }
            }
        }
        .padding(24)
        .task {
            monitor.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))

                guard !Task.isCancelled else { break }

                if isMonitoring {
                    monitor.refresh()
                }
            }
        }
        .sheet(item: $processToInspect) { process in
            ProcessInfoDetailView(process: process)
        }
    }
    
    private func formatCPUTime(_ nanoseconds: UInt64) -> String {
        let seconds = Double(nanoseconds) / 1_000_000_000

        if seconds < 60 {
            return String(format: "%.2fs", seconds)
        }

        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)

        return String(format: "%dm %.1fs", minutes, remainingSeconds)
    }

    
}


struct ProcessInfoDetailView: View {
    let process: ProcessRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "cpu")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name)
                        .font(.title.bold())

                    Text("Process ID: \(process.pid)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
            }

            Divider()

            Text("Process Information")
                .font(.headline)

            LabeledContent("Process Name", value: process.name)
            LabeledContent("Process ID", value: String(process.pid))
            LabeledContent("Parent PID", value: String(process.parentPID))
            LabeledContent("User ID", value: String(process.userID))

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 300)
    }
}
