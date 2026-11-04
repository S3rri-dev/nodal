// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
extension Store {
    func splitSession(_ params:Object) throws -> Object {
        guard let e=try entity(string(params,"id")),let reserve=try entity(string(params,"reserve")),reserve["reserve"] as? Bool==true,
              let start=Dates.parse(string(e,"start")),let end=Dates.parse(string(e,"finish")),let target=Dates.parse(string(reserve,"start")),let targetEnd=Dates.parse(string(reserve,"finish")),target>start else{throw problem("Sesión o reserva no válida")}
        let splitting=string(params,"operation")=="split",first=number(params,"minutes")*60,total=end.timeIntervalSince(start)
        if splitting && (first<900 || first>total-900) {throw problem("Cada parte debe durar al menos 15 minutos")}
        let remaining=splitting ? total-first:total
        guard remaining<=targetEnd.timeIntervalSince(target) else {throw problem("La reserva es más corta que el bloque. Reduce o divide la sesión.")}
        var rest=e;rest["id"]=string(reserve,"id");rest["uid"]=string(reserve,"uid");rest["start"]=Dates.format(target);rest["finish"]=Dates.format(target.addingTimeInterval(remaining));rest["reserve"]=false;rest["kind"]="event";rest.removeValue(forKey:"user")
        let issues=try moveIssues(rest)
        guard issues.isEmpty else {throw problem("Reserva incompatible: "+issues.joined(separator:" · "))}
        try db.transaction {
            if splitting {var firstPart=e;firstPart["finish"]=Dates.format(start.addingTimeInterval(first));_=try saveEntity(firstPart)}
            else {try db.exec("UPDATE entities SET archived=1 WHERE id=?",[string(e,"id")])}
            _=try saveEntity(rest)
        };return ["report":splitting ? "Sesión dividida; reserva sustituida":"Sesión movida; reserva sustituida"]
    }
    func subjectSummary(_ id:String) throws -> String {
        let all=try entities();guard let subject=all.first(where:{string($0,"id")==id}) else{throw problem("Asignatura no localizada")}
        let tasks=all.filter{string($0,"kind")=="task" && string($0,"subject")==id},times=try rows("time_records").filter{string($0,"subject")==id}
        var text="# \(string(subject,"title"))\n\nRevisión \(Dates.format(Date(),"dd/MM/yyyy HH:mm"))\nTiempo efectivo: \(Int(times.reduce(0.0){$0+number($1,"seconds")}/60)) min\n\n## Tareas y evidencia\n"
        for t in tasks {let u=t["user"] as? Object ?? [:];text+="- \(string(t,"id")) · \(string(t,"title")): \(string(u,"status","pendiente")); evidencia: \(string(u,"evidence","pendiente de comprobar"))\n  \(string(u,"notes"))\n"}
        text+="\n## Intentos\n"
        for a in try rows("attempts").filter({string($0,"subject")==id}){text+="- \(string(a,"task")): \(string(a,"evidence")) · \(string(a,"notes"))\n"}
        text+="\n## Dudas\n"
        for d in try rows("doubts").filter({string($0,"subject")==id}){text+="- [\(string(d,"status"))] \(string(d,"question")) · \(string(d,"reference"))\n"}
        return text
    }
}
