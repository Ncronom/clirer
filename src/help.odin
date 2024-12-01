package oldone

import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"

// - [x]: positional help
// - [x]: show portion of positional help for unions
// - [x]: display help on error
// - [ ]: enum help

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


print_help :: proc(
    path: string, 
    target: ^reflect.Type_Info, 
){
    builder := strings.builder_make() 
    defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder, "Program desccription\n")
    fmt.sbprintf(&builder, "Usage:\n")
    help := ""
    if reflect.is_union(target) {
        help = print_help_union(path, target)
    }
    else if reflect.is_struct(target) {
        help = print_help_struct(path, target)
    }
    res := fmt.sbprintf(&builder, "%s", help)
    fmt.println(res)
    delete(help)
}


get_flag_help :: proc(name: string, tag: Tag, info: ^reflect.Type_Info) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    flag_name := tag.short if len(tag.long) == 0 else tag.long
    flag_name = name if len(flag_name) == 0 else flag_name
    fmt.sbprintf(&builder, "\t\t-%s:", flag_name)
    if len(tag.value) > 0 {
        fmt.sbprintf(&builder, "%s\n", tag.value)
    }else {
        fmt.sbprintf(&builder, "<string>\n")
    }
    fmt.sbprintf(&builder, "\t\t\t%s\n", tag.help)

    #partial switch t in info.variant {
    case reflect.Type_Info_Enum:    {   // OPTION
        fmt.sbprintf(&builder, "\t\t\tAvailable Options\n")
        for n in t.names {
            fmt.sbprintf(&builder, "\t\t\t-%s:%s\n", flag_name, n)
        } 
    } 
    case reflect.Type_Info_String:  {   // VALUE
    } 
    case reflect.Type_Info_Array:   {
       if enum_type, ok := t.elem.variant.(reflect.Type_Info_Enum); ok { // N OPTIONS
        fmt.sbprintf(&builder, "\t\t\tAvailable Options\n")
        for n in enum_type.names {
            fmt.sbprintf(&builder, "\t\t\t-%s:%s\n", flag_name, n)
        } 
       }else { // N VALUES
       }
    }
    }
    return strings.clone(fmt.sbprint(&builder))
}


get_cmds_help :: proc(info: ^reflect.Type_Info) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder, "Commands:\n")
    info_union, _ := info.variant.(reflect.Type_Info_Union)
    named_union, ok := info.variant.(reflect.Type_Info_Named) 
    if ok {
        info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
    }
    help := ""
    for variant, i in info_union.variants {
        named_variant, _ := variant.variant.(reflect.Type_Info_Named)
        names := reflect.struct_field_names(named_variant.base.id)
        if names[len(names) - 1] == "help" {
            tags := reflect.struct_field_tags(named_variant.base.id)
            tag := parse_tag(tags[len(tags) - 1])
            index := strings.index(tag.help, "\n")
            help = tag.help
            if index >= 0 {
                help = tag.help[:index]
            }
        }
        fmt.sbprintf(&builder, "\t%s\t%s\n", named_variant.name, help)
    }
    res := strings.clone(fmt.sbprint(&builder))
    return res
}

@private
print_help_union :: proc(
    path: string, 
    target: ^reflect.Type_Info, 
) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    info_union, _ := target.variant.(reflect.Type_Info_Union)
    named_union, ok := target.variant.(reflect.Type_Info_Named) 
    if ok {
        info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
    }

    fmt.sbprintf(&builder, "\t%s command [arguments]\n", path)
    fmt.sbprintf(&builder, "Commands:\n")

    for variant, i in info_union.variants {
        named_variant, _ := variant.variant.(reflect.Type_Info_Named)
        names := reflect.struct_field_names(named_variant.base.id)
        help := ""
        if names[len(names) - 1] == "help" {
            tags := reflect.struct_field_tags(named_variant.base.id)
            tag := parse_tag(tags[len(tags) - 1])
            index := strings.index(tag.help, "\n")
            help = tag.help
            if index >= 0 {
                help = tag.help[:index]
            }
        }
        fmt.sbprintf(&builder, "\t%s\t%s\n", named_variant.name, help)
    }
    return strings.clone(fmt.sbprint(&builder))
}

@private
print_help_struct :: proc(
    path: string, 
    target: ^reflect.Type_Info, 
) -> string {
    names :=    reflect.struct_field_names(target.id)
    tags :=     reflect.struct_field_tags(target.id)
    types :=    reflect.struct_field_types(target.id)
    builder_main := strings.builder_make()
    defer strings.builder_destroy(&builder_main)
    builder_positional := strings.builder_make()
    defer strings.builder_destroy(&builder_positional)
    builder_flags := strings.builder_make()
    defer strings.builder_destroy(&builder_flags)
    help_cmds := ""

    fmt.sbprintf(&builder_main, "\t%s [arguments] ", path)

    splitted_path := strings.split(path, " ")
    defer delete(splitted_path)

    fmt.sbprintf(
        &builder_positional, 
        "\t%s\t",
        splitted_path[len(splitted_path)-1]
    )

    if names[len(names)-1] == "help" {
        tag := parse_tag(tags[len(names)-1])
        names := names[:len(names)-1]
        fmt.sbprintf(&builder_positional, "%s", tag.help)
    }
    fmt.sbprintf(&builder_positional, "\n")

    fmt.sbprintf(&builder_flags, "\tFlags\n")

    for name, i in names {
        if reflect.is_union(types[i]) {
            fmt.sbprintf(&builder_main, "[command]")
            help_cmds = get_cmds_help(types[i])
            break
        }else if names[i] != "help"{
            tag := parse_tag(tags[i])
            help_flag := get_flag_help(names[i], tag, types[i])
            fmt.sbprintf(&builder_flags, "%s", help_flag)
            delete(help_flag)
        }    
    }
    fmt.sbprintf(&builder_main, "\n")
    positional_str := fmt.sbprint(&builder_positional)
    flags_str := fmt.sbprint(&builder_flags)
    res:= strings.clone(fmt.sbprintf(&builder_main, "%s\n%s\n%s", positional_str, flags_str, help_cmds))
    delete(help_cmds)
    return res
}

