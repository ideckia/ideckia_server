package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaApi;
using api.internal.ServerApi;

class ClientManager {
	public static function handleMsg(msg:ClientMsg) {
		switch msg.type {
			case click | longPress:
				onItemClick(new ItemId(msg.itemId), msg.type == longPress);
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}

	static function onItemClick(clickedId:ItemId, isLongPress:Bool) {
		Log.debug('[$clickedId] item clicked');

		try {
			var toDir = LayoutManager.getChangeDirName(clickedId);
			if (toDir != null) {
				LayoutManager.changeDir(toDir);
				MsgManager.sendToAll(LayoutManager.currentDirForClient());
				return;
			}
		} catch (e:ItemNotFoundException) {
			Log.debug(e);
			return;
		}

		var currentState = null;
		try {
			currentState = LayoutManager.getItemCurrentState(clickedId, true);
			Log.info('Clicked state: [text=${currentState.text}], [icon=${(currentState.icon == null) ? null : currentState.icon.substring(0, 50) + "..."}]');
			Log.debug('State of the item [id=$clickedId]: $currentState');
		} catch (e:ItemNotFoundException) {
			Log.error(e.message, e.posInfos);
		}

		if (currentState != null) {
			switch ActionManager.getActionByStateId(currentState.id) {
				case Some(actions):
					var promiseThen = (newState:ItemState) -> {
						if (newState != null) {
							Log.debug('newState: $newState');
							currentState.text = newState.text;
							currentState.textColor = newState.textColor;
							currentState.icon = newState.icon;
							currentState.bgColor = newState.bgColor;
						}

						MsgManager.sendToAll(LayoutManager.currentDirForClient());
					};
					var promiseError = (error) -> {
						Log.error('Error executing actions of the state [${currentState.id}]: $error');
					};
					// Action chaining: use the output of each action as input for the next action
					Lambda.fold(actions, (action:IdeckiaAction, promise:Promise<ItemState>) -> {
						return promise.then((curState) -> {
							if (isLongPress)
								return action.onLongPress(curState);
							else
								return action.execute(currentState);
						});
					},
						js.lib.Promise.resolve(currentState)).then(promiseThen).catchError(promiseError);
				case None:
			}
		}

		MsgManager.sendToAll(LayoutManager.currentDirForClient());
	}

	public static function fromActionToClient(itemId:ItemId, actionName:String, newState:ItemState) {
		Log.debug('From Action [$actionName] to client state [$itemId] [$newState]');
		if (newState == null || !LayoutManager.isItemVisible(itemId))
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

		MsgManager.sendToAll(LayoutManager.currentDirForClient());
	}
}
