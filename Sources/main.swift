// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import WebKit
import Darwin
import UniformTypeIdentifiers

let resourceURL=Bundle.main.resourceURL?.appendingPathComponent("web").deletingLastPathComponent() ?? URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
let resolvedResources=FileManager.default.fileExists(atPath:resourceURL.appendingPathComponent("seed.json").path) ? resourceURL:URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
let dataURL=(ProcessInfo.processInfo.environment["NODAL_DATA"] ?? ProcessInfo.processInfo.environment["MI_UNIVERSIDAD_DATA"] ?? Bundle.main.object(forInfoDictionaryKey:"MUTestDataDirectory") as? String).map{URL(fileURLWithPath:$0)} ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent(Bundle.main.object(forInfoDictionaryKey:"NodalDataFolder") as? String ?? "Nodal")

final class AppDelegate:NSObject,NSApplicationDelegate,WKScriptMessageHandler,WKNavigationDelegate,NSWindowDelegate {
    var window:NSWindow!;var web:WKWebView!;var store:Store!;var pulse:Timer?;var instanceFD:Int32 = -1;var statusItem:NSStatusItem?;var remindersDay=""
    func applicationDidFinishLaunching(_ notification:Notification) {
        do {
            try FileManager.default.createDirectory(at:dataURL,withIntermediateDirectories:true)
            instanceFD=Darwin.open(dataURL.appendingPathComponent("instance.lock").path,O_CREAT|O_RDWR,0o600)
            guard instanceFD>=0,flock(instanceFD,LOCK_EX|LOCK_NB)==0 else {throw problem("Nodal ya está abierta para estos datos")}
            store=try Store(directory:dataURL,resources:resolvedResources)
            NSApp.applicationIconImage=NSImage(contentsOf:resolvedResources.appendingPathComponent("web/brand/nodal-icon-512.png"))
            let config=WKWebViewConfiguration();config.userContentController.add(self,name:"native")
            web=WKWebView(frame:.zero,configuration:config);web.navigationDelegate=self
            window=NSWindow(contentRect:NSRect(x:0,y:0,width:1360,height:880),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.titlebarAppearsTransparent=true;window.backgroundColor = .windowBackgroundColor;web.underPageBackgroundColor = .windowBackgroundColor
            try applyNativeAppearance()
            window.title=Bundle.main.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? "Nodal";window.minSize=NSSize(width:1024,height:700);window.contentView=web;window.delegate=self;window.center();window.makeKeyAndOrderFront(nil)
            let menu=NSMenu();let item=NSMenuItem();menu.addItem(item);let appMenu=NSMenu();appMenu.addItem(withTitle:"Acerca de Nodal",action:#selector(about),keyEquivalent:"");appMenu.addItem(withTitle:"Licencia y avisos",action:#selector(showLicense),keyEquivalent:"");appMenu.addItem(.separator());appMenu.addItem(withTitle:"Ocultar Nodal",action:#selector(NSApplication.hide(_:)),keyEquivalent:"h");appMenu.addItem(withTitle:"Salir de Nodal",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=appMenu
            let edit=NSMenuItem();menu.addItem(edit);let edits=NSMenu(title:"Edición");for (title,key,sel) in [("Deshacer","z","undo:"),("Cortar","x","cut:"),("Copiar","c","copy:"),("Pegar","v","paste:"),("Seleccionar todo","a","selectAll:")] {edits.addItem(withTitle:title,action:Selector(sel),keyEquivalent:key)};edit.submenu=edits;NSApp.mainMenu=menu
            web.loadFileURL(resolvedResources.appendingPathComponent("web/index.html"),allowingReadAccessTo:resolvedResources)
            pulse=Timer.scheduledTimer(withTimeInterval:5,repeats:true){[weak self] _ in
                guard let self=self else{return};do{try self.store.heartbeat();let text=try json(self.store.timer);self.web.evaluateJavaScript("window.timerUpdate?.(\(text))");self.configureMenu();if self.remindersDay != Dates.format(Date(),"yyyy-MM-dd") {try self.scheduleReminders()}}catch{self.show(error.localizedDescription)}
            }
            NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(sleeping),name:NSWorkspace.willSleepNotification,object:nil)
            NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(accessibilityOptionsChanged(_:)),name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
            configureMenu();try scheduleReminders()
            NSApp.activate(ignoringOtherApps:true)
        }catch{let alert=NSAlert();alert.messageText="No se pudo abrir Nodal";alert.informativeText=error.localizedDescription;alert.runModal();NSApp.terminate(nil)}
    }
    @objc func about(){
        let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.6.0"
        NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Nodal",.applicationVersion:version,.credits:NSAttributedString(string:"Copyright © 2026 S3rri-dev y colaboradores\nCódigo: GPL-3.0-or-later · Sin garantía\nNombre y logo reservados; consulta TRADEMARKS.md\nFuente: https://github.com/S3rri-dev/nodal")])
    }
    @objc func showLicense(){if let url=Bundle.main.url(forResource:"LICENSE",withExtension:"txt"){NSWorkspace.shared.open(url)}}

    @objc func sleeping(){try? store.pauseTimer(reason:"Mac suspendido. El tiempo de suspensión se excluye. Reanuda al volver.")}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        do{try store?.pauseTimer(reason:"Aplicación cerrada. El tiempo de ausencia se excluye.")}catch{show(error.localizedDescription);return .terminateCancel};return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
    func show(_ message:String){let a=NSAlert();a.messageText="Nodal";a.informativeText=message;a.runModal()}
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){
        let path=navigationAction.request.url?.standardizedFileURL.path ?? ""
        decisionHandler(path.hasPrefix(resolvedResources.appendingPathComponent("web").path+"/") ? .allow:.cancel)
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage){
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL==true, let body=message.body as? Object,let id=body["id"] as? Int else{return}
        let action=string(body,"action"),params=body["params"] as? Object ?? [:]
        if action=="reminders" {configureReminders(params,id);return}
        if ["chooseXML","chooseICS","saveText","exportBackup","restoreBackup","chooseMaterials"].contains(action) {performFileAction(action,params,id);return}
        do{let result=try handle(action,params);reply(id,result:result)}
        catch{let data=(try? json(["id":id,"ok":false,"error":error.localizedDescription])) ?? "{}";web.evaluateJavaScript("window.nativeReply(\(data))")}
    }
    func reply(_ id:Int,result:Any) {
        guard let text=try? json(["id":id,"ok":true,"result":result]) else{return};web.evaluateJavaScript("window.nativeReply(\(text))")
    }
    func replyError(_ id:Int,_ error:Error) {
        if let text=try? json(["id":id,"ok":false,"error":error.localizedDescription]) {web.evaluateJavaScript("window.nativeReply(\(text))")}
    }
    func performFileAction(_ action:String,_ p:Object,_ id:Int) {
        let saving=["saveText","exportBackup"].contains(action)
        let panel:NSSavePanel=saving ? NSSavePanel():NSOpenPanel()
        panel.prompt=saving ? "Guardar":"Abrir";panel.title="Nodal"
        if let chooser=panel as? NSOpenPanel {
            chooser.canChooseDirectories=action=="chooseMaterials";chooser.canChooseFiles=action != "chooseMaterials";chooser.allowsMultipleSelection=false
            chooser.allowsOtherFileTypes=true
            if action=="chooseXML" {chooser.allowedContentTypes=[.xml]}
            if action=="chooseICS",let type=UTType(filenameExtension:"ics") {chooser.allowedContentTypes=[type]}
        }else{
            let title=string(p,"title")
            panel.nameFieldStringValue=action=="exportBackup" ? "Nodal-\(Dates.format(Date(),"yyyyMMdd")).sqlite":(title.contains("Calendario") ? "Nodal.ics":(title.contains("Plan") ? "Nodal.xml":"Nodal.md"))
        }
        panel.beginSheetModal(for:window) {response in
            guard response == .OK,let url=panel.url else{self.reply(id,result:false);return}
            do {
                switch action {
                case "chooseXML","chooseICS":
                    let size=(try FileManager.default.attributesOfItem(atPath:url.path)[.size] as? NSNumber)?.intValue ?? 0
                    guard size<=5_000_000 else{throw problem("Archivo demasiado grande")}
                    let input=try Data(contentsOf:url)
                    let preview=action=="chooseXML" ? try self.store.previewXML(input):try self.store.previewICS(String(data:input,encoding:.utf8) ?? "")
                    self.reply(id,result:preview)
                case "exportBackup":try self.store.db.backup(to:url.path);self.reply(id,result:url.path)
                case "saveText":try string(p,"text").write(to:url,atomically:true,encoding:.utf8);self.reply(id,result:true)
                case "restoreBackup":try self.store.restore(url.path);self.reply(id,result:true)
                case "chooseMaterials":try self.store.setSetting("materials",url.path);self.reply(id,result:url.path)
                default:break
                }
            }catch{self.replyError(id,error)}
        }
    }
    func handle(_ action:String,_ p:Object) throws -> Any {
        switch action {
        case "snapshot":var snapshot=try store.snapshot(p);snapshot["accessibility"]=accessibilityPreferences();return snapshot
        case "fileByPath":
            let path=(string(p,"path") as NSString).expandingTildeInPath,url=URL(fileURLWithPath:path),mode=string(p,"mode")
            switch mode {
            case "exportBackup":
                guard url.pathExtension=="sqlite",!FileManager.default.fileExists(atPath:path) else{throw problem("Usa un nombre nuevo terminado en .sqlite; no se sobrescriben copias existentes")};try store.db.backup(to:path)
            case "restoreBackup":try store.restore(path);try scheduleReminders()
            case "chooseMaterials":
                var isDirectory:ObjCBool=false;guard FileManager.default.fileExists(atPath:path,isDirectory:&isDirectory),isDirectory.boolValue else{throw problem("La carpeta no existe")};try store.setSetting("materials",path)
            case "saveText":guard !FileManager.default.fileExists(atPath:path) else{throw problem("El archivo ya existe; elige otro nombre")};try string(p,"text").write(to:url,atomically:true,encoding:.utf8)
            default:throw problem("Operación de archivo desconocida")
            };return true
        case "previewFile":
            let path=(string(p,"path") as NSString).expandingTildeInPath,url=URL(fileURLWithPath:path),type=string(p,"type")
            guard url.pathExtension.lowercased()==type,["xml","ics"].contains(type) else{throw problem("Selecciona un archivo .xml o .ics del tipo indicado")}
            let size=(try FileManager.default.attributesOfItem(atPath:url.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size<=2_000_000 else{throw problem("Archivo supera 2 MB")}
            let input=try Data(contentsOf:url)
            return type=="xml" ? try store.previewXML(input):try store.previewICS(String(data:input,encoding:.utf8) ?? "")
        case "applyImport":let report=try store.applyImport(token:string(p,"token"),choices:p["choices"] as? Object ?? [:]);try scheduleReminders();return report
        case "exportPlan":return try store.exportPlan()
        case "exportICS":return try store.exportICS()
        case "copyText":NSPasteboard.general.clearContents();NSPasteboard.general.setString(string(p,"text"),forType:.string);return true
        case "replanCandidates":return try store.replanCandidates()
        case "previewReplan":return try store.previewReplan(p)
        case "applyReplan":let report=try store.applyReplan(p);try scheduleReminders();return report
        case "undoReplan":let report=try store.undoReplan(string(p,"id"));try scheduleReminders();return report
        case "examPreparation":return try store.examPreparation(string(p,"id"))
        case "splitSession":return try store.splitSession(p)
        case "exportSummary":return try store.subjectSummary(string(p,"subject"))
        case "timeHistory":return ["records":try store.rows("time_records",deleted:true),"audit":try store.rows("audit")]
        case "saveEntity":let entity=try store.saveEntity(p);try scheduleReminders();return entity
        case "saveUser":try store.saveUser(string(p,"id"),p["user"] as? Object ?? [:]);return true
        case "checkMove":return ["issues":try store.moveIssues(p),"alternative":try store.alternative(p) as Any? ?? NSNull()]
        case "startTimer":try store.startTimer(p);return store.timer
        case "pauseTimer":try store.pauseTimer();return store.timer
        case "resumeTimer":try store.resumeTimer();return store.timer
        case "finishTimer":return try store.finishTimer()
        case "saveTime":return try store.saveTime(p)
        case "saveDoubt":return try store.saveDoubt(p)
        case "saveAttempt":return try store.journal("attempts",p)
        case "saveReview":return try store.journal("reviews",p)
        case "deleteRecord":try store.deleteRecord(string(p,"table"),string(p,"id"),undo:p["undo"] as? Bool ?? false);return true
        case "exportDoubts":return try store.exportDoubts(professorOnly:p["professorOnly"] as? Bool ?? false)
        case "menuBar":try store.setSetting("menuBar",(p["enabled"] as? Bool ?? false) ? "true":"false");configureMenu();return true
        case "theme":try store.setSetting("theme",string(p,"value"));try applyNativeAppearance();return true
        case "backup":return try store.backup()
        case "openMaterial":
            guard let source=try store.entity(string(p,"id")),string(source,"kind")=="source" else {throw problem("Fuente no localizada")}
            let root=try store.setting("materials"),original=string(source,"path"),relative=original.components(separatedBy:"/Universidad/").last ?? (original as NSString).lastPathComponent
            let url=URL(fileURLWithPath:root).appendingPathComponent(relative).standardizedFileURL
            guard url.path.hasPrefix(URL(fileURLWithPath:root).standardizedFileURL.path+"/"),url.pathExtension.lowercased()=="pdf",FileManager.default.fileExists(atPath:url.path) else {throw problem("Archivo no localizado. Selecciona o repara la carpeta de materiales en Ajustes.\n\(url.path)")};NSWorkspace.shared.open(url);return true
        default:throw problem("Acción desconocida: \(action)")
        }
    }
}

if CommandLine.arguments.contains("--check") {
    guard ProcessInfo.processInfo.environment["NODAL_DATA"] != nil || ProcessInfo.processInfo.environment["MI_UNIVERSIDAD_DATA"] != nil else {fputs("Usa NODAL_DATA con una carpeta de prueba para --check.\n",stderr);exit(1)}
    do{let store=try Store(directory:dataURL,resources:resolvedResources);let all=try store.entities();print("SQLite OK · \(all.count) entidades · \(all.filter{string($0,"kind")=="series"}.count) series · \(all.filter{string($0,"category")=="exam"}.count) pruebas · \(all.filter{string($0,"category")=="study"}.count) bloques");exit(0)}catch{fputs("\(error)\n",stderr);exit(1)}
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(.regular);app.delegate=delegate;app.run()
