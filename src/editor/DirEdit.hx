import hx.Selectors.Id;
import api.internal.ServerApi.ServerState;
import api.internal.ServerApi;
import js.html.Element;
import js.html.MouseEvent;
import js.Browser.document;

class DirEdit {
	static var currentDir:Dir;

	public static function show(dir:Dir) {
		currentDir = dir;
		Utils.clearElement(Id.dir_content.get());

		var ulItems = document.createUListElement();
		for (item in currentDir.items) {
			ulItems.append(ItemEdit.show(item));
		}

		Id.dir_content.get().append(ulItems);
	}

	public static function refresh() {
		Utils.hideProps();
		show(currentDir);
	}

	public static function edit(dir:Dir) {}
	/*
		function showInGrid(dirName:String) {
			for (element in document.getElementsByClassName('is-active')) {
				element.classList.remove('is-active');
			}
			Utils.clearElement(Id.container.get());

			var layout = editorData.layout;
			var found = layout.dirs.filter(f -> f.name.toString() == dirName);
			if (found.length == 0)
				return;

			var dir = found[0];
			var items = dir.items;
			var rows = dir.rows == null ? layout.rows : dir.rows;
			var columns = dir.columns == null ? layout.columns : dir.columns;
			var gridTemplateColumns = '';
			for (rind in 0...rows) {
				gridTemplateColumns = '';
				for (cind in 0...columns) {
					gridTemplateColumns += 'auto ';
					var item = items[rind * columns + cind];
					var cell = document.createDivElement();
					if (item != null) {
						switch item.kind {
							case null:
								cell.innerText = 'empty';
							case ChangeDir(toDir, _):
								cell.innerText = 'dir: ${toDir.toString()}';
								cell.classList.add('dir');
							case States(_, list):
								cell.innerText = 'states: ${list[0].text}';
								cell.classList.add('states');
						};
						cell.id = Std.string(item.id);
					}

					cell.classList.add('grid-item');

					cell.onclick = onItemSelected.bind(item);
					cell.classList.add(Cls.clickable_item);
					Id.container.get().append(cell);
				}
			}

			Id.container.get().style.gridTemplateColumns = gridTemplateColumns;
			document.getElementById(dirName).classList.add('is-active');
		}
	 */
}
