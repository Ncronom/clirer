package oldone

import "core:log"
import "core:reflect"
import "core:testing"
import "core:mem"
import "core:os"
import "core:strings"
import "core:fmt"

CLIParseError :: struct {
    msg: string,
}

CLIError :: union {
    CLIParseError
}

Tag :: struct {
    help:       string,
    required:   bool,
    short:      string,
    long:       string,
    value:      string,
    options:    []string,
}

parse_tag :: proc(tag_type: reflect.Struct_Tag) -> (tag: Tag, exist: bool) {
    help, _ := reflect.struct_tag_lookup(tag_type, "help")
    tag.help = help
    raw_tag, ok := reflect.struct_tag_lookup(tag_type, "cli")
    if !ok {
        return tag, false
    }
    params := strings.split(raw_tag, "/")
    defer delete(params)
    for param in params {
        tag.required = param == "required"
        tag.value = param[1:len(param)-1] if param[0] == '<' &&
        param[len(param) - 1] == '>' else tag.value
        index := strings.index(param, ",") 
        tag.short = param[:index] if index >= 0 else tag.short
        tag.long = param[index+1:] if index >= 0 else tag.long
    }
    return tag, exist 
}

arg_name :: proc(raw_arg: string) -> string {
    rip := raw_arg[1:]
    index := strings.index(rip, ":")
    return rip[:index] if index >= 0 else rip
}

arg_value :: proc(raw_arg: string) -> string {
    rip := raw_arg[1:]
    index := strings.index(rip, ":")
    return rip[index+1:] if index >= 0 else "" 
}


parse_struct :: proc(data: []byte, args: []string, info: ^reflect.Type_Info) -> (err: CLIError){
    names :=    reflect.struct_field_names(info.id)
    tags :=     reflect.struct_field_tags(info.id)
    types :=    reflect.struct_field_types(info.id)
    offsets :=  reflect.struct_field_offsets(info.id)
    help := ""
    for name, j in names {
        tag, exist := parse_tag(tags[j])
        offseted_data := data[offsets[j]:]
        for &arg, i in args {
            name_arg := arg_name(arg)
            value_arg := arg_value(arg)
            if name_arg == tag.short || name_arg == tag.long {
                #partial switch t in types[j].variant {
                case reflect.Type_Info_Boolean: {   // FLAG
                    offseted_data[0] = 1
                }
                case reflect.Type_Info_Enum:    {   // OPTION
                    for f, k in t.names {
                        if value_arg == f {
                            mem.copy(raw_data(offseted_data), &t.values[k], types[j].size)  
                        }
                    }
                } 
                case reflect.Type_Info_String:  {   // VALUE
                    mem.copy(raw_data(offseted_data), &value_arg, types[j].size)  
                } 
                case reflect.Type_Info_Array:   {
                   splited_value := strings.split(value_arg, ",")
                    defer delete(splited_value)
                   if enum_type, ok := t.elem.variant.(reflect.Type_Info_Enum); ok { // N OPTIONS
                        for sv, k in splited_value {
                            for f, l in enum_type.names {
                                if sv == f {
                                    mem.copy(raw_data(offseted_data[k*size_of(reflect.Type_Info_Enum_Value):]), &enum_type.values[l], size_of(reflect.Type_Info_Enum_Value))  
                                }
                            }
                        }
                   }else { // N VALUES
                        if len(splited_value) <= t.count {
                            mem.copy(raw_data(offseted_data), raw_data(splited_value), len(splited_value)*size_of(string))  
                        }
                   }
                }
                case: {}
                }
            }else if _, ok := types[j].variant.(reflect.Type_Info_String); ok { // POSITIONAL 
                if len(tag.short) == 0 && len(tag.long) == 0{
                    mem.copy(raw_data(offseted_data), &arg, size_of(string))  
                }
            }else if _, ok := types[j].variant.(reflect.Type_Info_Union); ok { // SUB CMDs
                    parse_union(offseted_data, args[i:], types[j].id) or_return
            }
        }
    }
    return err
}    

parse_union :: proc(data: []byte, args: []string, id: typeid) -> CLIError  {
        info := type_info_of(id)
        named_info, named_ok := info.variant.(reflect.Type_Info_Named)
        if !named_ok {
            return CLIParseError{msg = fmt.tprintf("Internal Error \"%s\"\n", args[0])}
        }
        union_info, union_ok := named_info.base.variant.(reflect.Type_Info_Union)
        if !union_ok {
            return CLIParseError{msg = fmt.tprintf("Internal Error \"%s\"\n", args[0])}
        }

        for variant, i in union_info.variants {
            named_info, named_ok := variant.variant.(reflect.Type_Info_Named)
            if !named_ok {
                return CLIParseError{msg = fmt.tprintf("Internal Error \"%s\"\n", args[0])}
            }
            if args[0] == named_info.name {
                tag_index := 0 if union_info.no_nil else 1
                data[union_info.tag_offset] = u8(i + tag_index)
                parse_struct(data, args[1:], named_info.base)
                return nil
            }
        }
        return CLIParseError{msg = fmt.tprintf("Unknow command \"%s\"\n", args[0])}
}
