package clirer

import "core:reflect"
import "core:fmt"

ErrorMissing :: struct {
    msg: string,
    path: string,
    type_info: ^reflect.Type_Info,
}

new_error_missing :: proc(
    path: string, 
    type_info: ^reflect.Type_Info,
) -> ErrorMissing{
    return ErrorMissing{
        msg = fmt.tprintf("Missing required parameter %v\n", type_info),
        path = path,
        type_info = type_info,
    }
}

ErrorUnknown :: struct {
    msg: string,
    path: string,
    type_info: ^reflect.Type_Info,
}

new_error_unknown :: proc(
    path: string, 
    type_info: ^reflect.Type_Info,
) -> ErrorUnknown{
    return ErrorUnknown{
        msg = fmt.tprintf("Unknown parameter %v\n", type_info),
        path = path,
        type_info = type_info,
    }
}

ErrorValue :: struct {
    msg: string,
    path: string,
    type_info: ^reflect.Type_Info,
}

new_error_value :: proc(
    path: string, 
    type_info: ^reflect.Type_Info,
) -> ErrorValue{
    return ErrorValue{
        msg = fmt.tprintf("Bad value for parameter %v\n", type_info),
        path = path,
        type_info = type_info,
    }
}

Error :: union {
    ErrorUnknown,
    ErrorMissing,
    ErrorValue,
}

handle_error :: proc(err: Error){
    switch e in err {
    case ErrorUnknown:  { print_help(e.path, e.type_info) }
    case ErrorMissing:  { print_help(e.path, e.type_info) }
    case ErrorValue:    { print_help(e.path, e.type_info) }
    }
}
