// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import UserNotifications

extension AppDelegate {
    func configureMenu() {
        if (try? store.setting("menuBar")) != "true" {if let item=statusItem{NSStatusBar.system.removeStatusItem(item);statusItem=nil};return}
        if statusItem==nil {statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);let image=NSImage(contentsOf:resolvedResources.appendingPathComponent("brand/nodal-template.png"));image?.size=NSSize(width:18,height:18);image?.isTemplate=true;image?.accessibilityDescription="Nodal";statusItem?.button?.image=image}
        let menu=NSMenu();menu.addItem(withTitle:"Abrir Nodal",action:#selector(openFromMenu),keyEquivalent:"").target=self
        let t=store.timer
        let title=t.isEmpty ? "Sin cronómetro":string(t,"subject")+" · "+String(Int(store.timerSeconds()/60))+" min"
        let info=menu.addItem(withTitle:title,action:nil,keyEquivalent:"");info.isEnabled=false
        if !t.isEmpty {
            menu.addItem(withTitle:string(t,"state")=="running" ? "Pausar":"Reanudar",action:#selector(toggleFromMenu),keyEquivalent:"").target=self
            menu.addItem(withTitle:"Finalizar y guardar tiempo",action:#selector(finishFromMenu),keyEquivalent:"").target=self
        }
        menu.addItem(.separator());menu.addItem(withTitle:"Salir",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"")
        statusItem?.menu=menu
    }
    @objc func openFromMenu(){window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);web.evaluateJavaScript("window.openFocus?.()")}
    @objc func toggleFromMenu(){do{if string(store.timer,"state")=="running" {try store.pauseTimer()}else{try store.resumeTimer()};publishTimer()}catch{show(error.localizedDescription)}}
    @objc func finishFromMenu(){do{_=try store.finishTimer();publishTimer()}catch{show(error.localizedDescription)}}
    func publishTimer(){configureMenu();if let t=try? json(store.timer){web.evaluateJavaScript("window.timerUpdate?.(\(t))")}}
    func configureReminders(_ params:Object,_ id:Int) {
        let enabled=params["enabled"] as? Bool ?? false,lead=number(params,"minutes",30)
        guard lead>=1 && lead<=1440 else{replyError(id,problem("Antelación entre 1 y 1440 minutos"));return}
        let center=UNUserNotificationCenter.current()
        if !enabled {center.removeAllPendingNotificationRequests();do{try store.setSetting("reminders",try json(["enabled":false,"minutes":lead]));reply(id,result:true)}catch{replyError(id,error)};return}
        center.requestAuthorization(options:[.alert,.sound]) {granted,error in
            DispatchQueue.main.async {
                guard granted else{self.replyError(id,error ?? problem("macOS no ha permitido notificaciones. Puedes autorizarlas desde Ajustes del Sistema."));return}
                do{try self.store.setSetting("reminders",try json(["enabled":true,"minutes":lead]));try self.scheduleReminders();self.reply(id,result:true)}catch{self.replyError(id,error)}
            }
        }
    }
    func scheduleReminders() throws {
        let config=object(try store.setting("reminders"));guard config["enabled"] as? Bool==true else{return}
        let center=UNUserNotificationCenter.current();center.removeAllPendingNotificationRequests()
        let now=Date(),lead=number(config,"minutes",30)*60
        let events=try store.events(from:now,to:Dates.add(now,days:28)).filter{string($0,"category") != "availability" && !string($0,"start").isEmpty}.prefix(60)
        for e in events {
            guard let start=Dates.parse(string(e,"start")),start.addingTimeInterval(-lead)>now else{continue}
            let content=UNMutableNotificationContent();content.title=string(e,"title");content.body="\(Dates.format(start,"HH:mm")) · \(string(e,"location","Lugar pendiente"))";content.sound = .default
            var parts=Dates.cal.dateComponents([.year,.month,.day,.hour,.minute],from:start.addingTimeInterval(-lead));parts.timeZone=Dates.zone
            let request=UNNotificationRequest(identifier:"academico-"+string(e,"id"),content:content,trigger:UNCalendarNotificationTrigger(dateMatching:parts,repeats:false));center.add(request)
        }
        remindersDay=Dates.format(now,"yyyy-MM-dd")
    }
}
