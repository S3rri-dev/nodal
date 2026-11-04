// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

// Pure proposal over a simulated calendar; only apply/undo writes local date overrides.
private struct PlanningBlock {
    let start: Date, finish: Date, study: Bool, location: String
}
extension Store {
    func calendarFingerprint() throws -> String {
        digest(Data(try json(db.query("SELECT id,kind,plan,local,archived FROM entities ORDER BY id")).utf8))
    }
    func replanCandidates(at now:Date=Date()) throws -> Object {
        let sessions=try entities().filter {
            string($0,"kind")=="event" && string($0,"category")=="study" && $0["reserve"] as? Bool != true && $0["cancelled"] as? Bool != true &&
            string($0["user"] as? Object ?? [:],"status") != "completada" && Dates.parse(string($0,"start")) != nil && Dates.parse(string($0,"finish")) != nil
        }.sorted {string($0,"start")<string($1,"start")}.map { e -> Object in
            var row=e;row["overdue"]=(Dates.parse(string(e,"finish"))! <= now);return row
        }
        let last=object(try setting("lastReplan"))
        return ["sessions":sessions,"last":last.isEmpty ? Object():["id":string(last,"id"),"date":string(last,"date"),"count":number(last,"count"),"undone":last["undone"] as? Bool ?? false]]
    }
    private func guardReplanTimer(_ sessions:[Object]) throws {
        guard timer.isEmpty || !sessions.contains(where:{string($0,"id")==string(timer,"event") || (!string($0,"task").isEmpty && string($0,"task")==string(timer,"task"))}) else {
            throw problem("Finaliza el cronómetro de estas sesiones antes de reorganizarlas")
        }
    }
    func previewReplan(_ params:Object,at now:Date=Date()) throws -> Object {
        pendingReplan=nil
        guard let ids=params["ids"] as? [String],!ids.isEmpty,ids.count<=50,Set(ids).count==ids.count else {throw problem("Selecciona entre 1 y 50 sesiones distintas")}
        let all=try entities(),byID=Dictionary(uniqueKeysWithValues:all.map{(string($0,"id"),$0)})
        let allowed=(try replanCandidates(at:now))["sessions"] as! [Object]
        let sessions=try ids.map {id -> Object in
            guard let e=allowed.first(where:{string($0,"id")==id}) else {throw problem("La sesión ya no está disponible: \(id)")};return e
        }
        try guardReplanTimer(sessions)
        let horizon=number(params,"days",21)
        guard horizon.rounded()==horizon,horizon>=1,horizon<=42,
              let first=Dates.parse(string(params,"from",Dates.format(now,"yyyy-MM-dd"))),first>=Dates.cal.startOfDay(for:now),first<=Dates.add(now,days:28) else {throw problem("Elige una fecha desde hoy y un horizonte de 1–42 días")}
        func minute(_ key:String,_ fallback:String) throws -> Int {
            let s=string(params,key,fallback),parts=s.split(separator:":").compactMap{Int($0)}
            guard parts.count==2,parts[1]>=0,parts[1]<60,parts[1]%15==0,parts[0]>=8,parts[0]<22 else {throw problem("Las franjas deben comenzar entre 08:00 y 21:45, en cuartos de hora")};return parts[0]*60+parts[1]
        }
        let weekday=try minute("weekday","16:30"),weekend=try minute("weekend","10:30"),until=Dates.add(first,days:Int(horizon))
        let fixed=try events(from:first,to:until).filter{!ids.contains(string($0,"id")) && $0["cancelled"] as? Bool != true}
        var blocks=[PlanningBlock](),warnings=Set<String>()
        for e in fixed {
            if let date=Dates.parse(string(e,"date")) {
                // Unknown exam hours reserve that date, rather than inventing a duration.
                if string(e,"category")=="exam" {blocks.append(PlanningBlock(start:date,finish:Dates.parse(string(e,"dateEnd")) ?? Dates.add(date,days:1),study:false,location:""));warnings.insert("Pruebas sin hora: se reserva su día completo.")};continue
            }
            guard let a=Dates.parse(string(e,"start")) else {continue}
            let b=Dates.parse(string(e,"finish")) ?? Dates.add(Dates.cal.startOfDay(for:a),days:1)
            if e["finish"] == nil {warnings.insert("Eventos sin fin: se reserva el resto de su día, sin inventar su duración.")}
            blocks.append(PlanningBlock(start:a,finish:b,study:string(e,"category")=="study",location:string(e,"location")))
        }
        func evaluationID(_ e:Object) -> String {
            let direct=string(e,"evaluation")
            return direct.isEmpty ? string(byID[string(e,"task")] ?? [:],"evaluation"):direct
        }
        func deadline(_ e:Object) -> Date? {
            let exam=byID[evaluationID(e)] ?? [:]
            return Dates.parse(string(exam,"start",string(exam,"date")))
        }
        var remaining=sessions.sorted {
            let a=deadline($0) ?? .distantFuture,b=deadline($1) ?? .distantFuture
            if a != b {return a<b};if string($0,"start") != string($1,"start"){return string($0,"start")<string($1,"start")};return string($0,"id")<string($1,"id")
        }
        let selectedTasks=Set(sessions.map{string($0,"task")}.filter{!$0.isEmpty})
        var rows=[Object](),taskEnds=[String:Date](),failedTasks=Set<String>()
        func dependencies(_ e:Object) -> [String] {(byID[string(e,"task")]?["dependencies"] as? [String] ?? []).filter {string(byID[$0]?["user"] as? Object ?? [:],"status") != "completada"}}
        while !remaining.isEmpty {
            let index=remaining.firstIndex {e in
                !dependencies(e).contains {dep in selectedTasks.contains(dep) && !failedTasks.contains(dep) && remaining.contains{string($0,"task")==dep}}
            } ?? 0
            let e=remaining.remove(at:index),taskID=string(e,"task"),deps=dependencies(e)
            var row:Object=["id":string(e,"id"),"title":string(e,"title"),"subject":string(e,"subject"),"oldStart":string(e,"start"),"oldFinish":string(e,"finish")]
            let duration=Dates.parse(string(e,"finish"))!.timeIntervalSince(Dates.parse(string(e,"start"))!)
            var reason="",found:Date?
            if duration<900 || duration>14400 {reason="Duración fuera de 15–240 minutos"}
            else if !evaluationID(e).isEmpty && byID[evaluationID(e)] == nil {reason="Prueba vinculada archivada o no disponible: revisa el vínculo"}
            else if let dep=deps.first(where:{taskEnds[$0]==nil || failedTasks.contains($0)}) {reason="Dependencia sin completar o sin sesión previa en la propuesta: \(string(byID[dep] ?? [:],"title",dep))"}
            else {
                let earliest=max(now,deps.compactMap{taskEnds[$0]}.max() ?? now,taskEnds[taskID] ?? now)
                let limit=deadline(e) ?? until
                search: for offset in 0..<Int(horizon) {
                    let d=Dates.add(first,days:offset),wd=Dates.cal.component(.weekday,from:d),begin=(wd==1 || wd==7) ? weekend:weekday
                    for m in stride(from:begin,through:22*60-Int(ceil(duration/60)),by:15) {
                        let a=Dates.cal.date(bySettingHour:m/60,minute:m%60,second:0,of:d)!,b=a.addingTimeInterval(duration)
                        if a<earliest || b>limit {continue}
                        if blocks.contains(where:{block in
                            if a<block.finish && b>block.start {return true}
                            guard block.study else{return false}
                            let gap=min(abs(a.timeIntervalSince(block.finish)),abs(block.start.timeIntervalSince(b)))
                            return gap < (string(e,"location")==block.location ? 900:1800)
                        }) {continue}
                        found=a;break search
                    }
                }
                if found == nil {reason=deadline(e).map{$0<=now ? "La prueba vinculada ya ha pasado: revisa su fecha o el vínculo":"Sin hueco antes de la prueba vinculada y dentro de la franja elegida"} ?? "Sin hueco en el horizonte y la franja elegidos"}
            }
            if let start=found {
                let finish=start.addingTimeInterval(duration)
                row["start"]=Dates.format(start);row["finish"]=Dates.format(finish)
                row["unchanged"]=start==Dates.parse(string(e,"start")) && finish==Dates.parse(string(e,"finish"))
                blocks.append(PlanningBlock(start:start,finish:finish,study:true,location:string(e,"location")))
                if !taskID.isEmpty {taskEnds[taskID]=finish}
                if !deps.isEmpty {warnings.insert("Las dependencias se ordenan en el horario; siguen pendientes de comprobar al estudiar.")}
            } else {row["reason"]=reason;if !taskID.isEmpty {failedTasks.insert(taskID)}}
            rows.append(row)
        }
        let result:Object=["token":identifier(),"fingerprint":try planFingerprint(),"created":now.timeIntervalSince1970,"rows":rows,"warnings":warnings.sorted(),"from":Dates.format(first,"yyyy-MM-dd"),"until":Dates.format(until,"yyyy-MM-dd"),"weekday":string(params,"weekday","16:30"),"weekend":string(params,"weekend","10:30")]
        pendingReplan=result;return result
    }
    func applyReplan(_ params:Object,at now:Date=Date()) throws -> Object {
        guard let p=pendingReplan,string(p,"token")==string(params,"token"),now.timeIntervalSince1970-number(p,"created")<900,
              string(p,"fingerprint")==(try planFingerprint()) else {throw problem("La propuesta ha caducado o los datos han cambiado. Genera otra vista previa.")}
        let rows=p["rows"] as! [Object],moves=rows.filter{$0["start"] != nil && $0["unchanged"] as? Bool != true},unplaced=rows.filter{$0["start"] == nil}
        guard !moves.isEmpty else {throw problem("La propuesta no contiene cambios aplicables")}
        guard unplaced.isEmpty || params["acceptPartial"] as? Bool==true else {throw problem("Confirma que las sesiones sin hueco quedarán sin mover")}
        guard moves.allSatisfy({Dates.parse(string($0,"start"))!>=now}) else {throw problem("Una hora propuesta ya ha pasado. Genera otra vista previa.")}
        try guardReplanTimer(try moves.compactMap{try entity(string($0,"id"))})
        let copy=try backup("antes-reorganizar")
        let id=identifier()
        try db.transaction {
            guard string(p,"fingerprint")==(try planFingerprint()) else {throw problem("El plan cambió antes de aplicar. Genera otra propuesta.")}
            var changes=[Object]()
            for move in moves {
                let eid=string(move,"id"),raw=try db.query("SELECT local FROM entities WHERE id=?",[eid]).first!,before=string(raw,"local")
                var local=object(before);local["start"]=move["start"];local["finish"]=move["finish"]
                let after=try json(local);try db.exec("UPDATE entities SET local=? WHERE id=?",[after,eid])
                changes.append(["id":eid,"before":before,"after":after])
            }
            let history:Object=["id":id,"date":Dates.iso(now),"count":moves.count,"changes":changes,"calendarAfter":try calendarFingerprint(),"undone":false,"backup":copy]
            try setSetting("lastReplan",try json(history));try audit("reorganizar sesiones",["rows":rows],history)
        }
        pendingReplan=nil
        return ["id":id,"count":moves.count,"unplaced":unplaced.count,"backup":copy]
    }
    func undoReplan(_ id:String) throws -> Object {
        let last=object(try setting("lastReplan"))
        guard !id.isEmpty,string(last,"id")==id,last["undone"] as? Bool==false,let changes=last["changes"] as? [Object] else {throw problem("No hay una reorganización disponible para deshacer")}
        guard string(last,"calendarAfter")==(try calendarFingerprint()) else {throw problem("El plan ha cambiado después de reorganizar. No se deshace para evitar sobrescribir esos cambios; puedes consultar la copia anterior.")}
        try guardReplanTimer(try changes.compactMap{try entity(string($0,"id"))})
        let copy=try backup("antes-deshacer-reorganizacion")
        try db.transaction {
            guard string(last,"calendarAfter")==(try calendarFingerprint()) else {throw problem("El plan cambió antes de deshacer; se ha conservado sin sobrescribir.")}
            for change in changes {try db.exec("UPDATE entities SET local=? WHERE id=?",[string(change,"before"),string(change,"id")])}
            var undone=last;undone["undone"]=true;try setSetting("lastReplan",try json(undone));try audit("deshacer reorganización",last,undone)
        }
        pendingReplan=nil;return ["count":changes.count,"backup":copy]
    }
}
