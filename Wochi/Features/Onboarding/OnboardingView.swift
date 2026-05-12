import SwiftUI

// MARK: - Slide Model

private struct OnboardingSlide: Identifiable {
    let id: Int
    let symbolName: String
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
}

private let slides: [OnboardingSlide] = [
    OnboardingSlide(
        id: 0,
        symbolName: "house.and.flag",
        titleKey: "onboarding.slide1.title",
        subtitleKey: "onboarding.slide1.subtitle"
    ),
    OnboardingSlide(
        id: 1,
        symbolName: "bell.badge",
        titleKey: "onboarding.slide2.title",
        subtitleKey: "onboarding.slide2.subtitle"
    ),
    OnboardingSlide(
        id: 2,
        symbolName: "chart.bar.xaxis",
        titleKey: "onboarding.slide3.title",
        subtitleKey: "onboarding.slide3.subtitle"
    ),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentIndex: Int = 0
    @State private var showSignIn: Bool = false

    private var isLastSlide: Bool { currentIndex == slides.count - 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Slide carousel
            TabView(selection: $currentIndex) {
                ForEach(slides) { slide in
                    SlideView(slide: slide)
                        .tag(slide.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentIndex)

            // Navigation controls
            VStack(spacing: 16) {
                Spacer()

                Button {
                    if isLastSlide {
                        showSignIn = true
                    } else {
                        withAnimation { currentIndex += 1 }
                    }
                } label: {
                    Text("button.continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if !isLastSlide {
                    Button {
                        withAnimation { currentIndex = slides.count - 1 }
                    } label: {
                        Text("button.skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Invisible spacer to keep layout stable on last slide
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showSignIn) {
            SignInView(showOnboarding: $showOnboarding)
        }
    }
}

// MARK: - SlideView

private struct SlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: slide.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text(slide.titleKey)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(slide.subtitleKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            // Bottom padding so controls don't overlap text
            Color.clear.frame(height: 160)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
