package clirer


import "core:log"
import "core:testing"
import "core:os"

get_data_set :: proc() -> (input: [5]string) {
    input = [5]string{
        "C:/Users/name/apps/search.exe", 
        "-strict",
        "-prefix:_",
        "-suffix:_,*",
        "nomenclature"
    }
    return input
}

@(test)
user_get_root_name_test :: proc(t: ^testing.T) {
    input := get_data_set() 
    output := get_root_name(input[0])
    testing.expectf(
        t, 
        output == "search.exe", 
        "Expect output to be cmd.exe, got %s",
        output
    )
}

@(test)
user_args_iterator_make_test :: proc(t: ^testing.T) {
    input := get_data_set() 
    output := args_iterator_make(input[:])
    defer args_iterator_destroy(&output)
    testing.expectf(
        t, 
        output.args != nil && output.args[0] == "search.exe", 
        "Expect output to be <%v>, got <%v>",
        input,
        output.args
    )
}

@(test)
user_next_arg_test :: proc(t: ^testing.T) {
    input := get_data_set() 
    iterator := args_iterator_make(input[:])
    defer args_iterator_destroy(&iterator)
    arg, end := Arg{}, false
    i := -1
    for !end {
        arg, end = next_arg(&iterator)
        i += 1
        testing.expectf(
            t, 
            iterator.position == i, 
            "Expect position to be <%v>, got <%v>", 
            i, iterator.position
        )
    }
    testing.expectf(
        t, 
        end, 
        "Expect end to be <%v>, got <%v>", 
        true, end
    )
}

@(test)
user_parse_args_test :: proc(t: ^testing.T) {

    input := get_data_set() 
    iterator := args_iterator_make(input[:])
    defer args_iterator_destroy(&iterator)

    res_root        := parse_arg(iterator.args[:])
    res_switch      := parse_arg(iterator.args[1:])
    res_single      := parse_arg(iterator.args[2:])
    res_many        := parse_arg(iterator.args[3:])
    res_pos         := parse_arg(iterator.args[4:])

    defer delete(res_root.values) 
    defer delete(res_switch.values) 
    defer delete(res_single.values) 
    defer delete(res_many.values) 
    defer delete(res_pos.values) 

    expect_root     := 
        Arg{
            key="",
            values=[]string{"search.exe"},
            type= ArgType.POSITIONAL
        }
    expect_switch   := 
        Arg{
            key="strict",
            values=nil,
            type=ArgType.FLAG
        }
    expect_single   := 
        Arg{
            key="prefix",
            values=[]string{"_"},
            type=ArgType.FLAG
        }
    expect_many     := 
         Arg{
            key="suffix",
            values=[]string{"_", "*"},
            type= ArgType.FLAG
        }
    expect_pos      := 
         Arg{
            key="",
            values=[]string{"nomenclature"},
            type= ArgType.POSITIONAL
        }

    output_root     :=
        res_root.key            == expect_root.key              && 
        len(res_root.values)    == len(expect_root.values)      && 
        res_root.type           == expect_root.type 
    output_switch   :=
        res_switch.key          == expect_switch.key            && 
        len(res_switch.values)  == len(expect_switch.values)    && 
        res_switch.type         == expect_switch.type 
    output_single   :=
        res_single.key          == expect_single.key            && 
        len(res_single.values)  == len(expect_single.values)    && 
        res_single.type         == expect_single.type 
    output_many     :=
        res_many.key            == expect_many.key              && 
        len(res_many.values)    == len(expect_many.values)      && 
        res_many.type           == expect_many.type 
    output_pos      :=
        res_pos.key             == expect_pos.key               && 
        len(res_pos.values)     == len(expect_pos.values)       && 
        res_pos.type            == expect_pos.type 

    testing.expectf(
        t, 
        output_root,
        "Expect root arg to be %v, got %v",
        expect_root, res_root
    )
    testing.expectf(
        t, 
        output_switch,
        "Expect switch arg to be %v, got %v",
        expect_switch, res_switch
    )
    testing.expectf(
        t, 
        output_single,
        "Expect single arg to be %v, got %v",
        expect_single, res_single
    )
    testing.expectf(
        t, 
        output_many,
        "Expect many arg to be %v, got %v",
        expect_many, res_many
    )
    testing.expectf(
        t, 
        output_pos,
        "Expect pos arg to be %v, got %v",
        expect_pos, res_pos
    )
}
