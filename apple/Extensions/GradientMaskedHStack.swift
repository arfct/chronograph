import SwiftUI

struct ContentSizePreferenceKey: PreferenceKey {
  static var defaultValue: [CGSize] = []
  static func reduce(value: inout [CGSize], nextValue: () -> [CGSize]) {
    value.append(contentsOf: nextValue())
  }
}

struct GradientMaskedHStack<Content: View>: View {
  let content: Content
  let spacing: CGFloat?
  let alignment: VerticalAlignment
  
  //  @State private var trailingGradientLength: CGFloat = 0
  @State private var contentSize: CGSize = .zero
  @State private var containerSize: CGSize = CGSize(width: 10, height: 10)
  
  init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.alignment = alignment
    self.content = content()
  }
  
  
  var body: some View {
      
      let trailingGradientLength = contentSize.width > containerSize.width ? contentSize.height * 3 : 0.0
      
      let view =
      HStack {
        HStack(alignment: alignment, spacing:spacing) {
          content
            .background(GeometryReader { itemFrame in
              Color.clear.preference(key: ContentSizePreferenceKey.self, value: [itemFrame.size])
            })
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(alignment:.leading)
        .clipped()
        
        .overlay(GeometryReader { proxy in
          Color.clear.onChange(of: proxy.size) {
            print("size changed: \(proxy.size.width)")
            containerSize = proxy.size
          }.task {
            
              print("size changed: \(proxy.size.width)")
            containerSize = proxy.size
          }
        }.padding(2))
      }
      .frame(maxWidth:.infinity, alignment:.leading)

        .onPreferenceChange(ContentSizePreferenceKey.self) { sizes in
          let usedWidth = sizes.map({$0.width}).reduce(0, +) + CGFloat(sizes.count - 1) + CGFloat(spacing ?? 0.0)
          let height = sizes.map({$0.height}).reduce(0, max)
          contentSize = CGSize(width: usedWidth, height: height)
        }
      
      
      
      
      
      if (trailingGradientLength > 0) {
        view.mask(LinearGradient(
          gradient: Gradient(colors: [
            Color.black,
            Color.black.opacity(0.95),
            Color.black.opacity(0.75),
            Color.black.opacity(0.5),
            Color.black.opacity(0.0)]),
          startPoint:  UnitPoint(x: 1.0 - trailingGradientLength / containerSize.width, y: 0),
          endPoint: UnitPoint(x: 1.0, y: 0)))
      } else {
        view
      }
   
    
    
    
    
  }
}


// Example usage
struct HStackPreviewView: View {
  var body: some View {
    
    GradientMaskedHStack(spacing:10) {
      ForEach(0..<7) { index in
        Text("Item Title \(index)")
          .lineLimit(1)
          .padding()
          .background(Color.white)
          .cornerRadius(8)
      }
    }
    
  }
}

struct HStackPreviewView_Previews: PreviewProvider {
  static var previews: some View {
    HStackPreviewView()
  }
}
