import SwiftUI

struct CustomTabView: View {
    private let titles: [String]
    private let icons: [String]
    private let tabViews: [() -> AnyView]

@State private var selection = 0
@State private var indexHovered = -1

    init(content: [(title: String, icon: String, view: () -> AnyView)]) {
    self.titles = content.map{ $0.title }
    self.icons = content.map{ $0.icon }
    self.tabViews = content.map{ $0.view }
}

var tabBar: some View {
    HStack {
        Spacer()
        ForEach(0..<titles.count, id: \.self) { index in

            VStack {
                Image(systemName: self.icons[index])
                    .font(.largeTitle)
                Text(self.titles[index])
            }
            .frame(height: 30)
            .padding(15)
            .background(Color.gray.opacity(((self.selection == index) || (self.indexHovered == index)) ? 0.3 : 0),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            .frame(height: 80)
            .padding(.horizontal, 0)
            .foregroundColor(self.selection == index ? Color.accentColor : Color.primary)
            .onHover(perform: { hovering in
                if hovering {
                    indexHovered = index
                } else {
                    indexHovered = -1
                }
            })
            .onTapGesture {
                self.selection = index
            }
        }
        Spacer()
    }
    .padding(0)
}

var body: some View {
    VStack(spacing: 0) {
        tabBar

        tabViews[selection]()
            .padding(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(0)
    }
}
