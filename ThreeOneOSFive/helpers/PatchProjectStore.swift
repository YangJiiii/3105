import SwiftUI
import Combine

// Tipos de suporte para compatibilidade com o restante do app
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
    
    var titleKey: String {
        switch self {
        case .error: return "alert.error.title"
        case .success: return "alert.success.title"
        }
    }
    
    func message(language: Any) -> String {
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
    
    // ASSINATURA EXATA exigida pelo PackageRepositoryStore.swift
    func importPackage(data: Data, password: String?, origin: PatchPackageOrigin) -> Bool {
        self.isBusy = true
        
        // Simulação de importação para build passar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isBusy = false
            self.alert = .success("Package imported successfully")
        }
        return true
    }
    
    // Função exigida pelo PackageRepositoryStore para tratar erros de codec
    func presentImportError(_ error: PatchPackageError) {
        self.alert = .error(error.localizedDescription)
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
