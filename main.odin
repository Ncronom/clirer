package cleo

import "core:fmt"
import "core:log"
import "core:os"
import "core:testing"

Foo :: struct {
	xxx: bool        `cli:"x/xxx required"`,                   // required FLAG 
	yyy: string      `cli:"y/yyy val1,val2,val3 required"`,    // required OPTIONS
	aaa: string      `cli:"a/aaa required"`,                   // required any value option
	ccc: []string    `cli:"c/ccc required"`,                   // required any multi value option
	ddd: []string    `cli:"y/yyy val1,val2,val3 required"`,    // required muli value in OPTIONS
	eee: [3]string   `cli:"e/eee val1,val2,val3 required"`,    // required exaclty 3 muli value in OPTIONS
	zzz: string      `cli:"required"`,                         // reuired first position POSITIONAL
	bbb: string      `cli:"required"`,                         // reqired second position POSITIONAL
}

@(test)
simple_flag_test :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger()
    test_def :: struct {
        x: bool `cli:"x/x"`,
        y: bool `cli:"y/y"`,
        w: string `cli:"w/www"`,
        u: string `cli:"u/uuu val1,val2,val3"`,
        a: []string `cli:"a/aaa val1,val2,val3"`,
        z: bool `cli:"z/z"`,
    }
    cmd1 := []string{"/path/to/myProg.exe", "-x", "-z", "-w:hello", "-u:val1",
        "-a:val2,val1,val3"}
    res, err := parse(cmd1[1:], test_def)
    log.debug(res)
    testing.expect_value(t, err, nil)
}
