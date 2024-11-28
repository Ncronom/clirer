package oldone

import "core:strings"

// USER ERRORS
// - Unknown (parameter don't exist)
// - Missing (required)
// - Bad usage (wrong parameter value)

// DEFINITION ERRORS
// ???

LEGACY :: #config(FORMAT, false)

ArgType :: enum {
    ROOT,
    POSITIONAL,
    FLAG,
}

Arg :: struct {
    type:   ArgType,
    key:    string,
    values: []string
}

ArgsIterator :: struct {
    position:   int, 
    args:       []string,
    arg:        ^Arg
}

args_iterator_make :: proc(args: []string) -> (iterator: ^ArgsIterator){
    iterator = new(ArgsIterator)
    iterator.args = args
    iterator.args[0] = get_root_name(iterator.args[0])
    iterator.position = -1
    iterator.arg = new(Arg)
    iterator.arg.values = make([]string, 0)

    return iterator
}
args_iterator_destroy :: proc(iterator: ^ArgsIterator){
    if iterator != nil {
        free(iterator.arg)
        delete(iterator.arg.values)
        free(iterator)
    }
}

get_root_name :: proc(arg: string) -> (cmd_name: string) {
    cmd_name = arg
    index := strings.last_index(arg, "/")
    if index >= 0 {
        cmd_name = arg[index+1:]
    }
    return cmd_name
}

current_arg :: proc(iterator: ^ArgsIterator) -> ^Arg {
    return iterator.arg
}

next_arg :: proc(iterator: ^ArgsIterator) -> ^Arg {
    delete(iterator.arg.values)
    free(iterator.arg)
    iterator.position += 1
    if iterator.position == len(iterator.args) {
        return nil
    }
    iterator.arg = parse_arg(iterator.args[iterator.position:])
    return iterator.arg
}

parse_arg :: proc(args: []string) -> (arg: ^Arg) {
    when LEGACY {
        arg = parse_arg_legacy(args)
    }else {
        arg = parse_arg_odin(args)
    }
    return arg
}


parse_arg_legacy :: proc(args: []string) -> (arg: ^Arg) {
    panic("TODO - parse_arg_legacy(args: []string)") 
}

parse_arg_odin :: proc(args: []string) -> (arg: ^Arg) {
   arg = new(Arg)
   arg.type = ArgType.POSITIONAL
   param := args[0]
   if param[0] == '-'{
        arg.type = ArgType.FLAG
        param = param[1:]
   } 
   arg.key = param
   index := strings.index(param, ":")
   if index >= 0 {
    arg.key = param[:index]
    arg.values = strings.split(param[index+1:], ",")
   }
   return arg
}


