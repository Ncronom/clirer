package oldone

import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"



parse :: proc(args: []string, $T: typeid) -> (res: T, err: CLIError) {
    info := type_info_of(typeid_of(T))
    data := make([]byte, info.size)
    defer delete(data)
    named_info, _ := info.variant.(reflect.Type_Info_Named)
    if reflect.is_struct(info) {
        err = parse_struct(data, args, info, named_info.name)
    }
    else if reflect.is_union(info) {
        err = parse_union(data, args, T, named_info.name)
    }
    if err != nil {
        parse_err :=  err.(CLIParseError)
        print_help(parse_err.path, parse_err.type_info)
    }
    res = mem.reinterpret_copy(T, raw_data(data))
    return res, nil
}


