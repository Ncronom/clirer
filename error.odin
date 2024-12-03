package clirer

import "core:reflect"
import "core:fmt"

ErrorUnknownFlag :: struct {
    msg: string,
    path: string,
    type_info: ^reflect.Type_Info,
}

new_error_unknown_flag :: proc(
    path: string, 
    type_info: ^reflect.Type_Info,
) -> ErrorUnknownFlag{
    return ErrorUnknownFlag{
        msg = fmt.tprintf("Unknown parameter %v\n", type_info),
        path = path,
        type_info = type_info,
    }
}

ErrorUnknownCmd :: struct {
    msg: string,
    path: string,
    type_info: ^reflect.Type_Info,
}

new_error_unknown_cmd :: proc(
    path: string, 
    type_info: ^reflect.Type_Info,
) -> ErrorUnknownCmd{
    return ErrorUnknownCmd{
        msg = fmt.tprintf("Unknown parameter %v\n", type_info),
        path = path,
        type_info = type_info,
    }
}

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
    ErrorUnknownCmd,
    ErrorUnknownFlag,
    ErrorMissing,
    ErrorValue,
}

handle_error :: proc(err: Error){
    switch e in err {
    case ErrorUnknownCmd:   { print_help(e) }
    case ErrorUnknownFlag:  { print_help(e) }
    case ErrorMissing:      { print_help(e) }
    case ErrorValue:        { print_help(e) }
    }
}
