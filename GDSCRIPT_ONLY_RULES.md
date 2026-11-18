# GDSCRIPT ONLY RULES (binding)

All game code is **GDScript 2.0 for Godot 4.7**. Not Python, not C#, not Godot 3 GDScript. GDScript looks like Python, but habits from Python cause parse errors here. This file lists the traps.

If you are unsure whether a method, property or syntax exists in Godot 4.7, **say so and ask the user to check the in-editor help (F1 / search)** instead of guessing. Never invent API names.

Exception: the existing PowerShell test runners (`fowl-play/tests/run_checks.ps1` and `fowl-play/tests/run_m0_checks.ps1`) stay PowerShell. Gameplay and Godot-side tests remain GDScript.

---

## 1. The `:=` rule (the one that has bitten this project)

`:=` means "infer the type from the right side". It only works when the compiler **knows the exact type of the right side at parse time**. When it does not, you get:
`Cannot infer the type of "x" variable because the value doesn't have a set type.`

**Rule: use `:=` only when the right side has an obviously known type. Otherwise write the type explicitly: `var x: Type = ...`. When in doubt, write the type.**

### Safe for `:=`
- Literals: `var n := 0`, `var s := "a"`, `var f := 1.5`, `var v := Vector3.ZERO`
- Constructors: `var t := Timer.new()`, `var q := PhysicsRayQueryParameters3D.create(a, b)`
- Calls to functions **with a declared return type** (yours or the engine's typed ones): `var d := a.distance_to(b)`
- Casts: `var p := node as Player`
- Typed math helpers: `clampf`, `clampi`, `minf`, `maxf`, `mini`, `maxi`, `absf`, `absi`, `lerpf`, `floori`, `ceili`, `roundi`, `signf`

### NOT safe for `:=` (use an explicit type)
| Source | Why it fails | Write instead |
|---|---|---|
| `get_node("X")`, `$X`, `get_node_or_null("X")` | returns `Node` (or Variant-ish) | `var n: Node3D = $X` or `$X as Node3D` |
| `Dictionary` access: `d["k"]`, `d.get("k")`, `d.k` | Variant | `var v: int = d["k"]` |
| Untyped `Array` element: `arr[i]`, `for x in arr` | Variant | `var e: Foo = arr[i]`, or use typed arrays `Array[Foo]` |
| `load(...)` / `ResourceLoader.load` | `Resource` | `var s: PackedScene = load("res://...")` |
| `ray.get_collider()`, `get_collider()` results | Object/Variant | `var c: Node = ray.get_collider() as Node` |
| `min(), max(), abs(), clamp(), lerp(), round(), floor()` (Variant versions) | return Variant | `minf/maxf/absf/clampf/lerpf/roundf/floorf` or the `i` variants |
| Functions with **no return type** | Variant | add `-> Type` to the function |
| `await ...` results | often Variant | explicit type |
| Ternary with mixed types: `a if c else b` | unclear type | explicit type |
| `null` | no type | `var x: Node = null` |
| Anything read from a `Variant`-typed variable | Variant | explicit type |
| `Callable.call(...)` results | Variant | explicit type |

**A cascade warning:** if a class (`class_name`) cannot be found, every `:=` that depends on it fails too, producing a wall of errors. Always read the **first** error first; fix it; re-run before touching the rest.

## 2. Typing standard (everything typed)

- Every function has typed parameters and a return type: `func hit(who: int, amount: float) -> bool:`. Use `-> void` explicitly.
- Every member and local variable has a type (explicit, or `:=` where safe).
- Use typed arrays and dictionaries where possible: `Array[int]`, `Array[Node3D]`, `Dictionary[String, int]` (verify typed dictionaries in 4.7 before relying on them).
- Typed signals: `signal state_changed(old: int, new: int)`.
- `@export var speed: float = 5.0`; exported resources typed (`@export var profile: PropProfile`).
- Use `Variant` only when truly needed and always write it: `var x: Variant`.
- No untyped `var x = ...`.
- Ask the user (EDITOR TASK card) to turn on, in Project Settings → Debug → GDScript, the warnings for untyped declarations and unsafe access, so the compiler enforces this. Do **not** enable the warning that flags `:=` usage, because we use it deliberately. Verify exact warning names in 4.7.

## 3. Python habits that break in GDScript

| Python | GDScript 4 |
|---|---|
| `def f(x):` | `func f(x: int) -> void:` |
| `None`, `True`, `False` | `null`, `true`, `false` |
| `self.x` everywhere | `self` is optional; just `x` |
| `__init__` | `_init` |
| `import module` | `preload("res://...")`, `load()`, or `class_name` |
| `f"{x} and {y}"` | `"%s and %s" % [x, y]` (single value: `"%d" % x`) |
| `print(a, b)` (works) | `print(a, " ", b)` or `print("%s %s" % [a, b])` |
| `len(x)` | `x.size()` |
| list comprehension | a `for` loop, or `.map()` / `.filter()` with lambdas |
| tuples `(a, b)` | arrays `[a, b]`, dictionaries, or a small class |
| `dict.items()` | `for k in d: var v = d[k]` (typed) |
| `try / except` | **no exceptions**; check return values, `is_instance_valid()`, `has_method()`, `is_empty()` |
| `isinstance(x, T)` | `x is T` |
| `elif`, `and`, `or`, `not` | same (and `&&`, `||`, `!` also work) |
| `str[1:3]` slicing | `s.substr(1, 2)`, `s.left(n)`, `s.right(n)` |
| `switch` (absent) | `match` |
| `@property` | `var x: int: get: ... set(v): ...` |
| `pass` | `pass` (same) |
| `a // b` | no `//`; use `floori(a / float(b))` or `a / b` (int/int truncates, produces an INTEGER_DIVISION warning; do it deliberately and avoid it where possible) |
| `x ** 2` | `pow(x, 2)` |
| `%` on floats | `fmod(a, b)` / `fposmod(a, b)` (`%` is int-only) |
| tabs/spaces mixed | **tabs only** |
| `range(a, b)` | `range(a, b)` (end exclusive, same) |
| semicolons | none |
| `lambda x: x+1` | `func(x: int) -> int: return x + 1` |
| `global x` | use an autoload or a member variable |

## 4. Godot 3 habits that break in Godot 4

| Godot 3 (do NOT use) | Godot 4 |
|---|---|
| `onready var` | `@onready var` |
| `export var` | `@export var` |
| `tool` | `@tool` |
| `yield(...)` | `await ...` |
| `connect("sig", obj, "method")` | `sig.connect(method)` |
| `emit_signal("sig")` | `sig.emit()` |
| `remote` / `puppet` / `master` / `rset` | `@rpc(...)` |
| `get_tree().network_peer` | `multiplayer.multiplayer_peer` |
| `instance()` | `instantiate()` |
| `Spatial`, `KinematicBody`, `RigidBody` | `Node3D`, `CharacterBody3D`, `RigidBody3D` |
| `rand_range` | `randf_range` / `randi_range` |
| `deg2rad`, `rad2deg` | `deg_to_rad`, `rad_to_deg` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `setget` | property `get:` / `set(v):` |
| `move_and_slide(velocity)` | set `velocity`, call `move_and_slide()` |
| `PoolVector3Array` | `PackedVector3Array` |
| `.rpc_id` argument order from docs of Godot 3 | `method.rpc_id(peer_id, args...)` |

## 5. Godot 4 specifics to always follow

- **RPC:** `@rpc("any_peer", "call_local", "reliable")` / `@rpc("authority", "call_remote", "unreliable_ordered")`. Call with `method.rpc(args)` or `method.rpc_id(id, args)`. Never RPC to yourself. Every `any_peer` RPC validates `get_remote_sender_id()`.
- **`class_name` order:** a script that uses another script's `class_name` can fail to parse if that script has not been registered yet. Where consumers load first, add `const X := preload("res://path.gd")`, and after adding scripts, ask the user to **run the import step** (reopen the editor or `--editor --import --quit`) and paste errors.
- **`@export` cannot be used on `RefCounted`-derived members.** Use a plain `var`.
- **Signals:** declare and connect with the Godot 4 forms; disconnect where lifetimes differ.
- **Lambdas capturing loop variables** capture by value in 4; still prefer named methods for anything non-trivial.
- **Nodes after `queue_free`:** check `is_instance_valid(node)` before use.
- **Replicated visuals:** keep stored node references; don't search paths on remote peers.
- **`super()`** to call the parent's overridden method (`super._ready()` form is also valid).
- **Unique names / paths:** verify node paths against the actual scene the user built; never assume.

## 6. Style

- **Tabs** for indentation. `snake_case` for variables/functions/files. `PascalCase` for `class_name`s and enums. `UPPER_SNAKE_CASE` for constants and enum members. Private members start with `_`.
- Signal names are past tense / event-like (`limp_started`, `hold_ended`).
- One `class_name` per file. Script file name = `class_name` in snake_case.
- Line length about 100 characters; wrap with parentheses.
- Comments explain **why**, not what. Units in names: `_seconds`, `_m`, `_mps`, `_hz`.
- No magic numbers; they live in the single tuning source.
- Keep functions short and single-purpose. Pure logic goes in `RefCounted` classes with no node dependencies, so it can be tested headless.

## 7. Self-check before handing over ANY code

Walk this list for every file you write:
1. Every `:=`: is the right side's type definitely known? If not, write the type.
2. Every function has parameter types and a return type.
3. No Python or Godot 3 syntax from the tables above (`None`, `f""`, `len()`, `yield`, `onready`, `connect("…")`, etc.).
4. Tabs only; no mixed indentation.
5. Every `class_name` dependency that could be parsed first is `preload`ed.
6. No invented APIs. Anything you are not sure exists in 4.7 is flagged to the user.
7. RPCs validated, no self-RPC.
8. Nothing hard-coded that belongs in the tuning source.
9. Tell the user: "Reopen/import the project, run the tests, and paste back the **first** error if any."

## 8. When there are errors

- Ask for the **complete first error** and its file/line. Fix the root cause (often one missing class or one bad inference) before the cascade.
- Do not "fix" an inference error by deleting types or switching to untyped `var`. Add the explicit type.
- If a test run reports `SCRIPT ERROR:` or `ERROR:` in its output, treat it as a failure even if the exit code is 0.
