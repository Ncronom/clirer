package cleo

import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strings"
import "core:slice"
import "core:mem"

@(private)
InvalidFieldError       :: struct {} // Invalid field definition
@(private)
MissingFieldError       :: struct {} // required field missing
@(private)
MissingTagFieldError    :: struct {} // required tag field missing
@(private)
UnknownFieldError       :: struct {} // field doesn't exist
@(private)
BadValueFieldError      :: struct {} // field value exceed array capacity
@(private)
OutOfBoundFieldError    :: struct {} // field value exceed array capacity

@(private)
ParseError :: union {
    InvalidFieldError,      // DONE
    MissingFieldError,      // DONE
    MissingTagFieldError,   // DONE
    UnknownFieldError,      // DONE
    BadValueFieldError,     // DONE
    OutOfBoundFieldError,   // DONE
}

// TODO: implement -help

@(private)
Metadata :: struct {
    names: []string,
    types: []^reflect.Type_Info, 
    tags:  []reflect.Struct_Tag, 
}

@(private)
FieldKind :: enum {
    COMMAND,

    FLAG,

    OPTIONS,
    OPTIONS_ANY,

    OPTIONS_MANY,
    OPTIONS_MANY_ANY,

    POSITIONAL,

    UNKNOWN,
}



@(private)
FieldTag :: struct {
    short:      string,
    long:       string,
    desc:       string,
    required:   bool,
    options:    []string,
}

@(private)
Field :: struct {
    kind: FieldKind,
    name: string,
    type: ^reflect.Type_Info,
    pos:  int,
    count: int,
    tag:  FieldTag,
    fields: []Field,
}

@(private)
Arg :: struct{
    key:    string,
    value:  string,
    pos:    int
}

@(private)
append_help_flag :: proc(builder: ^strings.Builder, field: Field) {
}

@(private)
append_help_cmds :: proc(builder: ^strings.Builder, fields: []Field) {
}

@(private)
append_help_header :: proc(builder: ^strings.Builder) {
}

@(private)
append_help_footer :: proc(builder: ^strings.Builder) {
}



@(private)
print_help :: proc(fields: []Field) {
    flags_builder := strings.builder_make_len(0)
    defer strings.builder_destroy(&flags_builder)

    // Program description

    // (USAGE) 
    // maincmd [command] [arguments] 
    // COMMANDS (Command)
    // footer

    // maincmd command [arguments]
    // (USAGE) 
    // (RUN)
    fmt.sbprintf(&flags_builder,"\t%s\n\n", "Run") 
    for field in fields {
        #partial switch field.kind {
        case FieldKind.POSITIONAL:{}
        }
    }
    // FLAGS (Flags)
    fmt.sbprintf(&flags_builder,"\t%s\n\n", "Flags") 
    for field in fields {
        #partial switch field.kind {
        case FieldKind.FLAG:{
                fmt.sbprintf(&flags_builder,"\t-%s\n", field.tag.long) 
                if field.tag.desc != "" {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.desc) 
                }
        }
        case FieldKind.OPTIONS, FieldKind.OPTIONS_MANY:{
                fmt.sbprintf(&flags_builder,"\t-%s:<option>\n", field.tag.long) 
                if field.tag.desc != "" {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.desc) 
                }
                fmt.sbprintf(&flags_builder,"\t\tAvailable options:\n") 
                for opt in field.tag.options {
                    fmt.sbprintf(&flags_builder,"\t\t-%s: %s\n", field.tag.long, opt) 
                }

        }
        case FieldKind.OPTIONS_ANY, FieldKind.OPTIONS_MANY_ANY:{
                fmt.sbprintf(&flags_builder,"\t-%s:<string>\n", field.tag.long) 
                if field.tag.desc != "" {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.desc) 
                }
        }

    }
    }
    append_help_footer(&flags_builder)
    fmt.printf(fmt.sbprint(&flags_builder))
}


@(private)
get_metadata :: proc($T: typeid) -> Metadata {
    id := typeid_of(T)
    return Metadata{
        names   = reflect.struct_field_names(id),
	    types   = reflect.struct_field_types(id),
	    tags    = reflect.struct_field_tags(id),
    }
}

@(private)
parse_tag :: proc(tag: reflect.Struct_Tag) -> (field_tag: FieldTag, err: ParseError) {
    val, ok := reflect.struct_tag_lookup(tag, "cli");
    if !ok {
        return field_tag, MissingTagFieldError{}
	}
    params := strings.split(val, " ")
    defer delete(params)
    for param in params {
        if param == "required" {
            field_tag.required = true
        }else if strings.contains(param, "/"){
            short_long := strings.split(param, "/")
            defer delete(short_long)
            if len(short_long) == 2 {
                field_tag.short = short_long[0]
                field_tag.long = short_long[1]
            }        
        }else if strings.contains(param, ","){
            field_tag.options = strings.split(param, ",")
        }
    }
    val, ok = reflect.struct_tag_lookup(tag, "desc");
    if ok {
        field_tag.desc = val    
    }
    return field_tag, err
}

