package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaCmdApi;
using Types;

import websocket.WebSocketConnection;

class ClientManager {
	public static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		if (wsConnection == null)
			wsConnection = connection;

		switch msg.type {
			case click:
				onItemClick(msg.itemId);
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}

	static function onItemClick(clickedId:UInt) {
		Log.debug('[$clickedId] item clicked');

		var toFolder = LayoutManager.getSwitchFolderId(clickedId);
		if (toFolder != -1) {
			LayoutManager.switchFolder(toFolder);
			MsgManager.send(wsConnection, LayoutManager.currentFolderForClient());
			return;
		}

		var currentState = null;
		try {
			currentState = LayoutManager.getItemCurrentState(clickedId, true);
		} catch (e:ItemNotFoundException) {
			Log.error(e.message, e.posInfos);
		}

		if (currentState != null) {
			var cmd = currentState.cmd;
			if (cmd != null) {
				var newState:BaseState = currentState;
				var command:IdeckiaCmd = CmdManager.getClientCommand(cmd.id);
				if (command != null) {
					try {
						Log.debug('Executing [${cmd.name}] command from currentState = [${currentState}]');
						newState = command.execute();
					} catch (e:haxe.Exception) {
						Log.error('Error executing [${command}]: ${e.message}');
						return;
					}

					if (newState != null) {
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

	public static function fromCmdToClient(itemId:UInt, newState:ItemState) {
		Log.debug('From CMD to client state [$itemId] [$newState]');
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
