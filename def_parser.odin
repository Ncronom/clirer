#+private
package clirer
import "core:reflect"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:strings"

Tag :: struct {
    help:       string,
    required:   bool,
    short:      string,
    long:       string,
    value:      string,
}

parse_tag :: proc(tag_type: reflect.Struct_Tag) -> (tag: Tag) {
    help, _ := reflect.struct_tag_lookup(tag_type, "help")
    tag.help = help
    raw_tag, ok := reflect.struct_tag_lookup(tag_type, "cli")
    if !ok {
        return tag
    }
    params := strings.split(raw_tag, "/")
    defer delete(params)
    for param in params {
        tag.required = true if param == "required" else tag.required
        tag.value = param if param[0] == '<' && param[len(param) - 1] == '>' else tag.value
        index := strings.index(param, ",") 
        tag.short = param[:index] if index >= 0 else tag.short
        tag.long = param[index+1:] if index >= 0 else tag.long
    }
    return tag 
}

parse_cmd :: proc(
    iterator: ^ArgsIterator, 
    type_info: ^reflect.Type_Info,
    parent_path: string, 
    data: []byte
) -> Error{
    info_struct := type_info
    path := parent_path
    arg := current_arg(iterator)
    if reflect.is_union(type_info) && arg.type == ArgType.POSITIONAL {
        path = fmt.tprintf("%s %s", parent_path, arg.values[0])
        found := false
        info_union, _ := type_info.variant.(reflect.Type_Info_Union)
        named_union, ok := type_info.variant.(reflect.Type_Info_Named) 
        if ok {
            info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
        }
        for variant, i in info_union.variants {
            named_variant , _ := variant.variant.(reflect.Type_Info_Named) 
            if arg.values[0] == named_variant.name {
                info_struct = named_variant.base
                tag_index := 0 if info_union.no_nil else 1
                data[info_union.tag_offset] = u8(i + tag_index)
                found = true
                return parse_params(iterator, info_struct, path, data)
            }
        }
    }    
    return new_error_unknown(parent_path, type_info)
}
parse_params :: proc(
    iterator: ^ArgsIterator, 
    type_info: ^reflect.Type_Info,
    parent_path: string, 
    data: []byte
) -> Error {

    arg, end := next_arg(iterator)

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
    for !end {
        found := false
        for i in 0..<fields_count {
            if reflect.is_union(types[i]) && arg.type == ArgType.POSITIONAL {
                if required_tag := get_missing_required(tags[:i]); required_tag != nil {
                        return new_error_missing(parent_path, type_info)
                }
                err := parse_cmd(iterator, types[i], parent_path, data[offsets[i]:])
                if err == nil {
                    return nil
                }
            }else {
                found = parse_flag(&arg, &tags[i], types[i], data[offsets[i]:])
            }
            if found {break}
        }
        if !found {
            return new_error_unknown(parent_path, type_info)
        }
        arg, end = next_arg(iterator)
    }
    if required_tag := get_missing_required(tags); required_tag != nil {
        return new_error_missing(parent_path, type_info)
    }
    return nil
}

parse_flag :: proc(arg: ^Arg, tag: ^Tag, type: ^reflect.Type_Info, data: []byte) -> (found: bool) {
    if reflect.is_string(type) && arg.type == ArgType.POSITIONAL {
        found = true
        tag.required = false
        mem.copy(raw_data(data), &arg.values[0], type.size)  
    }
    else if (tag.short == arg.key || tag.long == arg.key) && arg.type == ArgType.FLAG {
        found = true
        tag.required = false
        type_info := type
        type_info_named, type_info_named_ok := type.variant.(reflect.Type_Info_Named)
        if type_info_named_ok {
            type_info = type_info_named.base
        }
        #partial switch t in type_info.variant {
            case reflect.Type_Info_String: {
                mem.copy(raw_data(data), &arg.values[0], type.size)  
            }
            case reflect.Type_Info_Enum: {
                for f, i in t.names {
                    if arg.values[0] == f {
                        mem.copy(raw_data(data), &t.values[i], type.size)  
                    }
                }
            }
            case reflect.Type_Info_Boolean: {
                data[0] = 1
            }
            case reflect.Type_Info_Array: {
                named_variant, _ := t.elem.variant.(reflect.Type_Info_Named)
                if reflect.is_enum(t.elem){ // N OPTIONS
                        enum_type, ok := named_variant.base.variant.(reflect.Type_Info_Enum)
                        for v, i in arg.values {
                            for e, j in enum_type.names {
                                if v == e {
                                    mem.copy(
                                        raw_data(data[i*size_of(reflect.Type_Info_Enum_Value):]), 
                                        &enum_type.values[j], 
                                        size_of(reflect.Type_Info_Enum_Value))  
                                }
                            }
                        }
                }
                else if reflect.is_string(t.elem){
                    if len(arg.values) <= t.count {
                        mem.copy(
                            raw_data(data), 
                            raw_data(arg.values),
                            len(arg.values)*size_of(string)
                        )  
                    }
                }
            }
        }
    }
    return found
}
get_missing_required :: proc(tags: []Tag) -> ^Tag {
    for &tag in tags {
         if tag.required {return &tag}
    }
    return nil
}
