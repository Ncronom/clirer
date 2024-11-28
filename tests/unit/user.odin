package unit

import "core:log"
import lib "../../src"
import "core:testing"
import "core:os"

//@(test)
//args_iterator_test :: proc(t: ^testing.T) {
//    argv := []string{os.args[0], "scmd", "-aaa", "-bbb:hello", "-ccc:je,suis", "-eee:arg4", "-fff:fff2,fff3,fff2", "position1"}
//    iter := lib.args_iterator_make(argv)
//    arg := lib.next_arg(iter)
//    for arg != nil {
//        log.error(arg)
//        arg = lib.next_arg(iter)
//    }
//}
