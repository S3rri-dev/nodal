// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CoreFoundation

extension Store {
    func validateGradeComponents(_ raw:Any) throws {
        guard let components=raw as? [Object],components.count<=100 else {throw problem("La calculadora admite hasta 100 componentes válidos")}
        func numeric(_ raw:Any?,_ label:String,_ maximum:Double) throws -> Double? {
            guard let raw=raw,!(raw is NSNull) else{return nil}
            let text:String
            if let value=raw as? String {text=value.trimmingCharacters(in:.whitespacesAndNewlines)}
            else if let value=raw as? NSNumber,CFGetTypeID(value) != CFBooleanGetTypeID(){text=value.stringValue}
            else{throw problem(label+": introduce un número válido")}
            if text.isEmpty{return nil}
            guard text.range(of:"^[+-]?(?:\\d+(?:[.,]\\d*)?|[.,]\\d+)$",options:.regularExpression) != nil,
                  let n=Double(text.replacingOccurrences(of:",",with:".")),n.isFinite,n>=0,n<=maximum else {
                throw problem(label+": valor entre 0 y \(Int(maximum))")
            };return n
        }
        var total=0.0
        for (index,c) in components.enumerated() {
            total += try numeric(c["weight"],"Peso del componente \(index+1)",100) ?? 0
            _=try numeric(c["grade"],"Nota del componente \(index+1)",10)
        }
        guard total<=100+1e-8 else {throw problem("Los pesos suman más del 100 %. Revisa los componentes.")}
    }
}
