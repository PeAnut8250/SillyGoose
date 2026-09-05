import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Supported languages (display name → Locale)
// ─────────────────────────────────────────────────────────────────────────────
class AppLanguage {
  final String displayName;
  final String nativeName;
  final Locale locale;
  const AppLanguage(this.displayName, this.nativeName, this.locale);
}

const List<AppLanguage> kSupportedLanguages = [
  AppLanguage('English',            'English',          Locale('en')),
  AppLanguage('Hindi',              'हिन्दी',            Locale('hi')),
  AppLanguage('Bengali',            'বাংলা',             Locale('bn')),
  AppLanguage('French',             'Français',         Locale('fr')),
  AppLanguage('Dutch',              'Nederlands',       Locale('nl')),
  AppLanguage('Spanish',            'Español',          Locale('es')),
  AppLanguage('Portuguese',         'Português',        Locale('pt')),
  AppLanguage('German',             'Deutsch',          Locale('de')),
  AppLanguage('Italian',            'Italiano',         Locale('it')),
  AppLanguage('Russian',            'Русский',          Locale('ru')),
  AppLanguage('Japanese',           '日本語',            Locale('ja')),
  AppLanguage('Korean',             '한국어',            Locale('ko')),
  AppLanguage('Chinese',            '中文',             Locale('zh')),
  AppLanguage('Arabic',             'العربية',          Locale('ar')),
  AppLanguage('Turkish',            'Türkçe',           Locale('tr')),
  AppLanguage('Polish',             'Polski',           Locale('pl')),
  AppLanguage('Ukrainian',          'Українська',       Locale('uk')),
  AppLanguage('Swedish',            'Svenska',          Locale('sv')),
  AppLanguage('Norwegian',          'Norsk',            Locale('no')),
  AppLanguage('Danish',             'Dansk',            Locale('da')),
  AppLanguage('Finnish',            'Suomi',            Locale('fi')),
  AppLanguage('Greek',              'Ελληνικά',         Locale('el')),
  AppLanguage('Czech',              'Čeština',          Locale('cs')),
  AppLanguage('Romanian',           'Română',           Locale('ro')),
  AppLanguage('Hungarian',          'Magyar',           Locale('hu')),
  AppLanguage('Thai',               'ภาษาไทย',          Locale('th')),
  AppLanguage('Vietnamese',         'Tiếng Việt',       Locale('vi')),
  AppLanguage('Indonesian',         'Bahasa Indonesia', Locale('id')),
  AppLanguage('Tamil',              'தமிழ்',             Locale('ta')),
  AppLanguage('Punjabi',            'ਪੰਜਾਬੀ',           Locale('pa')),
];

Locale localeForLanguage(String displayName) {
  return kSupportedLanguages
      .firstWhere((l) => l.displayName == displayName,
          orElse: () => kSupportedLanguages.first)
      .locale;
}

String languageForLocale(Locale locale) {
  return kSupportedLanguages
      .firstWhere((l) => l.locale.languageCode == locale.languageCode,
          orElse: () => kSupportedLanguages.first)
      .displayName;
}

