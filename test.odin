package cleo

import "core:fmt"
import "core:log"
import "core:slice"
import "core:mem"
import "core:strings"
import "core:os"
import "core:testing"



@(test)
help_test :: proc(t: ^testing.T) {
    subcmd :: struct {
        xxx: bool `cli:"x|xxx"`,
        yyy: bool `cli:"y|yyy"`,
    }
    subcmd2 :: struct {
        zzz: bool `cli:"z|zzz"`,
        www: bool `cli:"w|www"`,
        aaa: bool `cli:"a|aaa"`,
    }
    cmd :: struct {
        subcmd: union {
            subcmd,
            subcmd2,
        },
        //arg1: bool `cli:"a1|arg1"`,
        //arg2: bool `cli:"a2|arg2"`,
    }
    cmd1 := []string{"/path/to/myProg.exe", "subcmd2", "-zzz"}
    res, err := parse(cmd1[1:], cmd)
    //testing.expect_value(t, ok, true)
}


// E2E Tests
//@(test)
//positional_arg_test :: proc(t: ^testing.T) {
//    test_pos :: struct {
//        x: string,
//        y: string
//    }
//    cmd1 := []string{"/path/to/myProg.exe", "positionX", "positionY"}
//    res_test_pos, err_test_pos := parse(cmd1[1:], test_pos)
//    log.debug(res_test_pos)
//    testing.expect_value(t, err_test_pos, nil)
//    testing.expect_value(t, res_test_pos.x, "positionX")
//    testing.expect_value(t, res_test_pos.y, "positionY")
//
//    test_pos_inverted :: struct {
//        y: string,
//        x: string,
//    }
//    res_test_pos_inverted, err_test_pos_inverted := parse(cmd1[1:], test_pos_inverted)
//    testing.expect_value(t, err_test_pos_inverted, nil)
//    testing.expect_value(t, res_test_pos_inverted.y, "positionX")
//    testing.expect_value(t, res_test_pos_inverted.x, "positionY")
//
//
//    test_pos_required :: struct {
//        x: string ,
//        y: string `cli:"required"`,
//    }
//    cmd1 = []string{"/path/to/myProg.exe", "positionX"}
//    res_test_pos_required, err_test_pos_required := parse(cmd1[1:], test_pos_required)
//    _, ok := err_test_pos_required.(MissingFieldError)
//    //testing.expect_value(t, res_test_pos_required, nil)
//    testing.expect_value(t, ok, true)
//}
//
//
//@(test)
//help_test :: proc(t: ^testing.T) {
//    context.logger = log.create_console_logger()
//    test_switch_flag :: struct {
//        y: bool `cli:"y|yyy"`,
//        x: bool `cli:"x|xxx"`,
//        z: string `cli:"z|zzz"`,
//        w: string `cli:"w|www,<option>,[var1|var2|var3],required,'This is a test, you can choose an option'"`,
//    }
//    cmd1 := []string{"/path/to/myProg.exe", "positionX"}
//    res_test_pos_required, err_test_pos_required := parse(cmd1[1:], test_switch_flag)
//}


