## How does a refactoring look like?

Refactorings in Haskell-tools are monadic functions that take a syntax tree (AST) and return a modified version of that tree. The framework guarantees that only the source code of the changed syntax tree elements will be modified, so formatting and comments will not be lost.

One important decision when writing a refactoring is whether we want to refactor elements in a selection or we want to refactor a whole module, package or project.

If we want to create a refactoring that changes only one module, we can create a [local refactoring](https://github.com/haskell-tools/haskell-tools/blob/master/src/refactor/Language/Haskell/Tools/Refactor/Utils/Monadic.hs) otherwise we must create an ordinary refactoring. Of course if we don't need the monadic effects, we can define a pure function that works on the AST and call `return` to create a local or regular refactoring.

You should also check the general [development tips](general-tips.md).

## How to access the part of a large AST?

When you try to create a refactoring, most likely you only want to change small parts of the AST. To access them you have two options.

If you want to change AST fragments that are located at a particular place in the AST and not on a very deep level, you can use references to access that part.

For example, to replace data type definitions with newtype definitions wherever possible, you can use the `modDecl & annList` reference, that accesses each declaration in the module. See the whole source code of the transformation [here](https://github.com/haskell-tools/haskell-tools/blob/master/src/experimental-refactorings/Language/Haskell/Tools/Refactor/Builtin/DataToNewtype.hs).

[The API documentation for the complete list of references](https://www.stackage.org/haddock/nightly/haskell-tools-ast/Language-Haskell-Tools-AST-References.html)

[Check out the reference tutorial](https://github.com/nboldi/references/wiki/References-Tutorial)

On the other hand, if the AST elements you want to change can be found at multiple levels of the AST, it would be inconvenient to select each possible location with references. In these cases you can use generics to select all possible location where an AST element of a given type can appear.

For example, replace an if statement on the right-hand side of a binding with a function guard. The problem is that bindings can be local, so they can appear on different levels of the AST. But we can use the generic reference `nodesContaining sp` that selects the AST elements that contain the current selection. If we apply a function to that reference that has `ValueBind dom -> ValueBind dom` type, it will select all bindings contain the current selection. By checking the right-hand sides of these bindings, we can check to which one can be the subject of the refactoring. See the whole source code of the transformation [here](https://github.com/haskell-tools/haskell-tools/blob/master/src/experimental-refactorings/Language/Haskell/Tools/Refactor/Builtin/IfToGuards.hs).

 - `biplateRef` is the most general way to use generics, it is a reference for all elements contained in an AST node.
 - `nodesContaining` gets all the nodes that contain a given selection
 - `nodesContained` gets all the nodes that are contained in a given selection

### What are these AST elements?

The Haskell syntax tree is quite complex with all the language features and extensions. See the [latest specification](https://www.haskell.org/onlinereport/haskell2010/) and the [GHC documentation](http://downloads.haskell.org/~ghc/latest/docs/html/users_guide/index.html) for the use of specific language elements. We grouped the AST elements into groups based on which part of the language they are related to. You can find these categories in different parts of the framework, at both representation, transformation, generation and pattern matching of elements. The groups are:

 - Modules (module heads, exports, imports, file- and module-level pragmas),  
 - Declarations (top-level declarations, like types and classes)
 - Bindings (function and value bindings, pattern matching)
 - Types (user types, contexts)
 - Kinds (including promoted kinds)
 - Expressions (simple expressions, pattern matching, arrow-commands)
 - Statements (do-notation, list comprehensions)
 - Patterns (simple patterns, record field matching)
 - Names (normal names and operators, qualified names and their parts)

[The complete list of the different types of AST elements](https://www.stackage.org/haddock/nightly/haskell-tools-ast/Language-Haskell-Tools-AST.html)

The AST elements are annotated with semantic and source-related information. The API we present here hides this complexity behind the definitions for generation and pattern matching or the references for accessing parts of the AST.

## How to pattern match on elements?

You can use the pattern synonyms we provide to pattern match on different AST elements. For example if you want to transform infix expressions, you can pattern match on `InfixApp rhs operator lhs`.

[Check out pattern synonyms for different elements](https://www.stackage.org/haddock/nightly/haskell-tools-rewrite/Language-Haskell-Tools-AST-Match.html)

## Generating parts of the AST

Each function that generates an AST element has the  defined above to generate parts of the AST. So if you have `lhs` and `rhs` expressions, and `operator`, you can construct an infix expression with `mkInfixApp rhs operator lhs`.

[Check out generator functions for different elements](https://www.stackage.org/haddock/nightly/haskell-tools-rewrite/Language-Haskell-Tools-AST-Gen.html)

## How to check semantic constraints?

We annotate our AST representation with both syntactic and semantic information to make refactoring possible. The collection of the semantic informations added to a given AST is the domain of the AST. The domain decides which AST elements have semantic annotation and what will be the type of these annotations.

The domain of an AST depends on how far GHC can progress with the compilation of the module. If the module is type-correct, its domain will be `IdDom`, if it can be renamed but it is not type correct, its domain will be `Dom Name`, if the module can be parsed but cannot be renamed, the domain will be `Dom RdrName`.

It is likely that you need to constraint the domain for your transformation to provide some kinds of semantic information for the refactoring. The constraints you can use and the functions to access the semantic information are listed in the [`SemaInfoClasses`](https://www.stackage.org/haddock/nightly/haskell-tools-ast/Language-Haskell-Tools-AST-SemaInfoClasses.html) module.

Semantic information is stored in the AST nodes. The semantic information we currently have:

 - The unique name for `QualifiedName` elements.
 - An `isDefined` flag that tells if the current occurrence of a name defines the meaning of that name for `QualifiedName` elements.
 - The list of definitions that are in scope for `QualifiedName` elements and `Expr` elements.
 - The name of the imported module for `ImportDefinition` elements.
 - The list of actually imported definition for `ImportDefinition` elements.
 - The list of possibly imported definition for `ImportDefinition` elements (not considering hiding or explicit import).
 - The module name is available for `Module` elements.
 - A `defIsBootModule` flag that tells if a module is a hs-boot module is available for `Module` elements.
 - A list of implicitely imported names (Prelude) is available for `Module` elements.
 - A list of fields and associated values is available for `FieldWildcard` elements.

## How to run the generated refactoring?

The [`tryRefactor` function](https://github.com/haskell-tools/haskell-tools/blob/master/src/refactor/Language/Haskell/Tools/Refactor/Prepare.hs) provides an easy way to test the defined refactoring. The daemon is parameterized with a set of refactorings, so if you add your refactoring here, you can use it in your editor.

## How to add monadic effects to the transformation?

The transformation can be easily extended by monadic effects. For example, see the [dollar application](https://github.com/haskell-tools/haskell-tools/blob/master/src/experimental-refactorings/Language/Haskell/Tools/Refactor/Builtin/DollarApp.hs) example to see how a mutable state can be added to a transformation.

## How to change elements with multiplicity?

Not every element has single children in an AST, for example, there can be multiple definitions in a module and it may or may not contain a module head (optional element). In the [Utils.Lists](https://github.com/haskell-tools/haskell-tools/blob/master/src/refactor/Language/Haskell/Tools/Refactor/Utils/Lists.hs) module there are some useful functions for changing AST elements with multiplicity, for more information, see the documentation.

## How to import the definitions that I generate?

If you work in the `LocalRefactor` monad, you can ask the framework to automatically import the definitions that you use in the changed AST. To do this, use the [`referenceName`](https://github.com/haskell-tools/haskell-tools/blob/master/src/refactor/Language/Haskell/Tools/Refactor/Utils/Monadic.hs) and [`referenceOperator`](https://github.com/haskell-tools/haskell-tools/blob/master/src/refactor/Language/Haskell/Tools/Refactor/Utils/Monadic.hs) functions.

## Where to get help?

If stuck, check out the [built-in refactorings](https://github.com/haskell-tools/haskell-tools/tree/master/src/builtin-refactorings/Language/Haskell/Tools/Refactor/Builtin), where you can find many useful examples on how to define refactorings.
