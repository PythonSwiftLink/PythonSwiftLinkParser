//
//  WrapClass+Extensions.swift
//  PythonSwiftLink
//
//  Created by MusicMaker on 26/12/2022.
//  Copyright © 2022 Example Corporation. All rights reserved.
//

import Foundation


public extension WrapClass {
    
    var swift_string: String {
        """
        
        //
        // \(title)
        //
        
        fileprivate func setSwiftPointer(_ self: PyPointer  ,_ target: \(title)) {
            PySwiftObject_Cast(self).pointee.swift_ptr = Unmanaged.passRetained(target).toOpaque()
        }
        extension PythonPointer {
        
            fileprivate func getSwiftPointer() -> \(title) {
                return Unmanaged.fromOpaque(
                    PySwiftObject_Cast(self).pointee.swift_ptr
                ).takeUnretainedValue()
            }
        }
        
        \(PyGetSets)
        
        \(PyMethodDef_Output)
        
        \(PySequenceMethods_Output)
        
        \(MainFunctions)
        
        
        let \(title)PyType = SwiftPyType(
            name: "\(title)",
            functions: \(title)_PyFunctions,
            methods: \(title)_PyMethods,
            getsets: \(if: properties.isEmpty && functions.first(where: {$0.has_option(option: .callback)}) == nil, "nil", "\(title)_PyGetSets"),
            sequence: \(if: pySequenceMethods.isEmpty, "nil" , "\(title)_PySequenceMethods" ),
            module_target: nil
        )
        
        
        
        // Swift Init
        func create_py\(title)(_ data: \(title)) -> PythonObject {
            let new = PySwiftObject_New(\(title)PyType.pytype)
            setSwiftPointer(new, data)
            return .init(ptr: new, from_getter: true)
        }
        
        \(pyProtocol)
        """
    }
    
    
    
    
    private var PyMethodDef_Output: String {
        let funcs = functions.filter { !$0.has_option(option: .callback) }
        if funcs.isEmpty { return "fileprivate let \(title)_PyMethods = nil"}
        let _funcs = funcs.map { f in
            switch f._args_.count {
            case 0:
                return f.generate(PyMethod_noArgs: title)
            case 1:
                return f.generate(PyMethod_oneArg: title)
            default:
                return f.generate(PyMethod_withArgs: title)
                
            }
        }.map({$0.replacingOccurrences(of: newLine, with: newLineTab)}).joined(separator: ",\n\t")
        return """
        fileprivate let \(title)_PyMethods = PyMethodDefHandler(
            \(_funcs)
        )
        """
    }
    
    private var PySequenceMethods_Output: String {
        if pySequenceMethods.isEmpty { return "" }
        
        var length = "length: nil"
        var get_item = "get_item: nil"
        var set_item = "set_item: nil"
        
        for m in pySequenceMethods {
            switch m {
                
            case .__len__:
                length = """
                length: { s in
                    return (s.getSwiftPointer() as \(title)).__len__()
                }
                """.addTabs()
            case .__getitem__(key: _, returns: _):
                //let _key = key == .object ? "key" : ".init(key)"
                get_item = """
                get_item: { s, idx in
                    return (s.getSwiftPointer() as \(title)).__getitem__(idx: idx )
                }
                """.addTabs()
            case .__setitem__(key: _, value: _):
                //let _key = key == .object ? "key" : ".init(key)"
                set_item = """
                set_item: { s, idx, item in
                    if (s.getSwiftPointer() as \(title)).__setitem__(idx: idx, newValue: item ) {
                        return 0
                    }
                    return 1
                }
                """.addTabs()
            case .__delitem__(key: _):
                continue
            case .__missing__:
                continue
            case .__reversed__:
                continue
            case .__contains__:
                continue
            }
        }
        
        return """
        let \(title)_PySequenceMethods = PySequenceMethodsHandler(methods: .init(
            \(length),
            concat: nil,
            repeat_: nil,
            \(get_item),
            \(set_item),
            contains: nil,
            inplace_concat: nil,
            inplace_repeat: nil
            )
        )
        """
        /*
         let seq = PySequenceMethodsHandler(methods: .init(
         length: { s in
         return \(title).__len__()
         },
         concat: { lhs, rhs in
         return .PyNone
         },
         repeat_: { s, count in
         return .PyNone
         },
         get_item: { s, idx in
         return \(title).__getitem__()
         },
         set_item: { s, idx, item in
         return \(title).__setitem__()
         },
         contains: { s, o in
         return 1
         },
         inplace_concat: { lhs, rhs in
         return .PyNone
         },
         inplace_repeat: { s, count in
         return .PyNone
         }
         )
         )
         */
    }
    
