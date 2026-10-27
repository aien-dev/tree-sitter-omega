package tree_sitter_omega_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_omega "github.com/aien-dev/tree-sitter-omega/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_omega.Language())
	if language == nil {
		t.Errorf("Error loading Omega grammar")
	}
}
