var updateChecks = 0
func requireUpdate(_ condition: @autoclosure () -> Bool, _ label: String) {
    updateChecks += 1
    if !condition() { fatalError(label) }
}
func release(_ changes: [String: Any] = [:], assetChanges: [String: Any] = [:]) -> UpdateRelease {
    var asset: [String: Any] = ["name": UpdateRelease.archiveName, "browser_download_url": "https://github.com/\(UpdateRelease.repository)/releases/download/v1.3.0/\(UpdateRelease.archiveName)", "size": 1200, "state": "uploaded", "digest": "sha256:" + String(repeating: "a", count: 64)]
    asset.merge(assetChanges) { _, new in new }
    var json: [String: Any] = ["tag_name": "v1.3.0", "draft": false, "prerelease": false, "assets": [asset]]
    json.merge(changes) { _, new in new }
    return try! JSONDecoder().decode(UpdateRelease.self, from: JSONSerialization.data(withJSONObject: json))
}
requireUpdate(UpdateVersion("1.9.0")! < UpdateVersion("1.10.0")!, "numeric version order")
for value in ["1.2", "1.2.3.4", "1.2.-1", "1.2.3-beta1", "1.2.03", "999999999.0.0", "1.２.3", "", "../1.2.3"] {
    requireUpdate(UpdateVersion(value) == nil, "malformed version")
}
requireUpdate(release().isNewer(than: "1.2.0"), "newer")
requireUpdate(!release().isNewer(than: "1.3.0"), "equal")
requireUpdate(!release().isNewer(than: "1.4.0"), "downgrade")
requireUpdate(release().isNewer(than: "1.3.0-dev.1"), "stable replaces same-base development build")
for changes: [String: Any] in [["draft":true], ["prerelease":true], ["tag_name":"v1.3.0-beta1"], ["assets":[]]] {
    requireUpdate(release(changes).candidate == nil, "release refused")
}
for changes: [String: Any] in [["digest":"sha256:bad"], ["digest":NSNull()], ["size":0], ["size":UpdateRelease.maxBytes+1], ["browser_download_url":"https://example.com/update.zip"], ["name":"Other.zip"], ["state":"new"]] {
    requireUpdate(release(assetChanges:changes).candidate == nil, "asset refused")
}
let validAsset = release().assets[0]
let assetObject: [String: Any] = ["name":validAsset.name,"browser_download_url":validAsset.browser_download_url,"digest":validAsset.digest!,"size":validAsset.size,"state":validAsset.state]
requireUpdate(release(["assets":[assetObject,assetObject]]).candidate == nil, "ambiguous asset")
for path in CommandLine.arguments.dropFirst() {
    let data = try! Data(contentsOf: URL(fileURLWithPath:path))
    let expected = URL(fileURLWithPath:path).lastPathComponent.hasPrefix("valid")
    var accepted = true
    do { try UpdateArchive.validate(data) } catch { accepted = false }
    requireUpdate(accepted == expected, "archive \(path)")
    if expected {
        let digest = "sha256:" + SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined()
        let good = release(assetChanges:["size":data.count,"digest":digest]).assets[0]
        do { try GitHubUpdater.validateDownload(data, asset:good) } catch { fatalError("valid download") }
        for bad in [release(assetChanges:["size":data.count+1,"digest":digest]).assets[0],release(assetChanges:["size":data.count]).assets[0]] {
            var refused = false
            do { try GitHubUpdater.validateDownload(data,asset:bad) } catch { refused = true }
            requireUpdate(refused,"bad digest or size")
        }
    }
}
print("\(updateChecks) updater policy/archive assertions passed; no network, installer or HID calls.")
