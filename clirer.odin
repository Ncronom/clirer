package clirer

import "core:reflect"
import "core:mem"

parse :: proc(
    $T: typeid, 
    args: []string, 
    config: Config = DEFAULT_CONFIG
) -> (res: T, err: Error){
    current_config = config
    info := type_info_of(T)
    data := make([]byte, info.size)
    defer delete(data)
    iterator := args_iterator_make(args)
    defer args_iterator_destroy(&iterator)
    arg, end := next_arg(&iterator)
    if end {
        return res, err
    }
    root_name := arg.values[0]
    if reflect.is_union(type_info_of(T)) {
        next_arg(&iterator)
        err = parse_cmd(&iterator, info, root_name, data)
    }else {
        err = parse_params(&iterator, info, root_name, data)
    }
    if current_config.help && err != nil {
        handle_error(err)
    }
    res = mem.reinterpret_copy(T, raw_data(data))
    return res, err
}
