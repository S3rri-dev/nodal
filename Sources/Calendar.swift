// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

struct AcademicCalendar {
    static let weekdays=["SU","MO","TU","WE","TH","FR","SA"]
    static let allowedRules:Set<String>=["FREQ","INTERVAL","UNTIL","COUNT","BYDAY","BYMONTHDAY","BYMONTH","WKST"]
    static func rules(_ s: String) throws -> [String:String] {
        var r=[String:String]()
        for part in s.split(separator:";") {
            let kv=part.split(separator:"=",maxSplits:1).map(String.init)
            guard kv.count==2, allowedRules.contains(kv[0]), r[kv[0]]==nil else { throw problem("RRULE no admitida: \(part)") }; r[kv[0]]=kv[1]
        }
        guard ["DAILY","WEEKLY","MONTHLY","YEARLY"].contains(r["FREQ"] ?? ""), Int(r["INTERVAL"] ?? "1") ?? 0 > 0, r["WKST"]==nil || r["WKST"]=="MO" else { throw problem("Recurrencia inválida o WKST distinto de MO") }
        if let count=r["COUNT"], Int(count) ?? 0 <= 0 { throw problem("COUNT inválido") }
        if let until=r["UNTIL"], icsDate(until)==nil { throw problem("UNTIL inválido") }
        if let b=r["BYDAY"], !b.split(separator:",").allSatisfy({ $0.range(of:"^([+-]?[1-5])?(MO|TU|WE|TH|FR|SA|SU)$",options:.regularExpression) != nil }) { throw problem("BYDAY inválido") }
        if ["DAILY","WEEKLY"].contains(r["FREQ"] ?? ""),let by=r["BYDAY"],by.split(separator:",").contains(where:{$0.count>2}) {throw problem("Ordinal BYDAY solo en recurrencias mensuales/anuales")}
        if let b=r["BYMONTHDAY"], !b.split(separator:",").allSatisfy({ if let n=Int($0){return n != 0 && abs(n)<=31};return false }) { throw problem("BYMONTHDAY inválido") }
        if let b=r["BYMONTH"], !b.split(separator:",").allSatisfy({ (1...12).contains(Int($0) ?? 0) }) { throw problem("BYMONTH inválido") }
        return r
    }
    static func icsDate(_ s: String) -> Date? {
        let f=DateFormatter(); f.locale=Locale(identifier:"en_US_POSIX"); f.timeZone=s.hasSuffix("Z") ? TimeZone(secondsFromGMT:0) : Dates.zone; f.dateFormat=s.count==8 ? "yyyyMMdd" : (s.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"); return f.date(from:s)
    }
    static func occurrences(_ entity: Object, from: Date, to: Date) throws -> [Object] {
        let allDay=string(entity,"start").isEmpty && !string(entity,"date").isEmpty
        guard let start=Dates.parse(string(entity,"start",string(entity,"date"))), to>from, to.timeIntervalSince(from)<=100*86400 else { return [] }
        let rule=try rules(string(entity,"rrule")); let c=Dates.cal
        let limit=rule["UNTIL"].flatMap(icsDate) ?? to
        let count=Int(rule["COUNT"] ?? "100000") ?? 100000
        let interval=Int(rule["INTERVAL"] ?? "1") ?? 1
        let duration=Dates.parse(string(entity,"finish"))?.timeIntervalSince(start)
        let dateDays=Dates.parse(string(entity,"dateEnd")).map{c.dateComponents([.day],from:start,to:$0).day ?? 1} ?? 1
        let ex=Set((entity["exdates"] as? [String] ?? []).compactMap(Dates.parse).map{$0.timeIntervalSince1970})
        let anchorDay=c.startOfDay(for:start), anchorWeek=c.dateInterval(of:.weekOfYear,for:start)!.start
        var day=anchorDay, emitted=0, scanned=0, output=[Object]()
        while day<to && day<=Dates.add(limit,days:1) && emitted<count && scanned<36600 {
            defer{ day=Dates.add(day,days:1); scanned+=1 }
            let diff=c.dateComponents([.day],from:anchorDay,to:day).day ?? 0
            let monthDiff=(c.component(.year,from:day)-c.component(.year,from:start))*12+c.component(.month,from:day)-c.component(.month,from:start)
            let weekday=weekdays[c.component(.weekday,from:day)-1]
            var match=false
            switch rule["FREQ"] {
            case "DAILY": match=diff%interval==0
            case "WEEKLY": match=((c.dateComponents([.day],from:anchorWeek,to:day).day ?? 0)/7)%interval==0
            case "MONTHLY": match=monthDiff%interval==0
            case "YEARLY": match=(c.component(.year,from:day)-c.component(.year,from:start))%interval==0
            default: break
            }
            if !match {continue}
            if let months=rule["BYMONTH"] { match=months.split(separator:",").contains(Substring(String(c.component(.month,from:day)))) }
            else if rule["FREQ"]=="YEARLY" { match=c.component(.month,from:day)==c.component(.month,from:start) }
            if !match {continue}
            if let by=rule["BYDAY"] {
                let dom=c.component(.day,from:day), days=c.range(of:.day,in:.month,for:day)!.count
                match=by.split(separator:",").contains{token in
                    guard token.hasSuffix(weekday) else {return false}
                    let ord=Int(token.dropLast(2)) ?? 0
                    return ord==0 || (ord>0 ? (dom-1)/7+1==ord : -((days-dom)/7+1)==ord)
                }
            } else if rule["FREQ"]=="WEEKLY" { match=c.component(.weekday,from:day)==c.component(.weekday,from:start) }
            else if ["MONTHLY","YEARLY"].contains(rule["FREQ"] ?? ""), rule["BYMONTHDAY"]==nil { match=c.component(.day,from:day)==c.component(.day,from:start) }
            if !match {continue}
            if let md=rule["BYMONTHDAY"] {
                let dom=c.component(.day,from:day),days=c.range(of:.day,in:.month,for:day)!.count
                match=md.split(separator:",").contains{ let n=Int($0) ?? 0;return n>0 ? n==dom : days+n+1==dom }
            }
            guard match, let occurrence=c.date(bySettingHour:c.component(.hour,from:start),minute:c.component(.minute,from:start),second:c.component(.second,from:start),of:day), occurrence>=start, occurrence<=limit else {continue}
            emitted+=1
            if ex.contains(occurrence.timeIntervalSince1970) {continue}
            let end=allDay ? Dates.add(occurrence,days:dateDays):duration.map{occurrence.addingTimeInterval($0)}
            if (end ?? occurrence)>=from && occurrence<to {
                var e=entity; let key=allDay ? Dates.format(occurrence,"yyyy-MM-dd"):Dates.format(occurrence)
                e["id"]=string(entity,"id")+"#"+key; e["series"]=string(entity,"id"); e["recurrenceId"]=key; e["kind"]="occurrence"; if allDay {e["date"]=key;if let end=end {e["dateEnd"]=Dates.format(end,"yyyy-MM-dd")}}
                else {e["start"]=key;if let end=end {e["finish"]=Dates.format(end)}}
                output.append(e)
            }
        }
        return output
    }
    static func unfold(_ text: String) -> [String] {
        text.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").replacingOccurrences(of:"\n ",with:"").replacingOccurrences(of:"\n\t",with:"").components(separatedBy:"\n")
    }
    static func parseICS(_ text: String) throws -> [Object] {
        guard text.utf8.count<=5_000_000 else {throw problem("ICS supera 5 MB")}
        var rows=[Object](), props=[(String,String)](), inside=false, alarm=false
        for line in unfold(text) {
            if line=="BEGIN:VEVENT" {inside=true;props=[];continue}
            if line=="BEGIN:VALARM" {alarm=true;continue}; if line=="END:VALARM" {alarm=false;continue}
            if line=="END:VEVENT" {
                func val(_ key:String)->String {props.first{$0.0.components(separatedBy:";")[0]==key}?.1 ?? ""}
                func dateVal(_ key:String)->String? {guard let raw=props.first(where:{$0.0.components(separatedBy:";")[0]==key}) else{return nil};if raw.0.contains("TZID="), !raw.0.contains("TZID=Europe/Madrid") {return nil};return icsDate(raw.1).map{raw.1.count==8 ? Dates.format($0,"yyyy-MM-dd") : Dates.format($0)}}
                guard !val("UID").isEmpty, let start=dateVal("DTSTART") else {throw problem("VEVENT sin UID o DTSTART válido (solo UTC/Europe/Madrid)")}
                let rr=val("RRULE"); if !rr.isEmpty {_ = try rules(rr)}
                var e:Object=["id":val("UID"),"uid":val("UID"),"kind":rr.isEmpty ? "event":"series","title":val("SUMMARY"),"description":val("DESCRIPTION"),"location":val("LOCATION"),"category":"class","source":"ICS importado"]
                e[start.count==10 ? "date":"start"]=start
                if let end=dateVal("DTEND"){e[end.count==10 ? "dateEnd":"finish"]=end}
                if !rr.isEmpty {e["rrule"]=rr}
                var ex=[String]()
                for p in props where p.0.hasPrefix("EXDATE") {for v in p.1.split(separator:","){guard let d=icsDate(String(v)) else {throw problem("EXDATE inválido")};ex.append(v.count==8 ? Dates.format(d,"yyyy-MM-dd"):Dates.format(d))}}
                e["exdates"]=ex
                if let rec=dateVal("RECURRENCE-ID") {e["series"]=val("UID");e["recurrenceId"]=rec;e["id"]=val("UID")+"#"+rec;e["kind"]="occurrence"}
                if val("STATUS")=="CANCELLED" {e["cancelled"]=true}
                let category=val("CATEGORIES").lowercased().components(separatedBy:",").first ?? ""
                if ["class","exam","study","availability"].contains(category) {e["category"]=category}else{e["inferredCategory"]=true}
                rows.append(e);inside=false;continue
            }
            if inside && !alarm, let colon=line.firstIndex(of:":") {
                let k=String(line[..<colon]);if k.contains("TZID="),!k.contains("TZID=Europe/Madrid") {throw problem("TZID no admitida: usa Europe/Madrid o UTC")}; let v=String(line[line.index(after:colon)...]).replacingOccurrences(of:"\\n",with:"\n").replacingOccurrences(of:"\\,",with:",").replacingOccurrences(of:"\\;",with:";").replacingOccurrences(of:"\\\\",with:"\\")
                props.append((k,v))
            }
        }
        guard !rows.isEmpty, !inside, Set(rows.map{string($0,"id")}).count==rows.count else {throw problem("ICS incompleto, vacío o UID/RECURRENCE-ID duplicado")};return rows
    }
}