    private var pyProtocol: String {
    
        var _init_function = ""
        
        if let _init = init_function {
            let init_args = _init._args_.map({ a in a.swift_protocol_arg }).joined(separator: ", ")
            _init_function = "init(\(init_args))"
        }
        
        let user_functions = functions.filter({!$0.has_option(option: .callback)}).map { function -> String in
            
            let swift_return = "\(if: function._return_.type != .void, "-> \(function._return_.swift_send_return_type)", "")"
            let protocol_args = function._args_.map{$0.swift_protocol_arg}.joined(separator: ", ")
            return """
            func \(function.name)(\(protocol_args )) \(swift_return)
            """
        }.joined(separator: newLineTab)
        
        let pyseq_functions = pySequenceMethods.map(\.protocol_string).joined(separator: newLineTab)
        
        return """
        // Protocol to make target class match the functions in wrapper file
        protocol \(title)_PyProtocol {
        
            \(_init_function)
            \(user_functions)
            \(pyseq_functions)
        
        }
        """
    }
    
    private var PyGetSets: String {
        var _properties = properties.filter { p in
            p.property_type == .GetSet || p.property_type == .Getter
        }
        let cls_callbacks = functions.first(where: {$0.has_option(option: .callback)}) != nil
        if _properties.isEmpty && !cls_callbacks {
            //return "fileprivate let \(cls.title)_PyGetSets = nil"
            return ""
        }
        if cls_callbacks {
            _properties.insert(.init(name: "callback_target", property_type: .GetSet, arg_type: .init(name: "", type: .object, other_type: "", idx: 0, arg_options: [])), at: 0)
        }
        
        let properties = _properties.map { p -> String in
            switch p.property_type {
            case .Getter:
                return generate(Getter: p, cls_title: title)
            case .GetSet:
                return generate(GetSet: p, cls_title: title)
            default:
                return ""
            }
        }.joined(separator: newLine)
        
        return """
        \(properties)
        
        fileprivate let \(title)_PyGetSets = PyGetSetDefHandler(
            \(_properties.map { "\(title)_\($0.name)"}.joined(separator: ",\n\t") )
        )
        """
    }
    
    private func generate(GetSet prop: WrapClassProperty, cls_title: String) -> String {
        let arg = prop.arg_type_new
        let is_object = arg.type == .object
        let call = "\(arg.swift_property_getter(arg: "(s.getSwiftPointer() as \(cls_title)).\(prop.name)"))"
        var setValue = is_object ? ".init(newValue)" : "newValue"
        var callValue = is_object ? "PyPointer(\(call))" : call
        if prop.name == "callback_target" {
            callValue = "\(call)?.pycall.ptr"
            setValue = ".init(callback: v)"
        }
        return """
        fileprivate let \(cls_title)_\(prop.name) = PyGetSetDefWrap(
            name: "\(prop.name)",
            getter: {s,clossure in
                if let v = \(callValue) {
                    return v
                }
                return .PyNone
            },
            setter: { s,v,clossure in
                let newValue = \(arg.swift_property_setter(arg: "v"))
                (s.getSwiftPointer() as \(cls_title)).\(prop.name) = \(setValue)
                return 0
                // return 1 if error
            }
        )
        """.replacingOccurrences(of: newLine, with: newLineTab)
    }
    
    private func generate(Getter prop: WrapClassProperty, cls_title: String) -> String {
        let arg = prop.arg_type_new
        let is_object = arg.type == .object
        let call = "\(arg.swift_property_getter(arg: "(s.getSwiftPointer() as \(cls_title)).\(prop.name)"))"
        let callValue = is_object ? "PyPointer(\(call))" : call
        return """
        fileprivate let \(cls_title)_\(prop.name) = PyGetSetDefWrap(
            name: "\(prop.name)",
            getter: { s,clossure in
                if let v = \(callValue) {
                    return v
                }
                return .PyNone
            }
        )
        """.replacingOccurrences(of: newLine, with: newLineTab)
    }
    
