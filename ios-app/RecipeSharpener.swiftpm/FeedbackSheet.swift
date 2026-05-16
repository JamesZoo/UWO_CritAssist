import SwiftUI

struct FeedbackSheet: View {
    @Bindable var vm: FeedbackViewModel
    var onCompleted: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let outcome = vm.result {
                    RefinementResultView(
                        feedback: outcome.newFeedback,
                        previous: outcome.prevRevision,
                        next: outcome.newRevision,
                        onApply: {
                            onCompleted(outcome.updatedRecipe)
                            dismiss()
                        },
                        onDiscard: {
                            dismiss()
                        }
                    )
                } else {
                    feedbackForm
                }
            }
            .navigationTitle(vm.result == nil ? "Feedback" : "Refinement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.result == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private var feedbackForm: some View {
        Form {
            Section("On") {
                Text(vm.ownerName).font(.headline)
                if let rev = vm.currentRevision {
                    Text("Revision \(rev.index)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("What happened?") {
                TextField(
                    "e.g. The meat was too chewy and had a blood smell. The soup is too sour.",
                    text: $vm.text,
                    axis: .vertical
                )
                .lineLimit(3...8)
            }

            Section("Rating (optional)") {
                StarRatingPicker(rating: $vm.rating)
            }

            Section {
                TextField("Tester note (optional)", text: $vm.testerNote, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("For black-box testing")
            } footer: {
                Text("Recorded alongside the model output so you can compare what you expected to what the model did.")
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.footnote) }
            }

            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isSubmitting {
                        HStack { ProgressView(); Text("Refining…") }
                    } else {
                        Text("Refine recipe").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canSubmit)
            }
        }
    }
}

private struct StarRatingPicker: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = (rating == i) ? nil : i
                } label: {
                    Image(systemName: (rating ?? 0) >= i ? "star.fill" : "star")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let r = rating {
                Text("\(r)/5").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("none").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
