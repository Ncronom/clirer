package cleo

import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:mem"

MissingFieldError :: struct {}
UnknownFieldError :: struct {}

ParseError :: union {
    MissingFieldError,
    UnknownFieldError,
}

Metadata :: struct {
    names: []string,
    types: []^reflect.Type_Info, 
    tags:  []reflect.Struct_Tag, 
}

FieldKind :: enum {
    FLAG,

    OPTIONS,
    OPTIONS_ANY,

    OPTIONS_MANY,
    OPTIONS_MANY_ANY,

    OPTIONS_MANY_FIX,
    OPTIONS_MANY_FIX_ANY,

    POSITIONAL,
    UNKNOWN,
}



FieldTag :: struct {
    short:      string,
    long:       string,
    required:   bool,
    options:    []string,
}

Field :: struct {
    kind: FieldKind,
    name: string,
    type: ^reflect.Type_Info,
    pos:  int,
    size: int,
    tag:  FieldTag,
}

Arg :: struct{
    key:    string,
    value:  string,
    pos:    int
}


@private
get_metadata :: proc($T: typeid) -> Metadata {
    id := typeid_of(T)
    return Metadata{
        names   = reflect.struct_field_names(id),
	    types   = reflect.struct_field_types(id),
	    tags    = reflect.struct_field_tags(id),
    }
}



parse_tag :: proc(tag: reflect.Struct_Tag) -> FieldTag {
    field_tag := FieldTag{}
    val, ok := reflect.struct_tag_lookup(tag, "cli");
    if !ok {
        return field_tag
	}
    params := strings.split(val, " ")
    defer delete(params)
    for param in params {
        if param == "required" {
            field_tag.required = true
        }else if strings.contains(param, "/"){
            short_long := strings.split(val, "/")
            defer delete(short_long)
            if len(short_long) == 2 {
                field_tag.short = short_long[0]
                field_tag.long = short_long[1]
            }        
        }else if strings.contains(param, ","){
            field_tag.options = strings.split(param, ",")
        }
    }
    return field_tag
}

parse_field :: proc(name: string, type: ^reflect.Type_Info, tag: reflect.Struct_Tag) -> Field {
    field := Field {}
    field.tag = parse_tag(tag)
    field.name = name
    field.type = type
    field.kind = FieldKind.UNKNOWN
    // Check type 
    #partial switch _ in type.variant {
    case reflect.Type_Info_Boolean: {   
        field.kind = FieldKind.FLAG       
    }
    case reflect.Type_Info_String: {
        if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) > 0 {
            field.kind = FieldKind.OPTIONS 
        }else if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) == 0 {
            field.kind = FieldKind.OPTIONS_ANY 
        }else if field.tag.short == "" && field.tag.long == ""{
            field.kind = FieldKind.POSITIONAL 
        }
    }
    case reflect.Type_Info_Slice:   {
        if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) > 0 {
            field.kind = FieldKind.OPTIONS_MANY
        }else if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) == 0 {
            field.kind = FieldKind.OPTIONS_MANY_ANY 
        }    
    }
    case reflect.Type_Info_Array:   {
    //OPTIONS_MANY_FIX,
    //OPTIONS_MANY_FIX_ANY,
        if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) > 0 {
            field.kind = FieldKind.OPTIONS_MANY_FIX
        }else if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) == 0 {
            field.kind = FieldKind.OPTIONS_MANY_FIX_ANY 
        }    
        field.size = (transmute(^reflect.Type_Info_Array)(&type.variant)).count
    }
    }
    return field
}

parse_arg_odin :: proc(arg_raw: string, pos: int) -> (arg: Arg) {
    arg.pos = pos
    arg.value = arg_raw
    key_value := strings.split(arg_raw, ":")
    if arg_raw[0] == '-' {
        substr, ok := strings.substring_from(key_value[0], 1)
        arg.key = substr
        if len(key_value) == 2 {
            arg.value = key_value[1]
        }else if len(key_value) == 1 {
            arg.value = ""
        }
    }
    return arg
}

