package oldone
import "core:strings"
LEGACY :: #config(FORMAT, false)
ArgType :: enum {
    ROOT,
    POSITIONAL,
    FLAG,
}
Arg :: struct {
    type:   ArgType,
    key:    string,
    values: []string,
}
ArgsIterator :: struct {
    position:   int, 
    args:       []string,
    arg:        Arg
}
args_iterator_make :: proc(args: []string) -> (iterator: ArgsIterator){
    iterator.args = args
    iterator.args[0] = get_root_name(iterator.args[0])
    iterator.position = -1
    return iterator
}
args_iterator_destroy :: proc(iterator: ^ArgsIterator){
    delete(iterator.arg.values) 
}
get_root_name :: proc(arg: string) -> (cmd_name: string) {
    cmd_name = arg
    index := strings.last_index(arg, "/")
    if index >= 0 {
        cmd_name = arg[index+1:]
    }
    return cmd_name
}
current_arg :: proc(iterator: ^ArgsIterator) -> Arg {
    return iterator.arg
}
next_arg :: proc(iterator: ^ArgsIterator) -> (arg: Arg, end: bool) {
    iterator.position += 1
    if iterator.position == len(iterator.args) {
        return arg, true
    }
    delete(iterator.arg.values)
    iterator.arg = parse_arg(iterator.args[iterator.position:])
    return iterator.arg, false
}
parse_arg :: proc(args: []string) -> (arg: Arg) {
    when LEGACY {
        arg = parse_arg_legacy(args)
    }else {
        arg = parse_arg_odin(args)
    }
    return arg
}
parse_arg_legacy :: proc(args: []string) -> (arg: Arg) {
    panic("TODO - parse_arg_legacy(args: []string)") 
}
parse_arg_odin :: proc(args: []string) -> (arg: Arg) {
    arg.type = ArgType.POSITIONAL
    param := args[0]
    if param[0] == '-'{
        arg.type = ArgType.FLAG
        arg.key = param[1:]
        index := strings.index(param[:], ":")
        raw_values := ""
        if index >= 0 {
            arg.key = param[1:index]
            raw_values = param[index+1:]
        }
        if len(raw_values) > 0 {
            arg.values = strings.split(raw_values, ",")
        }
    }
    else {
        arg.values      = make([]string, 1)
        arg.values[0]   = param
    }
   return arg
}
