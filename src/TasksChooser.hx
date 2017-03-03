package;

import sys.io.File;
import haxe.io.Path;
import haxe.Json;

import vscode.ExtensionContext;
import vscode.StatusBarItem;

class TasksChooser {

/// Exposed

    static var instance:TasksChooser = null;

    @:expose("activate")
    static function activate(context:ExtensionContext) {

        instance = new TasksChooser(context);

    } //activate

/// Properties

    var context:ExtensionContext;

    var statusBarItem:StatusBarItem;

    var tasksPath:String;

    var listContent:Dynamic;

    var chooserIndex:Dynamic;

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

    } //new

/// Actions

    function reload():Void {

        try {
            var listPath = Path.join([Vscode.workspace.rootPath, '.vscode/tasks-chooser.json']);
            listContent = Json.parse(File.getContent(listPath));

            tasksPath = Path.join([Vscode.workspace.rootPath, '.vscode/tasks.json']);
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
        }

    } //reload

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
            }

        });

    } //select

    function setChooserIndex(targetIndex:Int) {

        chooserIndex = targetIndex;

        var item = Json.parse(Json.stringify(listContent.items[chooserIndex]));
        if (listContent.baseItem != null) {
            for (key in Reflect.fields(listContent.baseItem)) {
                if (!Reflect.hasField(item, key)) {
                    Reflect.setField(item, key, Reflect.field(listContent.baseItem, key));
                }
            }
        }
        item.chooserIndex = chooserIndex;

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
        statusBarItem.text = "[ " + statusBarItem.text + " ]";
        statusBarItem.tooltip = item.description != null ? item.description : '';
        statusBarItem.command = "tasks-chooser.select";
        statusBarItem.show();

    } //setChooserIndex

}
