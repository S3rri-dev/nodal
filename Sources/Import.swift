// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CryptoKit

func digest(_ data:Data)->String { SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined() }
func xmlEscape(_ s:String)->String {s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;").replacingOccurrences(of:"'",with:"&apos;")}
final class PlanXML:NSObject,XMLParserDelegate {
    var root=Object(),items=[Object](),current=Object(),fields=Object(),stack=[String](),text="",count=0,issue:Error?
    var seenFields=Set<String>()
    func parser(_ parser:XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
        stack.append(elementName);count+=1;text=""
        if stack.count>8 || count>30000 {issue=problem("XML supera profundidad o número de elementos permitido");parser.abortParsing();return}
        if stack.count==1 {root=attributes}
        if elementName=="elemento" {current=attributes;fields=[:];seenFields=[]}
        if ["dependencies","exdates"].contains(elementName) {fields[elementName]=[String]()}
        if stack.count==3 && !seenFields.insert(elementName).inserted {issue=problem("Campo duplicado \(elementName) en \(string(current,"id"))");parser.abortParsing()}
    }
    func parser(_ parser:XMLParser,foundCharacters string:String){text+=string;if text.utf8.count>100000{issue=problem("Texto demasiado grande en \(stack.last ?? "elemento")");parser.abortParsing()}}
    func parser(_ parser:XMLParser,didEndElement elementName:String,namespaceURI:String?,qualifiedName:String?) {
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        if stack.count==3 && !["dependencies","exdates"].contains(elementName) {fields[elementName]=["reserve","cancelled"].contains(elementName) ? (value=="true" || value=="1") : value as Any}
        if elementName=="ref" || elementName=="at" || elementName=="on" {let key=elementName=="ref" ? "dependencies":"exdates";var arr=fields[key] as? [String] ?? [];arr.append(value);fields[key]=arr}
        if elementName=="elemento" {current["plan"]=fields;items.append(current)}
        stack.removeLast();text=""
    }
    static func read(_ data:Data,schema:URL) throws -> Object {
        guard data.count<=2_000_000,let text=String(data:data,encoding:.utf8),!text.isEmpty else {throw problem("XML debe ser UTF-8 y menor de 2 MB")}
        guard text.range(of:"<!\\s*(DOCTYPE|ENTITY)|<[^>]*(schemaLocation|xinclude|xi:include)",options:[.regularExpression,.caseInsensitive])==nil else {throw problem("XML: DTD, entidades, esquemas externos y XInclude no están permitidos")}
        let delegate=PlanXML(),parser=XMLParser(data:data);parser.delegate=delegate;parser.shouldResolveExternalEntities=false
        guard parser.parse(),delegate.issue==nil else {throw delegate.issue ?? problem("XML inválido línea \(parser.lineNumber): \(parser.parserError?.localizedDescription ?? "sintaxis")")}
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent(identifier()),errors=temp.appendingPathExtension("err")
        try data.write(to:temp);FileManager.default.createFile(atPath:errors.path,contents:nil)
        defer{try? FileManager.default.removeItem(at:temp);try? FileManager.default.removeItem(at:errors)}
        let log=try FileHandle(forWritingTo:errors);defer{try? log.close()}
        let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/xmllint");process.arguments=["--nonet","--noout","--schema",schema.path,temp.path];process.standardError=log;process.standardOutput=FileHandle.nullDevice;try process.run();process.waitUntilExit()
        guard process.terminationStatus==0 else {let detail=(try? String(contentsOf:errors,encoding:.utf8)) ?? "No válido";throw problem("Validación XSD: \(detail.prefix(2500))")}
        return ["root":delegate.root,"items":delegate.items]
    }
}

extension Store {
    func planFingerprint() throws -> String {digest(Data(try json(db.query("SELECT * FROM entities ORDER BY id")).utf8))}
    func validatePlans(_ items:[Object]) throws {
        var all=Dictionary(uniqueKeysWithValues:try entities(includeArchived:true).map{(string($0,"id"),$0)})
        let ids=items.map{string($0,"id")}
        guard Set(ids).count==ids.count else {throw problem("Identificadores duplicados")}
        for item in items {
            let id=string(item,"id"),kind=string(item,"tipo",string(item,"kind")),p=item["plan"] as? Object ?? [:],old=all[id] ?? [:]
            guard old.isEmpty || string(old,"kind")==kind else {throw problem("\(id): no se puede cambiar el tipo de un ID existente")}
            if string(item,"accion")=="archivar" {guard !old.isEmpty else{throw problem("\(id): no existe para archivar")};continue}
            var merged=old;merged.merge(p){_,new in new};merged["id"]=id;merged["kind"]=kind
            guard !string(merged,"title").isEmpty else {throw problem("\(id): falta title")}
            if ["event","series","occurrence"].contains(kind) {
                guard let start=Dates.parse(string(merged,"start",string(merged,"date"))) else{throw problem("\(id): falta fecha/inicio válido")}
                if !string(merged,"date").isEmpty && !string(merged,"start").isEmpty {throw problem("\(id): date y start son excluyentes")}
                if let finish=merged["finish"] as? String,!finish.isEmpty {guard let end=Dates.parse(finish),end>start else {throw problem("\(id): finish debe ser posterior a start")}}
                if let finish=merged["dateEnd"] as? String,!finish.isEmpty {guard let end=Dates.parse(finish),end>start else {throw problem("\(id): dateEnd debe ser posterior a date")}}
                guard ["class","exam","study","availability"].contains(string(merged,"category")) else {throw problem("\(id): categoría inválida")}
                if string(merged,"category")=="study",Dates.parse(string(merged,"finish"))==nil {throw problem("\(id): una sesión de estudio requiere finish")}
            }
            if kind=="series" {_=try AcademicCalendar.rules(string(merged,"rrule"))}
            if kind=="availability" {guard !string(merged,"days").isEmpty,string(merged,"days").components(separatedBy:",").allSatisfy(AcademicCalendar.weekdays.contains),string(merged,"fromTime")<string(merged,"toTime") else {throw problem("\(id): disponibilidad inválida")}}
            all[id]=merged
        }
        for item in items where string(item,"accion") != "archivar" {
            let id=string(item,"id"),e=all[id]!
            for (key,kind) in [("subject","subject"),("topic","topic"),("task","task"),("evaluation","event"),("series","series")] {
                let ref=string(e,key);if !ref.isEmpty {guard let target=all[ref],string(target,"kind")==kind else {throw problem("\(id)/\(key): referencia rota \(ref)")}}
            }
            if string(e,"kind")=="task",!string(e,"topic").isEmpty,let topic=all[string(e,"topic")],string(topic,"subject") != string(e,"subject") {throw problem("\(id): el tema pertenece a otra asignatura")}
            for ref in e["dependencies"] as? [String] ?? [] {guard let target=all[ref],string(target,"kind")=="task",ref != id else {throw problem("\(id)/dependencies: referencia inválida \(ref)")}}
        }
        var visiting=Set<String>(),visited=Set<String>()
        func visit(_ id:String) throws {
            if visiting.contains(id){throw problem("Ciclo de dependencias en \(id)")};if visited.contains(id){return};visiting.insert(id)
            for ref in all[id]?["dependencies"] as? [String] ?? [] {try visit(ref)}
            visiting.remove(id);visited.insert(id)
        }
        for id in all.keys {try visit(id)}
    }
    func previewXML(_ input:Data) throws -> Object {
        let parsed=try PlanXML.read(input,schema:resources.appendingPathComponent("xml/plan-v1.xsd")),root=parsed["root"] as! Object
        let items=try (parsed["items"] as! [Object]).map { item -> Object in
            var value=item;var p=item["plan"] as! Object
            guard string(p,"date").isEmpty || string(p,"start").isEmpty else {throw problem("\(string(item,"id")): date y start son excluyentes")}
            if !string(p,"start").isEmpty {p["date"]=NSNull();p["dateEnd"]=NSNull()}
            if !string(p,"date").isEmpty {p["start"]=NSNull();p["finish"]=NSNull()}
            value["plan"]=p;return value
        }
        try validatePlans(items)
        return try previewItems(items,package:string(root,"paquete"),revision:string(root,"revision"),hash:digest(input),snapshot:string(root,"fechaRevision"))
    }
    func previewICS(_ input:String) throws -> Object {
        let values=try AcademicCalendar.parseICS(input)
        let items=try values.map{e->Object in
            var plan=e.filter{planKeys.contains($0.key)}
            if e["inferredCategory"] as? Bool==true,let old=try entity(string(e,"id")) {plan["category"]=old["category"] ?? "class"}
            return ["id":string(e,"id"),"tipo":string(e,"kind"),"plan":plan]
        }
        try validatePlans(items)
        let hash=digest(Data(input.utf8));return try previewItems(items,package:"ics-"+String(hash.prefix(16)),revision:"1",hash:hash,snapshot:Dates.format(Date(),"yyyy-MM-dd"))
    }
    func previewItems(_ items:[Object],package:String,revision:String,hash:String,snapshot:String) throws -> Object {
        let prior=try db.query("SELECT * FROM imports WHERE package=? AND revision=?",[package,revision]).first
        if let prior=prior,string(prior,"digest") != hash {throw problem("Revisión \(revision) ya aplicada con contenido diferente. Usa una revisión nueva.")}
        if prior==nil,let maxRow=try db.query("SELECT MAX(CAST(revision AS INTEGER)) AS n FROM imports WHERE package=?",[package]).first,number(maxRow,"n") >= (Double(revision) ?? 0) {throw problem("La revisión debe ser posterior a la ya aplicada")}
        var rows=[Object]()
        for item in items {
            let id=string(item,"id"),kind=string(item,"tipo"),p=item["plan"] as! Object,raw=try db.query("SELECT * FROM entities WHERE id=?",[id]).first
            let base=object(string(raw ?? [:],"plan")),local=object(string(raw ?? [:],"local"));var changes=[Object](),conflicts=[String]()
            for k in p.keys.sorted() {
                if try json(p[k]!) != json(base[k] ?? NSNull()) {
                    changes.append(["field":k,"before":try json(local[k] ?? base[k] ?? NSNull()),"after":try json(p[k]!)])
                    if let value=local[k],try json(value) != json(p[k]!) {conflicts.append(k)}
                }
            }
            let modeChange=(!string(p,"start").isEmpty && !string(base,"date").isEmpty) || (!string(p,"date").isEmpty && !string(base,"start").isEmpty)
            if modeChange && ["start","finish","date","dateEnd"].contains(where:{local[$0] != nil}) {conflicts.append("modo de fecha/hora")}
            let action=string(item,"accion","actualizar")
            if action=="archivar",raw != nil {
                let allHistory=try rowsWithReference(id)
                if !local.isEmpty || !object(string(raw!,"user")).isEmpty || allHistory {conflicts.append("archivo con historial")}
            }
            rows.append(["id":id,"kind":kind,"plan":p,"title":string(p,"title",string(base,"title",id)),"action":action=="archivar" ? "archivar":(action=="reactivar" ? "reactivar":(raw==nil ? "alta":(changes.isEmpty ? "sin cambios":"cambio"))),"changes":changes,"conflicts":conflicts])
        }
        let token=identifier();let preview:Object=["token":token,"package":package,"revision":revision,"digest":hash,"snapshot":snapshot,"rows":rows,"repeated":prior != nil,"fingerprint":try planFingerprint()]
        pendingImport=preview;return preview
    }
    func rowsWithReference(_ id:String) throws -> Bool {
        for table in ["time_records","attempts","doubts"] {if try rows(table,deleted:true).contains(where:{string($0,"task")==id || string($0,"event")==id || string($0,"subject")==id}){return true}};return false
    }
    func applyImport(token:String,choices:Object) throws -> Object {
        guard let pending=pendingImport,string(pending,"token")==token else {throw problem("La vista previa ha caducado. Abre de nuevo el archivo.")}
        if pending["repeated"] as? Bool==true {return ["report":"Revisión ya aplicada, sin cambios.","backup":""]}
        guard string(pending,"fingerprint")==((try planFingerprint())) else {throw problem("Los datos han cambiado desde la vista previa. Revisa otra vez el archivo.")}
        let rows=pending["rows"] as! [Object]
        for (i,r) in rows.enumerated() where !(r["conflicts"] as! [String]).isEmpty {guard ["local","incoming"].contains(string(choices,String(i))) else {throw problem("Elige cómo resolver el conflicto de \(string(r,"id"))")}}
        let copy=try backup("antes-importar")
        var changed=0,archived=0,kept=0
        try db.transaction {
            for (i,row) in rows.enumerated() {
                let id=string(row,"id"),action=string(row,"action"),p=row["plan"] as! Object,conflicts=row["conflicts"] as! [String],choice=string(choices,String(i),"local")
                if action=="archivar" {
                    if !conflicts.isEmpty && choice=="local" {kept+=1;continue};try db.exec("UPDATE entities SET archived=1 WHERE id=?",[id]);archived+=1;continue
                }
                if let existing=try db.query("SELECT * FROM entities WHERE id=?",[id]).first {
                    var base=object(string(existing,"plan")),local=object(string(existing,"local"))
                    if conflicts.contains("modo de fecha/hora") {
                        if choice=="local" {for k in ["start","finish","date","dateEnd"] {local[k]=local[k] ?? base[k] ?? NSNull()}}
                        else {for k in ["start","finish","date","dateEnd"] {local.removeValue(forKey:k)}}
                    }
                    base.merge(p){_,new in new};if choice=="incoming" {for k in conflicts {local.removeValue(forKey:k)}}
                    for (key,value) in local {if let incoming=base[key],try json(value)==json(incoming){local.removeValue(forKey:key)}}
                    try db.exec("UPDATE entities SET plan=?,local=?,archived=? WHERE id=?",[try json(base),try json(local),action=="reactivar" ? 0:number(existing,"archived"),id])
                }else{try db.exec("INSERT INTO entities(id,kind,plan) VALUES(?,?,?)",[id,string(row,"kind"),try json(p)])}
                if action != "sin cambios" {changed+=1}
            }
            let finalItems=try entities(includeArchived:true).map { e -> Object in ["id":string(e,"id"),"tipo":string(e,"kind"),"plan":e.filter{planKeys.contains($0.key)}] }
            try validatePlans(finalItems)
            let report="\(changed) altas/cambios · \(archived) archivados · \(kept) bajas no aplicadas. Progreso y registros conservados."
            try db.exec("INSERT INTO imports VALUES(?,?,?,?,?,?)",[identifier(),string(pending,"package"),string(pending,"revision"),string(pending,"digest"),report,copy])
            try setSetting("snapshot",string(pending,"snapshot"))
        }
        pendingImport=nil
        return ["report":"\(changed) altas/cambios · \(archived) archivados · \(kept) bajas no aplicadas. Progreso y registros conservados.","backup":copy]
    }
    func exportPlan() throws -> String {
        var text="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<universidad version=\"1\" paquete=\"nodal-exportado\" revision=\"\(Int(Date().timeIntervalSince1970))\" zona=\"Europe/Madrid\" fechaRevision=\"\(try setting("snapshot"))\">\n"
        for e in try entities(includeArchived:true).sorted(by:{string($0,"id")<string($1,"id")}) {
            text+="  <elemento id=\"\(xmlEscape(string(e,"id")))\" tipo=\"\(string(e,"kind"))\" accion=\"\((e["archived"] as? Bool ?? false) ? "archivar":"actualizar")\">\n"
            if !(e["archived"] as? Bool ?? false) {
                for key in planKeys.sorted() where e[key] != nil && !(e[key] is NSNull) {
                    if ["dependencies","exdates"].contains(key) {
                        text+="    <\(key)>"
                        for ref in e[key] as? [String] ?? [] {let tag=key=="dependencies" ? "ref":(ref.count==10 ? "on":"at");let value=key=="exdates" && ref.count != 10 ? Dates.parse(ref).map(Dates.iso) ?? ref:ref;text+="<\(tag)>\(xmlEscape(value))</\(tag)>"};text+="</\(key)>\n"
                    }else{
                        let value=["start","finish","recurrenceId"].contains(key) && string(e,key).count != 10 ? Dates.parse(string(e,key)).map(Dates.iso) ?? string(e,key):(["reserve","cancelled"].contains(key) ? ((e[key] as? Bool ?? false) ? "true":"false"):String(describing:e[key]!))
                        text+="    <\(key)>\(xmlEscape(value))</\(key)>\n"
                    }
                }
            };text+="  </elemento>\n"
        };return text+"</universidad>\n"
    }
    func exportICS() throws -> String {
        func esc(_ s:String)->String{s.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\n",with:"\\n").replacingOccurrences(of:",",with:"\\,").replacingOccurrences(of:";",with:"\\;")}
        var lines=["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//Nodal//ES","CALSCALE:GREGORIAN","X-WR-TIMEZONE:Europe/Madrid","BEGIN:VTIMEZONE","TZID:Europe/Madrid","BEGIN:DAYLIGHT","DTSTART:19700329T020000","TZOFFSETFROM:+0100","TZOFFSETTO:+0200","TZNAME:CEST","RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU","END:DAYLIGHT","BEGIN:STANDARD","DTSTART:19701025T030000","TZOFFSETFROM:+0200","TZOFFSETTO:+0100","TZNAME:CET","RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU","END:STANDARD","END:VTIMEZONE"]
        for e in try entities().filter({["event","series","occurrence"].contains(string($0,"kind"))}) {
            lines += ["BEGIN:VEVENT","UID:"+esc(string(e,"uid",string(e,"id"))),"DTSTAMP:"+Dates.iso(Date()).replacingOccurrences(of:"-",with:"").replacingOccurrences(of:":",with:"")]
            if let d=Dates.parse(string(e,"date")) {lines.append("DTSTART;VALUE=DATE:"+Dates.format(d,"yyyyMMdd"));if let end=Dates.parse(string(e,"dateEnd")){lines.append("DTEND;VALUE=DATE:"+Dates.format(end,"yyyyMMdd"))}}
            else if let d=Dates.parse(string(e,"start")){lines.append("DTSTART;TZID=Europe/Madrid:"+Dates.format(d,"yyyyMMdd'T'HHmmss"));if let end=Dates.parse(string(e,"finish")){lines.append("DTEND;TZID=Europe/Madrid:"+Dates.format(end,"yyyyMMdd'T'HHmmss"))}}
            if string(e,"kind")=="series" {lines.append("RRULE:"+string(e,"rrule"));for ex in e["exdates"] as? [String] ?? [] {if let d=Dates.parse(ex){lines.append(ex.count==10 ? "EXDATE;VALUE=DATE:"+Dates.format(d,"yyyyMMdd"):"EXDATE;TZID=Europe/Madrid:"+Dates.format(d,"yyyyMMdd'T'HHmmss"))}}}
            if string(e,"kind")=="occurrence",let d=Dates.parse(string(e,"recurrenceId")){lines.append(string(e,"recurrenceId").count==10 ? "RECURRENCE-ID;VALUE=DATE:"+Dates.format(d,"yyyyMMdd"):"RECURRENCE-ID;TZID=Europe/Madrid:"+Dates.format(d,"yyyyMMdd'T'HHmmss"))}
            lines += ["SUMMARY:"+esc(string(e,"title")),"LOCATION:"+esc(string(e,"location")),"DESCRIPTION:"+esc(string(e,"description")),"CATEGORIES:"+string(e,"category").uppercased()]
            if e["cancelled"] as? Bool==true {lines.append("STATUS:CANCELLED")};lines.append("END:VEVENT")
        };lines.append("END:VCALENDAR")
        return lines.map{line->String in var out="",bytes=0;for ch in line{let n=String(ch).utf8.count;if bytes+n>73 {out+="\r\n ";bytes=1};out.append(ch);bytes+=n};return out}.joined(separator:"\r\n")+"\r\n"
    }
}