@(private)
parse_field :: proc(name: string, type: ^reflect.Type_Info, tag: reflect.Struct_Tag) -> (field: Field, err: ParseError) {
    field_tag, parse_tag_err := parse_tag(tag)
    err = parse_tag_err
    field.tag = field_tag
    field.name = name
    field.type = type
    field.kind = FieldKind.UNKNOWN
    if _, ok := type.variant.(reflect.Type_Info_String); ok {
        if _, okk := parse_tag_err.(MissingTagFieldError); okk{
                field.kind = FieldKind.POSITIONAL 
                return field, nil
        }
    }
    if parse_tag_err != nil {
        return field, parse_tag_err
    }
    // Check type 
    #partial switch _ in type.variant {
    case reflect.Type_Info_Boolean: {   
        if field.tag.short != "" && field.tag.long != "" {
            field.kind = FieldKind.FLAG       
        }
    }
    case reflect.Type_Info_String: {
        if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) > 0 {
            field.kind = FieldKind.OPTIONS 
        }else if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) == 0 {
            field.kind = FieldKind.OPTIONS_ANY 
        }else if field.tag.short == "" && field.tag.long == ""{
            field.kind = FieldKind.POSITIONAL 
        }else {
            return field, InvalidFieldError{}
        }
    }
    case reflect.Type_Info_Array:   {
        field.count = type.variant.(reflect.Type_Info_Array).count
        if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) > 0 {
            field.kind = FieldKind.OPTIONS_MANY
        }else if field.tag.short != "" && field.tag.long != "" && len(field.tag.options) == 0 {
            field.kind = FieldKind.OPTIONS_MANY_ANY 
        }else {
            return field, InvalidFieldError{}
        }
   
    }
    case:{
        return field, InvalidFieldError{}
    }
    }
    return field, err
}

//free_fields :: proc(fields: []Field) {
//    for field in fields {
//        delete(field.tag.options)
//    }
//}

@(private)
parse_arg_odin :: proc(arg_raw: string, pos: int) -> (arg: Arg) {
    arg.pos = pos
    arg.value = arg_raw
    key_value := strings.split(arg_raw, ":")
    defer delete(key_value)
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

@(private)
parse_metadata :: proc(metadata: Metadata) -> (fields: [dynamic]Field, err: ParseError) {
    fields = make([dynamic]Field, 0, 16)
    j := 0
    k := 0
    for tag, i in metadata.tags {
		name, type := metadata.names[i], metadata.types[i]
        value := parse_field(name, type, tag) or_return
        if value.kind == FieldKind.POSITIONAL {
            value.pos = j
            j += 1
        }else {
            value.pos = k
            k += 1
        }
    
        append(&fields, value)
	}
    return fields, err
}


@(private)
parse_argv :: proc(argv: []string) -> [dynamic]Arg {
    args := make([dynamic]Arg, 0, 16)
    j := 0
    k := 0
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
    return args
}

@(private)
create_fields :: proc($T: typeid, fields: []Field, args: []Arg) -> (res: T, err: ParseError) {
    //res_b := mem.ptr_to_bytes(res, reflect.length(res))
    last_pos := 0
    exist := false
    for field, i in fields {
        found := false
        for arg in args {
            #partial switch field.kind {
            case FieldKind.FLAG:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    found = true
                    exist = true
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(&res)
                    flag := (^bool)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = true
                }
            }
            case FieldKind.OPTIONS:{
                if ((arg.key == field.tag.short || arg.key == field.tag.long)){
                    if slice.contains(field.tag.options, arg.value) {
                        found = true
                        exist = true
                        sf := reflect.struct_field_by_name(T, field.name)
                        res_c := (^byte)(&res)
                        flag := (^string)(mem.ptr_offset(res_c, sf.offset))
                        flag^ = arg.value
                    }else {
                        return res, BadValueFieldError{}
                    }
                }
            }
            case FieldKind.OPTIONS_ANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    found = true
                    exist = true
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(&res)
                    flag := (^string)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = arg.value
                }
            }

            case FieldKind.OPTIONS_MANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    found = true
                    exist = true
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(&res)
                    value_split := strings.split(arg.value, ",")
                    defer delete(value_split)
                    if len(value_split) <= field.count {
                        valid := true
                        for vs in value_split {
                            if !slice.contains(field.tag.options, vs) {
                                valid = false 
                            }
                        }
                        if valid {
                            flag := mem.ptr_offset(res_c, sf.offset)                     
                            mem.copy(flag, raw_data(value_split), size_of(value_split)*len(value_split)) 
                        }else {
                            return res, BadValueFieldError{}
                        }
                    }else {
                        return res, OutOfBoundFieldError{}
                    }
                }
            }
            case FieldKind.OPTIONS_MANY_ANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    exist = true
                    found = true
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(&res)
                    value_split := strings.split(arg.value, ",")
                    defer delete(value_split)
                    if len(value_split) <= field.count {
                        flag := mem.ptr_offset(res_c, sf.offset)                     
                        mem.copy(flag, raw_data(value_split), size_of(value_split)*len(value_split)) 
                    }else {
                        return res, OutOfBoundFieldError{}
                    }
                }
            }
            case FieldKind.POSITIONAL:{
                if field.pos == arg.pos {
                    exist = true
                    found = true
                    sf := reflect.struct_field_by_name(T, field.name)
                    res_c := (^byte)(&res)
                    flag := (^string)(mem.ptr_offset(res_c, sf.offset))
                    flag^ = arg.value
                }
            }
            case FieldKind.COMMAND:{

            }
            }
        }
        if field.tag.required && !found {
            err = MissingFieldError{}
        }
        found = false
    }
    if !exist {
            err = UnknownFieldError{}
    }

    return res, err
}

parse :: proc(argv: []string, $T: typeid) -> (res: T, err: ParseError) {
    fields := parse_metadata(get_metadata(T)) or_return
    defer delete(fields)
    args := parse_argv(argv)
    defer delete(args)
    res, err = create_fields(T, fields[:], args[:])
    print_help(fields[:])
    return res, err 
}

//free_parse :: proc($T: typeid, value: ^T) {
//    if value != nil {
//        free(value)
//    }
//}
