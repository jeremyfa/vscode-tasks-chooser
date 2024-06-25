package;

import haxe.Json;
import haxe.io.Path;
import js.node.ChildProcess;
import sys.io.File;
import vscode.ExtensionContext;
import vscode.FileSystemWatcher;
import vscode.StatusBarItem;

class TasksChooser {

/// Exposed

    static var instance:TasksChooser = null;

    @:expose("activate")
    static function activate(context:ExtensionContext) {

        instance = new TasksChooser(context);

    }

/// Properties

    var context:ExtensionContext;

    var statusBarItem:StatusBarItem;

    var tasksPath:String;

    var listContent:Dynamic;

    var chooserIndex:Dynamic;

    var watcher:FileSystemWatcher;

/// Lifecycle

    function new(context:ExtensionContext) {

        this.context = context;

        reload();

        context.subscriptions.push(Vscode.commands.registerCommand("tasks-chooser.reload", function() {
            reload();
        }));

        context.subscriptions.push(Vscode.commands.registerCommand("tasks-chooser.select", function() {
            select();
        }));

        watchChooserFile();

    }

/// Watch

    function watchChooserFile():Void {

        if (Vscode.workspace.workspaceFolders == null) {
            return;
        }

        watcher = Vscode.workspace.createFileSystemWatcher(Path.join([Vscode.workspace.workspaceFolders[0].uri.fsPath, '.vscode/tasks-chooser.json']), false, false, true);

        context.subscriptions.push(watcher.onDidChange(function(a) {
            reload();
        }));
        context.subscriptions.push(watcher.onDidCreate(function(a) {
            reload();
        }));
        context.subscriptions.push(watcher);

    }

/// Actions

    function reload():Void {

        try {
            var listPath = Path.join([Vscode.workspace.workspaceFolders[0].uri.fsPath, '.vscode/tasks-chooser.json']);
            listContent = Json.parse(File.getContent(listPath));

            tasksPath = Path.join([Vscode.workspace.workspaceFolders[0].uri.fsPath, '.vscode/tasks.json']);
            var tasksContent:Dynamic = null;
            try {
                tasksContent = Json.parse(File.getContent(tasksPath));
            } catch (e1:Dynamic) {}

            var targetIndex = 0;
            if (tasksContent != null && tasksContent.chooserIndex != null) {
                targetIndex = tasksContent.chooserIndex;
            }
            targetIndex = cast Math.min(targetIndex, listContent.items.length - 1);

            setChooserIndex(targetIndex);
        }
        catch (e:Dynamic) {
            Vscode.window.showErrorMessage("Failed to load: **.vscode/tasks-chooser.json**. Please check its content is valid.");
            js.Node.console.error(e);
        }

    }

    function select() {

        var pickItems:Array<Dynamic> = [];
        var index = 0;
        var items:Array<Dynamic> = listContent.items;
        for (item in items) {
            pickItems.push({
                label: (item.displayName != null ? item.displayName : 'Task #' + index),
                description: item.description != null ? item.description : '',
                index: index,
            });
            index++;
        }

        // Put selected task at the top
        if (chooserIndex > 0) {
            var selectedItem = pickItems[chooserIndex];
            pickItems.splice(chooserIndex, 1);
            pickItems.unshift(selectedItem);
        }

        var placeHolder = null;
        if (listContent.selectDescription != null) {
            placeHolder = listContent.selectDescription;
        } else {
            placeHolder = 'Select task';
        }

        Vscode.window.showQuickPick(pickItems, { placeHolder: placeHolder }).then(function(choice:Dynamic) {
            if (choice == null || choice.index == chooserIndex) {
                return;
            }

            try {
                setChooserIndex(choice.index);
            }
            catch (e:Dynamic) {
                Vscode.window.showErrorMessage("Failed to select task: " + e);
                js.Node.console.error(e);
            }

        });

    }