    private var MainFunctions: String {
        var __repr__ = "nil"
        var __str__  = "nil"
        var __hash__ = "nil"
        //var __init__ = "nil"
        
        
        for f in pyClassMehthods {
            switch f {
            case .__repr__:
                __repr__ = """
                { s in
                    (s.getSwiftPointer() as \(title)).__repr__().withCString(PyUnicode_FromString)
                }
                """.newLineTabbed
            case .__str__:
                __str__ = """
                { s in
                    (s.getSwiftPointer() as \(title)).__str__().withCString(PyUnicode_FromString)
                }
                """.newLineTabbed
            case .__hash__:
                __hash__ = """
                { s in
                    (s.getSwiftPointer() as \(title)).__hash__()
                }
                """.newLineTabbed
            case .__set_name__:
                ""
                
            default: continue
            }
        }
        var init_vars = ""
        var kw_extract = ""
        if let _init = init_function {
            let args = _init._args_
            init_vars = args.map { a in
                "var \(a.swift_protocol_arg)\(if: a.type != .object, "?") = nil"
            }.joined(separator: newLineTabTab)
            
        }
        let init_nargs = init_function?._args_.count ?? 0
        var init_args = [String]()
        var init_lines_kw = [String]()
        var init_lines = [String]()
        
        if let init_func = init_function {
            init_args = init_func._args_.map {a in "\(a.name): \(a.name)\(if: a.type != .object, "?")"}
            init_lines_kw = init_func._args_.map { a in
                return """
                let _\(a.name) = PyDict_GetItem(kw, "\(a.name)")
                """
            }
            init_lines = init_func._args_.map { a in
                let is_object = a.type == .object
                //                let extract = "PyTuple_GetItem(args, \(a.idx))"
                //                return "let \(a.name): \(a.type.swiftType) = \(is_object ? extract : "init(\(extract)")"
                return """
                if nargs > \(a.idx) {
                    \(a.name) = .init(PyTuple_GetItem(args, 0))
                } else {
                    if let _\(a.name) = PyDict_GetItem(kw, "\(a.name)") {
                        \(a.name) = .init(_\(a.name))
                    }
                }
                """.newLineTabbed
            }
        }
        
        let __init__ = """
        { s, args, kw -> Int32 in
            
            print("Py_Init \(title)")
            \(if: !(init_function?._args_.isEmpty ?? true), """
            
            \(init_vars)
            
            let nkwargs = (kw == nil) ? 0 : _PyDict_GET_SIZE(kw)
            if nkwargs >= \(init_nargs) {
                guard
                    \(init_lines_kw.joined(separator: ",\n\t\t\t"))
                else {
                    PyErr_SetString(PyExc_IndexError, "args missing needed \(init_nargs)")
                    return -1
                }
            } else {
                let nargs = _PyTuple_GET_SIZE(args)
            
                guard nkwargs + nargs >= \(init_nargs) else {
                    PyErr_SetString(PyExc_IndexError, "args missing needed \(init_nargs)")
                    return -1
                }
                \(init_lines.joined(separator: ",\n\t\t"))
            }
            
            """.addTabs())
            setSwiftPointer(
                s,
                .init(\(init_args.joined(separator: ", ")))
            )
            return 0
        }
        """.addTabs()
        
        let __dealloc__ = """
        { s in
            print("\(title) dealloc", s.printString)
            s.releaseSwiftPointer(\(title).self)
        }
        """.newLineTabbed
        
        let __new__ = """
        { type, args, kw -> PyPointer in
            print("\(title) New")
            return PySwiftObject_New(type)
        }
        """.newLineTabbed
        
        return """
        fileprivate func \(title)_Py_Call(self: PythonPointer, args: PythonPointer, keys: PythonPointer) -> PythonPointer {
            print("\(title) call self", self.printString)
            return .PyNone
        }
        
        fileprivate let \(title)_PyFunctions = PyTypeFunctions(
            tp_init: \(__init__),
            tp_new: \(__new__),
            tp_dealloc: \(__dealloc__),
            tp_getattr: nil, // will overwrite the other GetSets if not nil,
            tp_setattr: nil, // will overwrite the other GetSets if not nil,
            tp_as_number: nil,
            tp_as_sequence: nil,
            tp_call: \(title)_Py_Call,
            tp_str: \(__str__),
            tp_repr: \(__repr__)//,
            //tp_hash: \(__hash__)
        )
                
        """
    }
    
}