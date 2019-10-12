"""
ssyntax_abbrev.py - Abbreviations for pretty-printing syntax.asdl.
"""

from _devbuild.gen.id_kind_asdl import Id
from asdl import runtime


def _AbbreviateToken(tok, out):
  # type: (token, List[runtime._PrettyBase]) -> None
  if tok.id != Id.Lit_Chars:
    n1 = runtime.PrettyLeaf(tok.id.name, color_e.OtherConst)
    out.append(n1)

  n2 = runtime.PrettyLeaf(tok.val, color_e.StringConst)
  out.append(n2)


def _token(obj):
  # type: (token) -> PrettyNode
  p_node = runtime.PrettyNode('')  # don't show node type
  p_node.abbrev = True

  p_node.left = '<'
  p_node.right = '>'
  _AbbreviateToken(obj, p_node.unnamed_fields)
  return p_node


def _speck(obj):
  # type: (speck) -> PrettyNode
  """Always abbreviate a speck as the Id."""
  p_node = runtime.PrettyNode('')  # don't show node type
  p_node.abbrev = True

  n1 = runtime.PrettyLeaf(obj.id.name, color_e.OtherConst)
  p_node.unnamed_fields.append(n1)
  return p_node


def _double_quoted(obj):
  # type: (double_quoted) -> PrettyNode
  if obj.left.id != Id.Left_DoubleQuote:
    return None  # Fall back on obj._AbbreviatedTree()

  p_node = runtime.PrettyNode('DQ')
  p_node.abbrev = True

  for part in obj.parts:
    p_node.unnamed_fields.append(part.AbbreviatedTree())
  return p_node


def _single_quoted(obj):
  # type: (single_quoted) -> PrettyNode

  # Only abbreviate 'foo', not $'foo\n'
  if obj.left.id != Id.Left_SingleQuoteRaw:
    return None  # Fall back on obj._AbbreviatedTree()

  p_node = runtime.PrettyNode('SQ')
  p_node.abbrev = True

  for token in obj.tokens:
    p_node.unnamed_fields.append(token.AbbreviatedTree())
  return p_node


def _simple_var_sub(obj):
  # type: (simple_var_sub) -> PrettyNode
  p_node = runtime.PrettyNode('$')
  p_node.abbrev = True
  _AbbreviateToken(obj.token, p_node.unnamed_fields)
  return p_node


def _braced_var_sub(obj):
  # type: (braced_var_sub) -> PrettyNode
  p_node = runtime.PrettyNode('${')
  if obj.prefix_op or obj.bracket_op or obj.suffix_op:
    return None  # we have other fields to display; don't abbreviate

  p_node.abbrev = True
  _AbbreviateToken(obj.token, p_node.unnamed_fields)
  return p_node


def _word_part__Literal(obj):
  # type: (word_part__Literal) -> PrettyNode
  p_node = runtime.PrettyNode('')  # don't show node type
  p_node.abbrev = True

  _AbbreviateToken(obj.token, p_node.unnamed_fields)
  return p_node


def _word__Compound(obj):
  # type: (word__Compound) -> PrettyNode
  p_node = runtime.PrettyNode('')  # don't show node type
  p_node.abbrev = True
  p_node.left = '{'
  p_node.right = '}'

  for part in obj.parts:
    p_node.unnamed_fields.append(part.AbbreviatedTree())
  return p_node


def _command__Simple(obj):
  # type: (command__Simple) -> PrettyNode
  p_node = runtime.PrettyNode('C')
  if obj.redirects or obj.more_env or obj.block:
    return None  # we have other fields to display; don't abbreviate

  p_node.abbrev = True

  for w in obj.words:
    p_node.unnamed_fields.append(w.AbbreviatedTree())
  return p_node


def _expr__Var(obj):
  # type: (expr__Var) -> PrettyNode
  p_node = runtime.PrettyNode('Var')
  p_node.abbrev = True

  assert obj.name.id == Id.Expr_Name, obj.name
  n1 = runtime.PrettyLeaf(obj.name.val, color_e.StringConst)
  p_node.unnamed_fields.append(n1)
  return p_node


def _expr__Const(obj):
  # type: (expr__Const) -> PrettyNode
  p_node = runtime.PrettyNode('Const')
  p_node.abbrev = True

  tok = obj.c
  out = p_node.unnamed_fields

  n1 = runtime.PrettyLeaf(tok.id.name, color_e.OtherConst)
  out.append(n1)

  n2 = runtime.PrettyLeaf(tok.val, color_e.StringConst)
  out.append(n2)
  return p_node
