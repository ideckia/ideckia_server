package;

using api.IdeckiaCmdApi;

interface Types {}
typedef BaseState = api.IdeckiaCmdApi.ItemState;

typedef ClientItem = {
	> BaseState,
	var id:UInt;
}

typedef Cmd = {
	var ?id:UInt;
	var name:String;
	var ?props:Any;
}

typedef ServerState = {
	> BaseState,
	var ?cmd:Cmd;
}

enum Kind {
	SwitchFolder(toFolder:UInt, state:ServerState);
	SingleState(state:ServerState);
	MultiState(index:Int, states:Array<ServerState>);
}

typedef ServerItem = {
	var ?id:UInt;
	var kind:Kind;
}

typedef Folder = {
	> BaseState,
	var ?id:UInt;
	var items:Array<ServerItem>;
}

typedef Layout = {
	var rows:UInt;
	var columns:UInt;
	var folders:Array<Folder>;
	var ?icons:Array<{key:String, value:String}>;
}
