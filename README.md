# ideckia server

## Concepts

* Layout: Bunch of items
* Item: An element that has one or more states and is clickable in the client.
* State: Definition of the item status: text, textColor, bgColor, icon and a action.
* Action: Action which will be fired in the host computer when the item is pressed in the client.

## Layout file

All the items and their actions are defined in a plain JSON file.

## Actions

Actions are available in the `actions` folder usually (configurable via `app.props`). Every action is defined in it's own folder and an `index.js` file in it.

This `index.js` file must have [this structure](https://github.com/ideckia/ideckia_api#action-structure) to be called from the server when loaded and executed

```
|-- ideckia
|-- app.props
|-- layout.json
|-- actions
|   |-- my_action
|       |-- index.js
|   |-- another_action
|       |-- index.js
|       |-- dependencies.js
```

### Examples

* All pieces in the `sample` folder. Download the [latest release](https://github.com/ideckia/ideckia_server/releases/) of this server for you OS, put it in the `sample` folder and run it.
* Haxe: [action_command](https://github.com/ideckia/action_command)
* Javascript: [action_counter](https://github.com/ideckia/action_counter)

### Create your own action

Execute `ideckia --create-action` to create a new action from a existing template.
  * Select which template do you want to use as base. Current options Haxe and JavaScript
  * Select the name for the action.
  * A new folder is created in the actions folder with the name of you new action which contains the files from the selected template.