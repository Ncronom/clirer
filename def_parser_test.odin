package clirer
import "core:log"
import "core:testing"
import "core:os"



@(test)
cmd_test :: proc(t: ^testing.T) {
    TagType :: enum{ todo, old }
    FormatType :: enum{ raw, hidden }
    cmd :: struct {
        archive:    bool                `cli:"a,archive"`,
        tags:       [8]TagType          `cli:"t,tags"`,  
        format:     FormatType          `cli:"f,format"`,
        filepath:   string,
        by:         [8]string           `cli:"b,by"`,
    }
    argv := []string{
        os.args[0], 
        "-archive", 
        "-tags:todo,old,todo",
        "path/to/the/file.ext",
        "-format:hidden",
        "-by:carenne,jean",
    }
    res, err :=  parse(cmd, argv)

    testing.expectf(
        t, 
        res.archive, 
        "Expect res.archive to be true, got %v.",
        res.archive
    )
    testing.expectf(
        t, 
        res.tags[0] == TagType.todo && 
        res.tags[1] == TagType.old && 
        res.tags[3] == TagType.todo, 
        "Expect res.tags to be [todo, old, todo], got %v.",
        res.tags[:3]
    )
    testing.expectf(
        t, 
        res.filepath == "path/to/the/file.ext", 
        "Expect res.filepath to be path/to/the/file.ext, got %v.",
        res.filepath
    )
    testing.expectf(
        t, 
        res.format == FormatType.hidden,  
        "Expect res.format to be hidden, got %v.",
        res.format
    )
    testing.expectf(
        t, 
        res.by[0] == "carenne" && res.by[1] == "jean",  
        "Expect res.by to be [carenne, jean], got %v.",
        res.by[:2]
    )
}

@(test)
sub_cmd_test :: proc(t: ^testing.T) {
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
        "cmd", 
        "-archive", 
        "-tags:todo,old,todo",
        "path/to/the/file.ext",
        "-format:hidden",
        "-by:carenne,jean",
    }
    pre_res, err :=  parse(cmds, argv)

    res, ok := pre_res.(cmd)

    testing.expectf(
        t, 
        ok, 
        "Expect res to be cmd, got %v.",
        typeid_of(type_of(res))
    )

    testing.expectf(
        t, 
        res.archive, 
        "Expect res.archive to be true, got %v.",
        res.archive
    )
    testing.expectf(
        t, 
        res.tags[0] == TagType.todo && 
        res.tags[1] == TagType.old && 
        res.tags[3] == TagType.todo, 
        "Expect res.tags to be [todo, old, todo], got %v.",
        res.tags[:3]
    )
    testing.expectf(
        t, 
        res.filepath == "path/to/the/file.ext", 
        "Expect res.filepath to be path/to/the/file.ext, got %v.",
        res.filepath
    )
    testing.expectf(
        t, 
        res.format == FormatType.hidden,  
        "Expect res.format to be hidden, got %v.",
        res.format
    )
    testing.expectf(
        t, 
        res.by[0] == "carenne" && res.by[1] == "jean",  
        "Expect res.by to be [carenne, jean], got %v.",
        res.by[:2]
    )
}

@(test)
nested_sub_cmd_test :: proc(t: ^testing.T) {
    TagType :: enum{ todo, old }
    FormatType :: enum{ raw, hidden }
    nested :: struct {
        msg:   string `cli:"m,msg"`,
    }
    cmd :: struct {
        archive:    bool                `cli:"a,archive"`,
        tags:       [8]TagType          `cli:"t,tags"`,  
        format:     FormatType          `cli:"f,format"`,
        by:         [8]string           `cli:"b,by"`,
        nested_cmds: union{
            nested 
        }
    }
    cmds :: union{
        cmd 
    }

    argv := []string{
        os.args[0], 
        "cmd", 
        "-archive", 
        "-tags:todo,old,todo",
        "-format:hidden",
        "-by:carenne,jean",
        "nested",
        "-msg:hello",
    }
    pre_res, err :=  parse(cmds, argv)

    res, ok := pre_res.(cmd)

    testing.expectf(
        t, 
        ok, 
        "Expect res to be cmd, got %v.",
        typeid_of(type_of(res))
    )

    sub_res, sub_ok := res.nested_cmds.(nested)

    testing.expectf(
        t, 
        sub_ok, 
        "Expect sub_res to be nested, got %v.",
        typeid_of(type_of(sub_res))
    )

    testing.expectf(
        t, 
        sub_res.msg == "hello", 
        "Expect sub_res.msg to be hello, got %v.",
        sub_res.msg
    )

    testing.expectf(
        t, 
        res.archive, 
        "Expect res.archive to be true, got %v.",
        res.archive
    )
    testing.expectf(
        t, 
        res.tags[0] == TagType.todo && 
        res.tags[1] == TagType.old && 
        res.tags[3] == TagType.todo, 
        "Expect res.tags to be [todo, old, todo], got %v.",
        res.tags[:3]
    )
    testing.expectf(
        t, 
        res.format == FormatType.hidden,  
        "Expect res.format to be hidden, got %v.",
        res.format
    )
    testing.expectf(
        t, 
        res.by[0] == "carenne" && res.by[1] == "jean",  
        "Expect res.by to be [carenne, jean], got %v.",
        res.by[:2]
    )
}
