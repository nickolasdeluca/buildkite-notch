import AppKit
import BuildkiteNotchCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var draftToken = ""
    @State private var accessToken: AccessToken?
    @State private var failure: Failure?
    @State private var isLoading = false
    @State private var organizations: [Organization] = []
    @State private var pipelines: [Pipeline] = []
    @State private var search = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private static let requiredScopes = ["read_builds", "read_pipelines", "read_organizations"]

    /// Kept raw so the message follows a language change.
    private enum Failure {
        case api(any Error)
        case loginItem(any Error)
    }

    private var strings: any Strings { settings.strings }

    var body: some View {
        Form {
            accountSection
            pipelinesSection
            placementSection
            appearanceSection
            updatesSection
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
                Button(strings.connect) { Task { await connect() } }
                    .disabled(draftToken.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                if !settings.token.isEmpty {
                    Button(strings.disconnect, role: .destructive, action: disconnect)
                }
            }
            if let accessToken {
                Text(strings.connected(
                    as: accessToken.user?.name ?? accessToken.user?.email,
                    missingScopes: Self.requiredScopes.filter { !accessToken.scopes.contains($0) }
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let failure {
                Text(message(for: failure)).font(.caption).foregroundStyle(.red)
            }
            if !organizations.isEmpty {
                Picker(strings.organization, selection: organizationBinding) {
                    ForEach(organizations) { Text($0.name).tag($0.slug) }
                }
            }
        } header: {
            Text(strings.account)
        } footer: {
            Text(strings.tokenHelp(scopes: Self.requiredScopes.joined(separator: ", ")))
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
                Text(settings.organization.isEmpty ? strings.connectToListPipelines : strings.noPipelinesLoaded)
                    .foregroundStyle(.secondary)
            } else {
                if pipelines.count > Self.searchThreshold {
                    TextField(strings.search, text: $search)
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
            TextField(strings.branches, text: $settings.branchFilter, prompt: Text(verbatim: "main, production"))
        } header: {
            Text(strings.pipelinesHeader(selected: settings.pipelines.count))
        } footer: {
            Text(strings.branchesHelp)
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
            Picker(strings.edge, selection: $settings.placement.edge) {
                ForEach(ScreenEdge.allCases, id: \.self) { Text(strings.name(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Slider(value: $settings.placement.position, in: 0...1) { Text(strings.position) }
                Button(strings.center) { settings.placement.position = 0.5 }
            }
            if NSScreen.screens.count > 1 {
                Picker(strings.display, selection: $settings.placement.displayID) {
                    Text(strings.mainDisplay).tag(UInt32?.none)
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
            }
        } header: {
            Text(strings.notchPosition)
        } footer: {
            Text(strings.dragHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(strings.appearance) {
            Picker(strings.notchStyle, selection: $settings.notchStyle) {
                ForEach(NotchStyle.allCases) { Text(strings.name(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        Section {
            intervalRow(strings.whileBuildsRun, seconds: $settings.activePollInterval)
            intervalRow(strings.whenIdle, seconds: $settings.idlePollInterval)
        } header: {
            Text(strings.refreshInterval)
        } footer: {
            Text(strings.pollIntervalHelp(range: PollInterval.range))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func intervalRow(_ title: String, seconds: Binding<Int>) -> some View {
        let clamped = Binding { seconds.wrappedValue } set: { seconds.wrappedValue = PollInterval.clamped($0) }
        return LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: clamped, format: .number.grouping(.never))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                Text(strings.secondsUnit)
                Stepper(title, value: clamped, in: PollInterval.range, step: 5)
                    .labelsHidden()
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Picker(strings.language, selection: $settings.language) {
                Text(strings.systemLanguage).tag(Language?.none)
                ForEach(Language.allCases) { Text(verbatim: $0.nativeName).tag(Language?.some($0)) }
            }
            Toggle(strings.notifyWhenFinished, isOn: $settings.notificationsEnabled)
            Toggle(strings.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        failure = .loginItem(error)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        } header: {
            Text(strings.general)
        } footer: {
            Text(strings.languageHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func message(for failure: Failure) -> String {
        switch failure {
        case .api(let error): strings.message(for: error)
        case .loginItem(let error): strings.loginItemFailed(error.localizedDescription)
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
        accessToken = nil
        failure = nil
    }

    private func loadAccount() async {
        isLoading = true
        failure = nil
        defer { isLoading = false }
        let client = BuildkiteClient(token: settings.token)
        do {
            accessToken = try await client.accessToken()

            organizations = try await client.organizations().sorted { $0.name < $1.name }
            if !organizations.contains(where: { $0.slug == settings.organization }), let first = organizations.first {
                settings.organization = first.slug
                settings.organizationName = first.name
            }
            await loadPipelines()
        } catch {
            failure = .api(error)
        }
    }

    private func loadPipelines() async {
        guard !settings.organization.isEmpty else { return }
        do {
            pipelines = try await BuildkiteClient(token: settings.token)
                .pipelines(organization: settings.organization)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            failure = .api(error)
        }
    }
}
