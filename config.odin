package clirer

Config :: struct {
    description:    string,
    epilog:         string,
    legacy:         bool,
    help:           bool,
}

@private
DEFAULT_CONFIG :: Config {
    description = "",
    epilog      = "For further details on a command, invoke command help",
    help        = true,
    legacy      = false,
}

@private
current_config := Config{}
