# ideckia server

## Concepts

* Layout: Bunch of items
* Item: An element that has one or more states and is clickable in the client.
* State: Definition of the item status: text, textColor, bgColor, icon and a action which will be executed when the item is pressed.

## Configuration file

All the items and their actions are defined in a plain JSON file.

## Actions

### Create your own action

Execute `ideckia --create-action` to create a new action from a existing template.
  * Select which template do you want to use as base. Current options Haxe and JavaScript
  * Select the name for the action.
  * A new folder is created in the actions folder with the name of you new action.