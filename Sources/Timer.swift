// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

extension Store {
    func timerSeconds(at now:Date=Date()) -> Double {
        let segments=timer["segments"] as? [Object] ?? []
        var seconds=segments.reduce(0.0){$0+max(0,number($1,"end")-number($1,"start"))}
        if string(timer,"state")=="running" {seconds+=max(0,now.timeIntervalSince1970-number(timer,"started"))};return seconds
    }
    func persistTimer() throws {try setSetting("timer",try json(timer))}
    func startTimer(_ params:Object,at now:Date=Date()) throws {
        guard timer.isEmpty else {throw problem("Ya hay un cronómetro. Finalízalo antes de iniciar otro.")}
        let sid=string(params,"subject")
        guard try entities().contains(where:{string($0,"id")==sid && string($0,"kind")=="subject"}) else {throw problem("Selecciona una asignatura")}
        let interval=number(params,"interval",0),rest=number(params,"rest",5)
        guard interval==0 || (interval>=1 && interval<=180),rest>=1 && rest<=60 else {throw problem("Intervalos entre 1 y 180 min y descansos entre 1 y 60 min")}
        timer=["id":identifier(),"subject":sid,"task":string(params,"task"),"event":string(params,"event"),"label":string(params,"label","Estudio libre"),"state":"running","started":now.timeIntervalSince1970,"last":now.timeIntervalSince1970,"created":Dates.iso(now),"segments":[Object](),"interval":interval,"rest":rest,"cycleStart":0.0]
        try persistTimer()
    }
    func pauseTimer(at now:Date=Date(),reason:String="") throws {
        guard !timer.isEmpty else{return}
        if string(timer,"state")=="running" {
            var segments=timer["segments"] as? [Object] ?? []
            let start=number(timer,"started"),end=max(start,now.timeIntervalSince1970)
            segments.append(["start":start,"end":end]);timer["segments"]=segments
        }
        timer["state"]="paused";timer.removeValue(forKey:"started")
        if !reason.isEmpty {timer["recovery"]=reason;timer["excludedUntil"]=Date().timeIntervalSince1970}
        try persistTimer()
    }
    func resumeTimer(at now:Date=Date()) throws {
        guard !timer.isEmpty,string(timer,"state") != "running" else {throw problem("No hay cronómetro pausado")}
        if number(timer,"breakUntil")>now.timeIntervalSince1970 {throw problem("Descanso hasta \(Dates.format(Date(timeIntervalSince1970:number(timer,"breakUntil")),"HH:mm")). Puedes finalizar el intervalo si necesitas corregirlo.")}
        if timer["breakUntil"] != nil {timer["cycleStart"]=timerSeconds(at:now);timer.removeValue(forKey:"breakUntil")}
        timer["state"]="running";timer["started"]=now.timeIntervalSince1970;timer["last"]=now.timeIntervalSince1970;timer.removeValue(forKey:"recovery");try persistTimer()
    }
    func heartbeat(at now:Date=Date()) throws {
        guard string(timer,"state")=="running" else{return}
        if now.timeIntervalSince1970-number(timer,"last")>20 || now.timeIntervalSince1970<number(timer,"last") {
            try pauseTimer(at:Date(timeIntervalSince1970:number(timer,"last")),reason:"Se detectó un salto de reloj o ausencia de más de 20 segundos entre guardados. Ese tramo se ha excluido; puedes corregir el registro manualmente.");return
        }
        let interval=number(timer,"interval")*60
        if interval>0 && timerSeconds(at:now)-number(timer,"cycleStart")>=interval {
            let limit=number(timer,"started") + max(0,interval-(timerSeconds(at:Date(timeIntervalSince1970:number(timer,"started")))-number(timer,"cycleStart")))
            try pauseTimer(at:Date(timeIntervalSince1970:limit))
            timer["breakUntil"]=now.timeIntervalSince1970+number(timer,"rest",5)*60
            timer["recovery"]="Intervalo terminado. Descanso excluido del tiempo efectivo; reanuda cuando termine.";try persistTimer();return
        }
        timer["last"]=now.timeIntervalSince1970;try persistTimer()
    }
    @discardableResult func finishTimer(at now:Date=Date()) throws -> Object {
        guard !timer.isEmpty else {throw problem("No hay cronómetro")}
        try pauseTimer(at:now)
        var record=timer;record["seconds"]=timerSeconds(at:now);record["date"]=string(timer,"created");record["mode"]="cronometrado";record.removeValue(forKey:"state")
        try db.transaction {_=try journal("time_records",record);try audit("finalizar cronómetro",[:],record);try setSetting("timer","{}")}
        timer=[:];return record
    }
    func saveTime(_ p:Object) throws -> Object {
        let seconds=number(p,"seconds")
        guard seconds>0,seconds<=86400,let date=Dates.parse(string(p,"date")),date<=Date() else {throw problem("Tiempo entre 1 segundo y 24 horas, con fecha pasada o actual")}
        guard try entities().contains(where:{string($0,"id")==string(p,"subject") && string($0,"kind")=="subject"}) else {throw problem("Asignatura no válida")}
        let old=try rows("time_records").first{string($0,"id")==string(p,"id")} ?? [:]
        var next=old;next.merge(p){_,new in new};next["mode"]=old.isEmpty ? "manual":"corregido";next["originalSeconds"]=old["originalSeconds"] ?? old["seconds"] ?? seconds
        return try db.transaction {let saved=try journal("time_records",next);try audit("corregir tiempo",old,saved);return saved}
    }
    func deleteRecord(_ table:String,_ id:String,undo:Bool=false) throws {
        guard ["time_records","doubts"].contains(table) else {throw problem("Registro no borrable")}
        let old=try rows(table,deleted:true).first{string($0,"id")==id} ?? [:]
        try db.transaction {try db.exec("UPDATE \(table) SET deleted=? WHERE id=?",[undo ? 0:1,id]);try audit(undo ? "recuperar registro":"eliminar registro",old,["table":table,"id":id])}
    }
    func saveDoubt(_ p:Object) throws -> Object {
        guard !string(p,"question").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {throw problem("Escribe la pregunta")}
        let states=["abierta","investigando","para tutoría","respuesta recibida","pendiente de comprobar","resuelta"]
        guard states.contains(string(p,"status","abierta")) else {throw problem("Estado de duda no válido")}
        var d=p;d["updated"]=Dates.iso(Date());if d["created"]==nil {d["created"]=d["updated"]}
        return try journal("doubts",d)
    }
    func exportDoubts(professorOnly:Bool=false) throws -> String {
        let subjects=try entities().filter{string($0,"kind")=="subject"};let doubts=try rows("doubts").filter{!professorOnly || string($0,"recipient")=="profesor" || string($0,"status")=="para tutoría"}
        var text="# Dudas · Nodal\n\nExportado \(Dates.format(Date(),"dd/MM/yyyy HH:mm")) · Europe/Madrid\n"
        for s in subjects {
            let items=doubts.filter{string($0,"subject")==string(s,"id")};if items.isEmpty{continue}
            text+="\n## \(string(s,"title"))\n"
            for d in items {
                text+="\n### \(string(d,"question"))\n- Estado: \(string(d,"status")) · Prioridad: \(string(d,"priority"))\n- Referencia: \(string(d,"reference")) · Tema/tarea: \(string(d,"task"))\n- Intenté: \(string(d,"attempt"))\n- Atasco/error: \(string(d,"stuck"))\n- Respuesta: \(string(d,"answer"))\n- Procedencia: \(string(d,"provenance"))\n- Comprobación/resolución: \(string(d,"resolution"))\n"
            }
        };return text
    }
}
