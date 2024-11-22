package cleo
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strings"
import "core:slice"
import "core:mem"
import "core:bytes"

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
    short:          string,
    long:           string,
    help:           string,
    value_label:    string,
    required:       bool,
    options:        []string,
}

@(private)
Field :: struct {
    id: typeid,
    kind:   FieldKind,
    name:   string,
    type:   ^reflect.Type_Info,
    pos:    int,
    count:  int,
    size:   int,
    offset:   int,
    tag:    FieldTag,
    fields: [dynamic]Field,
}

@(private)
Arg :: struct{
    key:    string,
    value:  string,
    pos:    int
}

@(private)
print_help :: proc(cmd: Field) {
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
    for field in cmd.fields {
        #partial switch field.kind {
        case FieldKind.POSITIONAL:{}
        }
    }
    // FLAGS (Flags)
    fmt.sbprintf(&flags_builder,"\t%s\n\n", "Flags") 
    for field in cmd.fields {
        #partial switch field.kind {
        case FieldKind.FLAG:{
                fmt.sbprintf(&flags_builder,"\t-%s\n", field.tag.long) 
                if len(field.tag.help) > 0 {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.help) 
                }
        }
        case FieldKind.OPTIONS, FieldKind.OPTIONS_MANY:{
                value_label := field.name
                if len(field.tag.value_label) > 0 {
                    value_label = field.tag.value_label
                }
                fmt.sbprintf(&flags_builder,"\t-%s: <%s>\n", field.tag.long, value_label) 
                if len(field.tag.help) > 0 {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.help) 
                }
                fmt.sbprintf(&flags_builder,"\t\tAvailable options:\n") 
                for opt in field.tag.options {
                    fmt.sbprintf(&flags_builder,"\t\t-%s: %s\n", field.tag.long, opt) 
                }
        }
        case FieldKind.OPTIONS_ANY, FieldKind.OPTIONS_MANY_ANY:{
                value_label := field.name
                if len(field.tag.value_label) > 0 {
                    value_label = field.tag.value_label
                }
                fmt.sbprintf(&flags_builder,"\t-%s:<%s>\n", field.tag.long, value_label) 
                if len(field.tag.help) > 0 {
                    fmt.sbprintf(&flags_builder,"\t\t%s\n", field.tag.help) 
                }
        }

    }
    }
    fmt.printf(fmt.sbprint(&flags_builder))
}


@(private)
get_metadata :: proc(id: typeid) -> Metadata {
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
    params := strings.split(val, ",")
    defer delete(params)
    i := 0
    for i<len(params) {
        param := params[i]
        if param == "required" {
            field_tag.required = true
        }
        else if param[0] == '[' && param[len(param) - 1] == ']'{
            field_tag.options = strings.split(param[1:len(param) - 1], "|")
        }
        else if  param[0] == '\''{
            if param[len(param) - 1] != '\'' {
                offset := 0
                for i<len(params) && param[len(param) - 1] != '\'' {
                    offset += 1
                    i += 1
                    param = params[i]
                }
                field_tag.help = strings.join(params[i - offset: i+1], ",")
                field_tag.help = field_tag.help[1:len(field_tag.help)-1]
            }else {
                field_tag.help = param[1: len(param) - 1]
            }
        }
        else if  param[0] == '<' && param[len(param) - 1] == '>'{
            field_tag.value_label = param[1:len(param)-1]
        }
        else if strings.contains(param, "|"){
            short_long := strings.split(param, "|")
            defer delete(short_long)
            if len(short_long) == 2 {
                field_tag.short = short_long[0]
                field_tag.long = short_long[1]
            }        
        }    
        i+=1
    }
    return field_tag, err
}

