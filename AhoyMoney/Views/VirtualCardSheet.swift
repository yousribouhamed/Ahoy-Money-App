import SwiftUI

struct VirtualCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var accepted: Bool = false
    var onConfirm: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title.
            Text("T&C of the bank")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)

            // Body paragraph.
            Text("TWIG Solutions Ltd is regulated by the Dubai Financial Services Authority (DFSA) to provide money services. Financial services related to your wallet, card issuance, and payment processing are provided by our licensed financial institution partner, Mawarid Finance PJSC.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Checkbox row.
            Button {
                accepted.toggle()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(accepted ? Color(red: 0, green: 0.816, blue: 1) : Color(red: 0.78, green: 0.78, blue: 0.78), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(accepted ? Color(red: 0, green: 0.816, blue: 1) : Color.clear)
                            )
                            .frame(width: 22, height: 22)
                        if accepted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("I accept Bank")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                        Text("T&C's Document")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .underline()
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Get Virtual Card button.
            Button {
                if accepted {
                    onConfirm()
                    dismiss()
                }
            } label: {
                Text("Get Virtual Card")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        accepted
                            ? Color(red: 0, green: 0.816, blue: 1)              // #00D0FF
                            : Color(red: 0, green: 0.816, blue: 1).opacity(0.5),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!accepted)

        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.white)
    }
}