// ─────────────────────────────────────────────────────────────────────────────
// Translations (key → per-locale string)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _translations = {
  // ── Navigation
  'home':     {'en':'Home','hi':'होम','bn':'হোম','fr':'Accueil','nl':'Startpagina','es':'Inicio','pt':'Início','de':'Startseite','it':'Home','ru':'Главная','ja':'ホーム','ko':'홈','zh':'主页','ar':'الرئيسية','tr':'Ana Sayfa','pl':'Strona główna','uk':'Головна','sv':'Hem','no':'Hjem','da':'Hjem','fi':'Koti','el':'Αρχική','cs':'Domů','ro':'Acasă','hu':'Főoldal','th':'หน้าหลัก','vi':'Trang chủ','id':'Beranda','ta':'முகப்பு','pa':'ਹੋਮ'},
  'search':   {'en':'Search','hi':'खोज','bn':'অনুসন্ধান','fr':'Rechercher','nl':'Zoeken','es':'Buscar','pt':'Pesquisar','de':'Suche','it':'Cerca','ru':'Поиск','ja':'検索','ko':'검색','zh':'搜索','ar':'بحث','tr':'Ara','pl':'Szukaj','uk':'Пошук','sv':'Sök','no':'Søk','da':'Søg','fi':'Haku','el':'Αναζήτηση','cs':'Hledat','ro':'Caută','hu':'Keresés','th':'ค้นหา','vi':'Tìm kiếm','id':'Cari','ta':'தேடு','pa':'ਖੋਜ'},
  'library':  {'en':'Library','hi':'पुस्तकालय','bn':'লাইব্রেরি','fr':'Bibliothèque','nl':'Bibliotheek','es':'Biblioteca','pt':'Biblioteca','de':'Bibliothek','it':'Libreria','ru':'Библиотека','ja':'ライブラリ','ko':'보관함','zh':'库','ar':'المكتبة','tr':'Kütüphane','pl':'Biblioteka','uk':'Бібліотека','sv':'Bibliotek','no':'Bibliotek','da':'Bibliotek','fi':'Kirjasto','el':'Βιβλιοθήκη','cs':'Knihovna','ro':'Bibliotecă','hu':'Könyvtár','th':'คลังเพลง','vi':'Thư viện','id':'Perpustakaan','ta':'நூலகம்','pa':'ਲਾਇਬ੍ਰੇਰੀ'},
  'settings': {'en':'Settings','hi':'सेटिंग्स','bn':'সেটিংস','fr':'Paramètres','nl':'Instellingen','es':'Ajustes','pt':'Configurações','de':'Einstellungen','it':'Impostazioni','ru':'Настройки','ja':'設定','ko':'설정','zh':'设置','ar':'الإعدادات','tr':'Ayarlar','pl':'Ustawienia','uk':'Налаштування','sv':'Inställningar','no':'Innstillinger','da':'Indstillinger','fi':'Asetukset','el':'Ρυθμίσεις','cs':'Nastavení','ro':'Setări','hu':'Beállítások','th':'การตั้งค่า','vi':'Cài đặt','id':'Pengaturan','ta':'அமைப்புகள்','pa':'ਸੈਟਿੰਗਾਂ'},
  // ── Player
  'play':     {'en':'Play','hi':'चलाएं','bn':'চালান','fr':'Lecture','nl':'Afspelen','es':'Reproducir','pt':'Tocar','de':'Abspielen','it':'Riproduci','ru':'Воспроизвести','ja':'再生','ko':'재생','zh':'播放','ar':'تشغيل','tr':'Oynat','pl':'Odtwórz','uk':'Відтворити','sv':'Spela','no':'Spill','da':'Afspil','fi':'Toista','el':'Αναπαραγωγή','cs':'Přehrát','ro':'Redă','hu':'Lejátszás','th':'เล่น','vi':'Phát','id':'Putar','ta':'இயக்கு','pa':'ਚਲਾਓ'},
  'pause':    {'en':'Pause','hi':'रोकें','bn':'বিরাম','fr':'Pause','nl':'Pauzeren','es':'Pausar','pt':'Pausar','de':'Pause','it':'Pausa','ru':'Пауза','ja':'一時停止','ko':'일시정지','zh':'暂停','ar':'إيقاف مؤقت','tr':'Duraklat','pl':'Wstrzymaj','uk':'Пауза','sv':'Paus','no':'Pause','da':'Pause','fi':'Tauko','el':'Παύση','cs':'Pozastavit','ro':'Pauză','hu':'Szünet','th':'หยุดชั่วคราว','vi':'Tạm dừng','id':'Jeda','ta':'நிறுத்து','pa':'ਰੋਕੋ'},
  'next':     {'en':'Next','hi':'अगला','bn':'পরবর্তী','fr':'Suivant','nl':'Volgende','es':'Siguiente','pt':'Próximo','de':'Weiter','it':'Avanti','ru':'Далее','ja':'次へ','ko':'다음','zh':'下一首','ar':'التالي','tr':'Sonraki','pl':'Dalej','uk':'Далі','sv':'Nästa','no':'Neste','da':'Næste','fi':'Seuraava','el':'Επόμενο','cs':'Další','ro':'Următor','hu':'Következő','th':'ถัดไป','vi':'Tiếp theo','id':'Berikutnya','ta':'அடுத்து','pa':'ਅਗਲਾ'},
  'previous': {'en':'Previous','hi':'पिछला','bn':'আগের','fr':'Précédent','nl':'Vorige','es':'Anterior','pt':'Anterior','de':'Zurück','it':'Precedente','ru':'Назад','ja':'前へ','ko':'이전','zh':'上一首','ar':'السابق','tr':'Önceki','pl':'Wstecz','uk':'Назад','sv':'Föregående','no':'Forrige','da':'Forrige','fi':'Edellinen','el':'Προηγούμενο','cs':'Předchozí','ro':'Anterior','hu':'Előző','th':'ก่อนหน้า','vi':'Trước','id':'Sebelumnya','ta':'முன்பு','pa':'ਪਿਛਲਾ'},
  'shuffle':  {'en':'Shuffle','hi':'शफल','bn':'শাফল','fr':'Aléatoire','nl':'Willekeurig','es':'Aleatorio','pt':'Aleatório','de':'Zufällig','it':'Casuale','ru':'Перемешать','ja':'シャッフル','ko':'셔플','zh':'随机','ar':'عشوائي','tr':'Karıştır','pl':'Losowo','uk':'Перемішати','sv':'Blanda','no':'Bland','da':'Bland','fi':'Sekoita','el':'Ανακάτεμα','cs':'Náhodně','ro':'Aleatoriu','hu':'Véletlenszerű','th':'สุ่ม','vi':'Ngẫu nhiên','id':'Acak','ta':'சேர்த்து','pa':'ਫੇਰਬਦਲ'},
  'repeat':   {'en':'Repeat','hi':'दोहराएं','bn':'পুনরাবৃত্তি','fr':'Répéter','nl':'Herhalen','es':'Repetir','pt':'Repetir','de':'Wiederholen','it':'Ripeti','ru':'Повторить','ja':'リピート','ko':'반복','zh':'重复','ar':'تكرار','tr':'Tekrar','pl':'Powtórz','uk':'Повторити','sv':'Upprepa','no':'Gjenta','da':'Gentag','fi':'Toista','el':'Επανάληψη','cs':'Opakovat','ro':'Repetare','hu':'Ismétlés','th':'ทำซ้ำ','vi':'Lặp lại','id':'Ulangi','ta':'மீண்டும்','pa':'ਦੁਹਰਾਓ'},
  // ── Library / Playlists
  'liked_songs':      {'en':'Liked Songs','hi':'पसंदीदा गाने','bn':'পছন্দের গান','fr':'Titres aimés','nl':'Favoriete nummers','es':'Canciones favoritas','pt':'Músicas curtidas','de':'Gefallene Songs','it':'Brani preferiti','ru':'Понравившиеся','ja':'お気に入り曲','ko':'좋아요한 노래','zh':'喜欢的歌曲','ar':'الأغاني المفضلة','tr':'Beğenilen Şarkılar','pl':'Polubione Utwory','uk':'Вподобані пісні','sv':'Gillade Låtar','no':'Likte Sanger','da':'Likede Sange','fi':'Tykätyt Kappaleet','el':'Αγαπημένα Τραγούδια','cs':'Oblíbené Skladby','ro':'Melodii Apreciate','hu':'Kedvelt Dalok','th':'เพลงที่ชอบ','vi':'Bài hát yêu thích','id':'Lagu Disukai','ta':'விரும்பிய பாடல்கள்','pa':'ਪਸੰਦੀਦਾ ਗੀਤ'},
  'new_playlist':     {'en':'New Playlist','hi':'नई प्लेलिस्ट','bn':'নতুন প্লেলিস্ট','fr':'Nouvelle liste','nl':'Nieuwe afspeellijst','es':'Nueva lista','pt':'Nova lista','de':'Neue Playlist','it':'Nuova playlist','ru':'Новый плейлист','ja':'新しいプレイリスト','ko':'새 재생목록','zh':'新建播放列表','ar':'قائمة تشغيل جديدة','tr':'Yeni Çalma Listesi','pl':'Nowa playlista','uk':'Новий плейлист','sv':'Ny spellista','no':'Ny spilleliste','da':'Ny afspilningsliste','fi':'Uusi soittolista','el':'Νέα λίστα αναπαραγωγής','cs':'Nový playlist','ro':'Listă de redare nouă','hu':'Új lejátszási lista','th':'เพลย์ลิสต์ใหม่','vi':'Danh sách phát mới','id':'Daftar Putar Baru','ta':'புதிய பட்டியல்','pa':'ਨਵੀਂ ਪਲੇਲਿਸਟ'},
  'delete':           {'en':'Delete','hi':'हटाएं','bn':'মুছুন','fr':'Supprimer','nl':'Verwijderen','es':'Eliminar','pt':'Excluir','de':'Löschen','it':'Elimina','ru':'Удалить','ja':'削除','ko':'삭제','zh':'删除','ar':'حذف','tr':'Sil','pl':'Usuń','uk':'Видалити','sv':'Ta bort','no':'Slett','da':'Slet','fi':'Poista','el':'Διαγραφή','cs':'Smazat','ro':'Șterge','hu':'Törlés','th':'ลบ','vi':'Xóa','id':'Hapus','ta':'நீக்கு','pa':'ਮਿਟਾਓ'},
  // ── Settings sections
  'audio_quality':    {'en':'Audio Quality','hi':'ऑडियो गुणवत्ता','bn':'অডিও মান','fr':'Qualité audio','nl':'Audiokwaliteit','es':'Calidad de audio','pt':'Qualidade de áudio','de':'Audioqualität','it':'Qualità audio','ru':'Качество звука','ja':'音質','ko':'음질','zh':'音质','ar':'جودة الصوت','tr':'Ses Kalitesi','pl':'Jakość dźwięku','uk':'Якість звуку','sv':'Ljudkvalitet','no':'Lydkvalitet','da':'Lydkvalitet','fi':'Äänenlaatu','el':'Ποιότητα ήχου','cs':'Kvalita zvuku','ro':'Calitate audio','hu':'Hangminőség','th':'คุณภาพเสียง','vi':'Chất lượng âm thanh','id':'Kualitas audio','ta':'ஒலி தரம்','pa':'ਆਡੀਓ ਗੁਣਵੱਤਾ'},
  'on_wifi':          {'en':'On Wi-Fi','hi':'वाई-फाई पर','bn':'ওয়াই-ফাইয়ে','fr':'Sur Wi-Fi','nl':'Op Wi-Fi','es':'En Wi-Fi','pt':'No Wi-Fi','de':'Im WLAN','it':'Su Wi-Fi','ru':'По Wi-Fi','ja':'Wi-Fi接続時','ko':'Wi-Fi에서','zh':'使用Wi-Fi','ar':'على Wi-Fi','tr':'Wi-Fi üzerinde','pl':'Przez Wi-Fi','uk':'Через Wi-Fi','sv':'Via Wi-Fi','no':'Via Wi-Fi','da':'Via Wi-Fi','fi':'Wi-Fissä','el':'Μέσω Wi-Fi','cs':'Přes Wi-Fi','ro':'Prin Wi-Fi','hu':'Wi-Fi-n','th':'บน Wi-Fi','vi':'Qua Wi-Fi','id':'Melalui Wi-Fi','ta':'வைஃபையில்','pa':'ਵਾਈ-ਫਾਈ ਤੇ'},
  'on_mobile_data':   {'en':'On mobile data','hi':'मोबाइल डेटा पर','bn':'মোবাইল ডেটায়','fr':'En données mobiles','nl':'Op mobiele data','es':'En datos móviles','pt':'Em dados móveis','de':'Mit mobilen Daten','it':'Con dati mobili','ru':'По мобильным данным','ja':'モバイルデータ使用時','ko':'모바일 데이터에서','zh':'使用移动数据','ar':'على بيانات الجوال','tr':'Mobil veride','pl':'Przez dane mobilne','uk':'Через мобільні дані','sv':'Via mobildata','no':'Via mobildata','da':'Via mobildata','fi':'Mobiilidata','el':'Με δεδομένα','cs':'Přes mobilní data','ro':'Pe date mobile','hu':'Mobiladaton','th':'ใช้เน็ตมือถือ','vi':'Dữ liệu di động','id':'Data seluler','ta':'மொபைல் தரவு','pa':'ਮੋਬਾਈਲ ਡੇਟਾ ਤੇ'},
  'downloads':        {'en':'Downloads','hi':'डाउनलोड','bn':'ডাউনলোড','fr':'Téléchargements','nl':'Downloads','es':'Descargas','pt':'Downloads','de':'Downloads','it':'Download','ru':'Загрузки','ja':'ダウンロード','ko':'다운로드','zh':'下载','ar':'التنزيلات','tr':'İndirmeler','pl':'Pobrane','uk':'Завантаження','sv':'Nedladdningar','no':'Nedlastinger','da':'Downloads','fi':'Lataukset','el':'Λήψεις','cs':'Stažené','ro':'Descărcări','hu':'Letöltések','th':'ดาวน์โหลด','vi':'Tải xuống','id':'Unduhan','ta':'பதிவிறக்கங்கள்','pa':'ਡਾਊਨਲੋਡ'},
  'app_language':     {'en':'App language','hi':'ऐप भाषा','bn':'অ্যাপ ভাষা','fr':'Langue de l\'appli','nl':'App-taal','es':'Idioma de la app','pt':'Idioma do aplicativo','de':'App-Sprache','it':'Lingua dell\'app','ru':'Язык приложения','ja':'アプリの言語','ko':'앱 언어','zh':'应用语言','ar':'لغة التطبيق','tr':'Uygulama dili','pl':'Język aplikacji','uk':'Мова застосунку','sv':'Appens språk','no':'Appens språk','da':'Appens sprog','fi':'Sovelluksen kieli','el':'Γλώσσα εφαρμογής','cs':'Jazyk aplikace','ro':'Limba aplicației','hu':'Alkalmazás nyelve','th':'ภาษาแอป','vi':'Ngôn ngữ ứng dụng','id':'Bahasa aplikasi','ta':'செயலி மொழி','pa':'ਐਪ ਭਾਸ਼ਾ'},
};

// ─────────────────────────────────────────────────────────────────────────────
// AppLocalizations — retrieved via BuildContext
// ─────────────────────────────────────────────────────────────────────────────
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static List<Locale> get supportedLocales =>
      kSupportedLanguages.map((l) => l.locale).toList();

  String _t(String key) {
    final lang = _translations[key];
    if (lang == null) return key;
    return lang[locale.languageCode] ?? lang['en'] ?? key;
  }

  // Navigation
  String get home          => _t('home');
  String get search        => _t('search');
  String get library       => _t('library');
  String get settings      => _t('settings');

  // Player
  String get play          => _t('play');
  String get pause         => _t('pause');
  String get next          => _t('next');
  String get previous      => _t('previous');
  String get shuffle       => _t('shuffle');
  String get repeat        => _t('repeat');

  // Library
  String get likedSongs    => _t('liked_songs');
  String get newPlaylist   => _t('new_playlist');
  String get delete        => _t('delete');

  // Settings
  String get audioQuality  => _t('audio_quality');
  String get onWifi        => _t('on_wifi');
  String get onMobileData  => _t('on_mobile_data');
  String get downloads     => _t('downloads');
  String get appLanguage   => _t('app_language');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kSupportedLanguages.any((l) => l.locale.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
