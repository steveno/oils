"""
typed_arith_abbrev.py - Abbreviations for pretty-printing typed_arith.asdl.
"""

from asdl import runtime

def _arith_expr__Unary(obj):
  # type: (arith_expr__Unary) -> Optional[runtime.PrettyNode]

  p_node = runtime.PrettyNode('U')
  p_node.abbrev = True
  n = runtime.PrettyLeaf(str(obj.op), color_e.StringConst)
  p_node.unnamed_fields.append(n)
  p_node.unnamed_fields.append(obj.a.AbbreviatedTree())  # type: ignore
  return p_node


def _arith_expr__Binary(obj):
  # type: (arith_expr__Binary) -> Optional[runtime.PrettyNode]

  if obj.op == '=':  # test for fallback
    return None

  p_node = runtime.PrettyNode('B')
  p_node.abbrev = True
  n = runtime.PrettyLeaf(str(obj.op), color_e.StringConst)
  p_node.unnamed_fields.append(n)
  p_node.unnamed_fields.append(obj.left.AbbreviatedTree())  # type: ignore
  p_node.unnamed_fields.append(obj.right.AbbreviatedTree())  # type: ignore
  return p_node


def _arith_expr__Const(obj):
  # type: (arith_expr__Const) -> Optional[runtime.PrettyNode]
  p_node = runtime.PrettyNode(None)
  p_node.abbrev = True
  n = runtime.PrettyLeaf(str(obj.i), color_e.OtherConst)
  p_node.unnamed_fields.append(n)
  return p_node


def _arith_expr__Var(obj):
  # type: (arith_expr__Var) -> Optional[runtime.PrettyNode]
  p_node = runtime.PrettyNode('$')
  p_node.abbrev = True
  n = runtime.PrettyLeaf(str(obj.name), color_e.StringConst)
  p_node.unnamed_fields.append(n)
  return p_node

