# Tasks chooser

Allow to choose tasks and change default build command from status bar.

![Screenshot](/docs/screenshot.png)

# How it works

The idea is to be able to quickly change `.vscode/tasks.json` contents in order to bind a different command to, let's say `CMD/CTRL+SHIFT+B`.

Everything is configured from a single JSON file located at `.vscode/tasks-chooser.json` (relative to your workspace root).
You can see an example at [example/.vscode/tasks-chooser.json](https://github.com/jeremyfa/vscode-tasks-chooser/tree/master/example/.vscode/tasks-chooser.json).

When a `.vscode/tasks-chooser.json` file is provided, an item appears on the status bar allowing to choose between _items/targets_.
Everytime a target is selected, `.vscode/tasks.json` is updated accordingly.

`.vscode/tasks.json` content is computed by merging the selected `item` and it's `baseItem` (if provided) from `.vscode/tasks-chooser.json`.
`baseItem` is provided as a convenience to allow us to share keys that are identical between items without having to rewrite them for each item.

![How it works](/docs/howitworks.png)

# Commands

`tasks-chooser.reload` Reloads the `tasks-chooser.json` file and updates the status bar item.

`tasks-chooser.select` Select between available items/targets. This is the command run when clicking on the status bar item.
