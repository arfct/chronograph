import SwiftUI
import WidgetKit
import AppIntents
import EventKit

struct ContentView: View {
  @AppStorage(Keys.brailleMode, store: UserDefaults(suiteName: Keys.suiteName))
  private var legacyBrailleMode = false
  @AppStorage(Keys.obfuscation, store: UserDefaults(suiteName: Keys.suiteName))
  private var obfuscationRaw = ""

  private var obfuscation: Binding<ObfuscationStyle> {
    Binding(
      get: { ObfuscationStyle.resolve(rawValue: obfuscationRaw, legacyBrailleMode: legacyBrailleMode) },
      set: { obfuscationRaw = $0.rawValue }
    )
  }

  private let eventStore = EKEventStore()
  /// Held for the life of the view: a location prompt is dropped if its
  /// manager is released before the user answers.
  @State private var locationManager = LocationManager()
  /// Bumped after a permission prompt so the body re-reads the status.
  @State private var accessRefresh = 0

  var body: some View {
    let _ = accessRefresh

    NavigationStack {
    ScrollView {
      
      VStack {
       
        
      Image("Wordmark")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .padding(.top, 40)
        .padding(.leading, 20)
        .padding(.trailing, 60)
      
      
      Text("A large widget for the modular watch face")
        .frame(maxWidth:.infinity)
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding(.bottom, 16)
      .background(.white.opacity(0.1))
      
      // The default wheel has no intrinsic height inside a ScrollView and
      // collapsed to a sliver; a navigation-link row sizes itself.
      Picker("Obfuscation", selection: obfuscation) {
        ForEach(ObfuscationStyle.allCases) { style in
          Text(style.displayName).tag(style)
        }
      }
      .pickerStyle(.navigationLink)
      .padding(.horizontal)
      
      VStack(spacing:10) {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
          WidgetPreviewView(config: .calendar)
            .frame(minHeight: 600)
        } else {
          Button(action: {
            Task {
              _ = try? await eventStore.requestFullAccessToEvents()
              accessRefresh += 1
            }
          }) {
            Label("Enable Calendar Access", systemImage: "lock")
          }
        }
        Divider()
          .padding(.leading, 36)
        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
          
          WidgetPreviewView(config: .reminders)
            .frame(minHeight: 100)
            .listRowBackground(Color.clear)
        } else {
          Button(action: {
            Task {
              _ = try? await eventStore.requestFullAccessToReminders()
              accessRefresh += 1
            }
          }) {
            Label("Enable Reminders Access", systemImage: "lock")
          }
        }
        if !locationManager.isAuthorized {
          Divider()
            .padding(.leading, 36)
          Button(action: {
            locationManager.onAuthorizationChange = { accessRefresh += 1 }
            locationManager.checkAuthorization()
          }) {
            Label("Enable Location", systemImage: "location")
          }
          Text("For local weather in the widget")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }.padding(.vertical)
    }
      .edgesIgnoringSafeArea(.all)
    }
  }
}

#Preview {
  ContentView()
}
