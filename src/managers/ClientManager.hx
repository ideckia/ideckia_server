package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaApi;
using Types;

import websocket.WebSocketConnection;

class ClientManager {
	public static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		if (wsConnection == null)
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
			Log.info('Clicked state: [$currentState]');
		} catch (e:ItemNotFoundException) {
			Log.error(e.message, e.posInfos);
		}

		if (currentState != null) {
			var stateAction = currentState.action;
			if (stateAction != null) {
				var newState:BaseState = currentState;
				var action:IdeckiaAction = ActionManager.getClientAction(clickedId);
				if (action != null) {
					try {
						Log.debug('Executing [${stateAction.name}] action from currentState = [${currentState}]');
						newState = action.execute();
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

	public static function fromActionToClient(itemId:ItemId, newState:ItemState) {
		Log.debug('From Action to client state [$itemId] [$newState]');
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