    function setChooserIndex(targetIndex:Int) {

        chooserIndex = targetIndex;

        var item:Dynamic = Json.parse(Json.stringify(listContent.items[chooserIndex]));

        // Merge with base item
        if (listContent.baseItem != null) {

            // New format with tasks array?
            if (listContent.baseItem.tasks != null || listContent.baseTask != null) {
                var tasks = [];

                var displayName:String = null;
                var description:String = null;
                if (item.displayName != null) {
                    displayName = item.displayName;
                    Reflect.deleteField(item, "displayName");
                }
                if (item.description != null) {
                    description = item.description;
                    Reflect.deleteField(item, "description");
                }

                inline function wrapWithBaseTask(task:Dynamic) {
                    if (listContent.baseTask != null) {
                        for (key in Reflect.fields(listContent.baseTask)) {
                            if (!Reflect.hasField(task, key)) {
                                Reflect.setField(task, key, Reflect.field(listContent.baseTask, key));
                            }
                        }
                    }
                    if (displayName != null && task.label == null) {
                        item.label = displayName;
                    }
                    return task;
                }

                if (item.tasks != null && item.tasks is Array) {
                    var rawItemTasks:Array<Dynamic> = item.tasks;
                    for (rawItemTask in rawItemTasks) {
                        tasks.push(
                            wrapWithBaseTask(rawItemTask)
                        );
                    }
                    Reflect.deleteField(item, 'tasks');
                }
                else {
                    tasks.push(
                        wrapWithBaseTask(item)
                    );
                }
                if (listContent.baseItem.tasks != null && listContent.baseItem.tasks is Array) {
                    var rawTasks:Array<Dynamic> = listContent.baseItem.tasks;
                    for (rawTask in rawTasks) {
                        tasks.push(rawTask);
                    }
                }

                item = Json.parse(Json.stringify(listContent.baseItem));
                item.tasks = tasks;
                if (displayName != null && item.displayName == null) {
                    item.displayName = displayName;
                }
                if (description != null && item.description == null) {
                    item.description = description;
                }
            }
            else {
                for (key in Reflect.fields(listContent.baseItem)) {
                    if (!Reflect.hasField(item, key)) {
                        Reflect.setField(item, key, Reflect.field(listContent.baseItem, key));
                    }
                }
            }
        }

        // Add chooser index
        item.chooserIndex = chooserIndex;

        // Check if there is an onSelect command
        var onSelect:Dynamic = null;
        if (item != null) {
            onSelect = item.onSelect;
            if (onSelect != null) {
                Reflect.deleteField(item, "onSelect");
            }
        }

        // Update tasks.json
        if (item != null) {
            File.saveContent(tasksPath, Json.stringify(item, null, "    "));
        }

        // Update/add status bar item
        if (statusBarItem == null) {
            statusBarItem = Vscode.window.createStatusBarItem(Left, -1); // Ideally, we would want to make priority configurable
            context.subscriptions.push(statusBarItem);
        }
        if (item != null && item.displayName != null) {
            statusBarItem.text = item.displayName;
        } else {
            statusBarItem.text = "Task #" + chooserIndex;
        }
        statusBarItem.text = "[ " + statusBarItem.text + " ]";
        statusBarItem.tooltip = item.description != null ? item.description : '';
        statusBarItem.command = "tasks-chooser.select";
        statusBarItem.show();

        // Run onSelect command, if any
        if (onSelect != null && Vscode.workspace.workspaceFolders != null) {
            var args:Array<String> = onSelect.args;
            if (args == null) args = [];
            var showError = onSelect.showError;
            var proc = ChildProcess.spawn(onSelect.command, args, {cwd: Vscode.workspace.workspaceFolders[0].uri.fsPath});
            proc.stdout.on('data', function(data) {
                js.Node.process.stdout.write(data);
            });
            proc.stderr.on('data', function(data) {
                js.Node.process.stderr.write(data);
            });
            proc.on('close', function(code) {
                if (code != 0 && showError) {
                    Vscode.window.showErrorMessage("Failed run onSelect command: exited with code " + code);
                }
            });
        }

    }

}
