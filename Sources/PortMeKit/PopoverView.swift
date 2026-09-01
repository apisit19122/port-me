import SwiftUI

struct PopoverView: View {
    let model: PortMeModel
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Port me").font(.system(size: 13, weight: .semibold))
            Text(AppVersion.display).font(.system(size: 10)).foregroundStyle(.tertiary)
            Spacer()
            if model.isKilling {
                ProgressView().controlSize(.small)
            } else {
                Text(countLabel).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var countLabel: String {
        let count = model.visibleServers.count
        return count == 1 ? "1 รายการ" : "\(count) รายการ"
    }

    @ViewBuilder private var content: some View {
        if model.visibleServers.isEmpty {
            emptyState
        } else {
            ScrollView {
                DevServerList(servers: model.visibleServers) { server in
                    Task { await model.kill(server) }
                }
            }
            // เพดานความสูงเพื่อไม่ให้ popover ยาวเกินจอเมื่อ port เยอะ
            .frame(maxHeight: 360)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle").font(.system(size: 20)).foregroundStyle(.secondary)
            Text("ไม่มี dev server ถือ port อยู่").font(.system(size: 12)).foregroundStyle(.secondary)
            if model.hiddenAppCount > 0 {
                Text("ซ่อนแอป GUI ไว้ \(model.hiddenAppCount) รายการ")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status = model.status {
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Button("Kill All") { Task { await model.killAll() } }
                    .disabled(model.visibleServers.isEmpty || model.isKilling)
                Spacer()
                Button("Quit", action: onQuit)
            }
            .controlSize(.small)
            Toggle(
                "แสดงแอป GUI ด้วย",
                isOn: Binding(get: { model.showAll }, set: { model.setShowAll($0) })
            )
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            LaunchAtLoginToggle()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct DevServerList: View {
    let servers: [DevServer]
    let onKill: (DevServer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(servers) { server in
                DevServerRow(server: server) { onKill(server) }
                if server.id != servers.last?.id {
                    Divider().padding(.leading, 14)
                }
            }
        }
    }
}

private struct DevServerRow: View {
    let server: DevServer
    let onKill: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(RuntimePalette.color(for: server.name))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                title
                HStack(spacing: 4) {
                    ForEach(server.ports, id: \.self) { PortBadge(port: $0) }
                }
            }
            Spacer(minLength: 8)
            Button("Kill", action: onKill)
                .controlSize(.small)
                .tint(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear)
        .onHover { isHovered = $0 }
    }

    private var title: some View {
        HStack(spacing: 5) {
            Text(server.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            if let folder = server.projectFolder {
                Text("·").foregroundStyle(.tertiary)
                Text(folder).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            if server.kind == .guiApp {
                Text("app")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PortBadge: View {
    let port: UInt16

    var body: some View {
        Text(":\(String(port))")
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

private enum RuntimePalette {
    /// จุดสีช่วยกวาดตาหา runtime ที่ต้องการเจอเร็วกว่าอ่านชื่อทีละแถว
    static func color(for name: String) -> Color {
        let lowercased = name.lowercased()
        if lowercased.contains("bun") { return .pink }
        if lowercased.contains("deno") { return .purple }
        if lowercased.contains("python") { return .yellow }
        if lowercased.contains("ruby") { return .red }
        if lowercased.contains("java") { return .orange }
        if lowercased.contains("node") || lowercased.contains("next") { return .green }
        return .blue
    }
}
