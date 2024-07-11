import SwiftUI

struct TokenizedTextView: View {
  let text: String
  
  var body: some View {
    let components = tokenizeText(text)
    
    return HStack(spacing:0) {
      ForEach(components, id: \.self) { component in
        if component.hasPrefix("[") && component.hasSuffix("]") {
          Text(component.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .opacity(0.8)
            .background(.regularMaterial)
            .cornerRadius(4)
        } else if component.hasPrefix("(") && component.hasSuffix(")") {
          Text(component.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .opacity(0.8)
            .background(.regularMaterial)
            .cornerRadius(.infinity)
        } else {
          Text(component)
        }
      }
    }
  }
  
  func tokenizeText(_ text: String) -> [String] {
    var tokens: [String] = []
    var currentToken = ""
    var isInBracket = false
    var isInParenthesis = false
    
    for character in text {
      if character == "[" {
        if !currentToken.isEmpty {
          tokens.append(currentToken)
        }
        currentToken = "["
        isInBracket = true
      } else if character == "]" {
        currentToken.append("]")
        tokens.append(currentToken)
        currentToken = ""
        isInBracket = false
      } else if character == "(" {
        if !currentToken.isEmpty {
          tokens.append(currentToken)
        }
        currentToken = "("
        isInParenthesis = true
      } else if character == ")" {
        currentToken.append(")")
        tokens.append(currentToken)
        currentToken = ""
        isInParenthesis = false
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
    TokenizedTextView(text: "This is a [sample] text with [tokens] and (parentheses).")
      .padding()
  }
}
