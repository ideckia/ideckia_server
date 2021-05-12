package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaApi;
using Types;

import websocket.WebSocketConnection;

class ClientManager {
	public static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		wsConnection = connection;

		switch msg.type {
			case click:
				onItemClick(new ItemId(msg.itemId));
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}

	static function onItemClick(clickedId:ItemId) {
		Log.info('[$clickedId] item clicked');

		var toFolder = LayoutManager.getSwitchFolderId(clickedId);
		if (toFolder != null) {
			LayoutManager.switchFolder(toFolder);
			MsgManager.send(wsConnection, LayoutManager.currentFolderForClient());
			return;
		}

		var currentState = null;
		try {
			currentState = LayoutManager.getItemCurrentState(clickedId, true);
			Log.info('Clicked state: [text=${currentState.text}], [icon=${currentState.icon}]');
			Log.debug('State of the item [id=$clickedId]: $currentState');
		} catch (e:ItemNotFoundException) {
			Log.error(e.message, e.posInfos);
		}

		if (currentState != null) {
			var stateAction = currentState.action;
			if (stateAction != null) {
				var newState:BaseState = currentState;
				var action:IdeckiaAction = ActionManager.getActionByStateId(currentState.id);
				if (action != null) {
					try {
						Log.info('Executing [${stateAction.name}] action from clicked state.');
						newState = action.execute(currentState);
					} catch (e:haxe.Exception) {
						Log.error('Error executing [${action}]: ${e.message}');
						return;
					}

					if (newState != null) {
						Log.debug('newState: $newState');
						currentState.text = newState.text;
						currentState.textColor = newState.textColor;
						currentState.icon = newState.icon;
						currentState.bgColor = newState.bgColor;
					}
				}
			}
		}

		MsgManager.send(wsConnection, LayoutManager.currentFolderForClient());
	}

	public static function fromActionToClient(itemId:ItemId, actionName:String, newState:ItemState) {
		Log.debug('From Action [$actionName] to client state [$itemId] [$newState]');
		if (newState == null)
			return;

		var currentState = LayoutManager.getItemCurrentState(itemId);
		if (currentState == null)
			return;

		var tx = newState.text;
		var txc = newState.textColor;
		var ic = newState.icon;
		var bgc = newState.bgColor;

		if (tx != null)
			currentState.text = tx;
		if (txc != null)
			currentState.textColor = txc;
		if (ic != null)
			currentState.icon = ic;
		if (bgc != null)
			currentState.bgColor = bgc;

		MsgManager.send(wsConnection, LayoutManager.currentFolderForClient());
	}
}
