// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CSQLite

typealias Object = [String: Any]
func problem(_ text: String) -> NSError { NSError(domain: "MiUniversidad", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
func json(_ value: Any) throws -> String { String(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]), encoding: .utf8)! }
func object(_ text: String) -> Object { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? Object ?? [:] }
func string(_ o: Object, _ key: String, _ fallback: String = "") -> String { o[key] as? String ?? fallback }
func number(_ o: Object, _ key: String, _ fallback: Double = 0) -> Double { (o[key] as? NSNumber)?.doubleValue ?? fallback }
func identifier() -> String { UUID().uuidString.lowercased() }

struct Dates {
    static let zone = TimeZone(identifier: "Europe/Madrid")!
    static var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = zone; c.firstWeekday = 2; return c }
    static func format(_ d: Date, _ pattern: String = "yyyy-MM-dd'T'HH:mm:ss") -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = pattern; return f.string(from: d)
    }
    static func parse(_ s: String) -> Date? {
        if s.hasSuffix("Z") || s.range(of: "[+-][0-9]{2}:[0-9]{2}$", options: .regularExpression) != nil {
            let f=ISO8601DateFormatter(); if let d=f.date(from:s) { return d }; f.formatOptions.insert(.withFractionalSeconds); return f.date(from:s)
        }
        let p = s.count == 10 ? "yyyy-MM-dd" : (s.count == 16 ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd'T'HH:mm:ss")
        let f=DateFormatter(); f.locale=Locale(identifier:"en_US_POSIX"); f.timeZone=zone; f.dateFormat=p; f.isLenient=false
        guard let d=f.date(from:s), f.string(from:d)==s else { return nil }; return d
    }
    static func add(_ d: Date, days: Int) -> Date { cal.date(byAdding: .day, value: days, to: d)! }
    static func iso(_ d: Date) -> String { ISO8601DateFormatter().string(from: d) }
}

final class Database {
    var handle: OpaquePointer?
    let path: String
    init(_ path: String, readOnly: Bool = false) throws {
        self.path=path
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories:true)
        let openPath=readOnly ? URL(fileURLWithPath:path).absoluteString+"?immutable=1":path
        guard sqlite3_open_v2(openPath,&handle,readOnly ? (SQLITE_OPEN_READONLY|SQLITE_OPEN_URI) : (SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE),nil)==SQLITE_OK else { throw problem("No se pudo abrir SQLite") }
        sqlite3_busy_timeout(handle,3000)
        if !readOnly {try exec("PRAGMA journal_mode=WAL")}; try exec("PRAGMA foreign_keys=ON")
    }
    deinit { sqlite3_close(handle) }
    func exec(_ sql: String, _ args: [Any] = []) throws {
        _ = try query(sql,args)
    }
    func query(_ sql: String, _ args: [Any] = []) throws -> [Object] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle,sql,-1,&stmt,nil)==SQLITE_OK else { throw problem(String(cString:sqlite3_errmsg(handle))) }
        defer { sqlite3_finalize(stmt) }
        let transient=unsafeBitCast(-1,to:sqlite3_destructor_type.self)
        for (i,a) in args.enumerated() {
            let p=Int32(i+1)
            if a is NSNull { sqlite3_bind_null(stmt,p) }
            else if let n=a as? NSNumber { sqlite3_bind_double(stmt,p,n.doubleValue) }
            else { sqlite3_bind_text(stmt,p,String(describing:a),-1,transient) }
        }
        var rows=[Object](); var result=sqlite3_step(stmt)
        while result==SQLITE_ROW {
            var row=Object()
            for i in 0..<sqlite3_column_count(stmt) {
                let key=String(cString:sqlite3_column_name(stmt,i))
                switch sqlite3_column_type(stmt,i) {
                case SQLITE_INTEGER: row[key]=Int(sqlite3_column_int64(stmt,i))
                case SQLITE_FLOAT: row[key]=sqlite3_column_double(stmt,i)
                case SQLITE_TEXT: row[key]=String(cString:sqlite3_column_text(stmt,i))
                default: row[key]=NSNull()
                }
            }
            rows.append(row); result=sqlite3_step(stmt)
        }
        guard result==SQLITE_DONE else { throw problem(String(cString:sqlite3_errmsg(handle))) }; return rows
    }
    func transaction<T>(_ f: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        do { let value=try f(); try exec("COMMIT"); return value } catch { try? exec("ROLLBACK"); throw error }
    }
    func backup(to path: String) throws {
        var dest: OpaquePointer?; guard sqlite3_open(path,&dest)==SQLITE_OK else { throw problem("No se puede crear copia") }; defer{sqlite3_close(dest)}
        guard let b=sqlite3_backup_init(dest,"main",handle,"main") else { throw problem("SQLite no pudo iniciar copia consistente") }
        let result=sqlite3_backup_step(b,-1); let finish=sqlite3_backup_finish(b)
        guard result==SQLITE_DONE && finish==SQLITE_OK else { throw problem("Copia SQLite incompleta") }
    }
    func restore(from path: String) throws {
        var src: OpaquePointer?; guard sqlite3_open_v2(URL(fileURLWithPath:path).absoluteString+"?immutable=1",&src,SQLITE_OPEN_READONLY|SQLITE_OPEN_URI,nil)==SQLITE_OK else { throw problem("Copia ilegible") }; defer{sqlite3_close(src)}
        guard let b=sqlite3_backup_init(handle,"main",src,"main") else { throw problem("No se puede restaurar") }
        let step=sqlite3_backup_step(b,-1); let finish=sqlite3_backup_finish(b)
        guard step==SQLITE_DONE && finish==SQLITE_OK else { throw problem("Error al restaurar") }
    }
}
