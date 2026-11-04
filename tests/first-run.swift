// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
func verifyFirstRun(root:URL) throws {
    let resources=root.appendingPathComponent("Resources")
    let dir=root.appendingPathComponent("build/first-run-"+identifier())
    let s=try Store(directory:dir,resources:resources)
    try check(try s.entities().isEmpty,"primer arranque público vacío")
    try check(try s.setting("materials").isEmpty,"sin carpeta de materiales del autor")
    try check(try s.rows("doubts").isEmpty && s.rows("time_records").isEmpty,"sin registros personales iniciales")
    _=try s.saveEntity(["id":"FIRST","kind":"subject","title":"Mi primera asignatura","color":"#7A223C"])
    try check(try s.entity("FIRST-plan") != nil,"primera asignatura crea su tema")
    let again=try Store(directory:dir,resources:resources)
    try check(try again.entity("FIRST") != nil,"reapertura conserva la primera asignatura")
    try check(try again.entities().count==2,"semilla pública no duplica ni sustituye contenidos")
}
