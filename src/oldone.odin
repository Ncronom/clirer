package oldone

import "core:fmt"
import "core:mem"
import "core:reflect"



parse :: proc(args: []string, $T: typeid) -> (res: T, err: CLIError) {
    info := type_info_of(typeid_of(T))
    data := make([]byte, info.size)
    defer delete(data)
    fmt.println(parse_help("", info.id))
    if reflect.is_struct(info) {
        parse_struct(data, args, info) or_return
    }
    else if reflect.is_union(info) {
        parse_union(data, args, T) or_return
    }
    res = mem.reinterpret_copy(T, raw_data(data))
    return res, nil
}


