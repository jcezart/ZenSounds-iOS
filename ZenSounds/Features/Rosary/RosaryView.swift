import SwiftUI

struct RosaryView: View {
    @StateObject private var model = RosaryViewModel()
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var superwall = SuperwallService.shared
    @EnvironmentObject private var navigation: NavigationModel
    /// Starts open; minimizing leaves more room for the prayers (not persisted).
    @State private var isMysteryCardExpanded = true
    @Environment(\.essencePalette) private var palette

    @State private var isSettingsPresented = false
    @ScaledMetric(relativeTo: .subheadline) private var numberSize: CGFloat = 26
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var guidedPlaySize: CGFloat = 58
    @ScaledMetric(relativeTo: .title) private var guidedStopSize: CGFloat = 34

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                mysteryCard
                modePicker
                RosaryDiagram(steps: model.steps, currentIndex: model.currentIndex, onSelectBead: model.go)
                if model.isCompleted {
                    completionCard
                } else {
                    currentMysteryCard
                    currentPrayerCard
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .toolbar(.hidden, for: .navigationBar)
        // Order matters: the ambient row sits above the Previous / Next bead buttons.
        .ambientMiniPlayer(.always)
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .sheet(isPresented: $model.isChoosingSet) { mysteryPicker }
        .sheet(isPresented: $isSettingsPresented) { SettingsView() }
        .alert("Start a new Rosary?", isPresented: $model.showsRestartConfirmation) {
            Button("Cancel", role: .cancel) { model.pendingSet = nil }
            Button("Start new", role: .destructive) { model.confirmSetChange() }
        } message: { Text("Changing the mysteries restarts the current progress.") }
        .onChange(of: languageStore.selection) { model.languageDidChange() }
        .onChange(of: navigation.pendingRosarySet, initial: true) { _, requested in
            // Search → Recent/Mysteries: same set just opens the tab; another set asks before
            // restarting the current progress (requestSet).
            guard let requested else { return }
            navigation.pendingRosarySet = nil
            if requested != model.mysterySetID { model.requestSet(requested) }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Holy Rosary")
                .font(.essenceDisplaySmall)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            SettingsButton { isSettingsPresented = true }
        }
    }

