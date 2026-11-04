// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

final class Store {
    let db: Database
    let resources: URL
    let directory: URL
    var timer: Object = [:]
    var pendingImport: Object?
    var pendingReplan: Object?
    let planKeys:Set<String>=["title","subject","topic","task","evaluation","category","uid","description","location","objective","references","criterion","dependencies","start","finish","date","dateEnd","rrule","exdates","series","recurrenceId","source","path","color","days","fromTime","toTime","reserve","cancelled","exception","tags"]
    init(directory: URL, resources: URL) throws {
        self.directory=directory;self.resources=resources
        db=try Database(directory.appendingPathComponent("universidad.sqlite").path)
        try migrate(); try seed()
        timer=object(try setting("timer"))
        if string(timer,"state")=="running" {try pauseTimer(at:Date(timeIntervalSince1970:number(timer,"last")),reason:"La aplicación se cerró con el cronómetro activo. Se conservó hasta el último guardado y se excluyó el tramo posterior. Revisa el tiempo antes de reanudar.")}
    }
    func migrate() throws {
        try db.exec("CREATE TABLE IF NOT EXISTS migrations(version INTEGER PRIMARY KEY, applied TEXT NOT NULL)")
        let v=(try db.query("SELECT MAX(version) AS n FROM migrations").first?["n"] as? Int) ?? 0
        if v<1 {try db.transaction {
            try db.exec("CREATE TABLE entities(id TEXT PRIMARY KEY, kind TEXT NOT NULL, plan TEXT NOT NULL, local TEXT NOT NULL DEFAULT '{}', user TEXT NOT NULL DEFAULT '{}', archived INTEGER NOT NULL DEFAULT 0)")
            try db.exec("CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try db.exec("INSERT INTO migrations VALUES(1,?)",[Dates.iso(Date())])
        }}
        if v<2 {try db.transaction {
            for table in ["time_records","doubts","attempts","reviews","audit"] {try db.exec("CREATE TABLE \(table)(id TEXT PRIMARY KEY, data TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)")}
            try db.exec("CREATE TABLE imports(id TEXT PRIMARY KEY, package TEXT NOT NULL, revision TEXT NOT NULL, digest TEXT NOT NULL, report TEXT NOT NULL, backup TEXT NOT NULL, UNIQUE(package,revision))")
            try db.exec("INSERT INTO migrations VALUES(2,?)",[Dates.iso(Date())])
        }}
        if v<3 {try db.transaction {
            try db.exec("CREATE INDEX entity_kind ON entities(kind,archived)")
            try db.exec("INSERT INTO migrations VALUES(3,?)",[Dates.iso(Date())])
        }}
    }
    func setting(_ key:String) throws -> String {string(try db.query("SELECT value FROM settings WHERE key=?",[key]).first ?? [:],"value")}
    func setSetting(_ key:String,_ val:String) throws {try db.exec("INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",[key,val])}
    func seed() throws {
        if !(try setting("seeded")).isEmpty{return}
        let seed=try JSONSerialization.jsonObject(with:Data(contentsOf:resources.appendingPathComponent("seed.json"))) as! Object
        try db.transaction {
            for e in seed["entities"] as! [Object] {
                try db.exec("INSERT OR IGNORE INTO entities(id,kind,plan,user) VALUES(?,?,?,?)",[string(e,"id"),string(e,"kind"),try json(e["plan"]!),try json(e["user"] ?? Object())])
            }
            try setSetting("context",try json(seed["context"]!));try setSetting("snapshot",string(seed,"snapshot"));try setSetting("seeded","1")
            try setSetting("materials","")
        }
    }
    func entities(includeArchived:Bool=false) throws -> [Object] {
        try db.query("SELECT * FROM entities"+(includeArchived ? "":" WHERE archived=0")).map {row in
            var e=object(string(row,"plan")); let local=object(string(row,"local"))
            e.merge(local){_,new in new}; e["id"]=row["id"];e["kind"]=row["kind"];e["user"]=object(string(row,"user"));e["archived"]=number(row,"archived") != 0;e["localFields"]=Array(local.keys);return e
        }
    }
    func entity(_ id:String) throws -> Object? {try entities(includeArchived:true).first{string($0,"id")==id}}
    func rows(_ table:String, deleted:Bool=false) throws -> [Object] {
        guard ["time_records","doubts","attempts","reviews","audit"].contains(table) else {throw problem("Tabla no permitida")}
        return try db.query("SELECT * FROM \(table)"+(deleted ? "":" WHERE deleted=0")).map {row in var d=object(string(row,"data"));d["id"]=row["id"];d["deleted"]=number(row,"deleted") != 0;return d}
    }
    func journal(_ table:String,_ data:Object) throws -> Object {
        guard ["time_records","doubts","attempts","reviews","audit"].contains(table) else {throw problem("Registro desconocido")}
        var d=data;let id=string(d,"id",identifier());d["id"]=id
        try db.exec("INSERT INTO \(table)(id,data) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data",[id,try json(d)]);return d
    }
    func audit(_ action:String,_ before:Object,_ after:Object) throws {
        _=try journal("audit",["action":action,"date":Dates.iso(Date()),"before":before,"after":after])
    }
    func events(from:Date,to:Date) throws -> [Object] {
        guard to>from, to.timeIntervalSince(from)<100*86400 else {throw problem("Consulta de calendario limitada a 99 días")}
        let all=try entities(), overrides=Dictionary(uniqueKeysWithValues:all.filter{string($0,"kind")=="occurrence"}.map{(string($0,"id"),$0)})
        var out=[Object]()
        for e in all {
            switch string(e,"kind") {
            case "series":
                out += try AcademicCalendar.occurrences(e,from:from,to:to).filter {overrides[string($0,"id")]==nil}
            case "event","occurrence":
                let value=string(e,"start",string(e,"date"))
                if let d=Dates.parse(value),d<to,(Dates.parse(string(e,"finish")) ?? d)>=from, !(e["cancelled"] as? Bool ?? false) {out.append(e)}
            case "availability":
                var day=Dates.cal.startOfDay(for:from)
                while day<to {
                    if string(e,"days").components(separatedBy:",").contains(AcademicCalendar.weekdays[Dates.cal.component(.weekday,from:day)-1]) {
                        var a=e;a["id"]=string(e,"id")+"#"+Dates.format(day,"yyyy-MM-dd");a["category"]="availability";a["start"]=Dates.format(day,"yyyy-MM-dd")+"T"+string(e,"fromTime")+":00";a["finish"]=Dates.format(day,"yyyy-MM-dd")+"T"+string(e,"toTime")+":00";out.append(a)
                    };day=Dates.add(day,days:1)
                }
            default:break
            }
        }
        return out.sorted{string($0,"start",string($0,"date"))<string($1,"start",string($1,"date"))}
    }
    func snapshot(_ params:Object=[:]) throws -> Object {
        let now=Date(),from=Dates.parse(string(params,"from")) ?? Dates.add(Dates.cal.startOfDay(for:now),days:-7),to=Dates.parse(string(params,"to")) ?? Dates.add(from,days:49)
        return ["entities":try entities().map { e -> Object in
            var value=e
            if string(e,"kind")=="source" {
                let root=(try? setting("materials")) ?? "", relative=string(e,"path").components(separatedBy:"/Universidad/").last ?? ""
                value["available"]=FileManager.default.fileExists(atPath:URL(fileURLWithPath:root).appendingPathComponent(relative).path)
            };return value
        },"events":try events(from:from,to:to),"times":try rows("time_records"),"doubts":try rows("doubts"),"attempts":try rows("attempts"),"reviews":try rows("reviews"),"timer":timer,"settings":["snapshot":try setting("snapshot"),"materials":try setting("materials"),"theme":try setting("theme"),"menuBar":try setting("menuBar"),"reminders":object(try setting("reminders"))],"context":object(try setting("context")),"now":Dates.iso(now),"imports":try db.query("SELECT * FROM imports ORDER BY rowid DESC"),"dataPath":db.path,"backups":try backups()]
    }
    func saveEntity(_ p:Object) throws -> Object {
        var incoming=p;let id=string(p,"id",identifier()),kind=string(p,"kind","event");incoming["id"]=id
        let old=try entity(id) ?? [:]
        let plan=incoming.filter{planKeys.contains($0.key)}
        guard !string(plan,"title").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {throw problem("Falta título")}
        if ["event","occurrence","series"].contains(kind) {
            guard let start=Dates.parse(string(plan,"start",string(plan,"date"))) else {throw problem("Fecha de inicio inválida")}
            if let end=plan["finish"] as? String {guard let finish=Dates.parse(end),finish>start,finish.timeIntervalSince(start)<=86400 else {throw problem("La duración debe ser positiva y menor de un día")}}
        }
        let known=Set(try entities().map{string($0,"id")})
        for key in ["subject","topic","task","evaluation"] where !string(plan,key).isEmpty {if !known.contains(string(plan,key)){throw problem("Referencia \(key) inexistente")}}
        if string(p,"kind")=="series" {_=try AcademicCalendar.rules(string(p,"rrule"))}
        try validatePlans([["id":id,"tipo":kind,"plan":plan]])
        try db.transaction {
            if old.isEmpty {try db.exec("INSERT INTO entities(id,kind,plan,local) VALUES(?,?,?,?)",[id,kind,try json(plan),try json(plan)])}
            else {
                let row=try db.query("SELECT plan,local FROM entities WHERE id=?",[id]).first!;let base=object(string(row,"plan"));var local=object(string(row,"local"))
                for (k,v) in plan { if try json(v) != json(base[k] ?? NSNull()) {local[k]=v} else {local.removeValue(forKey:k)} }
                try db.exec("UPDATE entities SET local=? WHERE id=?",[try json(local),id])
            }
            if old.isEmpty && kind=="subject" {
                let topic:Object=["title":"General","subject":id]
                try db.exec("INSERT OR IGNORE INTO entities(id,kind,plan) VALUES(?,'topic',?)",[id+"-plan",try json(topic)])
            }
            if let user=p["user"] as? Object {try saveUser(id,user)}
            try audit("editar elemento",old,incoming)
        };return try entity(id)!
    }
    func saveUser(_ id:String,_ p:Object) throws {
        if let components=p["gradeComponents"] {try validateGradeComponents(components)}
        if try db.query("SELECT id FROM entities WHERE id=?",[id]).isEmpty, let sep=id.firstIndex(of:"#") {
            let seriesId=String(id[..<sep]),key=String(id[id.index(after:sep)...])
            if let series=try entity(seriesId),let date=Dates.parse(key),let occurrence=try AcademicCalendar.occurrences(series,from:date,to:Dates.add(date,days:1)).first(where:{string($0,"id")==id}) {
                let plan=occurrence.filter{planKeys.contains($0.key)}
                try db.exec("INSERT INTO entities(id,kind,plan) VALUES(?,'occurrence',?)",[id,try json(plan)])
            }
        }
        guard let row=try db.query("SELECT user FROM entities WHERE id=?",[id]).first else {throw problem("Elemento no localizado")}
        if let grade=p["grade"] as? NSNumber, !(0...10).contains(grade.doubleValue) {throw problem("Nota entre 0 y 10 o desconocida")}
        if let status=p["status"] as? String, !["pendiente","en curso","bloqueada","completada","necesita repaso"].contains(status) {throw problem("Estado de tarea no válido")}
        if let evidence=p["evidence"] as? String, !["pendiente de comprobar","explicado","practicado con ayuda","resuelto sin ayuda"].contains(evidence) {throw problem("Evidencia no válida")}
        var u=object(string(row,"user"));u.merge(p){_,new in new}
        try db.exec("UPDATE entities SET user=? WHERE id=?",[try json(u),id])
    }
    func moveIssues(_ event:Object) throws -> [String] {
        guard let start=Dates.parse(string(event,"start")),let finish=Dates.parse(string(event,"finish")),finish>start else {return ["La sesión necesita inicio y fin válidos"]}
        var issues=[String]();let minutes=finish.timeIntervalSince(start)/60
        if minutes<15 || minutes>240 {issues.append("Duración fuera del intervalo de 15–240 minutos")}
        if Dates.cal.component(.hour,from:finish)>22 || Dates.cal.component(.hour,from:start)<8 || (Dates.cal.component(.hour,from:finish)==22 && Dates.cal.component(.minute,from:finish)>0) {issues.append("El bloque invade el descanso (08:00–22:00)")}
        let same=try events(from:Dates.cal.startOfDay(for:start),to:Dates.add(Dates.cal.startOfDay(for:finish),days:1))
        for e in same where string(e,"id") != string(event,"id") && string(e,"category") != "exam" && e["start"] != nil {
            guard let a=Dates.parse(string(e,"start")),let b=Dates.parse(string(e,"finish")) else {continue}
            if start<b && finish>a {issues.append("Solapa con \(string(e,"title"))")}
            else if string(e,"category")=="study" {
                let gap=min(abs(start.timeIntervalSince(b)),abs(a.timeIntervalSince(finish)))/60
                let need=string(event,"location")==string(e,"location") ? 15.0:30.0
                if gap<need {issues.append("Pausa/traslado insuficiente: \(Int(need)) min junto a \(string(e,"title"))")}
            }
        }
        let all=try entities(),task=all.first{string($0,"id")==string(event,"task")}
        let directEvaluation=string(event,"evaluation"),evalId=directEvaluation.isEmpty ? string(task ?? [:],"evaluation"):directEvaluation
        if let eval=all.first(where:{string($0,"id")==evalId}),let deadline=Dates.parse(string(eval,"start",string(eval,"date"))) {
            let isDate=eval["date"] != nil
            if (isDate ? Dates.cal.startOfDay(for:finish)>=deadline : finish>deadline) {issues.append("Termina después de la prueba vinculada: \(string(eval,"title"))")}
        }
        for dep in task?["dependencies"] as? [String] ?? [] {
            if let t=all.first(where:{string($0,"id")==dep}),string(t["user"] as? Object ?? [:],"status") != "completada" {issues.append("Dependencia pendiente: \(string(t,"title"))")}
        }
        return Array(Set(issues)).sorted()
    }
    func alternative(_ e:Object) throws -> Object? {
        guard let start=Dates.parse(string(e,"start")),let finish=Dates.parse(string(e,"finish")) else {return nil}
        let duration=finish.timeIntervalSince(start);if duration<900 || duration>14400{return nil}
        for day in 0..<22 {
            let d=Dates.add(start,days:day),weekday=Dates.cal.component(.weekday,from:d)
            let first=(weekday==1 || weekday==7) ? 10*60+30 : 16*60+30
            for minute in stride(from:first,through:22*60-Int(duration/60),by:15) {
                let stamp=Dates.cal.date(bySettingHour:minute/60,minute:minute%60,second:0,of:d)!
                if stamp<start {continue};var candidate=e;candidate["start"]=Dates.format(stamp);candidate["finish"]=Dates.format(stamp.addingTimeInterval(duration))
                if try moveIssues(candidate).isEmpty {return candidate}
            }
        };return nil
    }
    func backups() throws -> [String] {
        let folder=directory.appendingPathComponent("Copias");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return try FileManager.default.contentsOfDirectory(atPath:folder.path).filter{$0.hasSuffix(".sqlite")}.sorted().reversed()
    }
    func backup(_ name:String="copia") throws -> String {
        _=try backups()
        let url=directory.appendingPathComponent("Copias/\(Dates.format(Date(),"yyyyMMdd-HHmmss"))-\(name)-\(identifier().prefix(6)).sqlite")
        try db.backup(to:url.path);return url.path
    }
    func restore(_ path:String) throws {
        guard string(timer,"state").isEmpty else {throw problem("Finaliza el cronómetro antes de restaurar")}
        guard URL(fileURLWithPath:path).resolvingSymlinksInPath().path != URL(fileURLWithPath:db.path).resolvingSymlinksInPath().path else {throw problem("No puedes restaurar la base que está abierta. Elige una copia exportada.")}
        if let attrs=try? FileManager.default.attributesOfItem(atPath:path+"-wal"),let size=attrs[.size] as? NSNumber,size.intValue>0 {throw problem("El archivo tiene cambios WAL en uso. Exporta una copia consistente antes de restaurar.")}
        let test=try Database(path,readOnly:true)
        guard string(try test.query("PRAGMA integrity_check").first ?? [:],"integrity_check")=="ok",!(try test.query("SELECT * FROM settings WHERE key='seeded'")).isEmpty,
              (try test.query("SELECT MAX(version) AS n FROM migrations").first?["n"] as? Int)==3 else {throw problem("La copia no es compatible o está dañada")}
        for table in ["entities","time_records","doubts","attempts","reviews","audit","imports"] {_=try test.query("SELECT * FROM \(table) LIMIT 1")}
        guard try test.query("SELECT id FROM entities WHERE NOT json_valid(plan) OR NOT json_valid(local) OR NOT json_valid(user) LIMIT 1").isEmpty else {throw problem("Copia con datos JSON dañados")}
        for table in ["time_records","doubts","attempts","reviews","audit"] {
            guard try test.query("SELECT id FROM \(table) WHERE NOT json_valid(data) LIMIT 1").isEmpty else {throw problem("Copia con registros dañados en \(table)")}
        }
        let contextRow=try test.query("SELECT value FROM settings WHERE key='context'").first
        guard let raw=contextRow?["value"] as? String,let context=(try? JSONSerialization.jsonObject(with:Data(raw.utf8))) as? Object,context["user_confirmations"] is [Any],context["known_conflicts"] is [Any] else {throw problem("Copia con contexto inicial ausente o dañado")}
        _=try backup("antes-restaurar");try db.restore(from:path);pendingReplan=nil;pendingImport=nil;timer=object(try setting("timer"))
        if string(timer,"state")=="running" {try pauseTimer(at:Date(timeIntervalSince1970:number(timer,"last")),reason:"Cronómetro recuperado de copia; tramo de ausencia excluido.")}
    }
}
