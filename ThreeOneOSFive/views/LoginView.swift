import SwiftUI

struct LoginView: View {
    @Binding var isUnlocked: Bool
    @State private var keyInput: String = ""
    @State private var showKey: Bool = false
    @State private var showAlert: Bool = false
    
    // COLOQUE A SUA KEY AQUI
    let correctKey = "SUA_KEY_AQUI"

    var body: some View {
        ZStack {
            // FOTO DE FUNDO
            Image("background_login") // Nome da imagem que você deve subir no Assets
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .overlay(Color.black.opacity(0.4)) // Escurece a foto para o texto aparecer
            
            VStack(spacing: 25) {
                VStack(spacing: 8) {
                    Text("GH777 EXTERNAL")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Enter your key to access the app.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // CAMPO DE KEY
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        
                        SecureField("Access key", text: $keyInput)
                            .foregroundColor(.white)
                        
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                    // BOTÃO ENTRAR
                    Button(action: {
                        if keyInput == correctKey {
                            isUnlocked = true
                        } else {
                            showAlert = true
                        }
                    }) {
                        Text("Entrar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.1))
                .cornerRadius(30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
        }
        .alert("Erro", isPresented: $showAlert) {
            Button("Tentar novamente", role: .cancel) { }
        } message: {
            Text("A chave inserida é inválida.")
        }
    }
}
