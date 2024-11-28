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
        tag.required = param == "required"
        tag.value = param[1:len(param)-1] if param[0] == '<' &&
        param[len(param) - 1] == '>' else tag.value
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
    if reflect.is_union(target) {
        print_help_union(&builder, path, target)
    }
    else if reflect.is_struct(target) {
        print_help_struct(&builder, path, target)
    }
    fmt.println(fmt.sbprint(&builder))
}

@private
print_help_union :: proc(
    builder: ^strings.Builder,
    path: string, 
    target: ^reflect.Type_Info, 
) {
    named_target, _ := target.variant.(reflect.Type_Info_Named)
    union_target, _ := named_target.base.variant.(reflect.Type_Info_Union)
    fmt.sbprintf(builder, "\t%s command [arguments]\n", path)
    fmt.sbprintf(builder, "Commands:\n")

    for variant, i in union_target.variants {
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
        fmt.sbprintf(builder, "\t%s\t%s\n", named_variant.name, help)
    }
}

@private
print_help_struct :: proc(
    builder: ^strings.Builder,
    path: string, 
    target: ^reflect.Type_Info, 
) {
    names :=    reflect.struct_field_names(target.id)
    tags :=     reflect.struct_field_tags(target.id)
    types :=    reflect.struct_field_types(target.id)
    builder_flags := strings.builder_make()
    defer strings.builder_destroy(&builder_flags)
    builder_positional := strings.builder_make()
    defer strings.builder_destroy(&builder_positional)
    named_info, named_ok := target.variant.(reflect.Type_Info_Named)
    if named_ok {
        fmt.sbprintf(builder, "\t%s [arguments]\n\n", path)
    }
    fmt.sbprintf(&builder_positional, "\t%s\t", named_info.name)
    if names[len(names)-1] == "help" {
        tag := parse_tag(tags[len(names)-1])
        fmt.sbprintf(&builder_positional, "%s", tag.help)
    }
    fmt.sbprintf(&builder_positional, "\n")
    fmt.sbprintf(&builder_flags, "\tFlags\n")

    for name, i in names {
        tag := parse_tag(tags[i])
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