    private var mysteryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Label + actions on one row and the set name on its own, so large text never squeezes it.
            HStack(alignment: .center, spacing: Spacing.xs) {
                Text("Today's Mysteries")
                    .font(.essenceLabelMedium)
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: Spacing.xs)
                Button("Change") { model.isChoosingSet = true }
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isMysteryCardExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                        .rotationEffect(.degrees(isMysteryCardExpanded ? 180 : 0))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(palette.secondaryText)
                .accessibilityLabel(isMysteryCardExpanded ? Text("Hide mysteries") : Text("Show mysteries"))
            }
            .padding(.vertical, -Spacing.xs)
            Text(model.mysterySet.name.text(for: language))
                .font(.scriptureHeadline)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            if isMysteryCardExpanded {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(model.mysterySet.mysteries) { mystery in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            Text("\(mystery.number)")
                                .font(.essenceLabelLarge.monospacedDigit())
                                .foregroundStyle(isCurrent(mystery) ? palette.onAccent : palette.accent)
                                .frame(minWidth: numberSize, minHeight: numberSize)
                                .background(isCurrent(mystery) ? palette.accent : palette.surfaceElevated, in: Circle())
                            Text(mystery.name.text(for: language))
                                .font(.essenceBodyMedium)
                                .foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Divider()
                Toggle("Fatima Prayer", isOn: Binding(get: { model.includeFatimaPrayer }, set: model.toggleFatima))
                    .font(.essenceBodyMedium)
                    .tint(palette.accent)
                if model.hasProgress {
                    Button("Start new") { model.beginNew() }
                        .font(.essenceLabelLarge)
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .padding(Spacing.md)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func isCurrent(_ mystery: RosaryMystery) -> Bool {
        !model.isCompleted && model.currentStep?.mysteryID == mystery.id
    }

    private var modePicker: some View {
        Picker("Prayer mode", selection: Binding(get: { model.mode }, set: setMode)) {
            Text("Manual").tag(RosaryMode.manual)
            Text("Guided").tag(RosaryMode.guided)
        }
        .pickerStyle(.segmented)
        // Segmented pickers can't host custom views, so the lock sits over the trailing ("Guided") segment.
        .overlay(alignment: .trailing) {
            PremiumLockBadge(feature: .guidedRosary)
                .padding(.trailing, 8)
        }
        .accessibilityHint(superwall.premiumGate.shouldShowBadge(for: .guidedRosary) ? Text("Requires Orante+") : Text(verbatim: ""))
    }

    private func setMode(_ mode: RosaryMode) {
        guard mode == .guided else {
            model.setMode(mode)
            return
        }
        SuperwallService.shared.gate(.guidedRosary) {
            model.setMode(mode)
        }
    }

    /// "5º · A Crucificação" (or opening/closing prayers), "Ave-Maria · 5 de 10" and the beads of this part.
    private var currentMysteryCard: some View {
        Group {
            if let step = model.currentStep {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(stageTitle(step))
                        .font(.scriptureHeadline)
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(positionTitle(step))
                        .font(.essenceLabelLarge)
                        .foregroundStyle(palette.secondaryText)
                    RosaryFocusStrip(steps: model.steps, currentIndex: model.currentIndex, language: language, onSelect: model.go)
                        .padding(.horizontal, -Spacing.xs)
                    Text("\(min(model.currentIndex + 1, model.steps.count)) of \(model.steps.count)")
                        .font(.essenceLabelMedium.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                        .accessibilityLabel(progressAccessibility)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var currentPrayerCard: some View {
        Group {
            if let step = model.currentStep {
                Text(model.spokenText(for: step, language: language))
                    .font(.scriptureBody)
                    .lineSpacing(6)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
        }
    }

    private var completionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(palette.accent).accessibilityHidden(true)
            Text("Rosary completed").font(.essenceTitleLarge)
            Button("Pray again") { model.beginNew() }.buttonStyle(.borderedProminent).tint(palette.accent)
        }.padding(22).frame(maxWidth: .infinity).background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var controls: some View {
        Group {
            if model.mode == .guided {
                guidedTransportControls
            } else {
                manualTransportControls
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .background(palette.background)
    }

    private var manualTransportControls: some View {
        // Side by side normally; stacked at accessibility text sizes so the labels are never cut.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            transportButton(
                title: "Previous",
                icon: "chevron.left",
                iconTrailing: false,
                prominent: false,
                disabled: model.currentIndex == 0 || model.isCompleted,
                action: model.previous
            )

            transportButton(
                title: model.currentIndex == model.steps.count - 1 ? "Complete" : "Next bead",
                icon: "chevron.right",
                iconTrailing: true,
                prominent: true,
                disabled: model.isCompleted,
                action: model.next
            )
        }
    }

    private var guidedTransportControls: some View {
        HStack(spacing: 30) {
            Button(action: model.previous) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
            }
            .disabled(model.currentIndex == 0 || model.isCompleted)
            .opacity(model.currentIndex == 0 || model.isCompleted ? 0.35 : 1)
            .accessibilityLabel("Previous")

            Button(action: guidedPrimaryAction) {
                Image(systemName: guidedIcon)
                    .font(.system(size: guidedPlaySize))
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: guidedPlaySize + 10, minHeight: guidedPlaySize + 10)
            }
            .disabled(model.isCompleted)
            .accessibilityLabel(guidedTitle)

            Button(action: model.stopGuided) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: guidedStopSize))
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
            }
            .disabled(model.guided.state == .idle || model.guided.state == .completed)
            .opacity(model.guided.state == .idle || model.guided.state == .completed ? 0.35 : 1)
            .accessibilityLabel("Stop")

            Button(action: model.next) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
            }
            .disabled(model.isCompleted)
            .opacity(model.isCompleted ? 0.35 : 1)
            .accessibilityLabel("Next bead")
        }
        .frame(maxWidth: .infinity)
    }

    private func transportButton(
        title: LocalizedStringKey,
        icon: String,
        iconTrailing: Bool,
        prominent: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                if !iconTrailing { Image(systemName: icon) }
                Text(title)
                if iconTrailing { Image(systemName: icon) }
            }
                .font(.essenceLabelLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(prominent ? palette.onAccent : palette.accent)
                .background(
                    prominent ? palette.accent : palette.surface,
                    in: Capsule()
                )
                .overlay {
                    if !prominent {
                        Capsule().stroke(palette.outline, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var mysteryPicker: some View {
        NavigationStack {
            List(RosaryMysterySetID.allCases) { id in
                Button {
                    model.isChoosingSet = false; model.requestSet(id)
                } label: {
                    HStack {
                        Text(model.repository.mysterySet(id)?.name.text(for: language) ?? id.rawValue)
                        Spacer()
                        if id == MysterySchedule.suggestedSet(for: Date()) { Text("Suggested today").font(.footnote).foregroundStyle(.secondary) }
                        if id == model.mysterySetID { Image(systemName: "checkmark").foregroundStyle(palette.accent) }
                    }
                }.foregroundStyle(palette.text)
            }
            .navigationTitle("Choose Mysteries")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.isChoosingSet = false } } }
        }
    }

    private var language: BibleLanguage { languageStore.selection.bibleLanguage }

    private func guidedPrimaryAction() {
        switch model.guided.state {
        case .idle, .completed:
            SuperwallService.shared.gate(.guidedRosary) {
                model.guidedPrimaryAction(language: language)
            }
        case .preparing, .speaking, .paused:
            model.guidedPrimaryAction(language: language)
        }
    }

    private var guidedTitle: LocalizedStringKey {
        switch model.guided.state { case .speaking, .preparing: "Pause"; case .paused: "Continue"; case .idle, .completed: "Start" }
    }
    private var guidedIcon: String {
        switch model.guided.state {
        case .speaking, .preparing: "pause.circle.fill"
        case .paused, .idle, .completed: "play.circle.fill"
        }
    }
    private func positionTitle(_ step: RosaryStep) -> String {
        let name = RosaryLabels.prayerName(step.prayer, language: language)
        if let position = step.position, let total = step.positionTotal {
            return language == .pt ? "\(name) · \(position) de \(total)" : "\(name) · \(position) of \(total)"
        }
        return name
    }
    private func stageTitle(_ step: RosaryStep) -> String {
        if let mystery = model.repository.mystery(step.mysteryID), let decade = step.decade {
            return "\(decade)º · \(mystery.name.text(for: language))"
        }
        return RosaryLabels.stageName(step.stage, language: language)
    }
    private var progressAccessibility: String {
        let current = model.currentIndex + 1, total = model.steps.count
        return language == .pt ? "Progresso: \(current) de \(total)" : "Progress: \(current) of \(total)"
    }
}

/// Prayer names and bead accessibility text in the Rosary's content language (same pt/en source as the prayer card).
enum RosaryLabels {
    static func prayerName(_ prayer: RosaryPrayerKind, language: BibleLanguage) -> String {
        if language == .pt {
            switch prayer {
            case .signOfCross: return "Sinal da Cruz"
            case .creed: return "Credo dos Apóstolos"
            case .ourFather: return "Pai-Nosso"
            case .hailMary: return "Ave-Maria"
            case .gloryBe: return "Glória ao Pai"
            case .fatima: return "Oração de Fátima"
            case .hailHolyQueen: return "Salve-Rainha"
            case .finalPrayer: return "Oração final"
            case .announcement: return "Meditação do mistério"
            }
        }
        switch prayer {
        case .signOfCross: return "Sign of the Cross"
        case .creed: return "Apostles' Creed"
        case .ourFather: return "Our Father"
        case .hailMary: return "Hail Mary"
        case .gloryBe: return "Glory Be"
        case .fatima: return "Fatima Prayer"
        case .hailHolyQueen: return "Hail Holy Queen"
        case .finalPrayer: return "Final Prayer"
        case .announcement: return "Mystery meditation"
        }
    }

    /// Title of the parts without a mystery (opening and closing prayers).
    static func stageName(_ stage: RosaryStage, language: BibleLanguage) -> String {
        switch stage {
        case .opening: language == .pt ? "Orações iniciais" : "Opening prayers"
        case .closing: language == .pt ? "Orações finais" : "Closing prayers"
        case .decade: language == .pt ? "Dezena" : "Decade"
        }
    }

    /// e.g. "Ave-Maria 4 de 10, dezena 2" / "Hail Mary 4 of 10, decade 2".
    static func beadLabel(for step: RosaryStep?, language: BibleLanguage) -> String {
        guard let step else { return language == .pt ? "Conta" : "Bead" }
        var label = prayerName(step.prayer, language: language)
        if let position = step.position, let total = step.positionTotal {
            label += language == .pt ? " \(position) de \(total)" : " \(position) of \(total)"
        }
        if let decade = step.decade {
            label += language == .pt ? ", dezena \(decade)" : ", decade \(decade)"
        }
        return label
    }

    static func beadStatus(_ progress: RosaryBeadProgress, language: BibleLanguage) -> String {
        switch progress {
        case .current: language == .pt ? "atual" : "current"
        case .completed: language == .pt ? "concluída" : "completed"
        case .pending: language == .pt ? "pendente" : "pending"
        }
    }
}

private struct RosaryDiagram: View {
    let steps: [RosaryStep]
    let currentIndex: Int
    let onSelectBead: (String) -> Void
    @Environment(\.essencePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.34)
                    let cord = palette.secondaryText.opacity(0.35)
                    var path = Path(); path.addEllipse(in: RosaryVisualRules.loopFrame(in: size))
                    context.stroke(path, with: .color(cord), lineWidth: 1.5)

                    var pendant = Path()
                    pendant.move(to: CGPoint(x: center.x, y: size.height * 0.60))
                    pendant.addLine(to: CGPoint(x: center.x, y: size.height * 0.965))
                    context.stroke(pendant, with: .color(cord), lineWidth: 1.5)

                    for (index, beadID) in RosaryVisualRules.loopBeadIDs.enumerated() {
                        drawBead(beadID, at: RosaryVisualRules.loopPoint(at: Double(index), in: size), in: &context)
                    }

                    // Medal: rounded oval with a soft rim.
                    let medal = CGRect(x: center.x - 11, y: size.height * 0.615, width: 22, height: 28)
                    context.fill(Path(ellipseIn: medal), with: .color(color(for: "medal")))
                    context.stroke(Path(ellipseIn: medal.insetBy(dx: 3, dy: 3)), with: .color(palette.background.opacity(0.35)), lineWidth: 1)

                    for (offset, id) in [
                        (0.72, "pendant.large.2"),
                        (0.79, "pendant.small.3"),
                        (0.835, "pendant.small.2"),
                        (0.88, "pendant.small.1"),
                        (0.935, "pendant.large.1")
                    ] {
                        drawBead(id, at: CGPoint(x: center.x, y: size.height * offset), in: &context)
                    }

                    var cross = Path()
                    cross.move(to: CGPoint(x: center.x, y: size.height * 0.962))
                    cross.addLine(to: CGPoint(x: center.x, y: size.height * 0.998))
                    cross.move(to: CGPoint(x: center.x - 8, y: size.height * 0.975))
                    cross.addLine(to: CGPoint(x: center.x + 8, y: size.height * 0.975))
                    context.stroke(cross, with: .color(color(for: "crucifix")), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rosary overview")
                .accessibilityValue("Progress: \(currentIndex + 1) of \(steps.count), decade \(steps[currentIndex].decade ?? 0)")
                ForEach(1...5, id: \.self) { decade in
                    Button { withAnimation(reduceMotion ? nil : .easeInOut) { onSelectBead(decade == 1 ? "pendant.large.2" : "loop.large.\(decade)") } } label: { Color.clear.frame(width: 44, height: 44) }
                        .position(RosaryVisualRules.decadeButtonCenter(decade: decade, in: proxy.size)).accessibilityLabel("Decade \(decade)")
                }
            }
        }.frame(height: 300)
    }
    private func beadState(_ id: String) -> Int {
        switch RosaryVisualRules.progress(for: id, in: steps, currentIndex: currentIndex) {
        case .pending: 0
        case .completed: 1
        case .current: 2
        }
    }
    /// Pending beads use the secondary text color so they stay visible in dark mode; prayed ones are
    /// a muted accent and the current one is solid accent with a halo.
    private func color(for id: String) -> Color {
        switch beadState(id) {
        case 2: palette.accent
        case 1: palette.accent.opacity(0.55)
        default: palette.secondaryText.opacity(0.45)
        }
    }

    private func drawBead(_ id: String, at point: CGPoint, in context: inout GraphicsContext) {
        let radius: CGFloat = id.contains("large") ? 7.5 : 4.8
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color(for: id)))
        if beadState(id) == 2 {
            context.fill(Path(ellipseIn: rect.insetBy(dx: -7, dy: -7)), with: .color(palette.accent.opacity(0.18)))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(palette.accent.opacity(0.55)), lineWidth: 1.5)
        }
    }
}

