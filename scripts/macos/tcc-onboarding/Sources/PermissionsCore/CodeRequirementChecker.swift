import Foundation
import Security

public enum RequirementResult: Equatable {
    case matches, mismatch, unverifiable(String)
}

public protocol RequirementChecking {
    func check(_ url: URL, requirement: Data?) -> RequirementResult
}

public final class CodeRequirementChecker: RequirementChecking {
    private struct Key: Hashable { let url: URL; let requirement: Data }
    private var results: [Key: RequirementResult] = [:]

    public init() {}

    public func check(_ url: URL, requirement data: Data?) -> RequirementResult {
        guard let data, !data.isEmpty else { return .unverifiable("The record has no code requirement to verify.") }
        let key = Key(url: url, requirement: data)
        if let result = results[key] { return result }
        let result = evaluate(url, data: data)
        results[key] = result
        return result
    }

    private func evaluate(_ url: URL, data: Data) -> RequirementResult {
        var requirement: SecRequirement?
        var code: SecStaticCode?
        let flags = SecCSFlags(rawValue: 0)
        var status = SecRequirementCreateWithData(data as CFData, flags, &requirement)
        guard status == errSecSuccess, let requirement else { return failure("Cannot decode the stored requirement", status) }
        status = SecStaticCodeCreateWithPath(url as CFURL, flags, &code)
        guard status == errSecSuccess, let code else { return failure("Cannot inspect the installed code", status) }
        // Check integrity separately so a damaged signature is not called a stale grant.
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
