package cleo

import "core:fmt"
import "core:log"
import "core:slice"
import "core:mem"
import "core:strings"
import "core:os"
import "core:testing"


test_def :: struct {
    x: bool `cli:"x/x"`,
    y: bool `cli:"y/y"`,
    w: string `cli:"w/www"`,
    bbb: string `cli:"required"`,                         // reqired second position POSITIONAL
    u: string `cli:"u/uuu val1,val2,val3"`,
    a: [3]string `cli:"a/aaa val1,val2,val3"`,
    z: bool `cli:"z/z"`,
    zzz: string `cli:"required"`,                         // reuired first position POSITIONAL
}


// E2E Tests
@(test)
positional_arg_test :: proc(t: ^testing.T) {
    test_pos :: struct {
        x: string,
        y: string
    }
    cmd1 := []string{"/path/to/myProg.exe", "positionX", "positionY"}
    res_test_pos, err_test_pos := parse(cmd1[1:], test_pos)
    testing.expect_value(t, err_test_pos, nil)
    testing.expect_value(t, res_test_pos.x, "positionX")
    testing.expect_value(t, res_test_pos.y, "positionY")

    test_pos_inverted :: struct {
        y: string,
        x: string,
    }
    res_test_pos_inverted, err_test_pos_inverted := parse(cmd1[1:], test_pos_inverted)
    testing.expect_value(t, err_test_pos_inverted, nil)
    testing.expect_value(t, res_test_pos_inverted.y, "positionX")
    testing.expect_value(t, res_test_pos_inverted.x, "positionY")


    test_pos_required :: struct {
        x: string ,
        y: string `cli:"required"`,
    }
    cmd1 = []string{"/path/to/myProg.exe", "positionX"}
    res_test_pos_required, err_test_pos_required := parse(cmd1[1:], test_pos_required)
    _, ok := err_test_pos_required.(MissingFieldError)
    //testing.expect_value(t, res_test_pos_required, nil)
    testing.expect_value(t, ok, true)
}
