#+private
package clirer

Config :: struct {
    description:    string,
    epilog:         string,
    legacy:         bool,
    help:           bool,
}

DEFAULT_CONFIG :: Config {
    description = "",
    epilog      = "For further details on a command, invoke command help",
    help        = true,
    legacy      = false,
}

current_config := Config{}
