// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
func verifyGradeStorage(resources:URL,root:URL) throws {
    let s=try Store(directory:root.appendingPathComponent("build/grades-"+identifier()),resources:resources)
    try s.saveUser("AC",["notes":"Conservar notas personales","gradeComponents":[["name":"Prueba A","group":"Teoría","weight":"50","grade":"6,5"],["name":"Prueba B","group":"Laboratorio","weight":"50","grade":""]]])
    let stored=try s.entity("AC")!["user"] as! Object
    try check((stored["gradeComponents"] as! [Object]).count==2,"componentes de notas persistidos con decimal español y nota desconocida")
    try s.saveUser("AC",["gradeComponents":[["name":"Prueba A","group":"Teoría","weight":"50","grade":"6,5"]]])
    try check(string(try s.entity("AC")!["user"] as! Object,"notes")=="Conservar notas personales","editar componentes conserva las notas personales")
    let before=try s.planFingerprint()
    for (label,components) in [
        ("nota fuera de rango",[["grade":"11","weight":"100"]] as [Object]),
        ("peso fuera de rango",[["grade":"5","weight":"101"]]),
        ("pesos acumulados",[["grade":"5","weight":"60"],["grade":"5","weight":"60"]]),
        ("nota no numérica",[["grade":"NaN","weight":"100"]]),
        ("booleano en nota",[["grade":true,"weight":"100"]])
    ] {try rejects("componentes con "+label){try s.saveUser("AC",["gradeComponents":components])}}
    try check(try s.planFingerprint()==before,"validación de componentes rechaza sin modificar SQLite")
    try s.saveUser("AC",["gradeComponents":[Object]()])
    try check((try s.entity("AC")!["user"] as! Object)["gradeComponents"] as? [Object] != nil,"se pueden guardar cero componentes")
    try check(((try s.entity("AC")!["user"] as! Object)["gradeComponents"] as! [Object]).isEmpty,"eliminar todos no recrea componentes de ejemplo")
    try s.saveUser("AC",["gradeComponents":[["name":"Cero","grade":0,"weight":100]]])
    let reopened=try Store(directory:s.directory,resources:resources)
    let zero=((try reopened.entity("AC")!["user"] as! Object)["gradeComponents"] as! [Object])[0]
    try check(number(zero,"grade",-1)==0,"cero y componentes se conservan al reabrir SQLite")
}
