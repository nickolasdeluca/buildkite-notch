import AppKit
import BuildkiteNotchCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var draftToken = ""
    @State private var tokenStatus: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var organizations: [Organization] = []
    @State private var pipelines: [Pipeline] = []
    @State private var search = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private static let requiredScopes = ["read_builds", "read_pipelines", "read_organizations"]

    var body: some View {
        Form {
            accountSection
            pipelinesSection
            placementSection
            appearanceSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 680)
        .task {
            draftToken = settings.token
            if !settings.token.isEmpty { await loadAccount() }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            SecureField("API Access Token", text: $draftToken)
                .onSubmit { Task { await connect() } }
            HStack {
                Button("Conectar") { Task { await connect() } }
                    .disabled(draftToken.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                if !settings.token.isEmpty {
                    Button("Desconectar", role: .destructive, action: disconnect)
                }
            }
            if let tokenStatus {
                Text(tokenStatus).font(.caption).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            if !organizations.isEmpty {
                Picker("Organização", selection: organizationBinding) {
                    ForEach(organizations) { Text($0.name).tag($0.slug) }
                }
            }
        } header: {
            Text("Conta")
        } footer: {
            Text("Crie um token em buildkite.com/user/api-access-tokens com os escopos \(Self.requiredScopes.joined(separator: ", ")).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var organizationBinding: Binding<String> {
        Binding {
            settings.organization
        } set: { slug in
            guard slug != settings.organization else { return }
            settings.organization = slug
            settings.organizationName = organizations.first { $0.slug == slug }?.name ?? slug
            settings.pipelines = []
            Task { await loadPipelines() }
        }
    }

    // MARK: - Pipelines

    private var filteredPipelines: [Pipeline] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return pipelines }
        return pipelines.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.slug.localizedCaseInsensitiveContains(query)
        }
    }

    private var pipelinesSection: some View {
        Section {
            if pipelines.isEmpty {
                Text(settings.organization.isEmpty ? "Conecte uma conta para listar os pipelines." : "Nenhum pipeline carregado.")
                    .foregroundStyle(.secondary)
            } else {
                if pipelines.count > Self.searchThreshold {
                    TextField("Buscar", text: $search)
                }
                if filteredPipelines.count > Self.maxInlineRows {
                    ScrollView {
                        VStack(spacing: 0) { pipelineRows }
                    }
                    .frame(height: CGFloat(Self.maxInlineRows) * 44)
                } else {
                    pipelineRows
                }
            }
            TextField("Branches", text: $settings.branchFilter, prompt: Text("main, production"))
        } header: {
            Text("Pipelines (\(settings.pipelines.count) selecionados)")
        } footer: {
            Text("Branches separadas por vírgula. Vazio acompanha todas as branches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Show the search field only when the list is long enough to need it.
    private static let searchThreshold = 6
    /// Beyond this many rows the list scrolls instead of growing the form.
    private static let maxInlineRows = 8

    @ViewBuilder
    private var pipelineRows: some View {
        ForEach(filteredPipelines) { pipeline in
            Toggle(isOn: selectionBinding(for: pipeline)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(pipeline.name)
                    if pipeline.slug != pipeline.name {
                        Text(pipeline.slug).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.vertical, filteredPipelines.count > Self.maxInlineRows ? 4 : 0)
        }
    }

    private func selectionBinding(for pipeline: Pipeline) -> Binding<Bool> {
        Binding {
            settings.pipelines.contains { $0.slug == pipeline.slug }
        } set: { selected in
            if selected {
                settings.pipelines.append(PipelineSelection(slug: pipeline.slug, name: pipeline.name))
            } else {
                settings.pipelines.removeAll { $0.slug == pipeline.slug }
            }
        }
    }

    // MARK: - Placement

    private var placementSection: some View {
        Section {
            Picker("Borda", selection: $settings.placement.edge) {
                Text("Topo").tag(ScreenEdge.top)
                Text("Base").tag(ScreenEdge.bottom)
                Text("Esquerda").tag(ScreenEdge.left)
                Text("Direita").tag(ScreenEdge.right)
            }
            .pickerStyle(.segmented)
            HStack {
                Slider(value: $settings.placement.position, in: 0...1) { Text("Posição") }
                Button("Centralizar") { settings.placement.position = 0.5 }
            }
            if NSScreen.screens.count > 1 {
                Picker("Tela", selection: $settings.placement.displayID) {
                    Text("Principal").tag(UInt32?.none)
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
            }
        } header: {
            Text("Posição do notch")
        } footer: {
            Text("Dica: segure ⌥ Option sobre o notch e arraste para movê-lo para qualquer borda.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Aparência") {
            Picker("Estilo do notch", selection: $settings.notchStyle) {
                ForEach(NotchStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("Geral") {
            Toggle("Notificar quando builds terminarem", isOn: $settings.notificationsEnabled)
            Toggle("Abrir ao iniciar sessão", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        errorMessage = "Não foi possível alterar o login: \(error.localizedDescription)"
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
    }

    // MARK: - Actions

    private func connect() async {
        let token = draftToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        if token != settings.token {
            settings.token = token
            settings.pipelines = []
        }
        await loadAccount()
    }

    private func disconnect() {
        settings.token = ""
        settings.organization = ""
        settings.organizationName = ""
        settings.pipelines = []
        draftToken = ""
        organizations = []
        pipelines = []
        tokenStatus = nil
        errorMessage = nil
    }

    private func loadAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let client = BuildkiteClient(token: settings.token)
        do {
            let info = try await client.accessToken()
            let missing = Self.requiredScopes.filter { !info.scopes.contains($0) }
            let who = info.user?.name ?? info.user?.email ?? "token válido"
            tokenStatus = missing.isEmpty
                ? "Conectado: \(who)"
                : "Conectado: \(who). Faltam escopos: \(missing.joined(separator: ", "))"

            organizations = try await client.organizations().sorted { $0.name < $1.name }
            if !organizations.contains(where: { $0.slug == settings.organization }), let first = organizations.first {
                settings.organization = first.slug
                settings.organizationName = first.name
            }
            await loadPipelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPipelines() async {
        guard !settings.organization.isEmpty else { return }
        do {
            pipelines = try await BuildkiteClient(token: settings.token)
                .pipelines(organization: settings.organization)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
