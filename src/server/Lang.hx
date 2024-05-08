import api.IdeckiaApi.Translations;
import api.action.Data;

using StringTools;

class Lang {
	static inline var LOCALIZATIONS_DIR = '/lang';

	static var translations:Translations;

	static var isWatching = false;
	static var newTranslationName = 'your_language_code_here.json';

	@:v('ideckia.language:en')
	static var currentLang:String;

	static public function init() {
		translations = Data.getTranslations(LOCALIZATIONS_DIR);
		loadFromDisk();
	}

	static function loadFromDisk() {
		var absolutePath = Ideckia.getAppPath(LOCALIZATIONS_DIR);
		if (sys.FileSystem.exists(absolutePath)) {
			translations.merge(Data.getTranslationsAbsolute(LOCALIZATIONS_DIR));
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
		final innerTxtPath = js.Node.__dirname + LOCALIZATIONS_DIR + '/en.json';
		final innerTxtContent = sys.io.File.getContent(innerTxtPath);

		sys.io.File.saveContent(absolutePath, innerTxtContent);

		return absolutePath;
	}

	static public function localizeAll(text:String) {
		final currentLangLower = getCurrentLang();
		if (!translations.exists(currentLangLower)) {
			// Try loading again, maybe the file has been created after the initialization of the app
			loadFromDisk();
			if (!translations.exists(currentLangLower)) {
				Log.error('[$currentLangLower] language not found.');
				return text;
			}
		}

		var currentLangStrings = translations.get(currentLangLower);
		for (string in currentLangStrings)
			text = text.replace('::${string.id}::', string.text);

		return text;
	}

	static public function getCurrentLang() {
		return currentLang.toLowerCase();
	}
}
