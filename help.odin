package clirer

import "core:log"
import "core:fmt"
import "core:slice"
import "core:reflect"
import "core:strings"

// - [x]: positional help
// - [x]: show portion of positional help for unions
// - [x]: display help on error
// - [ ]: enum help

print_help :: proc(
    err: Error
){

    builder := strings.builder_make() 
    defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder, "%s\n", current_config.description)
    fmt.sbprintf(&builder, "Usage:\n")
    str := ""
    switch e in err {
    case ErrorUnknownCmd:   {
        fmt.sbprintf(&builder, "\t%s command [arguments]\n", e.path)
        str = fmt.sbprint(&builder, get_cmds_help(e.type_info))
    }
    case ErrorUnknownFlag:  {
        fmt.sbprintf(&builder, "\t%s [arguments]\n", e.path)
        str = fmt.sbprint(&builder, get_help_struct(e.path, e.type_info))
    }
    case ErrorMissing:      {
        fmt.sbprintf(&builder, "\t%s [arguments]\n", e.path)
        str = fmt.sbprint(&builder, get_help_struct(e.path, e.type_info))
	}
    case ErrorValue:        {}
    }
    fmt.println(str)
}

@(private)
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
        if len(names) > 0 && names[len(names) - 1] == "help" {
            tags := reflect.struct_field_tags(named_variant.base.id)
            tag := parse_tag(tags[len(tags) - 1])
            index := strings.index(tag.help, "\n")
            help = tag.help
            if index >= 0 {
                help = tag.help[:index]
            }
        }
        fmt.sbprintf(&builder, "\t%s\t%s\n", named_variant.name, help)
		help = ""
    }
    res := strings.clone(fmt.sbprint(&builder))
    return res
}

//@(private)
//print_help_union :: proc(
//    path: string, 
//    target: ^reflect.Type_Info, 
//) -> string {
//    builder := strings.builder_make()
//    defer strings.builder_destroy(&builder)
//    info_union, _ := target.variant.(reflect.Type_Info_Union)
//    named_union, ok := target.variant.(reflect.Type_Info_Named) 
//    if ok {
//        info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
//    }
//
//    fmt.sbprintf(&builder, "\t%s command [arguments]\n", path)
//    fmt.sbprintf(&builder, "Commands:\n")
//
//    for variant, i in info_union.variants {
//        named_variant, _ := variant.variant.(reflect.Type_Info_Named)
//        names := reflect.struct_field_names(named_variant.base.id)
//        help := ""
//        if names[len(names) - 1] == "help" {
//            tags := reflect.struct_field_tags(named_variant.base.id)
//            tag := parse_tag(tags[len(tags) - 1])
//            index := strings.index(tag.help, "\n")
//            help = tag.help
//            if index >= 0 {
//                help = tag.help[:index]
//            }
//        }
//        fmt.sbprintf(&builder, "\t%s\t%s\n", named_variant.name, help)
//    }
//    return strings.clone(fmt.sbprint(&builder))
//}

//print_help :: proc(
//    path: string, 
//    target: ^reflect.Type_Info, 
//){
//    builder := strings.builder_make() 
//    defer strings.builder_destroy(&builder)
//    fmt.sbprintf(&builder, "Program desccription\n")
//    fmt.sbprintf(&builder, "Usage:\n")
//    help := ""
//    if reflect.is_union(target) {
//        help = print_help_union(path, target)
//    }
//    else if reflect.is_struct(target) {
//        help = print_help_struct(path, target)
//    }
//    res := fmt.sbprintf(&builder, "%s", help)
//    fmt.println(res)
//    delete(help)
//}

@(private)
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

is_positional :: proc(type_info: ^reflect.Type_Info, raw_tag: reflect.Struct_Tag) -> bool {
	tag := parse_tag(raw_tag)
	if  reflect.is_string(type_info) && 
		len(tag.short) == 0 && 
		len(tag.long) == 0 
	{
		return true
	}
	return false
}

is_sub_cmd :: proc(type_info: ^reflect.Type_Info) -> bool {
	return reflect.is_union(type_info)
}

is_help :: proc(name: string, type_info: ^reflect.Type_Info) -> bool {
	return name == "help" && reflect.is_boolean(type_info) 
}

is_flag :: proc(name: string, type_info: ^reflect.Type_Info, raw_tag: reflect.Struct_Tag) -> bool {
	return !is_sub_cmd(type_info) && !is_positional(type_info, raw_tag) && !is_help(name, type_info)
}


@(private)
get_help_struct :: proc(
    path: string, 
    target: ^reflect.Type_Info, 
) -> string {
    names :=    reflect.struct_field_names(target.id)
    tags :=     reflect.struct_field_tags(target.id)
    types :=    reflect.struct_field_types(target.id)
    builder_main := strings.builder_make()
    defer strings.builder_destroy(&builder_main)
    builder_cmd_help := strings.builder_make()
    defer strings.builder_destroy(&builder_cmd_help)
    builder_flags := strings.builder_make()
    defer strings.builder_destroy(&builder_flags)
    help_cmds := ""

    splitted_path := strings.split(path, " ")
    defer delete(splitted_path)


	flags_indices := make([dynamic]int, 0, 16)
	defer delete(flags_indices)
	sub_cmds_indices := make([dynamic]int, 0, 16)
	defer delete(sub_cmds_indices)
	positionals_indices := make([dynamic]int, 0, 16)
	defer delete(positionals_indices)


	// Analyse structure by searching for defined:
	// - sub commands
	// - positionals
	// - flags 
    for name, i in names {
		if is_sub_cmd(types[i]) {
			append(&sub_cmds_indices, i)
		}
		else if is_positional(types[i], tags[i]) {
			append(&positionals_indices, i)
		}else if is_flag(name, types[i], tags[i]) {
			append(&flags_indices, i)
		}
	}

	// Current CMD
    fmt.sbprintf(
        &builder_cmd_help, 
        "\t%s\t",
        splitted_path[len(splitted_path)-1]
    )
    if names[len(names)-1] == "help" {
        tag := parse_tag(tags[len(names)-1])
        names := names[:len(names)-1]
        fmt.sbprintf(&builder_cmd_help, "%s", tag.help)
    }
    fmt.sbprintf(&builder_cmd_help, "\n")


	// FLAGS
	if len(flags_indices) > 0 {
    	fmt.sbprintf(&builder_flags, "\tFlags\n")
    	for fi in flags_indices {
    	    if is_flag(names[fi], types[fi], tags[fi]){
    	        tag := parse_tag(tags[fi])
    	        help_flag := get_flag_help(names[fi], tag, types[fi])
    	        fmt.sbprintf(&builder_flags, "%s", help_flag)
    	        delete(help_flag)
    	    }    
    	}
	}

	// SUB COMMANDS 
	if len(sub_cmds_indices) > 0 {
    	help_cmds = get_cmds_help(types[sub_cmds_indices[0]])
	}
	
	// Create current command help
    fmt.sbprintf(&builder_main, "\n")
    positional_str := fmt.sbprint(&builder_cmd_help)
    flags_str := fmt.sbprint(&builder_flags)
    res:= strings.clone(fmt.sbprintf(&builder_main, "%s\n%s\n%s", positional_str, flags_str, help_cmds))
    delete(help_cmds)
    return res
}

