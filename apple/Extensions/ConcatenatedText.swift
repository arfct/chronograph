import SwiftUI

struct ConcatenatedTextView<Content: View>: View {
  @ViewBuilder var content: () -> Content
  
  var body: some View {
    VStack {
      Text("hi")
      concatenateViews(content: content())
        .font(.title)
        .frame(width: 200, height: 200, alignment: .center)
        .border(.red)
      
        Text("there")
    }
  }
  
  func concatenateViews(content: Content) -> Text {
    let mirror = Mirror(reflecting: content)
    let textElements = mirror.children.compactMap { $0.value as? Text }
    return textElements.reduce(Text("")) { $0 + $1 }
  }
}

struct ContentViewText: View {
  var body: some View {
    ConcatenatedTextView {
      Text("Hello, ")
      Text("world!").foregroundColor(.red)
      Text(" How ")
      Text("are ").bold()
      Text("you?").italic()
    }
  }
}

struct ContentViewText_Previews: PreviewProvider {
  static var previews: some View {
    ContentViewText()
      .previewLayout(.fixed(width: 300, height: 300))
  }
}
