# *CLI* RER ✨

clirer is an Odin compiler's style command line arguments parser that let you specify how command line arguments should be parsed with simple types declarations.

> [!WARNING]
> The library is in an ALPHA state so the API could change.

## Basic usage

### Definition

```odin
package main

import "core:os"
import "core:fmt"
import "clirer"

RangeArg :: enum {
	foo,
	bar,
}

cmd :: struct { // Root command 
	// Positional arguments
	src: 		string 		`cli:"required"`,		// Position 1
	dest: 		string  	`cli:"required"`,		// Position 2

	// Named arguments
	recursive: 	bool		`cli:"r,recursive"`,	// Switch
	pattern: 	string 		`cli:"p,pattern"`,		// value
	format: 	RangeArg 	`cli:"f,format"`,		// option

	exclude: 	[8]string 	`cli:"e,exclude"`,    	// list of values
	options: 	[8]RangeArg `cli:"o,options"`,    	// options
}

main :: proc() {
	res := clirer.parse(cmd, os.args)
	fmt.println(res)
}
```

```bash
myprog -r ./pos1/arg ./pos2/arg -pattern:*.c -f:bar -o:bar,foo,bar -exclude:foo.c,bar.c
```

Root command : will be the program's name

Arg types :

- Positional arguments 	-> are strings. Name mustn't be specified. Can be optionals. The order matter.
- Named arguments 		-> can be called by their short or long name. Must have a name. Can be optionals. The order doesn't matter.
	- switch  		-> are booleans. Value mustn't be specified.
	- value 		-> are strings. Value must be specified.
	- option 		-> are enums. Value must be specified and must be one of the enum values label.
	- list 			-> are lists of strings. Values must be specified and seperated by ",".
	- options 		-> are lists of enums. Values must be specified and seperated by ",". Must be one of the enum values label.

### Help

```odin
cmd :: struct { 
	pattern: 	string `cli:"p,pattern" help:"A simple descirption for 'pattern' arg"`,
	help: bool `help:"A simple description for 'cmd' command"`
}
```

## Sub commands

You can specified sub commands with unions. Must be specified at the end of a struct

Or, you can gave union as root. 
The result is the same except you can't specified parent command flags.

```odin
cmd1 :: struct {} 
cmd2 :: struct {}
cmd3 :: struct {}

cmds :: union {
	cmd1,
	cmd2,
	cmd3,
} 

root :: struct {
	sub_cmds: cmds
}

res2 := clirer.parse(root, os.args)
// OR
res1 := clirer.parse(cmds, os.args)
```

## Mentions

This project was inspired by these amazing libraries :

- https://github.com/GoNZooo/odin-cli
- https://github.com/SjVer/ClOdin
