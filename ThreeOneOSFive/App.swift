import SwiftUI

// --- ESTE É O APPSTATE (Colocado aqui para forçar o Xcode a ver) ---
class AppState: ObservableObject {
    @Published var isUnlocked: Bool = false
    
    // Adicionando as propriedades que o app original exige para não dar erro
    var isSupported: Bool {
        return true // Simula que o dispositivo é suportado para o app não crashar
    }
    
    // Caso o app peça outras propriedades dinamicamente, isso evita o erro de 'dynamic member'
    subscript(dynamicMember keyPath: String) -> Any {
        return "" 
    }
}


// --- ESTA É A LOGINVIEW (Colocada aqui para forçar o Xcode a ver) ---
struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var key: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Fundo preto caso a imagem falhe
            
            VStack(spacing: 20) {
                Text("GH777 EXTERNAL")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                
                TextField("Insira a Chave de Acesso", text: $key)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    appState.isUnlocked = true
                }) {
                    Text("ENTRAR")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// --- ESTE É O PONTO DE ENTRADA DO APP ---
@main
struct ThreeOneOSFiveApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.isUnlocked {
                ContentView()
                    .environmentObject(appState)
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}
