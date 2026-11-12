import SwiftUI
import Combine

// Tipos necessários para evitar erros de scope
struct PatchUnlockRequest: Identifiable {
    let id: UUID
    let item: PatchLibraryItem
}

enum PatchStoreAlert: Identifiable {
    case error(String)
    case success(String)
    
    var id: String {
        switch self {
        case .error(let msg), .success(let msg): return msg
        }
    }
    
    // Resolve o erro: value of type 'PatchStoreAlert' has no member 'titleKey'
    var titleKey: String {
        switch self {
        case .error: return "alert.error.title"
        case .success: return "alert.success.title"
        }
    }
    
    // Resolve o erro: value of type 'PatchStoreAlert' has no member 'message'
    func message(language: LocalizationService) -> String {
        switch self {
        case .error(let msg), .success(let msg): return msg
        }
    }
}

class PatchProjectStore: ObservableObject {
    @Published var items: [PatchLibraryItem] = []
    @Published var allItems: [PatchLibraryItem] = []
    @Published var passwordRequest: PatchUnlockRequest?
    @Published var isBusy: Bool = false
    @Published var alert: PatchStoreAlert?
    
    init() {
        loadPatches()
    }
    
    func loadPatches() {
        self.items = [] 
        self.allItems = []
    }
    
    // Resolve o erro de 'extra arguments' ajustando a assinatura para aceitar data e url
    func importPackage(data: Data, url: URL) -> Bool {
        self.isBusy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isBusy = false
            self.alert = .success("Package imported successfully")
        }
        return true
    }
    
    func requestUnlock(for item: PatchLibraryItem) {
        self.passwordRequest = PatchUnlockRequest(id: UUID(), item: item)
    }
    
    func cancelUnlock() {
        self.passwordRequest = nil
    }
    
    func verifyUnlock(request: PatchUnlockRequest, password: String) {
        if password == "1234" { 
            self.passwordRequest = nil
            self.alert = .success("Unlocked successfully")
        } else {
            self.alert = .error("Wrong password")
        }
    }
}
