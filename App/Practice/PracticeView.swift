import SwiftUI
import GrooveModel

/// A drum-teacher-style practice session: pick a day's plan, the tempo
/// climbs on a schedule while the drummer keeps time, and it's logged when
/// you're done — finished or not.
struct PracticeView: View {
    @Environment(GrooveSession.self) private var session
    @State private var controller = PracticeController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan = controller.activePlan {
                    activeSessionCard(plan)
                } else {
                    if let record = controller.lastCompletedRecord {
                        completionBanner(record)
                    }
                    planPicker
                }

                if !controller.recentSessions.isEmpty {
                    historySection
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.stage)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if controller.activePlan != nil { controller.stopEarly(using: session) }
        }
    }

    // MARK: - Plan picker

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a plan")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(PracticePlan.builtIn) { plan in
                Button {
                    controller.start(plan, using: session)
                } label: {
                    planRow(plan)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan-\(plan.id)")
            }
        }
    }

    private func planRow(_ plan: PracticePlan) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text(plan.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(plan.sessionMinutes) min")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.amber)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Active session

    private func activeSessionCard(_ plan: PracticePlan) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(plan.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(Int(controller.currentBPM.rounded()))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(controller.currentBPM.rounded()))
                    .accessibilityIdentifier("practiceBPM")
                Text("BPM")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: controller.progress)
                .tint(Color.amber)

            HStack {
                Label(timeString(controller.elapsed), systemImage: "clock")
                Spacer()
                Label("\(timeString(controller.remainingSeconds)) left", systemImage: "hourglass")
            }
            .font(.system(.footnote, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)

            Button {
                controller.stopEarly(using: session)
            } label: {
                Text("Stop")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ember)
            .accessibilityIdentifier("stopPracticeButton")
        }
        .padding(20)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func completionBanner(_ record: PracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Session complete")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.amber)
            Text("\(record.planTitle) — \(Int(record.startBPM))→\(Int(record.endBPM)) BPM, \(timeString(record.duration))")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent sessions")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(controller.recentSessions.prefix(10)) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.planTitle)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(record.date, style: .date)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(record.startBPM))→\(Int(record.endBPM)) BPM")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.amber)
                }
                .padding(12)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
