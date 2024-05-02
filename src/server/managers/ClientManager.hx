package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaApi;
using api.internal.ServerApi;

class ClientManager {
	public static function handleMsg(msg:ClientMsg) {
		switch msg.type {
			case click | longPress:
				onItemClick(new ItemId(msg.itemId), msg.type == longPress);
			case gotoDir if (msg.toDir == 'prev' || msg.toDir == 'main'):
				var changePromise = if (msg.toDir == 'prev') {
					LayoutManager.gotoPreviousDir();
				} else {
					LayoutManager.gotoMainDir();
				}
				changePromise.finally(() -> MsgManager.sendToAll(LayoutManager.currentDirForClient()));
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}

	static function onItemClick(clickedId:ItemId, isLongPress:Bool) {
		Log.debug('[$clickedId] item clicked');

		try {
			switch LayoutManager.checkChangeDir(clickedId) {
				case Some(toDir):
					LayoutManager.changeDir(toDir).finally(() -> MsgManager.sendToAll(LayoutManager.currentDirForClient()));
					return;
				case None:
			};
		} catch (e:ItemNotFoundException) {
			Log.debug(e);
			return;
		}

		try {
			var stateAndChanged = LayoutManager.getItemNextState(clickedId, true);
			var currentState = stateAndChanged.state;
			var hasMultiStateChanged = stateAndChanged.hasMultiStateChanged;

			if (hasMultiStateChanged) {
				MsgManager.sendToAll(LayoutManager.currentDirForClient());
			} else {
				Log.info('Clicked state: [text=${currentState.text}], [icon=${(currentState.icon == null) ? null : currentState.icon.substring(0, 50) + "..."}]');
				switch ActionManager.getActionsByStateId(currentState.id) {
					case Some(actions):
						var promiseThen = (response:ActionOutcome) -> {
							var actionOutcome:ActionOutcome = cast response;
							var instantSend = true;
							if (actionOutcome.state != null) {
								var newState = actionOutcome.state;
								if (newState != null) {
									Log.debug('newState: [text=${newState.text}], [icon=${(newState.icon == null) ? null : newState.icon.substring(0, 50) + "..."}]');
									currentState.text = newState.text;
									currentState.textColor = newState.textColor;
									currentState.textSize = newState.textSize;
									currentState.icon = newState.icon;
									currentState.bgColor = newState.bgColor;
								}
							} else if (actionOutcome.directory != null) {
								instantSend = false;
								LayoutManager.generateDynamicDirectory(clickedId, actionOutcome.directory)
									.then(_ -> MsgManager.sendToAll(LayoutManager.currentDirForClient()));
							}
							if (instantSend)
								MsgManager.sendToAll(LayoutManager.currentDirForClient());
						};
						var promiseError = (error) -> {
							Log.error('Error executing actions of the state [${currentState.id}]. [${Std.string(error)}]');
							Ideckia.dialog.error('Error executing actions of the state [${currentState.id}]', Std.string(error));
						};

						var prevAction:IdeckiaAction = null;
						// Action chaining: use the output of each action as input for the next action
						Lambda.fold(actions, (action:IdeckiaAction, promise:Promise<ActionOutcome>) -> {
							function execAction(newState) {
								if (isLongPress) {
									if (newState.extraData != null && prevAction != null) {
										return new js.lib.Promise<ActionOutcome>((resolve, reject) -> {
											prevAction.getActionDescriptor()
												.then(ad -> newState.extraData.fromAction = ad.name)
												.catchError(e -> Log.error('getActionDescriptor() error: $e'))
												.finally(() -> action.onLongPress(newState).then(resolve).catchError(reject));
										});
									} else {
										prevAction = action;
										var hasOnLongPressMethod = js.Syntax.code("typeof {0}.onLongPress", action) == 'function';
										if (hasOnLongPressMethod)
											return action.onLongPress(newState);
										else
											return js.lib.Promise.resolve(new ActionOutcome({state: currentState}));
									}
								} else {
									if (newState.extraData != null && prevAction != null) {
										return new js.lib.Promise<ActionOutcome>((resolve, reject) -> {
											prevAction.getActionDescriptor()
												.then(ad -> newState.extraData.fromAction = ad.name)
												.catchError(e -> Log.error('getActionDescriptor() error: $e'))
												.finally(() -> action.execute(newState).then(resolve).catchError(reject));
										});
									} else {
										prevAction = action;
										return action.execute(newState);
									}
								}
							}
							return promise.then((actionOutcome) -> {
								if (actionOutcome.state != null) {
									return execAction(actionOutcome.state);
								} else if (actionOutcome.directory != null) {
									return js.lib.Promise.resolve(actionOutcome);
								}

								return js.lib.Promise.resolve(new ActionOutcome({state: currentState}));
							}).catchError(e -> {
								Log.error('Error running action.');
								Log.raw(e.stack);
								return execAction(currentState);
							});
						},
							js.lib.Promise.resolve(new ActionOutcome({state: currentState}))).then(promiseThen).catchError(promiseError);
					case None:
						Log.error('No action found for state [${currentState.id}]');
				}
			}
		} catch (e:ItemNotFoundException) {
			Log.error(e.message, e.posInfos);
		}
	}

	public static function fromActionToClient(itemId:ItemId, actionName:String, newState:ItemState) {
		if (newState == null || !LayoutManager.isItemVisible(itemId))
			return;
		Log.debug('From Action [$actionName] to client state [$itemId] [${newState.text}]');

		var currentState = LayoutManager.getItemNextState(itemId).state;
		if (currentState == null)
			return;

		var tx = newState.text;
		var txc = newState.textColor;
		var txs = newState.textSize;
		var ic = newState.icon;
		var bgc = newState.bgColor;

		if (tx != null)
			currentState.text = tx;
		if (txc != null)
			currentState.textColor = txc;
		if (txs != null)
			currentState.textSize = txs;
		if (ic != null)
			currentState.icon = ic;
		if (bgc != null)
			currentState.bgColor = bgc;

		MsgManager.sendToAll(LayoutManager.currentDirForClient());
	}
}
