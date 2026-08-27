// CTANMapper.swift — Resolve nomes de pacotes TeX para seus nomes canônicos no CTAN via API JSON.

import Foundation

/// Protocolo para resolver o nome de um elemento TeX para seu par CTAN.
public protocol CTANMapping: Sendable {
    func resolve(_ name: String) async throws -> CTANMatch
}

/// Resultado de uma tentativa de resolução de nome no CTAN.
public enum CTANMatch: Equatable, Sendable {
    /// Resolvido com sucesso para um pacote canônico do CTAN.
    case matched(package: String)
    /// Nenhum pacote correspondente no CTAN (ou erro de rede transitório).
    case unknown
}

/// Resolve nomes de pacotes TeX para nomes canônicos do CTAN, com cache em memória.
public struct CTANMapper: Sendable {
    private struct Payload: Decodable {
        let name: String?
    }

    private let session: URLSession
    private let cache: LockedDict
    /// Callback opcional chamado a cada tentativa de resolução (progresso na UI).
    private let onResolve: (@Sendable (String) -> Void)?

    public init(session: URLSession = .shared, cache: [String: CTANMatch] = [:], onResolve: (@Sendable (String) -> Void)? = nil) {
        self.session = session
        self.cache = LockedDict(initial: cache)
        self.onResolve = onResolve
    }

    /// Resolve um nome de pacote contra o CTAN. Retorna resultado em cache; timeout de rede é 10s.
    /// Falhas de rede (timeout/offline) NÃO são cacheadas: são transitórias e devem ser retentadas.
    public func resolve(_ name: String) async throws -> CTANMatch {
        let key = name.lowercased()
        if let cached = cache.value(forKey: key) { return cached }
        onResolve?(name)
        guard let url = URL(string: "https://ctan.org/json/2.0/pkg/\(key)") else {
            // URL malformada é erro de programação, não de rede — não faz sentido cachear.
            return .unknown
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                // Resposta não-HTTP (queda de rede): não cacheia, tenta de novo depois.
                return .unknown
            }
            if http.statusCode == 200 {
                // Nome canônico do CTAN (campo `name`); fallback para o nome consultado.
                let canonical = (try? JSONDecoder().decode(Payload.self, from: data).name) ?? name
                cache.set(.matched(package: canonical), forKey: key)
                return .matched(package: canonical)
            }
            if http.statusCode == 404 {
                // Pacote de fato inexistente no CTAN: seguro cachear como desconhecido.
                cache.set(.unknown, forKey: key)
                return .unknown
            }
            // Outros status (429/5xx/erro transitório): não cacheia, retenta mais tarde.
            return .unknown
        } catch {
            // Falha de rede (timeout, offline): não confundir com "não encontrado".
            return .unknown
        }
    }

    /// Dicionário thread-safe usado como cache em memória.
    private final class LockedDict: @unchecked Sendable {
        private var storage: [String: CTANMatch]
        private let lock = NSLock()
        init(initial: [String: CTANMatch]) { storage = initial }
        func value(forKey key: String) -> CTANMatch? { lock.lock(); defer { lock.unlock() }; return storage[key] }
        func set(_ value: CTANMatch, forKey key: String) { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    }
}

extension CTANMapper: CTANMapping {}
