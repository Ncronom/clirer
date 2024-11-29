package e2e

import "core:log"
import lib "../../src"
import "core:testing"
import "core:os"

scmd_full :: struct {
    aaa: bool   `cli:"a,aaa"`,
    bbb: string `cli:"b,bbb"`,
    ccc: [3]string `cli:"c,ccc"`,
    ddd: string,
    eee: enum {
        arg1,
        arg2
    }`cli:"e,eee"`,
    fff: [3]enum {
        fff1, 
        fff2,
        fff3
    }`cli:"f,fff"`,
    help: bool   `help:"This is a test command.
                Exemples: blablalbla"`,
}

tests_full :: union {
    scmd, 
}


subcmd :: struct {
    aaa: bool   `cli:"a,aaa"`,
}

sub :: union {
    subcmd, 
}

scmd :: struct {
    lll: bool   `cli:"l,lll/required"`,
    s: union {
        subcmd, 
    }

}

tests :: union {
    scmd, 
}

// - [ ] check nil arg from iterator
// - [x] union named type not always working

@(test)
general_test :: proc(t: ^testing.T) {
    //parse(os.args[1:], ucmd)
    //argv := []string{os.args[0], "scmd", "-aaa", "-bbb:hello", "-ccc:je,suis", "-eee:arg4", "-fff:fff2,fff3,fff2", "position1"}
    argv := []string{os.args[0], "scmd", "-lll", "subcmd"}
    res := lib.parse(tests, argv)
    //log.error(res)
}