create_fields :: proc($T: typeid, fields: []Field, args: []Arg) -> (^T, ParseError) {
    res := new(T)
    //res_b := mem.ptr_to_bytes(res, reflect.length(res))
    last_pos := 0
    for arg in args {
        for field, i in fields {
            switch field.kind {
            case FieldKind.FLAG:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(res)
                    flag := (^bool)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = true
                }
            }
            case FieldKind.OPTIONS:{
                if ((arg.key == field.tag.short || arg.key == field.tag.long) &&
            slice.contains(field.tag.options, arg.value)){
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(res)
                    flag := (^string)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = arg.value
                }
            }
            case FieldKind.OPTIONS_ANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(res)
                    flag := (^string)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = arg.value
                }
            }

            case FieldKind.OPTIONS_MANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(res)
                    value_split := strings.split(arg.value, ",")
                    valid := true
                    for vs in value_split {
                        if !slice.contains(field.tag.options, vs) {
                            valid = false 
                        }
                    }
                    if valid {
                        //log.debug("VALID")
                        flag := mem.ptr_offset(res_c, sf.offset)
                        flag = raw_data(value_split)                     
                    }
                }
            }
            case FieldKind.OPTIONS_MANY_ANY:{}

            case FieldKind.OPTIONS_MANY_FIX:{}
            case FieldKind.OPTIONS_MANY_FIX_ANY:{}



            case FieldKind.POSITIONAL:{}
            case FieldKind.UNKNOWN:{}
            }
        }
    }
    return res, nil
}



parse :: proc(argv: []string, $T: typeid) -> (res: ^T, err: ParseError) {
    metadata := get_metadata(T)
    fields := make([dynamic]Field, 0, 16)
    args := make([dynamic]Arg, 0, 16)
    j := 0
    k := 0
    for tag, i in metadata.tags {
		name, type := metadata.names[i], metadata.types[i]
        value := parse_field(name, type, tag)
        if value.kind == FieldKind.POSITIONAL {
            value.pos = j
            j += 1
        }else {
            value.pos = k
            k += 1
        }
    
        append(&fields, value)
	}
    j = 0
    k = 0
    for arg, i in argv {
        value := parse_arg_odin(arg, i)
        if value.key == "" {
            value.pos = j
            j += 1
        }else {
            value.pos = k
            k += 1
        }
        append(&args, value)
	}
    res, err = create_fields(T, fields[:], args[:])
  
    return res, err 
}

//parse_arg_odin :: proc(arg: string, fields: []Field) -> (Field, ParseError) {
//    field := Field{}
//    key_value := strings.split(arg, ":")
//    if arg[0] == '-' {
//        substr, ok := strings.substring_from(key_value[0], 1)
//        if ok {
//            field.name = substr
//        }
//        if len(key_value) == 2 {
//            field.kind = FieldKind.OPTIONS
//            field.tag.options =  key_value[1:]
//        }else if len(key_value) == 1 {
//            field.field_type = FieldKind.FLAG
//        }
//    }else {
//        field.field_type = FieldType.POSITIONAL
//        field.options = []string{key_value[0]}
//    }
//    return field, nil
//}
//parse :: proc(args: []string, $T: typeid) -> ([]^Field, ParseError) {
//    metadata := get_metadata(T)
//    fields := make([dynamic]^Field, 0, 16)
//    defer free_fields(fields[:])
//    argv := make([dynamic]^Field, 0, 16)
//    j := 0
//    k := 0
//    for tag, i in metadata.tags {
//		name, type := metadata.names[i], metadata.types[i]
//        value := parse_fields(name, type, tag)
//        if value.field_type == FieldType.POSITIONAL {
//            value.pos = j
//            j += 1
//        }else {
//            value.pos = k
//            k += 1
//        }
//    
//        append(&fields, value)
//	}
//    fmt.println(fields)
//    j = 0
//    k = 0
//    for arg, i in args[1:] {
//        value := parse_arg(arg)
//        if value.field_type == FieldType.POSITIONAL {
//            value.pos = j
//            j += 1
//        }else {
//            value.pos = k
//            k += 1
//        }
//        if ok, err := check_unknown_field(value, fields[:]); !ok {
//            free_fields(argv[:])
//            return nil, err
//        } 
//        append(&argv, value)
//	}
//    if ok, err := check_missing_field(argv[:], fields[:]); !ok {
//        free_fields(argv[:])
//        return nil, err
//    } 
//    return argv[:], nil 
//}

