// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
func verifyPlanningFeatures(resources:URL,root:URL) throws {
    let dir=root.appendingPathComponent("build/features-"+identifier()),s=try Store(directory:dir,resources:resources)
    try s.db.exec("DELETE FROM entities")
    func add(_ id:String,_ kind:String,_ p:Object,_ user:Object=[:]) throws {try s.db.exec("INSERT INTO entities(id,kind,plan,user) VALUES(?,?,?,?)",[id,kind,try json(p),try json(user)])}
    try add("DEMO","subject",["title":"Asignatura sintética"])
    try add("EX","event",["title":"Prueba sintética","subject":"DEMO","category":"exam","date":"2030-01-18"])
    try add("T1","task",["title":"Tarea A","subject":"DEMO","evaluation":"EX","dependencies":[],"references":"PDF-A pp.1–2"])
    try add("T2","task",["title":"Tarea B","subject":"DEMO","evaluation":"EX","dependencies":["T1"]])
    try add("OTHER","task",["title":"Otra tarea","subject":"DEMO","dependencies":[]])
    try add("PDF-A","source",["title":"Material sintético","path":"/ficticio.pdf"])
    for (id,task) in [("A","T1"),("B","T2"),("C","OTHER")] {
        try add(id,"event",["title":"Sesión "+id,"subject":"DEMO","task":task,"category":"study","location":"Casa","start":"2030-01-06T17:00:00","finish":"2030-01-06T18:00:00"],["notes":"Conservar "+id])
    }
    try add("CLASS","event",["title":"Clase fija","category":"class","start":"2030-01-07T16:30:00","finish":"2030-01-07T18:00:00"])
    try add("FIXED","event",["title":"Sesión fija","category":"study","location":"Biblioteca","start":"2030-01-07T19:30:00","finish":"2030-01-07T20:30:00"],["status":"completada"])
    let now=Dates.parse("2030-01-07T09:00:00")!,params:Object=["ids":["B","A"],"from":"2030-01-07","days":7]
    let initial=try s.planFingerprint(),p=try s.previewReplan(params,at:now),rows=p["rows"] as! [Object]
    let a=rows.first{string($0,"id")=="A"}!,b=rows.first{string($0,"id")=="B"}!
    try check(try s.planFingerprint()==initial,"preview de lote no escribe SQLite")
    try check(string(a,"start")=="2030-01-07T18:00:00","respeta clase y traslado de 30 min a sesión fija")
    try check(string(b,"start")>=string(a,"finish"),"ordena dependencia dentro del lote")
    try check(!(p["warnings"] as! [String]).isEmpty,"dependencia prevista no se declara aprendida")
    try rejects("IDs duplicados"){_=try s.previewReplan(["ids":["A","A"]],at:now)}
    try rejects("sesión completada"){_=try s.previewReplan(["ids":["FIXED"]],at:now)}
    try rejects("fecha pasada"){_=try s.previewReplan(["ids":["A"],"from":"2030-01-06"],at:now)}
    let missing=try s.previewReplan(["ids":["B"],"from":"2030-01-07"],at:now)
    try check((missing["rows"] as! [Object])[0]["reason"] != nil,"explica dependencia pendiente fuera del lote")
    let preview=try s.previewReplan(params,at:now)
    try s.saveUser("A",["notes":"Cambio después de preview"])
    try rejects("preview obsoleto"){_=try s.applyReplan(["token":preview["token"]!],at:now)}
    let ready=try s.previewReplan(params,at:now)
    let applied=try s.applyReplan(["token":ready["token"]!],at:now)
    try check(number(applied,"count")==2 && FileManager.default.fileExists(atPath:string(applied,"backup")),"aplica lote con copia consistente")
    try check(string(try s.entity("FIXED")!,"start")=="2030-01-07T19:30:00","no mueve sesión fuera del lote")
    try check(string(try s.entity("A")!["user"] as! Object,"notes")=="Cambio después de preview","conserva estado personal al aplicar")
    try rejects("aplicar dos veces"){_=try s.applyReplan(["token":ready["token"]!],at:now)}
    try s.saveUser("T1",["evidence":"resuelto sin ayuda","status":"completada"])
    try s.saveUser("A",["notes":"Nota posterior"])
    _=try s.journal("time_records",["task":"T1","subject":"DEMO","seconds":120])
    _=try s.journal("attempts",["task":"T1","evidence":"resuelto sin ayuda","date":"2030-01-07"])
    _=try s.journal("attempts",["task":"OTHER","evidence":"practicado con ayuda"])
    _=try s.journal("doubts",["event":"A","status":"abierta","question":"Duda vinculada"])
    _=try s.journal("doubts",["subject":"DEMO","status":"abierta","question":"Duda general"])
    let restarted=try Store(directory:dir,resources:resources)
    _=try restarted.undoReplan(string(applied,"id"))
    try check(string(try restarted.entity("A")!,"start")=="2030-01-06T17:00:00","deshacer persiste al reiniciar")
    try check(string(try restarted.entity("A")!["user"] as! Object,"notes")=="Nota posterior","deshacer conserva notas posteriores")
    try check(try restarted.rows("time_records").count==1 && string(restarted.entity("T1")!["user"] as! Object,"status")=="completada","deshacer conserva tiempo y progreso posteriores")
    try rejects("deshacer dos veces"){_=try restarted.undoReplan(string(applied,"id"))}
    let dossier=try restarted.examPreparation("EX"),summary=dossier["summary"] as! Object
    try check((dossier["tasks"] as! [Object]).count==2 && (dossier["sessions"] as! [Object]).count==2,"ficha solo reúne vínculos explícitos con prueba")
    try check(number(summary,"unaided")==1 && number(summary,"completed")==1 && number(summary,"seconds")==120,"ficha distingue evidencia, estado y tiempo")
    try check((dossier["attempts"] as! [Object]).count==1 && number(summary,"openDoubts")==1,"no mezcla intentos o dudas generales de asignatura")
    try check((dossier["materials"] as! [Object]).count==1 && (dossier["exam"] as! Object)["start"]==nil,"material vinculado y hora desconocida conservada")
    try rejects("ficha de sesión en lugar de prueba"){_=try restarted.examPreparation("A")}
    let prepBefore=try restarted.planFingerprint();_=try restarted.examPreparation("EX")
    try check(try restarted.planFingerprint()==prepBefore,"consulta de ficha no cambia el progreso")
    let ready2=try restarted.previewReplan(params,at:now),applied2=try restarted.applyReplan(["token":ready2["token"]!],at:now)
    try restarted.db.exec("UPDATE entities SET local=? WHERE id='CLASS'",["{\"location\":\"Otra aula\"}"])
    try rejects("deshacer después de editar plan"){_=try restarted.undoReplan(string(applied2,"id"))}
    restarted.timer=["state":"paused","event":"A"]
    try rejects("mover sesión con cronómetro"){_=try restarted.previewReplan(params,at:now)}
    restarted.timer=[:]
    try restarted.db.exec("UPDATE entities SET plan=json_set(plan,'$.date','2030-01-07') WHERE id='EX'")
    try restarted.db.exec("UPDATE entities SET plan=json_set(plan,'$.evaluation','') WHERE id='A'")
    let noFit=try restarted.previewReplan(params,at:now)
    try check((noFit["rows"] as! [Object]).allSatisfy{$0["reason"] != nil},"prueba sin hora, heredada de tarea, impide estudiar ese día o después")
    try rejects("aplicar lote sin huecos"){_=try restarted.applyReplan(["token":noFit["token"]!],at:now)}
    let partial=try restarted.previewReplan(["ids":["A","C"],"from":"2030-01-07","days":7],at:now)
    try rejects("aplicación parcial sin confirmación"){_=try restarted.applyReplan(["token":partial["token"]!],at:now)}
    let partialResult=try restarted.applyReplan(["token":partial["token"]!,"acceptPartial":true],at:now)
    try check(number(partialResult,"count")==1 && number(partialResult,"unplaced")==1,"aplicación parcial explícita conserva sesión sin hueco")
    try check(string(try restarted.entity("A")!,"start")==string(a,"start"),"sesión sin hueco mantiene su horario anterior")
    try restarted.db.exec("DELETE FROM entities WHERE id NOT IN ('C','OTHER','DEMO')")
    try add("BUSY","availability",["title":"Ocupado","days":"MO","fromTime":"08:00","toTime":"19:00"])
    let constrained:Object=["ids":["C"],"from":"2030-01-07","days":1,"weekday":"08:00"]
    let busy=try restarted.previewReplan(constrained,at:now)
    try check(string((busy["rows"] as! [Object])[0],"start")=="2030-01-07T19:00:00","indisponibilidad recurrente bloquea horas configuradas")
    try add("TIMED","event",["title":"Prueba con hora","category":"exam","start":"2030-01-07T19:00:00","finish":"2030-01-07T20:00:00"])
    let timed=try restarted.previewReplan(constrained,at:now)
    try check(string((timed["rows"] as! [Object])[0],"start")=="2030-01-07T20:00:00","prueba con hora ocupa su intervalo")
    try restarted.db.exec("UPDATE entities SET plan=json_remove(plan,'$.finish') WHERE id='TIMED'")
    let unknown=try restarted.previewReplan(constrained,at:now)
    try check((unknown["rows"] as! [Object])[0]["reason"] != nil && !(unknown["warnings"] as! [String]).isEmpty,"fin desconocido no inventa duración y reserva resto del día")
    try restarted.db.exec("DELETE FROM entities WHERE id IN ('TIMED','BUSY')")
    let weekend=try restarted.previewReplan(["ids":["C"],"from":"2030-01-12","days":1],at:now)
    try check(string((weekend["rows"] as! [Object])[0],"start")=="2030-01-12T10:30:00","fin de semana usa su franja independiente")
    try rejects("propuesta caducada a los 15 minutos"){_=try restarted.applyReplan(["token":weekend["token"]!],at:now.addingTimeInterval(901))}
    try rejects("franja que invade descanso"){_=try restarted.previewReplan(["ids":["C"],"weekday":"07:00"],at:now)}
    try add("SAME","event",["title":"Mismo horario","category":"study","location":"Casa","start":"2030-01-11T16:30:00","finish":"2030-01-11T17:30:00"])
    let same=try restarted.previewReplan(["ids":["SAME"],"from":"2030-01-11","days":1],at:now)
    try check((same["rows"] as! [Object])[0]["unchanged"] as? Bool==true,"distingue horarios mantenidos de cambios reales")
    try rejects("crear lote sin cambios reales"){_=try restarted.applyReplan(["token":same["token"]!],at:now)}

    try restarted.db.exec("UPDATE entities SET local='{}',plan=json_set(plan,'$.finish','2030-01-06T17:05:00') WHERE id='C'")
    let tooShort=try restarted.previewReplan(["ids":["C"]],at:now)
    try check((tooShort["rows"] as! [Object])[0]["reason"] != nil,"duraciones inválidas quedan sin mover con motivo")
    try check(string(try restarted.db.query("PRAGMA integrity_check").first!,"integrity_check")=="ok","SQLite íntegra tras aplicar, reiniciar y deshacer lotes")
}
