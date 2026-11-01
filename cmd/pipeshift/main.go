// Command pipeshift migrates declarative Jenkinsfiles to GitHub Actions with
// per-element evidence of what is verified, what needs review and what is
// unsupported.
package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var errNotImplemented = errors.New("not implemented yet")

func newRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:           "pipeshift",
		Short:         "Migrate Jenkins pipelines to GitHub Actions with evidence-backed reports",
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	root.AddCommand(&cobra.Command{
		Use:   "analyze <Jenkinsfile>",
		Short: "Report what can be converted, without writing a workflow",
		Args:  cobra.ExactArgs(1),
		RunE:  func(*cobra.Command, []string) error { return errNotImplemented },
	})

	var outDir string
	convert := &cobra.Command{
		Use:   "convert <Jenkinsfile> -o <dir>",
		Short: "Write a GitHub Actions workflow and a report",
		Args:  cobra.ExactArgs(1),
		RunE:  func(*cobra.Command, []string) error { return errNotImplemented },
	}
	convert.Flags().StringVarP(&outDir, "output", "o", "", "output directory")
	_ = convert.MarkFlagRequired("output")
	root.AddCommand(convert)

	return root
}

func main() {
	if err := newRootCmd().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "pipeshift:", err)
		os.Exit(1)
	}
}
