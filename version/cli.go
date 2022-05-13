package version

import (
	"os"
	"reflect"
	"strings"
)

// CLI stores arguments and subcommands
type CLI struct {
	Version  VersionFlag `name:"version" help:"Print version information and quit" short:"v" type:"counter"`
	VersionC VersionCmd  `cmd:"" help:"Show the version information" name:"version" aliases:"ver" default:"true"`
}
type Context struct {
	*CLI
}

type VersionFlag int
type VersionCmd struct{}

func parseArgs() *CLI {
	res := &CLI{}
	rt := reflect.TypeOf(*res)
	veropt, shortveropt := "", ""
	vercmd, aliasvercmd := "", ""
	for i := 0; i < rt.NumField(); i++ {
		f := rt.Field(i)
		if f.Name == "Version" {
			veropt = f.Tag.Get("name")
			shortveropt = f.Tag.Get("short")
		}
		if f.Name == "VersionC" {
			vercmd = f.Tag.Get("name")
			aliasvercmd = f.Tag.Get("aliases")
		}
	}
	for i := 1; i < len(os.Args); i++ {
		anArg := os.Args[i]
		opt := strings.TrimLeft(anArg, "-")
		if opt == veropt || opt == shortveropt || opt == vercmd || opt == aliasvercmd {
			res.Version = res.Version + 1
		}
		// fmt.Printf("opt=%s, shortveropt='%s'\n", opt, shortveropt)
		if len(opt) > 1 && opt == strings.Repeat(shortveropt, len(opt)) {
			res.Version = res.Version + VersionFlag(len(opt))
		}
	}
	return res
}
