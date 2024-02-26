Up to 4 Pretty Printers?
========================

Date: 2024-02

## Intro 

Oils has a LOT of text parsing, and it's becoming apparent than we also need a
lot printing too!

And a shell is a user interface, so the printed text has to be reasonably
formatted.

---

This doc describes 4 possible pretty printers in Oils.  (Traditional shells
don't have appear to have **any** pretty printing.)

I'm writing it organize my thoughts -- particularly to explain the problem
requirements to contributors.

Note: sometimes I pile on too many requirements, which I mentioned in the
latest release announcement:

- <https://www.oilshell.org/blog/2024/02/release-0.20.0.html#zulip-why-am-i-working-on-json>

## Background

There are at least two schools of thought on pretty printers, which are
discussed in this lobste.rs thread:

- <https://lobste.rs/s/aevptj/why_is_prettier_rock_solid>
- HN comments on same story: <https://news.ycombinator.com/item?id=39437424>
  - (Top comment reveals why pretty-printing is hard - users are opinionated,
    and it can be **slow**.)

More here:

- <https://lobste.rs/s/1r0aak/twist_on_wadler_s_printer>

Let's call them the `go fmt` style and the "functional pretty pretty language"
or PPL style.

I'm probably "biased" toward `go fmt`, as the two formatters we actually
**use** in Oils are influenced by it (although importantly, they add line wrapping):

- `clang-format` for our C++ code.  This is the best formatter I've used.
- `yapf` for our Python code.  It is intentionally a "clone" for `clang-format`.

These could also be called formatters that use the "graph search" paradigm, but
that describes what they do for **line wrapping**, which I think of as a
**subset** of pretty printing.

There are also a bunch of Zulip threads where I "took notes" on pretty printing:

- TODO

---

However, the PPL style is appealing for a few reasons:

- There's really no "user layout" for data structures like JSON (untyped) and
  Zephyr ASDL (typed).  So a layout can be synthesized from scratch.
- I think we should use PPL for the **expression subproblem** of a shell
  formatter (OSH, YSH, or ideally both).
- The PPL style separates policy (language rules) and mechanism (line
  wrapping), and we have multiple languages to format.  So we should try this
  more principled architecture, hopefully without sacrificing quality for
  particular langauges.

## Summary of Four Formatters

(1) YSH data, which are dynamically typed JSON-like values

**Motivation**: We should look as good as `node.js` or `jq`.  TODO: add
screenshots.

(2) Replace the existing Zephyr ASDL pretty printer 

The algorithm is in `asdl/format.py`, and the code is in `asdl/hnode.asdl`.
This is an ad hoc line wrapper which I wrote several years ago.  TODO: I
believe it can be very slow, measure it.

The slowness didn't really matter because it's not user facing -- this format
is only debugging Oils itself.  But it's very useful, and we may want to expose
it to users.

**Motivation**: We already wrote an ad hoc pretty printer!  It seems like this
should "obviously" be unified

(3) Export the Oils Syntax Tree with "NIL8"  (data)

**Motivations**:

- Expose a stable format for users.  They should be able to reuse all the hard
  work we did on parsing shell.
- Is NIL8 a good idea?
  - NIL8 Isn't Lisp
  - Narrow Intermediate Language
- We also plan to use NIL8 as a WebAssembly-text-format-like IR for

Note: the graph has layers like this:

1. `source_t` describes whether shell code comes from `foo.sh` or `ysh -c 'echo mycode'`
2. `SourceLine` represents physical lines
3. `Token` represents portions of lines
4. Then we have the Lossless Syntax Tree of `command_t word_t word_part_t
   expr_t`

### Order of implementation

It makes sense to do (1) and then (2).

(3) and (4) can be done in any order, or not at all.

Note: The first two printers are "engineering", but (3) and (4) are more
**experimental**.  Especially (3).

## Notes

Notes on unifying pretty printing for 

- dynamically typed YSH values 
- statically typed ASDL values (mycpp, yaks)

## Dynamically Typed YSH Values

Similar to JSON / JSON8 printing, except we 

1. count references, and then print `...` instead of repeating
1. line wrap
1. assign colors
   - for atoms, and possibly for balanced parens, to make it more readable

### Step 1: Count References

This is a global pass that computes a Dict[int, int]

    object ID -> number of times referenced in the graph

The graph is specified by single root node, e.g. the argument to

    pp line (obj)

Pass this dict into the second step.

### Step 2: Convert To Homogeneous Representation

    value.List   -> hnode.Compound with []
    value.Dict   -> hnode.Compound with {}

    null, true, false -> Atom
    Cycle detected -> Atom, with { --- 4beef2 }
                                 [ --- 4beef2 ]

Repetition:

    { key: { ... 4beef2 }, key2: { ... 4beef2 }

Or maybe omit the type, since strings don't have that

    { key: ... 4beef2, key2: ... 4beef2 }

I guess you can do sharing

### hnode Schema

The schema looks like this now?

    hnode = 
      Atom(str s, color color) - # External objects can use this?
    | Compound(hnode* items)

The length of 'str s' is the input to line wrapping.

### Step 3: Figure out what's on each line

TODO: what's the heuristic here?  Is it global?

Dynamic programming?

do we insert hnode.Newline() or something?

## Statically Typed ASDL Data

Reduce it to the case above.

### Step 1 - Ref Counting / Cycle Detection?

We do this all at once?

Because to convert to value.Record, you have to do cycle detection anyway.

And that's similar to ref counting.

### Step 2 - ASDL records -> value.Record

    value = 
        ...
      | Record(str type_name, Dict[str, value_t] fields)

The special "-" key can be used for JSON:

    {"-": "command.Simple, "name": "hi"}

Though this loses some information, and it doesn't solve the problem with
shared references.  We would need Packle for that.

### Step 2a: Optional Abbreviation?

Is this separate?  Or part of step 2.

We need something between value.Record and hnode.Compound
to do ABBREVIATION:

- Abbreviate type name, or omit it
- Omit some field names (requires schema to record it)
- Change () to <>

Also need nodes for

- ... means already printed
- --- means CANNOT print, because it's a cycle
- @1f23 - ID if already printed, or in a cycle

### Step 3 and 4 - Homogeneous Representation, Line Wrapping

Identical to the dynamically typed case above.


## TODO

- Fix ADSL cycle bug
  - Fix it in C++
  - Maybe get rid of TraversalState in Python -- seems like it can just be a dict
  - we are not going to parse this format
    - we do not want to deal with `-->` cycles and `...` omitting
    - instead we are going to manually traverse it so there are no cycles!
    - It will be more imperative.  It will be either NIL8 or TYG8

- Do we need ASDL ref counts?
  - because the thing is long. to fix bin/osh -n
  - I think that WORD WRAPPING is more important, and will help.

- Components
  - separate parser for TYG8
  - j8.PrettyPrinter -> new hnode representation
  - ASDL PrettyTree() -> new hnode representation
  - ASDL AbbreviatedTree() -> new hnode representation
    - need to figure out if we want abbreviations in C++
    - it's more readable

- Write separate parser for TYG8
  - no commas, no JSON8, just () and []
    - (unquotedyaks unquotedjs:value) and [value value]
    - unquotedyaks 
      - well to be honest this is probably SUGAR
      - so Yaks is different than ASDL
        - ASDL does have module.Type, but it doesn't need to be parsed
          differently
      - reader macro
        - `module::Type`  to  (:: module 'Type')
        - `obj->method`   to  (-> obj 'method')
        - `obj.method`    to  (. obj 'field')

  - but is it for ASDL?  or is it for Yaks?
  - is it worth unifying these things?

- In both JSON8 and TYG8
  - allow comments
  - allow unquoted identifiers
    - for TYG8 field names
    - we need a different LEXER for reader macros
      - recognize . -> :: etc.
      - just like WASM text format, there are some syntax affordances, like
        i32.local

- maybe change = operator and pp line (x) to use new pretty printer?

- come up with new hnode.asdl
  - Is it just Compound and Atom?
  - ObjectCycle is an atom, etc.
