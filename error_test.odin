package clirer

import "core:testing"
import "core:os"

@(test)
error_unknown_test :: proc(t: ^testing.T) {
    TagType :: enum{ todo, old }
    FormatType :: enum{ raw, hidden }
    cmd :: struct {
        archive:    bool                `cli:"a,archive"`,
        tags:       [8]TagType          `cli:"t,tags"`,  
        format:     FormatType          `cli:"f,format"`,
        filepath:   string,
        by:         [8]string           `cli:"b,by"`,
    }
    cmds :: union{
        cmd 
    }
    argv := []string{
        os.args[0], 
        "-unknownflag", 
        "-archive", 
        "-tags:todo,old,todo",
        "path/to/the/file.ext",
        "-format:hidden",
        "-by:carenne,jean",
    }
    res, err :=  parse(cmd, argv)
    parsed_err, ok := err.(ErrorUnknown)
    testing.expectf(
        t, 
        ok, 
        "Expect Error to be ErrorUnknown, got %v.",
        typeid_of(type_of(err))
    )
    argv2 := []string{
        os.args[0], 
        "cm", 
        "-archive", 
        "-tags:todo,old,todo",
        "path/to/the/file.ext",
        "-format:hidden",
        "-by:carenne,jean",
    }
    res2, err2 :=  parse(cmds, argv2)
    parsed_err2, ok2 := err.(ErrorUnknown)
    testing.expectf(
        t, 
        ok2, 
        "Expect Error to be ErrorUnknown, got %v.",
        typeid_of(type_of(err))
    )

    res3, err3 :=  parse(cmds, argv)
    parsed_err3, ok3 := err.(ErrorUnknown)
    testing.expectf(
        t, 
        ok3, 
        "Expect Error to be ErrorUnknown, got %v.",
        typeid_of(type_of(err))
    )
}

@(test)
error_missing_test :: proc(t: ^testing.T) {
    TagType :: enum{ todo, old }
    FormatType :: enum{ raw, hidden }
    cmd :: struct {
        archive:    bool                `cli:"a,archive/required"`,
        tags:       [8]TagType          `cli:"t,tags"`,  
        format:     FormatType          `cli:"f,format"`,
        filepath:   string,
        by:         [8]string           `cli:"b,by"`,
    }
    cmds :: union{
        cmd 
    }
    argv := []string{
        os.args[0], 
        "-tags:todo,old,todo",
        "path/to/the/file.ext",
        "-format:hidden",
        "-by:carenne,jean",
    }
    res, err :=  parse(cmd, argv)
    parsed_err, ok := err.(ErrorMissing)
    testing.expectf(
        t, 
        ok, 
        "Expect Error to be ErrorMissing, got %v.",
        typeid_of(type_of(err))
    )
}

@(test)
error_value_test :: proc(t: ^testing.T) {

}
