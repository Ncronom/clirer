package clirer

import "core:testing"
import "core:os"
import "core:log"

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
    parsed_err, ok := err.(ErrorUnknownFlag)
    testing.expectf(
        t, 
        ok, 
        "Expect Error to be ErrorUnknownFlag, got %v.",
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
    parsed_err2, ok2 := err.(ErrorUnknownFlag)
    testing.expectf(
        t, 
        ok2, 
        "Expect Error to be ErrorUnknownCmd, got %v.",
        typeid_of(type_of(err))
    )

    res3, err3 :=  parse(cmds, argv)
    parsed_err3, ok3 := err.(ErrorUnknownFlag)
    testing.expectf(
        t, 
        ok3, 
        "Expect Error to be ErrorUnknownFlag, got %v.",
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
error_root_cmd_test :: proc(t: ^testing.T) {
    cmd1 :: struct {
		text: string `cli:"required"`
    }
    cmd2 :: struct {
		text: string `cli:"required"`
    }
    cmds :: union{
        cmd1,
        cmd2
    }
    argv := []string{
        os.args[0], 
    }
    res, err :=  parse(cmds, argv)
    parsed_err, ok := err.(ErrorUnknownCmd)
	log.error(err)
    testing.expectf(
        t, 
        ok, 
        "Expect Error to be ErrorUnknownCmd, got %v.",
        typeid_of(type_of(err))
    )
}

@(test)
error_value_test :: proc(t: ^testing.T) {

}
