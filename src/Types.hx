package;

using api.IdeckiaApi;

import tink.json.Representation;

interface Types {}
typedef BaseState = api.IdeckiaApi.ItemState;

typedef ClientItem = {
	> BaseState,
	var id:UInt;
}

typedef Action = {
	var ?id:ActionId;
	var name:String;
	var ?props:Any;
}

typedef ServerState = {
	> BaseState,
	var ?id:StateId;
	var ?action:Action;
}

enum Kind {
	SwitchFolder(toFolder:FolderId, state:ServerState);
	SingleState(state:ServerState);
	MultiState(index:Int, states:Array<ServerState>);
}

typedef ServerItem = {
	var ?id:ItemId;
	var kind:Kind;
}

typedef Folder = {
	> BaseState,
	var ?id:FolderId;
	var items:Array<ServerItem>;
}

typedef Layout = {
	var rows:UInt;
	var columns:UInt;
	var folders:Array<Folder>;
	var ?icons:Array<{key:String, value:String}>;
}

abstract ActionId(UInt) {
	public inline function new(v)
		this = v;

	@:to function toRepresentation():Representation<UInt>
		return new Representation(this);
	
	public function toUInt():UInt
		return this;

	@:from static function ofRepresentation(rep:Representation<UInt>)
		return new ActionId(rep.get());
}

abstract ItemId(UInt) {
	public inline function new(v)
		this = v;

	@:to function toRepresentation():Representation<UInt>
		return new Representation(this);
	
	public function toUInt():UInt
		return this;

	@:from static function ofRepresentation(rep:Representation<UInt>)
		return new ItemId(rep.get());
}

abstract FolderId(UInt) {
	public inline function new(v)
		this = v;

	@:to function toRepresentation():Representation<UInt>
		return new Representation(this);
	
	public function toUInt():UInt
		return this;

	@:from static function ofRepresentation(rep:Representation<UInt>)
		return new FolderId(rep.get());
}

abstract StateId(UInt) {
	public inline function new(v)
		this = v;

	@:to function toRepresentation():Representation<UInt>
		return new Representation(this);
	
	public function toUInt():UInt
		return this;

	@:from static function ofRepresentation(rep:Representation<UInt>)
		return new StateId(rep.get());
}