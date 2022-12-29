//
//  WrapFunction+Extension.swift
//  PythonSwiftLink
//
//  Created by MusicMaker on 26/12/2022.
//  Copyright © 2022 Example Corporation. All rights reserved.
//

import Foundation


public extension WrapFunction {
    func generate(PyMethod_withArgs cls_title: String?) -> String {
        let arg_extract = _args_.map { a in
            "let \(a.name) = \(a.type.swiftType)(args?[\(a.idx)])"
        }.joined(separator: ",\n\t\t")
        let args = _args_.map { a in
            "\(a.name): \(a.name)"
        }.joined(separator: ", ")
        var cls_call = ""
        if let cls_title = cls_title {
            cls_call = "(s.getSwiftPointer() as \(cls_title))."
        }
        let rtn_type = _return_.type
        let use_rtn = !(rtn_type == .void || rtn_type == .None)
        let result = use_rtn ? "let __result__ = " : ""
        let rtn = use_rtn ? "__result__.pyPointer" : ".PyNone"
        return """
        .init(withArgs: "\(name)") { s, args, nargs in
            guard
                nargs == \(_args_.count),
                \(arg_extract)
            else { return PyPointer.PyNone! }
            \(result)\(cls_call)\(name)(\(args))
            return \(rtn)
        }
        """
    }
    
    
    
    func generate(PyMethod_oneArg cls_title: String?) -> String {
        guard let arg = _args_.first else { return "//NoArg Handler missing\n" }
        var cls_call = ""
        if let cls_title = cls_title {
            cls_call = "(s.getSwiftPointer() as \(cls_title))."
        }
        let rtn_type = _return_.type
        let use_rtn = !(rtn_type == .void || rtn_type == .None)
        let result = use_rtn ? "let __result__ = " : ""
        let rtn = use_rtn ? "__result__.pyPointer" : ".PyNone"
        return """
        .init(oneArg: "\(name)") { s, \(arg.name) in
            \(result)\(cls_call)\(name)(\(arg.swift_send_call_arg))
            return \(rtn)
        }
        """
    }
    
    
    func generate(PyMethod_noArgs cls_title: String?) -> String {
        var cls_call = ""
        if let cls_title = cls_title {
            cls_call = "(s.getSwiftPointer() as \(cls_title))."
        }
        let rtn_type = _return_.type
        let use_rtn = !(rtn_type == .void || rtn_type == .None)
        let result = use_rtn ? "let __result__ = " : ""
        let rtn = use_rtn ? "__result__.pyPointer" : ".PyNone"
        return """
        .init(noArgs: "\(name)") { s, arg in
            \(result)\(cls_call)\(name)()
            return \(rtn)
        }
        """
    }
}