private struct RosaryFocusStrip: View {
    let steps: [RosaryStep]; let currentIndex: Int; let language: BibleLanguage; let onSelect: (String) -> Void
    @Environment(\.essencePalette) private var palette
    private var beadIDs: [String] {
        let step = steps[currentIndex]
        let relevant = steps.filter { item in
            switch step.stage { case .opening: item.stage == .opening; case .closing: item.stage == .closing; case .decade: item.decade == step.decade }
        }.map(\.beadID)
        return relevant.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(beadIDs, id: \.self) { id in
                    Button { onSelect(id) } label: {
                        Circle().fill(color(id)).frame(width: isLarge(id) ? 24 : 16, height: isLarge(id) ? 24 : 16).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(RosaryLabels.beadLabel(for: steps.first { $0.beadID == id }, language: language))
                    .accessibilityValue(RosaryLabels.beadStatus(RosaryVisualRules.progress(for: id, in: steps, currentIndex: currentIndex), language: language))
                }
            }.padding(.horizontal, 4)
        }.scrollIndicators(.hidden).padding(8).background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func state(_ id: String) -> Int {
        switch RosaryVisualRules.progress(for: id, in: steps, currentIndex: currentIndex) {
        case .pending: 0
        case .completed: 1
        case .current: 2
        }
    }
    private func color(_ id: String) -> Color { state(id)==2 ? palette.accent : state(id)==1 ? palette.accent.opacity(0.55) : palette.secondaryText.opacity(0.45) }
    private func isLarge(_ id: String) -> Bool { id.contains("large") || id == "medal" || id == "crucifix" }
}

#Preview("Rosary") { ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) } }
#Preview("Rosary Dark") { ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) }.preferredColorScheme(.dark) }
#Preview("Rosary Large Text") { ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) }.environment(\.dynamicTypeSize, .accessibility3) }
#Preview("Rosary 375pt", traits: .fixedLayout(width: 375, height: 667)) {
    ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) }
}
#Preview("Rosary 440pt", traits: .fixedLayout(width: 440, height: 956)) {
    ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) }
}
#Preview("Rosary full height", traits: .fixedLayout(width: 402, height: 1700)) {
    ZenSoundsTheme { NavigationStack { RosaryView() }.environmentObject(NavigationModel()) }.preferredColorScheme(.dark)
}
