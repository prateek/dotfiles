import Foundation
import Security

public enum RequirementResult: Equatable {
    case matches, mismatch, unverifiable(String)
}

public protocol RequirementChecking {
    func check(_ url: URL, requirement: Data?) -> RequirementResult
}

/// Caches verdicts for the checker's lifetime, keyed by the bundle's modification date so a
/// long-lived checker (the GUI keeps one across polls) re-evaluates replaced code.
public final class CodeRequirementChecker: RequirementChecking, @unchecked Sendable {
    private struct Key: Hashable { let url: URL; let modified: Date?; let requirement: Data }
    private var results: [Key: RequirementResult] = [:]
    private let lock = NSLock()

    public init() {}

    public func check(_ url: URL, requirement data: Data?) -> RequirementResult {
        guard let data, !data.isEmpty else { return .unverifiable("The record has no code requirement to verify.") }
        let key = Key(url: url, modified: Self.signatureDate(url), requirement: data)
        if let result = lock.withLock({ results[key] }) { return result }
        let result = evaluate(url, data: data)
        lock.withLock { results[key] = result }
        return result
    }

    /// A bundle's own mtime can survive an in-place update, but re-signing always rewrites its
    /// CodeResources; bare executables carry their signature inline.
    static func signatureDate(_ url: URL) -> Date? {
        let resources = url.appendingPathComponent("Contents/_CodeSignature/CodeResources")
        let target = FileManager.default.fileExists(atPath: resources.path) ? resources : url
        return (try? target.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func evaluate(_ url: URL, data: Data) -> RequirementResult {
        var requirement: SecRequirement?
        var code: SecStaticCode?
        let flags = SecCSFlags(rawValue: 0)
        var status = SecRequirementCreateWithData(data as CFData, flags, &requirement)
        guard status == errSecSuccess, let requirement else { return failure("Cannot decode the stored requirement", status) }
        status = SecStaticCodeCreateWithPath(url as CFURL, flags, &code)
        guard status == errSecSuccess, let code else { return failure("Cannot inspect the installed code", status) }
        // Check integrity separately so a damaged signature is not called a stale grant: with a
        // requirement attached, an identifier mismatch is reported before the damage.
        status = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil)
        guard status == errSecSuccess else { return failure("The installed code signature cannot be validated", status) }
        status = SecStaticCodeCheckValidity(code, flags, requirement)
        if status == errSecSuccess { return .matches }
        if status == errSecCSReqFailed { return .mismatch }
        return failure("Cannot evaluate the stored requirement", status)
    }

    private func failure(_ message: String, _ status: OSStatus) -> RequirementResult {
        .unverifiable("\(message) (Security error \(status)).")
    }
}
