# Graph Report - HabitTable_1  (2026-09-28)

## Corpus Check
- Corpus is ~6,405 words - fits in a single context window. You may not need a graph.

## Summary
- 207 nodes · 386 edges · 11 communities
- Extraction: 95% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Progress Levels & Fonts
- App Entry & Habit Model
- Progress Tests
- Habit Editor Sheet
- Week Matrix Table
- Progress Calculation Rules
- Project Docs & To-do Spec
- Lawn Grass View
- Design Decisions & CI
- Habit Board Screen
- Check Cell States

## God Nodes (most connected - your core abstractions)
1. `HabitProgressTests` - 18 edges
2. `Habit` - 16 edges
3. `HabitBoardView` - 16 edges
4. `HabitEditorView` - 15 edges
5. `ProgressLevel` - 14 edges
6. `HabitProgress` - 11 edges
7. `LawnView` - 11 edges
8. `LawnCell` - 11 edges
9. `WeekMatrixView` - 11 edges
10. `CheckCell` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Habit Table README` --semantically_similar_to--> `Habit Table project`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md
- `TodoProgress.sorted and TodoSortable` --semantically_similar_to--> `HabitSchedulable protocol`  [INFERRED] [semantically similar]
  docs/superpowers/specs/2026-09-28-todo-design.md → CLAUDE.md
- `TodoProgress.sorted and TodoSortable` --semantically_similar_to--> `HabitProgress (pure calculation rules)`  [INFERRED] [semantically similar]
  docs/superpowers/specs/2026-09-28-todo-design.md → CLAUDE.md
- `Simulator screenshot step (light/dark)` --conceptually_related_to--> `Light mode fixed (dark mode unimplemented)`  [AMBIGUOUS]
  .github/workflows/ios.yml → CLAUDE.md
- `Next feature candidates (week nav, To-do, notifications, dark mode)` --references--> `To-do feature design spec`  [INFERRED]
  CLAUDE.md → docs/superpowers/specs/2026-09-28-todo-design.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **CI build pipeline (workflow, XcodeGen, project.yml)** — github_workflows_ios_yml_ios_build_screenshot_workflow, github_workflows_ios_yml_xcodegen, project_yml_xcodegen_config, project_yml_habittabletests_target [EXTRACTED 0.95]
- **To-do feature components** — docs_superpowers_specs_2026_09_28_todo_design_todoitem, docs_superpowers_specs_2026_09_28_todo_design_todolistview, docs_superpowers_specs_2026_09_28_todo_design_todoeditorview, docs_superpowers_specs_2026_09_28_todo_design_todoprogress, docs_superpowers_specs_2026_09_28_todo_design_tabview [EXTRACTED 0.95]

## Communities (11 total, 0 thin omitted)

### Community 0 - "Progress Levels & Fonts"
Cohesion: 0.08
Nodes (24): CoreText, Equatable, .header, ProgressLevel, full, future, high, low (+16 more)

### Community 1 - "App Entry & Habit Model"
Cohesion: 0.10
Nodes (15): App, DayKey, HabitSchedulable, Calendar, Date, HabitTableApp, .body, SampleData (+7 more)

### Community 2 - "Progress Tests"
Cohesion: 0.19
Nodes (7): HabitTable, HabitProgressTests, Date, Int, TestHabit, XCTest, XCTestCase

### Community 3 - "Habit Editor Sheet"
Cohesion: 0.13
Nodes (17): Content, ContentView, .body, HabitEditorView, .body, .canSave, .trimmedName, Bool (+9 more)

### Community 4 - "Week Matrix Table"
Cohesion: 0.16
Nodes (18): Habit, Int, String, .body, CheckCell, .body, .shape, DayHeader (+10 more)

### Community 5 - "Progress Calculation Rules"
Cohesion: 0.29
Nodes (9): Foundation, H, AppCalendar, DayProgress, HabitProgress, Bool, Calendar, Date (+1 more)

### Community 6 - "Project Docs & To-do Spec"
Cohesion: 0.20
Nodes (16): DayKey (integer date key), Habit Table project, HabitProgress (pure calculation rules), HabitSchedulable protocol, Next feature candidates (week nav, To-do, notifications, dark mode), Workflow: design, approve, implement one feature at a time, This-week habit table (WeekMatrixView), Independence of To-do from Habit (+8 more)

### Community 7 - "Lawn Grass View"
Cohesion: 0.15
Nodes (14): LawnCell, .levelDescription, .shape, LawnView, .body, .dates, .legend, .percentText (+6 more)

### Community 8 - "Design Decisions & CI"
Cohesion: 0.16
Nodes (15): Lawn (jandi) 4-week view, Light mode fixed (dark mode unimplemented), No-Mac constraint: verify via GitHub Actions, Spoqa Han Sans Neo font, Theme color tokens and green palette, Fetch fonts step (spoqa-han-sans npm), iOS Build & Screenshot workflow, Simulator screenshot step (light/dark) (+7 more)

### Community 9 - "Habit Board Screen"
Cohesion: 0.15
Nodes (14): EditorTarget, edit, .habit, .id, new, HabitBoardView, .displayedDate, .emptyCard (+6 more)

### Community 10 - "Check Cell States"
Cohesion: 0.40
Nodes (5): CellState, done, future, missed, rest

## Ambiguous Edges - Review These
- `Simulator screenshot step (light/dark)` → `Light mode fixed (dark mode unimplemented)`  [AMBIGUOUS]
  .github/workflows/ios.yml · relation: conceptually_related_to

## Knowledge Gaps
- **38 isolated node(s):** `XCTest`, `HabitTable`, `.displayedDate`, `.weekTitle`, `.rangeText` (+33 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 66 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Simulator screenshot step (light/dark)` and `Light mode fixed (dark mode unimplemented)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `HabitBoardView` connect `Habit Board Screen` to `Progress Levels & Fonts`, `App Entry & Habit Model`, `Habit Editor Sheet`, `Week Matrix Table`, `Progress Calculation Rules`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **Why does `Habit` connect `Week Matrix Table` to `App Entry & Habit Model`, `Habit Editor Sheet`, `Habit Board Screen`, `Lawn Grass View`?**
  _High betweenness centrality (0.120) - this node is a cross-community bridge._
- **Why does `ProgressLevel` connect `Progress Levels & Fonts` to `Progress Calculation Rules`, `Lawn Grass View`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Habit` (e.g. with `.body` and `.insert()`) actually correct?**
  _`Habit` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `XCTest`, `HabitTable`, `.displayedDate` to the rest of the system?**
  _38 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Progress Levels & Fonts` be split into smaller, more focused modules?**
  _Cohesion score 0.0812807881773399 - nodes in this community are weakly interconnected._