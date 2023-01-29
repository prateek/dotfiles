package main

import (
	"fmt"
	"io/ioutil"
	"os"

	"github.com/ankitpokhrel/jira-cli/pkg/md"
)

func main() {
	args := os.Args
	if len(args) != 2 {
		fmt.Printf("Usage: %s <filename>\n", args[0])
		os.Exit(1)
	}

	filename := args[1]
	inputFile, err := os.Open(filename)
	if err != nil {
		fmt.Printf("unable to open file: %v", err)
		os.Exit(1)
	}

	inputBytes, err := ioutil.ReadAll(inputFile)
	if err != nil {
		fmt.Printf("unable to read file: %v", err)
		os.Exit(1)
	}

	fmt.Println(md.ToJiraMD(string(inputBytes)))
}