@(private)
parse_field :: proc(name: string, type: ^reflect.Type_Info, tag: reflect.Struct_Tag) -> (field: Field, err: ParseError) {
    field_tag, parse_tag_err := parse_tag(tag)
    err = parse_tag_err
    field.id = type.id
    field.tag = field_tag
    field.name = name
    field.type = type
    field.size = type.size
    field.kind = FieldKind.UNKNOWN
    if _, ok := type.variant.(reflect.Type_Info_String); ok {
        if _, okk := parse_tag_err.(MissingTagFieldError); okk{
                field.kind = FieldKind.POSITIONAL 
                return field, nil
        }
    }
    if _, ok := type.variant.(reflect.Type_Info_Union); ok {
        if _, okk := parse_tag_err.(MissingTagFieldError); okk{
                field.kind = FieldKind.COMMAND 
                return field, nil
        }
    }
    if parse_tag_err != nil {
        return field, parse_tag_err
    }
    // Check type 
    #partial switch _ in type.variant {
    case reflect.Type_Info_Union: {
            field.kind = FieldKind.COMMAND      
    }
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

@(private)
parse_metadata :: proc(cmd: ^Field, metadata: Metadata) -> (err: ParseError) {
    cmd.fields = make([dynamic]Field, 0, 16)
    j := 0
    k := 0
    for tag, i in metadata.tags {
		name, type := metadata.names[i], metadata.types[i]
        value := parse_field(name, type, tag) or_return
        if value.kind == FieldKind.COMMAND {
            parse_metadata(&value, get_metadata(value.type.id)) or_return
        }else {
            if value.kind == FieldKind.POSITIONAL {
                value.pos = j
                j += 1
            }else {
                value.pos = k
                k += 1
            }
        }
    
        append(&cmd.fields, value)
	}
    return err
}

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
create_fields :: proc(cmd: ^Field, args: []Arg, out: []byte) -> (err: ParseError) {
    last_pos := 0
    exist := false
    for &field, i in cmd.fields {
        found := false
        for arg, i in args {
            #partial switch field.kind {
            case FieldKind.COMMAND:{
                union_type, ok := field.type.variant.(reflect.Type_Info_Union)
                if ok {
                    for v in union_type.variants {
                        vp, ok := v.variant.(reflect.Type_Info_Named)
                        if arg.value == vp.name {
                            sf := reflect.struct_field_by_name(cmd.id, field.name)
                            found = true
                            exist = true

                            dest := raw_data(out[sf.offset:])
                            reflect.set_union_variant_type_info(dest, vp.base)
                            create_fields(&field, args[i:], out[sf.offset:]) or_return
                        }
                    }
                }
                //if arg.value == field.name {
                //    //field.type.variant.(reflect.Type_Info_Union)
                //    sf := reflect.struct_field_by_name(cmd.id, field.name)
                //    create_fields(&field, args[i:], out[sf.offset:]) or_return
                //}            
            }
            case FieldKind.FLAG:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                    found = true
                    exist = true
                    data := true
                    src := &data
                    dest := raw_data(out[sf.offset:])
                    mem.copy(dest, src, field.type.size)
                }
            }
            case FieldKind.OPTIONS:{
                if ((arg.key == field.tag.short || arg.key == field.tag.long)){
                    if slice.contains(field.tag.options, arg.value) {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                        found = true
                        exist = true

                        data := arg.value
                        src := &data
                        dest := raw_data(out[sf.offset:])
                        mem.copy(dest, src, field.type.size)
                    }else {
                        return BadValueFieldError{}
                    }
                }
            }
            case FieldKind.OPTIONS_ANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                    found = true
                    exist = true
                    data := arg.value
                    src := &data
                    dest := raw_data(out[sf.offset:])
                    mem.copy(dest, src, field.type.size)
                }
            }

            case FieldKind.OPTIONS_MANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                    found = true
                    exist = true
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
                            data := arg.value
                            src := raw_data(value_split) 
                            dest := raw_data(out[sf.offset:])
                            mem.copy(dest, src, field.type.size)
                        }else {
                            return BadValueFieldError{}
                        }
                    }else {
                        return OutOfBoundFieldError{}
                    }
                }
            }
            case FieldKind.OPTIONS_MANY_ANY:{
                if arg.key == field.tag.short || arg.key == field.tag.long {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                    exist = true
                    found = true
                    value_split := strings.split(arg.value, ",")
                    defer delete(value_split)
                    if len(value_split) <= field.count {
                        data := arg.value
                        src := raw_data(value_split) 
                        dest := raw_data(out[sf.offset:])
                        mem.copy(dest, src, field.type.size)
                    }else {
                        return OutOfBoundFieldError{}
                    }
                }
            }
            case FieldKind.POSITIONAL:{
                if field.pos == arg.pos {
                    sf := reflect.struct_field_by_name(cmd.id, field.name)
                    exist = true
                    found = true
                    data := arg.value
                    src := rawptr(&data) 
                    dest := raw_data(out[sf.offset:])
                    mem.copy(dest, src, len(data))
                }
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

    return err
}

parse :: proc(argv: []string, $T: typeid) -> (res: ^T, err: ParseError) {
    cmd := Field{
        id = T,
        name = "oldone",
        kind = FieldKind.COMMAND,
        size = size_of(T),
        offset = -1
    }
    parse_metadata(&cmd, get_metadata(T)) or_return
    defer delete(cmd.fields)
    args := parse_argv(argv)
    defer delete(args)
    out := make([]byte, size_of(T))
    create_fields(&cmd, args[:], out) or_return
    //print_help(cmd)
    res = (^T)(raw_data(out))
    return res, err 
}

//free_parse :: proc($T: typeid, value: ^T) {
//    if value != nil {
//        free(value)
//    }
//}
