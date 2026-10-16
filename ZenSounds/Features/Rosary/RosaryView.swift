import SwiftUI

struct RosaryView: View {
    @StateObject private var model = RosaryViewModel()
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var superwall = SuperwallService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    mysteryCard
                    modePicker
                    RosaryDiagram(steps: model.steps, currentIndex: model.currentIndex, onSelectBead: model.go)
                    RosaryFocusStrip(steps: model.steps, currentIndex: model.currentIndex, language: language, onSelect: model.go)
                    if model.isCompleted { completionCard } else { currentPrayerCard }
                    Text("\(min(model.currentIndex + 1, model.steps.count)) of \(model.steps.count)")
                        .font(.essenceLabelLarge).foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(progressAccessibility)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { controls }
        .ambientMiniPlayer(.always)
        .sheet(isPresented: $model.isChoosingSet) { mysteryPicker }
        .alert("Start a new Rosary?", isPresented: $model.showsRestartConfirmation) {
            Button("Cancel", role: .cancel) { model.pendingSet = nil }
            Button("Start new", role: .destructive) { model.confirmSetChange() }
        } message: { Text("Changing the mysteries restarts the current progress.") }
        .onChange(of: languageStore.selection) { model.languageDidChange() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Holy Rosary").font(.essenceHeadlineMedium).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Text("Pray at your pace or follow the guided reading.").font(.essenceBodyMedium).foregroundStyle(palette.secondaryText)
        }
    }

    private var mysteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Mysteries").font(.essenceTitleMedium)
                    Text(model.mysterySet.name.text(for: language)).font(.essenceBodyMedium).foregroundStyle(palette.accent)
                }
                Spacer()
                Button("Change") { model.isChoosingSet = true }
            }
            ForEach(model.mysterySet.mysteries) { mystery in
                Text("\(mystery.number). \(mystery.name.text(for: language))")
                    .font(.essenceBodyMedium).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Fatima Prayer", isOn: Binding(get: { model.includeFatimaPrayer }, set: model.toggleFatima))
                .tint(palette.accent)
            if model.hasProgress {
                Button("Start new") { model.beginNew() }
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(18).background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
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

    private var currentPrayerCard: some View {
        Group {
            if let step = model.currentStep {
                VStack(alignment: .leading, spacing: 12) {
                    if let mystery = model.repository.mystery(step.mysteryID), let decade = step.decade {
                        Text("\(decade)º · \(mystery.name.text(for: language))")
                            .font(.essenceTitleMedium).foregroundStyle(palette.accent)
                    }
                    Text(positionTitle(step)).font(.essenceLabelLarge).foregroundStyle(palette.secondaryText)
                    Text(model.spokenText(for: step, language: language))
                        .font(.essenceBodyLarge).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private var completionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(palette.accent).accessibilityHidden(true)
            Text("Rosary completed").font(.essenceTitleLarge)
            Button("Pray again") { model.beginNew() }.buttonStyle(.borderedProminent).tint(palette.accent)
        }.padding(22).frame(maxWidth: .infinity).background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var manualTransportControls: some View {
        HStack(spacing: 10) {
            transportButton(
                title: "Previous",
                icon: "chevron.left",
                prominent: false,
                disabled: model.currentIndex == 0 || model.isCompleted,
                action: model.previous
            )

            transportButton(
                title: model.currentIndex == model.steps.count - 1 ? "Complete" : "Next bead",
                icon: "chevron.right",
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
                    .font(.system(size: 58))
                    .foregroundStyle(palette.accent)
                    .frame(width: 68, height: 68)
            }
            .disabled(model.isCompleted)
            .accessibilityLabel(guidedTitle)

            Button(action: model.stopGuided) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 34))
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
        prominent: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.essenceLabelLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(prominent ? Color.white : palette.accent)
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
            return language == .pt ? "\(name) • \(position) de \(total)" : "\(name) • \(position) of \(total)"
        }
        return name
    }
    private var progressAccessibility: String {
        let current = model.currentIndex + 1, total = model.steps.count
        return language == .pt ? "Progresso: \(current) de \(total)" : "Progress: \(current) of \(total)"
    }
}

/// Prayer names and bead accessibility text in the Rosary's content language (same pt/en source as the prayer card).
private enum RosaryLabels {
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
                    var path = Path(); path.addEllipse(in: RosaryVisualRules.loopFrame(in: size))
                    context.stroke(path, with: .color(palette.outline), lineWidth: 2)
                    let loopBeads = RosaryVisualRules.loopBeadIDs
                    for (index, beadID) in loopBeads.enumerated() {
                        let point = RosaryVisualRules.loopPoint(at: Double(index), in: size)
                        let state = beadState(beadID)
                        let radius: CGFloat = beadID.contains("large") ? 7 : 4.5
                        let color = state == 2 ? palette.accent : state == 1 ? palette.accent.opacity(0.42) : palette.track
                        context.fill(Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2)), with: .color(color))
                        if state == 2 { context.stroke(Path(ellipseIn: CGRect(x: point.x-radius-4, y: point.y-radius-4, width: (radius+4)*2, height: (radius+4)*2)), with: .color(palette.accent.opacity(0.3)), lineWidth: 3) }
                    }
                    var pendant = Path()
                    pendant.move(to: CGPoint(x: center.x, y: size.height * 0.60))
                    pendant.addLine(to: CGPoint(x: center.x, y: size.height * 0.965))
                    context.stroke(pendant, with: .color(palette.outline), lineWidth: 2)

                    let medal = CGRect(x: center.x-11, y: size.height*0.615, width: 22, height: 28)
                    context.fill(Path(ellipseIn: medal), with: .color(color(for: "medal")))
                    for (offset,id) in [
                        (0.72,"pendant.large.2"),
                        (0.79,"pendant.small.3"),
                        (0.835,"pendant.small.2"),
                        (0.88,"pendant.small.1"),
                        (0.935,"pendant.large.1")
                    ] {
                        let r: CGFloat = id.contains("large") ? 7 : 4.5
                        context.fill(Path(ellipseIn: CGRect(x:center.x-r,y:size.height*offset-r,width:r*2,height:r*2)), with:.color(color(for:id)))
                    }
                    var cross = Path()
                    cross.move(to: CGPoint(x: center.x, y: size.height * 0.965))
                    cross.addLine(to: CGPoint(x: center.x, y: size.height * 0.995))
                    cross.move(to: CGPoint(x: center.x - 7, y: size.height * 0.977))
                    cross.addLine(to: CGPoint(x: center.x + 7, y: size.height * 0.977))
                    context.stroke(cross, with: .color(color(for: "crucifix")), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rosary overview")
                .accessibilityValue("Progress: \(currentIndex + 1) of \(steps.count), decade \(steps[currentIndex].decade ?? 0)")
                ForEach(1...5, id: \.self) { decade in
                    Button { withAnimation(reduceMotion ? nil : .easeInOut) { onSelectBead(decade == 1 ? "pendant.large.2" : "loop.large.\(decade)") } } label: { Color.clear.frame(width: 44, height: 44) }
                        .position(RosaryVisualRules.decadeButtonCenter(decade: decade, in: proxy.size)).accessibilityLabel("Decade \(decade)")
                }
            }
        }.frame(height: 320)
    }
    private func beadState(_ id: String) -> Int {
        switch RosaryVisualRules.progress(for: id, in: steps, currentIndex: currentIndex) {
        case .pending: 0
        case .completed: 1
        case .current: 2
        }
    }
    private func color(for id: String) -> Color { switch beadState(id) { case 2: palette.accent; case 1: palette.accent.opacity(0.42); default: palette.track } }
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
    private func color(_ id: String) -> Color { state(id)==2 ? palette.accent : state(id)==1 ? palette.accent.opacity(0.42) : palette.track }
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
