package oldone

import "core:reflect"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:strings"

// - [ ]: full error handling
//  - [x]: Unknown (not exist)
//  - [ ]: bad usage
//  - [ ]: required

CLIParseError :: struct {
    path: string,
    type_info: ^reflect.Type_Info,
}

CLIError :: union {
    CLIParseError
}

parse :: proc($T: typeid, args: []string) -> T {
    info := type_info_of(T)
    data := make([]byte, info.size)
    iterator := args_iterator_make(args)
    defer args_iterator_destroy(iterator)
    next_arg(iterator)
    arg := current_arg(iterator)
    root_name := arg.key
    arg = next_arg(iterator)
    err := parse_cmd(iterator, info, root_name, data)
    if err != nil {
        parse_err, _ := err.(CLIParseError)
        log.error(parse_err)
        //print_help(parse_err.path, parse_err.type_info)
    }
    res := mem.reinterpret_copy(T, raw_data(data))
    return res
}

parse_cmd :: proc(
    iterator: ^ArgsIterator, 
    type_info: ^reflect.Type_Info,
    parent_path: string, 
    data: []byte
) -> CLIError{
    info_struct := type_info
    path := parent_path
    arg := current_arg(iterator)
    if reflect.is_union(type_info) {
        path = fmt.tprintf("%s %s", parent_path, arg.key)
        found := false
        info_union, _ := type_info.variant.(reflect.Type_Info_Union)
        named_union, ok := type_info.variant.(reflect.Type_Info_Named) 
        if ok {
            info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
        }
        for variant in info_union.variants {
            named_variant , _ := variant.variant.(reflect.Type_Info_Named) 
            if arg.key == named_variant.name {
                info_struct = named_variant.base
                found = true
            }
        }
        if !found {
           return CLIParseError{path=parent_path, type_info=type_info}
        }
    }    
    //named_struct, _ := info_struct.variant.(reflect.Type_Info_Named) 
    return parse_params(iterator, info_struct, path, data)
}



parse_params :: proc(
    iterator: ^ArgsIterator, 
    type_info: ^reflect.Type_Info,
    parent_path: string, 
    data: []byte
) -> CLIError {
    arg := next_arg(iterator)
    names :=    reflect.struct_field_names(type_info.id)
    raw_tags :=     reflect.struct_field_tags(type_info.id)
    types :=    reflect.struct_field_types(type_info.id)
    offsets :=  reflect.struct_field_offsets(type_info.id)
    fields_count := len(names)
    tags := make([]Tag, len(raw_tags))
    defer delete(tags)
    for raw_tag, i in raw_tags {
        tags[i] =  parse_tag(raw_tag)
    }
    for arg != nil {
        found := false
        for i in 0..<fields_count {
            if reflect.is_union(types[i]) {
                for tag in tags[:i] {
                    if tag.required {
                        return CLIParseError{path=parent_path, type_info=type_info}
                    }
                }
                return parse_cmd(iterator, types[i], parent_path, data)
            }
            else if reflect.is_string(types[i]) && arg.type == ArgType.POSITIONAL {

            }
            //log.error(tag.short, arg.key, "-", tag.long, arg.key)
            if tags[i].short == arg.key || tags[i].long == arg.key {
                found = true
                tags[i].required = false
                if reflect.is_string(types[i]) && len(arg.values) == 1 && arg.type == ArgType.FLAG{

                }else if reflect.is_enum(types[i]) && arg.type == ArgType.FLAG{

                }else if reflect.is_boolean(types[i]) && arg.type == ArgType.FLAG{

                }else if reflect.is_array(types[i]) && len(arg.values) > 1 && arg.type == ArgType.FLAG{

                }
                break
            }
        }

        if !found {
            return CLIParseError{path=parent_path, type_info=type_info}
        }

        arg = next_arg(iterator)
    }
    for tag in tags {
        if tag.required {
            return CLIParseError{path=parent_path, type_info=type_info}
        }
    }
    return nil
}
