using StringTools;

class Lang {
	static inline var LOCALIZATIONS_DIR = '/lang';

	static var languages:Map<String, Map<String, String>> = [];

	static var isWatching = false;
	static var newTranslationName = 'your_language_code_here.txt';

	@:v('ideckia.language:en')
	static var currentLang:String;

	static public function init() {
		languages = [];
		getLang(js.Node.__dirname + LOCALIZATIONS_DIR);
		loadFromDisk();
	}

	static function loadFromDisk() {
		var absolutePath = Ideckia.getAppPath(LOCALIZATIONS_DIR);
		if (sys.FileSystem.exists(absolutePath)) {
			getLang(absolutePath);
			watchForChanges();
		}
	}

	public static function watchForChanges() {
		if (isWatching)
			return;

		Chokidar.watch(Ideckia.getAppPath(LOCALIZATIONS_DIR)).on('change', (_, _) -> {
			Log.info('Reloading translations...');
			init();
		});

		isWatching = true;
	}

	static public function newTranslation() {
		var absolutePath = Ideckia.getAppPath(LOCALIZATIONS_DIR);
		if (!sys.FileSystem.exists(absolutePath)) {
			sys.FileSystem.createDirectory(absolutePath);
			watchForChanges();
		}

		absolutePath += '/$newTranslationName';
		final innerTxtPath = js.Node.__dirname + LOCALIZATIONS_DIR + '/en.txt';
		final innerTxtContent = sys.io.File.getContent(innerTxtPath);

		sys.io.File.saveContent(absolutePath, innerTxtContent);

		return absolutePath;
	}

	static function getLang(directory:String) {
		var locTexts, splittedLine;
		if (sys.FileSystem.isDirectory(directory)) {
			for (langFile in sys.FileSystem.readDirectory(directory)) {
				if (langFile == newTranslationName)
					continue;

				Log.info('Reading [$langFile]');
				locTexts = new Map();
				var lines = ~/\r?\n/g.split(sys.io.File.getContent(directory + '/$langFile'));
				for (locLine in lines) {
					if (locLine.startsWith('#') || locLine.length == 0)
						continue;
					splittedLine = locLine.split('=');
					if (splittedLine.length != 2) {
						Log.debug('Skipping line [$locLine]');
						continue;
					}
					locTexts.set(splittedLine[0], splittedLine[1]);
				}

				languages.set(langFile.toLowerCase().replace('.txt', ''), locTexts);
			}
		}
	}

	static public function get(textId:String) {
		final currentLangLower = currentLang.toLowerCase();
		if (!languages.exists(currentLangLower)) {
			Log.error('[$currentLangLower] language not found.');
			return textId;
		}

		var currentLangTexts = languages.get(currentLangLower);
		if (!currentLangTexts.exists(textId)) {
			Log.error('[$currentLangLower] language not found.');
			return textId;
		}

		return currentLangTexts.get(textId);
	}

	static public function localizeAll(text:String) {
		final currentLangLower = currentLang.toLowerCase();
		if (!languages.exists(currentLangLower)) {
			// Try loading again, maybe the file has been created after the initialization of the app
			loadFromDisk();
			if (!languages.exists(currentLangLower)) {
				Log.error('[$currentLangLower] language not found.');
				return text;
			}
		}

		var currentLangTexts = languages.get(currentLangLower);
		for (key => value in currentLangTexts)
			text = text.replace('::$key::', value);

		return text;
	}

	static public function getCurrentLang() {
		return currentLang;
	}
}
