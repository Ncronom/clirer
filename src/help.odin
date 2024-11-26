package oldone

import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"

// - [x]: positional help
// - [x]: show portion of positional help for unions
// - [ ]: display help on error
// - [ ]: enum help

parse_help :: proc(root: string, id: typeid) -> string{
    info := type_info_of(id)
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder, "Program desccription\n")
    fmt.sbprintf(&builder, "Usage:\n")
    named_info, _ := info.variant.(reflect.Type_Info_Named)
    root_name := named_info.name
    if len(root) > 0 {
        root_name = fmt.tprintf("%s %s", root, root_name)
    }
    if reflect.is_struct(info) {
        parse_help_struct(root_name, &builder, info)
    }
    else if reflect.is_union(info) {
        parse_help_union(root_name, &builder, info)
    }
    return fmt.sbprint(&builder)
}



parse_help_union :: proc(parent_name: string, builder: ^strings.Builder, info: ^reflect.Type_Info) {
    named_info, named_ok := info.variant.(reflect.Type_Info_Named)
    if named_ok {
        named_info, named_ok := info.variant.(reflect.Type_Info_Named)
        fmt.sbprintf(builder, "\t%s command [arguments]\n", parent_name)
        fmt.sbprintf(builder, "Commands:\n")
        union_info, union_ok := named_info.base.variant.(reflect.Type_Info_Union)
        if union_ok {
            for variant, i in union_info.variants {
                named_info, named_ok := variant.variant.(reflect.Type_Info_Named)
                if named_ok {
                    help := ""
                    names := reflect.struct_field_names(named_info.base.id)
                    if names[len(names) - 1] == "help" {
                        tags := reflect.struct_field_tags(named_info.base.id)
                        tag, _ := parse_tag(tags[len(tags) - 1])
                        index := strings.index(tag.help, "\n")
                        help = tag.help
                        if index >= 0 {
                            help = tag.help[:index]
                        }
                    }
                    fmt.sbprintf(builder, "\t%s\t%s\n", named_info.name, help)
                }
            }
        }
    }
}

parse_help_struct :: proc(parent_name: string, builder: ^strings.Builder, info: ^reflect.Type_Info) {
    names :=    reflect.struct_field_names(info.id)
    tags :=     reflect.struct_field_tags(info.id)
    types :=    reflect.struct_field_types(info.id)
    builder_flags := strings.builder_make()
    defer strings.builder_destroy(&builder_flags)
    builder_positional := strings.builder_make()
    defer strings.builder_destroy(&builder_positional)
    named_info, named_ok := info.variant.(reflect.Type_Info_Named)
    if named_ok {
        fmt.sbprintf(builder, "\t%s [arguments]\n\n", parent_name)
    }
    fmt.sbprintf(&builder_positional, "\t%s\t", named_info.name)
    if names[len(names)-1] == "help" {
        tag, exist := parse_tag(tags[len(names)-1])
        fmt.sbprintf(&builder_positional, "%s", tag.help)
    }
    fmt.sbprintf(&builder_positional, "\n")
    fmt.sbprintf(&builder_flags, "\tFlags\n")

    for name, i in names {
        tag, exist := parse_tag(tags[i])
        flag_name := tag.short if len(tag.long) == 0 else tag.short
        flag_name = names[i] if len(flag_name) == 0 else flag_name
        fmt.sbprintf(&builder_flags, "\t\t-%s\n", flag_name)
        fmt.sbprintf(&builder_flags, "\t\t\t%s\n", tag.help)
        if len(tag.short) > 0 || len(tag.long) > 0 {
            #partial switch t in types[i].variant {
            case reflect.Type_Info_Enum:    {   // OPTION
                fmt.sbprintf(&builder_flags, "\t\t\tAvailable Options\n")
                for n in t.names {
                    fmt.sbprintf(&builder_flags, "\t\t\t-%s:%s\n", flag_name, n)
                } 
            } 
            case reflect.Type_Info_String:  {   // VALUE
            } 
            case reflect.Type_Info_Array:   {
               if enum_type, ok := t.elem.variant.(reflect.Type_Info_Enum); ok { // N OPTIONS
                fmt.sbprintf(&builder_flags, "\t\t\tAvailable Options\n")
                for n in enum_type.names {
                    fmt.sbprintf(&builder_flags, "\t\t\t-%s:%s\n", flag_name, n)
                } 
               }else { // N VALUES
               }
            }
            }
        }
    }
    positional_str := fmt.sbprint(&builder_positional)
    flags_str := fmt.sbprint(&builder_flags, "")
    fmt.sbprintf(builder, "%s\n%s", positional_str, flags_str)
}
