// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

extension Store {
    func examPreparation(_ id:String) throws -> Object {
        let all=try entities()
        guard let exam=all.first(where:{string($0,"id")==id && string($0,"category")=="exam"}) else {throw problem("Prueba no localizada")}
        let explicitSessions=all.filter{string($0,"category")=="study" && string($0,"evaluation")==id}
        let explicitTasks=Set(explicitSessions.map{string($0,"task")})
        let tasks=all.filter{string($0,"kind")=="task" && (string($0,"evaluation")==id || explicitTasks.contains(string($0,"id")))}.sorted{string($0,"id")<string($1,"id")}
        let taskIDs=Set(tasks.map{string($0,"id")})
        let sessions=all.filter{string($0,"category")=="study" && (string($0,"evaluation")==id || (string($0,"evaluation").isEmpty && taskIDs.contains(string($0,"task")))) && $0["cancelled"] as? Bool != true}.sorted{string($0,"start")<string($1,"start")}
        let eventIDs=Set(sessions.map{string($0,"id")}+[id])
        func linked(_ row:Object) -> Bool {taskIDs.contains(string(row,"task")) || eventIDs.contains(string(row,"event"))}
        let attempts=try rows("attempts").filter(linked).sorted{string($0,"date")>string($1,"date")}
        let doubts=try rows("doubts").filter(linked).sorted{string($0,"date")>string($1,"date")}
        let times=try rows("time_records").filter(linked)
        let refs=([exam]+tasks+sessions).map{string($0,"references")+" "+string($0,"source")}.joined(separator:"\n")
        let root=try setting("materials")
        let materials=all.filter {source in
            guard string(source,"kind")=="source" else{return false}
            let pattern="(?<![A-Za-z0-9_-])"+NSRegularExpression.escapedPattern(for:string(source,"id"))+"(?![A-Za-z0-9_-])"
            return refs.range(of:pattern,options:.regularExpression) != nil
        }.sorted{string($0,"id")<string($1,"id")}.map{source -> Object in
            var row=source
            let path=string(source,"path"),marker="/Universidad/"
            let relative=path.range(of:marker).map{String(path[$0.upperBound...])} ?? path
            row["available"]=FileManager.default.fileExists(atPath:URL(fileURLWithPath:root).appendingPathComponent(relative).path)
            return row
        }
        let conflicts=(object(try setting("context"))["known_conflicts"] as? [Object] ?? []).filter{string($0,"subject_id")==string(exam,"subject")}
        // Counts describe saved evidence, never a readiness percentage or inferred mastery.
        let summary:Object=["tasks":tasks.count,"completed":tasks.filter{string($0["user"] as? Object ?? [:],"status")=="completada"}.count,
                            "unaided":tasks.filter{string($0["user"] as? Object ?? [:],"evidence")=="resuelto sin ayuda"}.count,
                            "openDoubts":doubts.filter{string($0,"status") != "resuelta"}.count,"seconds":times.reduce(0.0){$0+number($1,"seconds")}]
        return ["exam":exam,"tasks":tasks,"sessions":sessions,"attempts":attempts,"doubts":doubts,"materials":materials,"conflicts":conflicts,"summary":summary]
    }
}
