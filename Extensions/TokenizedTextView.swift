import SwiftUI


struct TokenViewModifier: ViewModifier {
  var isMonochrome: Bool
  var corderRadius: CGFloat = 10
  
  func body(content: Content) -> some View {
    if isMonochrome {
      content.background( RoundedRectangle(cornerRadius: corderRadius).stroke(.primary.opacity(0.2), lineWidth: 2))
    } else {
      content.background( RoundedRectangle(cornerRadius: corderRadius).fill(.primary.opacity(0.15)))
      
    }
  }
}

extension View {
  func tokenBackground(_ isMonochrome: Bool, cornerRadius: CGFloat = 10) -> some View {
    self.modifier(TokenViewModifier(isMonochrome: isMonochrome, corderRadius: cornerRadius))
  }
}



struct TokenizedTextView: View {
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  
  let text: String
  @State var font: Font?
  @State var tokenFont: Font?
  @State var alignment: VerticalAlignment = .center
  
  
  
  
  var body: some View {
    let components = tokenizeText(text)
    
    return GradientMaskedHStack(alignment:alignment, spacing:0) {
      ForEach(components, id: \.self) { component in
        if component.hasPrefix("[") && component.hasSuffix("]") {
          Text(component.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
//            .font(tokenFont ?? Font.system(size: 10))
            .fixedSize()
            .padding(.horizontal, 3)
            .lineLimit(1)
            .padding(.vertical, 1)
          
            .tokenBackground(false, cornerRadius:4)
        } else if component.hasPrefix("(") && component.hasSuffix(")") {
          Text(component.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
//            .font(tokenFont ?? Font.system(size: 10))
            .fixedSize()

            .padding(.horizontal, 7.5)
            .padding(.vertical, 2)
            .tokenBackground(false, cornerRadius:.infinity)
            
        } else {
          Text(component)
            .fixedSize()
        }
      }
    }
  }
  
  func tokenizeText(_ text: String) -> [String] {
    var tokens: [String] = []
    var currentToken = ""
    
    for character in text {
      if character == "[" {
        if !currentToken.isEmpty {
          tokens.append(currentToken)
        }
        currentToken = "["
      } else if character == "]" {
        currentToken.append("]")
        tokens.append(currentToken)
        currentToken = ""
      } else if character == "(" {
        if !currentToken.isEmpty {
          tokens.append(currentToken)
        }
        currentToken = "("
      } else if character == ")" {
        currentToken.append(")")
        tokens.append(currentToken)
        currentToken = ""
      } else {
        currentToken.append(character)
      }
    }
    
    if !currentToken.isEmpty {
      tokens.append(currentToken)
    }
    
    return tokens
  }
}



struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    HStack {
      TokenizedTextView(text: "This is a [sample] text with [tokens] and (parentheses).").border(Color.red)
      Text("MORE")
    }
      .padding()
  }
}
