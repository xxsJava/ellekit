
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

struct Filter: Codable {
    var Filter: CoreFilter
    struct CoreFilter: Codable {
        var Bundles: [String]?
        var Executables: [String]?
    }
    var UnloadAfter: Bool?
}

class Tweak {
    internal init(tweak: String) throws {
        self.path = tweak+".dylib"
        let filterData = try Data(contentsOf: NSURL.fileURL(withPath: tweak+".plist"))
        let filterRoot = try PropertyListDecoder().decode(Filter.self, from: filterData)
        let bundles = filterRoot
            .Filter
            .Bundles?
            .map { $0.lowercased() } ?? []
        let executables = filterRoot
            .Filter
            .Executables?
            .map { $0.lowercased() } ?? []
        self.bundles = bundles
        self.executables = executables
        tprint("\(self.path) : \(self.bundles) : \(self.executables)")
    }
    
    var path: String
    var bundles: [String]
    var executables: [String]
}

func getTweaksPath() -> String {
    #if os(macOS)
    return "/Library/TweakInject/"
    #else
    if access("/var/jb/usr/lib/TweakInject/", F_OK) == 0 {
        return (("/var/jb/usr/lib/TweakInject/" as NSString).resolvingSymlinksInPath)+"/"
    } else {
        return (("/Library/EE59E951-FDD0-C6BF-809A-C35D0599D729/AI-155D000B-3232-7A8E-BFB2-07BEF118D7A6/" as NSString).resolvingSymlinksInPath)+"/"
    }
    #endif
}

var tweaks: [Tweak] = []

func loadTweaks() throws {
    let path = getTweaksPath()
    let loaded = try FileManager.default.contentsOfDirectory(atPath: path)
        .filter { $0.suffix(6) == ".dylib" || $0.suffix(6) == ".plist" }
        .compactMap {
            path+$0.components(separatedBy: ".").dropLast().joined(separator: ".") // remove extension
        }
        .removeDuplicates()
        .sorted { $0 < $1 }
    tweaks = loaded.compactMap { try? Tweak.init(tweak: $0) }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> Self {
        Array(Set(self))
    }
}
