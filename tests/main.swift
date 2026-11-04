// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
var passed=0
func check(_ condition:@autoclosure() throws -> Bool,_ label:String) throws {if try !condition(){throw problem("FALLO: "+label)};passed+=1;print("✓ \(label)")}
func rejects(_ label:String,_ f:() throws -> Void) throws {do{try f()}catch{passed+=1;print("✓ rechaza \(label)");return};throw problem("Aceptó indebidamente: "+label)}
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath),resources=URL(fileURLWithPath:ProcessInfo.processInfo.environment["NODAL_TEST_RESOURCES"]!),dir=root.appendingPathComponent("build/test-"+identifier())
func xml(_ revision:Int,_ contents:String,_ package:String="tests") -> Data {Data("<?xml version=\"1.0\"?><universidad version=\"1\" paquete=\"\(package)\" revision=\"\(revision)\" zona=\"Europe/Madrid\" fechaRevision=\"2026-10-28\">\(contents)</universidad>".utf8)}
func element(_ id:String,_ kind:String,_ body:String,action:String="actualizar")->String {"<elemento id=\"\(id)\" tipo=\"\(kind)\" accion=\"\(action)\">\(body)</elemento>"}
do {
 try verifyFirstRun(root:root)
 try verifyPlanningFeatures(resources:resources,root:root)
 try verifyGradeStorage(resources:resources,root:root)
 let s=try Store(directory:dir,resources:resources)
 let all=try s.entities()
 try check(all.filter{string($0,"kind")=="subject"}.count==5,"cinco asignaturas")
 try check(all.filter{string($0,"kind")=="series"}.count==11,"11 series, sin confundir ocurrencias")
 try check(all.filter{string($0,"category")=="exam"}.count==17,"17 pruebas")
 try check(all.filter{string($0,"category")=="study"}.count==60,"60 bloques")
 try check(all.filter{string($0,"kind")=="task"}.count==61,"61 tareas sintéticas")
 try check(try s.rows("time_records").isEmpty && s.rows("doubts").isEmpty,"sin tiempos ni dudas ficticios")
 try check(try s.entity("ac-pl1@nodal.test")?["user"] as? Object != nil,"estado de evaluación sintético")
 let acUser=(try s.entity("ac-pl1@nodal.test")!["user"]) as! Object
 try check(string(acUser,"assessment")=="no presentado" && acUser["grade"]==nil,"AC no presentado, sin cero")
 try check(((try s.entity("sed-pei@nodal.test")!["user"]) as! Object)["grade"] == nil,"SED sin nota inventada")
 let dates=try s.events(from:Dates.parse("2026-10-01")!,to:Dates.parse("2026-11-20")!)
 try check(Set(dates.map{string($0,"id")}).count==dates.count,"ocurrencias sin duplicados")
 try check(!dates.contains{string($0,"series")=="sed-teo-lun@nodal.test" && string($0,"start").hasPrefix("2026-10-12")},"EXDATE festivo excluido")
 try check(!dates.contains{string($0,"series")=="sed-teo-lun@nodal.test" && string($0,"start").hasPrefix("2026-11-02")},"EXDATE noviembre excluido")
 let before=dates.first{string($0,"series")=="sed-teo-lun@nodal.test" && string($0,"start").hasPrefix("2026-10-19")}!,after=dates.first{string($0,"series")=="sed-teo-lun@nodal.test" && string($0,"start").hasPrefix("2026-10-26")}!
 try check(string(before,"start").contains("T10:00") && string(after,"start").contains("T10:00"),"hora local estable en cambio CET/CEST")
 try check(Dates.iso(Dates.parse(string(before,"start"))!).contains("T08:00") && Dates.iso(Dates.parse(string(after,"start"))!).contains("T09:00"),"offset UTC cambia correctamente")
 let unknown=try s.entity("ac-pe1@nodal.test")!
 try check(unknown["date"] != nil && unknown["start"]==nil,"fecha sin hora no ocupa 24 horas")
 var moved=after;moved["start"]="2026-10-26T11:00:00";moved["finish"]="2026-10-26T13:00:00";_=try s.saveEntity(moved)
 let again=try s.events(from:Dates.parse("2026-10-19")!,to:Dates.parse("2026-11-10")!)
 try check(again.first{string($0,"id")==string(after,"id")}.map{string($0,"start")}=="2026-10-26T11:00:00","se mueve una ocurrencia")
 try check(again.first{string($0,"id")==string(before,"id")}.map{string($0,"start")}=="2026-10-19T10:00:00","la serie restante no se mueve")
 let base=s.db.path
 try s.saveUser("AC01",["status":"completada","notes":"Mi intento","checklist":[["text":"Unidades","done":true]]])
 let reopened=try Store(directory:dir,resources:resources)
 try check(try reopened.entities().count==206,"semilla idempotente al reabrir")
 let saved=(try reopened.entity("AC01")!["user"]) as! Object
 try check(string(saved,"status")=="completada" && string(saved,"notes")=="Mi intento" && saved["evidence"]==nil,"progreso persiste sin conceder dominio")
 try s.saveUser("AC01",["status":"pendiente"])
 try check(string((try s.entity("AC01")!["user"]) as! Object,"status")=="pendiente","progreso reversible")
 var study=try s.entity("fixture-study-ac01@nodal.test")!
 var overlap=study;overlap["start"]="2026-10-29T10:00:00";overlap["finish"]="2026-10-29T11:30:00"
 try check(try s.moveIssues(overlap).contains{$0.contains("SED")},"solape con clase detectado")
 try check(try s.moveIssues(overlap).contains{$0.contains("Ocupado")},"indisponibilidad detectada")
 try check(try s.alternative(overlap) != nil,"ofrece alternativa compatible")
 let now=Date().addingTimeInterval(-10000)
 try s.startTimer(["subject":"AC","task":"AC01","event":string(study,"id")],at:now)
 try rejects("dos cronómetros simultáneos"){try s.startTimer(["subject":"PV"],at:now)}
 try s.heartbeat(at:now.addingTimeInterval(5));try s.pauseTimer(at:now.addingTimeInterval(10));try s.resumeTimer(at:now.addingTimeInterval(100));try s.heartbeat(at:now.addingTimeInterval(105));let record=try s.finishTimer(at:now.addingTimeInterval(110))
 try check(number(record,"seconds")==20,"pausa de 90 s excluida; marcas temporales sin ticks")
 try check(string((try s.entity("AC01")!["user"]) as! Object,"status")=="pendiente","finalizar no completa tarea")
 try s.startTimer(["subject":"PA"],at:now);try s.heartbeat(at:now.addingTimeInterval(5))
 let crash=try Store(directory:dir,resources:resources)
 try check(string(crash.timer,"state")=="paused" && crash.timerSeconds()==5,"reapertura excluye ausencia desde último heartbeat")
 _=try crash.finishTimer(at:now.addingTimeInterval(10000));s.timer=[:]
 try s.startTimer(["subject":"SS"],at:now);try s.heartbeat(at:now.addingTimeInterval(1000))
 try check(string(s.timer,"state")=="paused" && s.timerSeconds()==0,"salto de reloj/ausencia dudosa excluido")
 _=try s.finishTimer(at:now.addingTimeInterval(1000))
 try s.startTimer(["subject":"PV","interval":1,"rest":1],at:now)
 for sec in stride(from:5,through:60,by:5){try s.heartbeat(at:now.addingTimeInterval(Double(sec)))}
 try check(string(s.timer,"state")=="paused" && s.timerSeconds()==60,"intervalo de trabajo cierra en su límite")
 try rejects("reanudar antes de descanso"){try s.resumeTimer(at:now.addingTimeInterval(80))}
 try s.resumeTimer(at:now.addingTimeInterval(120));try s.pauseTimer(at:now.addingTimeInterval(130));_=try s.finishTimer(at:now.addingTimeInterval(130))
 let manual=try s.saveTime(["subject":"AC","date":Dates.iso(now),"seconds":120,"label":"manual"])
 let corrected=try s.saveTime(["id":string(manual,"id"),"subject":"AC","date":Dates.iso(now),"seconds":180])
 try check(number(corrected,"seconds")==180 && string(corrected,"mode")=="corregido","corrección manual e historial")
 try s.deleteRecord("time_records",string(manual,"id"));try check(try !s.rows("time_records").contains{string($0,"id")==string(manual,"id")},"eliminación excluida del total")
 try s.deleteRecord("time_records",string(manual,"id"),undo:true);try check(try s.rows("time_records").contains{string($0,"id")==string(manual,"id")},"deshacer eliminación")
 try rejects("tiempo futuro manual"){_=try s.saveTime(["subject":"AC","date":Dates.iso(Date().addingTimeInterval(86400)),"seconds":60])}
 var doubt=try s.saveDoubt(["subject":"AC","task":"AC01","event":string(study,"id"),"question":"¿Por qué cambia CPI?","attempt":"Comparé ciclos","reference":"AC-T1 p.30","recipient":"profesor","status":"para tutoría"])
 try check(try s.exportDoubts(professorOnly:true).contains("Comparé ciclos"),"exporta duda e intento agrupados")
 doubt["status"]="resuelta";doubt["answer"]="Respuesta";doubt["provenance"]="Profesor";_=try s.saveDoubt(doubt);doubt["status"]="abierta";_=try s.saveDoubt(doubt)
 try check(string(try s.rows("doubts").first!,"status")=="abierta","duda resuelta se puede reabrir")
 try s.saveUser(string(study,"id"),["status":"completada","notes":"Nota personal que debe sobrevivir"])
 let update=xml(1,element(string(study,"id"),"event","<title>Plan actualizado</title><start>2026-10-29T17:00:00+01:00</start><finish>2026-10-29T18:30:00+01:00</finish>"))
 let p=try s.previewXML(update);let report=try s.applyImport(token:string(p,"token"),choices:[:])
 try check(!string(report,"backup").isEmpty,"copia consistente antes de importar")
 try check(string(try s.entity(string(study,"id"))!,"title")=="Plan actualizado","actualización XML aplicada")
 let progress=(try s.entity(string(study,"id"))!["user"]) as! Object
 try check(string(progress,"status")=="completada" && string(progress,"notes").contains("sobrevivir"),"XML conserva completados y notas")
 try check(try s.rows("time_records").contains{string($0,"event")==string(study,"id")} && s.rows("doubts").count==1,"XML conserva tiempo y dudas")
 let duplicate=try s.previewXML(update);try check(duplicate["repeated"] as? Bool==true,"misma revisión idempotente")
 _=try s.applyImport(token:string(duplicate,"token"),choices:[:]);try check(try s.db.query("SELECT * FROM imports").count==1,"sin duplicar importaciones")
 study=try s.entity(string(study,"id"))!;study["title"]="Mi título local";_=try s.saveEntity(study)
 let p2=try s.previewXML(xml(2,element(string(study,"id"),"event","<title>Título nuevo del plan</title>")))
 try check(!(p2["rows"] as! [Object])[0]["conflicts"].map{($0 as! [String]).isEmpty}!,"detecta edición local frente a XML")
 try rejects("aplicar conflicto sin elegir"){_=try s.applyImport(token:string(p2,"token"),choices:[:])}
 _=try s.applyImport(token:string(p2,"token"),choices:["0":"local"])
 try check(string(try s.entity(string(study,"id"))!,"title")=="Mi título local","resolución conserva edición local")
 let p3=try s.previewXML(xml(3,element(string(study,"id"),"event","<title>Elegido del plan</title>")))
 _=try s.applyImport(token:string(p3,"token"),choices:["0":"incoming"])
 try check(string(try s.entity(string(study,"id"))!,"title")=="Elegido del plan","resolución acepta plan sin borrar progreso")
 let checkpoint=try s.backup("checkpoint")
 let archive=try s.previewXML(xml(4,element(string(study,"id"),"event","",action:"archivar")))
 _=try s.applyImport(token:string(archive,"token"),choices:["0":"incoming"])
 try check(try !s.entities().contains{string($0,"id")==string(study,"id")} && s.entity(string(study,"id")) != nil,"baja explícita archiva sin destruir")
 try check(try s.rows("doubts").count==1 && s.rows("time_records").count>=1,"historial del archivado conservado")
 let fingerprint=try s.planFingerprint()
 try rejects("XML truncado"){_=try s.previewXML(Data("<universidad".utf8))}
 try rejects("XML hostil DTD/XXE"){_=try s.previewXML(Data("<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///etc/passwd'>]><universidad>&e;</universidad>".utf8))}
 try rejects("referencia rota"){_=try s.previewXML(xml(5,element("new-task","task","<title>Test</title><subject>NOEXISTE</subject>")))}
 try rejects("campo de estado de usuario no permitido"){_=try s.previewXML(xml(5,element("AC01","task","<status>completada</status>")))}
 try rejects("campo duplicado"){_=try s.previewXML(xml(5,element("AC01","task","<title>A</title><title>B</title>")))}
 try rejects("ciclo de dependencias"){_=try s.previewXML(xml(5,element("AC01","task","<dependencies><ref>AC02</ref></dependencies>")+element("AC02","task","<dependencies><ref>AC01</ref></dependencies>")))}
 try rejects("revisión previa"){_=try s.previewXML(xml(1,element("AC01","task","<title>distinto</title>")))}
 try rejects("XML sobredimensionado"){_=try s.previewXML(Data(repeating:65,count:2_000_001))}
 try check(try s.planFingerprint()==fingerprint,"rechazos no dejan cambios parciales")
 try s.restore(checkpoint)
 try check(try s.entities().contains{string($0,"id")==string(study,"id")} && s.rows("doubts").count==1,"restauración de copia probada en base de prueba")
 let knownTime=try s.previewXML(xml(1,element("ac-pe1@nodal.test","event","<start>2026-11-03T12:00:00+01:00</start>"),"hora-confirmada"))
 _=try s.applyImport(token:string(knownTime,"token"),choices:[:])
 try check(string(try s.entity("ac-pe1@nodal.test")!,"date").isEmpty && string(try s.entity("ac-pe1@nodal.test")!,"start").contains("12:00"),"XML confirma hora antes desconocida sin duplicar fecha")
 let unknownTime=try s.previewXML(xml(2,element("ac-pe1@nodal.test","event","<date>2026-11-03</date>"),"hora-confirmada"))
 _=try s.applyImport(token:string(unknownTime,"token"),choices:[:])
 try check(string(try s.entity("ac-pe1@nodal.test")!,"start").isEmpty,"XML puede volver a fecha sin hora")
 try rejects("XML profundo"){_=try s.previewXML(Data(("<a>"+String(repeating:"<a>",count:9)+String(repeating:"</a>",count:10)).utf8))}
 let stale=try s.previewXML(xml(1,element("AC02","task","<title>Actualizado</title>"),"stale"))
 try s.saveUser("AC02",["notes":"Edición posterior a vista previa"])
 try rejects("vista previa obsoleta"){_=try s.applyImport(token:string(stale,"token"),choices:[:])}
 let missing=s.directory.appendingPathComponent("invalid.sqlite");try Data("no es sqlite".utf8).write(to:missing)
 let validFingerprint=try s.planFingerprint()
 try rejects("copia corrupta"){try s.restore(missing.path)}
 try check(try s.planFingerprint()==validFingerprint,"copia corrupta no toca base actual")
 let badJSON=try s.backup("json-corrupto")
 let corruptDB=try Database(badJSON);try corruptDB.exec("UPDATE settings SET value='invalido' WHERE key='context'");try corruptDB.exec("PRAGMA wal_checkpoint(TRUNCATE)")
 try rejects("copia con contexto JSON dañado"){try s.restore(badJSON)}
 try rejects("restaurar la base abierta"){try s.restore(s.db.path)}
 let exported=try s.exportPlan();_=try PlanXML.read(Data(exported.utf8),schema:resources.appendingPathComponent("xml/plan-v1.xsd"));try check(true,"XML exportado valida contra XSD")
 let ics=try s.exportICS(),read=try AcademicCalendar.parseICS(ics)
 try check(ics.contains("DTSTART;TZID=Europe/Madrid") && ics.contains("BEGIN:VTIMEZONE"),"ICS exporta recurrencias con zona local")
 try check(read.filter{string($0,"kind")=="series"}.count==11,"exportación ICS conserva series")
 try check(read.contains{string($0,"kind")=="occurrence"},"ICS conserva RECURRENCE-ID")
 try check(read.contains{string($0,"date")=="2026-11-03"},"ICS conserva fechas sin hora")
 let rr:Object=["id":"test","start":"2026-10-01T10:00:00","finish":"2026-10-01T11:00:00","rrule":"FREQ=WEEKLY;COUNT=4;BYDAY=TH","exdates":["2026-10-08T10:00:00"]]
 let expanded=try AcademicCalendar.occurrences(rr,from:Dates.parse("2026-10-01")!,to:Dates.parse("2026-11-01")!)
 try check(expanded.count==3,"COUNT incluye exclusiones correctamente")
 try check(string(try s.db.query("PRAGMA integrity_check").first!,"integrity_check")=="ok","SQLite íntegra tras importaciones y restauración")
 let dateRR:Object=["id":"date-series","date":"2026-10-01","dateEnd":"2026-10-02","rrule":"FREQ=WEEKLY;COUNT=4","exdates":["2026-10-08"]]
 let dateEvents=try AcademicCalendar.occurrences(dateRR,from:Dates.parse("2026-10-01")!,to:Dates.parse("2026-11-01")!)
 try check(dateEvents.count==3 && dateEvents.allSatisfy{$0["start"]==nil && string($0,"date").count==10},"recurrencias de fechas sin hora con EXDATE")
 try rejects("TZID no admitida"){_=try AcademicCalendar.parseICS("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:foreign\nDTSTART;TZID=America/New_York:20261001T100000\nSUMMARY:Test\nEND:VEVENT\nEND:VCALENDAR")}
 _=try s.saveEntity(["id":"TEST-SUBJECT","kind":"subject","title":"Asignatura sintética","color":"#507da7"])
 try check(try s.entity("TEST-SUBJECT-plan") != nil,"asignatura nueva crea contenedor de temas")
 _=try s.saveEntity(["id":"TEST-TASK","kind":"task","title":"Ejercicio sintético","subject":"TEST-SUBJECT","topic":"TEST-SUBJECT-plan"])
 try check(try s.entity("TEST-TASK") != nil,"jerarquía nueva editable y persistente")
 try rejects("tema de otra asignatura"){_=try s.saveEntity(["id":"TEST-TASK","kind":"task","title":"Ejercicio sintético","subject":"AC","topic":"TEST-SUBJECT-plan"])}
 print("\n\(passed) comprobaciones superadas. Base de prueba: \(base)")
}catch{fputs("\(error.localizedDescription)\n",stderr);exit(1)}
