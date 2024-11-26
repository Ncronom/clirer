package e2e

import "core:log"
import lib "../../src"
import "core:testing"

scmd :: struct {
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

tests :: union {
    scmd, 
}

@(test)
general_test :: proc(t: ^testing.T) {
    //parse(os.args[1:], ucmd)
    argv := []string{"scmd", "-aaa", "-bbb:hello", "-ccc:je,suis", "-eee:arg4",
        "-fff:fff2,fff3,fff2", "position1"}
    res, err := lib.parse(argv, tests)
    log.error(res)
}
