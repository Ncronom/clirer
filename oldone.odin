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
    raw_tag, ok := reflect.struct_tag_lookup(tag_type, "cli")
    if ok {
        params := strings.split(raw_tag, ",")
        defer delete(params)
        i := 0
        for i<len(params) {
            param := params[i]
            if param == "required" {
                tag.required = true
            }
            else if param[0] == '[' && param[len(param) - 1] == ']'{
                tag.options = strings.split(param[1:len(param) - 1], "|")
            }
            else if  param[0] == '\''{
                if param[len(param) - 1] != '\'' {
                    offset := 0
                    for i<len(params) && param[len(param) - 1] != '\'' {
                        offset += 1
                        i += 1
                        param = params[i]
                    }
                    tag.help = strings.join(params[i - offset: i+1], ",")
                    tag.help = tag.help[1:len(tag.help)-1]
                }else {
                    tag.help = param[1: len(param) - 1]
                }
            }
            else if  param[0] == '<' && param[len(param) - 1] == '>'{
                tag.value = param[1:len(param)-1]
            }
            else if strings.contains(param, "|"){
                short_long := strings.split(param, "|")
                defer delete(short_long)
                if len(short_long) == 2 {
                    tag.short = short_long[0]
                    tag.long = short_long[1]
                }        
            }    
            i+=1
        }
    }
    return tag, exist 
}

arg_name :: proc(raw_arg: string) -> string {
    index := strings.index(raw_arg, ":")
    name := raw_arg[1:]
    if index >= 0 {
        name = name[:index - 1]
    }
    return name 
}

arg_value :: proc(raw_arg: string) -> string {
    index := strings.index(raw_arg, ":")
    value := "" 
    if index >= 0 {
        value = raw_arg[index+1:]
    }
    return value 
}

parse_struct :: proc(data: []byte, args: []string, info: ^reflect.Type_Info) -> (err: CLIError){
    names :=    reflect.struct_field_names(info.id)
    tags :=     reflect.struct_field_tags(info.id)
    types :=    reflect.struct_field_types(info.id)
    offsets :=  reflect.struct_field_offsets(info.id)
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

parse_union :: proc(data: []byte, args: []string, id: typeid) -> (err: CLIError)  {
        info := type_info_of(id)
        named_info, named_ok := info.variant.(reflect.Type_Info_Named)
        if named_ok {
            union_info, union_ok := named_info.base.variant.(reflect.Type_Info_Union)
            if union_ok {
                for variant, i in union_info.variants {
                    named_info, named_ok := variant.variant.(reflect.Type_Info_Named)
                    if named_ok && args[0] == named_info.name {
                        tag_index := 0 if union_info.no_nil else 1
                        data[union_info.tag_offset] = u8(i + tag_index)
                        parse_struct(data, args[1:], named_info.base)
                        return nil
                    }
                }
            }

        }
        return CLIParseError{msg = fmt.tprintf("Unknown command \"%s\"\n", args[0])}
}




parse :: proc(args: []string, $T: typeid) -> (res: T, err: CLIError) {
    info := type_info_of(typeid_of(T))
    data := make([]byte, info.size)
    defer delete(data)
    if reflect.is_struct(info) {
        parse_struct(data, args, info) or_return
    }
    else if reflect.is_union(info) {
        parse_union(data, args, T) or_return
    }
    res = mem.reinterpret_copy(T, raw_data(data))
    return res, nil
}


scmd :: struct {
    aaa: bool   `cli:"a|aaa"`,
    bbb: string `cli:"b|bbb"`,
    ccc: [3]string `cli:"c|ccc"`,
    ddd: string,
    eee: enum {
        arg1,
        arg2
    }`cli:"e|eee"`,
    fff: [3]enum {
        fff1,
        fff2,
        fff3
    }`cli:"f|fff"`
}

ucmd :: union {
    scmd
}

@(test)
general_test :: proc(t: ^testing.T) {
    //parse(os.args[1:], ucmd)
    argv := []string{"scmd", "-aaa", "-bbb:hello", "-ccc:je,suis", "-eee:arg4",
        "-fff:fff2,fff3,fff2", "position1"}
    res, err := parse(argv, ucmd)
    
    log.debug(res)
    log.debug(err)

}
