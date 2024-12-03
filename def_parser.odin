#+private
package clirer
import "core:reflect"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:slice"
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

parse_union :: proc(
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
                return parse_struct(iterator, info_struct, path, data)
            }
        }
    }    
    return new_error_unknown_cmd(parent_path, type_info)
}

get_sub_cmds :: proc(type_info: ^reflect.Type_Info) -> []^reflect.Type_Info {
    info_union, _ := type_info.variant.(reflect.Type_Info_Union)
    named_union, ok := type_info.variant.(reflect.Type_Info_Named) 
    if ok {
        info_union, _ =  named_union.base.variant.(reflect.Type_Info_Union)
    }
	return info_union.variants
}

get_sub_cmd_name :: proc(type_info: ^reflect.Type_Info) -> (res: string) {
    named, _ := type_info.variant.(reflect.Type_Info_Named) 
	res = named.name
	return res
}


get_sub_cmd_names :: proc(
	type_info: ^reflect.Type_Info, 
	allocator := context.allocator
) -> (names: []string) {
	sub_cmds := get_sub_cmds(type_info)
	names = make([]string, len(sub_cmds), allocator)
	for cmd, i in sub_cmds {
		names[i] = get_sub_cmd_name(cmd)	
	}
	return names
}


is_sub_cmd_of :: proc(name: string, type_info: ^reflect.Type_Info) -> bool {
	sub_cmds := get_sub_cmds(type_info)
	for cmd in sub_cmds {
		sub_cmd_name := get_sub_cmd_name(cmd)
		// CHECK ID ARG IS COMMAND
		if(name == sub_cmd_name) {
			return true
		}
	}
	return false
}

parse_tags :: proc(raw_tags: []reflect.Struct_Tag, allocator := context.allocator) -> []Tag {
    tags := make([]Tag, len(raw_tags), allocator)
    for raw_tag, i in raw_tags {
        tags[i] =  parse_tag(raw_tag)
    }
	return tags
}

resolve_required :: proc(
	tags: 	[]Tag,
	struct_info: 	^reflect.Type_Info,
	parent_path:	string,
) -> Error {
	required := false
    for tag in tags {
         if tag.required {return new_error_missing(parent_path, struct_info)}
    }
    return nil
}

get_positional :: proc(
	types: []^reflect.Type_Info, 
	raw_tags: []reflect.Struct_Tag, 
	start: int,
) -> int{
	for type, i in types[start:] {
		if is_positional(type, raw_tags[i]) {
			return start + i
		}
	}
	return -1
}


parse_struct :: proc(
    iterator: ^ArgsIterator, 
    struct_info: ^reflect.Type_Info,
    parent_path: string, 
    data: []byte
) -> (err: Error) {

    arg, end := next_arg(iterator)

    names :=    reflect.struct_field_names(struct_info.id)
    raw_tags :=     reflect.struct_field_tags(struct_info.id)
    types :=    reflect.struct_field_types(struct_info.id)
    offsets :=  reflect.struct_field_offsets(struct_info.id)

    tags := parse_tags(raw_tags)
    defer delete(tags)

	// FIND SUB COMMAND
	sub_cmd_names: []string = nil
	sub_cmds_index:= -1
	defer {
		if sub_cmd_names != nil {
			delete(sub_cmd_names) 
		}
	}
	for type, i in types {
		if reflect.is_union(type) {
			sub_cmds_index = i
			sub_cmd_names = get_sub_cmd_names(type)
			break
		}
	}

	last_positional_index := get_positional(types, raw_tags, 0)

    for !end {
		#partial switch arg.type {
		case ArgType.POSITIONAL:{
			if slice.contains(sub_cmd_names, arg.values[0]) {
				resolve_required(tags, struct_info, parent_path) or_return
				return parse_union(iterator, types[sub_cmds_index], parent_path, data[offsets[sub_cmds_index]:])
			}
			if last_positional_index == -1{
				return new_error_unknown_flag(parent_path, struct_info)
			}
        	tags[last_positional_index].required = false
        	mem.copy(raw_data(data[offsets[last_positional_index]:]), &arg.values[0], types[last_positional_index].size)  
			last_positional_index = get_positional(types, raw_tags, last_positional_index)
		}
		case ArgType.FLAG:{
			parse_flag(&arg, types, offsets, tags, parent_path, struct_info, data) or_return
		}
		}
    	arg, end = next_arg(iterator)
	}
	resolve_required(tags, struct_info, parent_path) or_return
    return nil
}

parse_flag :: proc(
	arg: 		^Arg, 
	types: 		[]^reflect.Type_Info, 
	offsets: 	[]uintptr, 
	tags: 		[]Tag,  
    parent_path: string, 
    struct_info: ^reflect.Type_Info,
	data: 		[]byte,
) -> Error {
	found := false
	for type, i in types {
    	if (tags[i].short == arg.key || tags[i].long == arg.key) && arg.type == ArgType.FLAG {
    	    found = true
    	    tags[i].required = false
    	    type_info := type
    	    type_info_named, type_info_named_ok := type.variant.(reflect.Type_Info_Named)
    	    if type_info_named_ok {
    	        type_info = type_info_named.base
    	    }
    	    #partial switch t in type_info.variant {
    	        case reflect.Type_Info_String: {
    	            mem.copy(raw_data(data[offsets[i]:]), &arg.values[0], type.size)  
    	        }
    	        case reflect.Type_Info_Enum: {
    	            for f, j in t.names {
    	                if arg.values[0] == f {
    	                    mem.copy(raw_data(data[offsets[i]:]), &t.values[j], type.size)  
    	                }
    	            }
    	        }
    	        case reflect.Type_Info_Boolean: {
    	            data[offsets[i]] = 1
    	        }
    	        case reflect.Type_Info_Array: {
    	            if reflect.is_enum(t.elem){ // N OPTIONS
    	            		named_variant, _ := t.elem.variant.(reflect.Type_Info_Named)
    	                    enum_type, ok := named_variant.base.variant.(reflect.Type_Info_Enum)
    	                    for v, j in arg.values {
    	                        for e, k in enum_type.names {
    	                            if v == e {
    	                                mem.copy(
    	                                    raw_data(data[offsets[i] + uintptr(k * size_of(reflect.Type_Info_Enum_Value)):]), 
    	                                    &enum_type.values[k], 
    	                                    size_of(reflect.Type_Info_Enum_Value)
										)  
    	                            }
    	                        }
    	                    }
    	            }
    	            else if reflect.is_string(t.elem){
    	                if len(arg.values) <= t.count {
    	                    mem.copy(
    	                        raw_data(data[offsets[i]:]), 
    	                        raw_data(arg.values),
    	                        len(arg.values)*size_of(string)
    	                    )  
    	                }
    	            }
    	        }
    	    }
    	}
	}
	if !found{
		return new_error_unknown_flag(parent_path, struct_info)
	}
    return nil
}
